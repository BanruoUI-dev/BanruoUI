--[[
  ✅ ARCH CONSOLIDATION (Step6)
  Responsibility:
  - ModuleManager: module lifecycle orchestration (init/enable/disable), registry wiring.
  - Should NOT be used as a cross-module call surface (use Gate).
  Notes:
  - Step6 adds boundary markers only (no behavior changes).
]]

-- Bre/Core/ModuleManager.lua
-- Step3: 模块级总开关（Module Manager）
-- 统一启停入口：Registry/Linker/Gate

local addonName, Bre = ...
Bre = Bre or {}

Bre.Modules = Bre.Modules or {}
local Modules = Bre.Modules

local Linker = Bre.Linker

local function ResolveId(id)
  if type(id) ~= 'string' or id == '' then return nil end
  -- Exact match first
  if Bre.Registry and Bre.Registry.Get and Bre.Registry:Get(id) then
    return id
  end
  -- Case-insensitive fallback for slash commands
  local reg = Bre.Registry
  if reg and type(reg.modules) == 'table' then
    local low = id:lower()
    for k,_ in pairs(reg.modules) do
      if type(k) == 'string' and k:lower() == low then
        return k
      end
    end
  end
  return id
end

local function EnsureSaved()
  _G.BreSaved = _G.BreSaved or {}
  _G.BreSaved.modules = _G.BreSaved.modules or {}
  return _G.BreSaved.modules
end

function Modules:IsEnabled(id)
  id = ResolveId(id)
  if type(id) ~= 'string' or id == '' then return false end
  if Linker and type(Linker.enabled) == 'table' and Linker.enabled[id] ~= nil then
    return Linker.enabled[id] and true or false
  end
  local m = EnsureSaved()
  if m[id] == nil then return true end
  return m[id] and true or false
end

function Modules:SetEnabled(id, enabled, persist)
  id = ResolveId(id)
  if type(id) ~= 'string' or id == '' then return false end
  enabled = not not enabled
  if persist ~= false then
    local m = EnsureSaved()
    m[id] = enabled
  end
  if Linker then
    local ok
    if enabled then
      ok = Linker:Enable(id)
    else
      ok = Linker:Disable(id)
    end

    -- If UI is open, hard-rebuild tree so Gate-stub/real switches take effect immediately (e.g. TreeIndex fixture).
    pcall(function()
      local Gate = Bre.Gate
--[[
  ⚠️ ARCH NOTE (Step7)
  Cached module reference detected at file scope:
    local UI = Gate:Get("UI")
  Policy:
  - Avoid caching real module refs at load time.
  - Prefer resolving via Gate:Get(...) at call time or rely on Gate proxy.
  - Step7 does NOT change behavior; this is a guidance marker.
]]
      local UI = Gate:Get("UI")
      if UI and UI.frame then
        if UI._RebuildIndexAndRefresh then
          UI:_RebuildIndexAndRefresh()
        elseif UI.RefreshTree then
          -- best-effort fallback
          if Gate and Gate.Get then
            local TI = Gate:Get("TreeIndex")
            if TI and TI.Build then pcall(function() TI:Build() end) end
          end
          UI:RefreshTree()
          if UI.RefreshRight then UI:RefreshRight() end
        end
      end
    end)

    return ok
  end
  return false
end

function Modules:Enable(id)
  return Modules:SetEnabled(id, true, true)
end

function Modules:Disable(id)
  return Modules:SetEnabled(id, false, true)
end

function Modules:LoadOptions()
  if C_AddOns and C_AddOns.LoadAddOn then
    pcall(function() C_AddOns.LoadAddOn('BreOptions') end)
  elseif LoadAddOn then
    pcall(function() LoadAddOn('BreOptions') end)
  end
end
