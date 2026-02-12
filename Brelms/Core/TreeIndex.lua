-- Bre/Core/TreeIndex.lua
-- Build parent/children index from BrelmsSaved.displays. v2.7.12

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate
local function _DB() return Gate:Get('DB') end

Bre.TreeIndex = Bre.TreeIndex or {}

local T = Bre.TreeIndex

local function getDisplays()
  local DB = _DB()
  if DB and DB.GetDisplays then
    return DB:GetDisplays() or {}
  end
  BrelmsSaved = BrelmsSaved or { displays = {} }
  BrelmsSaved.displays = BrelmsSaved.displays or {}
  return BrelmsSaved.displays
end

-- Returns: index { parentMap, childrenMap, roots }
function T:Build()
  local d = getDisplays()

  local parentMap = {}
  local childrenMap = {}
  local roots = {}

  -- pass 1: collect parent pointers
  for id, data in pairs(d) do
    if type(id) == "string" and type(data) == "table" then
      local pid = data.parent
      if type(pid) == "string" and pid ~= "" then
        parentMap[id] = pid
      end
    end
  end

  -- pass 2: build childrenMap (prefer parent's controlledChildren order)
  for pid, pdata in pairs(d) do
    if type(pid) == "string" and type(pdata) == "table" then
      local cc = pdata.controlledChildren
      if type(cc) == "table" and #cc > 0 then
        childrenMap[pid] = childrenMap[pid] or {}
        for _, cid in ipairs(cc) do
          if type(cid) == "string" and d[cid] and parentMap[cid] == pid then
            table.insert(childrenMap[pid], cid)
          end
        end
      end
    end
  end

  -- include any missing children (stable: append)
  for cid, pid in pairs(parentMap) do
    if d[pid] ~= nil then
      childrenMap[pid] = childrenMap[pid] or {}
      local exists = false
      for _, x in ipairs(childrenMap[pid]) do
        if x == cid then exists = true break end
      end
      if not exists then
        table.insert(childrenMap[pid], cid)
      end
    end
  end

  -- pass 3: compute roots (no parent or missing parent)
  local rootSet = {}
  for id, data in pairs(d) do
    if type(id) == "string" and type(data) == "table" then
      local pid = parentMap[id]
      if not pid or d[pid] == nil then
        rootSet[id] = true
      end
    end
  end

  -- Root order: prefer BrelmsSaved.rootChildren when present.
  -- This allows deterministic "insert at first" behavior for top-level nodes.
  local ordered = {}
  if BrelmsSaved and type(BrelmsSaved.rootChildren) == "table" then
    for _, rid in ipairs(BrelmsSaved.rootChildren) do
      if rootSet[rid] then
        table.insert(ordered, rid)
        rootSet[rid] = nil
      end
    end
  end

  -- Any remaining roots (not tracked yet) are appended in stable string order.
  local extra = {}
  for rid, on in pairs(rootSet) do
    if on then table.insert(extra, rid) end
  end
  table.sort(extra)
  for _, rid in ipairs(extra) do table.insert(ordered, rid) end

  roots = ordered
  for pid, arr in pairs(childrenMap) do
    local pdata = d[pid]
    local cc = pdata and pdata.controlledChildren
    if not (type(cc) == "table" and #cc > 0) then
      table.sort(arr)
    end
  end

  return {

    parentMap = parentMap,
    childrenMap = childrenMap,
    roots = roots,
  }
end
