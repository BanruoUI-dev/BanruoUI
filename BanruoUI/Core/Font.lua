-- Core/Font.lua
-- Fixed font set for BanruoUI (do not depend on system/ElvUI overrides)

local B = BanruoUI
if not B then return end

local FONT_PATH = "Fonts\\ARKai_T.ttf"

local Font = {}

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

  local normal = CreateOrGet("BRUI_FontNormal")
  normal:SetFont(FONT_PATH, 13, "")
  normal:SetShadowOffset(1, -1)
  normal:SetShadowColor(0, 0, 0, 0.75)

  local small = CreateOrGet("BRUI_FontSmall")
  small:SetFont(FONT_PATH, 12, "")
  small:SetShadowOffset(1, -1)
  small:SetShadowColor(0, 0, 0, 0.75)

  local large = CreateOrGet("BRUI_FontLarge")
  large:SetFont(FONT_PATH, 16, "")
  large:SetShadowOffset(1, -1)
  large:SetShadowColor(0, 0, 0, 0.75)

  local hl = CreateOrGet("BRUI_FontHighlight")
  hl:SetFont(FONT_PATH, 13, "")
  hl:SetShadowOffset(1, -1)
  hl:SetShadowColor(0, 0, 0, 0.75)

  local hlSmall = CreateOrGet("BRUI_FontHighlightSmall")
  hlSmall:SetFont(FONT_PATH, 12, "")
  hlSmall:SetShadowOffset(1, -1)
  hlSmall:SetShadowColor(0, 0, 0, 0.75)

  local disSmall = CreateOrGet("BRUI_FontDisableSmall")
  disSmall:SetFont(FONT_PATH, 12, "")
  disSmall:SetShadowOffset(1, -1)
  disSmall:SetShadowColor(0, 0, 0, 0.75)
end

function Font:Normal() self:Init(); return "BRUI_FontNormal" end
function Font:Small() self:Init(); return "BRUI_FontSmall" end
function Font:Large() self:Init(); return "BRUI_FontLarge" end
function Font:Highlight() self:Init(); return "BRUI_FontHighlight" end
function Font:HighlightSmall() self:Init(); return "BRUI_FontHighlightSmall" end
function Font:DisableSmall() self:Init(); return "BRUI_FontDisableSmall" end

B.Font = Font
