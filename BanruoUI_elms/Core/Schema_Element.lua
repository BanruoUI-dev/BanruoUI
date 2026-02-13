-- Bre/Core/Schema_Element.lua
-- Element minimal schema (v0.1). Data-only helpers.

local addonName, Bre = ...
Bre = Bre or {}
Bre.Schema = Bre.Schema or {}

local S = Bre.Schema

local function now()
  if type(time) == "function" then
    return time()
  end
  return 0
end

local function ensureTable(t)
  return type(t) == "table" and t or {}
end

local function normalizeRegionType(regionType)
  if type(regionType) ~= "string" or regionType == "" then
    return "custom"
  end
  return regionType
end

-- Create a new element table with the minimal, unified schema.
-- regionType: "group" | "dynamicgroup" | "custom" | "progress" | "stopmotion" | "model" | ...
-- opts: optional { id=..., parent=..., width=..., height=... }
function S:CreateElement(regionType, opts)
  opts = ensureTable(opts)
  local t = {}

  t.id = opts.id
  t.regionType = normalizeRegionType(regionType)

  -- tree
  t.parent = opts.parent
  t.controlledChildren = {}

  -- base switches / BanruoUI contract
  t.enabled = true
  t.load = { never = false }

  -- unified props (editor-facing, single source of intent)
  -- NOTE: v2.10.37 protocol freeze for upcoming Anchor/XY/FrameLevel integration.
  -- UI/Render must treat props as intent-only; runtime results must not be persisted here.
  t.props = {
    -- Anchor target: "SCREEN_CENTER" | "SELECTED_NODE"
    anchorTarget = "SCREEN_CENTER",
    -- Anchor relationship (BrA-style attach). Data-only in v2.11.8 (no behavior yet).
    -- nil/empty means default anchoring behavior.
    anchor = {
      mode = "NONE", -- "NONE" | "TARGET" (future)
      targetId = nil,
      selfPoint = "CENTER",
      targetPoint = "CENTER",
    },
    -- Frame level mode (placeholder, to be wired via Gate/Move in later steps)
    frameLevelMode = "AUTO",
    -- Frame strata intent (UI layering)
    frameStrata = "AUTO",
    -- XY offsets (intent-only)
    xOffset = 0,
    yOffset = 0,
  }


  -- output actions (L2 data only; execution via Gate in future)
  -- NOTE: v2.18.58 adds rotate action config storage (UI binding + preview only).
  t.actions = {
    rotate = {
      enabled = false,
      loop = false,
      duration = 0,     -- seconds (when loop=true)
      speed = 90,        -- deg/s (OnUpdate-driven angular velocity)
      delay = 0,        -- seconds
      angle = 360,      -- degrees
      dir = "cw",       -- cw | ccw
      anchor = "CENTER",
      endState = "keep", -- keep | reset
      -- reserved for future Condition module integration
      conditions = nil, -- e.g. { mode="ALL", ids={"cond1","cond2"} }
    },
  }

  -- geometry (shared)
  t.anchor = {
    point = "CENTER",
    relativeTo = "UIParent",
    relativePoint = "CENTER",
    x = 0,
    y = 0,
  }
  t.size = {
    width = tonumber(opts.width) or 200,
    height = tonumber(opts.height) or 200,
  }
  t.frame = {
    strata = "MEDIUM",
    level = 1,
  }

  -- visuals (shared)
  t.alpha = 1.0
  
  -- scale (v2.19.0: for group scaling feature)
  -- All elements have this field, but only top-level groups expose it in UI
  t.scale = 1.0

  -- model facing (v2.18.84)
  t.facing = 0

  -- model animation sequence (v2.18.87)
  t.animSequence = 0

  -- per-region payload (module block)
  t.region = {
    -- common texture-like defaults (custom)
    texture = nil,
    color = { r = 1, g = 1, b = 1, a = 1 },
    blendMode = "BLEND",
    mirror = false,
    desaturate = false,
    rotation = 0,
  }

  -- optional module blocks (placeholders)
  t.conditions = {}
  t.customFunctions = {}

  -- migration / bookkeeping
  t.meta = {
    version = 1,
    createdAt = now(),
    updatedAt = now(),
  }

  return t
end

-- Ensure an existing element at least has all minimal fields (non-destructive).
function S:NormalizeElement(e)
  if type(e) ~= "table" then return nil end

  e.regionType = normalizeRegionType(e.regionType)

  e.controlledChildren = ensureTable(e.controlledChildren)
  e.load = ensureTable(e.load)
  if e.load.never == nil then e.load.never = false end

  e.anchor = ensureTable(e.anchor)
  if e.anchor.point == nil then e.anchor.point = "CENTER" end
  if e.anchor.relativeTo == nil then e.anchor.relativeTo = "UIParent" end
  if e.anchor.relativePoint == nil then e.anchor.relativePoint = "CENTER" end
  if e.anchor.x == nil then e.anchor.x = 0 end
  if e.anchor.y == nil then e.anchor.y = 0 end

  e.size = ensureTable(e.size)
  if e.size.width == nil then e.size.width = 200 end
  if e.size.height == nil then e.size.height = 200 end

  e.frame = ensureTable(e.frame)
  if e.frame.strata == nil then e.frame.strata = "MEDIUM" end
  if e.frame.level == nil then e.frame.level = 1 end

  if e.alpha == nil then e.alpha = 1.0 end
  if e.scale == nil then e.scale = 1.0 end
  if e.facing == nil then e.facing = 0 end
  if e.animSequence == nil then e.animSequence = 0 end

  e.region = ensureTable(e.region)
  if e.region.color == nil then e.region.color = { r = 1, g = 1, b = 1, a = 1 } end

  e.conditions = ensureTable(e.conditions)
  e.customFunctions = ensureTable(e.customFunctions)

  e.meta = ensureTable(e.meta)
  if e.meta.version == nil then e.meta.version = 1 end
  if e.meta.createdAt == nil then e.meta.createdAt = now() end
  e.meta.updatedAt = now()

  return e
end
