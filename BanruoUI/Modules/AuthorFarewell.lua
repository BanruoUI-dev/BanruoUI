-- Modules/AuthorFarewell.lua
-- 作者告别：双语告别说明页

local B = BanruoUI
if not B then return end

local function CreatePage(parent)
  local page = CreateFrame('Frame', nil, parent)
  page:SetAllPoints(parent)

  local title = page:CreateFontString(nil, 'OVERLAY', (B.Font and B.Font:Large() or 'GameFontNormalLarge'))
  title:SetPoint('TOPLEFT', 16, -18)
  title:SetText(B:Loc('MODULE_AUTHOR_FAREWELL'))

  local desc = page:CreateFontString(nil, 'OVERLAY', (B.Font and B.Font:Highlight() or 'GameFontHighlight'))
  desc:SetPoint('TOPLEFT', 16, -56)
  desc:SetPoint('TOPRIGHT', -16, -56)
  desc:SetJustifyH('LEFT')
  desc:SetJustifyV('TOP')
  desc:SetText(B:Loc('AUTHOR_FAREWELL_DESC'))

  return page
end

B:RegisterModule('author_farewell', {
  titleKey = 'MODULE_AUTHOR_FAREWELL',
  order = 60,
  Create = function(self, parent)
    return CreatePage(parent)
  end,
})
