import contextlib
import base64
import csv
import fcntl
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "src/opnsense/scripts/OPNsense/speedtest/opn_speedtest.py"


class WrapperTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.csvfile = Path(self.directory.name) / "speedtest.csv"
        self.librespeed_servers = Path(self.directory.name) / "servers.json"
        self.librespeed = Path(self.directory.name) / "librespeed-cli"
        self.config_xml = Path(self.directory.name) / "config.xml"
        self.ca_bundle = Path(self.directory.name) / "ca.pem"
        self.config_xml.write_text(
            "<opnsense><OPNsense><speedtest><general><public_servers>0</public_servers>"
            "<retention_days>0</retention_days><history_limit>0</history_limit>"
            "</general></speedtest></OPNsense></opnsense>"
        )

    def wrapper_source(self):
        return SCRIPT.read_text().replace(
            '"/usr/local/opnsense/scripts/OPNsense/speedtest/speedtest.csv"',
            repr(str(self.csvfile)),
        ).replace('"/usr/local/etc/speedtest-community/librespeed-servers.json"',
                  repr(str(self.librespeed_servers))).replace('"/usr/local/bin/librespeed-cli"',
                                                             repr(str(self.librespeed))).replace(
            '"/conf/config.xml"', repr(str(self.config_xml))
        ).replace('"/usr/local/etc/speedtest-community/ca.pem"', repr(str(self.ca_bundle)))

    def run_wrapper(self, arg, calls, *options):
        source = self.wrapper_source()
        output = io.StringIO()
        with patch.object(sys, "argv", [str(SCRIPT), arg, *options]), \
                patch("subprocess.run", side_effect=calls) as run, \
                contextlib.redirect_stdout(output):
            try:
                exec(compile(source, str(SCRIPT), "exec"),
                     {"__name__": "__main__", "__file__": str(SCRIPT)})
            except SystemExit as exc:
                self.assertIn(exc.code, (None, 0))
        is_csv = '--format' in options and options[options.index('--format') + 1] == 'csv'
        return (output.getvalue() if is_csv else json.loads(output.getvalue())), run

    def configure_librespeed(self):
        servers = [{"id": 42, "name": "Lab", "server": "https://bench.example.net/",
                    "dlURL": "garbage", "ulURL": "empty", "pingURL": "empty", "getIpURL": "getIP"}]
        self.librespeed_servers.write_text(json.dumps(servers))
        self.librespeed.touch(mode=0o700)
        return servers

    def test_librespeed_runs_only_against_configured_server(self):
        servers = self.configure_librespeed()
        servers[0]['sponsorName'] = 'Lab network'
        self.librespeed_servers.write_text(json.dumps(servers))
        second = dict(servers[0], id=84, server="https://other.example.net/")
        self.librespeed_servers.write_text(json.dumps([*servers, second]))
        result = {"timestamp": "2026-11-24T22:00:00-05:00",
                  "server": {"url": servers[0]["server"]}, "client": {"ip": "192.0.2.9", "org": "Example ISP"},
                  "ping": 5.11, "jitter": 0, "download": 312.5, "upload": 125.75,
                  "bytes_sent": 123456, "bytes_received": 654321}
        output, run = self.run_wrapper("42", [
            subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode()),
        ])
        self.assertEqual((output["provider"], output["download"], output["upload"], output["jitter"]),
                         ("librespeed", 312.5, 125.75, 0))
        self.assertNotIn("packetloss", output)
        self.assertEqual(output["clientip"], "")
        self.assertEqual(output['sponsor'], 'Lab network')
        self.assertEqual(output['connection'], {'ip': '192.0.2.9', 'isp': 'Example ISP'})
        self.assertNotIn('192.0.2.9', self.csvfile.read_text())
        self.assertNotIn('192.0.2.9', Path(str(self.csvfile) + '.jsonl').read_text())
        self.assertNotIn('Example ISP', Path(str(self.csvfile) + '.jsonl').read_text())
        self.assertEqual(self.run_wrapper('status', [])[0]['results'][0]['connection'], output['connection'])
        self.assertEqual(output["link"], "")
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0][:4], [str(self.librespeed), "--local-json", "-", "--json"])
        self.assertNotIn("--share", run.call_args.args[0])
        self.assertEqual(json.loads(run.call_args.kwargs["input"]), servers)
        with self.csvfile.open() as file:
            self.assertEqual(float(list(csv.reader(file))[1][0]), 1795575600)
        recent, _ = self.run_wrapper("recent", [])
        self.assertEqual(recent["server"], "42 Lab (LibreSpeed)")

    def test_librespeed_version_is_reported_without_legacy_probe(self):
        self.configure_librespeed()
        self.librespeed_servers.unlink()
        output, run = self.run_wrapper("version", [
            subprocess.CompletedProcess([], 0, stdout=b"librespeed-cli v1.2.1\nLicense information\n"),
        ])
        self.assertEqual(output, {"version": "librespeed", "message": "librespeed-cli v1.2.1"})
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0], [str(self.librespeed), "--version"])

    def test_librespeed_lists_local_servers_without_network(self):
        self.configure_librespeed()
        output, run = self.run_wrapper("list", [])
        self.assertEqual(output, [{"id": "42", "name": "Lab", "location": "", "country": ""}])
        run.assert_not_called()

    def test_detection_is_latency_only_and_preserves_history_and_last_test(self):
        servers = self.configure_librespeed()
        servers[0]['sponsorName'] = 'Detected sponsor'
        self.librespeed_servers.write_text(json.dumps(servers))
        self.csvfile.write_text('existing CSV history\n')
        details = Path(str(self.csvfile) + '.jsonl')
        details.write_text('existing detailed history\n')
        state = Path(str(self.csvfile) + '.state.json')
        state.write_text('{"status":"completed","server":"Last measurement"}')
        saved = {path: path.read_bytes() for path in (self.csvfile, details, state)}
        result = {'timestamp': '2026-11-25T03:00:00Z',
                  'server': {'url': servers[0]['server']}, 'client': {'ip': '2001:db8::1', 'org': 'Detected ISP'},
                  'ping': 2.5, 'jitter': 0.1}
        output, run = self.run_wrapper('detect', [
            subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())
        ], '--mode', 'both')
        self.assertEqual((output['serverid'], output['mode'], output['latency']), (42, 'latency', 2.5))
        self.assertEqual(output['sponsor'], 'Detected sponsor')
        self.assertEqual(output['connection'], {'ip': '2001:db8::1', 'isp': 'Detected ISP'})
        for flag in ('--secure', '--no-download', '--no-upload'):
            self.assertIn(flag, run.call_args.args[0])
        detection_status = self.run_wrapper('detection-status', [])[0]
        self.assertEqual(detection_status['status'], 'completed')
        self.assertEqual(detection_status['results'][0]['connection'], output['connection'])
        for path, content in saved.items():
            self.assertEqual(path.read_bytes(), content)

    def test_untrusted_or_missing_connection_metadata_is_not_displayed(self):
        servers = self.configure_librespeed()
        servers[0]['sponsorName'] = 'Bad\u202esponsor'
        self.librespeed_servers.write_text(json.dumps(servers))
        result = {'timestamp': '2026-11-25T03:00:00Z', 'server': {'url': servers[0]['server']},
                  'client': {'ip': 'not an IP', 'org': 'invalid\nISP'}, 'ping': 2.5, 'jitter': 0.1}
        output, _ = self.run_wrapper('detect', [
            subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())
        ])
        self.assertEqual(output['sponsor'], '')
        self.assertEqual(output['connection'], {'ip': '', 'isp': ''})
        result.pop('client')
        output, _ = self.run_wrapper('detect', [
            subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())
        ])
        self.assertNotIn('connection', output)

    def test_failed_detection_creates_no_history_or_measurement_state(self):
        self.configure_librespeed()
        output, _ = self.run_wrapper('detect', [
            subprocess.CompletedProcess([], 0, stdout=b'[null]')
        ])
        self.assertIn('Invalid LibreSpeed result', output['error'])
        self.assertEqual(self.run_wrapper('detection-status', [])[0]['status'], 'failed')
        self.librespeed_servers.write_text('invalid server JSON')
        output, run = self.run_wrapper('detect', [])
        self.assertIn('error', output)
        run.assert_not_called()
        self.assertEqual(self.run_wrapper('detection-status', [])[0]['status'], 'failed')
        for suffix in ('', '.jsonl', '.state.json'):
            self.assertFalse(Path(str(self.csvfile) + suffix).exists())
        with open(str(self.csvfile) + '.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            output, run = self.run_wrapper('detect', [])
            self.assertIn('already running', output['error'])
            run.assert_not_called()

    def test_librespeed_config_does_not_fall_back(self):
        servers = self.configure_librespeed()
        output, run = self.run_wrapper("7", [])
        self.assertIn("not configured", output["error"])
        run.assert_not_called()
        servers[0]["pingURL"] = "https://other.example.net/ping"
        self.librespeed_servers.write_text(json.dumps(servers))
        output, run = self.run_wrapper("0", [])
        self.assertIn("relative endpoint path", output["error"])
        run.assert_not_called()

    def test_librespeed_incomplete_test_does_not_pollute_history(self):
        servers = self.configure_librespeed()
        result = {"timestamp": "2026-11-25T03:00:00Z",
                  "server": {"url": servers[0]["server"]}, "ping": 1, "jitter": 0.5,
                  "download": 0, "upload": 100, "bytes_sent": 123456, "bytes_received": 0}
        output, _ = self.run_wrapper("0", [
            subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode()),
        ])
        self.assertIn("did not complete", output["error"])
        self.assertIn("Lab", output["error"], 'The automatically selected server must be identified on failure')
        self.assertEqual(self.run_wrapper('status', [])[0]['server'], 'Lab')
        self.assertEqual(self.run_wrapper("stat", [])[0]["samples"], 0)

    def test_librespeed_malformed_result_does_not_pollute_history(self):
        self.configure_librespeed()
        output, _ = self.run_wrapper("0", [
            subprocess.CompletedProcess([], 0, stdout=b'[null]'),
        ])
        self.assertIn("Invalid LibreSpeed result", output["error"])
        self.assertEqual(self.run_wrapper("stat", [])[0]["samples"], 0)

    def test_single_direction_measurements_do_not_enter_history(self):
        servers = self.configure_librespeed()
        for direction, counter, skipped in (("download", "bytes_received", "upload"),
                                            ("upload", "bytes_sent", "download")):
            with self.subTest(direction=direction):
                result = {"timestamp": "2026-11-25T03:00:00Z", "server": {"url": servers[0]["server"]},
                          "ping": 1, "jitter": 0, direction: 42.5, counter: 123456}
                output, run = self.run_wrapper("42", [
                    subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode()),
                ], direction)
                self.assertEqual(output[direction], 42.5)
                self.assertEqual(output[counter], 123456)
                self.assertNotIn(skipped, output)
                self.assertIn("--no-" + skipped, run.call_args.args[0])
        self.assertEqual(self.run_wrapper("stat", [])[0]["samples"], 0)

    def test_latency_only_and_advanced_options_use_engine_contract(self):
        servers = self.configure_librespeed()
        self.ca_bundle.touch()
        options = {'duration': 30, 'timeout': 15, 'concurrent': 8, 'family': 'ipv4',
                   'source': '192.0.2.10', 'http2': True, 'no_pre_allocate': True,
                   'private_ca': True, 'icmp': True, 'chunks': 200, 'upload_size': 2048}
        result = {'timestamp': '2026-11-25T03:00:00Z', 'server': {'url': servers[0]['server']},
                  'ping': 2.5, 'jitter': 1.1, 'tls': {'version': 'TLSv1.3', 'cipher': 'AES_128_GCM'}}
        output, run = self.run_wrapper("42", [
            subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())
        ], 'latency', base64.b64encode(json.dumps(options).encode()).decode())
        self.assertEqual(output['tls'], result['tls'])
        self.assertNotIn('download', output)
        self.assertNotIn('upload', output)
        command = run.call_args.args[0]
        for flag in ('--no-download', '--no-upload', '--http2', '--no-pre-allocate', '--ipv4'):
            self.assertIn(flag, command)
        self.assertNotIn('--no-icmp', command)
        self.assertEqual(command[command.index('--ca-cert') + 1], str(self.ca_bundle))
        self.assertEqual(command[command.index('--source') + 1], '192.0.2.10')
        self.assertEqual(self.run_wrapper('stat', [])[0]['samples'], 0)

    def test_first_install_measurement_options_match_native_defaults(self):
        servers = self.configure_librespeed()
        self.config_xml.unlink()
        result = {'timestamp': '2026-11-25T03:00:00Z', 'server': {'url': servers[0]['server']},
                  'ping': 2.5, 'jitter': 1.1}
        _, run = self.run_wrapper('42', [
            subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())
        ], 'latency')
        command = run.call_args.args[0]
        expected = {'duration': '10', 'timeout': '15', 'concurrent': '3',
                    'chunks': '100', 'upload_size': '1024'}
        for key, value in expected.items():
            flag = '--' + key.replace('_', '-')
            self.assertEqual(command[command.index(flag) + 1], value)
        self.assertIn('--no-icmp', command)
        self.assertNotIn('--http2', command)
        self.assertNotIn('--no-pre-allocate', command)
        self.assertNotIn('--ca-cert', command)
        import xml.etree.ElementTree as ET
        general = ET.parse(ROOT / 'src/opnsense/mvc/app/models/OPNsense/Speedtest/Speedtest.xml').find('./items/general')
        for key, value in expected.items():
            self.assertEqual(general.findtext(key + '/default'), value, 'Native model default: ' + key)

    def test_saved_native_settings_apply_to_cron_and_cli_can_override(self):
        servers = self.configure_librespeed()
        self.librespeed_servers.unlink()
        import xml.etree.ElementTree as ET
        config = ET.Element('opnsense')
        general = ET.SubElement(ET.SubElement(ET.SubElement(config, 'OPNsense'), 'speedtest'), 'general')
        ET.SubElement(general, 'servers').text = json.dumps(servers)
        ET.SubElement(general, 'duration').text = '20'
        ET.SubElement(general, 'no_pre_allocate').text = '1'
        ET.ElementTree(config).write(self.config_xml)
        result = {'timestamp': '2026-11-25T03:00:00Z', 'server': {'url': servers[0]['server']},
                  'ping': 1, 'jitter': 0}
        for args, expected in [(('latency',), '20'), (('latency', '--duration', '5'), '5'),
                               (('latency', '--pre-allocate'), '20')]:
            _, run = self.run_wrapper('42', [
                subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())
            ], *args)
            command = run.call_args.args[0]
            self.assertEqual(command[command.index('--duration') + 1], expected)
            self.assertEqual('--no-pre-allocate' in command, '--pre-allocate' not in args)

    def test_terminal_boolean_flags_override_saved_defaults(self):
        server = self.configure_librespeed()[0]
        self.ca_bundle.touch()
        self.config_xml.write_text(
            '<opnsense><OPNsense><speedtest><general><public_servers>0</public_servers>'
            '<icmp>1</icmp><http2>1</http2><no_pre_allocate>1</no_pre_allocate><private_ca>1</private_ca>'
            '</general></speedtest></OPNsense></opnsense>')
        response = subprocess.CompletedProcess([], 0, stdout=json.dumps([self.report(server)]).encode())
        output, run = self.run_wrapper('run', [response], '--server', '42', '--mode', 'latency',
                                       '--no-icmp', '--no-http2', '--pre-allocate', '--system-ca')
        self.assertTrue(all(not output['options'][key]
                            for key in ('icmp', 'http2', 'no_pre_allocate', 'private_ca')))
        command = run.call_args.args[0]
        self.assertIn('--no-icmp', command)
        for flag in ('--http2', '--no-pre-allocate', '--ca-cert'):
            self.assertNotIn(flag, command)

        output, run = self.run_wrapper('run', [response], '--server', '42', '--mode', 'latency',
                                       '--icmp', '--http2', '--no-pre-allocate', '--private-ca')
        self.assertTrue(all(output['options'][key]
                            for key in ('icmp', 'http2', 'no_pre_allocate', 'private_ca')))
        command = run.call_args.args[0]
        self.assertNotIn('--no-icmp', command)
        for flag in ('--http2', '--no-pre-allocate', '--ca-cert'):
            self.assertIn(flag, command)

    def test_invalid_settings_rejected_before_save_without_history_write(self):
        for servers in ('[{"id":1}]', 42, None, []):
            with self.subTest(servers=servers):
                payload = base64.b64encode(json.dumps({'servers': servers, 'duration': '10'}).encode()).decode()
                output, run = self.run_wrapper('check-settings', [], 'both', payload)
                self.assertIn('error', output)
                self.assertFalse(self.csvfile.exists())
                run.assert_not_called()

    def test_invalid_limits_and_source_family_fail_before_engine_execution(self):
        self.configure_librespeed()
        for options in ({'concurrent': 0}, {'duration': 31}, {'http2': 'true'},
                        {'family': 'ipv6', 'source': '192.0.2.10'}, {'unknown': 1}):
            with self.subTest(options=options):
                encoded = base64.b64encode(json.dumps(options).encode()).decode()
                output, run = self.run_wrapper('42', [], 'both', encoded)
                self.assertIn('error', output)
                run.assert_not_called()

    def test_plain_http_server_is_rejected_independently_of_admin_gui_scheme(self):
        servers = self.configure_librespeed()
        servers[0]['server'] = 'http://bench.example.net/'
        self.librespeed_servers.write_text(json.dumps(servers))
        output, run = self.run_wrapper('42', [])
        self.assertIn('HTTPS', output['error'])
        run.assert_not_called()

    def test_cli_help_and_failure_exit_code(self):
        help_result = subprocess.run([sys.executable, '-B', str(SCRIPT), '--help'],
                                     capture_output=True, text=True)
        self.assertEqual(help_result.returncode, 0)
        self.assertIn('--private-ca', help_result.stdout)
        script = Path(self.directory.name) / 'opn_speedtest.py'
        script.write_text(self.wrapper_source())
        failure = subprocess.run([sys.executable, '-B', str(script), '--cli', 'run',
                                  '--history', str(self.csvfile), '--config', str(self.librespeed_servers)],
                                 capture_output=True, text=True)
        self.assertEqual(failure.returncode, 1)
        self.assertIn('Configure', failure.stdout)

    def test_explicit_and_all_server_selection_are_mutually_exclusive(self):
        script = Path(self.directory.name) / 'opn_speedtest.py'
        script.write_text(self.wrapper_source())
        result = subprocess.run([sys.executable, '-B', str(script), '--cli', 'run',
                                 '--server', '42', '--all-servers'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('not allowed with argument', result.stderr)
        self.assertFalse(self.csvfile.exists())

    def test_server_names_cannot_inject_csv_formulas(self):
        servers = self.configure_librespeed()
        servers[0]['name'] = '=IMPORTXML("https://example.net")'
        self.librespeed_servers.write_text(json.dumps(servers))
        result = {'timestamp': '2026-11-25T03:00:00Z', 'server': {'url': servers[0]['server']},
                  'ping': 1, 'jitter': 0, 'download': 10, 'upload': 5, 'bytes_sent': 1, 'bytes_received': 1}
        self.run_wrapper('42', [subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())])
        with self.csvfile.open() as file:
            self.assertTrue(list(csv.reader(file))[1][3].startswith("'="))

    def test_invalid_mode_never_executes_the_client(self):
        self.configure_librespeed()
        output, run = self.run_wrapper("42", [], "invalid")
        self.assertIn("Invalid LibreSpeed test mode", output["error"])
        run.assert_not_called()

    def test_unconfigured_actions_report_the_config_path(self):
        for action in ("list", "", "0", "42"):
            with self.subTest(action=action):
                output, run = self.run_wrapper(action, [])
                self.assertIn(f"Configure the LibreSpeed server list at {self.librespeed_servers}", output["error"])
                if action == "list":
                    self.assertEqual(output["code"], "servers_unconfigured")
                run.assert_not_called()

    def test_public_registry_is_used_when_no_custom_list_exists(self):
        servers = [{"id": 109, "name": "Detroit", "server": "https://bench.example.net/",
                    "dlURL": "backend/garbage.php", "ulURL": "backend/empty.php",
                    "pingURL": "backend/empty.php", "getIpURL": "backend/getIP.php"}]
        self.config_xml.write_text(
            "<opnsense><OPNsense><speedtest><general><public_servers>1</public_servers>"
            "</general></speedtest></OPNsense></opnsense>"
        )

        class RegistryResponse:
            status = 200

            def __enter__(self):
                return self

            def __exit__(self, *args):
                pass

            def geturl(self):
                return "https://librespeed.org/backend-servers/servers.php"

            def read(self, limit):
                self.limit = limit
                return json.dumps(servers).encode()

        response = RegistryResponse()
        with patch("urllib.request.OpenerDirector.open", return_value=response) as fetch:
            output, run = self.run_wrapper("list", [])
        self.assertEqual(output, [{"id": "109", "name": "Detroit", "location": "", "country": ""}])
        fetch.assert_called_once_with(
            "https://librespeed.org/backend-servers/servers.php", timeout=20
        )
        self.assertEqual(response.limit, 65537)
        run.assert_not_called()

    def test_public_registry_failure_is_explicit_and_never_uses_a_fallback(self):
        self.config_xml.write_text(
            "<opnsense><OPNsense><speedtest><general><public_servers>1</public_servers>"
            "</general></speedtest></OPNsense></opnsense>"
        )
        with patch("urllib.request.OpenerDirector.open", side_effect=OSError("network unavailable")):
            output, run = self.run_wrapper("list", [])
        self.assertIn("Unable to retrieve the official LibreSpeed.org server list", output["error"])
        self.assertNotIn("code", output)
        run.assert_not_called()

    def test_custom_admin_server_file_takes_precedence_over_public_registry(self):
        self.configure_librespeed()
        with patch("urllib.request.OpenerDirector.open", side_effect=AssertionError("unexpected registry request")):
            output, run = self.run_wrapper("list", [])
        self.assertEqual(output[0]["id"], "42")
        run.assert_not_called()

    def test_public_registry_setting_can_disable_discovery(self):
        self.config_xml.write_text(
            "<opnsense><OPNsense><speedtest><general><public_servers>0</public_servers>"
            "</general></speedtest></OPNsense></opnsense>"
        )
        with patch("urllib.request.OpenerDirector.open", side_effect=AssertionError("discovery is disabled")):
            output, run = self.run_wrapper("list", [])
            catalog, _ = self.run_wrapper("public-list", [])
        self.assertEqual(output["code"], "servers_unconfigured")
        self.assertIn("discovery is disabled", catalog["error"])
        run.assert_not_called()

    def test_catalog_is_independent_of_custom_list_and_does_not_write_history(self):
        servers = self.configure_librespeed()
        official = dict(servers[0], id=109, name="Official", sponsorName="Sponsor")
        self.config_xml.write_text("<opnsense/>")
        with patch("urllib.request.OpenerDirector.open") as fetch:
            fetch.return_value.__enter__.return_value.read.return_value = json.dumps([official]).encode()
            output, run = self.run_wrapper("public-list", [])
            self.assertEqual(output, {"servers": [dict(official, id="109")]})
            official["pingURL"] = "../empty.php"
            fetch.return_value.__enter__.return_value.read.return_value = json.dumps([official]).encode()
            invalid, _ = self.run_wrapper("public-list", [])
        self.assertIn("relative endpoint path", invalid["error"])
        self.assertFalse(self.csvfile.exists())
        run.assert_not_called()

    def set_server_policy(self, selection='all', combine='0'):
        import xml.etree.ElementTree as ET
        root = ET.Element('opnsense')
        general = ET.SubElement(ET.SubElement(ET.SubElement(root, 'OPNsense'), 'speedtest'), 'general')
        for key, value in {'public_servers': '1', 'public_selection': selection, 'combine_servers': combine}.items():
            ET.SubElement(general, key).text = value
        ET.ElementTree(root).write(self.config_xml)

    def test_public_allow_list_is_applied_to_selection_and_explicit_runs(self):
        servers = self.configure_librespeed()
        self.librespeed_servers.unlink()
        self.set_server_policy('109')
        allowed = dict(servers[0], id=109, name='Allowed', server='https://allowed.example.net/')
        with patch("urllib.request.OpenerDirector.open") as fetch:
            fetch.return_value.__enter__.return_value.read.return_value = json.dumps([*servers, allowed]).encode()
            listed, _ = self.run_wrapper('list', [])
            self.assertEqual([server['id'] for server in listed], ['109'])
            rejected, run = self.run_wrapper('42', [])
        self.assertIn('not configured', rejected['error'])
        run.assert_not_called()

    def test_no_allowed_public_servers_never_falls_back_to_other_public_servers(self):
        self.set_server_policy('none')
        with patch("urllib.request.OpenerDirector.open", side_effect=AssertionError('No public request expected')):
            result, _ = self.run_wrapper('list', [])
            self.assertIn('No servers are allowed', result['error'])
        self.set_server_policy('109')
        with patch("urllib.request.OpenerDirector.open") as fetch:
            # A valid catalog without the approved ID must not permit some other server.
            servers = self.configure_librespeed()
            self.librespeed_servers.unlink()
            fetch.return_value.__enter__.return_value.read.return_value = json.dumps(servers).encode()
            result, _ = self.run_wrapper('list', [])
        self.assertIn('None of the allowed', result['error'])

    def test_custom_servers_are_combined_only_when_enabled_and_conflicts_are_rejected(self):
        servers = self.configure_librespeed()
        official = dict(servers[0], id=109, server='https://official.example.net/')
        self.set_server_policy('109')
        with patch("urllib.request.OpenerDirector.open", side_effect=AssertionError('Preserve custom-only precedence')):
            listed, _ = self.run_wrapper('list', [])
        self.assertEqual([server['id'] for server in listed], ['42'])
        self.set_server_policy('109', '1')
        with patch("urllib.request.OpenerDirector.open") as fetch:
            fetch.return_value.__enter__.return_value.read.return_value = json.dumps([official]).encode()
            listed, _ = self.run_wrapper('list', [])
            self.assertEqual([server['id'] for server in listed], ['42', '109'])
            official['server'] = servers[0]['server'] + '/'
            fetch.return_value.__enter__.return_value.read.return_value = json.dumps([official]).encode()
            rejected, _ = self.run_wrapper('list', [])
            self.assertIn('share an ID or URL', rejected['error'])
        self.set_server_policy('none', '1')
        with patch("urllib.request.OpenerDirector.open", side_effect=AssertionError('Only custom servers allowed')):
            listed, _ = self.run_wrapper('list', [])
        self.assertEqual([server['id'] for server in listed], ['42'])

    def test_public_policy_validation_rejects_malformed_and_duplicate_ids(self):
        for selection in ('', '0', '-1', '42,42', '9223372036854775808', ','.join(map(str, range(1, 52)))):
            payload = base64.b64encode(json.dumps({'public_selection': selection}).encode()).decode()
            result, _ = self.run_wrapper('check-settings', [], 'both', payload)
            self.assertIn('error', result, selection)

    def test_invalid_server_list_is_not_reported_as_unconfigured(self):
        self.librespeed_servers.write_text("{invalid")
        output, run = self.run_wrapper("list", [])
        self.assertIn("error", output)
        self.assertNotIn("code", output)
        run.assert_not_called()

    def test_missing_rust_client_reports_the_install_path(self):
        self.configure_librespeed()
        self.librespeed.unlink()
        for action in ("version", "0"):
            with self.subTest(action=action):
                output, run = self.run_wrapper(action, [])
                self.assertIn(f"Install the LibreSpeed Rust CLI at {self.librespeed}", output["error"])
                run.assert_not_called()

    def test_legacy_log_without_link(self):
        with self.csvfile.open("w") as file:
            writer = csv.writer(file)
            writer.writerow(["Timestamp", "ClientIp", "ServerId", "ServerName", "Country",
                             "DlSpeed", "UlSpeed", "Latency", "Link"])
            writer.writerow([1, "ip", 42, "name", "country", 10, 5, 2])
        output, _ = self.run_wrapper("recent", [])
        self.assertEqual(output["url"], "")

    def test_duplicate_headers_do_not_break_history(self):
        header = ["Timestamp", "ClientIp", "ServerId", "ServerName", "Country",
                  "DlSpeed", "UlSpeed", "Latency", "Link"]
        with self.csvfile.open("w") as file:
            writer = csv.writer(file)
            writer.writerow(header)
            writer.writerow([1, "ip", 42, "name", "country", 10, 5, 2, ""])
            writer.writerow(header)
        stat = self.run_wrapper("stat", [])[0]
        self.assertEqual(stat["samples"], 1)
        self.assertEqual(stat["recent"], self.run_wrapper("recent", [])[0])
        self.assertEqual(len(self.run_wrapper("log", [])[0]), 1)
        self.assertEqual(self.run_wrapper("recent", [])[0]["server"], "42 name")

    def test_empty_history(self):
        stats = self.run_wrapper("stat", [])[0]
        self.assertEqual(stats["samples"], 0)
        self.assertEqual(stats["recent"]["error"], "No speedtest results yet")
        self.assertEqual(self.run_wrapper("log", [])[0], [])
        self.assertEqual(self.run_wrapper("recent", [])[0]["error"], "No speedtest results yet")

    def test_log_keeps_newest_50_even_if_history_is_unsorted(self):
        header = ["Timestamp", "ClientIp", "ServerId", "ServerName", "Country",
                  "DlSpeed", "UlSpeed", "Latency", "Link"]
        with self.csvfile.open("w") as file:
            writer = csv.writer(file)
            writer.writerow(header)
            for value in list(range(69, -1, -1)):
                writer.writerow([value * 86400, "ip", value, "name", "country", value, value * 2, 1, ""])
        log, _ = self.run_wrapper("log", [])
        self.assertEqual([int(row[2]) for row in log], list(range(69, 19, -1)))
        stats, _ = self.run_wrapper("stat", [])
        self.assertEqual(stats["samples"], 70)
        self.assertEqual(stats["download"], {"avg": 34.5, "min": 0, "max": 69})
        self.assertEqual(stats["recent"]["server"], "69 name")
        self.assertEqual(stats["recent"], self.run_wrapper("recent", [])[0])

    def test_run_lock_rejects_concurrent_tests(self):
        with open(str(self.csvfile) + '.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            output, run = self.run_wrapper("0", [])
        self.assertEqual(output["error"], "A speedtest is already running")
        run.assert_not_called()

    def test_alternate_history_cannot_bypass_shared_run_lock(self):
        server = self.configure_librespeed()[0]
        alternate = Path(self.directory.name) / 'alternate.csv'
        response = subprocess.CompletedProcess([], 0, stdout=json.dumps([self.report(server)]).encode())
        with open(str(self.csvfile) + '.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            output, run = self.run_wrapper('run', [response], '--history', str(alternate))
            alternate.write_text('preserve history\n')
            cleared, _ = self.run_wrapper('clear', [], '--history', str(alternate))
        self.assertEqual(output['error'], 'A speedtest is already running')
        self.assertEqual(cleared['error'], 'A speedtest is already running')
        self.assertEqual(alternate.read_text(), 'preserve history\n')
        run.assert_not_called()

    def test_existing_history_remains_readable_during_a_test(self):
        self.csvfile.write_text("Timestamp,ClientIp,ServerId,ServerName,Country,DlSpeed,UlSpeed,Latency,Link\n")
        with open(str(self.csvfile) + '.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            output, run = self.run_wrapper("stat", [])
        self.assertEqual(output["samples"], 0)
        run.assert_not_called()

    def test_log_orders_absolute_timestamps_across_daylight_saving_fallback(self):
        self.csvfile.write_text(
            "Timestamp,ClientIp,ServerId,ServerName,Country,DlSpeed,UlSpeed,Latency,Link\n"
            "1793511900,,1,Earlier,,10,5,2,\n"
            "1793514600,,2,Later,,10,5,2,\n"
        )
        try:
            with patch.dict(os.environ, {'TZ': 'America/New_York'}):
                time.tzset()
                log, _ = self.run_wrapper('log', [])
                self.assertEqual([row[2] for row in log], ['2', '1'])
                self.assertGreater(log[1][0], log[0][0])
        finally:
            time.tzset()

    def test_timeout_is_reported_and_lock_released(self):
        self.configure_librespeed()
        calls = [
            subprocess.TimeoutExpired(str(self.librespeed), 100),
        ]
        output, run = self.run_wrapper("0", calls)
        self.assertEqual(output["error"], "Speedtest timed out after 100 seconds")
        self.assertEqual(run.call_args.kwargs["timeout"], 100)
        with open(str(self.csvfile) + '.lock', 'r+') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def test_clear_preserves_header_and_does_not_require_client(self):
        self.csvfile.write_text("Timestamp,ClientIp,ServerId,ServerName,Country,DlSpeed,UlSpeed,Latency,Link\n"
                                "1,ip,42,name,country,10,5,2,\n")
        detection = Path(str(self.csvfile) + '.detect.json')
        detection.write_text('{"status":"completed","results":[{"connection":{"ip":"192.0.2.9"}}]}')
        result, run = self.run_wrapper("clear", [])
        self.assertEqual(result, {"result": "ok"})
        run.assert_not_called()
        self.assertEqual(self.run_wrapper("stat", [])[0]["samples"], 0)
        self.assertEqual(len(self.csvfile.read_text().splitlines()), 1)
        self.assertFalse(detection.exists())

    def test_clear_does_not_race_running_test(self):
        original = "Timestamp,ClientIp,ServerId,ServerName,Country,DlSpeed,UlSpeed,Latency,Link\n"
        self.csvfile.write_text(original)
        with open(str(self.csvfile) + '.lock', 'w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result, _ = self.run_wrapper("clear", [])
        self.assertEqual(result["error"], "A speedtest is already running")
        self.assertEqual(self.csvfile.read_text(), original)

    def report(self, server=None, timestamp=None, **values):
        return dict(timestamp=timestamp or datetime.now(timezone.utc).isoformat(),
                    server={'url': (server or self.configure_librespeed()[0])['server']},
                    ping=2, jitter=0.5, download=100, upload=50,
                    bytes_received=1000000, bytes_sent=500000, **values)

    def query_history(self, **filters):
        payload = base64.b64encode(json.dumps(filters).encode()).decode()
        return self.run_wrapper('history', [], payload)[0]

    def test_diagnostics_and_failures_are_durable_without_changing_legacy_statistics(self):
        server = self.configure_librespeed()[0]
        result = self.report(server)
        self.run_wrapper('42', [subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())], 'download')
        self.run_wrapper('42', [subprocess.TimeoutExpired('fixture', 100)], 'upload')
        history = self.query_history()
        self.assertEqual((history['total'], history['successful'], history['failed']), (2, 1, 1))
        self.assertEqual(history['metrics']['download']['avg'], 100)
        self.assertIsNone(history['metrics']['upload']['avg'])
        self.assertEqual(history['metrics']['jitter']['avg'], 0.5)
        self.assertEqual(history['bytes_received'], 1000000)
        self.assertEqual(self.run_wrapper('stat', [])[0]['samples'], 0)
        self.assertEqual(self.query_history(status='failed')['rows'][0]['mode'], 'upload')
        self.assertEqual(self.query_history(server='42')['total'], 2)

    def test_sequential_comparison_preserves_success_when_another_server_fails(self):
        first = self.configure_librespeed()[0]
        second = dict(first, id=84, name='Second', server='https://other.example.net/')
        self.librespeed_servers.write_text(json.dumps([first, second]))
        result = self.report(first)
        output, run = self.run_wrapper('run', [
            subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode()),
            subprocess.CalledProcessError(1, 'fixture', stderr=b'endpoint unavailable'),
        ], '--server', '42', '--server', '84')
        self.assertIn('1 of 2', output['error'])
        self.assertEqual(len(output['results']), 2)
        self.assertEqual([json.loads(call.kwargs['input'])[0]['id'] for call in run.call_args_list], [42, 84])
        history = self.query_history()
        self.assertEqual(history['total'], 2, 'The CSV mirror must not duplicate enriched full tests')
        self.assertEqual(self.run_wrapper('stat', [])[0]['samples'], 1)
        self.assertEqual(self.query_history(server='84')['failed'], 1)
        self.assertEqual(self.run_wrapper('status', [])[0]['status'], 'failed')

    def test_exclusions_filter_automatic_selection_and_never_fall_back(self):
        first = self.configure_librespeed()[0]
        second = dict(first, id=84, server='https://other.example.net/')
        self.librespeed_servers.write_text(json.dumps([first, second]))
        result = self.report(second)
        output, run = self.run_wrapper('run', [
            subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())
        ], '--exclude', '42')
        self.assertEqual(output['serverid'], 84)
        self.assertEqual(json.loads(run.call_args.kwargs['input']), [second])
        for arguments in (('--exclude', '42', '--exclude', '84'), ('--server', '42', '--exclude', '84')):
            output, run = self.run_wrapper('run', [], *arguments)
            self.assertIn('error', output)
            run.assert_not_called()
        self.assertEqual(self.query_history(status='failed', server='0')['total'], 1)

    def test_legacy_records_filters_and_paginated_statistics(self):
        server = self.configure_librespeed()[0]
        for index in range(3):
            result = self.report(server, timestamp=(datetime.now(timezone.utc) - timedelta(days=index)).isoformat())
            self.run_wrapper('42', [subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())])
        with self.csvfile.open('a') as stream:
            csv.writer(stream).writerow([1, 'old-ip', 99, 'Legacy', '', 10, 5, 2, ''])
        history = self.query_history(provider='librespeed', page='2', limit='2', family='auto', origin='cli')
        self.assertEqual(history['total'], 3)
        self.assertEqual(len(history['rows']), 1)
        self.assertEqual(history['metrics']['download']['count'], 3)
        self.assertEqual(len(history['series']), 3)
        self.assertEqual(self.query_history(provider='legacy')['total'], 1)
        self.assertEqual(self.query_history(source='192.0.2.9')['total'], 0)
        self.assertIn('error', self.query_history(limit='201'))
        self.assertIn('error', self.query_history(source='not-an-ip'))

    def test_saved_unlimited_retention_is_preserved_and_limits_prune_after_a_run(self):
        server = self.configure_librespeed()[0]
        old = self.report(server, timestamp=(datetime.now(timezone.utc) - timedelta(days=400)).isoformat())
        self.run_wrapper('42', [subprocess.CompletedProcess([], 0, stdout=json.dumps([old]).encode())])
        self.assertEqual(self.query_history()['total'], 1, 'Explicit unlimited retention must be preserved')
        self.config_xml.write_text('<opnsense><OPNsense><speedtest><general><retention_days>365</retention_days>'
                                   '<history_limit>1</history_limit></general></speedtest></OPNsense></opnsense>')
        current = self.report(server)
        self.run_wrapper('42', [subprocess.CompletedProcess([], 0, stdout=json.dumps([current]).encode())])
        self.assertEqual(self.query_history()['total'], 1)
        self.assertEqual(self.run_wrapper('stat', [])[0]['samples'], 1)
        self.run_wrapper('clear', [])
        self.assertFalse(Path(str(self.csvfile) + '.jsonl').exists())
        self.assertFalse(Path(str(self.csvfile) + '.state.json').exists())

    def test_default_retention_prunes_after_31_days_in_both_formats(self):
        server = self.configure_librespeed()[0]
        self.config_xml.write_text('<opnsense><OPNsense><speedtest><general><retention_days>31</retention_days>'
                                   '<history_limit>10000</history_limit></general></speedtest></OPNsense></opnsense>')
        old = self.report(server, timestamp=(datetime.now(timezone.utc) - timedelta(days=32)).isoformat())
        recent = self.report(server, timestamp=(datetime.now(timezone.utc) - timedelta(days=30)).isoformat())
        for result in (old, recent):
            self.run_wrapper('42', [subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())])
        self.assertEqual(self.query_history()['total'], 1)
        self.assertEqual(self.run_wrapper('stat', [])[0]['samples'], 1)
        self.assertNotIn(old['timestamp'], Path(str(self.csvfile) + '.jsonl').read_text())

    def test_default_record_cap_limits_recent_history_to_10000_records(self):
        server = self.configure_librespeed()[0]
        self.config_xml.write_text('<opnsense><OPNsense><speedtest><general><retention_days>31</retention_days>'
                                   '<history_limit>10000</history_limit></general></speedtest></OPNsense></opnsense>')
        now = time.time()
        with self.csvfile.open('w') as stream:
            writer = csv.writer(stream)
            writer.writerow(['Timestamp', 'ClientIp', 'ServerId', 'ServerName', 'Country',
                             'DlSpeed', 'UlSpeed', 'Latency', 'Link'])
            for index in range(10001):
                writer.writerow([now - 10002 + index, '', 42, 'Lab', '', 10, 5, 2, ''])
        self.run_wrapper('42', [subprocess.CompletedProcess([], 0, stdout=json.dumps([self.report(server)]).encode())])
        self.assertEqual(self.query_history()['total'], 10000)
        self.assertEqual(self.run_wrapper('stat', [])[0]['samples'], 10000)
        self.assertEqual(len(Path(str(self.csvfile) + '.jsonl').read_text().splitlines()), 10000)

    def test_missing_legacy_retention_settings_preserve_old_history(self):
        server = self.configure_librespeed()[0]
        self.config_xml.write_text('<opnsense/>')
        old = self.report(server, timestamp=(datetime.now(timezone.utc) - timedelta(days=400)).isoformat())
        for result in (old, self.report(server)):
            self.run_wrapper('42', [subprocess.CompletedProcess([], 0, stdout=json.dumps([result]).encode())])
        self.assertEqual(self.query_history()['total'], 2)
        self.assertEqual(self.run_wrapper('stat', [])[0]['samples'], 2)

    def test_preflight_failures_also_prune_history(self):
        self.config_xml.write_text('<opnsense><OPNsense><speedtest><general><public_servers>0</public_servers>'
                                   '<retention_days>31</retention_days><history_limit>1</history_limit>'
                                   '</general></speedtest></OPNsense></opnsense>')
        for _ in range(2):
            result, _ = self.run_wrapper('42', [])
            self.assertIn('error', result)
        history = self.query_history()
        self.assertEqual(history['total'], 1, 'Repeated failed runs must obey the same cap as successful tests')
        self.assertEqual(history['rows'][0]['status'], 'failed')
        self.assertEqual(self.run_wrapper('status', [])[0]['status'], 'failed')

    def test_corrupt_detailed_history_is_reported_not_discarded(self):
        path = Path(str(self.csvfile) + '.jsonl')
        path.write_text('broken\n')
        self.assertIn('error', self.query_history())
        self.assertEqual(path.read_text(), 'broken\n')

    def test_status_distinguishes_active_and_interrupted_measurements(self):
        server = self.configure_librespeed()[0]
        alternate = Path(self.directory.name) / 'alternate.csv'
        path = Path(str(alternate) + '.state.json')
        Path(str(self.csvfile) + '.state.json').write_text(
            json.dumps({'status': 'running', 'run_id': 'a' * 32}))
        response = subprocess.CompletedProcess([], 0, stdout=json.dumps([self.report(server)]).encode())

        def while_running(*args, **kwargs):
            current, _ = self.run_wrapper('status', [], '--history', str(alternate))
            self.assertEqual(current['status'], 'running')
            Path(str(self.csvfile) + '.state.json').write_text(
                json.dumps({'status': 'running', 'run_id': current['run_id']}))
            self.assertEqual(self.run_wrapper('status', [])[0]['status'], 'busy')
            other, run = self.run_wrapper('run', [response])
            self.assertEqual(other['error'], 'A speedtest is already running')
            run.assert_not_called()
            return response

        self.run_wrapper('42', while_running, '--history', str(alternate))
        self.assertEqual(self.run_wrapper('status', [], '--history', str(alternate))[0]['status'], 'completed')
        path.write_text(json.dumps({'status': 'running', 'run_id': 'b' * 32}))
        status = self.run_wrapper('status', [], '--history', str(alternate))[0]
        self.assertEqual(status['status'], 'failed')
        self.assertIn('stopped', status['error'])

    def test_status_does_not_report_failure_if_a_run_just_completed(self):
        state = Path(str(self.csvfile) + '.state.json')
        state.write_text(json.dumps({'status': 'running', 'run_id': 'a' * 32}))
        Path(str(self.csvfile) + '.lock').touch()
        open_file = os.open

        def finish_before_probe(path, flags, *args, **kwargs):
            if str(path) == str(self.csvfile) + '.lock':
                state.write_text(json.dumps({'status': 'completed', 'run_id': 'a' * 32}))
            return open_file(path, flags, *args, **kwargs)

        with patch('os.open', side_effect=finish_before_probe):
            self.assertEqual(self.run_wrapper('status', [])[0]['status'], 'completed')

    def test_async_setup_errors_reach_the_matching_run_status(self):
        token = 'a' * 32
        self.run_wrapper('42', [], '--run-id', token)
        status = self.run_wrapper('status', [])[0]
        self.assertEqual((status['run_id'], status['status']), (token, 'failed'))
        self.assertIn('Configure', status['error'])
        self.assertEqual(self.query_history(status='failed')['total'], 1)

    def test_real_stream_parser_persists_progress_and_validated_results(self):
        server = self.configure_librespeed()[0]
        events = [{'event': 'phase', 'phase': 'ping'},
                  {'event': 'phase', 'phase': 'download'},
                  {'event': 'progress', 'phase': 'download', 'seconds': 1.5, 'progress': 67, 'mbps': 42.5},
                  {'event': 'phase', 'phase': 'upload'},
                  {'event': 'progress', 'phase': 'upload', 'seconds': 1, 'progress': 33, 'mbps': 0},
                  {'event': 'result', 'reports': [self.report(server)]}]
        self.librespeed.write_text('#!' + sys.executable + '\nimport sys\nsys.stdin.read()\n'
                                  + '\n'.join('print(' + repr(json.dumps(event)) + ', flush=True)' for event in events))
        snapshots = []
        replace = os.replace
        def capture(source, destination):
            if str(destination).endswith('.state.json'):
                snapshots.append(json.loads(Path(source).read_text()))
            replace(source, destination)
        with patch('os.replace', side_effect=capture):
            output, _ = self.run_wrapper('42', [], '--run-id', 'b' * 32)
        self.assertEqual(output['download'], 100)
        self.assertTrue(any(row.get('progress') == 67 and row.get('mbps') == 42.5 for row in snapshots))
        self.assertEqual(snapshots[-1]['status'], 'completed')
        self.assertEqual(snapshots[-1]['server'], 'Lab')
        self.assertEqual(snapshots[-1]['samples'], {
            'download': [{'seconds': 1.5, 'mbps': 42.5}], 'upload': [{'seconds': 1, 'mbps': 0}]})

    def test_comparison_resets_live_samples_for_each_server(self):
        servers = self.configure_librespeed()
        servers.append(dict(servers[0], id=84, name='Other', server='https://other.example.net/'))
        self.librespeed_servers.write_text(json.dumps(servers))
        self.librespeed.write_text('#!' + sys.executable + '\n'
                                  'import json,sys\n'
                                  'server=json.load(sys.stdin)[0]\n'
                                  'print(json.dumps({"event":"progress","phase":"download","seconds":1,'
                                  '"progress":50,"mbps":server["id"]}),flush=True)\n'
                                  'print(json.dumps({"event":"result","reports":[{'
                                  '"timestamp":"2026-11-25T03:00:00Z","server":{"url":server["server"]},'
                                  '"ping":1,"jitter":0,"download":100,"upload":50,'
                                  '"bytes_received":1000,"bytes_sent":500}]}),flush=True)\n')
        snapshots = []
        replace = os.replace
        def capture(source, destination):
            if str(destination).endswith('.state.json'):
                snapshots.append(json.loads(Path(source).read_text()))
            replace(source, destination)
        with patch('os.replace', side_effect=capture):
            output, _ = self.run_wrapper('42,84', [], '--run-id', 'c' * 32)
        self.assertEqual(len(output['results']), 2)
        self.assertTrue(any(row.get('phase') == 'selecting' and row.get('completed') == 1
                            and row.get('samples') == {'download': [], 'upload': []} for row in snapshots))
        self.assertEqual(snapshots[-1]['server'], 'Other')
        self.assertEqual(snapshots[-1]['samples']['download'], [{'seconds': 1, 'mbps': 84}])

    def test_invalid_stream_sample_is_reported_as_a_failed_measurement(self):
        self.configure_librespeed()
        event = {'event': 'progress', 'phase': 'download', 'seconds': -1, 'progress': 50, 'mbps': 10}
        self.librespeed.write_text('#!' + sys.executable + '\nimport sys\nsys.stdin.read()\nprint('
                                  + repr(json.dumps(event)) + ',flush=True)\n')
        output, _ = self.run_wrapper('42', [], '--run-id', 'd' * 32)
        self.assertIn('Invalid LibreSpeed progress sample', output['error'])
        self.assertEqual(self.run_wrapper('status', [])[0]['status'], 'failed')
        self.assertEqual(self.query_history(status='failed')['total'], 1)

    def test_schedule_validation_checks_server_selection_without_writing_history(self):
        self.configure_librespeed()
        for selection, valid in (('42', True), ('-1', True), ('99', False), ('42,42', False)):
            payload = base64.b64encode(json.dumps({'enabled': '1', 'server': selection, 'mode': 'both'}).encode()).decode()
            result, _ = self.run_wrapper('check-schedule', [], 'both', payload)
            self.assertEqual('error' not in result, valid)
        self.assertFalse(self.csvfile.exists())
        self.assertFalse(Path(str(self.csvfile) + '.jsonl').exists())

    def test_saved_scheduled_mode_uses_streaming_and_records_its_trigger(self):
        server = self.configure_librespeed()[0]
        self.config_xml.write_text('<opnsense><OPNsense><speedtest><schedule><enabled>1</enabled>'
                                   '<server>42</server><mode>latency</mode></schedule></speedtest></OPNsense></opnsense>')
        result = self.report(server)
        self.librespeed.write_text('#!' + sys.executable + '\nimport sys\nsys.stdin.read()\n'
                                  + 'assert "--json-stream" in sys.argv\nassert "--no-download" in sys.argv\n'
                                  + 'assert "--no-upload" in sys.argv\nprint('
                                  + repr(json.dumps({'event': 'result', 'reports': [result]})) + ')\n')
        output, run = self.run_wrapper('scheduled', [])
        self.assertEqual(output['mode'], 'latency')
        self.assertNotIn('download', output)
        self.assertEqual(self.query_history(origin='scheduled')['total'], 1)
        run.assert_not_called()

    def test_terminal_csv_has_data_rows_and_protects_formula_cells(self):
        servers = self.configure_librespeed()
        servers[0]['name'] = '=1+1'
        self.librespeed_servers.write_text(json.dumps(servers))
        output, _ = self.run_wrapper('list', [], '--format', 'csv')
        rows = list(csv.reader(io.StringIO(output)))
        self.assertEqual(rows[0], ['id', 'name', 'location', 'country'])
        self.assertEqual(rows[1][:2], ['42', "'=1+1"])

    def test_long_history_chart_is_bounded_without_truncating_statistics(self):
        with self.csvfile.open('w') as stream:
            writer = csv.writer(stream)
            writer.writerow(['Timestamp', 'ClientIp', 'ServerId', 'ServerName', 'Country',
                             'DlSpeed', 'UlSpeed', 'Latency', 'Link'])
            for index in range(1000):
                writer.writerow([index * 86400, '', 42, 'Legacy', '', 100, 50, 2, ''])
        report = self.query_history(provider='legacy')
        self.assertEqual(report['total'], 1000)
        self.assertEqual(report['metrics']['download']['count'], 1000)
        self.assertLessEqual(len(report['series']), 500)
        self.assertEqual(len(report['rows']), 50)


if __name__ == "__main__":
    unittest.main()
