# rex.nvim

Navigate Neovim windows and Rex panes with Ctrl-h/j/k/l. Requires Neovim 0.10+
(`vim.system`) and a Rex version with `rex focus` and Lua function keybindings.

Navigation first tries the corresponding Neovim window. At the edge it runs
`rex focus -s "$REX_SESSION" DIRECTION` asynchronously, without wrapping.
Outside Rex it only navigates Neovim. Like rmux.nvim, entering an unmodified
file buffer reloads it while preserving its view; modified, unnamed, and special buffers
are left alone.

## Neovim configuration (lazy.nvim)

```lua
return {
  "tenfyzhong/rex.nvim",
  cond = function()
    return (vim.env.REX_SESSION ~= nil and vim.env.REX_SESSION ~= "")
      or vim.env.TERM_PROGRAM == "rex"
  end,
  opts = {},
  keys = {
    { "<C-h>", function() require("rex").move_left() end, mode = { "n", "t" } },
    { "<C-j>", function() require("rex").move_bottom() end, mode = { "n", "t" } },
    { "<C-k>", function() require("rex").move_top() end, mode = { "n", "t" } },
    { "<C-l>", function() require("rex").move_right() end, mode = { "n", "t" } },
  },
}
```

Disable conflicting navigation plugins (such as rmux.nvim) inside Rex. The
plugin does not install mappings itself. Normal and terminal modes are shown;
insert mode keeps its usual editing keys.

`setup` accepts `executable` (default `"rex"`) and `enabled` (automatic detection
by default, or a boolean override). If Rex is not in PATH, set `executable` to
its full path. For Rex Beta on macOS this is commonly
`/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex`.

The public functions are `move_left`, `move_bottom`, `move_top`, `move_right`,
and `move_to("left" | "bottom" | "top" | "right")`. They return a boolean and
`"nvim"`, `"rex"`, `"boundary"`, or `"error"`. `"rex"` means the command was
started; asynchronous failures are reported with `vim.notify`.

## Rex configuration

Rex must pass the keys to Neovim instead of intercepting them. Load the supplied
bridge **after** your other Rex keybindings in `~/.config/rex/init.lua`:

```lua
dofile(os.getenv("HOME") .. "/.config/nvim/lua/dev/rex.nvim/rex/navigation.lua")
```

Adjust the path to your plugin checkout, then run `rex config check` and
`rex config reload`. The bridge passes keys to a foreground `nvim`, including
an embedded terminal with a Neovim ancestor. Other panes use directional Rex
focus. It relies on Rex's process inspection; remote SSH editors require
integration on the remote Rex server. Explicit client shortcuts or key modes
can override these bindings.

## Tests

Install `nvim-lua/plenary.nvim` at `~/.local/share/nvim/lazy/plenary.nvim`, then
run `make test`. Tests cover navigation, buffer preservation, session detection,
command failures, and Rex-side key routing. GitHub Actions runs the same suite.

For live acceptance against your installed configurations, run:

```sh
REX_EXECUTABLE=/path/to/rex python3 -m unittest discover -s tests -p 'live_*.py' -v
```

This creates an isolated session, checks Neovim splits, terminal mode, and
round-trip pane navigation through Rex key routing, then removes the session.
