-- Bre/Core/DrawerSpec_Conditions.lua
-- Spec definition for Conditions drawer (Input Conditions)
-- v2.18.43: introduce template-based Conditions drawer skeleton (UI-only).

local addonName, Bre = ...
Bre = Bre or {}

-- This spec is intentionally UI-only (no commit logic yet).
Bre.DrawerSpec_Conditions = {
  drawerId = "Conditions",
  title = "TAB_CONDITIONS", -- "输入条件"

  specificContent = {
    { type = "label", text = "TAB_CONDITIONS", x = 22, y = -8 },
    { type = "label", text = "COND_PLACEHOLDER", x = 22, y = -36 },
  },
}

-- --------------------------------------------------------------------
-- Functional Drawer (v1.4): explicit Refresh backfill
-- --------------------------------------------------------------------
function Bre.DrawerSpec_Conditions:Refresh(ctx)
  local DT = Bre and Bre.DrawerTemplate
  if not DT or not DT._RefreshConditions then return end
  local drawer = ctx and ctx.drawer
  local controls = (ctx and ctx.controls) or (drawer and drawer._controls) or {}
  local data = (ctx and ctx.data) or {}
  DT:_RefreshConditions(drawer, controls, data, ctx and ctx.nodeId)
end

