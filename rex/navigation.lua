-- Load after other Rex keybinding plugins in ~/.config/rex/init.lua.
local directions = { h = "left", j = "down", k = "up", l = "right" }

local function is_nvim(process)
  return process and process.name == "nvim"
end

for key, direction in pairs(directions) do
  local target = direction
  local shortcut = "ctrl+" .. key
  for _, binding in ipairs(rex.bindings()) do
    if not binding.mode and binding.key == shortcut then
      rex.unbind(shortcut)
      break
    end
  end
  rex.bind("ctrl+" .. key, function(ctx)
    local process = rex.block.call("com.superlogical.terminal", "process", {
      session_id = ctx.session_id,
      block_id = ctx.block_id,
    })
    if process then
      if is_nvim(process.foreground) then
        return false
      end
      for _, ancestor in ipairs(process.ancestors or {}) do
        if is_nvim(ancestor) then
          return false
        end
      end
    end
    local _, err = rex.session.focus_direction({ session_id = ctx.session_id, direction = target })
    if err then
      error(err, 0)
    end
    return true
  end)
end
