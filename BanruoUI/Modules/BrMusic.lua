-- Modules/BrMusic.lua
-- BrMusic control page inside BanruoUI main window

local B = BanruoUI
if not B then return end

local function CreateToggle(parent)
  local c = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  c.Text:SetText(B:Loc("BRMUSIC_ENABLE"))
  return c
end

local function CreateButton(parent, text)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetHeight(22)
  btn:SetText(text)
  btn:SetWidth(btn:GetTextWidth() + 28)
  return btn
end

local function GetBrMusic()
  return _G.BrMusic
end

local function Refresh(page)
  local bm = GetBrMusic()
  local enabled = true
  local st = nil
  if bm and bm.GetState then
    st = bm:GetState()
    enabled = st.enabled
  end

  if page.enableCheck then
    page.enableCheck:SetChecked(enabled)
  end

  if page.statusText then
    if not bm then
      page.statusText:SetText("BrMusic: " .. (B:Loc("TEXT_PLACEHOLDER_UNAVAILABLE") or "Unavailable"))
    else
      local playing = st and st.playing
      local mode = st and st.mode or "manual"
      local line1 = (playing and (B:Loc("BRMUSIC_STATE_PLAYING") or "Playing") or (B:Loc("BRMUSIC_STATE_IDLE") or "Idle"))
      local line2 = (mode == "auto") and B:Loc("BRMUSIC_MODE_AUTO") or B:Loc("BRMUSIC_MODE_MANUAL")
      page.statusText:SetText(string.format("%s | %s", line1, line2))
    end
  end

  if page.btnMain then
    if not bm then
      page.btnMain:Disable()
      page.btnNext:Disable()
      page.btnMode:Disable()
    else
      page.btnMain:SetEnabled(enabled)
      page.btnNext:SetEnabled(enabled)
      page.btnMode:SetEnabled(enabled)

      if st and st.playing then
        page.btnMain:SetText("■")
      else
        page.btnMain:SetText("▶")
      end

      if st and st.mode == "auto" then
        page.btnMode:SetText("A")
      else
        page.btnMode:SetText("M")
      end
    end
  end
end

local function CreatePage(parent)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)

  local h = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Large() or "GameFontNormalLarge"))
  h:SetPoint("TOPLEFT", 16, -18)
  h:SetText(B:Loc("MODULE_BRMUSIC"))

  local dev = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Highlight() or "GameFontHighlight"))
  dev:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -10)
  dev:SetPoint("TOPRIGHT", -16, 0)
  dev:SetJustifyH("LEFT")
  dev:SetText(B:Loc("BRMUSIC_DEV_HINT"))

  local enable = CreateToggle(page)
  enable:SetPoint("TOPLEFT", 18, -86)
  page.enableCheck = enable

  local tip = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Highlight() or "GameFontHighlight"))
  tip:SetPoint("TOPLEFT", enable, "BOTTOMLEFT", 2, -8)
  tip:SetPoint("TOPRIGHT", -16, -0)
  tip:SetJustifyH("LEFT")
  tip:SetText(B:Loc("BRMUSIC_ENABLE_TIP"))

  local status = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Normal() or "GameFontNormal"))
  status:SetPoint("TOPLEFT", tip, "BOTTOMLEFT", 0, -12)
  status:SetText("")
  page.statusText = status

  local btnMain = CreateButton(page, "▶")
  btnMain:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -12)
  btnMain:SetWidth(36)

  local btnNext = CreateButton(page, "⏭")
  btnNext:SetPoint("LEFT", btnMain, "RIGHT", 6, 0)
  btnNext:SetWidth(36)

  local btnMode = CreateButton(page, "M")
  btnMode:SetPoint("LEFT", btnNext, "RIGHT", 6, 0)
  btnMode:SetWidth(36)

  page.btnMain = btnMain
  page.btnNext = btnNext
  page.btnMode = btnMode

  enable:SetScript("OnClick", function(self)
    local bm = GetBrMusic()
    local checked = self:GetChecked()
    if bm and bm.SetEnabled then
      bm:SetEnabled(checked)
    else
      -- still store preference for later
      BrMusicDB = BrMusicDB or {}
      BrMusicDB.enabled = checked and true or false
    end
    Refresh(page)
  end)

  btnMain:SetScript("OnClick", function()
    local bm = GetBrMusic(); if not bm then return end
    if bm.PlayStopToggle then bm:PlayStopToggle() end
    Refresh(page)
  end)
  btnNext:SetScript("OnClick", function()
    local bm = GetBrMusic(); if not bm then return end
    if bm.Next then bm:Next() end
    Refresh(page)
  end)
  btnMode:SetScript("OnClick", function()
    local bm = GetBrMusic(); if not bm then return end
    local st = bm.GetState and bm:GetState() or { mode = "manual" }
    if st.mode == "auto" then bm:SetMode("manual") else bm:SetMode("auto") end
    Refresh(page)
  end)

  Refresh(page)
  return page
end

B:RegisterModule("jukebox", {
  titleKey = "MODULE_BRMUSIC",
  order = 30,
  Create = function(self, parent)
    local p = CreatePage(parent)
    self._page = p
    return p
  end,
  OnShow = function(self)
    if self._page then Refresh(self._page) end
  end,
})
