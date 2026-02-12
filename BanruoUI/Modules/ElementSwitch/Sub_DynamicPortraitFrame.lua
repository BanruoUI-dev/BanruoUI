-- Modules/ElementSwitch/Sub_DynamicPortraitFrame.lua
-- v1.6.1 Step1: 动态相框（Dynamic Portrait Frame）子模块（占位）

local B = BanruoUI
if not B then return end

-- UI 文案走本地化；elementId 作为内部绑定键（后续 Adapter 用）
local ELEMENTS = {
  { id = "frame", labelKey = "ES_DPF_FRAME", fallback = "框体" },
  { id = "bg",    labelKey = "ES_DPF_BG",    fallback = "底纹" },
  { id = "portrait", labelKey = "ES_DPF_PORTRAIT", fallback = "3D 人物" },
}

B:ES_RegisterSubModule("es_dynamic_portrait_frame", {
  -- title 不在注册期直接 B:Loc()（避免加载期缓存 key）；由 Container 渲染时取词
  titleKey = "ES_DPF_TITLE",
  title = "动态相框", -- fallback
  order = 1,
  Create = function(self, parent, ui)
    if not ui or type(ui.AddItem) ~= "function" then return end
    for _, e in ipairs(ELEMENTS) do
      local text = e.fallback
      if B and type(B.Loc) == "function" and e.labelKey then
        text = B:Loc(e.labelKey)
      end
      if e.id == "portrait" then text = "  " .. tostring(text) end -- portrait_indent
      ui.AddItem(e.id, text)
    end
  end,
  Refresh = function(self, parent)
    -- Step1: nothing
  end,
})
