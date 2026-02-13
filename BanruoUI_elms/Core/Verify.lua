-- Bre/Core/Verify.lua
-- Step6: Isolation verification helpers (no UI requirement)

local addonName, Bre = ...
Bre = Bre or {}

Bre.Verify = Bre.Verify or {}
local V = Bre.Verify

local Gate = Bre.Gate
local Modules = Bre.Modules

local function _print(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffBre|r: " .. tostring(msg))
  end
end

local function _call(iface, fn, ...)
  local o = Gate:Get(iface)
  local f = o and o[fn]
  if type(f) ~= "function" then return true end
  return pcall(f, o, ...)
end

local function _get(iface, key)
  local o = Gate:Get(iface)
  local v = o and o[key]
  if type(v) == "function" then
    local ok, r = pcall(v, o)
    return ok, r
  end
  return true, v
end

local function _smoke()
  -- Keep this VERY light: only touch stable entrypoints.
  _call("DB", "InitSaved")
  _get("API_Data", "GetTreeWidth")
  _call("TreeIndex", "Build")
  _call("UIBindings", "ListRoots")
  _call("Skin", "GetActive")
  -- Move/UI are intentionally not forced here; they can be fully disabled.
end

-- Run isolation test: disable one module at a time (non-persistent), do smoke calls, then restore state.
function V:RunIsolation()
  if not Modules or not Modules.IsEnabled or not Modules.SetEnabled then
    _print("Verify: Modules manager missing")
    return
  end

  local listL1 = { "Move", "Skin", "TreeIndex", "API_Data", "UIBindings" }
  local listL2 = { "UI", "TreePanel_Resize" }

  local function testOne(id)
    local before = Modules:IsEnabled(id)
    Modules:SetEnabled(id, false, false) -- do not persist
    _print("Verify: disabled " .. id)

    local ok, err = pcall(_smoke)
    if ok then
      _print("Verify: PASS " .. id)
    else
      _print("Verify: FAIL " .. id .. " -> " .. tostring(err))
    end

    Modules:SetEnabled(id, before, false)
    _print("Verify: restored " .. id .. " = " .. tostring(before))
  end

  _print("Verify: start isolation")
  for _, id in ipairs(listL1) do testOne(id) end
  for _, id in ipairs(listL2) do testOne(id) end
  _print("Verify: done")
end

return V
