-- Bre/Core/DrawerSpec_Model.lua
-- Step1.1 (v2.18.75): 3D Model drawer functional shell (UI structure only; no wiring)

local addonName, Bre = ...
Bre = Bre or {}

Bre.DrawerSpec_Model = {
  drawerId = "Model",
  title = "NEW_BTN_MODEL", -- "3D人物"

  -- Specific content: UI shell only (no event wiring yet).
  -- NOTE: DrawerTemplate currently only refreshes/wires known drawerIds (CustomMat/ProgressMat/Actions/Conditions).
  --       Model drawer controls are intentionally inert in this step.
  specificContent = {
       
    -- Row: Source mode (Unit / FileID) + Value (combo_input)
    { type = "label", text = "MODEL_MODE", x = 18, y = -22 },
    { type = "dropdown", id = "modelMode", x = -5, y = -44, width = 140 },
    { type = "label", text = "MODEL_INPUT", x = 210, y = -22 },
    { type = "combo_input", id = "modelValue", x = 210, y = -44, width = 150 },

    -- Row: Facing (numeric + slider)
    { type = "label", text = "MODEL_FACING", x = 18, y = -108 },
    { type = "numericbox", id = "facing", x = 68, y = -103 },
    { type = "slider", id = "facingSlider", x = 18, y = -130, width = 150, min = 0, max = 360, step = 1 },

    -- Row: Animation sequence (v2.18.87)
    { type = "label", text = "MODEL_ANIM", x = 210, y = -108 },
    { type = "pager_input", id = "animSequence", x = 210, y = -125, width = 150 },
  },

  -- Common built-in sections (template-managed)
  attributes = "default",
  position = "default",
}

-- --------------------------------------------------------------------
-- Functional Drawer (v1.4): explicit Refresh backfill
-- --------------------------------------------------------------------
function Bre.DrawerSpec_Model:Refresh(ctx)
  local DT = Bre and Bre.DrawerTemplate
  if not DT or not DT._RefreshModel then return end
  local drawer = ctx and ctx.drawer
  local controls = (ctx and ctx.controls) or (drawer and drawer._controls) or {}
  local data = (ctx and ctx.data) or {}
  DT:_RefreshModel(drawer, controls, data, ctx and ctx.nodeId)
end

return Bre.DrawerSpec_Model
