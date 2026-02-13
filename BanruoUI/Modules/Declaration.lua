-- Modules/Declaration.lua
-- 纯说明页：更多主题包/开发声明（只做 UI 展示，不接入 Bre 引擎）

local B = BanruoUI
if not B then return end

local URL_GITHUB  = 'https://github.com/BanruoUI-dev/BanruoUI'
local URL_BILIBILI = 'https://www.bilibili.com/video/BV1pcc7zzE5L/'
local URL_YOUTUBE = 'https://www.youtube.com/watch?v=4BI7JlxN_UQ'

local function CreateReadonlyLinkBox(parent, w)
  local eb = CreateFrame('EditBox', nil, parent, 'InputBoxTemplate')
  eb:SetAutoFocus(false)
  eb:SetHeight(22)
  eb:SetWidth(w or 520)
  eb:EnableMouse(true)
  eb:SetScript('OnEscapePressed', function(self) self:ClearFocus() end)
  eb:SetScript('OnEditFocusGained', function(self)
    self:HighlightText()
  end)
  -- 防止用户修改：任何用户输入都回滚为 _value
  eb:SetScript('OnTextChanged', function(self, user)
    if user then
      self:SetText(self._value or '')
      self:HighlightText()
    end
  end)
  eb:SetScript('OnChar', function(self)
    self:SetText(self._value or '')
    self:HighlightText()
  end)
  return eb
end

local function CreatePage(parent)
  local page = CreateFrame('Frame', nil, parent)
  page:SetAllPoints(parent)

  local title = page:CreateFontString(nil, 'OVERLAY', (B.Font and B.Font:Large() or 'GameFontNormalLarge'))
  title:SetPoint('TOPLEFT', 16, -18)
  title:SetText(B:Loc('MODULE_DECLARATION'))
  page._title = title

  local desc = page:CreateFontString(nil, 'OVERLAY', (B.Font and B.Font:Highlight() or 'GameFontHighlight'))
  desc:SetPoint('TOPLEFT', 16, -56)
  desc:SetPoint('TOPRIGHT', -16, -56)
  desc:SetJustifyH('LEFT')
  desc:SetJustifyV('TOP')
  desc:SetText(B:Loc('DECLARATION_DESC'))
  page._desc = desc

  local y = -170
  local function AddLinkRow(labelKey, url)
    local lab = page:CreateFontString(nil, 'OVERLAY', (B.Font and B.Font:Normal() or 'GameFontNormal'))
    lab:SetPoint('TOPLEFT', 16, y)
    lab:SetText(B:Loc(labelKey))

    local eb = CreateReadonlyLinkBox(page, 520)
    eb:SetPoint('TOPLEFT', lab, 'BOTTOMLEFT', -2, -8)
    eb._value = url
    eb:SetText(url)
    eb:ClearFocus()
    eb:HighlightText(0, 0)

    y = y - 64
    return eb
  end

  page._ebGitHub  = AddLinkRow('DECLARATION_GITHUB', URL_GITHUB)
  page._ebBili    = AddLinkRow('DECLARATION_BILIBILI', URL_BILIBILI)
  page._ebYouTube = AddLinkRow('DECLARATION_YOUTUBE', URL_YOUTUBE)

  function page:RefreshTexts()
    title:SetText(B:Loc('MODULE_DECLARATION'))
    desc:SetText(B:Loc('DECLARATION_DESC'))
    -- link labels refresh on language switch (通常会 /reload，但这里保持安全)
    -- 由于 FontString 未保存引用，简单重设：
  end

  return page
end

B:RegisterModule('declaration', {
  titleKey = 'MODULE_DECLARATION',
  order = 50,
  Create = function(self, parent)
    local p = CreatePage(parent)
    self._page = p
    return p
  end,
})
