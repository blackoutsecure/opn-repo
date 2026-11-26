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
        return $this->searchServers(null);
    }

    public function searchPublicServerAction()
    {
        return $this->searchServers('public');
    }

    public function searchCustomServerAction()
    {
        return $this->searchServers('custom');
    }

    private function searchServers(?string $source)
    {
        $filter = null;
        if ($source !== null) {
            $filter = function ($record) use ($source) {
                return strtolower((string)$record->source) === $source;
            };
        }
        $result = $this->searchBase('servers.server', null, 'provider', $filter);
        foreach ($result['rows'] ?? [] as $index => $record) {
            if (
                strtolower((string)($record['provider'] ?? '')) === 'cloudflare' &&
                strtolower((string)($record['source'] ?? '')) === 'public' &&
                (string)($record['serverId'] ?? '') === 'edge'
            ) {
                $result['rows'][$index]['serverId'] = '';
            }
        }
        return $result;
    }

    public function getServerAction($uuid = null)
    {
        return $this->getBase('server', 'servers.server', $uuid);
    }

    public function addServerAction()
    {
        return $this->addBase('server', 'servers.server', [
            'source' => 'custom',
            'available' => '1'
        ]);
    }

    public function setServerAction($uuid)
    {
        $this->requireServerSource($uuid, 'custom');
        return $this->setBase('server', 'servers.server', $uuid);
    }

    public function delServerAction($uuid)
    {
        $this->requireServerSource($uuid, 'custom');
        return $this->delBase('servers.server', $uuid);
    }

    public function toggleServerAction($uuid, $enabled = null)
    {
        $this->requireServerSource($uuid, 'custom');
        return $this->toggleBase('servers.server', $uuid, $enabled);
    }

    public function togglePublicServerAction($uuid, $enabled = null)
    {
        $this->requireServerSource($uuid, 'public');
        return $this->toggleBase('servers.server', $uuid, $enabled);
    }

    private function requireServerSource($uuid, string $source): void
    {
        foreach (explode(',', (string)$uuid) as $itemUuid) {
            $node = $this->getModel()->getNodeByReference('servers.server.' . $itemUuid);
            if ($node === null || (string)$node->source !== $source) {
                throw new UserException(gettext('This action is not available for this target type.'));
            }
        }
    }

    protected function setBaseHook($node)
    {
        $provider = (string)$node->provider;
        $source = (string)$node->source;
        $name = trim((string)$node->name);
        $serverId = trim((string)$node->serverId);
        $baseUrl = trim((string)$node->baseUrl);

        if ($source !== 'custom') {
            throw new UserException(gettext('Public targets are managed automatically and cannot be edited.'));
        }
        $node->source->setValue('custom');
        $node->available->setValue('1');
        $this->assertSafeText($name, gettext('Target name'), 160, false);
        $this->assertSafeText($serverId, gettext('Network target id'), 128, true);
        $this->assertSafeText((string)$node->location, gettext('Location'), 160, true);
        $this->assertSafeText((string)$node->country, gettext('Country'), 80, true);
        $this->assertSafeText((string)$node->host, gettext('Latency host'), 255, true);
        foreach (['downloadPath', 'uploadPath', 'pingPath', 'ipPath'] as $pathField) {
            $path = trim((string)$node->{$pathField});
            $this->assertSafeText($path, gettext('Endpoint path'), 512, true);
            if (
                $path !== '' &&
                (
                    str_starts_with($path, '//') ||
                    preg_match('#^[a-z][a-z0-9+.-]*://#i', $path)
                )
            ) {
                throw new UserException(gettext('Endpoint paths must be relative to the base URL.'));
            }
        }
        if ($provider === 'ookla' && $serverId === '') {
            throw new UserException(gettext('A custom native-CLI target requires a network target id.'));
        }
        if ($provider === 'ookla' && !preg_match('/^\d+$/', $serverId)) {
            throw new UserException(gettext('The native-CLI target id must be numeric.'));
        }
        if (in_array($provider, ['librespeed', 'cloudflare'], true) && $baseUrl === '') {
            throw new UserException(gettext('A custom HTTP server requires a base URL.'));
        }
        if ($baseUrl !== '') {
            $parts = parse_url($baseUrl);
            if (
                $parts === false ||
                !in_array(strtolower($parts['scheme'] ?? ''), ['http', 'https'], true) ||
                empty($parts['host'])
            ) {
                throw new UserException(gettext('Base URL must use HTTP or HTTPS and include a host.'));
            }
        }
    }

    private function assertSafeText(string $value, string $label, int $maximum, bool $optional): void
    {
        if (!$optional && $value === '') {
            throw new UserException(sprintf(gettext('%s is required.'), $label));
        }
        if (
            strlen($value) > $maximum ||
            preg_match('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/', $value)
        ) {
            throw new UserException(sprintf(gettext('%s contains invalid or oversized text.'), $label));
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
            $record['available'] = '1';
            $freshKeys[$key] = true;
            if (!isset($recordKeys[$key])) {
                $recordKeys[$key] = true;
                $records[] = $record;
            }
        }

        $unavailable = 0;
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
                if ((string)$node->available !== '0') {
                    $node->available->setValue('0');
                    ++$unavailable;
                }
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
        $saved['unavailable'] = $unavailable;
        $saved['warnings'] = $payload['warnings'] ?? [];
        $saved['validations'] = array_merge($saved['validations'] ?? [], $imported['validations']);
        return $saved;
    }
}
