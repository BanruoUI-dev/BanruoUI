-- Bre/Core/IO.lua
-- IO services (export/import). v2.9.27
-- Export is read-only; does not mutate tree. Must be called via Gate.

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate
local function _API() return Gate:Get('API_Data') end
local function _TreeIndex() return Gate:Get('TreeIndex') end

Bre.IO = Bre.IO or {}
local IO = Bre.IO



-- WA-style encoding components (LibSerialize + LibDeflate)
local _LibStub = _G and _G.LibStub or LibStub
local function _getLibSerialize()
  if _LibStub then
    local ok, lib = pcall(_LibStub, "LibSerialize")
    if ok and lib then return lib end
    if _LibStub.GetLibrary then return _LibStub:GetLibrary("LibSerialize", true) end
  end
  return nil
end

local function _getLibDeflate()
  local ld = _G and _G.LibDeflate or nil
  if ld then return ld end
  if _LibStub and _LibStub.GetLibrary then
    return _LibStub:GetLibrary("LibDeflate", true)
  end
  return nil
end

local _CFG_DEFLATE = { level = 9 }
local _CFG_LS = { errorOnUnserializableType = false }

local function deep_copy(v, seen)
  if type(v) ~= "table" then return v end
  if seen and seen[v] then return seen[v] end
  seen = seen or {}
  local out = {}
  seen[v] = out
  for k, vv in pairs(v) do
    out[deep_copy(k, seen)] = deep_copy(vv, seen)
  end
  return out
end

local function subtree_ids(rootId)
  local API = _API()
  local TI = _TreeIndex()
  if not (TI and TI.Build) then return { rootId } end
  local idx = TI:Build()
  local childrenMap = (idx and idx.childrenMap) or {}
  local out = {}
  local function walk(id)
    table.insert(out, id)
    local kids = childrenMap[id]
    if type(kids) == "table" then
      for _, cid in ipairs(kids) do
        walk(cid)
      end
    end
  end
  walk(rootId)
  return out
end

local function serialize_lua(val, indent, seen)
  indent = indent or ""
  seen = seen or {}
  local t = type(val)
  if t == "string" then
    return string.format("%q", val)
  elseif t == "number" or t == "boolean" then
    return tostring(val)
  elseif t ~= "table" then
    return "nil"
  end
  if seen[val] then return '"<cycle>"' end
  seen[val] = true
  local parts = {"{\n"}
  local nextIndent = indent .. "  "
  -- stable key order for string keys
  local keys = {}
  for k in pairs(val) do table.insert(keys, k) end
  table.sort(keys, function(a,b)
    if type(a) == type(b) then return tostring(a) < tostring(b) end
    return tostring(type(a)) < tostring(type(b))
  end)
  for _, k in ipairs(keys) do
    local v = val[k]
    local key
    if type(k) == "string" and k:match("^[_%a][_%w]*$") then
      key = k
    else
      key = "[" .. serialize_lua(k, nextIndent, seen) .. "]"
    end
    table.insert(parts, string.format("%s%s = %s,\n", nextIndent, key, serialize_lua(v, nextIndent, seen)))
  end
  table.insert(parts, indent .. "}")
  return table.concat(parts, "")
end


-- Bre printable string contract (v2 only):
--   "!BRE:2!" .. LibDeflate:EncodeForPrint( CompressDeflate( LibSerialize:SerializeEx(bundle) ) )
local _B64URL_ALPH = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local _B64URL_INV = nil

local function _b64url_build_inv()
  if _B64URL_INV then return _B64URL_INV end
  local inv = {}
  for i = 1, #_B64URL_ALPH do
    inv[_B64URL_ALPH:sub(i,i)] = i - 1
  end
  _B64URL_INV = inv
  return inv
end

local function b64url_encode(data)
  if type(data) ~= "string" or data == "" then return "" end
  local t = {}
  local n = #data
  local i = 1
  while i <= n do
    local a = data:byte(i) or 0; i = i + 1
    local b = data:byte(i) or 0; i = i + 1
    local c = data:byte(i) or 0; i = i + 1

    local triple = a * 65536 + b * 256 + c
    local s1 = math.floor(triple / 262144) % 64
    local s2 = math.floor(triple / 4096) % 64
    local s3 = math.floor(triple / 64) % 64
    local s4 = triple % 64

    t[#t+1] = _B64URL_ALPH:sub(s1+1, s1+1)
    t[#t+1] = _B64URL_ALPH:sub(s2+1, s2+1)
    t[#t+1] = _B64URL_ALPH:sub(s3+1, s3+1)
    t[#t+1] = _B64URL_ALPH:sub(s4+1, s4+1)
  end

  local out = table.concat(t)
  -- remove padding-equivalent chars for Base64URL (we never add '=')
  local mod = n % 3
  if mod == 1 then
    out = out:sub(1, -3) -- keep 2 chars
  elseif mod == 2 then
    out = out:sub(1, -2) -- keep 3 chars
  end
  return out
end

local function b64url_decode(data)
  if type(data) ~= "string" or data == "" then return "" end
  data = data:gsub("%s+", "")

  -- pad to multiple of 4 with '=' placeholders
  local mod = #data % 4
  if mod == 2 then
    data = data .. "=="
  elseif mod == 3 then
    data = data .. "="
  elseif mod == 1 then
    return ""
  end

  local inv = _b64url_build_inv()
  local out = {}
  local n = #data
  local i = 1
  while i <= n do
    local c1 = data:sub(i,i); i=i+1
    local c2 = data:sub(i,i); i=i+1
    local c3 = data:sub(i,i); i=i+1
    local c4 = data:sub(i,i); i=i+1

    local s1 = inv[c1]; local s2 = inv[c2]
    local s3 = (c3 == "=") and 64 or inv[c3]
    local s4 = (c4 == "=") and 64 or inv[c4]
    if s1 == nil or s2 == nil or s3 == nil or s4 == nil then
      return ""
    end

    local triple = s1 * 262144 + s2 * 4096 + ( (s3 % 64) * 64 ) + (s4 % 64)
    local a = math.floor(triple / 65536) % 256
    local b = math.floor(triple / 256) % 256
    local c = triple % 256

    out[#out+1] = string.char(a)
    if c3 ~= "=" then out[#out+1] = string.char(b) end
    if c4 ~= "=" then out[#out+1] = string.char(c) end
  end
  return table.concat(out)
end

function IO:ExportSubtreeToString(rootId)
  if type(rootId) ~= "string" then return "" end
  local API = _API()
  if not (API and API.GetData) then return "" end

  local ids = subtree_ids(rootId)
  local bundle = { rootId = rootId, nodes = {} }
  for _, id in ipairs(ids) do
    local d = API:GetData(id)
    if type(d) == "table" then
      bundle.nodes[id] = deep_copy(d)
    end
  end

  local ls = _getLibSerialize()
  local ld = _getLibDeflate()
  if ls and ld and ls.SerializeEx and ld.CompressDeflate and ld.EncodeForPrint then
    local serialized = ls:SerializeEx(_CFG_LS, bundle)
    local compressed = ld:CompressDeflate(serialized, _CFG_DEFLATE)
    local encoded = ld:EncodeForPrint(compressed)
    return "!BRE:2!" .. encoded
  end

  -- v2 only: do not fallback to legacy encoding.
  return ""
end

-- Import (Bre string)
-- Returns: newRootId or nil, err
local function _ensureSaved()
  local DB = Gate and Gate.Get and Gate:Get("DB") or nil
  if DB and DB.EnsureSaved then DB:EnsureSaved()
  elseif DB and DB.InitSaved then DB:InitSaved() end
end

local function _getDisplays()
  local DB = Gate and Gate.Get and Gate:Get("DB") or nil
  if DB and DB.GetDisplays then
    return DB:GetDisplays() or {}
  end
  _G.BreSaved = _G.BreSaved or {}
  _G.BreSaved.displays = _G.BreSaved.displays or {}
  return _G.BreSaved.displays
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
  -- pass1: id mapping
  for id, _ in pairs(bundle.nodes or {}) do
    if type(id) == "string" and id ~= "" then
      map[id] = _genId(id, exists)
      exists[map[id]] = true
    end
  end
  -- pass2: rewrite nodes (deep copy already)
  local newNodes = {}
  for oldId, node in pairs(bundle.nodes or {}) do
    if type(oldId) == "string" and type(node) == "table" then
      local nid = map[oldId] or oldId
      node.id = nid
      if type(node.parent) == "string" and map[node.parent] then
        node.parent = map[node.parent]
      end
      if type(node.controlledChildren) == "table" then
        local cc = {}
        for _, cid in ipairs(node.controlledChildren) do
          if type(cid) == "string" then
            cc[#cc+1] = map[cid] or cid
          end
        end
        node.controlledChildren = cc
      end
      newNodes[nid] = node
    end
  end
  local newRoot = (type(bundle.rootId) == "string" and (map[bundle.rootId] or bundle.rootId)) or nil
  return newRoot, newNodes
end

function IO:ImportString(s)
  if type(s) ~= "string" then return nil, "bad_input" end
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then return nil, "empty" end

  -- Import supports v2 only.
  if s:sub(1, 7) ~= "!BRE:2!" then
    return nil, "unsupported_format"
  end

  local payload = s:sub(8)
  local ld = _getLibDeflate()
  local ls = _getLibSerialize()
  if not (ld and ls and ld.DecodeForPrint and ld.DecompressDeflate and ls.Deserialize) then
    return nil, "missing_libs"
  end
  local decoded = ld:DecodeForPrint(payload)
  if not decoded then return nil, "decode_failed" end
  local decompressed = ld:DecompressDeflate(decoded)
  if not decompressed then return nil, "decompress_failed" end
  local ok, t = ls:Deserialize(decompressed)
  if not ok or type(t) ~= "table" then
    return nil, "deserialize_failed"
  end

  local bundle = t

  if type(bundle) ~= "table" then
    return nil, "bad_bundle"
  end
  if type(bundle.nodes) ~= "table" or type(bundle.rootId) ~= "string" then
    return nil, "bad_bundle"
  end


  _ensureSaved()
  local displays = _getDisplays()
  local exists = {}
  for id, _ in pairs(displays) do exists[id] = true end

  local newRoot, newNodes = _remapBundle(bundle, exists)
  if not newRoot or type(newNodes) ~= "table" then
    return nil, "remap_failed"
  end

  -- attach imported root as top-level
  if type(newNodes[newRoot]) == "table" then
    newNodes[newRoot].parent = nil
  end

  for id, node in pairs(newNodes) do
    displays[id] = node
  end

  local TI = Gate and Gate.Get and Gate:Get("TreeIndex") or nil
  if TI and TI.Build then TI:Build() end

  return newRoot
end
return IO
