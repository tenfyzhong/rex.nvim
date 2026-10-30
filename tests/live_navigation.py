"""Opt-in acceptance test against installed Neovim and Rex configurations.

REX_EXECUTABLE=/path/to/rex python3 -m unittest discover -s tests -p 'live_*.py' -v
Creates and removes only its own Rex session. Requires the README setup.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


def navigation_ready(expr):
    return expr('!empty(maparg("<C-h>", "n", 0, 1))') == "1"


class LiveNavigation(unittest.TestCase):
    def test_window_and_pane_navigation(self):
        rex = os.environ.get("REX_EXECUTABLE") or shutil.which("rex")
        if not rex:
            self.skipTest("Set REX_EXECUTABLE or install rex on PATH")
        nvim = shutil.which("nvim")
        root = str(Path(__file__).resolve().parents[1])

        def cli(*args):
            return subprocess.check_output([rex, *args], text=True)

        with tempfile.TemporaryDirectory(prefix="rex-nvim-") as temp:
            socket = temp + "/nvim.sock"
            result = json.loads(cli("new", "rex-nvim-test", "--json", "-c", root,
                                    "--", nvim, "--listen", socket, "README.md"))
            session = result["session_id"]
            editor = result["initial_windows"][0]["block_ids"][0]
            try:
                def expr(value):
                    return subprocess.check_output(
                        [nvim, "--server", socket, "--remote-expr", value], text=True).strip()

                def wait_for(check):
                    for _ in range(100):
                        if check():
                            return
                        time.sleep(0.05)
                    self.fail("Timed out waiting for navigation")

                wait_for(lambda: Path(socket).exists())
                wait_for(lambda: navigation_ready(expr))
                pane = json.loads(cli("split", "-s", session, "-b", editor,
                                      "--split", "right", "--focus=false", "--json"))["block_ids"][0]

                def focus():
                    state = json.loads(cli("session", "inspect", session, "--json"))
                    return next(w["focused_block_id"] for w in state["windows"]
                                if w["window_id"] == state["active_window_id"])

                def key(letter):
                    # Unlike send-key, client.key exercises the installed Lua routing.
                    cli("do", "-s", session, "-e", '''
local _, err = rex.session.attach({})
if err then error(err) end
local result, err = rex.call("client.key", {
  session_id = rex.session_id,
  key = { key = "key_%s", mods = "ctrl", consumed_mods = "", text = "",
          unshifted_codepoint = %d, composing = false, action = "press" }
})
if err then error(err) end
return result
''' % (letter, ord(letter)))

                expr('execute("vsplit | wincmd h")')
                cli("focus", "-s", session, editor)
                key("l")
                wait_for(lambda: expr("winnr()") == "2")
                self.assertEqual(focus(), editor)
                key("l")
                wait_for(lambda: focus() == pane)
                key("h")
                wait_for(lambda: focus() == editor)
                key("h")
                wait_for(lambda: expr("winnr()") == "1")
                expr('execute("only | split | wincmd k")')
                key("j")
                wait_for(lambda: expr("winnr()") == "2")
                key("k")
                wait_for(lambda: expr("winnr()") == "1")
                expr('execute("wincmd j | terminal")')
                expr('execute("startinsert")')
                wait_for(lambda: expr("mode()") == "t")
                key("k")
                wait_for(lambda: expr("winnr()") == "1")
            finally:
                cli("kill", session)
