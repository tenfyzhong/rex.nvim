local M = {}

local directions = {
  bottom = { nvim = "j", rex = "down" },
  left = { nvim = "h", rex = "left" },
  right = { nvim = "l", rex = "right" },
  top = { nvim = "k", rex = "up" },
}

local config = {
  enabled = nil,
  executable = "rex",
}

local function notify_error(message)
  vim.schedule(function()
    vim.notify("rex.nvim: " .. message, vim.log.levels.ERROR)
  end)
end

local function is_rex_session()
  if config.enabled ~= nil then
    return config.enabled
  end

  return (vim.env.REX_SESSION ~= nil and vim.env.REX_SESSION ~= "") or vim.env.TERM_PROGRAM == "rex"
end

local function select_rex_pane(flag)
  if not is_rex_session() then
    return false, "boundary"
  end

  if vim.fn.executable(config.executable) ~= 1 then
    notify_error("rex executable not found: " .. config.executable)
    return false, "error"
  end

  local command = { config.executable, "focus" }
  if vim.env.REX_SESSION and vim.env.REX_SESSION ~= "" then
    vim.list_extend(command, { "-s", vim.env.REX_SESSION })
  end
  table.insert(command, flag)
  local ok, error_message = pcall(vim.system, command, { text = true }, function(result)
    if result.code ~= 0 then
      local detail = (result.stderr or ""):gsub("%s+$", "")
      if detail == "" then
        detail = "exit code " .. result.code
      end
      notify_error("failed to select pane: " .. detail)
    end
  end)

  if not ok then
    notify_error("failed to start rex: " .. tostring(error_message))
    return false, "error"
  end

  return true, "rex"
end

function M.setup(options)
  options = options or {}

  if options.enabled ~= nil then
    assert(type(options.enabled) == "boolean", "rex.nvim: enabled must be a boolean")
    config.enabled = options.enabled
  end

  if options.executable ~= nil then
    assert(
      type(options.executable) == "string" and options.executable ~= "",
      "rex.nvim: executable must be a non-empty string"
    )
    config.executable = options.executable
  end
end

function M.move_to(direction)
  local target = directions[direction]
  assert(target ~= nil, "rex.nvim: invalid direction: " .. tostring(direction))

  local previous_window = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(target.nvim)

  if vim.api.nvim_get_current_win() ~= previous_window then
    local buffer = vim.api.nvim_get_current_buf()
    local modified = vim.api.nvim_get_option_value("modified", { buf = buffer })
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buffer })
    if not modified and buftype == "" and vim.api.nvim_buf_get_name(buffer) ~= "" then
      local view = vim.fn.winsaveview()
      vim.api.nvim_cmd({ cmd = "edit", bang = true }, {})
      vim.fn.winrestview(view)
    end
    return true, "nvim"
  end

  return select_rex_pane(target.rex)
end

function M.move_left()
  return M.move_to("left")
end

function M.move_bottom()
  return M.move_to("bottom")
end

function M.move_top()
  return M.move_to("top")
end

function M.move_right()
  return M.move_to("right")
end

return M
