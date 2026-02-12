-- Modules/ElementSwitch.lua
-- v1.5 唯一功能交付：元素开关（Element Switch）
-- 口径：模块不直接调用 WeakAuras 全局，只通过 Adapter（Adapters/WeakAuras.lua）暴露接口。

local B = BanruoUI
if not B then return end

-- -------------------------
-- 写死面板结构（分类/元素）
-- -------------------------
local SCHEMA = {
  {
    title = "左上",
    elements = {
      { key = "top_left_outer", label = "外框" },
      { key = "top_left_round_bg", label = "圆形背景" },
      { key = "top_left_npc", label = "NPC" },
    },
  },
  {
    title = "小地图",
    elements = {
      { key = "minimap_outer", label = "外框" },
      { key = "minimap_bg", label = "背景" },
    },
  },
  {
    title = "动作条",
    elements = {
      { key = "actionbar_bg", label = "背景" },
      { key = "actionbar_left_orb", label = "左能量球" },
      { key = "actionbar_right_orb", label = "右能量球" },
      { key = "actionbar_left_deco", label = "左球装饰" },
      { key = "actionbar_right_deco", label = "右球装饰" },
    },
  },
  {
    title = "散件装饰",
    elements = {
      { key = "misc_top_strip", label = "顶部材质条" },
      { key = "misc_bottom_strip", label = "底部材质条" },
      { key = "misc_deco1", label = "装饰1" },
      { key = "misc_deco2", label = "装饰2" },
    },
  },
}

-- -------------------------
-- DB helpers
-- -------------------------
local function ensureDB()
  BanruoUIDB = BanruoUIDB or {}
  BanruoUIDB.elementSwitch = BanruoUIDB.elementSwitch or {}
end

local function getThemeContext()
  ensureDB()
  local themeId = BanruoUIDB.activeThemeId
  if not themeId then return nil, nil, nil end
  local theme = B:GetTheme(themeId)
  local rootName = (theme and theme.bre and theme.bre.groupName) or nil
  return themeId, theme, rootName
end

local function getElemState(themeId, key)
  ensureDB()
  BanruoUIDB.elementSwitch[themeId] = BanruoUIDB.elementSwitch[themeId] or {}
  BanruoUIDB.elementSwitch[themeId][key] = BanruoUIDB.elementSwitch[themeId][key] or {}
  return BanruoUIDB.elementSwitch[themeId][key]
end

-- -------------------------
-- Element Switch operations (via Adapter)
-- -------------------------
function B:ES_SetEnabled(themeId, elemKey, enabled, rootName)
  if not themeId or not elemKey then return end
  local st = getElemState(themeId, elemKey)
  st.enabled = enabled and true or false

  local auraId = st.auraId
  if not auraId or auraId == "" then
    -- 未绑定 Display 时，仅记录状态
    return
  end

  if self.BRE_SetNeverById then
    -- enabled=true -> never=false
    self:BRE_SetNeverById(auraId, not st.enabled)
    if self.BRE_RebuildDisplays then
      self:BRE_RebuildDisplays({auraId})
    elseif self.BRE_RefreshLoads then
      self:BRE_RefreshLoads()
    end
  else
    self:Print("Bre 适配层未就绪（无法切换元素）")
  end
end

function B:ES_SetAuraForElement(themeId, elemKey, newAuraId, rootName)
  if not themeId or not elemKey then return end
  local st = getElemState(themeId, elemKey)
  local oldAuraId = st.auraId

  if newAuraId == "" then newAuraId = nil end
  st.auraId = newAuraId

  if not self.BRE_SetNeverById then
    self:Print("Bre 适配层未就绪（无法绑定元素 Variant）")
    return
  end

  -- 若当前元素为“显示”，切换 Variant 时：隐藏旧 / 显示新
  local shouldShow = (st.enabled ~= false)

  if oldAuraId and oldAuraId ~= "" and oldAuraId ~= newAuraId and shouldShow then
    self:BRE_SetNeverById(oldAuraId, true)
  end

  if newAuraId and newAuraId ~= "" and shouldShow then
    self:BRE_SetNeverById(newAuraId, false)
  end

  local rebuild = {}
  if oldAuraId and oldAuraId ~= "" then table.insert(rebuild, oldAuraId) end
  if newAuraId and newAuraId ~= "" then table.insert(rebuild, newAuraId) end
  if self.BRE_RebuildDisplays and #rebuild > 0 then
    self:BRE_RebuildDisplays(rebuild)
  elseif self.BRE_RefreshLoads then
    self:BRE_RefreshLoads()
  end
end

-- -------------------------
-- UI building
-- -------------------------
local function CreateButton(parent, text)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetHeight(22)
  btn:SetText(text)
  btn:SetWidth(btn:GetTextWidth() + 28)
  return btn
end

local function BuildAuraOptions(rootName)
  local opts = {}
  if not rootName or rootName == "" then return opts end
  if not (B and B.BRE_ScanRootIndex) then return opts end

  local idx = B:BRE_ScanRootIndex(rootName)
  local list = idx and idx.snapshot or {}
  table.sort(list, function(a, b)
    return tostring(a.name or a.id) < tostring(b.name or b.id)
  end)

  for _, it in ipairs(list) do
    if type(it) == "table" then
      local id = it.id
      if id and id ~= "" then
        local title = it.name or id
        if it.isGroup then
          title = "[组] " .. title
        end
        table.insert(opts, { id = id, title = title })
      end
    end
  end

  return opts
end

local function CreateElementRow(parent, y, elem, themeId, auraOptions, rootName)
  local row = CreateFrame("Frame", nil, parent)
  row:SetPoint("TOPLEFT", 0, y)
  row:SetPoint("TOPRIGHT", 0, y)
  row:SetHeight(26)

  local check = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
  check:SetPoint("LEFT", 6, 0)

  local label = row:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Highlight() or "GameFontHighlight"))
  label:SetPoint("LEFT", check, "RIGHT", 2, 1)
  label:SetText(elem.label or elem.key)

  local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
  dd:SetPoint("LEFT", label, "RIGHT", -8, -2)
  UIDropDownMenu_SetWidth(dd, 290)
  UIDropDownMenu_JustifyText(dd, "LEFT")

  row._elemKey = elem.key
  row._themeId = themeId

  local function refresh()
    local st = getElemState(themeId, elem.key)

    local enabled = st.enabled
    local auraId = st.auraId

    -- DB 未写入 enabled 时：尽量从 WA 当前 never 推断
    if enabled == nil and auraId and auraId ~= "" and B and B.BRE_ScanRootIndex and B.BRE_IsNeverById then
      local idx = B:BRE_ScanRootIndex(rootName)
      local never = B:BRE_IsNeverById(auraId, idx)
      if never ~= nil then enabled = not never end
    end
    if enabled == nil then enabled = true end

    check:SetChecked(enabled and true or false)

    if auraId and auraId ~= "" then
      UIDropDownMenu_SetText(dd, auraId)
    else
      UIDropDownMenu_SetText(dd, "未选择")
    end
  end

  UIDropDownMenu_Initialize(dd, function(_, level)
    local info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true

    info.text = "未选择"
    info.func = function()
      B:ES_SetAuraForElement(themeId, elem.key, nil, nil)
      refresh()
    end
    UIDropDownMenu_AddButton(info, level)

    for _, opt in ipairs(auraOptions) do
      info.text = opt.title
      info.func = function()
        B:ES_SetAuraForElement(themeId, elem.key, opt.id, nil)
        refresh()
      end
      UIDropDownMenu_AddButton(info, level)
    end
  end)

  check:SetScript("OnClick", function()
    local on = check:GetChecked() and true or false
    B:ES_SetEnabled(themeId, elem.key, on, nil)
    refresh()
  end)

  row.Refresh = refresh
  refresh()

  return row
end

local function CreateElementSwitchPage(parent)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)

  local title = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Large() or "GameFontNormalLarge"))
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText(B:Loc('MODULE_ELEMENT_SWITCH'))

  local hint = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:HighlightSmall() or "GameFontHighlightSmall"))
  hint:SetPoint("TOPLEFT", 16, -40)
  hint:SetPoint("TOPRIGHT", -16, -40)
  hint:SetJustifyH("LEFT")
  hint:SetText("v1.5：仅对 WeakAuras 生效（通过 Adapter）。下拉选择一个 Display 作为该元素的 Variant；勾选框用于显示/隐藏。")

  local refreshBtn = CreateButton(page, B:Loc('BTN_REFRESH_LIST'))
  refreshBtn:SetPoint("TOPRIGHT", -18, -12)

  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -72)
  scroll:SetPoint("BOTTOMRIGHT", -34, 12)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  page._rows = {}

  local function clearRows()
    for _, r in ipairs(page._rows) do
      if r and r.Hide then r:Hide() end
    end
    page._rows = {}

    -- 清掉旧标题文本
    if page._headers then
      for _, h in ipairs(page._headers) do
        if h and h.Hide then h:Hide() end
      end
    end
    page._headers = {}
  end

  function page:Refresh()
    clearRows()

    local themeId, theme, rootName = getThemeContext()
    if not themeId or not theme then
      local t = content:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Highlight() or "GameFontHighlight"))
      t:SetPoint("TOPLEFT", 16, -10)
      t:SetPoint("TOPRIGHT", -16, -10)
      t:SetJustifyH("LEFT")
      t:SetJustifyV("TOP")
      t:SetText(B:Loc('TEXT_NO_ACTIVE_THEME') .. "\n\n" .. B:Loc('TEXT_CLICK_APPLY_THEME'))
      table.insert(page._headers, t)
      content:SetHeight(120)
      return
    end

    if not rootName or rootName == "" then
      local t = content:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Highlight() or "GameFontHighlight"))
      t:SetPoint("TOPLEFT", 16, -10)
      t:SetPoint("TOPRIGHT", -16, -10)
      t:SetJustifyH("LEFT")
      t:SetJustifyV("TOP")
      t:SetText("该主题未提供 BRE 根组名（theme.bre.groupName）。")
      table.insert(page._headers, t)
      content:SetHeight(80)
      return
    end

    local auraOptions = BuildAuraOptions(rootName)

    local y = -6
    for _, cat in ipairs(SCHEMA) do
      local h = content:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Normal() or "GameFontNormal"))
      h:SetPoint("TOPLEFT", 16, y)
      h:SetText(cat.title)
      table.insert(page._headers, h)
      y = y - 22

      for _, elem in ipairs(cat.elements or {}) do
        local row = CreateElementRow(content, y, elem, themeId, auraOptions, rootName)
        table.insert(page._rows, row)
        y = y - 28
      end

      y = y - 10
    end

    content:SetHeight(math.max(1, -y + 20))
  end

  refreshBtn:SetScript("OnClick", function() page:Refresh() end)

  return page
end

B:RegisterModule("element_switch", {
  titleKey = 'MODULE_ELEMENT_SWITCH',
  order = 10,
  Create = function(self, parent) return CreateElementSwitchPage(parent) end,
  OnShow = function(self)
    -- 页面显示时强制刷新一次（确保使用最新 activeThemeId）
    local p = B and B.frame and B.frame.modulePages and B.frame.modulePages["element_switch"] or nil
    -- 上面这条可能拿不到，兜底：遍历 B.modulePages
    if not p and B and B.modulePages then p = B.modulePages["element_switch"] end
    if p and p.Refresh then p:Refresh() end
  end,
})
