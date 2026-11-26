# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import datetime
import time
from typing import Dict, List
from .base import ProviderAdapter
from ..config import Settings, normalize_http_url
from ..errors import ProviderUnavailableError
from ..http import (
    endpoint,
    measure_http_latency,
    open_request,
    timed_download,
    timed_upload,
    with_query,
)
from ..models import ProbeResult, Server, SpeedResult


class CloudflareAdapter(ProviderAdapter):
    provider_id = "cloudflare"
    label = "Cloudflare (Edge)"

    def status(self, settings: Settings) -> Dict:
        return {
            "id": self.provider_id,
            "label": self.label,
            "enabled": settings.providers[self.provider_id],
            "available": True,
            "client": "edge-http",
            "message": "Automatic global edge network",
            "supportsCustomServers": True,
        }

    def discover(self, settings: Settings) -> List[Server]:
        base_url = normalize_http_url(settings.cloudflare_base_url)
        if not base_url:
            raise ProviderUnavailableError("The automatic edge base URL is invalid")
        return [
            Server(
                provider="cloudflare",
                server_id="edge",
                name="Automatic global edge",
                location="Global / DNS-routed",
                country="",
                base_url=base_url,
                download_path="__down",
                upload_path="__up",
                ping_path="__down",
                source="public",
            )
        ]

    @staticmethod
    def _prepare(server: Server, settings: Settings) -> Server:
        server.base_url = normalize_http_url(server.base_url, settings.cloudflare_base_url)
        if not server.base_url:
            raise ProviderUnavailableError("The edge target URL is invalid")
        server.download_path = server.download_path or "__down"
        server.upload_path = server.upload_path or "__up"
        server.ping_path = server.ping_path or "__down"
        return server

    def probe(self, server: Server, settings: Settings) -> ProbeResult:
        try:
            server = self._prepare(server, settings)
            latency, jitter, samples = measure_http_latency(
                with_query(endpoint(server.base_url, server.ping_path), bytes=0),
                settings.ping_samples,
                settings.probe_timeout,
            )
            return ProbeResult(
                server=server,
                latency=latency,
                jitter=jitter,
                samples=samples,
                score=latency + jitter * 0.25,
            )
        except Exception as exc:
            return ProbeResult(server=server, error=str(exc))

    @staticmethod
    def _client_info(server: Server, settings: Settings):
        try:
            with open_request(endpoint(server.base_url, "cdn-cgi/trace"), settings.probe_timeout) as response:
                trace = response.read(16384).decode("utf-8", "replace")
            values = {}
            for line in trace.splitlines():
                if "=" in line:
                    key, value = line.split("=", 1)
                    values[key] = value
            return values.get("ip", ""), values.get("colo", ""), []
        except Exception as exc:
            return "", "", [f"Edge client metadata lookup failed: {exc}"]

    def run(self, server: Server, settings: Settings) -> SpeedResult:
        server = self._prepare(server, settings)
        probe = self.probe(server, settings)
        if probe.error:
            raise ProviderUnavailableError(f"Edge latency probe failed: {probe.error}")
        download_url = endpoint(server.base_url, server.download_path)
        upload_url = endpoint(server.base_url, server.upload_path)
        download, download_warnings = timed_download(
            lambda stream: with_query(
                download_url, bytes=25_000_000, r=f"{time.time_ns()}-{stream}"
            ),
            settings.test_duration,
            settings.transfer_streams,
            settings.probe_timeout,
        )
        upload, upload_warnings = timed_upload(
            lambda stream: with_query(upload_url, r=f"{time.time_ns()}-{stream}"),
            settings.test_duration,
            settings.transfer_streams,
            settings.probe_timeout,
        )
        client_ip, colo, client_warnings = self._client_info(server, settings)
        if colo and "DNS-routed" in server.location:
            server.location = f"Global / edge {colo}"
        return SpeedResult(
            provider="cloudflare",
            timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            client_ip=client_ip,
            server=server,
            latency=probe.latency,
            jitter=probe.jitter,
            download=download,
            upload=upload,
            engine="standard-library",
            warnings=download_warnings + upload_warnings + client_warnings,
        )
