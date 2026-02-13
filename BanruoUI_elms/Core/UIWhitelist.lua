-- Bre/Core/UIWhitelist.lua
-- UI whitelist + switch + apply dispatcher (extensible)
--
-- Scope for this iteration (per user request):
--   - Top action buttons whitelist
--   - Right drawers (tabs) whitelist
--
-- Future extensibility (reserved keys):
--   - drawer_sections
--   - controls

local addonName, Bre = ...
Bre = Bre or {}

Bre.UIWhitelist = Bre.UIWhitelist or {}
local W = Bre.UIWhitelist

-- ------------------------------
-- Default config (white-list only; does NOT auto-apply)
-- ------------------------------
W.config = W.config or {
  top_buttons = {
    -- keys must match UI's internal mapping (e.g. "Import", "Close", "New")
    allow = { Import = true, New = true, Close = true },
  },
  drawers = {
    -- keys must match right tab keys (e.g. "Element", "LoadIO")
    allow = { Element = true, LoadIO = true },
  },

  -- reserved (future)
  drawer_sections = {},
  controls = {},
}

-- ------------------------------
-- Switches (default ON; ThemeMinimal preset)
-- ------------------------------
W.state = W.state or {
  enabled = true,
  enable_top_buttons = true,
  enable_drawers = true,
  -- opt-in routing helpers (future profiles)
  theme_minimal_mode = true,
  -- reserved (future)
  enable_drawer_sections = false,
  enable_controls = false,
}

local function _Bool(v) return v == true end

function W:SetEnabled(on)
  self.state.enabled = _Bool(on)
  self:TryApply()
end

function W:SetLevelEnabled(levelKey, on)
  if type(levelKey) ~= "string" then return end
  local k = "enable_" .. levelKey
  if self.state[k] == nil then return end
  self.state[k] = _Bool(on)
  self:TryApply()
end

-- ThemeMinimal mode is an opt-in routing flag used by UI:RefreshRight.
-- Default OFF (no behavior change). When ON (and whitelist enabled),
-- Element pane routes all element drawers to ThemeMinimal.
function W:SetThemeMinimalMode(on)
  self.state.theme_minimal_mode = _Bool(on)
  self:TryApply()
end

-- Optional: allow external code to replace config table.
function W:SetConfig(cfg)
  if type(cfg) ~= "table" then return end
  self.config = cfg
  self:TryApply()
end

-- Apply dispatcher (no side effects if disabled)
function W:Apply(ui)
  if not ui then return end

  -- When whitelist is disabled, we must actively restore all UI visibilities
  -- so switching THEME -> FULL/DEV does not leave buttons/tabs hidden.
  if not self.state.enabled then
    if ui.ApplyTopButtonsWhitelist then ui:ApplyTopButtonsWhitelist(nil) end
    if ui.ApplyDrawersWhitelist then ui:ApplyDrawersWhitelist(nil) end
    return
  end

  if self.state.enable_top_buttons and ui.ApplyTopButtonsWhitelist then
    ui:ApplyTopButtonsWhitelist(self.config.top_buttons)
  end

  if self.state.enable_drawers and ui.ApplyDrawersWhitelist then
    ui:ApplyDrawersWhitelist(self.config.drawers)
  end

  -- reserved (future)
  -- if self.state.enable_drawer_sections and ui.ApplyDrawerSectionsWhitelist then
  --   ui:ApplyDrawerSectionsWhitelist(self.config.drawer_sections)
  -- end
  -- if self.state.enable_controls and ui.ApplyControlsWhitelist then
  --   ui:ApplyControlsWhitelist(self.config.controls)
  -- end
end

function W:TryApply()
  local UI = Bre and Bre.UI
  if not UI or not UI.frame then return end
  if UI.ApplyUIWhitelist then
    UI:ApplyUIWhitelist()
  else
    -- fallback: call Apply directly if UI didn't add a wrapper
    self:Apply(UI)
  end
end