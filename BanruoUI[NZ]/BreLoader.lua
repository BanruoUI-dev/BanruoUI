local B = BanruoUI
if not B then return end

local BRE_ID = "banruoui_nz_bre_main"
local locale = GetLocale and GetLocale() or "enUS"
local data = (locale == "zhCN") and BRE_ZH or BRE_EN

B:RegisterBRE({
  id   = BRE_ID,
  name = "BANRUOUI[NZ]",
  data = data,
})
