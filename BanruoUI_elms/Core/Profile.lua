-- Bre/Core/Profile.lua
-- Centralized build profile for split packages.
--
-- Profiles (per Bre 分包开发文档):
-- DEV    : Bre_dev (source plugin, internal identity "Bre")
-- THEME  : Bre_theme (skin of Bre, internal identity still "Bre")
-- FULL   : Brelms (standalone, internal identity "Brelms")

local addonName, Bre = ...
Bre = Bre or {}

Bre.Profile = Bre.Profile or {}
local P = Bre.Profile

-- Priority:
-- 1) Explicit global override (packaging / dev): _G.BRE_BUILD_PROFILE = "DEV" | "THEME" | "FULL"
-- 2) Default (BanruoUI child): THEME
--
-- NOTE: We intentionally DO NOT use addon folder name heuristics like "Brelms" => FULL.
-- DEV/FULL are entered explicitly via Profile:SetMode(...).
local override = _G.BRE_BUILD_PROFILE
if override == "FULL" or override == "THEME" or override == "DEV" then
  P.id = override
else
  P.id = "THEME"
end

function P:IsDev() return self.id == "DEV" end
function P:IsTheme() return self.id == "THEME" end
function P:IsFull() return self.id == "FULL" end

function P:AllowSlashCommands()
  -- DEV/FULL: authoring entrypoints.
  -- THEME: slash exists but should be minimal; BanruoUI does not rely on slash.
  return true
end

-- Authoring UI gate: keep runtime modules alive, but don't register most authoring drawers in THEME.
-- NOTE: Specific allow list will be implemented at Registry/ModuleManager layer.
function P:AllowAuthoringUI()
  return self:IsDev() or self:IsFull()
end

-- Slash contract per 分包文档:
-- Slash command (stable):
-- Always register /bre (regardless of DEV/THEME/FULL).
function P:GetSlashCommand()
  return "/bre"
end


-- ------------------------------
-- Runtime UI profile mode (DEV/THEME/FULL)
-- - This is user-controlled and persisted in SavedVariables (BreSaved.ui.profile_mode)
-- - It unifies: UIWhitelist, SizeMode, ThemeMinimal drawer routing.
-- ------------------------------

local function _EnsureSavedProfileMode()
  -- Keep this file standalone (loaded before DB.lua).
  BreSaved = BreSaved or {}
  BreSaved.ui = BreSaved.ui or {}
  if type(BreSaved.ui.profile_mode) ~= "string" then
    -- Default: FULL build => FULL, otherwise THEME (BanruoUI child default)
    BreSaved.ui.profile_mode = (P:IsFull() and "FULL") or "THEME"
  end
  return BreSaved.ui.profile_mode
end

local function _NormalizeMode(mode)
  mode = tostring(mode or ""):upper()
  if mode == "DEV" or mode == "THEME" or mode == "FULL" then return mode end
  return nil
end

function P:GetMode()
  return _EnsureSavedProfileMode()
end

function P:SetMode(mode)
  local m = _NormalizeMode(mode)
  if not m then return end
  _EnsureSavedProfileMode()
  BreSaved.ui.profile_mode = m
  -- Best-effort apply (no hard dependency on UI/DB)
  if Bre and Bre.Profile and Bre.Profile.Apply then
    pcall(function() Bre.Profile:Apply() end)
  end
end

-- Apply current mode to UI switches (safe to call repeatedly).
function P:Apply(ui)
  local mode = self:GetMode()
  ui = ui or (Bre and Bre.UI)

  local W = Bre and Bre.UIWhitelist
  local U = ui

  -- 1) SizeMode + LayoutPreset
  if U then
    -- Profile rule:
    -- THEME => COMPACT (560x560) + THEME_310_250 layout
    -- DEV/FULL => LEGACY (original size) + LEGACY_DEFAULT layout
    if mode == "THEME" then
      if U.SetLayoutPreset then pcall(function() U:SetLayoutPreset("THEME_320_240") end) end
      if U.SetSizeMode then
        pcall(function() U:SetSizeMode("COMPACT") end)
        U._currentSizeMode = "COMPACT"
      end
    else
      if U.SetLayoutPreset then pcall(function() U:SetLayoutPreset("LEGACY_DEFAULT") end) end
      if U.SetSizeMode then
        pcall(function() U:SetSizeMode("LEGACY") end)
        U._currentSizeMode = "LEGACY"
      end
    end
  end

  -- 2) Drawer routing + Whitelist
  if W then
    if mode == "THEME" then
      pcall(function()
        W:SetThemeMinimalMode(true)
        W:SetEnabled(true)
      end)
    else
      pcall(function()
        W:SetThemeMinimalMode(false)
        W:SetEnabled(false) -- disable whitelist so FULL/DEV shows all
      end)
    end
  end

  -- 3) UI refresh / re-apply whitelist (no commit)
  if U and U.ApplyUIWhitelist then
    pcall(function() U:ApplyUIWhitelist() end)
  end
  if U and U.RefreshRight then
    pcall(function() U:RefreshRight() end)
  end
end
