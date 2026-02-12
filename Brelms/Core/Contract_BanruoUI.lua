-- Bre/Core/Contract_BanruoUI.lua
-- NOTE: BanruoUI-ready contract file (kept side-effect free).
-- Minimal schema + helpers for BanruoUI↔Bre contract. v2.7.12
-- NOTE: No rendering logic here. Pure data validation/normalization.
-- NOTE: This file is runtime-safe "data/validation only"; keep side-effect free.

local addonName, Bre = ...
Bre = Bre or {}
Bre.Contract = Bre.Contract or {}

local C = Bre.Contract

local GROUP_TYPES = {
  group = true,
  dynamicgroup = true,
}

function C:IsGroup(regionType)
  return regionType and GROUP_TYPES[regionType] or false
end

local function ensureTable(t)
  return type(t) == "table" and t or {}
end

function C:NormalizeNode(id, data)
  if type(data) ~= "table" then data = {} end
  if type(id) == "string" and data.id ~= id then
    data.id = id
  end

  -- Minimal structural fields used by BanruoUI:
  data.regionType = data.regionType or "texture"
  data.position = data.position or {}
  if type(data.position.x) ~= "number" then data.position.x = 0 end
  if type(data.position.y) ~= "number" then data.position.y = 0 end
  data.controlledChildren = ensureTable(data.controlledChildren)
  data.parent = data.parent

  data.load = ensureTable(data.load)
  if data.load.use_never ~= nil then
    -- Prefer load.never; keep compatibility field present but neutralized
    data.load.use_never = nil
  end
  if data.load.never == nil then
    data.load.never = false
  end

  return data
end

function C:ValidateNode(id, data)
  local ok = true
  local issues = {}

  if type(id) ~= "string" or id == "" then
    ok = false
    table.insert(issues, "id is missing/invalid")
  end

  if type(data) ~= "table" then
    ok = false
    table.insert(issues, "data is not a table")
    return ok, issues
  end

  if data.id and data.id ~= id then
    table.insert(issues, "data.id mismatch")
  end

  if type(data.regionType) ~= "string" then
    table.insert(issues, "regionType missing/invalid")
  end

  if data.parent ~= nil and type(data.parent) ~= "string" then
    table.insert(issues, "parent must be string or nil")
  end

  if data.controlledChildren ~= nil and type(data.controlledChildren) ~= "table" then
    table.insert(issues, "controlledChildren must be table")
  end

  if data.load ~= nil and type(data.load) ~= "table" then
    table.insert(issues, "load must be table")
  else
    local load = data.load or {}
    if load.never ~= nil and type(load.never) ~= "boolean" then
      table.insert(issues, "load.never must be boolean")
    end
  end

  return ok, issues
end
