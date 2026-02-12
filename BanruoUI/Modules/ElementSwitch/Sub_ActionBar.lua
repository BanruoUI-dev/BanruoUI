-- Modules/ElementSwitch/Sub_ActionBar.lua
-- v1.6.1 Step1: 动作条（Action Bar）子模块（占位）

local B = BanruoUI
if not B then return end

-- UI 文案通过 Locale 表渲染；elementId 作为内部绑定键（后续 Adapter 用）
local ELEMENTS = {
  { id = "actionbar_bg",     labelKey = "ES_AB_BG" },
  { id = "orb_right",        labelKey = "ES_AB_ORB_R" },
  { id = "orb_right_decor",  labelKey = "ES_AB_ORB_R_DECOR" },
  { id = "orb_left",         labelKey = "ES_AB_ORB_L" },
  { id = "orb_left_decor",   labelKey = "ES_AB_ORB_L_DECOR" },
}

B:ES_RegisterSubModule("es_actionbar", {
  titleKey = "ES_AB_TITLE",
  order = 3,
  Create = function(self, parent, ui)
    if not ui or type(ui.AddItem) ~= "function" then return end
    for _, e in ipairs(ELEMENTS) do
      ui.AddItem(e.id, B:Loc(e.labelKey))
    end
  end,
  Refresh = function(self, parent) end,
})
