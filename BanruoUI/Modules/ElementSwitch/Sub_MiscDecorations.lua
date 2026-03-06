-- Modules/ElementSwitch/Sub_MiscDecorations.lua
-- v1.6.1 Step1: 散件装饰（Misc Decorations）子模块（占位）
-- v1.6.2：由容器统一负责“两两一行”排版（本子模块只上报元素清单）

local B = BanruoUI
if not B then return end

-- elementId 作为内部绑定键（后续 Adapter 用）；label 走本地化 key
local ELEMENTS = {
  { id = "misc_top_strip",    labelKey = "ES_MISC_TRIM_TOP" },
  { id = "misc_bottom_strip", labelKey = "ES_MISC_TRIM_BOTTOM" },
  { id = "misc_deco1",        labelKey = "ES_MISC_DECOR_1" },
  { id = "misc_deco2",        labelKey = "ES_MISC_DECOR_2" },
  { id = "misc_deco3",        labelKey = "ES_MISC_DECOR_3" },
  { id = "misc_deco4",        labelKey = "ES_MISC_DECOR_4" },
  { id = "misc_deco5",        labelKey = "ES_MISC_DECOR_5" },
  { id = "misc_deco6",        labelKey = "ES_MISC_DECOR_6" },
  { id = "misc_deco7",        labelKey = "ES_MISC_DECOR_7" },
  { id = "misc_deco8",        labelKey = "ES_MISC_DECOR_8" },
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
