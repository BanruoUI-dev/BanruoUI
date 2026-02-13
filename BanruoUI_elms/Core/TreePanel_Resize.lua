-- Bre/Core/TreePanel_Resize.lua
-- Optional tree panel resize module (UI-only). v2.7.40

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate
local function _API() return Gate:Get('API_Data') end
local function _UI() return Gate:Get('UI') end

Bre.TreePanel_Resize = Bre.TreePanel_Resize or {}
local M = Bre.TreePanel_Resize

-- L2 module capability declaration (v1.5 mandatory)
M.runtime_required = false
M.authoring_required = true

-- Feature flag (can be toggled by other modules later)
M.enabled = true

-- Bounds for the left tree width
M.MIN_W = 200
M.MAX_W = 520

local function clamp(v, lo, hi)
  v = tonumber(v) or lo
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- Core-only API surface (requested):
--   Bre.GetTreeWidth() / Bre.SetTreeWidth(w)
-- This module only consumes them.

function M:ApplyWidthPreview(frame, w)
  if not frame or not frame._body or not frame._body._inner then return end
  local inner = frame._body._inner
  local left = inner._left
  if not left then return end

  w = clamp(w, self.MIN_W, self.MAX_W)
  left:SetWidth(w)
  -- Preview only: DO NOT write SavedVariables/DB here.
end

function M:CommitWidth(frame, w)
  if not frame or not frame._body or not frame._body._inner then return end
  local inner = frame._body._inner
  local left = inner._left
  if not left then return end

  w = clamp(w, self.MIN_W, self.MAX_W)
  local API = _API(); if API and API.SetTreeWidth then API:SetTreeWidth(w) end
end

-- Backward compat: ApplyWidth defaults to preview+commit (non-drag callers)
function M:ApplyWidth(frame, w, commit)
  self:ApplyWidthPreview(frame, w)
  if commit ~= false then
    self:CommitWidth(frame, w)
  end
end


function M:Attach(frame)
  if not self.enabled then return end
  if not frame or not frame._body or not frame._body._inner then return end

  local inner = frame._body._inner
  local left = inner._left
  if not left then return end

  -- Apply saved width once
  local API = _API(); local initW = (API and API.GetTreeWidth and API:GetTreeWidth()) or left:GetWidth() or 260
  self:ApplyWidth(frame, initW)

  if inner._treeResizer then
    return
  end

  local resizer = CreateFrame("Frame", nil, inner)
  resizer:SetFrameStrata(frame:GetFrameStrata())
  resizer:SetFrameLevel(left:GetFrameLevel() + 20)
  resizer:SetPoint("TOPLEFT", left, "TOPRIGHT", 6, 0)
  resizer:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 6, 0)
  resizer:SetWidth(8)
  resizer:EnableMouse(true)
  resizer:SetMouseClickEnabled(true)
  resizer:SetClampedToScreen(false)

  local tex = resizer:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture("Interface/Buttons/WHITE8x8")
  tex:SetVertexColor(1, 0.82, 0, 0.08)
  resizer._tex = tex

  resizer:SetScript("OnEnter", function(self)
    self._tex:SetVertexColor(1, 0.82, 0, 0.16)
    if self.SetCursor then self:SetCursor("SIZEWE") end
  end)
  resizer:SetScript("OnLeave", function(self)
    self._tex:SetVertexColor(1, 0.82, 0, 0.08)
    if self.SetCursor then self:SetCursor(nil) end
  end)

  resizer:SetScript("OnMouseDown", function(self, btn)
    if btn ~= "LeftButton" then return end
    self._dragging = true
    self._startX = select(1, GetCursorPosition())
    self._startScale = UIParent:GetEffectiveScale() or 1
    self._startW = left:GetWidth()
    self:SetScript("OnUpdate", function(s)
      if not s._dragging then return end
      local x = select(1, GetCursorPosition())
      local dx = (x - s._startX) / (s._startScale or 1)
      local newW = (s._startW or 260) + dx
      s._pendingW = newW
      M:ApplyWidthPreview(frame, newW)
    end)
  end)

  resizer:SetScript("OnMouseUp", function(self, btn)
    if btn ~= "LeftButton" then return end
    self._dragging = false
    self:SetScript("OnUpdate", nil)
    local w = self._pendingW or (left and left:GetWidth())
    if w then M:CommitWidth(frame, w) end
    self._pendingW = nil
  end)

  inner._treeResizer = resizer
end
