-- Modules/ThemePreview.lua
-- 主题预览模块：显示主题信息与预览（不直接依赖 WA/ElvUI）

local B = BanruoUI
if not B then return end

local function CreatePreviewPage(parent)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)

  local hint = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Normal() or "GameFontNormal"))
  hint:SetPoint("TOPLEFT", 16, -12)
  hint:SetText(B:Loc('PREVIEW_HINT_TOP'))

  local txt = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Highlight() or "GameFontHighlight"))
  txt:SetPoint("TOPLEFT", 16, -40)
  txt:SetPoint("TOPRIGHT", -16, -40)
  txt:SetJustifyH("LEFT")
  txt:SetJustifyV("TOP")
  txt:SetText("")
  page.previewText = txt

  local tex = page:CreateTexture(nil, "ARTWORK")
  tex:SetPoint("TOPLEFT", 16, -170)
  tex:SetPoint("BOTTOMRIGHT", -16, 16)
  tex:SetColorTexture(0, 0, 0, 0.25)
  page.previewTex = tex

  -- expose to Core/Main.lua preview updater
  B.previewText = txt
  B.previewTex = tex

  return page
end

B:RegisterModule("theme_preview", {
  titleKey = 'MODULE_THEME_PREVIEW',
  order = 0,
  Create = function(self, parent) return CreatePreviewPage(parent) end,
  OnShow = function(self)
    if B and B.UpdatePreviewPanel then B:UpdatePreviewPanel() end
  end,
})
