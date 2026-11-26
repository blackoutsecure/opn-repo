# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
import platform
import ssl
import time
from typing import Dict, Iterable, List, Tuple

from .config import Settings
from .errors import ProviderUnavailableError, ServerNotFoundError, SpeedtestError
from .models import ProbeResult, Server
from .providers import provider_adapters


class SpeedtestOrchestrator:
    def __init__(self, settings: Settings, adapters=None, progress=None):
        self.settings = settings
        self.adapters = adapters or provider_adapters()
        self.progress = progress

    def provider_ids(self, requested: str = "all") -> List[str]:
        requested = requested.lower()
        if requested == "all":
            return list(self.adapters)
        if requested == "auto":
            return list(self.adapters)
        if requested not in self.adapters:
            raise ServerNotFoundError(f"Unknown provider: {requested}")
        return [requested]

    def provider_status(self) -> Dict:
        providers = []
        configured_counts = {}
        for server in self.settings.servers:
            configured_counts[server.provider] = configured_counts.get(server.provider, 0) + 1
        for provider_id, adapter in self.adapters.items():
            status = adapter.status(self.settings)
            status["configuredServers"] = configured_counts.get(provider_id, 0)
            providers.append(status)
        enabled = [provider for provider in providers if provider["enabled"]]
        available = [provider for provider in enabled if provider["available"]]
        return {
            "version": "multi-provider",
            "message": ", ".join(provider["label"] for provider in available)
            if available
            else "No enabled speedtest provider is available",
            "providers": providers,
        }

    def about(self) -> Dict:
        version_path = os.environ.get(
            "OPNSENSE_SPEEDTEST_VERSION",
            "/usr/local/opnsense/version/speedtest-community",
        )
        package_error = ""
        try:
            with open(version_path, "r", encoding="utf-8") as stream:
                package = json.load(stream)
        except (OSError, ValueError, TypeError) as exc:
            package = {
                "product_version": "development",
                "product_hash": "",
                "product_abi": "",
                "product_arch": platform.machine(),
            }
            package_error = str(exc)

        components = []
        for provider_id, adapter in self.adapters.items():
            status = adapter.status(self.settings)
            version = status.get("message", "")
            if provider_id == "ookla" and status.get("available"):
                version = adapter.client()["version"]
            elif provider_id == "librespeed":
                rust = adapter.rust_status()
                version = rust if rust else "Built-in HTTP transfer engine"
            components.append(
                {
                    "name": status["label"],
                    "version": version,
                    "website": status.get("website", ""),
                    "status": "available" if status.get("available") else "unavailable",
                    "required": False,
                    "role": " / ".join(
                        value
                        for value in (
                            status.get("protocol"),
                            status.get("client"),
                        )
                        if value
                    )
                    or "Measurement network adapter",
                }
            )

        python = f"{platform.python_version()} ({platform.python_implementation()})"
        return {
            "package": package,
            "packageError": package_error,
            "runtime": {
                "python": python,
                "openssl": ssl.OPENSSL_VERSION,
                "platform": platform.platform(),
                "architecture": platform.machine(),
            },
            "dependencies": [
                {
                    "name": "Python standard library",
                    "version": python,
                    "status": "available",
                    "required": True,
                    "role": "Configuration, HTTP, history, and orchestration",
                },
                {
                    "name": "Python TLS / OpenSSL",
                    "version": ssl.OPENSSL_VERSION,
                    "status": "available",
                    "required": True,
                    "role": "Verified HTTPS measurement connections",
                },
            ]
            + components,
            "thirdPartyPythonDependencies": [],
        }

    def legacy_ookla_version(self) -> Dict:
        adapter = self.adapters["ookla"]
        status = adapter.status(self.settings)
        version = "none"
        message = "No speedtest package installed"
        if status["available"]:
            version = "binary" if status.get("client") == "official" else "cli"
            client_details = getattr(adapter, "client", None)
            if client_details is not None:
                client = client_details()
                message = client["version"]
            else:
                message = status["message"]
        return {"version": version, "message": message}

    def discover(self, requested: str = "all") -> Dict:
        servers = []
        warnings = []
        providers = []
        for provider_id in self.provider_ids(requested):
            if not self.settings.providers.get(provider_id, False):
                warnings.append(f"{provider_id} is disabled")
                continue
            adapter = self.adapters[provider_id]
            try:
                discovered = adapter.discover(self.settings)
            except SpeedtestError as exc:
                warnings.append(str(exc))
                continue
            if not discovered:
                warnings.append(f"{provider_id} returned no public servers")
                continue
            providers.append(provider_id)
            for server in discovered:
                server.source = "public"
                server.enabled = True
                servers.append(server)
        if not servers:
            message = "; ".join(warnings) if warnings else "No public servers were discovered"
            raise ProviderUnavailableError(message)
        return {
            "servers": [self.server_to_config(server) for server in servers],
            "providers": providers,
            "warnings": warnings,
        }

    def _configured(self, provider_id: str, enabled_only: bool = True) -> List[Server]:
        return [
            server
            for server in self.settings.servers
            if server.provider == provider_id and (not enabled_only or server.enabled)
        ]

    def servers_for_provider(self, provider_id: str) -> Tuple[List[Server], List[str]]:
        warnings = []
        if provider_id not in self.adapters:
            raise ServerNotFoundError(f"Unknown provider: {provider_id}")
        if not self.settings.providers.get(provider_id, False):
            return [], [f"{provider_id} is disabled"]
        configured = self._configured(provider_id, enabled_only=True)
        all_configured = self._configured(provider_id, enabled_only=False)
        has_persisted_records = bool(all_configured)
        has_public_records = any(server.source == "public" for server in all_configured)
        stale = (
            self.settings.auto_refresh
            and time.time() - self.settings.last_refresh
            >= self.settings.refresh_interval * 60
        )
        if configured and not (has_public_records and stale):
            return self._deduplicate(configured), warnings
        if has_persisted_records:
            if has_public_records and stale:
                pass
            else:
                return [], [f"All configured {provider_id} servers are disabled"]
        try:
            discovered = self.adapters[provider_id].discover(self.settings)
            disabled_keys = {server.key for server in all_configured if not server.enabled}
            refreshed = [
                server
                for server in discovered
                if server.key not in disabled_keys
            ]
            custom = [
                server for server in all_configured
                if server.source == "custom" and server.enabled
            ]
            return self._deduplicate(custom + refreshed), warnings
        except SpeedtestError as exc:
            warnings.append(str(exc))
            return self._deduplicate(configured), warnings

    @staticmethod
    def _deduplicate(servers: Iterable[Server]) -> List[Server]:
        unique = {}
        for server in servers:
            unique.setdefault(server.key, server)
        return list(unique.values())

    def list_servers(self, requested: str = "all") -> List[Dict]:
        results = []
        for provider_id in self.provider_ids(requested):
            if not self.settings.providers.get(provider_id, False):
                continue
            servers, _ = self.servers_for_provider(provider_id)
            for server in servers:
                results.append(self.server_to_ui(server))
        return results

    @staticmethod
    def server_to_ui(server: Server) -> Dict:
        payload = {
            "uuid": server.uuid,
            "provider": server.provider,
            "id": server.server_id,
            "serverId": server.server_id,
            "name": server.name,
            "location": server.location,
            "country": server.country,
            "baseUrl": server.base_url,
            "source": server.source,
            "enabled": server.enabled,
            "selectionName": server.selection_name,
        }
        return payload

    @staticmethod
    def server_to_config(server: Server) -> Dict:
        return {
            "enabled": "1" if server.enabled else "0",
            "provider": server.provider,
            "name": server.name,
            "serverId": server.server_id,
            "location": server.location,
            "country": server.country,
            "baseUrl": server.base_url,
            "host": server.host,
            "port": str(server.port) if server.port else "",
            "downloadPath": server.download_path,
            "uploadPath": server.upload_path,
            "pingPath": server.ping_path,
            "ipPath": server.ip_path,
            "source": "public",
        }

    def _candidate_servers(self, provider_id: str) -> List[Server]:
        servers, _ = self.servers_for_provider(provider_id)
        custom = [server for server in servers if server.source == "custom"]
        public = [server for server in servers if server.source != "custom"]
        ordered = custom + public
        return ordered[: self.settings.max_candidates]

    def candidates(self, requested: str) -> List[Tuple[str, Server]]:
        candidates = []
        for provider_id in self.provider_ids(requested):
            for server in self._candidate_servers(provider_id):
                candidates.append((provider_id, server))
        return candidates

    def probe_candidates(self, candidates: List[Tuple[str, Server]]) -> List[ProbeResult]:
        if not candidates:
            raise ProviderUnavailableError("No enabled servers are available for automatic selection")
        results = []
        with ThreadPoolExecutor(max_workers=min(self.settings.probe_workers, len(candidates))) as executor:
            futures = {
                (
                    executor.submit(
                        self.adapters[provider_id].probe,
                        server,
                        self.settings,
                        self.progress,
                    )
                    if self.progress is not None
                    else executor.submit(
                        self.adapters[provider_id].probe,
                        server,
                        self.settings,
                    )
                ): (
                    provider_id,
                    server,
                )
                for provider_id, server in candidates
            }
            total = len(futures)
            checked = 0
            for future in as_completed(futures):
                provider_id, server = futures[future]
                try:
                    result = future.result()
                except Exception as exc:
                    result = ProbeResult(server=server, error=f"{provider_id}: {exc}")
                results.append(result)
                checked += 1
                if self.progress is not None:
                    self.progress.update(
                        "selecting-target",
                        f"Checking measurement target {checked} of {total}",
                        5 + checked / total * 35,
                        checked=checked,
                        total=total,
                    )
        return results

    @staticmethod
    def _selection_payload(
        chosen: ProbeResult, probes: List[ProbeResult], method: str
    ) -> Dict:
        ordered = sorted(
            probes,
            key=lambda result: (not result.succeeded, result.score),
        )
        return {
            "method": method,
            "provider": chosen.server.provider,
            "serverId": chosen.server.server_id,
            "serverUuid": chosen.server.uuid,
            "server": chosen.server.selection_name,
            "latency": round(chosen.latency, 2) if chosen.samples else None,
            "jitter": round(chosen.jitter, 2) if chosen.samples else None,
            "score": round(chosen.score, 2) if chosen.samples else None,
            "probes": [probe.as_dict() for probe in ordered],
        }

    def select_best(self, requested: str = "auto") -> Tuple[Server, Dict, List[ProbeResult]]:
        candidates = self.candidates(requested)
        probes = self.probe_candidates(candidates)
        successful = [probe for probe in probes if probe.succeeded]
        if successful:
            successful.sort(key=lambda probe: probe.score)
            chosen = successful[0]
            if self.progress is not None:
                self.progress.update(
                    "target-selected",
                    f"Selected {chosen.server.selection_name}",
                    42,
                    provider=chosen.server.provider,
                    target=chosen.server.selection_name,
                    latency=round(chosen.latency, 2),
                )
            return chosen.server, self._selection_payload(chosen, probes, "median-latency-jitter"), probes

        # Legacy speedtest-cli cannot expose endpoint hosts for a preflight. It remains
        # a deliberate last resort because it performs its own server selection.
        legacy_candidate = next(
            (
                server
                for provider_id, server in candidates
                if provider_id == "ookla" and not server.host
            ),
            None,
        )
        if legacy_candidate is None:
            details = "; ".join(probe.error for probe in probes if probe.error)
            raise ProviderUnavailableError(
                "No speedtest server passed the latency preflight"
                + (f": {details}" if details else "")
            )
        fallback = ProbeResult(
            server=Server(
                provider="ookla",
                name="Ookla automatic server",
                server_id="",
                source=legacy_candidate.source,
            )
        )
        selection = self._selection_payload(fallback, probes, "provider-fallback")
        return fallback.server, selection, probes

    def _explicit_server(self, provider_id: str, server_key: str) -> Server:
        provider_id = provider_id.lower()
        if provider_id not in self.adapters:
            raise ServerNotFoundError(f"Unknown provider: {provider_id}")
        if not self.settings.providers.get(provider_id, False):
            raise ProviderUnavailableError(f"{provider_id} is disabled in Settings")

        if provider_id == "ookla" and (server_key in ("auto", "0", "") or server_key.isdigit()):
            return Server(
                provider="ookla",
                name="Ookla automatic server" if server_key in ("auto", "0", "") else "Ookla server",
                server_id="" if server_key in ("auto", "0", "") else server_key,
                source="custom",
            )

        for server in self._configured(provider_id, enabled_only=True):
            if server_key in (server.uuid, server.server_id):
                return server

        servers, warnings = self.servers_for_provider(provider_id)
        for server in servers:
            if server_key in (server.uuid, server.server_id):
                return server
        if warnings and not servers:
            raise ProviderUnavailableError(warnings[-1])

        if server_key in ("auto", "0") and servers:
            return servers[0]
        raise ServerNotFoundError(f"{provider_id} server {server_key} is not enabled or no longer exists")

    def run(self, provider_id: str = "auto", server_key: str = "auto") -> Dict:
        provider_id = provider_id.lower() or "auto"
        server_key = server_key.strip() if isinstance(server_key, str) else str(server_key)
        server_key = server_key or "auto"
        retries = []
        if self.progress is not None:
            self.progress.start(provider_id, server_key)
            self.progress.update(
                "selecting-target",
                "Checking the available measurement targets",
                5,
            )

        if provider_id == "auto" and server_key != "auto":
            matches = [
                server
                for server in self.settings.servers
                if (
                    server.enabled
                    and self.settings.providers.get(server.provider, False)
                    and server.uuid == server_key
                )
            ]
            if len(matches) != 1:
                raise ServerNotFoundError(f"Auto selection server {server_key} was not found")
            provider_id = matches[0].provider
            server = matches[0]
            selection = {
                "method": "manual",
                "provider": provider_id,
                "serverId": server.server_id,
                "serverUuid": server.uuid,
                "server": server.selection_name,
                "probes": [],
            }
        elif server_key == "auto" or (provider_id == "auto" and server_key == "0"):
            server, selection, probes = self.select_best(provider_id)
            retries = [
                probe.server
                for probe in sorted(
                    (probe for probe in probes if probe.succeeded),
                    key=lambda probe: probe.score,
                )[1:3]
            ]
        else:
            server = self._explicit_server(provider_id, server_key)
            selection = {
                "method": "manual",
                "provider": provider_id,
                "serverId": server.server_id,
                "serverUuid": server.uuid,
                "server": server.selection_name,
                "probes": [],
            }

        if self.progress is not None:
            self.progress.update(
                "preparing-transfer",
                f"Preparing {getattr(self.adapters[server.provider], 'label', server.provider)} "
                f"at {server.selection_name}",
                44,
                provider=server.provider,
                target=server.selection_name,
            )
        candidates = [server] + retries
        failures = []
        for candidate_index, candidate in enumerate(candidates):
            try:
                if self.progress is None:
                    result = self.adapters[candidate.provider].run(
                        candidate,
                        self.settings,
                    ).as_dict()
                else:
                    result = self.adapters[candidate.provider].run(
                        candidate,
                        self.settings,
                        self.progress,
                    ).as_dict()
                if candidate_index:
                    selection["method"] = "latency-fallback"
                    selection["provider"] = candidate.provider
                    selection["serverId"] = candidate.server_id
                    selection["serverUuid"] = candidate.uuid
                    selection["server"] = candidate.selection_name
                    selection["latency"] = None
                    selection["jitter"] = None
                selection["fallbackErrors"] = failures
                result["selection"] = selection
                if self.progress is not None:
                    result["samples"] = self.progress.samples()
                    self.progress.complete(result)
                return result
            except SpeedtestError as exc:
                failures.append(f"{candidate.provider}/{candidate.server_id or candidate.name}: {exc}")
        raise ProviderUnavailableError(
            "Speedtest failed on all selected candidates: " + "; ".join(failures)
        )
