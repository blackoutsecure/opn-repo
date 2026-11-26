# Copyright (C) 2026
# SPDX-License-Identifier: BSD-2-Clause

import csv
import json
import os
import sys
import tempfile
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
from speedtest_core.providers.cloudflare import CloudflareAdapter  # noqa: E402
from speedtest_core.providers.librespeed import LibreSpeedAdapter  # noqa: E402
from speedtest_core.providers.ookla import OoklaAdapter  # noqa: E402


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
        self.assertEqual(settings.servers[0].source, "custom")

    def test_url_normalization_accepts_protocol_relative_http_servers(self):
        self.assertEqual(
            normalize_http_url("//speed.example.test/backend"),
            "https://speed.example.test/backend",
        )
        self.assertEqual(normalize_http_url("file:///tmp/server"), "")


class ProviderParsingTests(unittest.TestCase):
    def test_provider_labels_put_network_name_before_connection_type(self):
        self.assertEqual(PROVIDER_LABELS["ookla"], "Ookla (CLI)")
        self.assertEqual(PROVIDER_LABELS["librespeed"], "LibreSpeed (HTTP)")
        self.assertEqual(PROVIDER_LABELS["cloudflare"], "Cloudflare (Edge)")

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
            "interface": {"externalIp": "192.0.2.10"},
            "server": {
                "id": 10,
                "name": "Example",
                "location": "London",
                "country": "GB",
            },
            "ping": {"latency": 12.5, "jitter": 1.25},
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
                "client": {"ip": "192.0.2.4"},
                "ping": 9.5,
                "jitter": 0.8,
                "download": 850.25,
                "upload": 120.5,
                "share": "",
            }
        ]
        with mock.patch(
            "speedtest_core.providers.librespeed.subprocess.run",
            return_value=mock.Mock(stdout=json.dumps(report), stderr=""),
        ):
            result = adapter._run_rust(server, Settings(test_duration=4), probe)
        self.assertEqual(result.engine, "rust")
        self.assertEqual(result.download, 850.25)
        self.assertEqual(result.client_ip, "192.0.2.4")


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

    def probe(self, server, settings):
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

    def run(self, server, settings):
        self.runs.append((self.provider, server.server_id))
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

    def test_auto_retries_next_provider_when_chosen_transfer_fails(self):
        runs = []

        class FailingAdapter(FakeAdapter):
            def run(self, server, settings):
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


class HistoryTests(unittest.TestCase):
    def test_legacy_csv_is_migrated_without_losing_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "speedtest.csv"
            with path.open("w", encoding="utf-8", newline="") as stream:
                writer = csv.writer(stream)
                writer.writerow(FIELDS[:9])
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
                    }
                )
                self.assertEqual(len(read_log()), 2)
                with path.open("r", encoding="utf-8", newline="") as stream:
                    self.assertEqual(next(csv.reader(stream)), FIELDS)
                clear_history()
            self.assertEqual(path.exists(), True)


if __name__ == "__main__":
    unittest.main()
