-- Bre/Core/DrawerSpec_CustomMat.lua
-- Step4 (v2.14.69): Spec definition for CustomMat drawer
-- This defines the drawer structure without implementing the UI yet.

local addonName, Bre = ...
Bre = Bre or {}

Bre.DrawerSpec_CustomMat = {
  drawerId = "CustomMat",
  title = "ELEM_MAT_TITLE", -- "自定义材质"
  
  -- Specific content section (CustomMat unique controls)
  specificContent = {
    -- Material path label
    -- Step9: Reduced y from -20 to -6 (saves 14px)
    {
      type = "label",
      text = "ELEM_MAT_TEXTURE",
      x = 18,
      y = -6,
    },
    
    -- Material path editbox (full width)
    {
      type = "fullwidth_editbox",
      id = "texturePath",
      x = 18,
      y = -28,
    },
    
    -- Texture preview
    {
      type = "texture_preview",
      id = "preview",
      x = 18,
      y = -66,
      size = 72,
    },
    
    -- UseColor label + color button
    {
      type = "label",
      text = "ELEM_MAT_USE_COLOR",
      x = 100,
      y = -72,
    },
    
    {
      type = "color_button",
      id = "colorBtn",
      x = 130, -- aligned with useColor label (right after text)
      y = -72,
    },
    
    -- Mirror checkbox
    {
      type = "checkbox",
      id = "mirror",
      text = "ELEM_MAT_MIRROR",
      x = 260,
      y = -112,
    },
    
    -- Fade checkbox
    {
      type = "checkbox",
      id = "fade",
      text = "ELEM_MAT_FADE",
      x = 260,
      y = -72,
    },
  },
  
  -- Use default built-in attribute section
  attributes = "default",
  
  -- Use default built-in position section
  position = "default",
}

-- --------------------------------------------------------------------
-- Functional Drawer (v1.4): explicit Refresh backfill
-- --------------------------------------------------------------------
function Bre.DrawerSpec_CustomMat:Refresh(ctx)
  local DT = Bre and Bre.DrawerTemplate
  if not DT or not DT._RefreshCustomMat then return end
  local controls = (ctx and ctx.controls) or (ctx and ctx.drawer and ctx.drawer._controls) or {}
  local data = (ctx and ctx.data) or {}
  DT:_RefreshCustomMat(controls, data, ctx and ctx.nodeId)
end

return Bre.DrawerSpec_CustomMat
