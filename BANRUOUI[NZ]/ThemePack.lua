local B = BanruoUI
if not B then return end

local THEME_ID = "nz"
local BRE_ID   =  "banruoui_nz_bre_main"
local ELV_ID   =  "banruoui_nz_elv_profile"

B:RegisterTheme({
  id      = THEME_ID,
  title   = "BANRUOUI 内置主题包",
  author  = "BanruoUI",
  version = "1.0.0",
  preview = "Interface\\AddOns\\BANRUOUI[NZ]\\Media\\Previews\\preview.tga",

  bre = { main = BRE_ID, groupName = "BANRUOUI[NZ]" },
  elvui = { profile = ELV_ID, profileName = "BANRUOUI[NZ]" },
})
