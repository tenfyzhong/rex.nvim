describe("rex navigation", function()
  local current_window
  local current_buffer
  local executable
  local edit_commands
  local buftype
  local modified
  local notifications
  local originals
  local rex_commands
  local window_moves
  local events
  local restored_views
  local saved_view

  before_each(function()
    current_window = 1
    current_buffer = 1
    buftype = ""
    executable = 1
    edit_commands = {}
    events = {}
    modified = false
    notifications = {}
    restored_views = {}
    rex_commands = {}
    saved_view = { lnum = 42, col = 3, topline = 30 }
    window_moves = {}

    originals = {
      executable = vim.fn.executable,
      get_current_buf = vim.api.nvim_get_current_buf,
      buf_get_name = vim.api.nvim_buf_get_name,
      get_current_win = vim.api.nvim_get_current_win,
      nvim_cmd = vim.api.nvim_cmd,
      get_option_value = vim.api.nvim_get_option_value,
      notify = vim.notify,
      rex = vim.env.REX_SESSION,
      schedule = vim.schedule,
      system = vim.system,
      term_program = vim.env.TERM_PROGRAM,
      winrestview = vim.fn.winrestview,
      winsaveview = vim.fn.winsaveview,
      wincmd = vim.cmd.wincmd,
    }

    vim.env.REX_SESSION = "test-session"
    vim.env.TERM_PROGRAM = "rex"
    vim.api.nvim_get_current_win = function()
      return current_window
    end
    vim.api.nvim_buf_get_name = function()
      return "/tmp/example.txt"
    end
    vim.api.nvim_get_current_buf = function()
      return current_buffer
    end
    vim.api.nvim_cmd = function(command)
      table.insert(edit_commands, command)
      table.insert(events, "edit")
    end
    vim.api.nvim_get_option_value = function(option, options)
      assert.are.equal(current_buffer, options.buf)
      if option == "modified" then
        return modified
      end
      return buftype
    end
    vim.cmd.wincmd = function(key)
      table.insert(window_moves, key)
    end
    vim.fn.executable = function()
      return executable
    end
    vim.fn.winrestview = function(view)
      table.insert(events, "restore")
      table.insert(restored_views, view)
    end
    vim.fn.winsaveview = function()
      table.insert(events, "save")
      return saved_view
    end
    vim.notify = function(message, level)
      table.insert(notifications, { message = message, level = level })
    end
    vim.schedule = function(callback)
      callback()
    end
    vim.system = function(command, _, callback)
      table.insert(rex_commands, command)
      callback({ code = 0, stderr = "" })
    end

    package.loaded.rex = nil
    package.loaded["rex.config"] = nil
  end)

  after_each(function()
    vim.env.REX_SESSION = originals.rex
    vim.env.TERM_PROGRAM = originals.term_program
    vim.api.nvim_buf_get_name = originals.buf_get_name
    vim.api.nvim_get_current_buf = originals.get_current_buf
    vim.api.nvim_get_current_win = originals.get_current_win
    vim.api.nvim_cmd = originals.nvim_cmd
    vim.api.nvim_get_option_value = originals.get_option_value
    vim.cmd.wincmd = originals.wincmd
    vim.fn.executable = originals.executable
    vim.fn.winrestview = originals.winrestview
    vim.fn.winsaveview = originals.winsaveview
    vim.notify = originals.notify
    vim.schedule = originals.schedule
    vim.system = originals.system
  end)

  it("moves inside Neovim before using rex", function()
    vim.cmd.wincmd = function(key)
      table.insert(window_moves, key)
      current_window = 2
    end

    local rex = require("rex")
    local moved, destination = rex.move_left()

    assert.is_true(moved)
    assert.are.equal("nvim", destination)
    assert.are.same({ "h" }, window_moves)
    assert.are.same({
      { cmd = "edit", bang = true },
    }, edit_commands)
    assert.are.same({}, rex_commands)
  end)

  it("restores the last position after refreshing a Neovim buffer", function()
    vim.cmd.wincmd = function(key)
      table.insert(window_moves, key)
      current_window = 2
    end

    local rex = require("rex")
    local moved, destination = rex.move_left()

    assert.is_true(moved)
    assert.are.equal("nvim", destination)
    assert.are.same({ "h" }, window_moves)
    assert.are.same({
      { cmd = "edit", bang = true },
    }, edit_commands)
    assert.are.same({ saved_view }, restored_views)
    assert.are.same({ "save", "edit", "restore" }, events)
    assert.are.same({}, rex_commands)
  end)

  it("does not refresh a non-file Neovim buffer", function()
    buftype = "nofile"
    vim.cmd.wincmd = function(key)
      table.insert(window_moves, key)
      current_window = 2
    end

    local rex = require("rex")
    local moved, destination = rex.move_right()

    assert.is_true(moved)
    assert.are.equal("nvim", destination)
    assert.are.same({ "l" }, window_moves)
    assert.are.same({}, edit_commands)
    assert.are.same({}, events)
    assert.are.same({}, rex_commands)
  end)

  it("moves to an rex pane at a Neovim boundary", function()
    local rex = require("rex")
    local moved, destination = rex.move_bottom()

    assert.is_true(moved)
    assert.are.equal("rex", destination)
    assert.are.same({ "j" }, window_moves)
    assert.are.same({}, edit_commands)
    assert.are.same({
      { "rex", "focus", "-s", "test-session", "down" },
    }, rex_commands)
  end)

  it("does not refresh a modified Neovim buffer", function()
    modified = true
    vim.cmd.wincmd = function(key)
      table.insert(window_moves, key)
      current_window = 2
    end

    local rex = require("rex")
    local moved, destination = rex.move_right()

    assert.is_true(moved)
    assert.are.equal("nvim", destination)
    assert.are.same({ "l" }, window_moves)
    assert.are.same({}, edit_commands)
    assert.are.same({}, rex_commands)
  end)

  it("maps all public directions", function()
    local rex = require("rex")

    rex.move_left()
    rex.move_bottom()
    rex.move_top()
    rex.move_right()

    assert.are.same({ "h", "j", "k", "l" }, window_moves)
    assert.are.same({
      { "rex", "focus", "-s", "test-session", "left" },
      { "rex", "focus", "-s", "test-session", "down" },
      { "rex", "focus", "-s", "test-session", "up" },
      { "rex", "focus", "-s", "test-session", "right" },
    }, rex_commands)
  end)

  it("does not start rex outside an rex session", function()
    vim.env.REX_SESSION = nil
    vim.env.TERM_PROGRAM = "ghostty"

    local rex = require("rex")
    local moved, destination = rex.move_right()

    assert.is_false(moved)
    assert.are.equal("boundary", destination)
    assert.are.same({}, rex_commands)
  end)

  it("reports a missing rex executable", function()
    executable = 0

    local rex = require("rex")
    local moved, destination = rex.move_top()

    assert.is_false(moved)
    assert.are.equal("error", destination)
    assert.are.equal(1, #notifications)
    assert.matches("rex executable", notifications[1].message)
    assert.are.equal(vim.log.levels.ERROR, notifications[1].level)
  end)

  it("reports an rex command failure without stderr", function()
    vim.system = function(command, _, callback)
      table.insert(rex_commands, command)
      callback({ code = 1 })
    end

    local rex = require("rex")
    rex.move_left()

    assert.are.equal(1, #notifications)
    assert.matches("failed to select pane: exit code 1", notifications[1].message)
  end)

  it("can be explicitly disabled", function()
    local rex = require("rex")
    rex.setup({ enabled = false })
    local moved, destination = rex.move_top()

    assert.is_false(moved)
    assert.are.equal("boundary", destination)
    assert.are.same({}, rex_commands)
  end)

  it("accepts a custom executable and forced detection", function()
    vim.env.REX_SESSION = "test-session"
    vim.env.TERM_PROGRAM = "ghostty"

    local rex = require("rex")
    rex.setup({
      executable = "/opt/rex/bin/rex",
      enabled = true,
    })
    rex.move_to("right")

    assert.are.same({
      { "/opt/rex/bin/rex", "focus", "-s", "test-session", "right" },
    }, rex_commands)
  end)

  it("rejects unknown directions", function()
    local rex = require("rex")

    assert.has_error(function()
      rex.move_to("diagonal")
    end, "rex.nvim: invalid direction: diagonal")
  end)
end)
