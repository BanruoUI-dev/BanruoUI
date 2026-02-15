-- Core/Init.lua
-- SavedVariables + slash + runtime state
-- 路线S：BanruoUI 不负责“安装/管理主题包”，只负责列出已注册主题并切换。

local B = BanruoUI

BanruoUIDB = BanruoUIDB or {}
BanruoUIDB.activeThemeId = BanruoUIDB.activeThemeId or nil
BanruoUIDB.themeInit = BanruoUIDB.themeInit or {}

-- v2.5 Step0: apply locale after SavedVariables are available
if B and B.ApplyLocale then B:ApplyLocale() end

B.state = B.state or {}
B.state.pendingPreviewThemeId = B.state.pendingPreviewThemeId or nil
B.state.activeModuleId = B.state.activeModuleId or "theme_preview"

SLASH_BANRUOUIOPEN1 = "/banruo"
SLASH_BANRUOUIOPEN2 = "/banruoui"
SLASH_BANRUOUIOPEN3 = "/br"
SlashCmdList["BANRUOUIOPEN"] = function(msg)
  local raw = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local lower = raw:lower()

  -- lang override: /br lang [auto|zhCN|enUS]
  if lower == "lang" or lower:match("^lang%s") then
    _G.BanruoUIDB = _G.BanruoUIDB or {}
    local a = raw:match("^%S+%s+(%S+)$")
    local cur = _G.BanruoUIDB.langOverride or "auto"
    if not a or a == "" then
      B:Print("lang = " .. tostring(cur) .. " (use: /br lang auto|zhCN|enUS)")
      return
    end
    local v = a
    if v == "AUTO" or v == "Auto" or v == "auto" then
      _G.BanruoUIDB.langOverride = nil
    else
      if v == "zhcn" then v = "zhCN" end
      if v == "enus" then v = "enUS" end
      if v == "zhCN" or v == "enUS" then
        _G.BanruoUIDB.langOverride = v
      end
    end
    if B and B.ApplyLocale then B:ApplyLocale() end
    local now = _G.BanruoUIDB.langOverride or "auto"
    B:Print("lang set = " .. tostring(now) .. ". /reload")
    return
  end

  if not B.frame then
    B:Print("UI 尚未初始化，请 /reload 后重试。")
    return
  end
  if B.frame:IsShown() then B.frame:Hide() else B.frame:Show() end
end
