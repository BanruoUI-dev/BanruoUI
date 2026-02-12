-- Modules/ElementSwitch/Sub_MiscDecorations.lua
-- v1.6.1 Step1: 散件装饰（Misc Decorations）子模块（占位）
-- v1.6.2：由容器统一负责“两两一行”排版（本子模块只上报元素清单）

local B = BanruoUI
if not B then return end

-- elementId 作为内部绑定键（后续 Adapter 用）；label 走本地化 key
local ELEMENTS = {
  { id = "trim_top",    labelKey = "ES_MISC_TRIM_TOP" },
  { id = "trim_bottom", labelKey = "ES_MISC_TRIM_BOTTOM" },
  { id = "decor_1",     labelKey = "ES_MISC_DECOR_1" },
  { id = "decor_2",     labelKey = "ES_MISC_DECOR_2" },
  { id = "decor_3",     labelKey = "ES_MISC_DECOR_3" },
  { id = "decor_4",     labelKey = "ES_MISC_DECOR_4" },
  { id = "decor_5",     labelKey = "ES_MISC_DECOR_5" },
  { id = "decor_6",     labelKey = "ES_MISC_DECOR_6" },
  { id = "decor_7",     labelKey = "ES_MISC_DECOR_7" },
  { id = "decor_8",     labelKey = "ES_MISC_DECOR_8" },
}

B:ES_RegisterSubModule("es_misc_decorations", {
  titleKey = "ES_MISC_TITLE",
  order = 4,
  Create = function(self, parent, ui)
    if not ui or type(ui.AddItem) ~= "function" then return end
    for _, e in ipairs(ELEMENTS) do
      ui.AddItem(e.id, B:Loc(e.labelKey))
    end
  end,
  Refresh = function(self, parent)
    -- placeholder
  end,
})
