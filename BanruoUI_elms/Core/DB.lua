-- Bre/Core/DB.lua
-- SavedVariables base (minimal). v2.7.9

local addonName, Bre = ...
Bre = Bre or {}
Bre.DB = Bre.DB or {}

local DB = Bre.DB

-- Guard: make InitSaved idempotent and cheap for repeated callers.
DB._savedInited = DB._savedInited or false

function DB:EnsureSaved()
  if DB._savedInited then return end
  DB._savedInited = true
  self:InitSaved()
end

-- Public: ensure saved tables exist (call on ADDON_LOADED)
function DB:InitSaved()
  BreSaved = BreSaved or {}
  BreSaved.meta = BreSaved.meta or {}
  BreSaved.meta.version = Bre.Const and Bre.Const.VERSION or (BreSaved.meta.version or "v2.7.x")
  BreSaved.meta.schema = BreSaved.meta.schema or 1

  BreSaved.displays = BreSaved.displays or {}

  -- Root order (deterministic ordering for top-level nodes in the left tree)
  -- UI-only; does not change node schema.
  BreSaved.rootChildren = BreSaved.rootChildren or {}

  -- UI state (stable + minimal)
  BreSaved.ui = BreSaved.ui or {}
  BreSaved.ui.tree = BreSaved.ui.tree or {}
  if type(BreSaved.ui.tree.width) ~= "number" then
    BreSaved.ui.tree.width = 260
  end
  BreSaved.ui.tree.expanded = BreSaved.ui.tree.expanded or {}

  -- UI selection state (optional; persisted)
  if type(BreSaved.ui.selectedId) ~= "string" then
    BreSaved.ui.selectedId = nil
  end

  -- optional mock seed for early UI work
  self:SeedMockIfEmpty()
end

-- ------------------------------------------------------------
-- UI state helpers (Tree)
-- ------------------------------------------------------------
function DB:_EnsureUI()
  self:InitSaved()
  BreSaved.ui = BreSaved.ui or {}
  BreSaved.ui.tree = BreSaved.ui.tree or {}
  BreSaved.ui.tree.expanded = BreSaved.ui.tree.expanded or {}
  return BreSaved.ui
end

function DB:GetSelectedId()
  local ui = self:_EnsureUI()
  return (type(ui.selectedId) == "string" and ui.selectedId) or nil
end

function DB:SetSelectedId(id)
  local ui = self:_EnsureUI()
  if type(id) ~= "string" or id == "" then
    ui.selectedId = nil
    return
  end
  ui.selectedId = id
end

function DB:GetTreeWidth()
  local ui = self:_EnsureUI()
  return tonumber(ui.tree.width) or 260
end

function DB:SetTreeWidth(w)
  local ui = self:_EnsureUI()
  w = tonumber(w)
  if not w then return end
  ui.tree.width = w
end

function DB:GetTreeExpanded(id)
  if type(id) ~= "string" then return nil end
  local ui = self:_EnsureUI()
  return ui.tree.expanded[id]
end

function DB:SetTreeExpanded(id, on)
  if type(id) ~= "string" then return end
  local ui = self:_EnsureUI()
  ui.tree.expanded[id] = (on and true) or false
end

-- Public: quick access
function DB:GetDisplays()
  if not BreSaved or not BreSaved.displays then
    return nil
  end
  return BreSaved.displays
end


-- Seed mock data for UI testing.
--
-- We seed not only when the DB is empty, but also when a previous mock seed is
-- incomplete (e.g. user already has 1 old test node). This keeps the UI
-- consistently testable.
function DB:SeedMockIfEmpty()
  local d = BreSaved.displays
  if type(d) ~= "table" then return end

  -- IMPORTANT (v2.7.34): mock seed must never overwrite user edits.
  -- We seed once (or only fill missing nodes) and then stop.
  BreSaved.meta = BreSaved.meta or {}

  local S = Bre.Schema

  local function mkGroup(id, parent)
    local g
    if S and S.CreateGroup then
      g = S:CreateGroup(id, parent)
    else
      g = { id = id, kind = "group", type = "group", regionType = "group", parent = parent, controlledChildren = {}, group = {} }
    end
    g.controlledChildren = g.controlledChildren or {}
    g.group = g.group or {}
    g.label = g.label or id
    return g
  end

  local function mkElement(id, regionType, parent)
    local e
    if S and S.CreateElement then
      e = S:CreateElement(regionType, { id = id, parent = parent })
    else
      e = { id = id, kind = "element", type = "custom", regionType = regionType, parent = parent, controlledChildren = {} }
    end
    e.label = e.label or id
    return e
  end

  local function ensure(id, maker)
    if type(d[id]) == "table" then
      return d[id]
    end
    local node = maker()
    d[id] = node
    return node
  end

  -- Helper: insert unique into array
  local function pushUnique(arr, v)
    if type(arr) ~= "table" then return end
    for _, x in ipairs(arr) do if x == v then return end end
    table.insert(arr, v)
  end

  -- System seed (v2.14.6): ensure built-in editor elements exist even if mock seed already ran.
  -- This must never overwrite user data; only fill missing nodes.
  local function ensureSystemProgressMat()
    local id = "进度条材质"
    if type(d[id]) == "table" then return end

    local node = mkElement(id, "progress", nil)
    node.label = node.label or id
    node.features = node.features or {}
    node.features.progress = node.features.progress or {}
    node.features.progress.enabled = true
    node.features.progress.shape = node.features.progress.shape or "linear"
    node.features.progress.value = node.features.progress.value or 1.0
    node.features.progress.linear = node.features.progress.linear or { orientation = "H", inverse = false }
    node.features.progress.circular = node.features.progress.circular or { startAngle = 0, endAngle = 360, inverse = false }

    node.region = node.region or {}
    node.region.progress = node.region.progress or { mode = "linear" }

    d[id] = node

    -- Ensure it appears as a top-level node in deterministic order.
    BreSaved.rootChildren = BreSaved.rootChildren or {}
    pushUnique(BreSaved.rootChildren, id)
  end

  -- ensureSystemProgressMat()  -- Disabled: no longer auto-create progress mat node

  -- After system seed, honor mock seed sentinel to avoid rewriting sample data.
  if BreSaved.meta._mockSeeded then
    return
  end

  -- Ensure groups exist (but never overwrite their wiring if user already edited it)
  local g1 = ensure("父组", function() return mkGroup("父组", nil) end)
  g1.group = g1.group or {}
  if not g1.group.iconPath or g1.group.iconPath == "" then
    g1.group.iconPath = "Interface/Icons/INV_Misc_QuestionMark"
  end
  g1.controlledChildren = g1.controlledChildren or {}

  local sg = ensure("子组", function() return mkGroup("子组", "父组") end)
  sg.parent = sg.parent or "父组"
  sg.controlledChildren = sg.controlledChildren or {}

  local g2 = ensure("父组2", function() return mkGroup("父组2", nil) end)
  g2.controlledChildren = g2.controlledChildren or {}

  -- Ensure 5 mock elements (only fill missing; do not force their parent)
  local eids = { "元素1", "元素2", "元素3", "元素4", "元素5" }
  for _, eid in ipairs(eids) do
    local e = ensure(eid, function() return mkElement(eid, "custom", "子组") end)
    if e.parent == nil then
      e.parent = "子组"
    end
  end

  -- Initial wiring only if empty
  if #g1.controlledChildren == 0 then
    table.insert(g1.controlledChildren, "子组")
  else
    pushUnique(g1.controlledChildren, "子组")
  end
  if #sg.controlledChildren == 0 then
    for _, eid in ipairs(eids) do table.insert(sg.controlledChildren, eid) end
  else
    for _, eid in ipairs(eids) do pushUnique(sg.controlledChildren, eid) end
  end

  -- Mark seeded so we won't rewrite on subsequent refreshes.
  BreSaved.meta._mockSeeded = true
end

