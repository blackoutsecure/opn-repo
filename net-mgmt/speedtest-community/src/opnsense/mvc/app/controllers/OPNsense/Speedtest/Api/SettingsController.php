<?php

namespace OPNsense\Speedtest\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Base\UserException;
use OPNsense\Core\Backend;

class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'speedtest';
    protected static $internalModelClass = 'OPNsense\Speedtest\Speedtest';

    public function catalogAction()
    {
        return (new Backend())->configdRun('speedtest public-list');
    }

    protected function setActionHook()
    {
        $posted = $this->request->getPost('speedtest');
        if (is_array($posted) && array_diff(array_keys($posted), ['general'])) {
            throw new UserException(gettext('Use the schedule endpoint to manage scheduled measurements'));
        }
        $general = $this->getModel()->general;
        $settings = [];
        foreach (['public_servers', 'public_selection', 'combine_servers', 'servers', 'duration', 'timeout', 'concurrent', 'chunks', 'upload_size',
                  'family', 'source', 'icmp', 'http2', 'no_pre_allocate', 'private_ca',
                  'exclude', 'retention_days', 'history_limit'] as $key) {
            $settings[$key] = (string)$general->{$key};
        }
        $servers = json_decode($settings['servers'], true);
        if (is_array($servers)) {
            $settings['servers'] = json_encode($servers, JSON_UNESCAPED_SLASHES);
        }
        $payload = base64_encode(json_encode($settings));
        if (strlen($payload) > 3500) {
            throw new UserException(gettext('Server settings exceed the native backend message limit. Shorten server names or use the administrator-managed server file.'));
        }
        $response = (new Backend())->configdpRun('speedtest validate-settings', [
            $payload
        ]);
        $result = json_decode($response, true);
        if (!is_array($result) || ($result['result'] ?? '') !== 'ok') {
            throw new UserException($result['error'] ?? gettext('Unable to validate Speedtest settings'));
        }
    }
}
