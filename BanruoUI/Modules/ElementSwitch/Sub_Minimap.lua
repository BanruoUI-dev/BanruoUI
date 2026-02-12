-- Modules/ElementSwitch/Sub_Minimap.lua
-- v1.6.1 Step1: 小地图（Minimap）子模块（占位）

local B = BanruoUI
if not B then return end

-- elementId 作为内部绑定键（后续 Adapter 用）；显示文本走 Locale（运行时取词）
local ELEMENTS = {
  { id = "minimap_frame", labelKey = "ES_MM_FRAME" },
  { id = "minimap_bg",    labelKey = "ES_MM_BG" },
}

B:ES_RegisterSubModule("es_minimap", {
  titleKey = "ES_MM_TITLE",
  order = 2,
  Create = function(self, parent, ui)
    if not ui or type(ui.AddItem) ~= "function" then return end
    for _, e in ipairs(ELEMENTS) do
      ui.AddItem(e.id, B:Loc(e.labelKey))
    end
  end,
  Refresh = function(self, parent) end,
})
