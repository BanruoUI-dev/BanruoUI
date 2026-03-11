-- Modules/ThemePackGuide.lua
-- 自制主题包说明页（仅展示）

local B = BanruoUI
if not B then return end

local function CreatePage(parent)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)

  local title = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Large() or "GameFontNormalLarge"))
  title:SetPoint("TOPLEFT", 16, -18)
  title:SetText(B:Loc("MODULE_THEMEPACK_GUIDE"))

  local body = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Highlight() or "GameFontHighlight"))
  body:SetPoint("TOPLEFT", 16, -52)
  body:SetPoint("TOPRIGHT", -16, -52)
  body:SetPoint("BOTTOMLEFT", 16, 16)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  body:SetText(B:Loc("THEMEPACK_GUIDE_BODY"))

  page._title = title
  page._body = body

  function page:RefreshTexts()
    title:SetText(B:Loc("MODULE_THEMEPACK_GUIDE"))
    body:SetText(B:Loc("THEMEPACK_GUIDE_BODY"))
  end

  return page
end

B:RegisterModule("theme_pack_guide", {
  titleKey = "MODULE_THEMEPACK_GUIDE",
  order = 55,
  Create = function(self, parent)
    local p = CreatePage(parent)
    self._page = p
    return p
  end,
})
