local B = BanruoUI
if not B then return end

local addonName, ns = ...
ns = ns or _G
local meta = ns.ThemeMeta or {}

local THEME_ID = meta.themeId or "nz"
local BRE_ID   = meta.breId or ("banruoui_" .. THEME_ID .. "_bre_main")
local ELV_ID   = meta.elvProfileId or ("banruoui_" .. THEME_ID .. "_elv_profile")

local loc = GetLocale and GetLocale() or "enUS"
local title = (loc == "zhCN") and (meta.titleZhCN or "BanruoUI Theme") or (meta.titleEnUS or "BanruoUI Theme")

local tocVersion = nil
if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" and addonName then
  tocVersion = C_AddOns.GetAddOnMetadata(addonName, "Version")
elseif GetAddOnMetadata and addonName then
  tocVersion = GetAddOnMetadata(addonName, "Version")
end
if type(tocVersion) ~= "string" or tocVersion == "" then
  tocVersion = meta.version or "1.0.0"
end

local data = (loc == "zhCN") and ns.BRE_ZH or ns.BRE_EN
if type(data) == "string" and data ~= "" then
  B:RegisterBRE({
    id   = BRE_ID,
    name = meta.themeName or ("BANRUOUI[" .. string.upper(THEME_ID) .. "]"),
    data = data,
  })
end

B:RegisterTheme({
  id      = THEME_ID,
  title   = title,
  author  = meta.author or "BanruoUI",
  version = tocVersion,
  preview = meta.preview or "",
  sourceAddon = addonName,

  bre   = { main = BRE_ID, groupName = meta.themeName or ("BANRUOUI[" .. string.upper(THEME_ID) .. "]") },
  elvui = { profile = ELV_ID, profileName = meta.themeName or ("BANRUOUI[" .. string.upper(THEME_ID) .. "]") },
})
