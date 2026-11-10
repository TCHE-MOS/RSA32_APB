#!/usr/bin/env python3
"""Regression checks for watchdog limits; no simulator/license required."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).with_name('uvm_campaign_timing.py')


class CampaignTimingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.header = Path(self.temp.name) / 'top_tb_pkg.svh'
        self.header.write_text('''
parameter integer CLOCK_PERIOD_NS = 10;
parameter integer ADDR_WIDTH = 12;
parameter integer XZ_VALUES_PATTERN_COUNT = 8;
parameter integer CORNERS_CASES_EXP_4 = 5;
parameter integer CORNERS_CASES_EXP_8 = 5;
parameter integer CORNERS_CASES_EXP_12 = 0;
parameter integer CORNERS_CASES_EXP_16 = 1;
parameter integer CORNERS_CASES_EXP_32 = 1;
''')

    def calculate(self, limit='auto', simulator='xcelium', args=(), fails=False):
        result = subprocess.run(
            [sys.executable, '-I', str(SCRIPT), limit, str(self.header), simulator] + list(args),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        if fails:
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('limite seguro', result.stderr)
            self.assertEqual(result.stdout, '')
            return
        self.assertEqual(result.returncode, 0, result.stderr)
        fields = result.stdout.split()
        self.assertEqual(len(fields), 9)
        return fields, result.stderr

    def test_long_xcelium_campaign_keeps_cases_and_caps_watchdog(self):
        values, warning = self.calculate()
        self.assertEqual(values[0], '9200000000000ns')
        self.assertEqual(int(values[1]), 9_000_000_000_000)
        self.assertEqual(int(values[3]), 12)
        self.assertGreater(int(values[8]), int(values[1]))
        self.assertIn('sera reportada como falha', warning)

    def test_xezim_does_not_inherit_xcelium_limit(self):
        values, warning = self.calculate(simulator='xezim')
        self.assertEqual(values[1], values[8])
        self.assertGreater(int(values[1]), 9_200_000_000_000)
        self.assertEqual(warning, '')

    def test_explicit_overflow_is_rejected(self):
        self.calculate(args=['+UVM_TIMEOUT=13744132099590,YES'], fails=True)

    def test_external_overflow_is_rejected(self):
        self.calculate(limit='10000s', fails=True)

    def test_short_external_limit(self):
        values, _ = self.calculate(limit='1ms')
        self.assertEqual(int(values[1]), 900_000)

    def test_explicit_timeout_is_preserved(self):
        values, _ = self.calculate(args=['+UVM_TIMEOUT=123456,NO'])
        self.assertEqual(values[1:3], ['123456', '0'])

    def test_focused_test_keeps_original_budget(self):
        values, warning = self.calculate(args=['+TEST_ID_ONLY=1'])
        self.assertEqual(values[0:3], ['1375220ns', '1250200', '1'])
        self.assertEqual(warning, '')

    def test_disabled_timeout_is_preserved(self):
        values, _ = self.calculate(args=['+UVM_TIMEOUT=0,YES'])
        self.assertEqual(values[1:3], ['0', '0'])


if __name__ == '__main__':
    unittest.main()
