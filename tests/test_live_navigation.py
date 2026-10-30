"""Readiness regression tests; no Rex server or user configuration required."""
import json
import shutil
import subprocess
import unittest

import live_navigation


class MappingReadiness(unittest.TestCase):
    def check_mapping(self, setup):
        def expr(expression):
            return subprocess.check_output([
                shutil.which("nvim"), "--headless", "-u", "NONE", "-i", "NONE",
                "--cmd", "lua " + setup,
                "-c", "lua io.write(tostring(vim.fn.eval(" + json.dumps(expression) + ")))",
                "-c", "qa!",
            ], text=True, timeout=10).strip()
        return live_navigation.navigation_ready(expr)

    def test_mapping_without_description(self):
        self.assertTrue(self.check_mapping(
            'vim.keymap.set({"n", "t"}, "<C-h>", function() end)'))

    def test_mapping_with_custom_description(self):
        self.assertTrue(self.check_mapping(
            'vim.keymap.set("n", "<C-h>", function() end, {desc = "Go left"})'))

    def test_missing_mapping(self):
        self.assertFalse(self.check_mapping('vim.cmd("mapclear")'))
