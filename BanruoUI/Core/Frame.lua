-- Core/Frame.lua
-- Main window: Table（模块入口） + 顶部全局操作（切换/强制还原默认）

local B = BanruoUI

local function CreateButton(parent, text)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetHeight(22)
  btn:SetText(text)
  btn:SetWidth(btn:GetTextWidth() + 28)
  return btn
end

local function EnsureConfirmRestorePopup()
  if StaticPopupDialogs["BANRUOUI_CONFIRM_RESTORE"] then return end
  StaticPopupDialogs["BANRUOUI_CONFIRM_RESTORE"] = {
    text = (B and B.Loc) and B:Loc("POPUP_RESTORE_TEXT") or [[确定要【强制还原默认】吗？

这会：
- 删除该主题在 WA 中的旧内容并重新导入作者默认

可能覆盖你的微调。]],
    button1 = (B and B.Loc) and B:Loc("POPUP_CONTINUE") or "继续",
    button2 = CANCEL,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
      if B and B.ForceRestoreSelectedTheme then
        B:ForceRestoreSelectedTheme()
      end
    end,
  }
end

function B:CreateMainFrame()
  if self.frame then return self.frame end

  EnsureConfirmRestorePopup()

  local f = CreateFrame("Frame", "BanruoUI_MainFrame", UIParent, "BackdropTemplate")
  self.frame = f

  f:SetSize(820, 583)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  f:SetBackdropColor(0, 0, 0, 0.92)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  -- Brand title removed (replaced by logo slot)

  -- Top bar (global)
  local bar = CreateFrame("Frame", nil, f)
  bar:SetPoint("TOPLEFT", 16, -34)
  bar:SetPoint("TOPRIGHT", -16, -34)
  bar:SetHeight(34)

  -- Centered theme selector group
  local themeBox = CreateFrame("Frame", nil, bar)
  themeBox:SetSize(310, 30)
  themeBox:SetPoint("CENTER", bar, "CENTER", -40, 0)

  local themeLabel = themeBox:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Normal() or "GameFontNormal"))
  themeLabel:SetPoint("LEFT", 0, 0)
  themeLabel:SetText((B and B.Loc) and B:Loc("LABEL_THEME") or "主题：")

  -- Logo slot (left of header), aligned to theme text baseline
  local logo = bar:CreateTexture(nil, "OVERLAY")
  logo:SetSize(135, 135)
  logo:SetTexture("Interface\\AddOns\\BanruoUI\\Media\\Logo\\Logo.tga")
  logo:SetPoint("CENTER", themeLabel, "CENTER", -135, 2)

  local dd = CreateFrame("Frame", "BanruoUI_ThemeDropDown", themeBox, "UIDropDownMenuTemplate")
  self.themeDD = dd
  dd:SetPoint("LEFT", themeLabel, "RIGHT", -6, -2)
  UIDropDownMenu_SetWidth(dd, 260)
  UIDropDownMenu_SetText(dd, (B and B.Loc) and B:Loc("DD_NO_THEME_PACK") or "未检测到主题包")

  local btnSwitch = CreateButton(bar, (B and B.Loc) and B:Loc("BTN_SWITCH_THEME") or "切换主题")
  local btnRestore = CreateButton(bar, (B and B.Loc) and B:Loc("BTN_FORCE_RESTORE") or "强制还原默认")
  self.btnSwitch = btnSwitch
  self.btnRestore = btnRestore

  btnSwitch:SetPoint("LEFT", themeBox, "RIGHT", 18, -2)
  btnRestore:SetPoint("LEFT", btnSwitch, "RIGHT", 10, 0)

  -- v2.5 Step0: gear menu (LangSwitch submodule)
  local gear = CreateFrame("Button", nil, bar)
  gear:SetSize(22, 22)
  gear:SetPoint("LEFT", btnRestore, "RIGHT", 8, 0)
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  gear:SetPushedTexture("Interface\\Buttons\\UI-OptionsButton")
  gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  gear:SetScript("OnClick", function()
    if B and B.ShowLangMenu then
      B:ShowLangMenu(gear)
    end
  end)

  gear:SetScript("OnEnter", function()
    if not GameTooltip then return end
    GameTooltip:SetOwner(gear, "ANCHOR_TOPLEFT")
    local tip = (B and B.Loc) and B:Loc("LANG_GEAR_TOOLTIP") or "Settings"
    GameTooltip:SetText(tip)
    GameTooltip:Show()
  end)
  gear:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)

  btnSwitch:SetScript("OnClick", function()
    self:SwitchSelectedTheme()
  end)

  btnRestore:SetScript("OnClick", function()
    StaticPopup_Show("BANRUOUI_CONFIRM_RESTORE")
  end)

  -- Left Table (modules)
  local left = CreateFrame("Frame", nil, f, "BackdropTemplate")
  left:SetPoint("TOPLEFT", 16, -74)
  left:SetPoint("BOTTOMLEFT", 16, 16)
  left:SetWidth(160)
  left:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  left:SetBackdropColor(0, 0, 0, 0.25)
  self.leftPanel = left

  local right = CreateFrame("Frame", nil, f, "BackdropTemplate")
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
  right:SetPoint("BOTTOMRIGHT", -16, 16)
  -- 右侧内容区需要“有边”（Table 按钮切换后的展示页边框）
  right:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  right:SetBackdropColor(0, 0, 0, 0.08)
  right:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.9)
  self.contentPanel = right

  self.moduleButtons = {}
  self.modulePages = {}

  local function buildModuleButtons()
    -- clean old
    for _, btn in ipairs(self.moduleButtons) do btn:Hide() end
    self.moduleButtons = {}

    local y = -12
    for _, def in ipairs(self:GetModules() or {}) do
      local text
      if def and def.titleKey and B and B.Loc then
        text = B:Loc(def.titleKey)
      end
      if not text or text == "" then
        text = def.title or def.id
      end
      local btn = CreateButton(left, text)
      btn:SetPoint("TOPLEFT", 10, y)
      btn:SetWidth(140)
      btn:SetHeight(24)
      y = y - 30

      btn:SetScript("OnClick", function()
        B:ShowModule(def.id)
      end)

      table.insert(self.moduleButtons, btn)
    end
  end

  function B:ShowModule(moduleId)
    if not moduleId then return end
    self.state = self.state or {}
    self.state.activeModuleId = moduleId

    for id, page in pairs(self.modulePages) do
      if page then page:Hide() end
    end

    local def = self:GetModule(moduleId)
    if not def then return end

    if not self.modulePages[moduleId] then
      if type(def.Create) == "function" then
        self.modulePages[moduleId] = def:Create(right)
      else
        local p = CreateFrame("Frame", nil, right)
        p:SetAllPoints(right)
        self.modulePages[moduleId] = p
      end
    end

    local page = self.modulePages[moduleId]
    if page then page:Show() end
    if type(def.OnShow) == "function" then pcall(def.OnShow, def) end
  end

  buildModuleButtons()

  -- default module
  self:ShowModule(self.state and self.state.activeModuleId or "theme_preview")

  -- 初始按钮/显示状态
  if self.ValidateActiveTheme then self:ValidateActiveTheme() end
  if self.UpdateSwitchButtonState then self:UpdateSwitchButtonState() end
  if self.UpdateThemePackLabel then self:UpdateThemePackLabel() end

  return f
end

-- -------------------------
-- 顶部条：按钮禁用口径 + 主题包名展示
-- -------------------------
function B:UpdateSwitchButtonState()
  if not self.btnSwitch then return end
  self.state = self.state or {}

  local pending = self.state.pendingPreviewThemeId
  local active = BanruoUIDB and BanruoUIDB.activeThemeId or nil

  local ok = false
  if pending and self:GetTheme(pending) and (pending ~= active or (self.NeedApplyTheme and self:NeedApplyTheme(pending))) then
    ok = true
  end

  if ok then
    self.btnSwitch:Enable()
    self.btnSwitch:SetAlpha(1)
  else
    self.btnSwitch:Disable()
    self.btnSwitch:SetAlpha(0.5)
  end
end

function B:UpdateThemePackLabel()
  if not self.themePackText then return end

  local name = "未知"
  local active = BanruoUIDB and BanruoUIDB.activeThemeId or nil
  local theme = active and self:GetTheme(active) or nil
  if theme then
    if type(theme.sourceAddon) == "string" and theme.sourceAddon ~= "" then
      name = theme.sourceAddon
    elseif type(theme._sourceAddon) == "string" and theme._sourceAddon ~= "" then
      name = theme._sourceAddon
    elseif type(theme.__sourceAddon) == "string" and theme.__sourceAddon ~= "" then
      name = theme.__sourceAddon
    end
  end

  self.themePackText:SetText("插件名为：" .. tostring(name))
end

-- activeThemeId 变化后刷新整套 UI
function B:OnActiveThemeChanged()
  if self.RefreshThemeDropdown then self:RefreshThemeDropdown() end
  if self.UpdateSwitchButtonState then self:UpdateSwitchButtonState() end
  if self.UpdateThemePackLabel then self:UpdateThemePackLabel() end

  if self.state and self.state.activeModuleId == "theme_preview" then
    if self.UpdatePreviewPanel then self:UpdatePreviewPanel() end
  end

  if self.state and self.state.activeModuleId == "element_switch" then
    local p = self.modulePages and self.modulePages["element_switch"] or nil
    if p and p.Refresh then p:Refresh() end
  end
end

function B:OnThemesChanged()
  if not self.themeDD then return end
  self:RefreshThemeDropdown()
  if self.UpdateSwitchButtonState then self:UpdateSwitchButtonState() end
  if self.UpdateThemePackLabel then self:UpdateThemePackLabel() end
  if self.state and self.state.activeModuleId == "theme_preview" and self.UpdatePreviewPanel then
    self:UpdatePreviewPanel()
  end
end