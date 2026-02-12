-- Modules/ElementSwitch/Container.lua
-- v1.6.7.7：UI 收尾（移除说明文字块 + 内容区上移；仅布局/显示，不改逻辑）
-- 变更：
--   1) 子选项行：不显示复选框（保持 1.6.7.5 行内布局）。
--   2) 四大类分组标题：移除标题前复选框（不做分类显隐功能）。

local B = BanruoUI
if not B then return end

B._esSubMods = B._esSubMods or {}
B._esSubModOrder = B._esSubModOrder or {}

function B:ES_RegisterSubModule(id, def)
  if type(id) ~= "string" or id == "" then return false end
  if type(def) ~= "table" then return false end
  def.id = id
  def.title = def.title or id
  def.order = tonumber(def.order or 999) or 999
  self._esSubMods[id] = def

  local exists = false
  for _, v in ipairs(self._esSubModOrder) do
    if v == id then exists = true break end
  end
  if not exists then
    table.insert(self._esSubModOrder, id)
    table.sort(self._esSubModOrder, function(a, b)
      local A = self._esSubMods[a] and self._esSubMods[a].order or 999
      local Bn = self._esSubMods[b] and self._esSubMods[b].order or 999
      return A < Bn
    end)
  end
  return true
end

function B:ES_GetSubModules()
  local out = {}
  for _, id in ipairs(self._esSubModOrder or {}) do
    local d = self._esSubMods[id]
    if d then table.insert(out, d) end
  end
  return out
end

-- ---------- UI helpers (Step2/3 placeholders) ----------
local function CreateButton(parent, text)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetHeight(22)
  btn:SetText(text)
  btn:SetWidth(btn:GetTextWidth() + 18)
  return btn
end

-- v1.6.7.6：四大类分组标题行（无 checkbox，仅标题文字）
local function CreateGroupHeader(parent, headerText, width)
  local row = CreateFrame("Frame", nil, parent)
  -- 标题更明显：字号更大 + 阴影 + 右侧淡分隔线（不改功能，仅增强层级）
  row:SetHeight(24)

  -- 显式给宽度，避免部分环境下子控件不可见
  if width and width > 0 then
    row:SetWidth(width)
  else
    row:SetWidth(520)
  end

  local label = row:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Large() or "GameFontNormalLarge"))
  label:SetPoint("LEFT", 10, 0)
  label:SetJustifyH("LEFT")
  label:SetText(headerText or "")
  -- 轻微阴影：提升在暗底上的可读性
  label:SetShadowColor(0, 0, 0, 0.9)
  label:SetShadowOffset(1, -1)
  -- 保持 BanruoUI 金色体系（更亮但不跳色）
  label:SetTextColor(1, 0.82, 0, 1)
  row._label = label

  -- 标题右侧淡分隔线：从标题右边延伸到容器右侧
  local line = row:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("LEFT", label, "RIGHT", 10, 0)
  line:SetPoint("RIGHT", row, "RIGHT", -10, 0)
  line:SetPoint("CENTER", row, "CENTER", 0, -1)
  if line.SetColorTexture then
    line:SetColorTexture(1, 0.82, 0, 0.25)
  else
    line:SetTexture(1, 1, 1, 1)
    line:SetVertexColor(1, 0.82, 0, 0.25)
  end
  row._line = line

  return row
end

local function CreatePlaceholderItem(parent, labelText, itemWidth)
  local item = CreateFrame("Frame", nil, parent)
  item:SetHeight(28)
  if itemWidth then item:SetWidth(itemWidth) end

  -- v1.6.7.2：子选项行不再显示 checkbox。
  -- 为保持整体视觉不变（不动布局），保留原本“checkbox 占位”的左缩进。
  local label = item:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Normal() or "GameFontNormal"))
  label:SetPoint("LEFT", 16, 1)
  label:SetJustifyH("LEFT")
  -- UI 只展示中文/显示名；elementId 作为内部键不在此处展示
  label:SetText(labelText or "元素")
  label:SetWidth(72) -- 固定标签宽度（更紧凑），并保持下拉起点对齐

  local dd = CreateFrame("Frame", nil, item, "UIDropDownMenuTemplate")
  dd:SetPoint("LEFT", label, "RIGHT", 2, -2)
  UIDropDownMenu_SetWidth(dd, math.max(120, (itemWidth or 300) - 112))
  UIDropDownMenu_JustifyText(dd, "LEFT")
  UIDropDownMenu_SetText(dd, "未选择")
  UIDropDownMenu_DisableDropDown(dd) -- 默认禁用；命中且有 variants 时启用

  item._dd = dd

  -- 右侧状态：Step4/5 用于验收（命中/缺失/重复/未就绪）。
  local status = item:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:DisableSmall() or "GameFontDisableSmall"))
  status:SetPoint("RIGHT", -6, 1)
  status:SetJustifyH("RIGHT")
  status:SetText("")
  item._status = status

  function item:SetStatus(text)
    if self._status then self._status:SetText(text or "") end
  end

  -- Step5：设置 Variant 下拉（仅展示/可选择并写入 BanruoUIDB，不触发 WA 切换）
  function item:SetVariants(variants, selectedId, selectedTitle, onSelect)
    if type(variants) ~= "table" or #variants == 0 then
      UIDropDownMenu_SetText(dd, "未选择")
      UIDropDownMenu_DisableDropDown(dd)
      dd._variants, dd._onSelect = nil, nil
      return
    end

    dd._variants = variants
    dd._onSelect = onSelect

    UIDropDownMenu_Initialize(dd, function(self, level)
      level = level or 1
      if level ~= 1 then return end
      local list = self._variants or {}
      for i = 1, #list do
        local v = list[i]
        local info = UIDropDownMenu_CreateInfo()
        info.text = v.title
        info.value = v.id
        info.func = function()
          UIDropDownMenu_SetSelectedValue(dd, v.id)
          UIDropDownMenu_SetText(dd, v.title)
          if type(dd._onSelect) == "function" then
            dd._onSelect(v)
          end
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)

    if selectedId and selectedId ~= "" then
      UIDropDownMenu_SetSelectedValue(dd, selectedId)
      UIDropDownMenu_SetText(dd, selectedTitle or "未选择")
    else
      UIDropDownMenu_SetText(dd, "未选择")
    end

    UIDropDownMenu_EnableDropDown(dd)
  end

  return item
end

local VERSION_TAG = "2.1"

local function getActiveRootName()
  local themeId = BanruoUIDB and BanruoUIDB.activeThemeId or nil
  if not themeId then return nil, nil end
  local theme = B and B.GetTheme and B:GetTheme(themeId) or nil
  local rootName = (theme and theme.bre and theme.bre.groupName) or nil
  return rootName, themeId
end

-- Step5：DB 记录（仅保存用户选择的 Variant，不触发 WA 切换）
local function ensureESDB()
  BanruoUIDB = BanruoUIDB or {}
  BanruoUIDB.elementSwitch = BanruoUIDB.elementSwitch or {}
end

local function getElemState(themeId, elementId)
  ensureESDB()
  if not themeId or not elementId then return nil end
  BanruoUIDB.elementSwitch[themeId] = BanruoUIDB.elementSwitch[themeId] or {}
  BanruoUIDB.elementSwitch[themeId][elementId] = BanruoUIDB.elementSwitch[themeId][elementId] or {}
  return BanruoUIDB.elementSwitch[themeId][elementId]
end

local function CreateElementSwitchPage(parent)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(true)

  local title = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Large() or "GameFontNormalLarge"))
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText(B:Loc('MODULE_ELEMENT_SWITCH'))

  -- v1.6.7.7：移除顶部说明文字块（收尾），仅保留标题。

  -- 顶部按钮：右侧新增【元素管理】，原【刷新列表】向左挪
  -- NOTE: 文案走 Locale（运行期取词，避免注册期缓存）
  local manageBtn = CreateButton(page, B:Loc('BTN_ELEMENT_MANAGER'))
  manageBtn:SetPoint("TOPRIGHT", -18, -12)

  local refreshBtn = CreateButton(page, B:Loc('BTN_REFRESH_LIST'))
  refreshBtn:SetPoint("TOPRIGHT", manageBtn, "TOPLEFT", -6, 0)

  manageBtn:SetScript("OnClick", function()
    if InCombatLockdown and InCombatLockdown() then
      if B and B.Print then B:Print("战斗中不可打开 Bre，请脱战后再试。") end
      return
    end

    -- v1.0.11: 优先走 Bre.HostAPI:Open()（避免依赖 slash 命令）
    if _G.Bre and _G.Bre.HostAPI and _G.Bre.HostAPI.Open then
      _G.Bre.HostAPI:Open()
    elseif SlashCmdList and SlashCmdList.BRS then
      -- fallback: legacy /brs
      SlashCmdList.BRS("")
    else
      if B and B.Print then B:Print("Bre 未就绪（无法打开元素管理）") end
    end
  end)

  local subMods = B:ES_GetSubModules()
  if #subMods <= 0 then
    local t = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Normal() or "GameFontNormal"))
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("元素切换子模块未加载（请检查 toc 加载顺序）")
    return page
  end

  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  -- 说明文字块移除后，上移内容区填充空白
  scroll:SetPoint("TOPLEFT", 12, -44)
  scroll:SetPoint("BOTTOMRIGHT", -34, 12)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  page._content = content

  local function clearContent()
    if not content._widgets then content._widgets = {} end
    for _, w in ipairs(content._widgets) do
      if w and w.Hide then w:Hide() end
    end
    wipe(content._widgets)
  end

  local function addWidget(w)
    content._widgets = content._widgets or {}
    table.insert(content._widgets, w)
  end

  function page:Refresh()
    clearContent()

    local anomalyCount = 0

    -- 计算两列宽度（避免“卡片/网格”感觉：只摆控件，不画格子）
    local padX = 16
    -- v1.6.7.5：仅布局微调
    -- 目的：让“四大分类标题行（含复选框）”更突出一些，不与子项视觉混在一起。
    -- 规则：只移动标题行的 X 偏移，子项行与下拉布局不动。
    local headerShiftX = 10
    local gapX = 18
    local availW = (scroll:GetWidth() or 700) - 26 -- 给滚动条留空间
    local colW = math.floor((availW - padX * 2 - gapX) / 2)
    if colW < 260 then colW = 260 end

    -- Step7：Bre 扫描（仅用于命中回显；不做任何写操作）
    local rootName = getActiveRootName()
    local scan = nil
    if B and type(B.BRE_B1_ScanRoot) == "function" then
      scan = B:BRE_B1_ScanRoot(rootName)
    else
      scan = { ok = false, reason = "Bre 适配层未就绪", map = {}, dupes = {}, _idx = nil }
    end
    page._b1 = scan

    -- 更新可视化验收标识（Container 渲染链路 + B1 状态摘要；Step6 会在末尾追加异常汇总）
    local markerBaseText = nil
    do
      local names = {}
      for _, m in ipairs(subMods) do
        table.insert(names, (m.title or m.id or ""))
      end
      if marker then
        local b1 = "B1："
        if scan and scan.ok then
          b1 = b1 .. "Root命中，元素" .. tostring(scan.elementCount or 0)
          if scan.dupCount and scan.dupCount > 0 then
            b1 = b1 .. "，重复" .. tostring(scan.dupCount)
          end
        else
          b1 = b1 .. (scan and scan.reason or "未就绪")
        end
        markerBaseText = "渲染：Container → " .. table.concat(names, "/") .. "  (" .. VERSION_TAG .. ")  |  " .. b1
        marker:SetText(markerBaseText)
      end
    end

    local y = -8
    for _, m in ipairs(subMods) do
      -- 分组标题（单行）
      local headerText = m.headerText
      if not headerText then
        if m.titleKey and B and type(B.Loc) == "function" then
          headerText = B:Loc(m.titleKey)
        else
          headerText = m.title
        end
      end
      local header = CreateGroupHeader(content, headerText or m.id, (colW * 2 + gapX))
      -- v1.6.7.5：标题行整体左移一点，使其更像“分组标题”而不是与子项混在一起。
      header:SetPoint("TOPLEFT", padX - headerShiftX, y)
      addWidget(header)
      y = y - 22

      -- 分组内子项目：两两一行
      local layout = { y = y, col = 1 }

      -- ui.AddItem 支持两种签名：
      --   AddItem(labelText)
      --   AddItem(elementId, labelText)
      -- elementId 作为内部绑定键，不在 UI 上显示。
      local function addItem(a, b)
        local elementId, labelText
        if b == nil then
          labelText = a
        else
          elementId = a
          labelText = b
        end

        -- 兼容旧占位：若 labelText 仍带 {elementId}，这里剥离掉花括号
        if type(labelText) == "string" then
          labelText = labelText:gsub("%s*%b{}%s*", "")
        end

        local item = CreatePlaceholderItem(content, labelText, colW)
        item._elementId = elementId

        -- Step4：命中/缺失回显（UI 仅中文；不显示 elementId）
        if elementId and scan then
          if scan.ok then
            if scan.dupes and scan.dupes[elementId] then
              item:SetStatus("重复")
            elseif scan.map and scan.map[elementId] then
              item:SetStatus("已命中")
            else
              item:SetStatus("未命中")
            end
          else
            item:SetStatus("未就绪")
          end
        end

        -- Step6：Variant 静默回显（读 WA 子项启用状态；仍不做写操作）
        if elementId and scan and scan.ok and scan.map and scan.map[elementId] and not (scan.dupes and scan.dupes[elementId]) then
          local eg = scan.map[elementId]
          local idx = scan._idx
          local variants = {}
          if B and type(B.BRE_ListDirectChildrenObjs) == "function" then
            variants = B:BRE_ListDirectChildrenObjs(eg.id, idx)
          end

          -- 静默回显：根据 WA 子项启用状态决定默认选中项
          local selected = nil
          if type(variants) == "table" and #variants > 0 and B and type(B.BRE_IsNeverById) == "function" then
            local enabled = {}
            for i = 1, #variants do
              local v = variants[i]
              local never = B:BRE_IsNeverById(v.id, idx)
              if never == false then
                table.insert(enabled, v)
              end
            end

            if #enabled == 1 then
              selected = enabled[1]
            elseif #enabled == 0 then
              selected = variants[1]
            else
              selected = enabled[1]
              anomalyCount = anomalyCount + 1
            end
          end

          local _, themeId = getActiveRootName()
          item:SetVariants(variants, selected and selected.id or nil, selected and selected.title or nil, function(v)
            -- Step7：互斥切换（写 never）。
            -- 口径：关闭是硬权限（Never=true 一票否决）；开启只是放行（Never=false 仍受 WA 自身 Load/Trigger 约束）。
            if InCombatLockdown and InCombatLockdown() then
              if B and B.Print then B:Print("战斗中不可使用 BanruoUI，请脱战后再试。") end
              return
            end

            if not (B and B.BRE_SetNeverById and B.BRE_RefreshLoads) then
              if B and B.Print then B:Print("Bre 适配层未就绪（无法切换 Variant）") end
              return
            end

            -- 互斥：选中项放行，其它全部硬关
            if type(variants) == "table" then
              local rebuild = {}
              for i = 1, #variants do
                local vv = variants[i]
                if vv and vv.id then
                  table.insert(rebuild, vv.id)
                  B:BRE_SetNeverById(vv.id, vv.id ~= v.id)
                end
              end
              if B.BRE_RebuildDisplays and #rebuild > 0 then
                B:BRE_RebuildDisplays(rebuild)
              else
                B:BRE_RefreshLoads()
              end
            end

            -- 记录选择（用于后续 UI 回显与排障）
            local s = getElemState(themeId, elementId)
            if s then
              s.variantId = v.id
              s.variantTitle = v.title
            end
          end)
        else
          item:SetVariants(nil)
        end

        local x = padX + (layout.col == 2 and (colW + gapX) or 0)
        item:SetPoint("TOPLEFT", x, layout.y)
        addWidget(item)
        if layout.col == 1 then
          layout.col = 2
        else
          layout.col = 1
          layout.y = layout.y - 30
        end
      end

      local ui = { AddItem = addItem }
      if type(m.Create) == "function" then
        m:Create(content, ui)
      end

      -- 若最后一行只有左列，补齐换行
      if layout.col == 2 then
        layout.col = 1
        layout.y = layout.y - 30
      end
      y = layout.y - 12
    end

    content:SetHeight(math.max(1, -y + 30))

    -- Step6：异常汇总（多个 Variant 同时启用）——不弹窗、不刷屏，仅在页顶部标识上追加
    if marker and markerBaseText then
      if anomalyCount > 0 then
        marker:SetText(markerBaseText .. "  |  异常" .. tostring(anomalyCount) .. "：多个 Variant 同时启用（已默认取第一个启用）")
      else
        marker:SetText(markerBaseText)
      end
    end
  end

  refreshBtn:SetScript("OnClick", function() page:Refresh() end)

  return page
end

B:RegisterModule("element_switch", {
  titleKey = 'MODULE_ELEMENT_SWITCH',
  order = 10,
  Create = function(self, parent) return CreateElementSwitchPage(parent) end,
  OnShow = function(self)
    local frame = B and B.frame
    local pages = frame and frame.modulePages
    local p = pages and pages["element_switch"] or nil
    if p and p.Refresh then p:Refresh() end
  end,
})

-- ForceRebuild placeholder for decoration expansion