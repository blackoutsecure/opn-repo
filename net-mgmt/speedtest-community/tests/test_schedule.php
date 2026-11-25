<?php

namespace OPNsense\Base {
    class UserException extends \RuntimeException {}
    class ApiControllerBase
    {
        public $request;
        public $readOnly = false;
        public function throwReadOnly(): void
        {
            if ($this->readOnly) {
                throw new UserException('Read only');
            }
        }
    }
}
namespace OPNsense\Core {
    class Config
    {
        public static $instance;
        public $locked = false;
        public $saves = 0;
        public $data = ['schedule' => ['enabled' => '0', 'cadence' => 'daily', 'hour' => '3',
                        'minute' => '0', 'weekday' => '1', 'server' => '0', 'mode' => 'both'], 'jobs' => []];
        public $pending = [];
        public static function getInstance() { return self::$instance ??= new self(); }
        public function lock() { $this->locked = true; }
        public function unlock() { $this->locked = false; $this->pending = []; }
        public function object() { return (object)['system' => (object)['timezone' => 'UTC']]; }
        public function save($revision)
        {
            if (!$this->locked) throw new \RuntimeException('Save without native configuration lock');
            $this->data = array_replace($this->data, $this->pending);
            $this->saves++;
        }
    }
    class Backend
    {
        public static $validation = '{"result":"ok"}';
        public static $apply = 'OK';
        public function configdpRun(...$arguments)
        {
            if (!Config::getInstance()->locked) throw new \RuntimeException('Validation outside lock');
            return self::$validation;
        }
        public function configdRun($action)
        {
            if (Config::getInstance()->locked) throw new \RuntimeException('Cron applied before releasing lock');
            if ($action !== 'cron restart') throw new \RuntimeException('Unexpected action');
            return self::$apply;
        }
    }
}
namespace SpeedtestFixture {
    class Node
    {
        public $values;
        public function __construct($values = []) { $this->values = $values; }
        public function __get($key) { return $this->values[$key] ?? ''; }
        public function setNodes($values) { $this->values = array_replace($this->values, $values); }
    }
    class Jobs
    {
        public $nodes = [];
        public function __construct($values)
        {
            foreach ($values as $uuid => $job) $this->nodes[$uuid] = new Node($job);
        }
        public function iterateItems() { return $this->nodes; }
        public function add()
        {
            $uuid = 'fixture-' . count($this->nodes);
            return $this->nodes[$uuid] = new Node();
        }
        public function del($uuid) { unset($this->nodes[$uuid]); }
    }
}
namespace OPNsense\Speedtest {
    class Speedtest
    {
        public $schedule;
        public function __construct() { $this->schedule = new \SpeedtestFixture\Node(\OPNsense\Core\Config::getInstance()->data['schedule']); }
        public function performValidation() { return []; }
        public function serializeToConfig() { \OPNsense\Core\Config::getInstance()->pending['schedule'] = $this->schedule->values; }
    }
}
namespace OPNsense\Cron {
    class Cron
    {
        public $jobs;
        public function __construct()
        {
            $this->jobs = (object)['job' => new \SpeedtestFixture\Jobs(\OPNsense\Core\Config::getInstance()->data['jobs'])];
        }
        public function serializeToConfig()
        {
            \OPNsense\Core\Config::getInstance()->pending['jobs'] =
                array_map(fn($node) => $node->values, $this->jobs->job->nodes);
        }
    }
}
namespace {
    require dirname(__DIR__) . '/src/opnsense/mvc/app/controllers/OPNsense/Speedtest/Api/ScheduleController.php';
    function check($condition, $message) { if (!$condition) throw new \RuntimeException($message); }
    $controller = new \OPNsense\Speedtest\Api\ScheduleController();
    $request = new class {
        public $post = [];
        public $postMethod = true;
        public function isPost() { return $this->postMethod; }
        public function getPost($key) { return $this->post[$key] ?? null; }
    };
    $controller->request = $request;
    $config = \OPNsense\Core\Config::getInstance();
    $request->post = ['schedule' => ['enabled' => '1', 'cadence' => 'daily', 'hour' => '3', 'minute' => '17']];
    check($controller->setAction()['result'] === 'saved', 'Daily schedule saves and applies');
    $jobs = $config->data['jobs'];
    $job = reset($jobs);
    check(count($jobs) === 1 && $job['hours'] === '3' && $job['minutes'] === '17' && $job['weekdays'] === '*', 'Daily cron expression');
    check($job['origin'] === 'Speedtest' && $job['command'] === 'speedtest scheduled' && $job['parameters'] === '', 'Only the fixed plugin command is allowed');
    $controller->setAction();
    check(count($config->data['jobs']) === 1, 'Saving twice does not duplicate jobs');
    foreach (['hourly' => ['*', '*'], 'weekdays' => ['3', '1-5'], 'weekly' => ['3', '1']] as $cadence => [$hours, $weekdays]) {
        $request->post['schedule']['cadence'] = $cadence;
        $controller->setAction();
        $jobs = $config->data['jobs'];
        $job = reset($jobs);
        check($job['hours'] === $hours && $job['weekdays'] === $weekdays, 'Correct cron expression for ' . $cadence);
    }
    $config->data['jobs']['unrelated'] = ['origin' => 'cron', 'enabled' => '1', 'command' => 'other run'];
    $config->data['jobs']['legacy'] = ['origin' => 'cron', 'enabled' => '1', 'command' => 'speedtest run'];
    $before = $config->data;
    try {
        $controller->setAction();
        throw new \RuntimeException('Enabled legacy job did not block a duplicate schedule');
    } catch (\OPNsense\Base\UserException $error) {
        check(str_contains($error->getMessage(), 'duplicate'), 'Duplicate schedule error is actionable');
    }
    check($before === $config->data && !$config->locked, 'Conflict does not save and always unlocks');
    check($controller->getAction()['schedule']['other_jobs'] === 1, 'Existing enabled jobs are visible');
    $request->post['schedule']['enabled'] = '0';
    $controller->setAction();
    check($config->data['jobs']['legacy']['enabled'] === '1', 'Disabling never changes a manually created job');
    check($config->data['jobs']['unrelated'] === $before['jobs']['unrelated'], 'Unrelated cron jobs are preserved');
    \OPNsense\Core\Backend::$apply = 'Error (1)';
    $response = $controller->setAction();
    check($response['result'] === 'failed' && $response['saved'] === true && isset($response['error']), 'A saved-but-unapplied schedule must not look successful');
    $request->post['schedule']['command'] = 'arbitrary command';
    check(isset($controller->setAction()['error']), 'Arbitrary cron command input is rejected');
    unset($request->post['schedule']['command']);
    $request->postMethod = false;
    check(isset($controller->setAction()['error']) && isset($controller->applyAction()['error']), 'GET cannot save or apply');
    $controller->readOnly = true;
    foreach (['setAction', 'applyAction'] as $action) {
        try {
            $controller->{$action}();
            throw new \RuntimeException('Read-only mutation was allowed');
        } catch (\OPNsense\Base\UserException $error) {
            check($error->getMessage() === 'Read only', 'Read-only guard');
        }
    }
    echo "Schedule mapping, idempotency, transaction, coexistence, ACL guards and apply failures passed\n";
}
