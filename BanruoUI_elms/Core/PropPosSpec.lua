-- Bre/Core/PropPosSpec.lua
-- L2 Spec: Property + Position drawer (placeholder scaffold)
-- Step2 (v2.18.68): introduce Spec-only module; not wired to any existing drawer yet.

local addonName, Bre = ...
Bre = Bre or {}

-- NOTE:
-- This spec is a scaffold only. The actual controls + wiring will be implemented
-- during Step3 migrations, reusing the already-established UI -> PropertyService
-- commit chain and EditGuard refresh discipline.

Bre.PropPosSpec = {
  drawerId = "PropPos",
  title = "TAB_PROP_POS",

  -- L2 module capability declaration (v1.5 mandatory)
  runtime_required = false,
  authoring_required = false,

  specificContent = {
    { type = "label", text = "Prop+Pos", x = 22, y = -8 },
    { type = "label", text = "(placeholder: X/Y, Anchor/Point, Alpha, Size, Strata)", x = 22, y = -36 },
  },

  -- Future-proof hooks (optional): DrawerChassis may call these when present.
  Build = function(ctx) end,
  Refresh = function(ctx) end,
}
