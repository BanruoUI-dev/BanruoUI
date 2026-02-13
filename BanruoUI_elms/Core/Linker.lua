--[[
  ✅ ARCH CONSOLIDATION (Step6)
  Responsibility:
  - Linker: wiring helpers that connect modules/providers to the system.
  - Should not be a runtime dependency surface for UI/L2 (use Gate + Registry).
  Notes:
  - Step6 adds boundary markers only (no behavior changes).
]]

-- Bre/Core/Linker.lua
-- Linker = resolves Registry declarations and injects implementations into Gate.
-- In v2.9.1 we only provide the safe skeleton; modules are not yet migrated to Gate calls.

local addonName, Bre = ...
Bre = Bre or {}

Bre.Linker = Bre.Linker or {
  version = "2.9.32",
  enabled = {}, -- moduleId -> bool
}

local Linker = Bre.Linker
local Registry = Bre.Registry
local Gate = Bre.Gate

local function _log(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffBre|r: " .. tostring(msg))
  end
end


local function _loadSavedFlags()
  _G.BreSaved = _G.BreSaved or {}
  _G.BreSaved.modules = _G.BreSaved.modules or {}
  return _G.BreSaved.modules
end

local function _mkctx()
  return {
    get = function(_, iface) return Gate:Get(iface) end,
    has = function(_, iface) return Gate:Has(iface) end,
    log = function(_, level, ...) _log(table.concat({tostring(level), ...}, " ")) end,
    env = { addonName = addonName, version = (Bre.Const and Bre.Const.VERSION) or "" },
  }
end

-- Declare stubs based on registry defaults
function Linker:InitStubs()
  if type(Registry) ~= "table" or type(Registry.modules) ~= "table" then return end
  for id, spec in pairs(Registry.modules) do
    if type(spec.defaults) == "table" then
      for _, d in ipairs(spec.defaults) do
        if d and d.iface then
          Gate:RegisterStub(d.iface, d.stub, { owner = id, policy = d.policy })
        end
      end
    end
  end
end

-- Enable a module (inject its iface into Gate)
function Linker:Enable(id)
  local spec = Registry and Registry:Get(id)
  if not spec then
    return false
  end
  Linker.enabled[id] = true

  if type(spec.init) == "function" then
    local ok, iface = pcall(spec.init, _mkctx())
    if ok and type(iface) == "table" then
      -- If spec.exports is empty, default to module id as iface name
      local exports = (type(spec.exports) == "table" and spec.exports) or { id }
      if #exports == 0 then exports = { id } end
      for _, name in ipairs(exports) do
        if type(name) == "string" and name ~= "" then
          Gate:Set(name, iface, { owner = id })
        end
      end
      return true
    end
  end

  -- No init provided yet; treated as enabled but not injected
  return true
end

function Linker:Disable(id)
  local spec = Registry and Registry:Get(id)
  if not spec then return false end
  Linker.enabled[id] = false

  -- clear exports
  local exports = (type(spec.exports) == "table" and spec.exports) or { id }
  if #exports == 0 then exports = { id } end
  for _, name in ipairs(exports) do
    if type(name) == "string" and name ~= "" then
      Gate:Clear(name)
    end
  end

  if type(spec.shutdown) == "function" then
    pcall(spec.shutdown, _mkctx())
  end
  return true
end

-- Bulk operations
function Linker:EnableLayer(layer)
  local ids = Registry and Registry.layers and Registry.layers[layer]
  if type(ids) ~= "table" then return end
  for _, id in ipairs(ids) do Linker:Enable(id) end
end

function Linker:DisableLayer(layer)
  local ids = Registry and Registry.layers and Registry.layers[layer]
  if type(ids) ~= "table" then return end
  for _, id in ipairs(ids) do Linker:Disable(id) end
end

-- Initialize skeleton (safe no-op)
function Linker:Bootstrap()
  Linker:InitStubs()

  local saved = _loadSavedFlags()
  if type(Registry) ~= "table" or type(Registry.modules) ~= "table" then return end
  for id, _ in pairs(Registry.modules) do
    if saved[id] == false then
      Linker.enabled[id] = false
    elseif Linker.enabled[id] == nil then
      Linker.enabled[id] = true
    end
  end

  -- Step4: resolve and inject implementations in stable layer order.
  -- Note: actual migration to Gate calls is incremental; this only makes
  -- enable/disable effective at the interface boundary.
  if Registry.layers and Gate then
    for _, layer in ipairs({"L0", "L1", "L2"}) do
      local ids = Registry.layers[layer]
      if type(ids) == "table" then
        for _, id in ipairs(ids) do
          if Linker.enabled[id] ~= false then
            pcall(function() Linker:Enable(id) end)
          else
            pcall(function() Linker:Disable(id) end)
          end
        end
      end
    end
  end
end
