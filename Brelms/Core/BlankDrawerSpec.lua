-- Bre/Core/BlankDrawerSpec.lua
-- L2 Spec: Blank drawer placeholder (no-op Build/Refresh)
-- Step2 (v2.18.68): introduce Spec-only module; not wired to any existing drawer yet.

local addonName, Bre = ...
Bre = Bre or {}

-- This is intentionally minimal. It exists to validate drawer system cleanliness
-- and to provide a safe starting point for new drawer work.
Bre.BlankDrawerSpec = {
  drawerId = "Blank",
  title = "TAB_BLANK",
  -- L2 module capability declaration (v1.5 mandatory)
  runtime_required = false,
  authoring_required = false,
  specificContent = {
    { type = "label", text = "Blank", x = 22, y = -8 },
    { type = "label", text = "(no-op spec placeholder)", x = 22, y = -36 },
  },

  -- Future-proof hooks (optional): DrawerChassis may call these when present.
  Build = function(ctx) end,
  Refresh = function(ctx) end,
}
