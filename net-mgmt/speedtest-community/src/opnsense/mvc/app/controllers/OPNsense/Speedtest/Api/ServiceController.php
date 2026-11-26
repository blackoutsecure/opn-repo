<?php

/*
 * Copyright 2021 Miha Kralj
 * Copyright 2026
 * SPDX-License-Identifier: BSD-2-Clause
 */

namespace OPNsense\Speedtest\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiControllerBase
{
    public function versionAction()
    {
        return (new Backend())->configdRun('speedtest version');
    }

    public function providerlistAction()
    {
        return (new Backend())->configdRun('speedtest providers');
    }

    public function serverlistAction($provider = null)
    {
        if ($provider === null) {
            return (new Backend())->configdRun('speedtest serverlist');
        }
        $provider = strtolower(trim((string)$provider));
        if (!in_array($provider, ['all', 'ookla', 'librespeed', 'cloudflare'], true)) {
            return ['error' => sprintf(gettext('%s is not a valid provider'), $provider)];
        }
        return (new Backend())->configdpRun('speedtest serverlist-provider', [$provider]);
    }

    public function runAction($provider = null, $server = null)
    {
        if ($provider === null) {
            return (new Backend())->configdpRun('speedtest run', ['0'], false, 300);
        }
        $provider = strtolower(trim((string)$provider));
        $server = $server === null ? 'auto' : trim((string)$server);
        if (preg_match('/^\d+$/', $provider) && $server === 'auto') {
            $server = $provider;
            $provider = 'ookla';
        }
        if (!in_array($provider, ['auto', 'ookla', 'librespeed', 'cloudflare'], true)) {
            return ['error' => sprintf(gettext('%s is not a valid provider'), $provider)];
        }
        if ($server === '') {
            $server = 'auto';
        }
        if (!preg_match('/^[0-9a-z_.:-]+$/i', $server)) {
            return ['error' => gettext('The selected server token is invalid')];
        }
        return (new Backend())->configdpRun(
            'speedtest run-provider',
            [$provider, $server],
            false,
            300
        );
    }

    public function showstatAction()
    {
        return (new Backend())->configdRun('speedtest showstat');
    }

    public function showlogAction()
    {
        return (new Backend())->configdRun('speedtest showlog');
    }

    public function showrecentAction()
    {
        return (new Backend())->configdRun('speedtest showrecent');
    }

    public function deletelogAction()
    {
        return (new Backend())->configdRun('speedtest deletelog');
    }

    public function installhttpAction()
    {
        return (new Backend())->configdRun('speedtest install-socket', false, 300);
    }

    public function installsocketAction()
    {
        return (new Backend())->configdRun('speedtest install-socket', false, 300);
    }

    public function installrustAction()
    {
        return (new Backend())->configdRun('speedtest install-rust', false, 1800);
    }
}
