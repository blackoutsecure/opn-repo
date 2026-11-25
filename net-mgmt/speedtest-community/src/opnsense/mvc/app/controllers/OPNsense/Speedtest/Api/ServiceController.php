<?php

/*
 * Copyright 2021 Miha Kralj
 *    All rights reserved.
 *
 *    Redistribution and use in source and binary forms, with or without
 *    modification, are permitted provided that the following conditions are met:
 *
 *    1. Redistributions of source code must retain the above copyright notice,
 *       this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *
 *    THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 *    INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 *    AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 *    AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 *    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 *    SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 *    INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 *    CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *    ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *    POSSIBILITY OF SUCH DAMAGE.
 */
namespace OPNsense\Speedtest\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiControllerBase
{
    public function defaultsAction()
    {
        $general = (new \OPNsense\Speedtest\Speedtest())->general;
        $result = [];
        foreach (['public_servers', 'duration', 'timeout', 'concurrent', 'chunks', 'upload_size',
                  'family', 'source', 'icmp', 'http2', 'no_pre_allocate', 'private_ca',
                  'exclude', 'retention_days', 'history_limit'] as $key) {
            $result[$key] = (string)$general->{$key};
        }
        return $result;
    }

    public function versionAction()
    {
        return (new Backend())->configdRun("speedtest version");
    }

    public function serverlistAction()
    {
        return (new Backend())->configdRun("speedtest serverlist");
    }

    public function runAction($serverid = 0, $mode = 'both')
    {
        return $this->measurement($serverid, $mode, false);
    }

    public function startAction($serverid = 0, $mode = 'both')
    {
        return $this->measurement($serverid, $mode, true);
    }

    public function statusAction()
    {
        return (new Backend())->configdRun('speedtest status');
    }

    public function detectAction()
    {
        return $this->measurement('0', 'latency', true, true);
    }

    public function detectionstatusAction()
    {
        return (new Backend())->configdRun('speedtest detection-status');
    }

    public function historyAction()
    {
        $filters = [];
        foreach (['days', 'page', 'limit', 'server', 'mode', 'status', 'origin', 'family', 'source', 'provider'] as $key) {
            $value = $this->request->getPost($key);
            if ($value !== null) {
                if (!is_scalar($value) || strlen((string)$value) > 200) {
                    return ['error' => gettext('Invalid history filter')];
                }
                $filters[$key] = (string)$value;
            }
        }
        return (new Backend())->configdpRun('speedtest history', [base64_encode(json_encode((object)$filters))]);
    }

    public function statAction()
    {
        return $this->showstatAction();
    }

    protected function measurement($serverid, $mode, $background, $detection = false)
    {
        $this->throwReadOnly();
        if (!$this->request->isPost()) {
            return ['error' => gettext('Use POST to start a measurement')];
        }
        $serverid = trim((string)$serverid);
        if ($serverid === '') {
            $serverid = '0';
        }
        if (!preg_match('/^(?:0|-1|[1-9][0-9]{0,18}(?:,[1-9][0-9]{0,18}){0,9})$/D', $serverid)) {
            return ['error' => sprintf(gettext('%s is not a valid server id'), $serverid)];
        }
        if (!in_array($mode, ['both', 'download', 'upload', 'latency'], true)) {
            return ['error' => gettext('Invalid speedtest mode')];
        }
        $options = [];
        foreach (['duration' => 30, 'timeout' => 15, 'concurrent' => 8,
                  'chunks' => 1000, 'upload_size' => 16384] as $key => $maximum) {
            $value = $this->request->getPost($key);
            if ($value !== null) {
                if (!is_scalar($value) || !preg_match('/^[0-9]+$/D', (string)$value)
                    || (int)$value < 1 || (int)$value > $maximum) {
                    return ['error' => sprintf(gettext('%s must be between 1 and %s'), $key, $maximum)];
                }
                $options[$key] = (int)$value;
            }
        }
        foreach (['icmp', 'http2', 'no_pre_allocate', 'private_ca'] as $key) {
            $value = $this->request->getPost($key);
            if ($value !== null) {
                if (!in_array($value, ['0', '1'], true)) {
                    return ['error' => sprintf(gettext('Invalid option: %s'), $key)];
                }
                $options[$key] = $value === '1';
            }
        }
        $family = $this->request->getPost('family');
        if ($family !== null) {
            if (!in_array($family, ['auto', 'ipv4', 'ipv6'], true)) {
                return ['error' => gettext('Invalid IP family')];
            }
            $options['family'] = $family;
        }
        $source = $this->request->getPost('source');
        if ($source !== null) {
            if (!is_string($source) || ($source !== '' && !filter_var($source, FILTER_VALIDATE_IP))) {
                return ['error' => gettext('Invalid source IP address')];
            }
            $options['source'] = $source;
        }
        $exclude = $this->request->getPost('exclude');
        if ($exclude !== null) {
            if (!is_string($exclude) || !preg_match('/^(?:[1-9][0-9]{0,18}(?:,[1-9][0-9]{0,18}){0,9})?$/D', $exclude)) {
                return ['error' => gettext('Invalid server exclusions')];
            }
            $options['exclude'] = $exclude;
        }
        if ($background) {
            $backend = new Backend();
            $state = json_decode($backend->configdRun('speedtest status'), true);
            if (!is_array($state)
                || !in_array($state['status'] ?? '', ['idle', 'running', 'busy', 'completed', 'failed'], true)
                || isset($state['error']) && $state['status'] !== 'failed') {
                return ['error' => gettext('Unable to check measurement status')];
            }
            if (in_array($state['status'], ['running', 'busy'], true)) {
                return ['error' => gettext('A speedtest is already running')];
            }
            $runId = bin2hex(random_bytes(16));
            $encoded = base64_encode(json_encode((object)$options));
            $response = trim($backend->configdpRun($detection ? 'speedtest detect' : 'speedtest start',
                $detection ? [$mode, $encoded, $runId] : [$serverid, $mode, $encoded, $runId], true));
            if (!preg_match('/^[a-f0-9-]{36}$/D', $response)) {
                return ['error' => gettext('Unable to queue the measurement. Check backend logs.')];
            }
            return ['result' => 'started', 'run_id' => $runId];
        }
        return (new Backend())->configdpRun("speedtest run-options", [
            $serverid, $mode, base64_encode(json_encode((object)$options))
        ], false, 250);
    }

    public function showstatAction()
    {
        return (new Backend())->configdRun("speedtest showstat");
    }

    public function showlogAction()
    {
        return (new Backend())->configdRun("speedtest showlog");
    }
	
	public function showrecentAction()
	{
		return (new Backend())->configdRun("speedtest showrecent");
	}

    public function deletelogAction()
    {
        $this->throwReadOnly();
        if (!$this->request->isPost()) {
            return ['error' => gettext('Use POST to clear history')];
        }
        return (new Backend())->configdRun("speedtest deletelog");
    }    

}
