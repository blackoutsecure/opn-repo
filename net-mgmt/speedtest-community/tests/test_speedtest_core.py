# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import csv
import io
import json
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock


PLUGIN_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_ROOT = PLUGIN_ROOT / "src/opnsense/scripts/OPNsense/speedtest"
sys.path.insert(0, str(SCRIPT_ROOT))

from speedtest_core.config import Settings, load_settings, normalize_http_url  # noqa: E402
from speedtest_core.errors import ProviderUnavailableError  # noqa: E402
from speedtest_core.history import FIELDS, append_result, clear_history, read_log  # noqa: E402
from speedtest_core.models import PROVIDER_LABELS, ProbeResult, Server, SpeedResult  # noqa: E402
from speedtest_core.orchestrator import SpeedtestOrchestrator  # noqa: E402
from speedtest_core.progress import ProgressReporter, read_progress  # noqa: E402
from speedtest_core.providers.cloudflare import CloudflareAdapter  # noqa: E402
from speedtest_core.providers.librespeed import LibreSpeedAdapter  # noqa: E402
from speedtest_core.providers.ookla import OoklaAdapter  # noqa: E402


class InterfaceRenderingTests(unittest.TestCase):
    def test_live_gauge_values_override_stylesheet_dasharray(self):
        view = (
            PLUGIN_ROOT
            / "src/opnsense/mvc/app/views/OPNsense/Speedtest/index.volt"
        ).read_text(encoding="utf-8")
        self.assertIn(".css(\n            'stroke-dasharray',", view)
        self.assertNotIn(".attr('stroke-dasharray'", view)

    def test_live_progress_animates_numbers_and_renders_streamed_result(self):
        view = (
            PLUGIN_ROOT
            / "src/opnsense/mvc/app/views/OPNsense/Speedtest/index.volt"
        ).read_text(encoding="utf-8")
        self.assertIn("requestAnimationFrame(tick)", view)
        self.assertIn('speedtestSetGaugeNumber("download"', view)
        self.assertIn('speedtestSetGaugeNumber("upload"', view)
        self.assertIn('speedtestSetGaugeNumber("latency"', view)
        self.assertIn("speedtestRenderResult(data.result)", view)


class ConfigTests(unittest.TestCase):
    def test_config_reads_provider_flags_and_server_rows(self):
        payload = """<?xml version="1.0"?>
<opnsense>
  <OPNsense>
    <speedtest>
      <ooklaEnabled>0</ooklaEnabled>
      <librespeedEnabled>1</librespeedEnabled>
      <cloudflareEnabled>1</cloudflareEnabled>
      <maxCandidates>12</maxCandidates>
      <servers>
        <server uuid="0193f5f0-c3d9-4f5a-9f5c-7d3b9eaf0001">
          <enabled>0</enabled>
          <available>0</available>
          <provider>librespeed</provider>
          <name>Local</name>
          <serverId>local</serverId>
          <baseUrl>https://speed.example.test/backend</baseUrl>
          <source>custom</source>
        </server>
      </servers>
    </speedtest>
  </OPNsense>
</opnsense>
"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.xml"
            path.write_text(payload, encoding="utf-8")
            settings = load_settings(str(path))
        self.assertFalse(settings.providers["ookla"])
        self.assertTrue(settings.providers["librespeed"])
        self.assertEqual(settings.max_candidates, 12)
        self.assertEqual(len(settings.servers), 1)
        self.assertFalse(settings.servers[0].enabled)
        self.assertFalse(settings.servers[0].available)
        self.assertEqual(settings.servers[0].source, "custom")

    def test_url_normalization_accepts_protocol_relative_http_servers(self):
        self.assertEqual(
            normalize_http_url("//speed.example.test/backend"),
            "https://speed.example.test/backend",
        )
        self.assertEqual(normalize_http_url("file:///tmp/server"), "")


class ProviderParsingTests(unittest.TestCase):
    def test_provider_labels_put_network_name_before_connection_type(self):
        self.assertEqual(PROVIDER_LABELS["ookla"], "Ookla")
        self.assertEqual(PROVIDER_LABELS["librespeed"], "LibreSpeed")
        self.assertEqual(PROVIDER_LABELS["cloudflare"], "Cloudflare")

    def test_librespeed_preserves_rust_backend_paths(self):
        server = LibreSpeedAdapter._server_from_payload(
            {
                "id": 95,
                "name": "Rust backend",
                "server": "//librespeed.example.test",
                "dlURL": "backend/garbage",
                "ulURL": "backend/empty",
                "pingURL": "backend/empty",
                "getIpURL": "backend/getIP",
            }
        )
        self.assertEqual(server.base_url, "https://librespeed.example.test")
        self.assertEqual(server.download_path, "backend/garbage")
        self.assertEqual(server.ip_path, "backend/getIP")

    def test_legacy_ookla_list_parser_reads_ids_and_locations(self):
        output = "\n".join(
            [
                "Retrieving speedtest.net configuration...",
                " 12345) Example Networks (London, United Kingdom) [42.7 km]",
                " 67890) Another Networks (Paris, France) [101.0 km]",
            ]
        )
        servers = OoklaAdapter._legacy_servers(output)
        self.assertEqual([server.server_id for server in servers], ["12345", "67890"])
        self.assertEqual(servers[0].name, "Example Networks")
        self.assertEqual(servers[0].location, "London")
        self.assertEqual(servers[0].country, "United Kingdom")

    def test_official_ookla_output_uses_bytes_per_second_and_normalizes_server(self):
        adapter = OoklaAdapter()
        adapter._client_cache = {
            "id": "official",
            "version": "Speedtest by Ookla 1.2.0",
            "official": True,
        }
        payload = {
            "timestamp": "2026-11-26T10:00:00Z",
            "interface": {
                "externalIp": "192.0.2.10",
                "name": "igc0",
                "isVpn": False,
            },
            "isp": "Example ISP",
            "server": {
                "id": 10,
                "name": "Example",
                "location": "London",
                "country": "GB",
            },
            "ping": {"latency": 12.5, "jitter": 1.25},
            "packetLoss": 1.5,
            "download": {"bandwidth": 12500000},
            "upload": {"bandwidth": 2500000},
            "result": {"url": "https://www.speedtest.net/result/example"},
        }
        completed = mock.Mock(stdout=json.dumps(payload))
        with mock.patch.object(adapter, "_command", return_value=completed):
            result = adapter.run(Server(provider="ookla", name="Old", server_id="10"), Settings())
        output = result.as_dict()
        self.assertEqual(output["download"], 100.0)
        self.assertEqual(output["upload"], 20.0)
        self.assertEqual(output["serverid"], 10)
        self.assertEqual(output["timestamp"], "2026-11-26T10:00:00Z")
        self.assertEqual(output["clientip"], "192.0.2.10")
        self.assertEqual(output["client"]["isp"], "Example ISP")
        self.assertEqual(output["serverDetails"]["id"], 10)
        self.assertEqual(output["packetLoss"], 1.5)
        self.assertTrue(output["packetLossMeasured"])

    def test_official_ookla_streams_live_latency_and_throughput(self):
        adapter = OoklaAdapter()
        adapter._client_cache = {
            "id": "official",
            "version": "Speedtest by Ookla 1.2.0",
            "official": True,
        }
        events = [
            {
                "type": "ping",
                "ping": {"latency": 4.2, "jitter": 0.5, "progress": 0.5},
            },
            {
                "type": "download",
                "download": {
                    "bandwidth": 12500000,
                    "elapsed": 1000,
                    "progress": 0.5,
                    "latency": {"iqm": 7.5},
                },
            },
            {
                "type": "upload",
                "upload": {
                    "bandwidth": 2500000,
                    "elapsed": 2000,
                    "progress": 0.75,
                    "latency": {"iqm": 8.5},
                },
            },
            {
                "type": "result",
                "timestamp": "2026-11-26T10:00:00Z",
                "interface": {"externalIp": "192.0.2.10"},
                "server": {"id": 10, "name": "Example", "location": "Test"},
                "ping": {"latency": 4.0, "jitter": 0.4},
                "download": {"bandwidth": 12500000},
                "upload": {"bandwidth": 2500000},
                "result": {"url": "https://www.speedtest.net/result/example"},
            },
        ]
        process = mock.Mock()
        process.stdout = io.StringIO("".join(json.dumps(event) + "\n" for event in events))
        process.stderr = io.StringIO()
        process.args = ["speedtest"]
        process.wait.return_value = 0
        progress = mock.Mock()
        with mock.patch("speedtest_core.providers.ookla.subprocess.Popen", return_value=process) as popen:
            result = adapter.run(
                Server(provider="ookla", name="Example", server_id="10"),
                Settings(),
                progress,
            )
        self.assertEqual(result.download, 100.0)
        self.assertEqual(result.upload, 20.0)
        progress.sample.assert_any_call("download", 100.0, 1.0, 50.0)
        progress.sample.assert_any_call("upload", 20.0, 2.0, 75.0)
        phases = [call.args[0] for call in progress.update.call_args_list]
        self.assertIn("measuring-latency", phases)
        self.assertIn("measuring-download", phases)
        self.assertIn("measuring-upload", phases)
        arguments = popen.call_args.args[0]
        self.assertIn("jsonl", arguments)
        self.assertIn("--progress=yes", arguments)

    def test_http_providers_probe_their_configured_ping_endpoints(self):
        settings = Settings(ping_samples=2)
        libre = Server(
            provider="librespeed",
            name="Libre",
            server_id="libre",
            base_url="https://libre.example.test",
            ping_path="backend/latency",
        )
        with mock.patch(
            "speedtest_core.providers.librespeed.measure_http_latency",
            return_value=(12.0, 1.0, [11.0, 13.0]),
        ) as probe:
            LibreSpeedAdapter().probe(libre, settings)
        probe.assert_called_once_with(
            "https://libre.example.test/backend/latency",
            2,
            settings.probe_timeout,
        )

        cloud = Server(
            provider="cloudflare",
            name="Cloud",
            server_id="edge",
            base_url="https://speed.example.test",
            ping_path="__down",
        )
        with mock.patch(
            "speedtest_core.providers.cloudflare.measure_http_latency",
            return_value=(8.0, 0.5, [7.5, 8.5]),
        ) as probe:
            CloudflareAdapter().probe(cloud, settings)
        self.assertEqual(probe.call_args.args[0], "https://speed.example.test/__down?bytes=0")

    def test_librespeed_prefers_native_rust_engine_when_available(self):
        adapter = LibreSpeedAdapter()
        version = (
            "librespeed-cli v1.2.1 (example, built on 2026-11-26)\n"
            "https://github.com/librespeed/speedtest-cli-rust\n"
        )
        with mock.patch(
            "speedtest_core.providers.librespeed.subprocess.run",
            return_value=mock.Mock(stdout=version),
        ):
            self.assertEqual(
                adapter.rust_status(),
                "librespeed-cli v1.2.1 (example, built on 2026-11-26)",
            )

        server = Server(
            provider="librespeed",
            name="Rust target",
            server_id="51",
            base_url="https://speed.example.test/backend",
            download_path="garbage",
            upload_path="empty",
            ping_path="empty",
            ip_path="getIP",
        )
        probe = ProbeResult(
            server=server,
            latency=10.0,
            jitter=1.0,
            samples=[9.0, 10.0, 11.0],
            score=10.25,
        )
        report = [
            {
                "timestamp": "2026-11-26T12:00:00Z",
                "server": {"name": "Rust target", "url": server.base_url},
                "client": {
                    "ip": "192.0.2.4",
                    "city": "Atlanta",
                    "region": "Georgia",
                    "country": "US",
                    "org": "Example ISP",
                },
                "ping": 9.5,
                "jitter": 0.8,
                "download": 850.25,
                "upload": 120.5,
                "share": "",
                "bytes_sent": 1000,
                "bytes_received": 2000,
                "tls": {"version": "TLSv1.3", "cipher": "AES"},
            }
        ]
        process = mock.Mock()
        process.stdin = io.StringIO()
        process.stdout = [
            json.dumps({"event": "progress", "phase": "download", "mbps": 500, "seconds": 1, "progress": 50}) + "\n",
            json.dumps({"event": "result", "reports": report}) + "\n",
        ]
        process.stderr = io.StringIO("")
        process.wait.return_value = 0
        with mock.patch(
            "speedtest_core.providers.librespeed.subprocess.Popen",
            return_value=process,
        ):
            result = adapter._run_rust(server, Settings(test_duration=4), probe)
        self.assertEqual(result.engine, "rust")
        self.assertEqual(result.download, 850.25)
        self.assertEqual(result.client_ip, "192.0.2.4")
        self.assertEqual(result.client_metadata["city"], "Atlanta")
        self.assertEqual(result.network_metadata["bytesReceived"], 2000)

    def test_librespeed_keeps_provider_supplied_client_geo_metadata(self):
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = json.dumps(
            {
                "processedString": "203.0.113.8 - Example ISP, United States",
                "rawIspInfo": {
                    "ip": "203.0.113.8",
                    "city": "Atlanta",
                    "region": "Georgia",
                    "country": "US",
                    "loc": "33.7490,-84.3880",
                    "org": "AS64500 Example ISP",
                    "timezone": "America/New_York",
                },
            }
        ).encode()
        server = Server(
            provider="librespeed",
            name="Geo target",
            server_id="geo",
            base_url="https://speed.example.test",
            ip_path="backend/getIP.php",
        )
        with mock.patch(
            "speedtest_core.providers.librespeed.open_request",
            return_value=response,
        ):
            ip, metadata, warnings = LibreSpeedAdapter()._client_info(server, Settings())
        self.assertEqual(ip, "203.0.113.8")
        self.assertEqual(metadata["loc"], "33.7490,-84.3880")
        self.assertEqual(metadata["org"], "AS64500 Example ISP")
        self.assertEqual(warnings, [])

    def test_cloudflare_keeps_edge_trace_metadata(self):
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = (
            b"ip=198.51.100.4\nloc=US\ncolo=ATL\ntls=TLSv1.3\n"
        )
        server = Server(
            provider="cloudflare",
            name="Edge",
            server_id="edge",
            base_url="https://speed.example.test",
        )
        with mock.patch(
            "speedtest_core.providers.cloudflare.open_request",
            return_value=response,
        ):
            metadata, warnings = CloudflareAdapter._client_info(server, Settings())
        self.assertEqual(metadata["colo"], "ATL")
        self.assertEqual(metadata["loc"], "US")
        self.assertEqual(warnings, [])

    def test_cloudflare_can_capture_optional_rust_udp_loss_diagnostic(self):
        adapter = CloudflareAdapter()
        adapter._rust_available = "cloudflare-speed-cli 1.0.12"
        server = Server(
            provider="cloudflare",
            name="Automatic global edge",
            server_id="edge",
            base_url="https://speed.example.test",
            download_path="__down",
            upload_path="__up",
            ping_path="__down",
        )
        diagnostic = {
            "meta": {
                "clientIp": "198.51.100.9",
                "city": "Atlanta",
                "region": "Georgia",
                "country": "US",
                "latitude": "33.7",
                "longitude": "-84.4",
                "asOrganization": "Example ISP",
                "asn": 64500,
                "colo": {"iata": "ATL"},
            },
            "ip": "198.51.100.9",
            "asn": 64500,
            "as_org": "Example ISP",
            "experimental_udp": {
                "target": "stun:stun.cloudflare.com:3478",
                "latency": {"sent": 20, "received": 20, "loss": 0.0, "jitter_ms": 0.2},
                "mos": 4.4,
                "quality_label": "Excellent",
            },
        }
        with mock.patch.object(adapter, "probe", return_value=ProbeResult(
                server=server,
                latency=20.0,
                jitter=1.0,
                samples=[19, 20, 21],
                score=20.25,
            )), \
            mock.patch.object(adapter, "_client_info", return_value=({"ip": "198.51.100.9"}, [])), \
            mock.patch.object(adapter, "_run_rust_diagnostic", return_value=diagnostic), \
            mock.patch(
                "speedtest_core.providers.cloudflare.timed_download",
                return_value=(500.0, []),
            ), \
            mock.patch(
                "speedtest_core.providers.cloudflare.timed_upload",
                return_value=(100.0, []),
            ):
            result = adapter.run(server, Settings())
        self.assertEqual(result.packet_loss, 0.0)
        self.assertEqual(result.packet_loss_method, "udp-stun")
        self.assertEqual(result.client_metadata["city"], "Atlanta")
        self.assertEqual(
            result.network_metadata["packetLossProbe"]["target"],
            "stun:stun.cloudflare.com:3478",
        )


class FakeAdapter:
    def __init__(self, provider, latencies, runs, discovered=None):
        self.provider = provider
        self.latencies = latencies
        self.runs = runs
        self.probed = []
        self.discovered = discovered or []

    def status(self, settings):
        return {
            "id": self.provider,
            "label": self.provider.title(),
            "enabled": settings.providers[self.provider],
            "available": True,
            "client": "fake",
            "message": "fake",
            "supportsCustomServers": True,
        }

    def discover(self, settings):
        return self.discovered

    def probe(self, server, settings, progress=None):
        self.probed.append(server.server_id)
        latency = self.latencies[server.server_id]
        jitter = 1.0
        return ProbeResult(
            server=server,
            latency=latency,
            jitter=jitter,
            samples=[latency - 1, latency, latency + 1],
            score=latency + 0.25,
        )

    def run(self, server, settings, progress=None):
        self.runs.append((self.provider, server.server_id))
        if progress is not None:
            progress.sample("download", 100.0, 0.5, 50.0)
        return SpeedResult(
            provider=self.provider,
            timestamp="2026-11-26T00:00:00+00:00",
            client_ip="192.0.2.1",
            server=server,
            latency=self.latencies[server.server_id],
            jitter=1.0,
            download=100.0,
            upload=20.0,
        )


class SelectionTests(unittest.TestCase):
    def configured_settings(self):
        return Settings(
            servers=[
                Server(
                    provider="ookla",
                    name="Ookla custom",
                    server_id="100",
                    uuid="ookla-uuid",
                    source="custom",
                ),
                Server(
                    provider="librespeed",
                    name="Libre custom",
                    server_id="libre",
                    uuid="libre-uuid",
                    base_url="https://speed.example.test",
                    source="custom",
                ),
                Server(
                    provider="cloudflare",
                    name="Cloudflare edge",
                    server_id="edge",
                    uuid="cloudflare-uuid",
                    base_url="https://speed.cloudflare.com",
                    source="custom",
                ),
            ],
            ping_samples=3,
            probe_workers=3,
        )

    def test_auto_chooses_lowest_median_latency_across_providers(self):
        runs = []
        adapters = {
            "ookla": FakeAdapter("ookla", {"100": 40.0}, runs),
            "librespeed": FakeAdapter("librespeed", {"libre": 10.0}, runs),
            "cloudflare": FakeAdapter("cloudflare", {"edge": 20.0}, runs),
        }
        orchestrator = SpeedtestOrchestrator(self.configured_settings(), adapters)
        result = orchestrator.run("auto", "auto")
        self.assertEqual(result["provider"], "librespeed")
        self.assertEqual(runs, [("librespeed", "libre")])
        self.assertEqual(result["selection"]["method"], "median-latency-jitter")
        self.assertEqual(len(result["selection"]["probes"]), 3)

    def test_disabled_provider_is_not_probed(self):
        settings = self.configured_settings()
        settings.providers["librespeed"] = False
        runs = []
        adapters = {
            "ookla": FakeAdapter("ookla", {"100": 40.0}, runs),
            "librespeed": FakeAdapter("librespeed", {"libre": 1.0}, runs),
            "cloudflare": FakeAdapter("cloudflare", {"edge": 20.0}, runs),
        }
        orchestrator = SpeedtestOrchestrator(settings, adapters)
        result = orchestrator.run("auto", "auto")
        self.assertEqual(result["provider"], "cloudflare")
        self.assertEqual(adapters["librespeed"].probed, [])

    def test_stale_refresh_preserves_disabled_public_server(self):
        disabled = Server(
            provider="librespeed",
            name="Disabled public",
            server_id="disabled",
            base_url="https://disabled.example.test",
            source="public",
            enabled=False,
        )
        enabled = Server(
            provider="librespeed",
            name="New public",
            server_id="new",
            base_url="https://new.example.test",
            source="public",
        )
        moved_disabled = Server(
            provider="librespeed",
            name="Moved disabled public",
            server_id="disabled",
            base_url="https://moved.example.test",
            source="public",
        )
        settings = Settings(
            providers={"ookla": False, "librespeed": True, "cloudflare": False},
            servers=[disabled],
            last_refresh=0,
        )
        adapter = FakeAdapter(
            "librespeed",
            {"new": 12.0},
            [],
            [moved_disabled, enabled],
        )
        orchestrator = SpeedtestOrchestrator(settings, {"librespeed": adapter})
        servers = orchestrator.servers_for_provider("librespeed")[0]
        self.assertEqual([server.server_id for server in servers], ["new"])

    def test_unavailable_public_target_is_not_selectable(self):
        target = Server(
            provider="librespeed",
            name="Offline public",
            server_id="offline",
            base_url="https://offline.example.test",
            source="public",
            enabled=True,
            available=False,
        )
        settings = Settings(
            providers={"ookla": False, "librespeed": True, "cloudflare": False},
            servers=[target],
            last_refresh=int(time.time()),
        )
        orchestrator = SpeedtestOrchestrator(
            settings,
            {"librespeed": FakeAdapter("librespeed", {"offline": 10.0}, [])},
        )
        servers, warnings = orchestrator.servers_for_provider("librespeed")
        self.assertEqual(servers, [])
        self.assertTrue(warnings)

    def test_public_discovery_rejects_invalid_endpoint_records(self):
        valid = Server(
            provider="librespeed",
            name="Valid",
            server_id="valid",
            base_url="https://speed.example.test",
            download_path="backend/garbage.php",
        )
        invalid = Server(
            provider="librespeed",
            name="Unsafe",
            server_id="unsafe",
            base_url="file:///tmp/speedtest",
        )
        adapter = FakeAdapter("librespeed", {"valid": 10.0}, [], [valid, invalid])
        orchestrator = SpeedtestOrchestrator(
            Settings(providers={"ookla": False, "librespeed": True, "cloudflare": False}),
            {"librespeed": adapter},
        )
        payload = orchestrator.discover("librespeed")
        self.assertEqual(len(payload["servers"]), 1)
        self.assertTrue(any("invalid public target" in warning for warning in payload["warnings"]))

    def test_auto_retries_next_provider_when_chosen_transfer_fails(self):
        runs = []

        class FailingAdapter(FakeAdapter):
            def run(self, server, settings, progress=None):
                raise ProviderUnavailableError("simulated transfer failure")

        adapters = {
            "ookla": FakeAdapter("ookla", {"100": 80.0}, runs),
            "librespeed": FailingAdapter("librespeed", {"libre": 5.0}, runs),
            "cloudflare": FakeAdapter("cloudflare", {"edge": 20.0}, runs),
        }
        result = SpeedtestOrchestrator(self.configured_settings(), adapters).run("auto", "auto")
        self.assertEqual(result["provider"], "cloudflare")
        self.assertEqual(result["selection"]["method"], "latency-fallback")
        self.assertTrue(result["selection"]["fallbackErrors"])

    def test_legacy_numeric_ookla_selection_does_not_discover_servers(self):
        runs = []

        class NoDiscoveryAdapter(FakeAdapter):
            def discover(self, settings):
                raise AssertionError("numeric Ookla selection must not discover servers")

        adapter = NoDiscoveryAdapter("ookla", {"12345": 15.0}, runs)
        settings = Settings(
            providers={"ookla": True, "librespeed": False, "cloudflare": False}
        )
        result = SpeedtestOrchestrator(settings, {"ookla": adapter}).run("ookla", "12345")
        self.assertEqual(runs, [("ookla", "12345")])
        self.assertEqual(result["provider"], "ookla")

    def test_legacy_zero_keeps_provider_automatic_selection(self):
        runs = []
        adapter = FakeAdapter("ookla", {"": 15.0}, runs)
        settings = Settings(
            providers={"ookla": True, "librespeed": False, "cloudflare": False}
        )
        SpeedtestOrchestrator(settings, {"ookla": adapter}).run("ookla", "0")
        self.assertEqual(runs, [("ookla", "")])
        self.assertEqual(adapter.probed, [])

    def test_empty_provider_discovery_is_not_reported_as_refreshed(self):
        empty = FakeAdapter("ookla", {}, [], [])
        cloud = Server(
            provider="cloudflare",
            name="Cloudflare edge",
            server_id="edge",
            base_url="https://speed.cloudflare.com",
        )
        cloudflare = FakeAdapter("cloudflare", {"edge": 10.0}, [], [cloud])
        result = SpeedtestOrchestrator(
            Settings(),
            {"ookla": empty, "cloudflare": cloudflare},
        ).discover("all")
        self.assertEqual(result["providers"], ["cloudflare"])
        self.assertTrue(any("no public servers" in warning for warning in result["warnings"]))

    def test_version_response_keeps_legacy_ookla_contract(self):
        adapter = FakeAdapter("ookla", {}, [])
        result = SpeedtestOrchestrator(Settings(), {"ookla": adapter}).legacy_ookla_version()
        self.assertEqual(result, {"version": "cli", "message": "fake"})

    def test_about_reports_package_runtime_and_no_python_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "speedtest-version.json"
            path.write_text(
                json.dumps(
                    {
                        "product_version": "1.0_9",
                        "product_hash": "abc123",
                        "product_abi": "26.7",
                        "product_arch": "amd64",
                    }
                ),
                encoding="utf-8",
            )
            with mock.patch.dict(
                os.environ,
                {"OPNSENSE_SPEEDTEST_VERSION": str(path)},
            ):
                about = SpeedtestOrchestrator(Settings()).about()
        self.assertEqual(about["package"]["product_version"], "1.0_9")
        self.assertTrue(about["runtime"]["python"])
        self.assertTrue(about["runtime"]["openssl"])
        self.assertEqual(about["thirdPartyPythonDependencies"], [])

    def test_orchestrator_records_live_progress_for_ui_polling(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "progress.json"
            reporter = ProgressReporter(str(path))
            runs = []
            adapters = {
                "ookla": FakeAdapter("ookla", {"100": 40.0}, runs),
                "librespeed": FakeAdapter("librespeed", {"libre": 10.0}, runs),
                "cloudflare": FakeAdapter("cloudflare", {"edge": 20.0}, runs),
            }
            result = SpeedtestOrchestrator(
                self.configured_settings(),
                adapters,
                progress=reporter,
            ).run("auto", "auto")
            self.assertGreater(len(result["selection"].get("probes", [])), 0)
            self.assertTrue(result["samples"])
            with mock.patch.dict(
                os.environ,
                {"OPNSENSE_SPEEDTEST_PROGRESS": str(path)},
            ):
                state = read_progress()
            self.assertFalse(state["active"])
            self.assertEqual(state["phase"], "complete")
            self.assertEqual(state["result"]["samples"][0]["direction"], "download")


class HistoryTests(unittest.TestCase):
    def test_legacy_csv_is_migrated_without_losing_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "speedtest.csv"
            with path.open("w", encoding="utf-8", newline="") as stream:
                writer = csv.writer(stream)
                writer.writerow(FIELDS[:12])
                writer.writerow(
                    [1764115200, "192.0.2.1", "1", "Old", "GB", 100, 20, 5, "https://example.test"]
                )
            with mock.patch.dict(os.environ, {"OPNSENSE_SPEEDTEST_HISTORY": str(path)}):
                rows = read_log()
                append_result(
                    {
                        "timestamp": "2026-11-26T00:00:00+00:00",
                        "provider": "librespeed",
                        "clientip": "192.0.2.2",
                        "serverid": "2",
                        "servername": "New",
                        "country": "US",
                        "download": 200,
                        "upload": 40,
                        "latency": 8,
                        "jitter": 1,
                        "link": "",
                        "selection": {"method": "manual"},
                        "engine": "rust",
                        "packetLoss": 0.5,
                        "packetLossMethod": "provider",
                        "client": {
                            "ip": "192.0.2.2",
                            "city": "Atlanta",
                            "region": "Georgia",
                            "country": "US",
                            "org": "Example ISP",
                        },
                        "serverDetails": {"id": "2", "name": "New"},
                        "network": {"protocol": "HTTP"},
                        "samples": [{"direction": "download", "mbps": 200, "time": 1}],
                    }
                )
                self.assertEqual(len(read_log()), 2)
                with path.open("r", encoding="utf-8", newline="") as stream:
                    reader = csv.reader(stream)
                    self.assertEqual(next(reader), FIELDS)
                    newest = list(reader)[-1]
                    self.assertEqual(newest[12], "rust")
                    self.assertEqual(json.loads(newest[13])["client"]["city"], "Atlanta")
                    self.assertEqual(newest[14], "0.5")
                clear_history()
            self.assertEqual(path.exists(), True)

    def test_progress_file_records_live_samples_and_final_result(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "progress.json"
            reporter = ProgressReporter(str(path))
            reporter.start("librespeed", "53")
            reporter.update("measuring-download", "Measuring download at 500 Mbps", 50)
            reporter.sample("download", 500.0, 1.25, 50.0)
            reporter.complete({"provider": "librespeed", "download": 500.0, "upload": 100.0})
            with mock.patch.dict(os.environ, {"OPNSENSE_SPEEDTEST_PROGRESS": str(path)}):
                payload = read_progress()
            self.assertFalse(payload["active"])
            self.assertEqual(payload["phase"], "complete")
            self.assertEqual(payload["result"]["samples"][0]["direction"], "download")


if __name__ == "__main__":
    unittest.main()
