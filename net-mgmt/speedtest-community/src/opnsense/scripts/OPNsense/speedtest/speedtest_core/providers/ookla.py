# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import datetime
import json
import math
import os
import queue
import re
import socket
import statistics
import subprocess
import threading
import time
from typing import Dict, List, Optional
from urllib.parse import urlsplit

from .base import ProviderAdapter
from ..config import Settings
from ..errors import ProviderUnavailableError
from ..models import ProbeResult, Server, SpeedResult


class OoklaAdapter(ProviderAdapter):
    provider_id = "ookla"
    label = "Ookla"

    def __init__(self):
        self.binary = os.environ.get("OPNSENSE_SPEEDTEST_BIN", "speedtest")
        self._client_cache = None

    def _command(self, arguments, timeout: int = 30) -> subprocess.CompletedProcess:
        try:
            return subprocess.run(
                [self.binary] + arguments,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True,
                timeout=timeout,
                text=True,
            )
        except FileNotFoundError as exc:
            raise ProviderUnavailableError(
                "The native measurement CLI is not installed. Install it in Sources and targets."
            ) from exc
        except subprocess.TimeoutExpired as exc:
            raise ProviderUnavailableError("The native measurement CLI timed out") from exc
        except subprocess.CalledProcessError as exc:
            messages = [
                line.strip()
                for stream in (exc.stderr, exc.stdout)
                if stream
                for line in stream.splitlines()
                if line.strip()
            ]
            detail = messages[-1] if messages else f"exit code {exc.returncode}"
            raise ProviderUnavailableError(f"The native measurement CLI failed: {detail}") from exc

    @staticmethod
    def _finite_float(value) -> Optional[float]:
        try:
            result = float(value)
        except (TypeError, ValueError):
            return None
        return result if math.isfinite(result) else None

    def _report_live_event(self, event: Dict, server: Server, progress) -> None:
        event_type = str(event.get("type", "")).lower()
        if event_type == "ping":
            ping = event.get("ping") or {}
            if not isinstance(ping, dict):
                return
            latency = self._finite_float(ping.get("latency")) or 0.0
            jitter = self._finite_float(ping.get("jitter")) or 0.0
            fraction = max(
                0.0,
                min(1.0, self._finite_float(ping.get("progress")) or 0.0),
            )
            progress.update(
                "measuring-latency",
                f"Measuring latency at {latency:.1f} ms",
                44 + fraction * 4,
                provider=self.provider_id,
                target=server.selection_name,
                direction="latency",
                latency=round(latency, 2),
                jitter=round(jitter, 2),
            )
            return

        if event_type not in ("download", "upload"):
            return
        transfer = event.get(event_type) or {}
        if not isinstance(transfer, dict):
            return
        mbps = (self._finite_float(transfer.get("bandwidth")) or 0.0) / 125000.0
        elapsed = (self._finite_float(transfer.get("elapsed")) or 0.0) / 1000.0
        fraction = max(
            0.0,
            min(1.0, self._finite_float(transfer.get("progress")) or 0.0),
        )
        progress.sample(event_type, mbps, elapsed, fraction * 100.0)
        details = {
            "provider": self.provider_id,
            "target": server.selection_name,
            "direction": event_type,
            "currentMbps": round(mbps, 2),
        }
        transfer_latency = transfer.get("latency") or {}
        if isinstance(transfer_latency, dict):
            loaded_latency = self._finite_float(transfer_latency.get("iqm"))
            if loaded_latency is not None:
                details["latency"] = round(loaded_latency, 2)
        progress.update(
            f"measuring-{event_type}",
            f"Measuring {event_type} at {mbps:.1f} Mbps",
            (48 + fraction * 24) if event_type == "download" else (72 + fraction * 20),
            **details,
        )

    def _stream_official_result(
        self, arguments, timeout: int, server: Server, progress
    ) -> Dict:
        try:
            process = subprocess.Popen(
                [self.binary] + arguments,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
            )
        except FileNotFoundError as exc:
            raise ProviderUnavailableError(
                "The native measurement CLI is not installed. Install it in Sources and targets."
            ) from exc
        assert process.stdout is not None
        assert process.stderr is not None

        output = queue.Queue()
        errors = []
        invalid = []

        def read_stdout() -> None:
            try:
                for line in process.stdout:
                    output.put(line)
            finally:
                output.put(None)

        def read_stderr() -> None:
            for line in process.stderr:
                message = line.strip()
                if message:
                    errors.append(message)

        stdout_thread = threading.Thread(target=read_stdout, daemon=True)
        stderr_thread = threading.Thread(target=read_stderr, daemon=True)
        stdout_thread.start()
        stderr_thread.start()
        deadline = time.monotonic() + timeout
        result = None
        try:
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise subprocess.TimeoutExpired(process.args, timeout)
                try:
                    line = output.get(timeout=min(0.25, remaining))
                except queue.Empty:
                    continue
                if line is None:
                    break
                try:
                    event = json.loads(line)
                except (TypeError, json.JSONDecodeError):
                    invalid.append(line.strip())
                    continue
                if not isinstance(event, dict):
                    continue
                self._report_live_event(event, server, progress)
                if event.get("type") == "result":
                    result = event

            remaining = max(0.1, deadline - time.monotonic())
            returncode = process.wait(timeout=remaining)
        except subprocess.TimeoutExpired as exc:
            process.kill()
            process.wait(timeout=5)
            raise ProviderUnavailableError("The native measurement CLI timed out") from exc
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=5)
            stdout_thread.join(timeout=1)
            stderr_thread.join(timeout=1)

        if returncode != 0:
            detail = errors[-1] if errors else f"exit code {returncode}"
            raise ProviderUnavailableError(f"The native measurement CLI failed: {detail}")
        if result is None:
            detail = errors[-1] if errors else invalid[-1] if invalid else "no final result"
            raise ProviderUnavailableError(f"The native measurement CLI returned invalid JSON: {detail}")
        return result

    def client(self) -> Optional[Dict]:
        if self._client_cache is not None:
            return self._client_cache
        completed = self._command(["--version"], timeout=10)
        lines = [line.strip() for line in completed.stdout.splitlines() if line.strip()]
        version = " ".join(lines[:2])
        official = "ookla" in version.lower()
        self._client_cache = {
            "id": "official" if official else "legacy",
            "version": version,
            "official": official,
        }
        return self._client_cache

    def status(self, settings: Settings) -> Dict:
        enabled = settings.providers[self.provider_id]
        try:
            client = self.client()
            version_match = re.search(r"\b(\d+\.\d+(?:\.\d+)+(?:\.\d+)*)", client["version"])
            return {
                "id": self.provider_id,
                "label": self.label,
                "enabled": enabled,
                "available": True,
                "client": client["id"],
                "message": (
                    f"Native measurement CLI {version_match.group(1)}"
                    if version_match
                    else "Native measurement CLI"
                ),
                "supportsCustomServers": True,
                "website": "https://www.speedtest.net/",
                "protocol": "Native CLI",
            }
        except (ProviderUnavailableError, OSError) as exc:
            return {
                "id": self.provider_id,
                "label": self.label,
                "enabled": enabled,
                "available": False,
                "client": "",
                "message": str(exc),
                "supportsCustomServers": True,
                "website": "https://www.speedtest.net/",
                "protocol": "Native CLI",
            }

    @staticmethod
    def _server_from_json(payload: Dict) -> Server:
        server_id = str(payload.get("id", "")).strip()
        if not server_id:
            raise ValueError("Ookla server is missing an id")
        host_value = str(payload.get("host", "")).strip()
        parsed = urlsplit(host_value if "://" in host_value else "//" + host_value)
        host = parsed.hostname or host_value.split(":")[0]
        port = payload.get("port") or parsed.port
        if port in (None, ""):
            port = 8080
        return Server(
            provider="ookla",
            name=str(payload.get("name") or payload.get("sponsor") or "Ookla server"),
            server_id=server_id,
            location=str(payload.get("location", "")),
            country=str(payload.get("country", "")),
            host=host,
            port=int(port),
            source="public",
            metadata={"client": "official"},
        )

    @staticmethod
    def _legacy_servers(output: str) -> List[Server]:
        pattern = re.compile(
            r"^\s*(?P<id>\d+)\)\s+(?P<name>.+?)\s+\((?P<location>[^()]*)\)"
            r"\s+\[(?P<distance>[0-9.]+)\s*km\]\s*$"
        )
        servers = []
        for line in output.splitlines():
            match = pattern.match(line)
            if not match:
                continue
            location = match.group("location").strip()
            parts = [part.strip() for part in location.rsplit(",", 1)]
            servers.append(
                Server(
                    provider="ookla",
                    name=match.group("name").strip(),
                    server_id=match.group("id"),
                    location=parts[0] if parts else location,
                    country=parts[1] if len(parts) > 1 else "",
                    source="public",
                    metadata={
                        "client": "legacy",
                        "distanceKm": float(match.group("distance")),
                    },
                )
            )
        return servers

    def discover(self, settings: Settings) -> List[Server]:
        client = self.client()
        if client is None:
            return []
        if client["official"]:
            completed = self._command(
                ["--accept-license", "--accept-gdpr", "--servers", "-f", "jsonl"], timeout=30
            )
            servers = []
            for line in completed.stdout.splitlines():
                if not line.strip():
                    continue
                try:
                    server = self._server_from_json(json.loads(line))
                except (TypeError, ValueError, json.JSONDecodeError):
                    continue
                servers.append(server)
            return servers
        completed = self._command(["--list"], timeout=30)
        return self._legacy_servers(completed.stdout)

    @staticmethod
    def _endpoint_host(server: Server):
        host = server.host
        port = server.port
        if server.base_url and not host:
            parsed = urlsplit(server.base_url)
            host = parsed.hostname or ""
            port = port or parsed.port or (443 if parsed.scheme == "https" else 80)
        if not host:
            return "", 0
        return host, port or 8080

    def probe(self, server: Server, settings: Settings, progress=None) -> ProbeResult:
        host, port = self._endpoint_host(server)
        if not host:
            return ProbeResult(
                server=server,
                error=(
                    "The installed CLI does not expose target endpoints for a live "
                    "latency preflight; install the native client or select a target explicitly."
                ),
            )
        timings = []
        errors = []
        for _ in range(settings.ping_samples):
            started = time.perf_counter()
            try:
                with socket.create_connection((host, port), timeout=settings.probe_timeout):
                    timings.append((time.perf_counter() - started) * 1000.0)
            except OSError as exc:
                errors.append(str(exc))
        if not timings:
            return ProbeResult(server=server, error=errors[-1] if errors else "Latency probe failed")
        latency = statistics.median(timings)
        jitter = (
            statistics.mean(abs(current - previous) for previous, current in zip(timings, timings[1:]))
            if len(timings) > 1
            else 0.0
        )
        return ProbeResult(
            server=server,
            latency=latency,
            jitter=jitter,
            samples=timings,
            score=latency + jitter * 0.25,
        )

    @staticmethod
    def _normalize_timestamp(value: str) -> str:
        if not value:
            return datetime.datetime.now(datetime.timezone.utc).isoformat()
        try:
            parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return datetime.datetime.now(datetime.timezone.utc).isoformat()
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=datetime.timezone.utc)
        return parsed.astimezone(datetime.timezone.utc).isoformat()

    def run(self, server: Server, settings: Settings, progress=None) -> SpeedResult:
        client = self.client()
        if client is None:
            raise ProviderUnavailableError("The native measurement CLI is unavailable")
        stream_progress = bool(client["official"] and progress is not None)
        if client["official"]:
            arguments = [
                "--accept-license",
                "--accept-gdpr",
                "-f",
                "jsonl" if stream_progress else "json",
            ]
            if stream_progress:
                arguments += ["--progress=yes", "--progress-update-interval=250"]
            if server.server_id and server.server_id != "auto":
                arguments += ["-s", server.server_id]
        else:
            arguments = ["--json", "--share"]
            if server.server_id and server.server_id != "auto":
                arguments += ["--server", server.server_id]

        stop_heartbeat = threading.Event()
        heartbeat = None
        if progress is not None:
            progress.update(
                "measuring-latency" if stream_progress else "measuring-throughput",
                "Measuring native CLI latency" if stream_progress
                else "Measuring download and upload throughput",
                44 if stream_progress else 55,
                provider=self.provider_id,
                target=server.selection_name,
            )

            def report_elapsed():
                started = time.monotonic()
                while not stop_heartbeat.wait(1):
                    progress.update(
                        "measuring-throughput",
                        f"Measuring download and upload ({time.monotonic() - started:.0f}s)",
                        None,
                        provider=self.provider_id,
                        target=server.selection_name,
                    )

            if not stream_progress:
                heartbeat = threading.Thread(target=report_elapsed, daemon=True)
                heartbeat.start()
        try:
            timeout = max(120, settings.test_duration * 8)
            if stream_progress:
                payload = self._stream_official_result(arguments, timeout, server, progress)
            else:
                completed = self._command(arguments, timeout=timeout)
        finally:
            stop_heartbeat.set()
            if heartbeat is not None:
                heartbeat.join(timeout=1)
        if not stream_progress:
            try:
                payload = json.loads(completed.stdout.strip())
            except json.JSONDecodeError as exc:
                raise ProviderUnavailableError(
                    "The native measurement CLI returned invalid JSON"
                ) from exc

        if client["official"]:
            download = float(payload["download"]["bandwidth"]) / 125000.0
            upload = float(payload["upload"]["bandwidth"]) / 125000.0
            ping = payload.get("ping", {})
            result_data = payload.get("result", {})
            interface = payload.get("interface", {})
            server_payload = payload.get("server", {})
            packet_loss = payload.get("packetLoss")
            if packet_loss is not None:
                try:
                    packet_loss = round(float(packet_loss), 2)
                except (TypeError, ValueError):
                    packet_loss = None
            client_metadata = {
                "ip": interface.get("externalIp", ""),
                "isp": payload.get("isp", ""),
                "interfaceName": interface.get("name", ""),
                "isVpn": interface.get("isVpn"),
            }
            server_metadata = {
                "id": server_payload.get("id", server.server_id),
                "name": server_payload.get("name", server.name),
                "location": server_payload.get("location", server.location),
                "country": server_payload.get("country", server.country),
                "host": server_payload.get("host", server.host),
                "port": server_payload.get("port", server.port),
                "ip": server_payload.get("ip", ""),
            }
            resolved = Server(
                provider="ookla",
                name=server_payload.get("name", server.name),
                server_id=str(server_payload.get("id", server.server_id)),
                location=server_payload.get("location", server.location),
                country=server_payload.get("country", server.country),
                base_url=server.base_url,
                host=server.host,
                port=server.port,
                source=server.source,
                uuid=server.uuid,
            )
            return SpeedResult(
                provider="ookla",
                timestamp=(
                    str(payload.get("timestamp"))
                    if payload.get("timestamp")
                    else self._normalize_timestamp("")
                ),
                client_ip=str(interface.get("externalIp", "")),
                server=resolved,
                latency=float(ping.get("latency", 0)),
                jitter=float(ping.get("jitter", 0)),
                packet_loss=packet_loss,
                packet_loss_method="provider" if packet_loss is not None else "",
                download=download,
                upload=upload,
                link=str(result_data.get("url", "")),
                server_id_output=server_payload.get("id", server.server_id),
                engine="native-cli",
                client_metadata={key: value for key, value in client_metadata.items() if value not in (None, "")},
                server_metadata=server_metadata,
                network_metadata={
                    "protocol": "native-cli",
                    "packetLoss": payload.get("packetLoss"),
                    "downloadBytes": payload.get("download", {}).get("bytes"),
                    "downloadElapsed": payload.get("download", {}).get("elapsed"),
                    "uploadBytes": payload.get("upload", {}).get("bytes"),
                    "uploadElapsed": payload.get("upload", {}).get("elapsed"),
                    "resultId": result_data.get("id"),
                },
            )

        legacy_server = payload.get("server", {})
        legacy_client = payload.get("client", {})
        legacy_packet_loss = payload.get("packetLoss")
        if legacy_packet_loss is not None:
            try:
                legacy_packet_loss = round(float(legacy_packet_loss), 2)
            except (TypeError, ValueError):
                legacy_packet_loss = None
        resolved = Server(
            provider="ookla",
            name=legacy_server.get("sponsor", server.name),
            server_id=str(legacy_server.get("id", server.server_id)),
            location=legacy_server.get("name", server.location),
            country=legacy_server.get("country", server.country),
            source=server.source,
            uuid=server.uuid,
        )
        return SpeedResult(
            provider="ookla",
            timestamp=(
                str(payload.get("timestamp"))
                if payload.get("timestamp")
                else self._normalize_timestamp("")
            ),
            client_ip=str(payload.get("client", {}).get("ip", "")),
            server=resolved,
            latency=float(payload.get("ping", 0)),
            packet_loss=legacy_packet_loss,
            packet_loss_method="provider" if legacy_packet_loss is not None else "",
            download=float(payload.get("download", 0)) / 1_000_000.0,
            upload=float(payload.get("upload", 0)) / 1_000_000.0,
            link=str(payload.get("share") or "").removesuffix(".png"),
            server_id_output=legacy_server.get("id", server.server_id),
            engine="native-cli",
            client_metadata={
                key: value
                for key, value in legacy_client.items()
                if key not in ("internal_ip", "mac", "internalIp") and value not in (None, "")
            },
            server_metadata={
                "id": legacy_server.get("id", server.server_id),
                "name": legacy_server.get("name", server.location),
                "sponsor": legacy_server.get("sponsor", server.name),
                "country": legacy_server.get("country", server.country),
                "host": legacy_server.get("host", ""),
                "url": legacy_server.get("url", ""),
                "distance": legacy_server.get("d"),
                "latency": legacy_server.get("latency"),
                "coordinates": legacy_server.get("latlon") or {
                    "latitude": legacy_server.get("lat"),
                    "longitude": legacy_server.get("lon"),
                },
            },
            network_metadata={
                "protocol": "native-cli",
                "packetLoss": legacy_packet_loss,
                "bytesSent": payload.get("bytes_sent"),
                "bytesReceived": payload.get("bytes_received"),
            },
        )
