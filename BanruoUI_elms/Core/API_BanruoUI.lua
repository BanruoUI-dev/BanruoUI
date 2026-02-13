-- Bre/Core/API_BanruoUI.lua
-- BanruoUI-ready public API surface for Bre.
-- Purpose:
--   Provide a stable, side-effect controlled interface for BanruoUI control panel
--   (tree listing + enable/disable toggles + refresh hooks), without coupling to
--   Bre UI internals.
--
-- Policy:
--   - Read-only queries MUST be side-effect free.
--   - Any mutation MUST go through Gate -> L1 service modules (no DB direct write).
--   - This file is runtime-safe (no Options/LoD dependencies).

local addonName, Bre = ...
Bre = Bre or {}

Bre.API = Bre.API or {}
local API = Bre.API

local Gate = Bre.Gate

local function _DB() return Gate and Gate.Get and Gate:Get("DB") end
local function _Move() return Gate and Gate.Get and Gate:Get("Move") end
local function _UI() return Gate and Gate.Get and Gate:Get("UI") end

local function _isGroupType(regionType)
  return regionType == "group" or regionType == "dynamicgroup"
end

local function _getChildren(d, id)
  if type(d) ~= "table" then return {} end
  if type(id) == "string" and id ~= "" then
    local el = d[id]
    if type(el) == "table" and type(el.controlledChildren) == "table" then
      return el.controlledChildren
    end
    return {}
  end
  -- root
  if BreSaved and type(BreSaved.rootChildren) == "table" then
    return BreSaved.rootChildren
  end
  return {}
end

-- Public: Version string (matches TOC).
function API:Version()
  local v = (Bre.Const and Bre.Const.VERSION) or nil
  if type(v) == "string" and v ~= "" then
    return "v" .. v
  end
  return "v?.?.?"
end

-- Public: Ready signal for external callers (BanruoUI adapter).
function API:Ready()
  if not (Gate and Gate.Get) then return false end
  local DB = _DB()
  return (DB and DB.GetDisplays) and true or false
end
-- =========================
-- BanruoUI Theme/Import helpers (Step0-3)
-- Goals:
--   - Root detection by name (for theme switching / first-init check)
--   - Import string into Bre DB (BanruoUI-controlled, safe sandbox)
-- Contract:
--   - Import supports Bre v2 printable string ONLY:
--       "!BRE:2!" .. LibDeflate:EncodeForPrint( CompressDeflate( LibSerialize:SerializeEx(bundle) ) )
--   - bundle = { rootId = "<id>", nodes = { [id]=nodeTable, ... } }
-- =========================

local function _findRootIdByName(rootName)
  if type(rootName) ~= "string" or rootName == "" then return nil end
  local DB = _DB()
  if not (DB and DB.GetDisplays) then return nil end
  local d = DB:GetDisplays()
  if type(d) ~= "table" then return nil end

  -- Direct id hit (rootName may already be an id)
  local direct = d[rootName]
  if type(direct) == "table" and _isGroupType(direct.regionType) then
    return rootName
  end

  -- Prefer top-level groups matching name
  for id, el in pairs(d) do
    if type(el) == "table" then
      local name = (type(el.name) == "string" and el.name) or (type(el.id) == "string" and el.id) or id
      local rt = el.regionType
      local parent = el.parent
      if name == rootName and _isGroupType(rt) and (parent == nil or parent == "") then
        return id
      end
    end
  end

  -- Fallback: any group matching name
  for id, el in pairs(d) do
    if type(el) == "table" then
      local name = (type(el.name) == "string" and el.name) or (type(el.id) == "string" and el.id) or id
      local rt = el.regionType
      if name == rootName and _isGroupType(rt) then
        return id
      end
    end
  end
  return nil
end

-- Base64URL decode (RFC 4648 URL-safe, no padding)
local _B64URL_ALPH = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local _B64URL_INV = nil
local function _b64url_inv()
  if _B64URL_INV then return _B64URL_INV end
  local inv = {}
  for i = 1, #_B64URL_ALPH do
    inv[_B64URL_ALPH:sub(i,i)] = i - 1
  end
  _B64URL_INV = inv
  return inv
end

local function _b64url_decode(data)
  if type(data) ~= "string" or data == "" then return "" end
  local inv = _b64url_inv()
  local out = {}
  local bits = 0
  local bitCount = 0
  for i = 1, #data do
    local c = data:sub(i,i)
    local v = inv[c]
    if v ~= nil then
      bits = bits * 64 + v
      bitCount = bitCount + 6
      while bitCount >= 8 do
        bitCount = bitCount - 8
        local b = math.floor(bits / (2 ^ bitCount)) % 256
        -- keep only remaining bits to avoid float overflow on long strings
        bits = bits % (2 ^ bitCount)
        out[#out+1] = string.char(b)
      end
    end
  end
  return table.concat(out, "")
end


local function _getLibDeflate()
  local ld = _G and _G.LibDeflate or nil
  if ld then return ld end
  if LibStub and LibStub.GetLibrary then
    return LibStub:GetLibrary("LibDeflate", true)
  end
  return nil
end

local function _ensureSaved()
  local DB = _DB()
  if DB and DB.EnsureSaved then DB:EnsureSaved()
  elseif DB and DB.InitSaved then DB:InitSaved() end
end

local function _genId(base, exists)
  if type(base) ~= "string" or base == "" then base = "Imported" end
  if not exists[base] then return base end
  local i = 1
  while true do
    local cand = base .. "_I" .. i
    if not exists[cand] then return cand end
    i = i + 1
  end
end

local function _remapBundle(bundle, exists)
  local map = {}
  for id, _ in pairs(bundle.nodes or {}) do
    if type(id) == "string" and id ~= "" then
      map[id] = _genId(id, exists)
      exists[map[id]] = true
    end
  end

  local newRoot = map[bundle.rootId] or _genId(bundle.rootId, exists)
  local out = {}

  for oldId, node in pairs(bundle.nodes or {}) do
    if type(oldId) == "string" and type(node) == "table" then
      local nid = map[oldId] or oldId
      local n = {}
      for k,v in pairs(node) do n[k] = v end

      -- rewrite internal references
      if type(n.id) == "string" and map[n.id] then n.id = map[n.id] end
      if type(n.parent) == "string" and map[n.parent] then n.parent = map[n.parent] end
      if type(n.controlledChildren) == "table" then
        local cc = {}
        for i, cid in ipairs(n.controlledChildren) do
          if type(cid) == "string" and map[cid] then
            cc[i] = map[cid]
          else
            cc[i] = cid
          end
        end
        n.controlledChildren = cc
      end

      out[nid] = n
    end
  end

  return newRoot, out
end

-- Public: Find root id by name (theme root group).
function API:FindRootId(rootName)
  return _findRootIdByName(rootName)
end

-- Public: Root exists check.
function API:HasRoot(rootName)
  return (API:FindRootId(rootName) ~= nil)
end

-- Public: Import Bre string bundle into DB. Returns: newRootId or nil, err
function API:ImportString(s)
  if type(s) ~= "string" then return nil, "bad_input" end
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then return nil, "empty" end

  -- Import supports v2 only.
  if s:sub(1, 7) ~= "!BRE:2!" then
    return nil, "unsupported_format"
  end

  -- Single source of truth: delegate to L1 IO module.
  local IOM = Gate and Gate.Get and Gate:Get("IO") or nil
  if IOM and type(IOM.ImportString) == "function" then
    return IOM:ImportString(s)
  end

  return nil, "io_missing"

  -- (legacy inline importer removed)
end

-- Public: Flat tree snapshot.
-- rootId: optional node id; nil means root.
-- Returns: array of { id, parentId, regionType, name, isGroup, never, enabled }
function API:GetTreeSnapshot(rootId)
  local DB = _DB()
  if not (DB and DB.GetDisplays) then return {} end
  local d = DB:GetDisplays()
  if type(d) ~= "table" then return {} end

  local out = {}
  local visited = {}

  local function push(id)
    if type(id) ~= "string" or id == "" then return end
    if visited[id] then return end
    visited[id] = true
    local el = d[id]
    if type(el) ~= "table" then return end

    local rt = el.regionType
    local name = (type(el.name) == "string" and el.name ~= "" and el.name) or (type(el.id) == "string" and el.id) or id
    local never = (type(el.load) == "table") and el.load.never or nil
    local enabled = (never ~= true)

    out[#out+1] = {
      id = id,
      parentId = (type(el.parent) == "string" and el.parent) or nil,
      regionType = rt,
      name = name,
      isGroup = _isGroupType(rt),
      never = (never == true) and true or nil,
      enabled = enabled,
    }
  end

  local function walk(id)
    push(id)
    local ch = _getChildren(d, id)
    if type(ch) ~= "table" then return end
    for _, cid in ipairs(ch) do
      if type(cid) == "string" then
        walk(cid)
      end
    end
  end

  -- start
  local roots = _getChildren(d, rootId)
  if type(rootId) == "string" and rootId ~= "" then
    -- include the root itself at the beginning
    walk(rootId)
    return out
  end

  if type(roots) == "table" then
    for _, rid in ipairs(roots) do
      if type(rid) == "string" then
        walk(rid)
      end
    end
  end

  return out
end

-- Public: Enable/Disable a node (BanruoUI toggle).
-- Behavior:
--   enabled=true  => clear load.never (loadable again)
--   enabled=false => set load.never=true (hard-unloaded)
-- Returns: boolean ok
function API:SetNodeEnabled(id, enabled)
  if type(id) ~= "string" or id == "" then return false end
  local Move = _Move()
  if not (Move and Move.CommitLoadNever) then return false end

  local payload = { id = id, value = (enabled and nil) or true }
  local ok = pcall(function() Move:CommitLoadNever(payload) end)
  return ok and true or false
end


-- ============================================================
-- Step4-6: BanruoUI联动必备能力
-- Step4: never硬开关 (load.never)
-- Step5: 刷新入口 (RebuildDisplays / RefreshLoads)
-- Step6: 树扫描与直系子项 (ScanRoot / ListDirectChildren)
-- ============================================================

-- Step4: SetNever (explicit never setter; same semantics as WA load.never)
-- never=true  => hard-unload (tri-state nil)
-- never=false/nil => clear never (loadable again)
function API:SetNever(id, never)
  if type(id) ~= "string" or id == "" then return false end
  local Move = _Move()
  if not (Move and Move.CommitLoadNever) then return false end
  local v = (never == true) and true or nil
  local ok = pcall(function() Move:CommitLoadNever({ id = id, value = v }) end)
  return ok and true or false
end

-- Convenience: set root never by rootId or rootName
function API:SetRootNever(rootIdOrName, never)
  local id = rootIdOrName
  if type(id) ~= "string" or id == "" then return false end
  local DB = _DB()
  if not (DB and DB.GetDisplays) then return false end
  local d = DB:GetDisplays() or {}
  if type(d[id]) ~= "table" then
    -- treat as rootName
    id = API:FindRootId(rootIdOrName)
  end
  if type(id) ~= "string" or id == "" then return false end
  return API:SetNever(id, never)
end

-- Step6: List direct children (stable order)
function API:ListDirectChildren(parentId)
  local DB = _DB()
  if not (DB and DB.GetDisplays) then return {} end
  local d = DB:GetDisplays()
  if type(d) ~= "table" then return {} end
  local ch = _getChildren(d, parentId)
  if type(ch) ~= "table" then return {} end
  -- return a shallow copy to avoid external mutation
  local out = {}
  for i = 1, #ch do out[i] = ch[i] end
  return out
end

-- Step6: Scan root tree (returns rootId + flat snapshot)
-- rootIdOrName: string; if omitted, scans all top-level roots.
-- Return: { rootId = <id or nil>, snapshot = <array> }
function API:ScanRoot(rootIdOrName)
  local rootId = nil
  if type(rootIdOrName) == "string" and rootIdOrName ~= "" then
    local DB = _DB()
    if DB and DB.GetDisplays then
      local d = DB:GetDisplays() or {}
      if type(d[rootIdOrName]) == "table" then
        rootId = rootIdOrName
      else
        rootId = API:FindRootId(rootIdOrName)
      end
    end
  end
  return { rootId = rootId, snapshot = API:GetTreeSnapshot(rootId) }
end

-- StepX: Delete by keyword (Force Restore)
-- Behavior:
--   - Find group/dynamicgroup nodes whose id/name contains keyword.
--   - Prefer top-level roots (parent nil/"") as deletion entry.
--   - Delete subtree via Move:DeleteSubtree.
function API:DeleteByKeyword(keyword)
  if type(keyword) ~= "string" then return false end
  keyword = keyword:gsub("^%s+", ""):gsub("%s+$", "")
  if keyword == "" then return false end

  local DB = _DB()
  if not (DB and DB.GetDisplays) then return false end
  local d = DB:GetDisplays()
  if type(d) ~= "table" then return false end

  local Move = _Move()
  if not (Move and Move.DeleteSubtree) then return false end

  local roots = {}
  local any = {}

  for id, el in pairs(d) do
    if type(el) == "table" and _isGroupType(el.regionType) then
      local sid = (type(el.id) == "string" and el.id) or id
      local name = (type(el.name) == "string" and el.name) or sid
      local hit = (type(sid) == "string" and sid:find(keyword, 1, true)) or (type(name) == "string" and name:find(keyword, 1, true))
      if hit then
        any[#any + 1] = sid
        local parent = el.parent
        if parent == nil or parent == "" then
          roots[#roots + 1] = sid
        end
      end
    end
  end

  local list = (#roots > 0) and roots or any
  if #list == 0 then return true end

  local ok = true
  for i = 1, #list do
    local rid = list[i]
    if type(rid) == "string" and rid ~= "" then
      ok = pcall(function() Move:DeleteSubtree(rid) end) and ok
    end
  end

  -- best-effort refresh after deletion
  pcall(function() API:RefreshLoads() end)

  return ok and true or false
end

-- Step5: Rebuild displays (best-effort, safe)
-- ids: string id or array of ids; nil => no-op false
function API:RebuildDisplays(ids)
  local Move = _Move()
  if not (Move and Move.RebuildRegion) then return false end

  local ok = true
  if type(ids) == "string" and ids ~= "" then
    ok = pcall(function() Move:RebuildRegion(ids) end) and ok
  elseif type(ids) == "table" then
    for i = 1, #ids do
      local id = ids[i]
      if type(id) == "string" and id ~= "" then
        ok = pcall(function() Move:RebuildRegion(id) end) and ok
      end
    end
  else
    return false
  end
  return ok and true or false
end

-- Step5: Refresh loads/runtime visibility (best-effort)
-- rootIdOrName: optional; when provided, refresh subtree under that root
function API:RefreshLoads(rootIdOrName)
  local Move = _Move()
  if not Move then return false end
  local DB = _DB()
  if not (DB and DB.GetDisplays) then return false end
  local d = DB:GetDisplays()
  if type(d) ~= "table" then return false end

  local idx = nil
  if Move.BuildIndex then
    local okIdx, got = pcall(function() return Move:BuildIndex() end)
    if okIdx then idx = got end
  end

  local function refreshSub(id)
    if Move.RefreshSubtree then
      pcall(function() Move:RefreshSubtree(id, idx, true) end)
    elseif Move.Refresh then
      pcall(function() Move:Refresh(id) end)
    end
  end

  local rootId = nil
  if type(rootIdOrName) == "string" and rootIdOrName ~= "" then
    if type(d[rootIdOrName]) == "table" then
      rootId = rootIdOrName
    else
      rootId = API:FindRootId(rootIdOrName)
    end
    if type(rootId) == "string" and rootId ~= "" then
      refreshSub(rootId)
      return true
    end
  end

  -- fallback: refresh all top-level roots
  local roots = API:ListDirectChildren(nil)
  if type(roots) == "table" then
    for i = 1, #roots do
      local rid = roots[i]
      if type(rid) == "string" and rid ~= "" then
        refreshSub(rid)
      end
    end
    return true
  end

  return false
end


-- Public: Force refresh/rebuild helpers (best-effort).
function API:RefreshNode(id)
  local Move = _Move()
  if not Move then return false end
  local ok = true
  if type(id) == "string" and id ~= "" then
    if Move.Refresh then ok = pcall(function() Move:Refresh(id) end) and ok end
  else
    -- no global refresh API; best-effort: refresh selected if exists
    local DB = _DB()
    local sid = DB and DB.GetSelectedId and DB:GetSelectedId() or nil
    if type(sid) == "string" and sid ~= "" and Move.Refresh then
      ok = pcall(function() Move:Refresh(sid) end) and ok
    end
  end
  return ok and true or false
end

function API:RebuildNode(id)
  local Move = _Move()
  if not (Move and Move.RebuildRegion) then return false end
  if type(id) ~= "string" or id == "" then return false end
  local ok = pcall(function() Move:RebuildRegion(id) end)
  return ok and true or false
end


-- Public: Open Bre main panel (for BanruoUI element manager button)
function API:Open()
  local UI = _UI()
  if UI and UI.Show then
    pcall(function() UI:Show() end)
    return true
  end
  if UI and UI.Toggle then
    pcall(function() UI:Toggle() end)
    return true
  end
  return false
end

-- Expose stable host-facing API (BanruoUI adapter)
Bre.HostAPI = API