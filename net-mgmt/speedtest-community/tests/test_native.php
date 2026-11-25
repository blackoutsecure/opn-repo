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
        return $arguments[0] === 'speedtest start' ? '12345678-1234-1234-1234-123456789012' : self::$response;
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

$model = new \OPNsense\Speedtest\Speedtest();
check((string)$model->general->duration === '10', 'Default duration');
$model->setNodes(['general' => ['duration' => '31']]);
check(count($model->performValidation()) > 0, 'Invalid duration must be rejected by the native model');
$model->setNodes(['general' => ['duration' => '15', 'family' => 'ipv6', 'private_ca' => '1']]);
check(count($model->performValidation()) === 0, 'Valid settings must pass native validation');
check((string)$model->general->private_ca === '1', 'Boolean settings persist in native format');
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
check(!$acl->isPageAccessible('viewer', '/api/speedtest/service/deletelog'), 'Viewer cannot clear');
check(!$acl->isPageAccessible('viewer', '/api/speedtest/service/start/42/both'), 'Viewer cannot queue a run');
check(!$acl->isPageAccessible('viewer', '/api/speedtest/schedule/set'), 'Viewer cannot schedule');
check($acl->isPageAccessible('viewer', '/api/speedtest/service/history'), 'Viewer can query trends');
check($acl->isPageAccessible('viewer', '/api/speedtest/download/json'), 'Viewer can export details');
check($acl->isPageAccessible('scheduler', '/api/speedtest/schedule/set'), 'Scheduler can save');
check(!$acl->isPageAccessible('scheduler', '/api/cron/settings/setJob'), 'Scheduler cannot edit arbitrary cron jobs');
check($acl->isPageAccessible('runner', '/api/speedtest/service/run/42/latency'), 'Runner can diagnose');
check(!$acl->isPageAccessible('runner', '/api/speedtest/service/deletelog'), 'Runner cannot clear');
check($acl->isPageAccessible('editor', '/api/speedtest/settings/set'), 'Settings privilege');
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
$started = $controller->startAction('42,84', 'both');
check($started['result'] === 'started' && strlen($started['run_id']) === 32, 'Detached measurement has its own tracking ID');
check(SpeedtestTestBackend::$call[2] === true, 'Long measurements use native configd detachment');
SpeedtestTestBackend::$status = '{"status":"running"}';
check(isset($controller->startAction()['error']), 'An active run cannot be queued again');
SpeedtestTestBackend::$status = '{"status":"idle"}';
$request->post = ['family' => 'ipv4', 'source' => '192.0.2.10', 'duration' => '15'];
$controller->runAction(42, 'latency');
check(json_decode(base64_decode(SpeedtestTestBackend::$call[1][2]), true) === [
    'duration' => 15, 'family' => 'ipv4', 'source' => '192.0.2.10'
], 'Explicit API overrides are validated and encoded');
$request->post = ['duration' => '31'];
check(isset($controller->runAction()['error']), 'Invalid API limits are rejected');
$request->isPost = false;
check(isset($controller->runAction()['error']), 'GET cannot start a test');
$controller->readOnly = true;
foreach (['runAction', 'startAction', 'deletelogAction'] as $action) {
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
check(json_decode(base64_decode(SpeedtestTestBackend::$call[1][0]), true)['duration'] === '15',
      'Pre-save validation receives the candidate model');
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
    file_put_contents($argv[2], ob_get_clean());
    $canRun = $canConfigure = $canClear = $canSchedule = false;
    ob_start();
    include $argv[1];
    file_put_contents($argv[2] . '.viewer', ob_get_clean());
}
echo "Native model, API contracts, ACL separation, and Volt compilation passed\n";
