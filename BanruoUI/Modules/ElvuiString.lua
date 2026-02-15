-- Modules/ElvuiString.lua
-- ElvUI 适配字符串（仅复制/展示）
-- 口径：不进入自动化导入链路，不调用 ElvUI API；字符串来自主题包写死提供。

local B = BanruoUI
if not B then return end


local function CreateButton(parent, text)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetHeight(22)
  btn:SetText(text)
  btn:SetWidth(btn:GetTextWidth() + 28)
  return btn
end

local function SetButtonText(btn, text)
  btn:SetText(text)
  btn:SetWidth(btn:GetTextWidth() + 28)
end

local function CreateElvuiStringPage(parent)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)

  local title = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Large() or "GameFontNormalLarge"))
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText(B:Loc('MODULE_ELVUI_STRING'))

  local hint = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:HighlightSmall() or "GameFontHighlightSmall"))
  hint:SetPoint("TOPLEFT", 16, -40)
  hint:SetPoint("TOPRIGHT", -16, -40)
  hint:SetJustifyH("LEFT")
  hint:SetText(B:Loc('ELVUI_STRING_HINT'))

  local meta = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Highlight() or "GameFontHighlight"))
  meta:SetPoint("TOPLEFT", 16, -62)
  meta:SetPoint("TOPRIGHT", -16, -62)
  meta:SetJustifyH("LEFT")
  meta:SetText("")
  page.metaText = meta

  -- Source selector (ElvUI / NDui)
  page.source = "elvui"
  local btnCopy = CreateButton(page, B:Loc('BTN_COPY'))
  btnCopy:SetPoint("TOPRIGHT", -18, -12)

  local btnSourceNDui = CreateButton(page, B:Loc('ELVUI_STRING_SOURCE_NDUI'))
  btnSourceNDui:SetPoint("RIGHT", btnCopy, "LEFT", -10, 0)

  local btnSourceElvui = CreateButton(page, B:Loc('ELVUI_STRING_SOURCE_ELVUI'))
  btnSourceElvui:SetPoint("RIGHT", btnSourceNDui, "LEFT", -6, 0)

  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, -90)
  scroll:SetPoint("BOTTOMRIGHT", -36, 16)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetTextColor(1, 1, 1, 1)
  edit:SetAutoFocus(false)
  edit:EnableMouse(true)
  edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
  edit:SetWidth(560)
  edit:SetHeight(2000) -- 足够大，滚动交给 ScrollFrame
  edit:SetText("")
  scroll:SetScrollChild(edit)
  page.editBox = edit

  -- 根据 ScrollFrame 宽度自适应 EditBox 宽度
  scroll:SetScript("OnSizeChanged", function()
  local w = scroll:GetWidth() or 560
  edit:SetWidth(math.max(200, w - 20))
  edit:SetHeight(2000)  -- 新增这行
end)

  local function UpdateSourceButtons()
    -- Selected source button: visually "pressed" by disabling it.
    if page.source == "elvui" then
      btnSourceElvui:Disable(); btnSourceElvui:SetAlpha(0.9)
      btnSourceNDui:Enable();  btnSourceNDui:SetAlpha(1)
    else
      btnSourceNDui:Disable(); btnSourceNDui:SetAlpha(0.9)
      btnSourceElvui:Enable(); btnSourceElvui:SetAlpha(1)
    end
  end

  function page:Refresh()
    -- Refresh localized texts (language switch uses ReloadUI, but keep safe)
    title:SetText(B:Loc('MODULE_ELVUI_STRING'))
    hint:SetText(B:Loc('ELVUI_STRING_HINT'))
    SetButtonText(btnCopy, B:Loc('BTN_COPY'))
    SetButtonText(btnSourceElvui, B:Loc('ELVUI_STRING_SOURCE_ELVUI'))
    SetButtonText(btnSourceNDui, B:Loc('ELVUI_STRING_SOURCE_NDUI'))

    local active = BanruoUIDB and BanruoUIDB.activeThemeId or nil
    local theme = active and B:GetTheme(active) or nil

    local profileId = theme and theme.elvui and theme.elvui.profile or nil
    local profileName = theme and theme.elvui and theme.elvui.profileName or nil

    -- 优先：主题包直接提供 importString（最直观）
    local str = theme and theme.elvui and theme.elvui.importString or nil

    -- 兼容：主题包通过 B:RegisterElvUIProfile({id,name,data}) 注册仓库（不需要在 RegisterTheme 里粘贴长字符串）
    if (type(str) ~= "string" or str == "") and profileId then
      local prof = B:GetElvUIProfile(profileId)
      if prof and type(prof.data) == "string" and prof.data ~= "" then
        str = prof.data
        if (not profileName or profileName == "") and prof.name then
          profileName = prof.name
        end
      end
    end

    if not active or not theme then
      meta:SetText(B:Loc('ELVUI_STRING_META_NO_ACTIVE'))
      edit:SetText(B:Loc('ELVUI_STRING_BODY_NO_ACTIVE'))
      btnCopy:Disable(); btnCopy:SetAlpha(0.5)
      btnSourceElvui:Disable(); btnSourceElvui:SetAlpha(0.5)
      btnSourceNDui:Disable();  btnSourceNDui:SetAlpha(0.5)
      return
    end

    local metaLine = string.format(B:Loc('ELVUI_STRING_META_ACTIVE_FMT'), tostring(theme.title or active))
    if profileName and profileName ~= "" then
      metaLine = metaLine .. "   |   " .. string.format(B:Loc('ELVUI_STRING_META_PROFILE_FMT'), tostring(profileName))
    end
    meta:SetText(metaLine)

    -- Source output
    if page.source == "ndui" then
      edit:SetText(B:Loc('ELVUI_STRING_NDUI_PLACEHOLDER'))
      edit:SetCursorPosition(0)
      btnCopy:Enable(); btnCopy:SetAlpha(1)
      UpdateSourceButtons()
      return
    end

    -- ElvUI
    if type(str) ~= "string" or str == "" then
      edit:SetText(B:Loc('ELVUI_STRING_BODY_NO_STRING'))
      btnCopy:Disable(); btnCopy:SetAlpha(0.5)
      UpdateSourceButtons()
      return
    end

    edit:SetText(str)
    edit:SetCursorPosition(0)
    btnCopy:Enable(); btnCopy:SetAlpha(1)
    UpdateSourceButtons()
  end

  btnSourceElvui:SetScript("OnClick", function()
    page.source = "elvui"
    page:Refresh()
  end)

  btnSourceNDui:SetScript("OnClick", function()
    page.source = "ndui"
    page:Refresh()
  end)

  -- One-click: Select All + Copy (user presses Ctrl+C)
  btnCopy:SetScript("OnClick", function()
    edit:SetFocus()
    edit:HighlightText()
    if B and B.Print then B:Print(B:Loc('ELVUI_STRING_COPY_NOTICE')) end
  end)

  page:Refresh()
  return page
end

B:RegisterModule("elvui_string", {
  titleKey = 'MODULE_ELVUI_STRING',
  order = 40,
  Create = function(self, parent) return CreateElvuiStringPage(parent) end,
  OnShow = function(self)
    local p = B and B.frame and B.frame.modulePages and B.frame.modulePages["elvui_string"] or nil
    if not p and B and B.modulePages then p = B.modulePages["elvui_string"] end
    if p and p.Refresh then p:Refresh() end
  end,
})
