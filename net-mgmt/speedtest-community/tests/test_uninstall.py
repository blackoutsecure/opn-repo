import fcntl
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
PRE_HOOK = ROOT / "+POST_DEINSTALL.pre"
HOOK = ROOT / "+POST_DEINSTALL.post"
PHP = shutil.which("php")
LOCKF = shutil.which("lockf")


@unittest.skipUnless(sys.platform.startswith("freebsd") and PHP and LOCKF,
                     "Uninstall tests require FreeBSD lockf and PHP")
class UninstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="speedtest-uninstall-test.")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = self.root / "speedtest"
        self.data.mkdir()
        self.history = self.data / "speedtest.csv"
        self.lock = self.data / "speedtest.csv.lock"
        self.history.write_text("test history\n")
        self.details = self.data / "speedtest.csv.jsonl"
        self.state = self.data / "speedtest.csv.state.json"
        self.details.write_text('{"saved":"details"}\n')
        self.state.write_text('{"status":"completed"}')
        self.lock.touch()
        self.config = self.root / "config.xml"
        self.config.write_text(
            "<opnsense><system><hostname>keep</hostname></system><OPNsense>"
            "<speedtest><general><duration>15</duration></general></speedtest>"
            "<other><value>keep</value></other><cron><jobs>"
            '<job uuid="remove"><command>speedtest run</command></job>'
            '<job uuid="remove-too"><command>speedtest run-options</command></job>'
            '<job uuid="keep-prefix"><command>speedtest-other run</command></job>'
            '<job uuid="keep"><command>other run</command></job>'
            "</jobs></cron></OPNsense></opnsense>"
        )
        self.admin = self.root / "admin"
        self.admin.mkdir()
        (self.admin / "ca.pem").write_text("administrator CA")
        (self.admin / "librespeed-servers.json").write_text("administrator servers")
        self.custom_history = self.root / "custom-history.csv"
        self.custom_history.write_text("custom history")
        self.save_log = self.root / "save.log"
        self.cron_log = self.root / "cron.log"
        self.auto_log = self.root / "auto.log"
        self.loader = self.root / "fake-loader.php"
        self.loader.write_text(
            """<?php
namespace OPNsense\\Core;
class Config {
    private static $instance;
    private $locked = false;
    private $xml;
    public static function getInstance() {
        return self::$instance ??= new self();
    }
    public function __construct() {
        $this->xml = simplexml_load_file(getenv('SPEEDTEST_TEST_CONFIG'));
        if ($this->xml === false) {
            throw new \\RuntimeException('Cannot load test configuration');
        }
    }
    public function lock() {
        $this->locked = true;
    }
    public function unlock() {
        $this->locked = false;
    }
    public function object() {
        if (!$this->locked) {
            throw new \\RuntimeException('Configuration was not locked');
        }
        return $this->xml;
    }
    public function save($revision) {
        if (!$this->locked) {
            throw new \\RuntimeException('Configuration was not locked for saving');
        }
        if (getenv('SPEEDTEST_TEST_SAVE_FAIL')) {
            throw new \\RuntimeException('Simulated config save failure');
        }
        if ($this->xml->asXML(getenv('SPEEDTEST_TEST_CONFIG')) === false ||
            file_put_contents(getenv('SPEEDTEST_TEST_SAVE_LOG'), json_encode($revision) . "\\n", FILE_APPEND) === false) {
            throw new \\RuntimeException('Cannot save test configuration');
        }
    }
}
"""
        )
        self.configctl = self.root / "configctl"
        self.configctl.write_text(
            '#!/bin/sh\n'
            'printf "%s\\n" "$*" >> "$SPEEDTEST_TEST_CRON_LOG"\n'
            'printf "%s\\n" "${SPEEDTEST_TEST_CRON_RESULT:-OK}"\n'
            '[ -z "${SPEEDTEST_TEST_CRON_FAIL:-}" ]\n'
        )
        self.configctl.chmod(0o755)
        self.env = os.environ.copy()
        self.env.pop("PKG_UPGRADE", None)
        self.env.pop("PKG_ROOTDIR", None)
        self.env.update({
            "SPEEDTEST_TEST_CONFIG": str(self.config),
            "SPEEDTEST_TEST_SAVE_LOG": str(self.save_log),
            "SPEEDTEST_TEST_CRON_LOG": str(self.cron_log),
        })
        self.hook = (
            PRE_HOOK.read_text() +
            '\nprintf "automatic hook\\n" >> ' + shlex.quote(str(self.auto_log)) + '\n' +
            HOOK.read_text()
        )
        for old, new in (
            ("data_dir=/usr/local/opnsense/scripts/OPNsense/speedtest",
             "data_dir=" + shlex.quote(str(self.data))),
            ("[ -f /conf/config.xml ]", "[ -f " + shlex.quote(str(self.config)) + " ]"),
            ("'/usr/local/opnsense/mvc/script/load_phalcon.php'", "'" + str(self.loader) + "'"),
            ("/usr/local/bin/php", shlex.quote(PHP)),
            ("/usr/bin/lockf", shlex.quote(LOCKF)),
            ("/usr/local/sbin/configctl", shlex.quote(str(self.configctl))),
            (" -t 250 ", " -t 1 "),
        ):
            self.assertIn(old, self.hook)
            self.hook = self.hook.replace(old, new, 1)

    def run_hook(self, **updates):
        env = self.env.copy()
        env.update(updates)
        return subprocess.run(["/bin/sh", "-c", self.hook], env=env, text=True,
                              capture_output=True, timeout=15)

    def test_removes_only_plugin_owned_state_and_is_idempotent(self):
        note = self.data / "administrator-note"
        note.write_text("keep")
        result = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.history.exists())
        self.assertFalse(self.lock.exists())
        self.assertFalse(self.details.exists())
        self.assertFalse(self.state.exists())
        self.assertEqual(note.read_text(), "keep")
        self.assertEqual((self.admin / "ca.pem").read_text(), "administrator CA")
        self.assertEqual((self.admin / "librespeed-servers.json").read_text(), "administrator servers")
        self.assertEqual(self.custom_history.read_text(), "custom history")
        root = ET.parse(self.config).getroot()
        self.assertIsNone(root.find("./OPNsense/speedtest"))
        self.assertEqual(root.findtext("./system/hostname"), "keep")
        self.assertEqual(root.findtext("./OPNsense/other/value"), "keep")
        self.assertEqual([job.get("uuid") for job in root.findall("./OPNsense/cron/jobs/job")],
                         ["keep-prefix", "keep"])
        self.assertEqual(self.cron_log.read_text().splitlines(), ["cron restart"])
        self.assertEqual(len(self.save_log.read_text().splitlines()), 1)
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertEqual(self.cron_log.read_text().splitlines(), ["cron restart"])
        self.assertEqual(len(self.save_log.read_text().splitlines()), 1)

    def test_upgrade_and_alternate_root_preserve_state(self):
        original = self.config.read_bytes()
        for environment in ({"PKG_UPGRADE": "1"}, {"PKG_ROOTDIR": str(self.root / "other-root")}):
            self.auto_log.unlink(missing_ok=True)
            result = self.run_hook(**environment)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.config.read_bytes(), original)
            self.assertEqual(self.history.read_text(), "test history\n")
            self.assertTrue(self.lock.exists())
            self.assertTrue(self.details.exists())
            self.assertTrue(self.state.exists())
            self.assertFalse(self.save_log.exists())
            self.assertFalse(self.cron_log.exists())
            self.assertEqual(self.auto_log.exists(), "PKG_ROOTDIR" not in environment)

    def test_busy_history_is_retained_and_cleanup_failure_is_reported(self):
        with self.lock.open("r+") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_hook()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("unable to lock or remove history", result.stderr)
            self.assertEqual(self.history.read_text(), "test history\n")
            self.assertTrue(self.lock.exists())
        result = self.run_hook()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.history.exists())
        self.assertFalse(self.lock.exists())
        self.assertEqual(self.cron_log.read_text().splitlines(), ["cron restart"])

    def test_symlink_lock_does_not_remove_history_or_target(self):
        target = self.root / "other-file"
        target.write_text("keep")
        self.lock.unlink()
        self.lock.symlink_to(target)
        result = self.run_hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unsafe history", result.stderr)
        self.assertEqual(self.history.read_text(), "test history\n")
        self.assertEqual(target.read_text(), "keep")

    def assert_inflight_command_cannot_recreate_history(self, action, pause_before="flock"):
        wrapper = self.data / "opn_speedtest.py"
        wrapper.write_text((ROOT / "src/opnsense/scripts/OPNsense/speedtest/opn_speedtest.py").read_text().replace(
            '"/usr/local/opnsense/scripts/OPNsense/speedtest/speedtest.csv"', repr(str(self.history))))
        (self.data / "administrator-note").write_text("keep directory")
        paused = self.root / "paused"
        resume = self.root / "resume"
        customization = (
            "import fcntl, os, time\n"
            "def pause():\n"
            "    open(os.environ['SPEEDTEST_TEST_PAUSED'], 'w').close()\n"
            "    while not os.path.exists(os.environ['SPEEDTEST_TEST_RESUME']):\n"
            "        time.sleep(0.01)\n"
        )
        if pause_before == "open":
            customization += (
                "_open = os.open\n"
                "def pause_before_open(path, flags, *args, **kwargs):\n"
                "    if str(path).endswith('speedtest.csv.lock'):\n"
                "        pause()\n"
                "    return _open(path, flags, *args, **kwargs)\n"
                "os.open = pause_before_open\n"
            )
        else:
            customization += (
                "_flock = fcntl.flock\n"
                "def pause_before_lock(fd, operation):\n"
                "    pause()\n"
                "    return _flock(fd, operation)\n"
                "fcntl.flock = pause_before_lock\n"
            )
        (self.root / "sitecustomize.py").write_text(customization)
        env = dict(self.env, PYTHONPATH=str(self.root), SPEEDTEST_TEST_PAUSED=str(paused),
                   SPEEDTEST_TEST_RESUME=str(resume))
        process = subprocess.Popen(
            [sys.executable, "-B", str(wrapper), action, "--history", str(self.history),
             "--cli", "--format", "json"],
            env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        try:
            deadline = time.monotonic() + 10
            while not paused.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue(paused.exists(), "Command did not attempt to acquire its history lock")
            wrapper.unlink()
            result = self.run_hook()
            self.assertEqual(result.returncode, 0, result.stderr)
            resume.touch()
            stdout, stderr = process.communicate(timeout=10)
            self.assertNotEqual(process.returncode, 0, stdout + stderr)
            self.assertIn("uninstalled", json.loads(stdout)["error"])
            self.assertFalse(self.history.exists())
        finally:
            resume.touch()
            if process.poll() is None:
                process.kill()
            process.communicate(timeout=5)

    def test_inflight_clear_cannot_recreate_uninstalled_history(self):
        self.assert_inflight_command_cannot_recreate_history("clear")

    def test_inflight_first_read_cannot_recreate_uninstalled_history(self):
        self.history.unlink()
        self.assert_inflight_command_cannot_recreate_history("stat")

    def test_inflight_command_cannot_recreate_history_after_lock_removal(self):
        self.assert_inflight_command_cannot_recreate_history("clear", pause_before="open")

    def test_config_save_and_cron_action_failures_are_reported(self):
        original = self.config.read_bytes()
        result = self.run_hook(SPEEDTEST_TEST_SAVE_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Simulated config save failure", result.stderr)
        self.assertEqual(self.config.read_bytes(), original)
        self.assertFalse(self.cron_log.exists())
        result = self.run_hook(SPEEDTEST_TEST_CRON_RESULT="Error (1)")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unable to apply the updated cron configuration: Error (1)", result.stderr)
        self.assertEqual(self.cron_log.read_text().splitlines(), ["cron restart"])

    def test_missing_configuration_is_reported(self):
        self.config.unlink()
        result = self.run_hook()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("configuration is unavailable", result.stderr)
        self.assertFalse(self.history.exists())

    @unittest.skipUnless(shutil.which("pkg") and os.geteuid() == 0,
                         "Package lifecycle test needs root and FreeBSD pkg")
    def test_pkg_forced_replacement_and_delete_in_an_isolated_root(self):
        package_root = self.root / "package-root"
        (package_root / "var/db/pkg").mkdir(parents=True)
        repos = self.root / "repos"
        repos.mkdir()
        common = [shutil.which("pkg"), "-r", str(package_root), "-R", str(repos)]

        def run(command, env=None):
            result = subprocess.run(command, env=env or self.env, text=True, capture_output=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return result

        packages = []
        for version in ("0.0", "1.0", "2.0"):
            directory = self.root / ("package-" + version)
            metadata = directory / "metadata"
            stage = directory / "stage"
            output = directory / "output"
            metadata.mkdir(parents=True)
            output.mkdir()
            (stage / "usr/local/share/speedtest-pkg-test").mkdir(parents=True)
            (stage / "usr/local/share/speedtest-pkg-test/file").write_text(version)
            (metadata / "+MANIFEST").write_text(
                f'name: "os-speedtest-pkg-test"\nversion: "{version}"\n'
                'origin: "test/os-speedtest-pkg-test"\ncomment: "test"\n'
                'maintainer: "nobody@example.test"\nwww: "https://example.test"\n'
                'prefix: "/usr/local"\n'
            )
            (metadata / "+DESC").write_text("Isolated uninstall test\n")
            (metadata / "plist").write_text("/usr/local/share/speedtest-pkg-test/file\n")
            # The 0.0 package exercises pkg's actual alternate-root environment.
            root_override = "" if version == "0.0" else "PKG_ROOTDIR=/\n"
            (metadata / "+POST_DEINSTALL").write_text("#!/bin/sh\n" + root_override + self.hook)
            run([shutil.which("pkg"), "create", "-q", "-m", str(metadata), "-r", str(stage),
                 "-p", str(metadata / "plist"), "-o", str(output)])
            packages.append(next(output.glob("*.pkg")))

        original = self.config.read_bytes()
        run(common + ["add", str(packages[0])])
        run(common + ["delete", "-fy", "os-speedtest-pkg-test"])
        self.assertEqual(self.config.read_bytes(), original)
        self.assertTrue(self.history.exists())
        self.assertFalse(self.auto_log.exists())
        run(common + ["add", str(packages[1])])
        repository = self.root / "repository"
        repository.mkdir()
        shutil.copy2(packages[2], repository)
        run([shutil.which("pkg"), "repo", "-q", str(repository)])
        (repos / "local.conf").write_text(
            f'local: {{ url: "file://{repository}", enabled: yes, signature_type: "none" }}\n'
        )
        run(common + ["update", "-f"])
        run(common + ["upgrade", "-y"])
        self.assertEqual(
            (package_root / "usr/local/share/speedtest-pkg-test/file").read_text(), "2.0"
        )
        self.assertEqual(self.config.read_bytes(), original)
        self.assertTrue(self.history.exists())
        run(common + ["add", "-f", str(packages[2])])
        self.assertEqual(self.config.read_bytes(), original)
        self.assertTrue(self.history.exists())
        preserve = dict(self.env, PKG_UPGRADE="1")
        run(common + ["delete", "-fy", "os-speedtest-pkg-test"], preserve)
        self.assertEqual(self.config.read_bytes(), original)
        self.assertTrue(self.history.exists())
        run(common + ["add", str(packages[2])])
        failure = subprocess.run(
            common + ["delete", "-fy", "os-speedtest-pkg-test"],
            env=dict(self.env, SPEEDTEST_TEST_SAVE_FAIL="1"), text=True,
            capture_output=True, timeout=90,
        )
        self.assertIn("unable to remove saved settings", failure.stdout + failure.stderr)
        self.assertEqual(self.config.read_bytes(), original)
        run(common + ["add", str(packages[2])])
        run(common + ["delete", "-fy", "os-speedtest-pkg-test"])
        self.assertIsNone(ET.parse(self.config).getroot().find("./OPNsense/speedtest"))
        self.assertFalse(self.history.exists())
        self.assertFalse(self.lock.exists())
        self.assertEqual(self.cron_log.read_text().splitlines(), ["cron restart"])


if __name__ == "__main__":
    unittest.main()
