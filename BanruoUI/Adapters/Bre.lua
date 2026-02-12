-- Adapters/Bre.lua
-- BanruoUI <-> Bre adapter (Step0-3)
-- Goal (this step): provide a safe detection + no-op shell.
-- Later steps will wire BanruoUI theme/element switch flows to these APIs.

local ADDON_NAME, ns = ...
BanruoUI = BanruoUI or {}
local B = BanruoUI

local function _host()
  local h = _G.Bre and _G.Bre.HostAPI or nil
  if h and type(h.Ready) == "function" and h:Ready() then
    return h
  end
  return nil
end

-- Ready/exists
function B:BRE_Ready()
  local h = _host()
  return h ~= nil
end

function B:BRE_RootExists(rootName)
  local h = _host()
  if not h or type(h.HasRoot) ~= "function" then return false end
  return h:HasRoot(rootName) and true or false
end

function B:BRE_FindRootId(rootName)
  local h = _host()
  if not h or type(h.FindRootId) ~= "function" then return nil end
  return h:FindRootId(rootName)
end

-- Import
function B:BRE_Import(str)
  local h = _host()
  if not h or type(h.ImportString) ~= "function" then return nil, "bre_not_ready" end
  return h:ImportString(str)
end

-- Delete helpers (Force Restore)
function B:BRE_DeleteByKeyword(keyword)
  local h = _host()
  if not h or type(h.DeleteByKeyword) ~= "function" then return false, "bre_not_ready" end
  return h:DeleteByKeyword(keyword) and true or false
end

function B:BRE_DeleteByGroupName(groupName)
  return self:BRE_DeleteByKeyword(groupName)
end

-- Tree helpers
function B:BRE_ListDirectChildren(parentId)
  local h = _host()
  if not h or type(h.ListDirectChildren) ~= "function" then return {} end
  return h:ListDirectChildren(parentId)
end

function B:BRE_ScanRoot(rootIdOrName)
  local h = _host()
  if not h or type(h.ScanRoot) ~= "function" then return { rootId = nil, snapshot = {} } end
  return h:ScanRoot(rootIdOrName)
end

-- Step7 helpers: build index from snapshot (id->item, parent->children ids), plus {elementId} parsing.
-- Return: { ok, reason, rootId, snapshot, byId, children, elementMap, dupes }
function B:BRE_ScanRootIndex(rootIdOrName)
  local out = {
    ok = false,
    reason = "bre_not_ready",
    rootId = nil,
    snapshot = {},
    byId = {},
    children = {},
    elementMap = {},
    dupes = {},
    elementCount = 0,
    dupCount = 0,
  }

  local scan = self:BRE_ScanRoot(rootIdOrName)
  if type(scan) ~= "table" then
    out.reason = "scan_failed"
    return out
  end

  out.rootId = scan.rootId
  out.snapshot = type(scan.snapshot) == "table" and scan.snapshot or {}

  -- index
  for _, it in ipairs(out.snapshot) do
    if type(it) == "table" and type(it.id) == "string" and it.id ~= "" then
      out.byId[it.id] = it

      local pid = it.parentId
      if pid == "" then pid = nil end
      local pkey = pid or "__ROOT__"
      out.children[pkey] = out.children[pkey] or {}
      table.insert(out.children[pkey], it.id)

      -- parse {elementId} from name
      local name = tostring(it.name or "")
      local eid = name:match("%b{}")
      if eid then
        eid = eid:sub(2, -2)
        eid = eid and eid:gsub("^%s+", ""):gsub("%s+$", "") or nil
      end
      if eid and eid ~= "" then
        out.elementCount = out.elementCount + 1
        if out.elementMap[eid] then
          out.dupes[eid] = true
        else
          out.elementMap[eid] = { id = it.id, title = it.name or it.id, isGroup = it.isGroup and true or false }
        end
      end
    end
  end

  for k,_ in pairs(out.dupes) do
    out.dupCount = out.dupCount + 1
  end

  out.ok = true
  out.reason = "ok"
  return out
end

-- B1 scan compatibility for ElementSwitch/Container.
function B:BRE_B1_ScanRoot(rootName)
  local idx = self:BRE_ScanRootIndex(rootName)
  return {
    ok = idx.ok,
    reason = idx.ok and nil or idx.reason,
    map = idx.elementMap or {},
    dupes = idx.dupes or {},
    elementCount = idx.elementCount or 0,
    dupCount = idx.dupCount or 0,
    _idx = idx,
  }
end

-- Helpers for UI: list direct children as objects {id,title,isGroup}
function B:BRE_ListDirectChildrenObjs(parentId, idx)
  local ids = self:BRE_ListDirectChildren(parentId)
  local out = {}
  if type(ids) ~= "table" then return out end
  for i = 1, #ids do
    local id = ids[i]
    if type(id) == "string" and id ~= "" then
      local it = idx and idx.byId and idx.byId[id] or nil
      local title = (it and (it.name or it.id)) or id
      local isGroup = it and it.isGroup and true or false
      table.insert(out, { id = id, title = title, isGroup = isGroup })
    end
  end
  table.sort(out, function(a, b) return tostring(a.title) < tostring(b.title) end)
  return out
end

function B:BRE_IsNeverById(id, idx)
  if type(id) ~= "string" or id == "" then return nil end
  local it = idx and idx.byId and idx.byId[id] or nil
  if it and it.never ~= nil then return it.never and true or false end
  return nil
end

-- Load/never helpers
function B:BRE_SetNeverById(id, never)
  local h = _host()
  if not h then return false end
  if type(h.SetNever) == "function" then
    return h:SetNever(id, never) and true or false
  end
  if type(h.SetNodeEnabled) == "function" then
    return h:SetNodeEnabled(id, not never) and true or false
  end
  return false
end

function B:BRE_RebuildDisplays(ids)
  local h = _host()
  if not h or type(h.RebuildDisplays) ~= "function" then return false end
  return h:RebuildDisplays(ids) and true or false
end

function B:BRE_RefreshLoads(rootIdOrName)
  local h = _host()
  if not h or type(h.RefreshLoads) ~= "function" then return false end
  return h:RefreshLoads(rootIdOrName) and true or false
end
