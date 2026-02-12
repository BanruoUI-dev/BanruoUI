-- Bre/Core/DrawerSpec_ThemeMinimal.lua
-- Template-only: Theme minimal drawer (single column, 5 fields)
-- NOTE: This spec is NOT wired/enabled anywhere yet. It is provided as a future Bre_theme asset.
-- Constitution v1.5 compliant (spec-only): no DB writes, no Move calls, no side effects.

local addonName, Bre = ...
Bre = Bre or {}

Bre.DrawerSpec_ThemeMinimal = {
  drawerId = "ThemeMinimal",
  title = "THEME_MINIMAL_TITLE",

  -- L2 module capability declaration (v1.5 mandatory; template-only)
  runtime_required = false,
  authoring_required = false,

  -- Single-column layout (explicit coordinates; built from existing control primitives)
  -- Note: Uses the same control ids as the built-in attribute/position template so we can reuse
  -- DrawerTemplate's proven Refresh/Wire logic (but arranged in 1 column).
  specificContent = {
    -- ===== Size =====
    { type = "label",      text = "THEME_MINIMAL_SECTION_SIZE", x = 18, y = -10 },

    { type = "label",      text = "ELEM_MAT_HEIGHT", x = 18, y = -34 },
    { type = "numericbox", id = "hNum",   x = 70, y = -36 },
    { type = "slider",     id = "hSlider", x = 18, y = -52, width = 150, min = 1, max = 2048, step = 1 },

    { type = "label",      text = "ELEM_MAT_WIDTH", x = 18, y = -90 },
    { type = "numericbox", id = "wNum",   x = 70, y = -92 },
    { type = "slider",     id = "wSlider", x = 18, y = -108, width = 150, min = 1, max = 2048, step = 1 },

    -- ===== Position =====
    { type = "label",      text = "THEME_MINIMAL_SECTION_POS", x = 18, y = -160 },

    { type = "label",      text = "ELEM_MAT_FRAME_LEVEL", x = 18, y = -184 },
    { type = "dropdown",   id = "strataDD", x = 0, y = -206, width = 150 },

    { type = "label",      text = "ELEM_MAT_XOFF", x = 18, y = -248 },
    { type = "numericbox", id = "xNum",   x = 70, y = -250 },
    { type = "slider",     id = "xSlider", x = 18, y = -266, width = 150, min = -4096, max = 4096, step = 1 },

    { type = "label",      text = "ELEM_MAT_YOFF", x = 18, y = -304 },
    { type = "numericbox", id = "yNum",   x = 70, y = -306 },
    { type = "slider",     id = "ySlider", x = 18, y = -322, width = 150, min = -4096, max = 4096, step = 1 },
  },
}

function Bre.DrawerSpec_ThemeMinimal:Refresh(ctx)
  local DT = Bre.DrawerTemplate
  if not DT or not ctx or not ctx.controls or type(ctx.data) ~= "table" then return end
  -- Reuse proven core refresh logic (no side effects; guarded by DrawerTemplate).
  DT:_RefreshAttributes(ctx.controls, ctx.data)
  DT:_RefreshPosition(ctx.controls, ctx.data, ctx.nodeId)
end

function Bre.DrawerSpec_ThemeMinimal:WireEvents(ctx)
  local DT = Bre.DrawerTemplate
  if not DT or not ctx or not ctx.drawer or not ctx.controls then return end
  -- Reuse proven core wiring for size + position (commit only on whitelist events).
  DT:_WireAttributeEvents(ctx.drawer, ctx.controls)
  DT:_WirePositionEvents(ctx.drawer, ctx.controls)
end

return Bre.DrawerSpec_ThemeMinimal
