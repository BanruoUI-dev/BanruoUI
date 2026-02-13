-- Bre/Core/FixtureTreeIndex.lua
-- FixtureTreeIndex: TreeIndex stub implementation backed by FixtureTree.
-- Activated ONLY when module TreeIndex is disabled (Gate returns stub).
-- NOTE: Runtime fixture index (safe stub defaults). Must stay side-effect free.

local addonName, Bre = ...
Bre = Bre or {}

Bre.FixtureTreeIndex = Bre.FixtureTreeIndex or {}
local TI = Bre.FixtureTreeIndex

local function _fixture()
  local F = Bre.FixtureTree
  if F and F.GetDisplays then
    return F:GetDisplays(), (F.GetRootOrder and F:GetRootOrder() or {})
  end
  return {}, {}
end

-- Returns: index { parentMap, childrenMap, roots }
function TI:Build()
  local d, rootOrder = _fixture()

  local parentMap, childrenMap = {}, {}
  for id, data in pairs(d) do
    if type(id) == "string" and type(data) == "table" then
      local pid = data.parent
      if type(pid) == "string" and pid ~= "" then
        parentMap[id] = pid
        childrenMap[pid] = childrenMap[pid] or {}
      end
    end
  end

  -- Deterministic child order: prefer controlledChildren if present.
  for pid, pdata in pairs(d) do
    if type(pid) == "string" and type(pdata) == "table" then
      local cc = pdata.controlledChildren
      if type(cc) == "table" and #cc > 0 then
        childrenMap[pid] = {}
        for _, cid in ipairs(cc) do
          if type(cid) == "string" and d[cid] and parentMap[cid] == pid then
            childrenMap[pid][#childrenMap[pid] + 1] = cid
          end
        end
      end
    end
  end

  -- Compute roots: only use fixture root order if it matches existing nodes.
  local roots = {}
  local seen = {}
  if type(rootOrder) == "table" and #rootOrder > 0 then
    for _, rid in ipairs(rootOrder) do
      if d[rid] and not parentMap[rid] then
        roots[#roots + 1] = rid
        seen[rid] = true
      end
    end
  end

  -- Append any remaining roots (shouldn't happen, but keep safe & deterministic).
  local extra = {}
  for id, data in pairs(d) do
    if type(id) == "string" and type(data) == "table" then
      if not parentMap[id] and not seen[id] then
        extra[#extra + 1] = id
      end
    end
  end
  table.sort(extra)
  for _, rid in ipairs(extra) do roots[#roots + 1] = rid end

  return { parentMap = parentMap, childrenMap = childrenMap, roots = roots }
end

-- Optional: allow UIBindings:GetNode to pull fixture data.
function TI:GetNode(id)
  local d = _fixture()
  local displays = d
  -- _fixture() returns (displays, rootOrder) but lua only keeps first if assigned to one var
  if type(displays) == "table" then
    return displays[id]
  end
  return nil
end
