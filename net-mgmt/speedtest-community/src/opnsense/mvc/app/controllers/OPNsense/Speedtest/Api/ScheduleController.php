<?php

namespace OPNsense\Speedtest\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Base\UserException;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;
use OPNsense\Cron\Cron;
use OPNsense\Speedtest\Speedtest;

class ScheduleController extends ApiControllerBase
{
    private const FIELDS = ['enabled', 'cadence', 'hour', 'minute', 'weekday', 'server', 'mode'];

    public function getAction()
    {
        $schedule = (new Speedtest())->schedule;
        $result = [];
        foreach (self::FIELDS as $key) {
            $result[$key] = (string)$schedule->{$key};
        }
        $result['timezone'] = (string)Config::getInstance()->object()->system->timezone;
        $result['other_jobs'] = 0;
        foreach ((new Cron())->jobs->job->iterateItems() as $job) {
            if ((string)$job->origin !== 'Speedtest' && (string)$job->enabled === '1'
                && preg_match('/^speedtest(?:\s|$)/', trim((string)$job->command))) {
                $result['other_jobs']++;
            }
        }
        return ['schedule' => $result];
    }

    protected function synchronize(Cron $cron, $schedule)
    {
        $managed = [];
        foreach ($cron->jobs->job->iterateItems() as $uuid => $job) {
            if ((string)$job->origin === 'Speedtest' && (string)$job->command === 'speedtest scheduled') {
                $managed[$uuid] = $job;
            } elseif ((string)$schedule->enabled === '1' && (string)$job->enabled === '1'
                && preg_match('/^speedtest(?:\s|$)/', trim((string)$job->command))) {
                throw new UserException(gettext('An existing speedtest cron job is enabled. Disable it in System > Settings > Cron before enabling this schedule to avoid duplicate measurements.'));
            }
        }
        if (!$managed && (string)$schedule->enabled !== '1') {
            return false;
        }
        $job = $managed ? reset($managed) : $cron->jobs->job->add();
        $cadence = (string)$schedule->cadence;
        $job->setNodes([
            'origin' => 'Speedtest', 'enabled' => (string)$schedule->enabled,
            'minutes' => (string)$schedule->minute,
            'hours' => $cadence === 'hourly' ? '*' : (string)$schedule->hour,
            'days' => '*', 'months' => '*',
            'weekdays' => $cadence === 'weekly' ? (string)$schedule->weekday : ($cadence === 'weekdays' ? '1-5' : '*'),
            'who' => 'root', 'command' => 'speedtest scheduled', 'parameters' => '',
            'description' => 'Speedtest scheduled measurement'
        ]);
        if ($managed) {
            array_shift($managed);
            foreach (array_keys($managed) as $uuid) {
                $cron->jobs->job->del($uuid);
            }
        }
        return true;
    }

    public function setAction()
    {
        $this->throwReadOnly();
        $values = $this->request->getPost('schedule');
        if (!$this->request->isPost() || !is_array($values) || array_diff(array_keys($values), self::FIELDS)
            || count(array_filter($values, 'is_scalar')) !== count($values)) {
            return ['error' => gettext('Use POST with valid schedule settings')];
        }
        $config = Config::getInstance();
        $config->lock();
        try {
            $model = new Speedtest();
            $model->schedule->setNodes($values);
            $validations = [];
            foreach ($model->performValidation() as $message) {
                $validations[$message->getField()] = $message->getMessage();
            }
            if ($validations) {
                return ['result' => 'failed', 'validations' => $validations];
            }
            $candidate = [];
            foreach (self::FIELDS as $key) {
                $candidate[$key] = (string)$model->schedule->{$key};
            }
            $response = json_decode((new Backend())->configdpRun('speedtest validate-schedule', [
                base64_encode(json_encode($candidate))
            ]), true);
            if (!is_array($response) || ($response['result'] ?? '') !== 'ok') {
                throw new UserException($response['error'] ?? gettext('Unable to validate the schedule'));
            }
            $cron = new Cron();
            if ($this->synchronize($cron, $model->schedule)) {
                $cron->serializeToConfig();
            }
            $model->serializeToConfig();
            $config->save(['description' => 'Updated Speedtest schedule']);
        } finally {
            $config->unlock();
        }
        return $this->applyAction();
    }

    public function applyAction()
    {
        $this->throwReadOnly();
        if (!$this->request->isPost()) {
            return ['error' => gettext('Use POST to apply the schedule')];
        }
        if (trim((new Backend())->configdRun('cron restart')) !== 'OK') {
            return ['result' => 'failed', 'saved' => true,
                    'error' => gettext('Schedule saved, but cron could not be applied. Use Apply saved schedule to retry and check backend logs.')];
        }
        return ['result' => 'saved'];
    }
}
