-- Bre/Core/UI_Bindings.lua
-- UI ↔ SavedVariables bridge. v2.7.12 (no rendering)

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate
local function _DB() return Gate:Get('DB') end
local function _TreeIndex() return Gate:Get('TreeIndex') end
local function _API() return Gate:Get('API_Data') end
local function _Contract() return Gate:Get('Contract') end
local function _Move() return Gate:Get('Move') end

Bre.UIBindings = Bre.UIBindings or {}

local U = Bre.UIBindings

local function getDisplays()
  local DB = _DB()
  if DB and DB.GetDisplays then
    -- DB initialization is centralized in Core (Gate→DB)
    return DB:GetDisplays() or {}
  end
  return {}
end

function U:GetTreeIndex()
  local TI = _TreeIndex()
  if not TI or not TI.Build then
    return { parentMap = {}, childrenMap = {}, roots = {} }
  end
  return TI:Build()
end

function U:ListRoots()
  local idx = self:GetTreeIndex()
  return idx.roots or {}
end

function U:ListChildren(id)
  local idx = self:GetTreeIndex()
  local map = idx.childrenMap or {}
  return map[id] or {}
end

function U:GetNode(id)
  local TI = _TreeIndex()
  if TI and TI.GetNode then
    local n = TI:GetNode(id)
    if n ~= nil then return n end
  end
  local API = _API(); if API and API.GetData then return API:GetData(id) end
  return getDisplays()[id]
end

function U:IsGroupNode(data)
  local C = _Contract()
  if not C or not C.IsGroup then
    return false
  end
  return C:IsGroup(data and data.regionType)
end

function U:GetDisplayLabel(id, data)
  if type(id) ~= "string" then return "" end
  data = data or self:GetNode(id)
  local t = data and data.regionType or "?"
  local n = (data and (data.name or data.title))
  local head = (type(n)=="string" and n~="" and n) or id
  return string.format("%s  |cff888888(%s)|r", head, t)
end

-- ------------------------------------------------------------
-- Tree operations (testing: reorder and detach)
-- ------------------------------------------------------------
local function ensureDisplays()
  -- DB initialization is centralized in Core (Gate→DB)
  if DB and DB.GetDisplays then
    return DB:GetDisplays() or {}
  end
  return {}
end

local function indexOf(t, v)
  if type(t) ~= "table" then return nil end
  for i, x in ipairs(t) do
    if x == v then return i end
  end
  return nil
end

local function removeValue(t, v)
  local i = indexOf(t, v)
  if i then table.remove(t, i) end
end

local function insertAt(t, i, v)
  table.insert(t, i, v)
end

function U:MoveUp(id)
  local M = _Move()
  if M and M.MoveSibling then
    return M:MoveSibling(id, -1) and true or false
  end
  return false
end

function U:MoveDown(id)
  local M = _Move()
  if M and M.MoveSibling then
    return M:MoveSibling(id, 1) and true or false
  end
  return false
end

function U:DetachFromParent(id)
  local M = _Move()
  if M and M.DetachFromParent then
    return M:DetachFromParent(id) and true or false
  end
  return false
end

-- ------------------------------------------------------------
-- Group icon inheritance helpers
-- ------------------------------------------------------------
function U:GetGroupIconPath(id, data)
  data = data or self:GetNode(id)
  if type(data) ~= "table" then return nil end
  local g = data.group
  if type(g) == "table" and type(g.iconPath) == "string" and g.iconPath ~= "" then
    return g.iconPath
  end
  return nil
end

function U:GetInheritedGroupIconPath(id, data)
  data = data or self:GetNode(id)
  if type(data) ~= "table" then return nil end
  local icon = self:GetGroupIconPath(id, data)
  if icon then return icon end
  local pid = data.parent
  local guard = 0
  while type(pid) == "string" and pid ~= "" and guard < 20 do
    local p = self:GetNode(pid)
    icon = self:GetGroupIconPath(pid, p)
    if icon then return icon end
    pid = p and p.parent
    guard = guard + 1
  end
  return nil
end


function U:GetPosition(id)
  local d = self:GetNode(id)
  if not d then return 0,0 end
  d.position = d.position or {}
  return d.position.x or 0, d.position.y or 0
end

function U:SetPosition(id, x, y)
  local d = self:GetNode(id)
  if not d then return end
  d.position = d.position or {}
  if type(x) == 'number' then d.position.x = x end
  if type(y) == 'number' then d.position.y = y end
end
