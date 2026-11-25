from pathlib import Path
import shutil
import subprocess
import unittest


@unittest.skipUnless(shutil.which("php"), "PHP is required for isolated schedule controller tests")
class ScheduleTests(unittest.TestCase):
    def test_native_transaction_and_schedule_contract(self):
        test = Path(__file__).with_suffix(".php")
        result = subprocess.run(["php", str(test)], capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
