# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import datetime
import json
import os
import re
import subprocess
import time
from typing import Dict, List
from urllib.parse import urlsplit

from .base import ProviderAdapter
from ..config import Settings, normalize_http_url
from ..errors import ProviderUnavailableError
from ..http import (
    endpoint,
    fetch_json,
    measure_http_latency,
    open_request,
    timed_download,
    timed_upload,
    with_query,
)
from ..models import ProbeResult, Server, SpeedResult


class LibreSpeedAdapter(ProviderAdapter):
    provider_id = "librespeed"
    label = "LibreSpeed"

    def __init__(self):
        self.rust_binary = os.environ.get(
            "OPNSENSE_LIBRESPEED_RUST_BIN",
            "/usr/local/bin/librespeed-cli-rust",
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
        version = completed.stdout.strip()
        if "librespeed-cli v" not in version or "speedtest-cli-rust" not in version:
            self._rust_available = None
            return None
        self._rust_available = version.splitlines()[0]
        return self._rust_available

    def status(self, settings: Settings) -> Dict:
        rust_version = self.rust_status()
        rust_match = re.search(r"v(\d+\.\d+\.\d+)", rust_version) if rust_version else None
        return {
            "id": self.provider_id,
            "label": self.label,
            "enabled": settings.providers[self.provider_id],
            "available": True,
            "client": "rust-native" if rust_version else "standard-library",
            "message": (
                f"Native transfer engine {rust_match.group(1)}"
                if rust_match
                else "Dependency-free transfer engine"
            ),
            "supportsCustomServers": True,
            "website": "https://librespeed.org/",
            "protocol": "HTTP",
        }

    @staticmethod
    def _server_from_payload(payload: Dict) -> Server:
        base_url = normalize_http_url(str(payload.get("server", "")))
        if not base_url:
            raise ValueError("HTTP measurement target is missing a valid base URL")
        return Server(
            provider="librespeed",
            name=str(payload.get("name") or "LibreSpeed server"),
            server_id=str(payload.get("id") or urlsplit(base_url).hostname or base_url),
            location=str(payload.get("location", "")),
            country=str(payload.get("country", "")),
            base_url=base_url,
            download_path=str(payload.get("dlURL") or "backend/garbage.php"),
            upload_path=str(payload.get("ulURL") or "backend/empty.php"),
            ping_path=str(payload.get("pingURL") or "backend/empty.php"),
            ip_path=str(payload.get("getIpURL") or "backend/getIP.php"),
            source="public",
            metadata={
                "sponsor": str(payload.get("sponsorName", "")),
                "sponsorUrl": str(payload.get("sponsorURL", "")),
            },
        )

    def discover(self, settings: Settings) -> List[Server]:
        try:
            payload = fetch_json(settings.librespeed_list_url, settings.probe_timeout * 3)
        except Exception as exc:
            raise ProviderUnavailableError(f"HTTP target discovery failed: {exc}") from exc
        if not isinstance(payload, list):
            raise ProviderUnavailableError("The HTTP target list did not return a JSON array")
        servers = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            try:
                servers.append(self._server_from_payload(item))
            except ValueError:
                continue
        if not servers:
            raise ProviderUnavailableError("The HTTP target list contained no usable targets")
        return servers

    @staticmethod
    def _prepare(server: Server) -> Server:
        server.base_url = normalize_http_url(server.base_url)
        if not server.base_url:
            raise ProviderUnavailableError("The HTTP measurement target URL is invalid")
        server.download_path = server.download_path or "backend/garbage.php"
        server.upload_path = server.upload_path or "backend/empty.php"
        server.ping_path = server.ping_path or "backend/empty.php"
        server.ip_path = server.ip_path or "backend/getIP.php"
        return server

    def probe(self, server: Server, settings: Settings, progress=None) -> ProbeResult:
        try:
            server = self._prepare(server)
            latency, jitter, samples = measure_http_latency(
                endpoint(server.base_url, server.ping_path),
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

    def _client_info(self, server: Server, settings: Settings):
        if not server.ip_path:
            return "", {}, []
        try:
            url = with_query(endpoint(server.base_url, server.ip_path), isp="true", r=time.time_ns())
            with open_request(url, settings.probe_timeout) as response:
                text = response.read(16384).decode("utf-8", "replace")
            try:
                payload = json.loads(text)
                if isinstance(payload, dict):
                    client_ip = str(payload.get("processedString") or payload.get("ip") or "")
                    raw = payload.get("rawIspInfo")
                    metadata = dict(raw) if isinstance(raw, dict) else {}
                    processed = str(payload.get("processedString") or "")
                    parsed_ip = client_ip.split(" - ", 1)[0].strip()
                    if parsed_ip:
                        metadata["ip"] = parsed_ip
                    if processed:
                        metadata["processedString"] = processed
                    return parsed_ip, metadata, []
            except json.JSONDecodeError:
                pass
            parsed_ip = text.strip().split(" - ", 1)[0][:128]
            return parsed_ip, {"ip": parsed_ip, "processedString": text.strip()}, []
        except Exception as exc:
            return "", {}, [f"Client IP lookup failed: {exc}"]

    def _rust_server_payload(self, server: Server):
        try:
            server_id = int(server.server_id)
        except (TypeError, ValueError):
            server_id = 1
        return {
            "id": server_id,
            "name": server.name,
            "server": server.base_url,
            "dlURL": server.download_path,
            "ulURL": server.upload_path,
            "pingURL": server.ping_path,
            "getIpURL": server.ip_path,
        }

    def _run_rust(
        self,
        server: Server,
        settings: Settings,
        probe: ProbeResult,
        progress=None,
    ) -> SpeedResult:
        server_payload = self._rust_server_payload(server)
        payload = json.dumps([server_payload], separators=(",", ":"))
        arguments = [
            self.rust_binary,
            "--local-json",
            "-",
            "--server",
            str(server_payload["id"]),
            "--json-stream",
            "--telemetry-level",
            "disabled",
            "--duration",
            str(settings.test_duration),
            "--concurrent",
            str(settings.transfer_streams),
            "--timeout",
            str(max(15, settings.probe_timeout)),
            "--no-icmp",
        ]
        process = None
        try:
            process = subprocess.Popen(
                arguments,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            assert process.stdin is not None
            assert process.stdout is not None
            process.stdin.write(payload)
            process.stdin.close()
            reports = None
            for line in process.stdout:
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(event, dict) and event.get("event") == "progress":
                    direction = str(event.get("phase", "latency")).lower()
                    mbps = float(event.get("mbps", 0))
                    elapsed = float(event.get("seconds", 0))
                    phase_progress = float(event.get("progress", 0))
                    if progress is not None:
                        progress.sample(direction, mbps, elapsed, phase_progress)
                        progress.update(
                            f"measuring-{direction}",
                            f"Measuring {direction} at {mbps:.1f} Mbps",
                            (
                                48 + min(phase_progress, 100) * 0.24
                                if direction == "download"
                                else 72 + min(phase_progress, 100) * 0.2
                                if direction == "upload"
                                else 45
                            ),
                            provider=self.provider_id,
                            target=server.selection_name,
                            direction=direction,
                            currentMbps=round(mbps, 2),
                        )
                elif isinstance(event, dict) and event.get("event") == "phase":
                    phase = str(event.get("phase", "latency")).lower()
                    if progress is not None:
                        progress.update(
                            f"measuring-{phase}",
                            (
                                "Checking target latency"
                                if phase == "ping"
                                else f"Measuring {phase}"
                            ),
                            45 if phase in ("ping", "latency") else 50,
                            provider=self.provider_id,
                            target=server.selection_name,
                            direction=phase,
                        )
                elif isinstance(event, dict) and event.get("event") == "result":
                    reports = event.get("reports") or []
                elif isinstance(event, list):
                    reports = event
                elif isinstance(event, dict) and "download" in event and "upload" in event:
                    reports = [event]
            returncode = process.wait(timeout=max(120, settings.test_duration * 12))
            stderr = process.stderr.read() if process.stderr else ""
            if returncode != 0:
                detail = next(
                    (line.strip() for line in stderr.splitlines() if line.strip()),
                    f"exit code {returncode}",
                )
                raise ProviderUnavailableError(f"The native Rust engine failed: {detail}")
            if reports is None:
                raise ProviderUnavailableError("The native Rust engine returned no result")
        except FileNotFoundError as exc:
            raise ProviderUnavailableError("The native Rust engine is not installed") from exc
        except subprocess.TimeoutExpired as exc:
            if process is not None:
                process.kill()
            raise ProviderUnavailableError("The native Rust engine timed out") from exc

        try:
            report = reports[0]
        except (IndexError, TypeError) as exc:
            raise ProviderUnavailableError("The native Rust engine returned invalid JSON") from exc
        report_server = report.get("server") or {}
        client = report.get("client") or {}
        resolved = Server(
            provider="librespeed",
            name=report_server.get("name", server.name),
            server_id=server.server_id,
            location=server.location,
            country=server.country,
            base_url=server.base_url,
            host=server.host,
            port=server.port,
            download_path=server.download_path,
            upload_path=server.upload_path,
            ping_path=server.ping_path,
            ip_path=server.ip_path,
            source=server.source,
            uuid=server.uuid,
        )
        return SpeedResult(
            provider="librespeed",
            timestamp=str(report.get("timestamp") or datetime.datetime.now(datetime.timezone.utc).isoformat()),
            client_ip=str(client.get("ip", "")),
            server=resolved,
            latency=float(report.get("ping", probe.latency)),
            jitter=float(report.get("jitter", probe.jitter)),
            download=float(report["download"]),
            upload=float(report["upload"]),
            link=str(report.get("share") or ""),
            engine="rust",
            client_metadata=client,
            server_metadata={
                "id": server.server_id,
                "name": resolved.name,
                "url": report_server.get("url", server.base_url),
                "location": server.location,
                "country": server.country,
                "sponsor": server.metadata.get("sponsor", ""),
            },
            network_metadata={
                "protocol": "HTTP",
                "transferEngine": "native-rust",
                "bytesSent": report.get("bytes_sent"),
                "bytesReceived": report.get("bytes_received"),
                "tls": report.get("tls"),
            },
        )

    def run(self, server: Server, settings: Settings, progress=None) -> SpeedResult:
        server = self._prepare(server)
        probe = self.probe(server, settings)
        if probe.error:
            raise ProviderUnavailableError(f"HTTP target latency probe failed: {probe.error}")

        fallback_warnings = []
        if self.rust_status():
            try:
                return self._run_rust(server, settings, probe, progress)
            except ProviderUnavailableError as exc:
                fallback_warnings.append(
                    f"Native Rust transfer unavailable; using standard-library fallback: {exc}"
                )

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
                download_url, ckSize=32, r=f"{time.time_ns()}-{stream}"
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
        client_ip, client_metadata, client_warnings = self._client_info(server, settings)
        return SpeedResult(
            provider="librespeed",
            timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            client_ip=client_ip,
            server=server,
            latency=probe.latency,
            jitter=probe.jitter,
            download=download,
            upload=upload,
            engine="standard-library",
            warnings=fallback_warnings + download_warnings + upload_warnings + client_warnings,
            client_metadata=client_metadata,
            server_metadata={
                "id": server.server_id,
                "name": server.selection_name,
                "baseUrl": server.base_url,
                "location": server.location,
                "country": server.country,
                "sponsor": server.metadata.get("sponsor", ""),
            },
            network_metadata={
                "protocol": "HTTP",
                "transferEngine": "standard-library",
            },
        )
