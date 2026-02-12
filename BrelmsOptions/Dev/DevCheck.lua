-- Bre/Core/DevCheck.lua
-- L1 (dev-only): Constitution self-check hooks (optional, zero-cost when disabled).
-- Enable via: /brs mod DevCheck on  (or /brs devcheck on)

local addonName, Bre = ...
Bre = Bre or {}

-- hard guard: keep zero-cost when not in dev mode
if not (Bre.Const and Bre.Const.DEV_MODE) then
  return
end

local Dev = Bre.DevCheck or {}
Bre.DevCheck = Dev

Dev._enabled = false
Dev._installed = false
Dev._orig = Dev._orig or {}

local function _msg(s)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff3333Bre-DevCheck|r: " .. tostring(s))
  end
end

local function _stack()
  -- WoW: debugstack exists; fallback to debug.traceback if needed.
  local ok, s = pcall(function()
    if debugstack then return debugstack(3, 20, 20) end
    if debug and debug.traceback then return debug.traceback("", 3) end
    return ""
  end)
  return ok and (s or "") or ""
end

local function _callerIsUI(stack)
  return stack:find("Core/UI.lua", 1, true) or stack:find("Core/UI_", 1, true) or stack:find("Options", 1, true)
end

local function _looksLikeOnValueChanged(stack)
  return stack:find("OnValueChanged", 1, true) or stack:find("OnTextChanged", 1, true) or stack:find("OnUpdate", 1, true)
end

local function _wrap(tbl, key, kind, ruleFn)
  if type(tbl) ~= "table" then return end
  local fn = tbl[key]
  if type(fn) ~= "function" then return end
  local id = kind .. ":" .. key
  if Dev._orig[id] then return end

  Dev._orig[id] = fn
  tbl[key] = function(self, ...)
    if Dev._enabled then
      local st = _stack()
      if ruleFn then
        local ok, warn = pcall(ruleFn, st)
        if ok and warn then _msg(warn) end
      else
        if _callerIsUI(st) then
          _msg(kind .. " direct call from UI: " .. key)
        end
      end
    end
    return fn(self, ...)
  end
end

local function _unwrapAll()
  for id, fn in pairs(Dev._orig) do
    local kind, key = id:match("^(.-):(.*)$")
    if kind and key then
      local tbl = nil
      if kind == "Move" then tbl = Bre.Move
      elseif kind == "DB" then tbl = Bre.DB
      elseif kind == "PropertyService" then tbl = Bre.PropertyService
      end
      if type(tbl) == "table" and type(fn) == "function" then
        tbl[key] = fn
      end
    end
  end
end

function Dev:IsEnabled()
  return Dev._enabled and true or false
end

function Dev:SetEnabled(on)
  Dev._enabled = (on and true) or false
  _G.BrelmsSaved = _G.BrelmsSaved or {}
  _G.BrelmsSaved.debug = _G.BrelmsSaved.debug or {}
  _G.BrelmsSaved.debug.devcheck = Dev._enabled
  _msg("devcheck = " .. (Dev._enabled and "on" or "off"))
end

function Dev:Install()
  if Dev._installed then return end
  Dev._installed = true

  -- Move: warn if UI bypasses Actions/Gate and calls Move directly.
  local M = Bre.Move
  if type(M) == "table" then
    local keys = {
      "CommitAnchorTarget","CommitOffsets","CommitFrameLevelMode","CommitFrameStrata",
      "Refresh","RefreshSubtree","ApplyElement","RestoreAll",
      "MoveSibling","SetParentAt","DetachFromParent",
      "RenameNode","DeleteSubtree","DuplicateSubtree",
      "ShowForElement","Hide","EnsureRegion","EnsureRuntimeRoot"
    }
    for _, k in ipairs(keys) do
      _wrap(M, k, "Move")
    end
  end

  -- DB: warn if UI calls DB setters directly.
  local DB = Bre.DB
  if type(DB) == "table" then
    for k, v in pairs(DB) do
      if type(v) == "function" and (k:match("^Set") or k == "InitSaved") then
        _wrap(DB, k, "DB")
      end
    end
  end

  -- PropertyService: warn if commit-like Set happens from OnValueChanged / OnUpdate.
  local PS = Bre.PropertyService
  if type(PS) == "table" then
    _wrap(PS, "Set", "PropertyService", function(st)
      if _looksLikeOnValueChanged(st) then
        return "Commit from non-commit window: PropertyService:Set (likely OnValueChanged/OnUpdate)."
      end
      if _callerIsUI(st) then
        return "UI should not call PropertyService:Set directly."
      end
      return nil
    end)
    _wrap(PS, "Apply", "PropertyService", function(st)
      if _looksLikeOnValueChanged(st) then
        return "Commit from non-commit window: PropertyService:Apply (likely OnValueChanged/OnUpdate)."
      end
      if _callerIsUI(st) then
        return "UI should not call PropertyService:Apply directly."
      end
      return nil
    end)
  end

  -- honor saved flag
  local sv = _G.BrelmsSaved and _G.BrelmsSaved.debug and _G.BrelmsSaved.debug.devcheck
  if sv == true then
    Dev._enabled = true
  end
end

function Dev:Uninstall()
  if not Dev._installed then return end
  Dev._installed = false
  Dev._enabled = false
  _unwrapAll()
end

return Dev
