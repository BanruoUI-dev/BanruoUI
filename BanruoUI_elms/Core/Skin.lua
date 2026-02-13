-- Bre/Core/Skin.lua
-- Skin system (low-coupling, swappable). UI should call Skin methods via tokens.

local _, Bre = ...
Bre = Bre or {}

local Skin = {}
Bre.Skin = Skin

local function getSkin(name)
  if Bre.Skins and Bre.Skins[name] then return Bre.Skins[name] end
  return nil
end

Skin._activeName = Skin._activeName or "Default"

function Skin:GetActive()
  return getSkin(self._activeName) or getSkin("Default")
end

function Skin:SetActive(name)
  if getSkin(name) then
    self._activeName = name
  else
    self._activeName = "Default"
  end
end

function Skin:GetColor(token)
  local s = self:GetActive()
  local c = s and s.colors and s.colors[token]
  if not c then return 1, 1, 1, 1 end
  return c[1], c[2], c[3], c[4] or 1
end

-- Apply a standard panel backdrop (BackdropTemplate-aware).
function Skin:ApplyPanelBackdrop(frame, opts)
  if not frame then return end
  opts = opts or {}
  local s = self:GetActive()
  local border = (opts.strong and s.borders.PANEL_STRONG) or s.borders.PANEL
  local inset = opts.inset or border.inset or 2
  local borderAlpha = opts.borderAlpha or border.alpha or 0.35

  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = border.edgeFile,
      edgeSize = border.edgeSize,
      insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    local br, bg, bb, ba = self:GetColor("PANEL_BG")
    frame:SetBackdropColor(br, bg, bb, ba)
    local ar, ag, ab, aa = self:GetColor("ACCENT")
    frame:SetBackdropBorderColor(ar, ag, ab, borderAlpha)
  else
    -- Fallback: overlay background only (no border)
    local bgTex = frame._brSkinBgTex
    if not bgTex then
      bgTex = frame:CreateTexture(nil, "BACKGROUND")
      bgTex:SetAllPoints()
      frame._brSkinBgTex = bgTex
    end
    local br, bg, bb, ba = self:GetColor("PANEL_BG")
    bgTex:SetColorTexture(br, bg, bb, ba)
  end
end

function Skin:ApplyButtonBorder(btn, opts)
  if not btn or not btn.SetBackdrop then return end
  opts = opts or {}
  local s = self:GetActive()
  local border = (opts.strong and s.borders.BTN_STRONG) or s.borders.BTN
  btn:SetBackdrop({ edgeFile = border.edgeFile, edgeSize = border.edgeSize })
  local ar, ag, ab = self:GetColor("ACCENT")
  btn:SetBackdropBorderColor(ar, ag, ab, opts.borderAlpha or border.alpha or 0.55)
  local br, bg, bb, ba = self:GetColor(opts.bgToken or "BTN_BG")
  btn:SetBackdropColor(br, bg, bb, ba)
end

function Skin:ApplyFontColor(fs, token)
  if not fs or not fs.SetTextColor then return end
  local r, g, b, a = self:GetColor(token or "ACCENT")
  fs:SetTextColor(r, g, b, a)
end

function Skin:ApplyRowSelected(rowBg)
  if not rowBg then return end
  local r, g, b, a = self:GetColor("ROW_SELECTED_BG")
  if rowBg.SetColorTexture then
    rowBg:SetColorTexture(r, g, b, a)
  end
end
