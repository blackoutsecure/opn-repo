<?php

// Run on an OPNsense builder; model and ACL checks never save system configuration.
$root = dirname(__DIR__);
class SpeedtestTestBackend
{
    public static $call;
    public static $response = '{"result":"ok"}';
    public static $status = '{"status":"idle"}';

    public function configdpRun(...$arguments)
    {
        self::$call = $arguments;
        return in_array($arguments[0], ['speedtest start', 'speedtest detect'], true)
            ? '12345678-1234-1234-1234-123456789012' : self::$response;
    }

    public function configdRun($action)
    {
        return self::$status;
    }
}
class_alias(SpeedtestTestBackend::class, 'OPNsense\Core\Backend');
$config = require '/usr/local/opnsense/mvc/app/config/config.php';
require '/usr/local/opnsense/mvc/app/config/loader.php';
require $root . '/src/opnsense/mvc/app/models/OPNsense/Speedtest/Speedtest.php';

function check($condition, $message)
{
    if (!$condition) {
        throw new RuntimeException($message);
    }
}

$configRoot = \OPNsense\Core\Config::getInstance()->object()->OPNsense;
$savedNode = isset($configRoot->speedtest) ? dom_import_simplexml($configRoot->speedtest) : null;
$savedCopy = $savedNode?->cloneNode(true);
$parent = dom_import_simplexml($configRoot);
try {
    $fixture = new DOMDocument();
    $fixture->loadXML('<speedtest version="1.2.2"><general><timeout>5</timeout></general></speedtest>');
    $fixtureNode = $parent->ownerDocument->importNode($fixture->documentElement, true);
    if ($savedNode === null) {
        $parent->appendChild($fixtureNode);
    } else {
        $parent->replaceChild($fixtureNode, $savedNode);
    }
    $legacy = new \OPNsense\Speedtest\Speedtest();
    check((string)$legacy->general->retention_days === '0' && (string)$legacy->general->history_limit === '0',
          'Missing legacy retention fields must remain unlimited before migration');
    check($legacy->runMigrations(), 'Native upgrade migration succeeds without saving system configuration');
    check((string)$configRoot->speedtest->general->retention_days === '0'
          && (string)$configRoot->speedtest->general->history_limit === '0',
          'Native migration persists legacy unlimited choices, not new deletion limits');
    $legacy->Default();
    check((string)$legacy->general->retention_days === '31'
          && (string)$legacy->general->history_limit === '10000', 'Native first-install defaults match the recommendation');
    $legacy->serializeToConfig();
    check((string)$configRoot->speedtest->general->retention_days === '31'
          && (string)$configRoot->speedtest->general->history_limit === '10000',
          'Native serialization supplies both first-install limits to the Python runtime');
} finally {
    if ($savedCopy === null) {
        $parent->removeChild(dom_import_simplexml($configRoot->speedtest));
    } else {
        $parent->replaceChild($savedCopy, dom_import_simplexml($configRoot->speedtest));
    }
}

$model = new \OPNsense\Speedtest\Speedtest();
check((string)$model->general->duration === '10', 'Default duration');
check((string)$model->general->public_servers === '1', 'Official server discovery is enabled by default');
check((string)$model->general->public_selection === 'all', 'New installs allow the official catalog');
check((string)$model->general->combine_servers === '0', 'Existing custom server precedence is preserved');
$modelXml = simplexml_load_file($root . '/src/opnsense/mvc/app/models/OPNsense/Speedtest/Speedtest.xml');
check((string)$modelXml->items->general->retention_days->default === '31'
      && (string)$modelXml->items->general->history_limit->default === '10000',
      'First-install retention is bounded by both age and record count');
$model->setNodes(['general' => ['retention_days' => '0', 'history_limit' => '0']]);
check((string)$model->general->retention_days === '0' && (string)$model->general->history_limit === '0',
      'Explicit unlimited retention overrides the recommended defaults');
check((string)$modelXml->items->general->timeout->default === '15',
      'Default request timeout accommodates slow OPNsense DNS');
require $root . '/src/opnsense/mvc/app/models/OPNsense/Speedtest/Migrations/M1_2_2.php';
$migration = new \OPNsense\Speedtest\Migrations\M1_2_2();
$model->setNodes(['general' => ['timeout' => '8']]);
$migration->run($model);
check((string)$model->general->timeout === '15', 'Migration replaces the old default timeout');
$model->setNodes(['general' => ['timeout' => '5']]);
$migration->run($model);
check((string)$model->general->timeout === '5', 'Migration preserves customized timeout values');
$model->setNodes(['general' => ['duration' => '31']]);
check(count($model->performValidation()) > 0, 'Invalid duration must be rejected by the native model');
$model->setNodes(['general' => ['duration' => '15', 'family' => 'ipv6',
                                  'private_ca' => '1', 'public_servers' => '0',
                                  'public_selection' => '52,84', 'combine_servers' => '1']]);
check(count($model->performValidation()) === 0, 'Valid settings must pass native validation');
check((string)$model->general->public_selection === '52,84', 'Official approvals use native saved settings');
check((string)$model->general->private_ca === '1', 'Boolean settings persist in native format');
check((string)$model->general->public_servers === '0', 'Public registry opt-out persists in native settings');
$model->setNodes(['schedule' => ['enabled' => '1', 'cadence' => 'daily', 'hour' => '24']]);
check(count($model->performValidation()) > 0, 'Invalid schedule hour is rejected by the native model');
$model->setNodes(['schedule' => ['hour' => '3', 'server' => '42,84'], 'general' => ['retention_days' => '365', 'history_limit' => '5000']]);
check(count($model->performValidation()) === 0, 'Schedule and retention settings pass native validation');

$xml = simplexml_load_file($root . '/src/opnsense/mvc/app/models/OPNsense/Speedtest/ACL/ACL.xml');
$patterns = [];
foreach ($xml->children() as $key => $privilege) {
    $patterns[$key] = array_map('strval', iterator_to_array($privilege->patterns->pattern, false));
}
$reflection = new ReflectionClass(\OPNsense\Core\ACL::class);
$acl = $reflection->newInstanceWithoutConstructor();
$users = $reflection->getProperty('userDatabase');
$users->setAccessible(true);
$users->setValue($acl, [
    'viewer' => ['priv' => [$patterns['page-reporting-speedtest']], 'groups' => []],
    'runner' => ['priv' => [$patterns['page-reporting-speedtest'],
                          $patterns['page-reporting-speedtest-run']], 'groups' => []],
    'editor' => ['priv' => [$patterns['page-reporting-speedtest-settings']], 'groups' => []],
    'clearer' => ['priv' => [$patterns['page-reporting-speedtest-clear']], 'groups' => []],
    'scheduler' => ['priv' => [$patterns['page-reporting-speedtest-schedule']], 'groups' => []]
]);
check($acl->isPageAccessible('viewer', '/ui/speedtest/'), 'Viewer page access');
check($acl->isPageAccessible('viewer', '/api/speedtest/service/showstat'), 'Viewer dashboard access');
check($acl->isPageAccessible('viewer', '/api/speedtest/download/csv'), 'Viewer CSV access');
check(!$acl->isPageAccessible('viewer', '/api/speedtest/service/run/42/both'), 'Viewer cannot run');
check(!$acl->isPageAccessible('viewer', '/api/speedtest/settings/set'), 'Viewer cannot save');
check(!$acl->isPageAccessible('viewer', '/api/speedtest/settings/catalog'), 'Viewer cannot refresh the editing catalog');
check(!$acl->isPageAccessible('viewer', '/api/speedtest/service/deletelog'), 'Viewer cannot clear');
check(!$acl->isPageAccessible('viewer', '/api/speedtest/service/start/42/both'), 'Viewer cannot queue a run');
check(!$acl->isPageAccessible('viewer', '/api/speedtest/service/detect'), 'Viewer cannot start active server probes');
check($acl->isPageAccessible('viewer', '/api/speedtest/service/detectionstatus'), 'Detection status is read-only');
check(!$acl->isPageAccessible('viewer', '/api/speedtest/schedule/set'), 'Viewer cannot schedule');
check($acl->isPageAccessible('viewer', '/api/speedtest/service/history'), 'Viewer can query trends');
check($acl->isPageAccessible('viewer', '/api/speedtest/download/json'), 'Viewer can export details');
check($acl->isPageAccessible('scheduler', '/api/speedtest/schedule/set'), 'Scheduler can save');
check(!$acl->isPageAccessible('scheduler', '/api/cron/settings/setJob'), 'Scheduler cannot edit arbitrary cron jobs');
check($acl->isPageAccessible('runner', '/api/speedtest/service/run/42/latency'), 'Runner can diagnose');
check($acl->isPageAccessible('runner', '/api/speedtest/service/detect'), 'Runner can detect servers');
check(!$acl->isPageAccessible('runner', '/api/speedtest/service/deletelog'), 'Runner cannot clear');
check($acl->isPageAccessible('editor', '/api/speedtest/settings/set'), 'Settings privilege');
check($acl->isPageAccessible('editor', '/api/speedtest/settings/catalog'), 'Configurator can browse the official catalog');
check($acl->isPageAccessible('clearer', '/api/speedtest/service/deletelog'), 'Clear privilege');

require $root . '/src/opnsense/mvc/app/controllers/OPNsense/Speedtest/Api/ServiceController.php';
require $root . '/src/opnsense/mvc/app/controllers/OPNsense/Speedtest/Api/SettingsController.php';
require $root . '/src/opnsense/mvc/app/controllers/OPNsense/Speedtest/Api/ScheduleController.php';
$request = new class extends \OPNsense\Mvc\Request {
    public $post = [];
    public $isPost = true;

    public function isPost(): bool
    {
        return $this->isPost;
    }

    public function isGet(): bool
    {
        return !$this->isPost;
    }

    public function getPost($name = null, $filters = null, $defaultValue = null, $notAllowEmpty = false, $noRecursive = false)
    {
        return $name === null ? $this->post : ($this->post[$name] ?? $defaultValue);
    }
};
$controller = new class extends \OPNsense\Speedtest\Api\ServiceController {
    public $readOnly = false;

    public function throwReadOnly(): void
    {
        if ($this->readOnly) {
            throw new \OPNsense\Base\UserException('Read only');
        }
    }
};
$controller->request = $request;
$controller->runAction(42, 'latency');
check(json_decode(base64_decode(SpeedtestTestBackend::$call[1][2]), true) === [],
      'Omitted API options preserve saved source and IP family');
check(base64_decode(SpeedtestTestBackend::$call[1][2]) === '{}', 'Empty API options use the JSON object contract');
check(SpeedtestTestBackend::$call[3] === 250, 'Backend wait covers the maximum measurement deadline');
$request->post = ['days' => '30', 'provider' => 'librespeed'];
$emptyHistory = '{"rows":[],"series":[],"metrics":{},"servers":{},"sources":[],"total":0}';
SpeedtestTestBackend::$response = $emptyHistory;
check($controller->historyAction() === $emptyHistory, 'An empty history response stays valid JSON');
SpeedtestTestBackend::$response = '';
check(str_contains($controller->historyAction()['error'], 'configd'),
      'No backend response reports a service error instead of invalid JSON');
SpeedtestTestBackend::$response = '{"result":"ok"}';
$request->post = [];
$started = $controller->startAction('42,84', 'both');
check($started['result'] === 'started' && strlen($started['run_id']) === 32, 'Detached measurement has its own tracking ID');
check(SpeedtestTestBackend::$call[2] === true, 'Long measurements use native configd detachment');
$detected = $controller->detectAction();
check($detected['result'] === 'started' && strlen($detected['run_id']) === 32,
      'Server detection is a separately tracked native job');
check(SpeedtestTestBackend::$call[0] === 'speedtest detect'
      && SpeedtestTestBackend::$call[1][0] === 'latency' && SpeedtestTestBackend::$call[2] === true,
      'Detection cannot start bandwidth measurements or synchronous HTTP waits');
SpeedtestTestBackend::$status = '{"status":"running"}';
check(isset($controller->startAction()['error']), 'An active run cannot be queued again');
check(isset($controller->detectAction()['error']), 'Detection cannot be queued during a measurement');
SpeedtestTestBackend::$status = '{"status":"busy"}';
check(isset($controller->startAction()['error']), 'A run with a different history cannot be queued again');
SpeedtestTestBackend::$status = '{"status":"unexpected"}';
check(isset($controller->startAction()['error']), 'Unknown measurement status cannot queue a run');
SpeedtestTestBackend::$status = '{"status":"idle"}';
$request->post = ['family' => 'ipv4', 'source' => '192.0.2.10', 'duration' => '15'];
$controller->runAction(42, 'latency');
check(json_decode(base64_decode(SpeedtestTestBackend::$call[1][2]), true) === [
    'duration' => 15, 'family' => 'ipv4', 'source' => '192.0.2.10'
], 'Explicit API overrides are validated and encoded');
foreach (['duration' => 30, 'timeout' => 15, 'concurrent' => 8, 'chunks' => 1000, 'upload_size' => 16384] as $key => $maximum) {
    foreach ([0, $maximum + 1] as $invalid) {
        $request->post = [$key => (string)$invalid];
        check(isset($controller->runAction()['error']), "$key outside its bounds must be rejected");
    }
    $request->post = [$key => (string)$maximum];
    $controller->runAction(42, 'latency');
    check(json_decode(base64_decode(SpeedtestTestBackend::$call[1][2]), true)[$key] === $maximum,
          "$key at its maximum must be forwarded");
}
foreach (['icmp', 'http2', 'no_pre_allocate', 'private_ca'] as $key) {
    $request->post = [$key => '1'];
    $controller->runAction(42, 'latency');
    check(json_decode(base64_decode(SpeedtestTestBackend::$call[1][2]), true)[$key] === true,
          "$key must be forwarded");
    $request->post = [$key => 'yes'];
    check(isset($controller->runAction()['error']), "$key must reject invalid booleans");
}
$request->post = ['duration' => '31'];
check(isset($controller->runAction()['error']), 'Invalid API limits are rejected');
$request->isPost = false;
check(isset($controller->runAction()['error']), 'GET cannot start a test');
check(isset($controller->detectAction()['error']), 'GET cannot start server probes');
$controller->readOnly = true;
foreach (['runAction', 'startAction', 'detectAction', 'deletelogAction'] as $action) {
    try {
        $controller->{$action}();
        throw new RuntimeException('Read-only action was not rejected: ' . $action);
    } catch (\OPNsense\Base\UserException $error) {
        check($error->getMessage() === 'Read only', 'Read-only guard is invoked');
    }
}
$settingsController = new class extends \OPNsense\Speedtest\Api\SettingsController {
    public $model;

    protected function getModel()
    {
        return $this->model;
    }

    public function checkSettings()
    {
        $this->setActionHook();
    }
};
$settingsController->model = $model;
$settingsController->request = $request;
check(is_string($settingsController->getAction()['speedtest']['general']['servers']),
      'Native GET returns server JSON text');
$settingsController->checkSettings();
$candidate = json_decode(base64_decode(SpeedtestTestBackend::$call[1][0]), true);
check($candidate['duration'] === '15',
      'Pre-save validation receives the candidate model');
check($candidate['public_selection'] === '52,84' && $candidate['combine_servers'] === '1',
      'Official approval and source-combining policies reach backend validation');
SpeedtestTestBackend::$response = '{"error":"Invalid server JSON"}';
try {
    $settingsController->checkSettings();
    throw new RuntimeException('Failed validation did not abort the save hook');
} catch (\OPNsense\Base\UserException $error) {
    check($error->getMessage() === 'Invalid server JSON', 'Validation error reaches the native exception handler');
}

// Keep the dynamic command field from reading or updating the live configd cache.
class SpeedtestTestCronActionsField extends \OPNsense\Base\FieldTypes\TextField
{
    public function setFilters($filters) {}
}
class_alias(SpeedtestTestCronActionsField::class, 'OPNsense\Base\FieldTypes\ConfigdActionsField');
$cron = new \OPNsense\Cron\Cron();
foreach ($cron->jobs->job->iterateItems() as $uuid => $job) {
    $cron->jobs->job->del($uuid);
}
$scheduleController = new class extends \OPNsense\Speedtest\Api\ScheduleController {
    public function syncFixture($cron, $schedule) { return $this->synchronize($cron, $schedule); }
};
$scheduleController->syncFixture($cron, $model->schedule);
check(count($cron->performValidation()) === 0, 'Generated cron fields pass the native model');
$nativeJobs = iterator_to_array($cron->jobs->job->iterateItems());
check(count($nativeJobs) === 1, 'Native ArrayField receives exactly one managed job');
$nativeJob = reset($nativeJobs);
check((string)$nativeJob->origin === 'Speedtest' && (string)$nativeJob->command === 'speedtest scheduled',
      'Native cron registration preserves origin and fixed command');
$scheduleController->syncFixture($cron, $model->schedule);
check(count(iterator_to_array($cron->jobs->job->iterateItems())) === 1, 'Native schedule update is idempotent');

$csv = tempnam(sys_get_temp_dir(), 'speedtest-native-csv-');
$downloadSource = tempnam(sys_get_temp_dir(), 'speedtest-native-php-');
try {
    file_put_contents($csv, "Timestamp,Server\n1,Test\n");
    $source = file_get_contents($root . '/src/opnsense/mvc/app/controllers/OPNsense/Speedtest/Api/DownloadController.php');
    file_put_contents($downloadSource, str_replace(
        '/usr/local/opnsense/scripts/OPNsense/speedtest/speedtest.csv', $csv, $source
    ));
    require $downloadSource;
    $download = new \OPNsense\Speedtest\Api\DownloadController();
    $download->response = new \OPNsense\Mvc\Response();
    $download->csvAction();
    $content = new ReflectionProperty($download->response, 'content');
    $content->setAccessible(true);
    $stream = $content->getValue($download->response);
    check(is_resource($stream), 'CSV export uses native streaming instead of loading all history');
    check(stream_get_contents($stream) === "Timestamp,Server\n1,Test\n", 'CSV export preserves bytes');
    fclose($stream);
    file_put_contents($csv . '.jsonl', "{\"mode\":\"latency\"}\n");
    $download->jsonAction();
    $stream = $content->getValue($download->response);
    check(stream_get_contents($stream) === "{\"mode\":\"latency\"}\n", 'Detailed export streams JSONL bytes');
    fclose($stream);
    unlink($csv . '.jsonl');
    unlink($csv);
    try {
        $download->csvAction();
        throw new RuntimeException('Missing history did not raise an error');
    } catch (\OPNsense\Base\UserException $error) {
        check(str_contains($error->getMessage(), 'No readable'), 'Missing CSV is reported explicitly');
    }
} finally {
    if (file_exists($csv)) {
        unlink($csv);
    }
    unlink($downloadSource);
}

$compiler = new \Phalcon\Mvc\View\Engine\Volt\Compiler();
$compiled = $compiler->compileString(file_get_contents(
    $root . '/src/opnsense/mvc/app/views/OPNsense/Speedtest/index.volt'
));
if (isset($argv[1])) {
    file_put_contents($argv[1], $compiled);
}
if (isset($argv[2])) {
    $lang = new class {
        public function _($message)
        {
            return $message;
        }
    };
    $canRun = $canConfigure = $canClear = $canSchedule = true;
    ob_start();
    include $argv[1];
    $adminPage = ob_get_clean();
    check(str_contains($adminPage, 'id="open_server_setup"'), 'Configurator can navigate to server setup');
    check(str_contains($adminPage, 'id="servers_json"'), 'Configurator can edit servers');
    check(str_contains($adminPage, 'id="reportAct"'), 'Runner can start a test');
    $runPanel = substr($adminPage, 0, strpos($adminPage, 'id="history"'));
    check(str_contains($runPanel, '<h2>Speedtest</h2>') && !str_contains($runPanel, 'LibreSpeed'),
        'The run panel uses the Speedtest name without engine branding');
    check(!str_contains($runPanel, 'id="mode"') && preg_match(
        '/<select id="mode"[^>]*>\s*<option value="both" selected>Full test<\/option>/', $adminPage
    ) === 1, 'Manual test mode defaults to Full test in Settings');
    check(!str_contains($runPanel, 'id="serverid"') && preg_match(
        '/<select id="serverid"[^>]*>\s*<option value="0" selected>Auto/', $adminPage
    ) === 1, 'Manual server defaults to Auto in Settings');
    check(!str_contains($runPanel, 'id="speed_units"') && preg_match(
        '/<select id="speed_units"[^>]*>\s*<option value="auto" selected>Auto<\/option>/', $adminPage
    ) === 1, 'Speed units default to Auto in Settings');
    check(str_contains($adminPage, '<summary>About Speedtest</summary>')
        && str_contains($adminPage, 'Measurements use the LibreSpeed Rust engine.'), 'About identifies the actual engine');
    file_put_contents($argv[2], $adminPage);
    $canRun = $canConfigure = $canClear = $canSchedule = false;
    ob_start();
    include $argv[1];
    $viewerPage = ob_get_clean();
    check(!str_contains($viewerPage, 'id="open_server_setup"'), 'Viewer has no configuration shortcut');
    check(!str_contains($viewerPage, 'id="servers_json"'), 'Viewer cannot edit servers');
    check(!str_contains($viewerPage, 'id="reportAct"'), 'Viewer cannot start a test');
    check(!str_contains($viewerPage, 'id="detect_server"'), 'Viewer has no active preview control');
    check(str_contains($viewerPage, 'View only.'), 'Viewer sees why test controls are absent');
    file_put_contents($argv[2] . '.viewer', $viewerPage);
}
echo "Native model, API contracts, ACL separation, and Volt compilation passed\n";
