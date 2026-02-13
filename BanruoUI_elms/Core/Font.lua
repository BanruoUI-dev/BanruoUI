-- Core/Font.lua
-- Fixed font set for BanruoUI_elms (do not depend on system/ElvUI overrides)

local addonName, Bre = ...
Bre = Bre or {}

local FONT_PATH = "Fonts\\ARKai_T.ttf"

local Font = Bre.Font or {}
Bre.Font = Font

local function CreateOrGet(name)
  local fo = _G[name]
  if not fo then
    fo = CreateFont(name)
  end
  return fo
end

function Font:Init()
  if self._inited then return end
  self._inited = true

  local normal = CreateOrGet("BRE_FontNormal")
  normal:SetFont(FONT_PATH, 13, "")
  normal:SetShadowOffset(1, -1)
  normal:SetShadowColor(0, 0, 0, 0.75)

  local small = CreateOrGet("BRE_FontSmall")
  small:SetFont(FONT_PATH, 12, "")
  small:SetShadowOffset(1, -1)
  small:SetShadowColor(0, 0, 0, 0.75)

  local large = CreateOrGet("BRE_FontLarge")
  large:SetFont(FONT_PATH, 16, "")
  large:SetShadowOffset(1, -1)
  large:SetShadowColor(0, 0, 0, 0.75)

  local hl = CreateOrGet("BRE_FontHighlight")
  hl:SetFont(FONT_PATH, 13, "")
  hl:SetShadowOffset(1, -1)
  hl:SetShadowColor(0, 0, 0, 0.75)

  local hlSmall = CreateOrGet("BRE_FontHighlightSmall")
  hlSmall:SetFont(FONT_PATH, 12, "")
  hlSmall:SetShadowOffset(1, -1)
  hlSmall:SetShadowColor(0, 0, 0, 0.75)
end

function Font:Normal() self:Init(); return "BRE_FontNormal" end
function Font:Small() self:Init(); return "BRE_FontSmall" end
function Font:Large() self:Init(); return "BRE_FontLarge" end
function Font:Highlight() self:Init(); return "BRE_FontHighlight" end
function Font:HighlightSmall() self:Init(); return "BRE_FontHighlightSmall" end
