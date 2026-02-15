-- Locales/enUS.lua
local B = BanruoUI
if not B then return end

B.__locales = B.__locales or {}
local L = {}
B.__locales['enUS'] = L

L['LANG_GEAR_TOOLTIP'] = 'Settings'
L['LANG_MENU_TOGGLE'] = 'Switch language'
L['LANG_TO_ZH'] = 'Switch to Chinese'
L['LANG_TO_EN'] = 'Switch to English'
L['LANG_AUTO'] = 'Auto (System)'
L['LANG_ZH'] = 'Chinese'
L['LANG_EN'] = 'English'

-- Step1 (v2.5.2) Core/Frame top bar + restore popup
L['LABEL_THEME'] = 'Theme:'
L['DD_NO_THEME_PACK'] = 'No theme pack detected'
L['BTN_SWITCH_THEME'] = 'Apply Theme'
L['BTN_FORCE_RESTORE'] = 'Reset'
L['POPUP_CONTINUE'] = 'Continue'
L['POPUP_RESTORE_TEXT'] = [[Confirm reset to default?

This will:
- Delete the theme's existing BrE content and re-import the author's defaults

Your tweaks may be overwritten.]]

-- Step2 (v2.5.3) Core/Main localized
L["DD_NO_THEME_PACK"] = "No theme pack detected"
L["DD_UNKNOWN"] = "Unknown"
L["PREVIEW_NO_THEME_PACK"] = "No theme pack detected.\n\nInstall a theme-pack addon, then /reload.\nClick [Help] for instructions."
L["PREVIEW_AUTHOR_LINE"] = "Author: %s"
L["PREVIEW_VERSION_LINE"] = "Version: %s"
L["PREVIEW_INCLUDES_LINE"] = "Includes: %s"
L["PREVIEW_INCLUDES_BRE"] = " BrE theme data"
L["PREVIEW_INCLUDES_NONE"] = "None (display/extension only)"
L["PREVIEW_TIP_APPLY_REQUIRED"] = "Click [Apply Theme] to take effect."
L["PREVIEW_TIP_SWITCH_NO_OVERRIDE"] = "Normal switch won't overwrite tweaks; use [Reset] to reset."
L["PREVIEW_TIP_ELVUI_MANUAL"] = "Note: ElvUI is not applied automatically. Import it manually in ElvUI."
L["ERR_WA_ADAPTER_NOT_READY"] = "BrE adapter not ready"
L["ERR_WA_NO_GROUPNAME"] = "groupName missing"
L["ERR_THEME_NO_WA_REF"] = "Theme has no BRE reference"
L["ERR_WA_REG_MISSING"] = "Missing BrE registry data (theme.bre.main)"
L["WA_FORCE_RESTORE_OK"] = "BrE: force restored (re-imported)"
L["WA_FIRST_IMPORT_OK"] = "BrE: first import completed"
L["WA_HIDDEN_SWITCH_OK"] = "BrE: hidden switch (keeps tweaks)"
L["PRINT_NO_THEME_PACK"] = "No themes available (no theme pack)."
L["PRINT_ALREADY_ACTIVE"] = "Theme already active."
L["PRINT_WA_FAIL"] = "BrE: failed - %s"
L["PRINT_SWITCH_OK"] = "Theme switched: %s"
L["PRINT_WA_RESULT"] = "BrE: %s"
L["PRINT_RELOAD_SUGGEST"] = "If anything looks wrong, try /reload."
L["PRINT_LOADED_HINT"] = "Loaded. Type /banruo to open."

-- Step3 fix (v2.5.5): ThemePreview module texts
L['PREVIEW_HINT_TOP'] = 'Preview only. Click [Apply Theme] to take effect.'
L['MODULE_THEME_PREVIEW'] = 'Theme Preview'

-- Step4: module titles + ElementSwitch UI bits
L['MODULE_ELEMENT_SWITCH']   = 'Element Switch'
L['MODULE_STORY_COLLECTION'] = 'Tarot'
L['MODULE_JUKEBOX']          = 'Jukebox'
L['MODULE_ELVUI_STRING']     = 'ElvUI String'

-- Themes & Notice
L['MODULE_DECLARATION'] = 'Themes & Notice'
L['DECLARATION_DESC'] = [[
Bre is developed based on the WeakAuras (WA) architecture.

Since WA stopped updating on retail, this project continues development and extends features while complying with the WA open-source license.
Thanks to the WA project. 
Mode Code: /run Bre.Profile:SetMode("FULL")
]]
L['DECLARATION_GITHUB'] = 'GitHub'
L['DECLARATION_BILIBILI'] = 'More Theme Bilibili'
L['DECLARATION_YOUTUBE'] = 'More Theme YouTube'

-- Element Switch - Dynamic Portrait Frame
L['ES_DPF_TITLE'] = 'Dynamic Portrait Frame'
L['ES_DPF_FRAME'] = 'Frame'
L['ES_DPF_BG']    = 'Backdrop'

L['ES_MM_TITLE'] = 'Minimap'
L['ES_MM_FRAME'] = 'Border'
L['ES_MM_BG']    = 'BG'

-- Element Switch - Action Bar
L['ES_AB_TITLE']        = 'Action Bar'
L['ES_AB_BG']           = 'BG'
L['ES_AB_ORB_R']        = 'Orb(R)'
L['ES_AB_ORB_R_DECOR']  = 'Statue (R)'
L['ES_AB_ORB_L']        = 'Orb(L)'
L['ES_AB_ORB_L_DECOR']  = 'Statue (L)'

-- Element Switch: Misc Decorations
L['ES_MISC_TITLE']       = 'Misc Decorations'
L['ES_MISC_TRIM_TOP']    = 'Top Trim'
L['ES_MISC_TRIM_BOTTOM'] = 'Bottom'
L['ES_MISC_DECOR_1']     = 'Decor I'
L['ES_MISC_DECOR_2']     = 'Decor II'
L['ES_MISC_DECOR_3']     = 'Decor III'
L['ES_MISC_DECOR_4']     = 'Decor IV'

L['BTN_APPLY_THEME'] = L['BTN_SWITCH_THEME']
L['BTN_RESET']       = L['BTN_FORCE_RESTORE']

L['BTN_REFRESH_LIST']    = 'Refresh'
L['BTN_ELEMENT_MANAGER'] = 'Elements'

-- ElvUI String page: source selector + copy
L['BTN_COPY'] = 'Copy'
L['ELVUI_STRING_SOURCE_ELVUI'] = 'ElvUI'
L['ELVUI_STRING_SOURCE_NDUI']  = 'NDui'
L['ELVUI_STRING_HINT'] = 'Display/copy only: this page does not import or call ElvUI. Copy and paste into ElvUI Import manually.'
L['ELVUI_STRING_META_NO_ACTIVE'] = 'Active theme: Unknown (apply a theme first in [Theme Preview])'
L['ELVUI_STRING_BODY_NO_ACTIVE'] = 'Theme not active. Unable to read export strings.'
L['ELVUI_STRING_META_ACTIVE_FMT'] = 'Active theme: %s'
L['ELVUI_STRING_META_PROFILE_FMT'] = 'Profile: %s'
L['ELVUI_STRING_BODY_NO_STRING'] = 'This theme pack does not provide an ElvUI export string.\n\nTheme authors may set: theme.elvui.importString'
L['ELVUI_STRING_NDUI_PLACEHOLDER'] = 'NDui export is not available yet.'
L['ELVUI_STRING_COPY_NOTICE'] = 'Selected. Press Ctrl+C to copy.'

L['TEXT_NO_ACTIVE_THEME']   = 'No active theme applied.'
L['TEXT_CLICK_APPLY_THEME'] = 'Go to [Theme Preview] and click [Apply Theme] first.'

L['TEXT_PLACEHOLDER_UNAVAILABLE'] = 'Unavailable / Coming soon.'

-- Ensure B.L points to the filled locale tables before modules register titles.
if B and B.ApplyLocale then B:ApplyLocale() end

L["ELEMENT_3D_PORTRAIT"] = "Model"

L["ES_DPF_PORTRAIT"] = "Model"

L["ES_DECOR_V"] = "Decor V"

L["ES_DECOR_VI"] = "Decor VI"

L["ES_DECOR_VII"] = "Decor VII"

L["ES_DECOR_VIII"] = "Decor VIII"

L["ES_MISC_DECOR_5"] = "Decor V"

L["ES_MISC_DECOR_6"] = "Decor VI"

L["ES_MISC_DECOR_7"] = "Decor VII"

L["ES_MISC_DECOR_8"] = "Decor VIII"

-- BrMusic
L['MODULE_BRMUSIC'] = 'BrMusic'
L['BRMUSIC_ENABLE'] = 'Enable BrMusic'
L['BRMUSIC_ENABLE_TIP'] = 'Disables features only. To fully disable, disable BrMusic in AddOns and /reload.'
L['BRMUSIC_DEV_HINT'] = 'In development. Coming soon.'
L['BRMUSIC_BTN_PLAY_TIP'] = 'Play'
L['BRMUSIC_BTN_STOP_TIP'] = 'Stop'
L['BRMUSIC_BTN_NEXT_TIP'] = 'Next'
L['BRMUSIC_MODE_AUTO'] = 'Auto'
L['BRMUSIC_MODE_MANUAL'] = 'Manual'

L['BRMUSIC_STATE_IDLE'] = 'Idle'
L['BRMUSIC_STATE_PLAYING'] = 'Playing'

L['BRMUSIC_CUSTOM_01'] = 'Custom 01'
L['BRMUSIC_CUSTOM_02'] = 'Custom 02'
L['BRMUSIC_CUSTOM_03'] = 'Custom 03'
L['BRMUSIC_CUSTOM_04'] = 'Custom 04'
L['BRMUSIC_CUSTOM_05'] = 'Custom 05'

L['BRMUSIC_GAME_01'] = 'Game Track 01'
L['BRMUSIC_GAME_02'] = 'Game Track 02'
L['BRMUSIC_GAME_03'] = 'Game Track 03'
L['BRMUSIC_GAME_04'] = 'Game Track 04'
L['BRMUSIC_GAME_05'] = 'Game Track 05'
