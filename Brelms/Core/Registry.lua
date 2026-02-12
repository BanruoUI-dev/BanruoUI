--[[
  ✅ ARCH CONSISTENCY (Step7)
  Registry is the SINGLE source of truth for module discovery.
  Policy:
  - Do NOT cache "real module" tables outside Core/L1 unless obtained via Gate:Get (proxy-safe).
  - UI/L2 must rely on Gate:Get(<ModuleId>) and treat returned value as the only contract surface.
  - No soft-bypass via Bre.<Module> direct references.
  Notes:
  - Step7 aims to align mindset and reduce future bypass risk.
  - No behavior changes in Step7.
]]

-- Bre/Core/Registry.lua
-- Central module registry (declarations only). Runtime linking is handled by Core/Linker.lua.

local addonName, Bre = ...
Bre = Bre or {}

Bre.Registry = Bre.Registry or {
  version = "2.13.11",
  modules = {},
  layers = { L0 = {}, L1 = {}, L2 = {} },
}

local Registry = Bre.Registry

local function _assert(cond, msg)
  if not cond then error("Bre.Registry: " .. tostring(msg), 2) end
end

-- v2.9.7: Move stub policy: Move off => no mover body, no move entry.
local function _hideMoverBody()
  local f = _G.BrelmsMoverBody
  if f and type(f.Hide) == "function" then
    pcall(function() f:Hide() end)
  end
end

local function _MoveStub()
  return {
    -- Keep selection sync safe: do NOT show mover body when Move is disabled.
    ShowForElement = function() _hideMoverBody() end,
    Hide = function() _hideMoverBody() end,
  }
end

local function _ViewStub()
  return {
    GetState = function() return 2 end, -- treat as shown when ViewService is disabled
    Toggle = function() end,
    GetNodePreview = function() return { kind = 'none' } end,
    RegisterPreviewProvider = function() end,
    UnregisterPreviewProvider = function() end,


  }
end

local function _LoadStateStub()
  return {
    -- Conservative default: treat as Standby (loadable) when service is disabled.
    GetTri = function() return false end,
    IsHardUnloaded = function() return false end,
  }
end

local _TreeIndexStub = {
  -- Safe empty tree; used when TreeIndex is disabled.
  Build = function() return { parentMap = {}, childrenMap = {}, roots = {} } end,
}


-- ModuleSpec fields (declaration):
-- id, layer(L0|L1|L2), desc,
-- exports{ifaceName,...}, requires{{iface=..., optional=bool},...},
-- defaults{{iface=..., policy=...},...},
-- init(ctx)->ifaceTable, shutdown(ctx), health(ctx)->ok,msg
function Registry:Register(spec)
  _assert(type(spec) == "table", "spec must be a table")
  _assert(type(spec.id) == "string" and spec.id ~= "", "spec.id required")
  _assert(spec.layer == "L0" or spec.layer == "L1" or spec.layer == "L2", "spec.layer must be L0/L1/L2")

  -- shallow copy to avoid accidental external mutation
  local s = {}
  for k, v in pairs(spec) do s[k] = v end

  Registry.modules[s.id] = s
  Registry.layers[s.layer] = Registry.layers[s.layer] or {}

  -- keep insertion order stable
  local layerList = Registry.layers[s.layer]
  layerList[#layerList + 1] = s.id

  return s
end

function Registry:Get(id)
  return Registry.modules[id]
end

function Registry:List(layer)
  if layer then return Registry.layers[layer] or {} end
  local out = {}
  for id in pairs(Registry.modules) do out[#out + 1] = id end
  table.sort(out)
  return out
end

-- helper: normalize requires list
function Registry:Requires(id)
  local s = Registry.modules[id]
  if not s or type(s.requires) ~= "table" then return {} end
  return s.requires
end

-- helper: normalize exports list
function Registry:Exports(id)
  local s = Registry.modules[id]
  if not s or type(s.exports) ~= "table" then return {} end
  return s.exports
end

-- -----------------------------------------------------------------------------
-- v2.9.1: pre-declare module specs (declaration-only; no runtime migration yet)
-- -----------------------------------------------------------------------------

-- L0 (never unplug)
Registry:Register({
  id = "Const", layer = "L0", exports = { "Const" }, requires = {}, defaults = {},
  init = function(ctx) return Bre.Const or {} end,
})
Registry:Register({
  id = "Contract", layer = "L0", exports = { "Contract" }, requires = {}, defaults = {},
  init = function(ctx) return Bre.Contract or {} end,
})
Registry:Register({
  id = "DB", layer = "L0", exports = { "DB" }, requires = {}, defaults = {},
  init = function(ctx) return Bre.DB or {} end,
})
Registry:Register({
  id = "Events", layer = "L0", exports = { "Events" }, requires = {}, defaults = {},
  init = function(ctx) return Bre.Events or {} end,
})
Registry:Register({
  id = "Locale", layer = "L0", exports = { "Locale" }, requires = {}, defaults = {},
  init = function(ctx) return Bre.L or {} end,
})

-- L1 (unpluggable services)
Registry:Register({
  id = "API_Data",
  layer = "L1",
  exports = { "API_Data" },
  requires = { { iface = "DB", optional = false } },
  defaults = { { iface = "API_Data", policy = "safe-return" } },
  init = function(ctx) return Bre.API_Data or {} end,
})

Registry:Register({
  id = "TreeIndex",
  layer = "L1",
  exports = { "TreeIndex" },
  requires = { { iface = "DB", optional = false }, { iface = "API_Data", optional = false } },
  defaults = { { iface = "TreeIndex", policy = "safe-return", stub = _TreeIndexStub } },
  init = function(ctx) return Bre.TreeIndex or {} end,
})

Registry:Register({
  id = "LoadState",
  layer = "L1",
  exports = { "LoadState" },
  requires = { { iface = "DB", optional = true } },
  defaults = { { iface = "LoadState", policy = "safe-return", stub = _LoadStateStub } },
  init = function(ctx) return Bre.LoadState or {} end,
})

Registry:Register({
  id = "UIBindings",
  layer = "L1",
  exports = { "UIBindings" },
  requires = { { iface = "Contract", optional = false }, { iface = "DB", optional = false }, { iface = "TreeIndex", optional = false }, { iface = "API_Data", optional = false } },
  defaults = { { iface = "UIBindings", policy = "safe-return" } },
  init = function(ctx) return Bre.UIBindings or {} end,
})

Registry:Register({
  id = "Skin",
  layer = "L1",
  exports = { "Skin" },
  requires = {},
  defaults = { { iface = "Skin", policy = "no-op" } },
  init = function(ctx) return Bre.Skin or {} end,
})

Registry:Register({
  id = "Render",
  layer = "L1",
  exports = { "Render" },
  requires = {},
  defaults = { { iface = "Render", policy = "no-op" } },
  init = function(ctx) return Bre.Render or {} end,
})

Registry:Register({
  id = "Move",
  layer = "L1",
  exports = { "Move" },
  requires = { { iface = "API_Data", optional = false }, { iface = "UI", optional = true } },
  defaults = { { iface = "Move", policy = "no-op", stub = _MoveStub() } },
  init = function(ctx) return Bre.Move or {} end,
})

-- v2.12.0: PropertyService (L1) - unified entry for properties/attributes. Skeleton only.
Registry:Register({
  id = "PropertyService",
  layer = "L1",
  exports = { "PropertyService" },
  requires = { { iface = "Move", optional = true } },
  defaults = { { iface = "PropertyService", policy = "no-op", stub = { Set = function() return false end, Apply = function() return false end, Get = function() return nil end, Normalize = function(_, _, v) return v end } } },
  init = function(ctx)
    local PS = Bre.PropertyService
    if PS then
    end
    return PS or {}
  end,
})

-- v2.19.10: GroupScaleService (L1) - event-driven batch apply for LOCAL group scaling (effective = multiplicative).
Registry:Register({
  id = "GroupScaleService",
  layer = "L1",
  exports = { "GroupScaleService" },
  requires = { { iface = "Move", optional = true }, { iface = "PropertyService", optional = true } },
  defaults = { { iface = "GroupScaleService", policy = "no-op", stub = { ApplyTopGroupScale = function() return false end, GetTopGroupIdFor = function() return nil end, ApplyNodeBetweenTopGroups = function() return false end, GetEffectiveScaleFor = function() return 1 end, ApplyEffectiveScaleOnly = function() return false end } } },
  init = function(ctx)
    return Bre.GroupScaleService or {}
  end,
})

-- v2.12.0: SelectionService (L1) - unified selection state. Skeleton only.
Registry:Register({
  id = "SelectionService",
  layer = "L1",
  exports = { "SelectionService" },
  requires = {},
  defaults = { { iface = "SelectionService", policy = "no-op", stub = { GetState = function() return { active = nil, set = {} } end, GetActive = function() return nil end, IsSelected = function() return false end, SetActive = function() return false end, SetActiveRaw = function() return false end, SetActiveInSet = function() return false end, SetSet = function() return false end, Toggle = function() return false end, Clear = function() return false end } } },
  init = function(ctx) return Bre.SelectionService or {} end,
})

-- v2.12.0: EditGuard (L1) - refresh lock / side-effect guard. Skeleton only.
Registry:Register({
  id = "EditGuard",
  layer = "L1",
  exports = { "EditGuard" },
  requires = {},
  defaults = { { iface = "EditGuard", policy = "no-op", stub = { Begin = function() end, End = function() end, IsGuarded = function() return true end, RunGuarded = function(_, _, fn) if type(fn) == "function" then pcall(fn) end end } } },
  init = function(ctx) return Bre.EditGuard or {} end,
})

-- v2.13.11: DevCheck (L1) - dev-only constitution self-check hooks.
Registry:Register({
  id = "DevCheck",
  layer = "L1",
  exports = { "DevCheck" },
  requires = { { iface = "Move", optional = true }, { iface = "DB", optional = true }, { iface = "PropertyService", optional = true } },
  defaults = { { iface = "DevCheck", policy = "no-op", stub = { Install = function() end, Uninstall = function() end, SetEnabled = function() end, IsEnabled = function() return false end } } },
  init = function(ctx)
    local d = Bre.DevCheck or {}
    if type(d.Install) == "function" then pcall(function() d:Install() end) end
    return d
  end,
  shutdown = function(ctx)
    local d = Bre.DevCheck
    if d and type(d.Uninstall) == "function" then pcall(function() d:Uninstall() end) end
  end,
})


-- v2.11.9: ResolveTargetFrame (BrA-style anchor resolve) - read-only; no position side effects.
Registry:Register({
  id = "TargetResolver",
  layer = "L1",
  exports = { "ResolveTargetFrame" },
  requires = { { iface = "Move", optional = true } },
  defaults = { { iface = "ResolveTargetFrame", policy = "safe-return" } },
  init = function(ctx) return Bre.TargetResolver or {} end,
})


-- v2.11.11: AnchorRetry (BrA-style postpone + retry queue) - read-only; no position side effects.
Registry:Register({
  id = "AnchorRetry",
  layer = "L1",
  exports = { "AnchorRetry" },
  requires = { { iface = "ResolveTargetFrame", optional = true } },
  defaults = { { iface = "AnchorRetry", policy = "safe-return" } },
  init = function(ctx)
    -- Start retry loop; safe even if ResolveTargetFrame is currently stubbed/nil.
    local ar = Bre.AnchorRetry or {}
    if type(ar.StartRetry) == "function" then
      pcall(function() ar:StartRetry(1.0) end)
    end
    return ar
  end,
  shutdown = function(ctx)
    local ar = Bre.AnchorRetry
    if ar and type(ar.StopRetry) == "function" then
      pcall(function() ar:StopRetry() end)
    end
  end,
})

Registry:Register({
  id = "ViewService",
  layer = "L1",
  exports = { "View" },
  requires = { { iface = "TreeIndex", optional = true }, { iface = "Move", optional = true } },
  defaults = { { iface = "View", policy = "safe-return", stub = _ViewStub() } },
  init = function(ctx) return Bre.View or {} end,
})



Registry:Register({
  id = "IO",
  layer = "L1",
  exports = { "IO" },
  requires = { { iface = "DB", optional = false }, { iface = "TreeIndex", optional = true }, { iface = "API_Data", optional = true } },
  defaults = { { iface = "IO", policy = "safe-return" } },
  init = function(ctx) return Bre.IO or {} end,
})

-- L2 (unpluggable UI)
Registry:Register({
  id = "CustomMat",
  layer = "L2",
  exports = { "CustomMat" },
  requires = { { iface = "UI", optional = true }, { iface = "DB", optional = true } },
  defaults = { { iface = "CustomMat", policy = "no-op" } },
  init = function(ctx)
    local m = Bre.CustomMat or {}
    if type(m.OnInit) == "function" then pcall(m.OnInit, m, ctx) end
    return m
  end,
  shutdown = function(ctx)
    local m = Bre.CustomMat or {}
    if type(m.OnShutdown) == "function" then pcall(m.OnShutdown, m, ctx) end
  end,
})

Registry:Register({
  id = "ProgressMat",
  layer = "L2",
  exports = { "ProgressMat" },
  requires = { { iface = "UI", optional = true }, { iface = "DB", optional = true }, { iface = "Render", optional = true } },
  defaults = { { iface = "ProgressMat", policy = "no-op" } },
  init = function(ctx)
    local m = Bre.ProgressMat or {}
    if type(m.OnInit) == "function" then pcall(m.OnInit, m, ctx) end
    return m
  end,
  shutdown = function(ctx)
    local m = Bre.ProgressMat or {}
    if type(m.OnShutdown) == "function" then pcall(m.OnShutdown, m, ctx) end
  end,
})

Registry:Register({
  id = "ProgressData",
  layer = "L2",
  exports = { "ProgressData" },
  requires = { { iface = "Gate", optional = false } },
  defaults = { { iface = "ProgressData", policy = "no-op" } },
  init = function(ctx)
    local m = Bre.ProgressData or {}
    if type(m.Init) == "function" then pcall(m.Init, m, ctx) end
    return m
  end,
  shutdown = function(ctx)
    local m = Bre.ProgressData or {}
    if type(m.Shutdown) == "function" then pcall(m.Shutdown, m, ctx) end
  end,
})

Registry:Register({
  id = "UI",
  layer = "L2",
  exports = { "UI" },
  requires = { { iface = "DB", optional = false }, { iface = "Skin", optional = true }, { iface = "Move", optional = true }, { iface = "TreeIndex", optional = true }, { iface = "UIBindings", optional = true }, { iface = "API_Data", optional = true } },
  defaults = { { iface = "UI", policy = "no-op" } },
  init = function(ctx) return Bre.UI or {} end,
})

Registry:Register({
  id = "TreePanel_Resize",
  layer = "L2",
  exports = { "TreePanel_Resize" },
  requires = { { iface = "UI", optional = false }, { iface = "API_Data", optional = false } },
  defaults = { { iface = "TreePanel_Resize", policy = "no-op" } },
  init = function(ctx) return Bre.TreePanel_Resize or {} end,
})

-- -----------------------------------------------------------------------------
-- Step2 (v2.18.68): L2 Specs (not wired to any existing drawer yet)
-- -----------------------------------------------------------------------------

Registry:Register({
  id = "BlankDrawerSpec",
  layer = "L2",
  exports = { "BlankDrawerSpec" },
  requires = {},
  defaults = { { iface = "BlankDrawerSpec", policy = "safe-return" } },
  init = function(ctx) return Bre.BlankDrawerSpec or {} end,
})

Registry:Register({
  id = "PropPosSpec",
  layer = "L2",
  exports = { "PropPosSpec" },
  requires = {},
  defaults = { { iface = "PropPosSpec", policy = "safe-return" } },
  init = function(ctx) return Bre.PropPosSpec or {} end,
})