-- Bre/Core/API_Data.lua
-- Minimal data API for BanruoUI contract (no rendering, no import). v2.7.9

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate
local function _DB() return Gate:Get('DB') end

local function ensureDB()
  local DB = _DB()
  if DB and DB.EnsureSaved then DB:EnsureSaved()
  elseif DB and DB.InitSaved then DB:InitSaved() end
end

local function displays()
  ensureDB()
  local DB = _DB()
  if DB and DB.GetDisplays then
    return DB:GetDisplays() or {}
  end
  return {}
end

-- Get display data by id
function Bre.GetData(id)
  if type(id) ~= "string" then return nil end
  local d = displays()
  return d[id]
end

-- SetData supports (id, data) or (data with data.id)
function Bre.SetData(a, b)
  local id, data
  if type(a) == "string" and type(b) == "table" then
    id, data = a, b
  elseif type(a) == "table" then
    data = a
    id = data.id
  end
  if type(id) ~= "string" or type(data) ~= "table" then
    return false
  end
  data.id = id
  local d = displays()
  d[id] = data
  return true
end

-- UpdateData supports (data) or (id) where id exists
function Bre.UpdateData(a)
  if type(a) == "table" then
    return Bre.SetData(a)
  elseif type(a) == "string" then
    -- no-op placeholder; in future will rebuild region instance
    return Bre.GetData(a) ~= nil
  end
  return false
end

-- Add (alias of SetData for now)
function Bre.Add(data)
  return Bre.SetData(data)
end

function Bre.AddToTable(data)
  return Bre.SetData(data)
end

-- Delete a node by id (no recursion yet; placeholder)
function Bre.Delete(id)
  if type(id) ~= "string" then return false end
  local d = displays()
  if d[id] == nil then return false end
  d[id] = nil
  return true
end

-- ------------------------------------------------------------
-- UI state API (Tree)
-- ------------------------------------------------------------
function Bre.GetTreeWidth()
  local DB = _DB(); return (DB and DB.GetTreeWidth and DB:GetTreeWidth()) or 260
end

function Bre.SetTreeWidth(w)
  local DB = _DB(); if DB and DB.SetTreeWidth then DB:SetTreeWidth(w) end
end

function Bre.GetTreeExpanded(id)
  local DB = _DB(); return DB and DB.GetTreeExpanded and DB:GetTreeExpanded(id) or nil
end

function Bre.SetTreeExpanded(id, on)
  local DB = _DB(); if DB and DB.SetTreeExpanded then DB:SetTreeExpanded(id, on) end
end

-- ------------------------------------------------------------
-- Step4: API_Data iface wrapper for Gate/Linker
-- Keep legacy globals (Bre.GetData/SetData/...) unchanged.
-- ------------------------------------------------------------
Bre.API_Data = Bre.API_Data or {}
local A = Bre.API_Data

function A:GetData(id) return Bre.GetData(id) end
function A:SetData(a, b) return Bre.SetData(a, b) end
function A:UpdateData(id, patch) return Bre.UpdateData(id, patch) end
function A:Add(data) return Bre.Add(data) end
function A:AddToTable(data) return Bre.AddToTable(data) end
function A:Delete(id) return Bre.Delete(id) end

function A:GetTreeWidth() return Bre.GetTreeWidth() end
function A:SetTreeWidth(w) return Bre.SetTreeWidth(w) end
function A:GetTreeExpanded(id) return Bre.GetTreeExpanded(id) end
function A:SetTreeExpanded(id, on) return Bre.SetTreeExpanded(id, on) end
