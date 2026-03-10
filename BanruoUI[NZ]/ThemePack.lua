local B = BanruoUI
if not B then return end

local _, ns = ...
ns = ns or _G
local meta = ns.ThemeMeta or {}

local THEME_ID = meta.themeId or "nz"
local BRE_ID   = meta.breId or ("banruoui_" .. THEME_ID .. "_bre_main")
local ELV_ID   = meta.elvProfileId or ("banruoui_" .. THEME_ID .. "_elv_profile")

local loc = GetLocale and GetLocale() or "enUS"
local title = (loc == "zhCN") and (meta.titleZhCN or "BanruoUI Theme") or (meta.titleEnUS or "BanruoUI Theme")

B:RegisterTheme({
  id      = THEME_ID,
  title   = title,
  author  = meta.author or "BanruoUI",
  version = meta.version or "1.0.0",
  preview = meta.preview or "",

  bre   = { main = BRE_ID, groupName = meta.themeName or ("BANRUOUI[" .. string.upper(THEME_ID) .. "]") },
  elvui = { profile = ELV_ID, profileName = meta.themeName or ("BANRUOUI[" .. string.upper(THEME_ID) .. "]") },
})
