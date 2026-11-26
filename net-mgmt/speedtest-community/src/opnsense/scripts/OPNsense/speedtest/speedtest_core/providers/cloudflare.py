# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import datetime
import json
import os
import subprocess
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
    label = "Cloudflare"

    def __init__(self):
        self.rust_binary = os.environ.get(
            "OPNSENSE_CLOUDFLARE_RUST_BIN",
            "/usr/local/bin/cloudflare-speed-rust",
        )
        self._rust_available = None

    def rust_status(self):
        if self._rust_available is not None:
            return self._rust_available
        try:
            completed = subprocess.run(
                [self.rust_binary, "--version"],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=True,
                timeout=5,
                text=True,
            )
        except (FileNotFoundError, OSError, subprocess.SubprocessError):
            self._rust_available = None
            return None
        version = completed.stdout.strip().splitlines()[0] if completed.stdout.strip() else ""
        self._rust_available = version or None
        return self._rust_available

    def status(self, settings: Settings) -> Dict:
        rust_version = self.rust_status()
        return {
            "id": self.provider_id,
            "label": self.label,
            "enabled": settings.providers[self.provider_id],
            "available": True,
            "client": "rust-diagnostic" if rust_version else "edge-http",
            "message": rust_version or "Automatic global edge network",
            "supportsCustomServers": True,
            "website": "https://speed.cloudflare.com/",
            "protocol": "Edge HTTP + UDP/STUN" if rust_version else "Edge HTTP",
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

    def probe(self, server: Server, settings: Settings, progress=None) -> ProbeResult:
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
            return values, []
        except Exception as exc:
            return {}, [f"Edge client metadata lookup failed: {exc}"]

    def _run_rust_diagnostic(self, settings: Settings, progress=None):
        if progress is not None:
            progress.update(
                "checking-udp-quality",
                "Checking UDP route quality",
                94,
                provider=self.provider_id,
                target="Automatic edge",
                direction="packet-loss",
            )
        try:
            completed = subprocess.run(
                [
                    self.rust_binary,
                    "--json",
                    "--auto-save",
                    "false",
                    "--skip-diagnostics",
                    "--download-duration",
                    "0s",
                    "--upload-duration",
                    "0s",
                    "--idle-latency-duration",
                    "0s",
                    "--udp-packets",
                    "20",
                    "--concurrency",
                    "1",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
                timeout=60,
                text=True,
            )
        except FileNotFoundError:
            return {}
        except subprocess.TimeoutExpired as exc:
            raise ProviderUnavailableError("The native UDP route diagnostic timed out") from exc
        except subprocess.CalledProcessError as exc:
            detail = next(
                (line.strip() for line in exc.stderr.splitlines() if line.strip()),
                f"exit code {exc.returncode}",
            )
            raise ProviderUnavailableError(f"The native UDP route diagnostic failed: {detail}") from exc
        try:
            return json.loads(completed.stdout)
        except json.JSONDecodeError as exc:
            raise ProviderUnavailableError("The native UDP route diagnostic returned invalid JSON") from exc

    def run(self, server: Server, settings: Settings, progress=None) -> SpeedResult:
        server = self._prepare(server, settings)
        probe = self.probe(server, settings)
        if probe.error:
            raise ProviderUnavailableError(f"Edge latency probe failed: {probe.error}")
        download_url = endpoint(server.base_url, server.download_path)
        upload_url = endpoint(server.base_url, server.upload_path)
        def report_transfer(direction, mbps, elapsed, percent):
            if progress is not None:
                progress.sample(direction, mbps, elapsed, percent)
                progress.update(
                    f"measuring-{direction}",
                    f"Measuring {direction} at {mbps:.1f} Mbps",
                    (48 + percent * 0.24)
                    if direction == "download"
                    else (72 + percent * 0.2),
                    provider=self.provider_id,
                    target=server.selection_name,
                    direction=direction,
                    currentMbps=round(mbps, 2),
                )

        download, download_warnings = timed_download(
            lambda stream: with_query(
                download_url, bytes=25_000_000, r=f"{time.time_ns()}-{stream}"
            ),
            settings.test_duration,
            settings.transfer_streams,
            settings.probe_timeout,
            report_transfer,
        )
        upload, upload_warnings = timed_upload(
            lambda stream: with_query(upload_url, r=f"{time.time_ns()}-{stream}"),
            settings.test_duration,
            settings.transfer_streams,
            settings.probe_timeout,
            report_transfer,
        )
        client_metadata, client_warnings = self._client_info(server, settings)
        client_ip = str(client_metadata.get("ip", ""))
        packet_loss = None
        packet_loss_method = ""
        rust_diagnostic = {}
        if self.rust_status():
            try:
                rust_diagnostic = self._run_rust_diagnostic(settings, progress)
                experimental = rust_diagnostic.get("experimental_udp") or {}
                udp_latency = experimental.get("latency") or {}
                if udp_latency.get("loss") is not None:
                    packet_loss = round(float(udp_latency["loss"]), 2)
                    packet_loss_method = "udp-stun"
                    meta = rust_diagnostic.get("meta") or {}
                    client_metadata = {
                        **client_metadata,
                        "ip": rust_diagnostic.get("ip") or meta.get("clientIp") or client_ip,
                        "city": meta.get("city", client_metadata.get("city", "")),
                        "region": meta.get("region", client_metadata.get("region", "")),
                        "country": meta.get("country", client_metadata.get("country", "")),
                        "postal": meta.get("postalCode", client_metadata.get("postal", "")),
                        "asn": rust_diagnostic.get("asn") or meta.get("asn"),
                        "org": rust_diagnostic.get("as_org") or meta.get("asOrganization"),
                        "coordinates": {
                            "latitude": meta.get("latitude"),
                            "longitude": meta.get("longitude"),
                        },
                        "edge": (
                            meta.get("colo", {}).get("iata")
                            if isinstance(meta.get("colo"), dict)
                            else rust_diagnostic.get("colo")
                        ),
                    }
            except ProviderUnavailableError as exc:
                client_warnings.append(str(exc))
        colo = str(client_metadata.get("colo", ""))
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
            packet_loss=packet_loss,
            packet_loss_method=packet_loss_method,
            engine="standard-library",
            warnings=download_warnings + upload_warnings + client_warnings,
            client_metadata=client_metadata,
            server_metadata={
                "id": server.server_id,
                "name": server.selection_name,
                "baseUrl": server.base_url,
                "location": server.location,
                "colo": colo,
            },
            network_metadata={
                "protocol": "HTTP",
                "transferEngine": "standard-library",
                "packetLossProbe": (
                    {
                        "method": packet_loss_method,
                        "target": (
                            (rust_diagnostic.get("experimental_udp") or {}).get("target")
                        ),
                        "sent": (
                            ((rust_diagnostic.get("experimental_udp") or {}).get("latency") or {}).get(
                                "sent"
                            )
                        ),
                        "received": (
                            ((rust_diagnostic.get("experimental_udp") or {}).get("latency") or {}).get(
                                "received"
                            )
                        ),
                        "jitterMs": (
                            ((rust_diagnostic.get("experimental_udp") or {}).get("latency") or {}).get(
                                "jitter_ms"
                            )
                        ),
                        "mos": (rust_diagnostic.get("experimental_udp") or {}).get("mos"),
                        "quality": (rust_diagnostic.get("experimental_udp") or {}).get(
                            "quality_label"
                        ),
                        "tool": "cloudflare-speed-cli",
                        "toolLicense": "GPL-3.0",
                    }
                    if packet_loss is not None
                    else None
                ),
                "edge": dict(client_metadata),
            },
        )
