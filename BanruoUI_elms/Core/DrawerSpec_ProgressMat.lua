-- Bre/Core/DrawerSpec_ProgressMat.lua
-- Step8 (v2.14.69): Spec definition for ProgressMat drawer

local addonName, Bre = ...
Bre = Bre or {}

Bre.DrawerSpec_ProgressMat = {
  drawerId = "ProgressMat",
  title = "NEW_BTN_MAT_PROGRESS", -- "进度条材质"
  
  -- Specific content section (ProgressMat unique controls)
  -- Step9: All y coordinates adjusted upward by 14px
  -- Step10.1: Redesigned layout - 2 rows x 3 columns
  specificContent = {
    -- Row : 前景材质/背景材质
    
    
    
    
    -- Row：进度条类型/监听单位
    {
      type = "label",
      text = "PROG_MAT_TYPE",
      x = 18,
      y = -6,
    },
    {
      type = "dropdown",
      id = "type",
      x = -5,
      y = -28,
      width = 140,
    },
    {
      type = "label",
      text = "PROG_MAT_UNIT",
      x = 210,
      y = -6,
    },
    {
      type = "dropdown",
      id = "progressUnit",
      x = 187,
      y = -28,
      width = 140,
    },
 
   -- Row：进度条方向/遮罩材质
    {
      type = "label",
      text = "PROG_MAT_DIRECTION",
      x = 18,
      y = -62,
    },
    
    {
      type = "dropdown",
      id = "progressDirection",
      x = -5,
      y = -80,
      width = 140,
    },
    
    {
      type = "label",
      text = "PROG_MAT_MASK",
      x = 210,
      y = -62,
    },
    {
      type = "combo_input",
      id = "mask",
      x = 210,
      y = -80,
      width = 150,
    },
    
    
    
    -- Row：褪色/前景颜色/前景
    {
      type = "checkbox",
      id = "fade",
      text = "ELEM_MAT_FADE",
      x = 18,
      y = -128,
    },
    
    {
      type = "label",
      text = "PROG_MAT_FG_COLOR",
      x = 85,
      y = -134,
    },
    
    {
      type = "color_button",
      id = "fgColor",
      x = 141,
      y = -134,
    },
     {
      type = "label",
      text = "PROG_MAT_FG",
      x = 195,
      y = -134,
    },
    {
      type = "combo_input",
      id = "foreground",
      x = 230,
      y = -127,
      width = 130,
    },
    
    -- Row：镜像/背景颜色/背景
    {
      type = "checkbox",
      id = "mirror",
      text = "ELEM_MAT_MIRROR",
      x = 18,
      y = -165,
    },
    
    {
      type = "label",
      text = "PROG_MAT_BG_COLOR",
      x = 85,
      y = -172,
    },
    
    {
      type = "color_button",
      id = "bgColor",
      x = 141,
      y = -172,
    },
     {
      type = "label",
      text = "PROG_MAT_BG",
      x = 195,
      y = -172,
    },
    {
      type = "combo_input",
      id = "background",
      x = 230,
      y = -165,
      width = 130,
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
function Bre.DrawerSpec_ProgressMat:Refresh(ctx)
  local DT = Bre and Bre.DrawerTemplate
  if not DT or not DT._RefreshProgressMat then return end
  local controls = (ctx and ctx.controls) or (ctx and ctx.drawer and ctx.drawer._controls) or {}
  local data = (ctx and ctx.data) or {}
  DT:_RefreshProgressMat(controls, data, ctx and ctx.nodeId)
end

return Bre.DrawerSpec_ProgressMat
