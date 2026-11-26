<?php

/*
 * Copyright (C) 2026
 * SPDX-License-Identifier: BSD-2-Clause
 */

namespace OPNsense\Speedtest\Api;

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Base\UserException;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;

class SettingsController extends ApiMutableModelControllerBase
{
    protected static $internalModelName = 'speedtest';
    protected static $internalModelClass = '\OPNsense\Speedtest\Speedtest';

    public function searchServerAction()
    {
        $result = $this->searchBase('servers.server', null, 'provider');
        foreach ($result['rows'] ?? [] as &$record) {
            $node = $this->getModel()->getNodeByReference(
                'servers.server.' . ($record['uuid'] ?? '')
            );
            if (
                $node !== null &&
                (string)$node->provider === 'cloudflare' &&
                (string)$node->source === 'public' &&
                (string)$node->serverId === 'edge'
            ) {
                $record['serverId'] = '';
            }
        }
        unset($record);
        return $result;
    }

    public function getServerAction($uuid = null)
    {
        return $this->getBase('server', 'servers.server', $uuid);
    }

    public function addServerAction()
    {
        return $this->addBase('server', 'servers.server');
    }

    public function setServerAction($uuid)
    {
        return $this->setBase('server', 'servers.server', $uuid);
    }

    public function delServerAction($uuid)
    {
        return $this->delBase('servers.server', $uuid);
    }

    public function toggleServerAction($uuid, $enabled = null)
    {
        return $this->toggleBase('servers.server', $uuid, $enabled);
    }

    protected function setBaseHook($node)
    {
        $provider = (string)$node->provider;
        $source = (string)$node->source;
        $serverId = trim((string)$node->serverId);
        $baseUrl = trim((string)$node->baseUrl);

        if ($source !== 'custom') {
            return;
        }
        if ($provider === 'ookla' && $serverId === '') {
            throw new UserException(gettext('A custom native-CLI target requires a network target id.'));
        }
        if (
            $provider === 'cloudflare' &&
            $source === 'public' &&
            $serverId !== 'edge'
        ) {
            throw new UserException(gettext('The automatic edge target id is managed automatically.'));
        }
        if (in_array($provider, ['librespeed', 'cloudflare'], true) && $baseUrl === '') {
            throw new UserException(gettext('A custom HTTP server requires a base URL.'));
        }
    }

    private function serverKey($provider, $serverId, $baseUrl, $source): string
    {
        $identifier = trim((string)$serverId);
        if ($identifier === '') {
            $identifier = rtrim((string)$baseUrl, '/');
        }
        return implode("\n", [
            (string)$provider,
            $identifier,
            (string)$source
        ]);
    }

    public function refreshServersAction($provider = 'all', $automatic = '0')
    {
        if (!$this->request->isPost()) {
            return ['error' => gettext('A POST request is required')];
        }
        $provider = strtolower((string)$provider);
        if (!in_array($provider, ['all', 'ookla', 'librespeed', 'cloudflare'], true)) {
            return ['error' => gettext('Invalid provider')];
        }

        $model = $this->getModel();
        $serverField = $model->getNodeByReference('servers.server');
        if ((string)$automatic === '1') {
            if ((string)$model->autoRefresh !== '1') {
                return [
                    'status' => 'disabled',
                    'automatic' => true,
                    'discovered' => 0,
                    'warnings' => []
                ];
            }
            $providerFields = [
                'ookla' => 'ooklaEnabled',
                'librespeed' => 'librespeedEnabled',
                'cloudflare' => 'cloudflareEnabled'
            ];
            $publicCounts = [
                'ookla' => 0,
                'librespeed' => 0,
                'cloudflare' => 0
            ];
            foreach ($serverField->iterateItems() as $node) {
                $nodeProvider = strtolower((string)$node->provider);
                if ((string)$node->source === 'public' && isset($publicCounts[$nodeProvider])) {
                    ++$publicCounts[$nodeProvider];
                }
            }
            $missingTargets = false;
            $enabledProviders = 0;
            foreach ($providerFields as $providerId => $fieldName) {
                if ($provider !== 'all' && $provider !== $providerId) {
                    continue;
                }
                if ((string)$model->{$fieldName} !== '1') {
                    continue;
                }
                ++$enabledProviders;
                if ($publicCounts[$providerId] === 0) {
                    $missingTargets = true;
                }
            }
            if ($enabledProviders === 0) {
                return [
                    'status' => 'disabled',
                    'automatic' => true,
                    'discovered' => 0,
                    'warnings' => []
                ];
            }
            $lastRefresh = (int)(string)$model->lastRefresh;
            $refreshInterval = (int)(string)$model->refreshInterval * 60;
            $stale = $lastRefresh === 0 || time() - $lastRefresh >= $refreshInterval;
            if (!$stale && !$missingTargets) {
                return [
                    'status' => 'unchanged',
                    'automatic' => true,
                    'discovered' => 0,
                    'warnings' => []
                ];
            }
        }

        $discovery = trim((new Backend())->configdpRun('speedtest discover', [$provider], false, 120));
        $payload = json_decode($discovery, true);
        if (!is_array($payload) || !isset($payload['servers']) || !is_array($payload['servers'])) {
            $message = is_array($payload) && !empty($payload['error'])
                ? $payload['error']
                : gettext('Public server discovery returned no usable data');
            return ['error' => $message];
        }

        Config::getInstance()->lock();
        $existing = [];
        foreach ($serverField->iterateItems() as $node) {
            $key = $this->serverKey(
                $node->provider,
                $node->serverId,
                $node->baseUrl,
                $node->source
            );
            $existing[$key] = [
                'enabled' => (string)$node->enabled,
                'uuid' => (string)$node->getAttribute('uuid')
            ];
        }

        $records = [];
        $recordKeys = [];
        $freshKeys = [];
        $refreshedProviders = array_map('strtolower', $payload['providers'] ?? []);
        foreach ($payload['servers'] as $record) {
            if (!is_array($record)) {
                continue;
            }
            $record['provider'] = strtolower((string)($record['provider'] ?? ''));
            if (!in_array($record['provider'], ['ookla', 'librespeed', 'cloudflare'], true)) {
                continue;
            }
            $record['source'] = 'public';
            $key = $this->serverKey(
                $record['provider'],
                $record['serverId'] ?? '',
                $record['baseUrl'] ?? '',
                $record['source']
            );
            $record['enabled'] = $existing[$key]['enabled'] ?? '1';
            $freshKeys[$key] = true;
            if (!isset($recordKeys[$key])) {
                $recordKeys[$key] = true;
                $records[] = $record;
            }
        }

        $removed = 0;
        $staleUuids = [];
        foreach ($serverField->iterateItems() as $node) {
            $nodeProvider = strtolower((string)$node->provider);
            $nodeSource = (string)$node->source;
            if (
                $nodeSource === 'public' &&
                in_array($nodeProvider, $refreshedProviders, true) &&
                !isset($freshKeys[$this->serverKey(
                    $node->provider,
                    $node->serverId,
                    $node->baseUrl,
                    $node->source
                )])
            ) {
                $uuid = (string)$node->getAttribute('uuid');
                $staleUuids[] = $uuid;
            }
        }
        foreach ($staleUuids as $uuid) {
            if ($serverField->del($uuid)) {
                ++$removed;
            }
        }
        $imported = $serverField->importRecordSet(
            $records,
            ['provider', 'serverId', 'source']
        );
        $model->lastRefresh->setValue((string)time());
        $saved = $this->validateAndSave();
        if (!empty($saved['result']) && $saved['result'] !== 'saved') {
            return $saved;
        }

        $saved['discovered'] = count($records);
        $saved['inserted'] = $imported['inserted'];
        $saved['updated'] = $imported['updated'];
        $saved['removed'] = $removed;
        $saved['warnings'] = $payload['warnings'] ?? [];
        $saved['validations'] = array_merge($saved['validations'] ?? [], $imported['validations']);
        return $saved;
    }
}
