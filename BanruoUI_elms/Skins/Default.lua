-- Bre/Skins/Default.lua
-- Default skin (matches current Bre v2.8 look)

local _, Bre = ...
Bre = Bre or {}
Bre.Skins = Bre.Skins or {}

Bre.Skins.Default = {
  name = "Default",

  colors = {
    ACCENT = { 1.0, 0.82, 0.0, 1.0 },
    PANEL_BG = { 0.03, 0.03, 0.03, 0.88 },
    PANEL_BG_SOFT = { 0.00, 0.00, 0.00, 0.65 },
    BTN_ACTIVE_BG = { 0.12, 0.12, 0.12, 0.85 },
    BTN_BG = { 0.00, 0.00, 0.00, 0.00 },
    ROW_SELECTED_BG = { 0.00, 0.00, 0.00, 0.15 },
  },

  borders = {
    PANEL = { edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1, inset = 2, alpha = 0.35 },
    PANEL_STRONG = { edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1, inset = 3, alpha = 0.65 },
    BTN = { edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1, alpha = 0.55 },
    BTN_STRONG = { edgeFile = "Interface/Buttons/WHITE8x8", edgeSize = 1, alpha = 0.65 },
  },
}
