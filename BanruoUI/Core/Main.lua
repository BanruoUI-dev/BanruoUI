-- Core/Main.lua
-- v1.5.0：
-- 1) 仅管理 WA（A+B 兜底：首次导入初始化 + 已初始化隐藏式切换）
-- 2) 主题下拉：展开用于“预览选择”（临时态 pendingPreviewThemeId），收起/失焦必须回显“当前已生效主题”
-- 3) 仅点击【切换主题】且成功后才写入 BanruoUIDB.activeThemeId

local B = BanruoUI

local function norm(id) return B._normalizeId(id) end

local function ensureDB()
  BanruoUIDB = BanruoUIDB or {}
  BanruoUIDB.activeThemeId = BanruoUIDB.activeThemeId or nil
  BanruoUIDB.themeInit = BanruoUIDB.themeInit or {}
end

local function getActiveThemeId()
  ensureDB()
  return BanruoUIDB.activeThemeId
end

-- Dropdown close behavior: DropDownList1 is shared by all dropdowns
local function ensureDropdownHooks()
  if B._ddHooksInstalled then return end
  local list = _G and _G["DropDownList1"] or nil
  if not list or type(list.HookScript) ~= "function" then return end

  list:HookScript("OnShow", function()
    -- UIDROPDOWNMENU_OPEN_MENU 指向当前打开的 dropdown
    B._openDropdown = _G and _G.UIDROPDOWNMENU_OPEN_MENU or nil
  end)

  list:HookScript("OnHide", function()
    if B and B._openDropdown == B.themeDD and B.RefreshThemeDropdownCollapsed then
      B:RefreshThemeDropdownCollapsed()
    end
    B._openDropdown = nil
  end)

  B._ddHooksInstalled = true
end

-- -------------------------
-- Theme dropdown
-- -------------------------
function B:RefreshThemeDropdown()
  local dd = self.themeDD
  if not dd then return end

  local themes = self:GetThemes()

  ensureDropdownHooks()

  UIDropDownMenu_Initialize(dd, function(_, level)
    local info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true

    if #themes == 0 then
      info.text = B:Loc("DD_NO_THEME_PACK")
      info.disabled = true
      UIDropDownMenu_AddButton(info, level)
      return
    end

    for _, t in ipairs(themes) do
      local id = t.themeId or t.id
      info.text = t.title or id or "Theme"
      info.func = function()
        self:SetPendingPreviewTheme(id)
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  -- pending preview default
  self.state = self.state or {}
  local pending = self.state.pendingPreviewThemeId
  local active = getActiveThemeId()
  if not pending then
    pending = active
    if not pending and #themes > 0 then
      pending = themes[1].themeId or themes[1].id
    end
    self.state.pendingPreviewThemeId = pending
  end

  -- 收起状态：必须回显“当前已生效主题”
  self:RefreshThemeDropdownCollapsed()

  -- 预览区使用 pending（不代表已切换）
  self:UpdatePreviewPanel()
  if self.UpdateSwitchButtonState then self:UpdateSwitchButtonState() end
  if self.UpdateThemePackLabel then self:UpdateThemePackLabel() end
end

function B:RefreshThemeDropdownCollapsed()
  local dd = self.themeDD
  if not dd then return end

  local themes = self:GetThemes()
  if #themes == 0 then
    UIDropDownMenu_SetText(dd, B:Loc("DD_NO_THEME_PACK"))
    return
  end

  local active = getActiveThemeId()
  local t = active and self:GetTheme(active) or nil
  if t then
    UIDropDownMenu_SetText(dd, t.title)
  else
    UIDropDownMenu_SetText(dd, B:Loc("DD_UNKNOWN"))
  end
end

-- 下拉展开时选择主题：仅用于预览（临时态），不写入 DB
function B:SetPendingPreviewTheme(themeId)
  themeId = norm(themeId)
  local theme = themeId and self:GetTheme(themeId) or nil
  if not theme then return end

  self.state = self.state or {}
  self.state.pendingPreviewThemeId = themeId

  -- 展开状态允许回显预览选择（收起/失焦会被 hook 回滚到 active）
  if self.themeDD then
    UIDropDownMenu_SetText(self.themeDD, theme.title)
  end

  self:UpdatePreviewPanel()
  if self.UpdateSwitchButtonState then self:UpdateSwitchButtonState() end
end

-- -------------------------
-- Preview (ThemePreview module reads B.previewText/B.previewTex)
-- -------------------------
function B:UpdatePreviewPanel()
  local id = self.state and self.state.pendingPreviewThemeId or nil
  local theme = id and self:GetTheme(id) or nil

  if not theme then
    if self.previewText then
      self.previewText:SetText(B:Loc("PREVIEW_NO_THEME_PACK"))
    end
    if self.previewTex then
      self.previewTex:SetTexture(nil)
      self.previewTex:SetColorTexture(0,0,0,0.25)
    end
    return
  end

  local lines = {}

  -- Theme packs may optionally provide bilingual fields (e.g., title_en / author_en)
  local loc = self.__activeLocale
  local title = theme.title
  local author = theme.author
  if loc == "enUS" then
    if theme.title_en and theme.title_en ~= "" then title = theme.title_en end
    if theme.author_en and theme.author_en ~= "" then author = theme.author_en end
  end

  table.insert(lines, title or "")
  if author and author ~= "" then table.insert(lines, B:Loc("PREVIEW_AUTHOR_LINE", author)) end
  if theme.version and theme.version ~= "" then table.insert(lines, B:Loc("PREVIEW_VERSION_LINE", theme.version)) end

    local hasBRE = (theme.bre and theme.bre.main and theme.bre.main ~= "") and true or false

  table.insert(lines, "")
  table.insert(lines, B:Loc("PREVIEW_INCLUDES_LINE", hasBRE and B:Loc("PREVIEW_INCLUDES_BRE") or B:Loc("PREVIEW_INCLUDES_NONE")))

  table.insert(lines, "")
  table.insert(lines, B:Loc("PREVIEW_TIP_APPLY_REQUIRED"))
  table.insert(lines, B:Loc("PREVIEW_TIP_SWITCH_NO_OVERRIDE"))
  table.insert(lines, B:Loc("PREVIEW_TIP_ELVUI_MANUAL"))

  if self.previewText then
    self.previewText:SetText(table.concat(lines, "\n"))
  end

  if self.previewTex then
    if theme.preview and theme.preview ~= "" then
      self.previewTex:SetTexture(theme.preview)
    else
      self.previewTex:SetTexture(nil)
      self.previewTex:SetColorTexture(0,0,0,0.25)
    end
  end
end

-- -------------------------
-- Switch / Force Restore
-- -------------------------
local function getThemeById(id)
  id = norm(id)
  return id and B:GetTheme(id) or nil
end

local function getBreCfg(theme)
  if theme and type(theme.bre) == "table" then return theme.bre end
  return nil
end

local function getBREString(theme)
  local cfg = getBreCfg(theme)
  local v = cfg and cfg.main or nil
  if not v or v == "" then return nil end
  -- allow either registry id (GetBRE) or raw bundle string.
  if type(v) == "string" and v:match("^%s*!BRE:2!") then
    return v
  end
  local def = (B.GetBRE and B:GetBRE(v)) or nil
  if not def or type(def.data) ~= "string" then return nil end
  if not def.data:match("^%s*!BRE:2!") then return nil end
  return def.data
end

local function breNeedInit(themeId, theme)
  ensureDB()
  local cfg = getBreCfg(theme)
  if not cfg or not cfg.main or cfg.main == "" then return false end

  local init = (BanruoUIDB.themeInit and BanruoUIDB.themeInit[themeId] == true) and true or false
  if not init then return true end

  local gn = cfg.groupName
  if type(gn) == "string" and gn ~= "" then
    if B.BRE_RootExists and not B:BRE_RootExists(gn) then
      return true -- 兜底：DB 说已初始化，但 Bre 根组不存在
    end
  end

  return false
end


function B:NeedApplyTheme(themeId)
  themeId = norm(themeId)
  if not themeId then return false end
  local theme = getThemeById(themeId)
  if not theme then return false end
  return breNeedInit(themeId, theme) and true or false
end

function B:ValidateActiveTheme()
  ensureDB()
  local activeId = norm(BanruoUIDB.activeThemeId)
  if not activeId then return end
  -- 兜底：历史“假成功”遗留（activeThemeId 已写入，但实际未完成初始化/根组丢失）
  if self:NeedApplyTheme(activeId) then
    BanruoUIDB.activeThemeId = nil
    BanruoUIDB.activeBREGroupName = nil
    BanruoUIDB.activeWAGroupName = nil
  end
end



local function setRootNever(gn, never)
  -- v2.1：切换主题只管 Root（不递归、不关子树），避免误伤其它主题。
  if not (B.BRE_SetNeverById and B.BRE_RefreshLoads) then
    return false, B:Loc("ERR_WA_ADAPTER_NOT_READY")
  end
  if type(gn) ~= "string" or gn == "" then
    return true, B:Loc("ERR_WA_NO_GROUPNAME")
  end

  local rootId = (B.BRE_FindRootId and B:BRE_FindRootId(gn)) or nil
  if not rootId then
    return false, "root_not_found"
  end

  local okRoot = B:BRE_SetNeverById(rootId, never)

  if B.BRE_RebuildDisplays and rootId then
    B:BRE_RebuildDisplays({rootId})
  elseif B.BRE_RefreshLoads then
    B:BRE_RefreshLoads()
  end

  return okRoot, okRoot and "ok" or "set_never_failed"
end

local function doBRESwitch(oldTheme, newTheme, newThemeId, mode)
  local newCfg = getBreCfg(newTheme)
  if not newTheme or not newCfg or not newCfg.main or newCfg.main == "" then
    return true, B:Loc("ERR_THEME_NO_WA_REF")
  end

  local oldCfg = getBreCfg(oldTheme)
  local newGN = newCfg.groupName
  local oldGN = oldCfg and oldCfg.groupName or nil

  if mode == "force" then
    -- 强制还原默认：删除式清理 + 重新导入
    if B.BRE_DeleteByKeyword and type(newGN) == "string" and newGN ~= "" then
      local okDel, msgDel = B:BRE_DeleteByKeyword(newGN)
      if not okDel then return false, msgDel end
    end
    local breStr = getBREString(newTheme)
    if not breStr then return false, B:Loc("ERR_WA_REG_MISSING") end
    local newRoot, msgImp = B:BRE_Import(breStr)
    if not newRoot then return false, msgImp end

    ensureDB()
    BanruoUIDB.themeInit[newThemeId] = true

    -- 切到新主题（隐藏旧/显示新）
    if type(oldGN) == "string" and oldGN ~= "" and oldGN ~= newGN then
      local okOld, msgOld = setRootNever(oldGN, true)

      if not okOld then return false, msgOld end
    end
    if type(newGN) == "string" and newGN ~= "" then
      local okNew, msgNew = setRootNever(newGN, false)

      if not okNew then return false, msgNew end
    end

    return true, B:Loc("WA_FORCE_RESTORE_OK")
  end

  -- 普通切换：A+B 判定，必要时首次导入；然后做隐藏式切换（root-only + parent 残留兜底）
  local needInit = breNeedInit(newThemeId, newTheme)
  if needInit then
    local breStr = getBREString(newTheme)
    if not breStr then return false, B:Loc("ERR_WA_REG_MISSING") end
    local newRoot, msgImp = B:BRE_Import(breStr)
    if not newRoot then return false, msgImp end

    ensureDB()
    BanruoUIDB.themeInit[newThemeId] = true
  end

  if type(oldGN) == "string" and oldGN ~= "" and oldGN ~= newGN then
    local okOld, msgOld = setRootNever(oldGN, true)

    if not okOld then return false, msgOld end
  end
  if type(newGN) == "string" and newGN ~= "" then
    local okNew, msgNew = setRootNever(newGN, false)

    if not okNew then return false, msgNew end
  end

  if needInit then
    return true, B:Loc("WA_FIRST_IMPORT_OK")
  end
  return true, B:Loc("WA_HIDDEN_SWITCH_OK")
end

local function finalizeSuccess(themeId, theme)
  ensureDB()
  BanruoUIDB.activeThemeId = themeId
  local cfg = getBreCfg(theme)
  if cfg and cfg.groupName then
    BanruoUIDB.activeBREGroupName = cfg.groupName
    -- backward compatible field (legacy): keep updated so other modules won't break
    BanruoUIDB.activeWAGroupName = cfg.groupName
  end
end

local function runApply(mode)
  ensureDB()

  local themeId = B.state and B.state.pendingPreviewThemeId or nil
  themeId = norm(themeId)
  local theme = getThemeById(themeId)
  if not theme then
    B:Print(B:Loc("PRINT_NO_THEME_PACK"))
    return
  end

  -- 口径：pending == active 时不允许切换
  if mode == "switch" and themeId == BanruoUIDB.activeThemeId then
    B:Print(B:Loc("PRINT_ALREADY_ACTIVE"))
    return
  end

  local oldId = BanruoUIDB.activeThemeId
  local oldTheme = oldId and getThemeById(oldId) or nil

  local okBRE, msgBRE = doBRESwitch(oldTheme, theme, themeId, mode)
  if not okBRE then
    B:Print(B:Loc("PRINT_WA_FAIL", tostring(msgBRE)))
    return
  end

  finalizeSuccess(themeId, theme)

  -- UI 刷新：activeThemeId 发生变化
  if B.OnActiveThemeChanged then
    pcall(B.OnActiveThemeChanged, B)
  else
    -- 兜底：至少把下拉收起回显与按钮状态刷新
    if B.RefreshThemeDropdownCollapsed then B:RefreshThemeDropdownCollapsed() end
    if B.UpdateSwitchButtonState then B:UpdateSwitchButtonState() end
    if B.UpdateThemePackLabel then B:UpdateThemePackLabel() end
  end

  B:Print(B:Loc("PRINT_SWITCH_OK", tostring(theme.title or themeId)))
  B:Print(B:Loc("PRINT_WA_RESULT", tostring(msgBRE)))
  B:Print(B:Loc("PRINT_RELOAD_SUGGEST"))
end

function B:SwitchSelectedTheme()
  runApply("switch")
end

function B:ForceRestoreSelectedTheme()
  runApply("force")
end

-- -------------------------
-- Events
-- -------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, name)
  if name ~= B.addonName then return end

  -- activeThemeId 兜底校验（避免历史“假成功”导致 UI 锁死）
  if B.ValidateActiveTheme then
    B:ValidateActiveTheme()
  end


  B:CreateMainFrame()
  B:RefreshThemeDropdown()

  if B.frame then
    B.frame:Hide()
  end

  B:Print(B:Loc("PRINT_LOADED_HINT"))
end)