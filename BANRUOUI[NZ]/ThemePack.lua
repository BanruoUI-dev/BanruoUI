local B = BanruoUI
if not B then return end

local THEME_ID = "nz"
local BRE_ID   = "banruoui_nz_bre_main"
local ELV_ID   = "banruoui_nz_elv_profile"

local loc = GetLocale and GetLocale() or "enUS"
local title = (loc == "zhCN") and "BanruoUI 内置主题包" or "BanruoUI Demo Theme"

B:RegisterTheme({
  id      = THEME_ID,
  title   = title,
  author  = "BanruoUI",
  version = "1.0.0",
  preview = "Interface\\AddOns\\BANRUOUI[NZ]\\Media\\Previews\\preview.tga",

  bre  = { main = BRE_ID, groupName = "BANRUOUI[NZ]" },
  elvui = { profile = ELV_ID, profileName = "BANRUOUI[NZ]" },
})
