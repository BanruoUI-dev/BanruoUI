local B = BanruoUI
if not B then return end

local _, ns = ...
ns = ns or _G
local meta = ns.ThemeMeta or {}

local BRE_ID = meta.breId or ("banruoui_" .. (meta.themeId or "nz") .. "_bre_main")
local locale = GetLocale and GetLocale() or "enUS"
local data = (locale == "zhCN") and ns.BRE_ZH or ns.BRE_EN
if type(data) ~= "string" or data == "" then return end

B:RegisterBRE({
  id   = BRE_ID,
  name = meta.themeName or "BANRUOUI[NZ]",
  data = data,
})
