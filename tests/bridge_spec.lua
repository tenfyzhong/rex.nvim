describe("Rex key routing", function()
  local old_rex, bindings, process, focused, warnings
  before_each(function()
    old_rex = _G.rex
    bindings, focused, warnings = {}, {}, {}
    process = { foreground = { name = "nvim" } }
    _G.rex = {
      bind = function(key, callback)
        bindings[key] = callback
      end,
      bindings = function()
        local result = {}
        for key in pairs(bindings) do
          table.insert(result, { key = key })
        end
        return result
      end,
      unbind = function(key)
        if not bindings[key] then
          table.insert(warnings, "nothing is bound to " .. key)
        end
        bindings[key] = nil
      end,
      block = {
        call = function()
          return process
        end,
      },
      session = {
        focus_direction = function(args)
          table.insert(focused, args)
          return {}
        end,
      },
    }
  end)
  after_each(function()
    _G.rex = old_rex
  end)
  it("loads without warnings when keys are unbound", function()
    dofile("rex/navigation.lua")
    assert.are.same({}, warnings)
  end)
  it("removes existing bindings before installing navigation callbacks", function()
    local removed = {}
    for _, key in ipairs({ "h", "j", "k", "l" }) do
      bindings["ctrl+" .. key] = function() end
    end
    local unbind = rex.unbind
    rex.unbind = function(key)
      removed[key] = true
      unbind(key)
    end
    dofile("rex/navigation.lua")
    assert.are.same({
      ["ctrl+h"] = true,
      ["ctrl+j"] = true,
      ["ctrl+k"] = true,
      ["ctrl+l"] = true,
    }, removed)
    assert.are.same({}, warnings)
  end)
  it("passes all navigation keys to Neovim", function()
    dofile("rex/navigation.lua")
    for _, key in ipairs({ "h", "j", "k", "l" }) do
      assert.is_false(bindings["ctrl+" .. key]({ session_id = "s", block_id = "b" }))
    end
    assert.are.same({}, focused)
  end)
  it("routes shell keys to directional panes", function()
    process = { foreground = { name = "fish" } }
    dofile("rex/navigation.lua")
    for _, key in ipairs({ "h", "j", "k", "l" }) do
      assert.is_true(bindings["ctrl+" .. key]({ session_id = "s", block_id = "b" }))
    end
    assert.are.same({
      { session_id = "s", direction = "left" },
      { session_id = "s", direction = "down" },
      { session_id = "s", direction = "up" },
      { session_id = "s", direction = "right" },
    }, focused)
  end)
  it("recognizes Neovim above an embedded terminal process", function()
    process = { foreground = { name = "fish" }, ancestors = { { name = "nvim" } } }
    dofile("rex/navigation.lua")
    assert.is_false(bindings["ctrl+h"]({ session_id = "s", block_id = "b" }))
  end)
  it("keeps pane navigation available for non-terminal blocks", function()
    process = nil
    dofile("rex/navigation.lua")
    assert.is_true(bindings["ctrl+h"]({ session_id = "s", block_id = "b" }))
  end)
end)
