-- Bre/Core/DrawerSpec_Actions.lua
-- Spec definition for Actions drawer (Output Actions)
-- v2.18.40: migrated from UI.lua hand-made pane to DrawerTemplate.
-- v2.18.46: add rotation params UI-only (angle/dir/anchor/end state) + i18n keys.

local addonName, Bre = ...
Bre = Bre or {}

-- This spec is intentionally UI-only (no commit logic yet).
Bre.DrawerSpec_Actions = {
  drawerId = "Actions",
  title = "TAB_ACTIONS", -- "输出动作"

  -- Rotation speed numeric range (deg/s)
  speedMin = 0,
  speedMax = 300,
  speedStep = 1,
  defaultSpeed = 90,

  dirOptions = {
    { value = "cw",  textKey = "ACTIONS_ROT_DIR_CW"  },
    { value = "ccw", textKey = "ACTIONS_ROT_DIR_CCW" },
  },
  defaultDirValue = "cw",

  anchorOptions = {
    { value = "CENTER",      textKey = "ACTIONS_ANCHOR_CENTER"      },
    { value = "TOPLEFT",     textKey = "ACTIONS_ANCHOR_TOPLEFT"     },
    { value = "TOPRIGHT",    textKey = "ACTIONS_ANCHOR_TOPRIGHT"    },
    { value = "BOTTOMLEFT",  textKey = "ACTIONS_ANCHOR_BOTTOMLEFT"  },
    { value = "BOTTOMRIGHT", textKey = "ACTIONS_ANCHOR_BOTTOMRIGHT" },
  },
  defaultAnchorValue = "CENTER",

  endStateOptions = {
    { value = "keep",  textKey = "ACTIONS_ROT_END_KEEP"  },
    { value = "reset", textKey = "ACTIONS_ROT_END_RESET" },
  },
  defaultEndStateValue = "keep",

  -- Angle slider defaults (UI only)
  angleMin = 0,
  angleMax = 360,
  angleStep = 1,
  defaultAngle = 360,

  -- Only specific content for now. No built-in attributes/position sections.
  specificContent = {
    { type = "label", text = "ACTIONS_ROT_SECTION", x = 22, y = -8 },

    -- Row 1 启用
    { type = "checkbox", id = "rot_enable", text = "ACTIONS_ROT_ENABLE", x = 22, y = -44 },

    -- Row 2 速率（输入框 + 滑块）
    { type = "label", text = "ACTIONS_ROT_SPEED", x = 24, y = -82 },
    { type = "numericbox", id = "rot_speed_num", x = 24 + 42, y = -79 },
    { type = "slider", id = "rot_speed_slider", x = 24, y = -112, width = 140 },

    -- Row 3 方向
    { type = "label", text = "ACTIONS_ROT_DIR", x = 210, y = -82 },
    { type = "dropdown", id = "rot_dir", x = 180 , y = -105, width = 130 },
  },
}

-- --------------------------------------------------------------------
-- Functional Drawer (v1.4): explicit Refresh backfill
-- --------------------------------------------------------------------
function Bre.DrawerSpec_Actions:Refresh(ctx)
  local DT = Bre and Bre.DrawerTemplate
  if not DT or not DT._RefreshActions then return end
  local drawer = ctx and ctx.drawer
  local controls = (ctx and ctx.controls) or (drawer and drawer._controls) or {}
  local data = (ctx and ctx.data) or {}
  DT:_RefreshActions(drawer, controls, data, ctx and ctx.nodeId)
end

