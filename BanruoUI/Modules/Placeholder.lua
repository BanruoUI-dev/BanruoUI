-- Modules/Placeholder.lua
-- 占位模块：故事集/点歌机（v1.5：元素开关已独立为可用模块）

local B = BanruoUI
if not B then return end

local function CreatePlaceholder(parent, titleKey)
  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)

  local h = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Large() or "GameFontNormalLarge"))
  h:SetPoint("TOPLEFT", 16, -18)
  h:SetText((titleKey and B and B.Loc) and B:Loc(titleKey) or "")

  local t = page:CreateFontString(nil, "OVERLAY", (B.Font and B.Font:Highlight() or "GameFontHighlight"))
  t:SetPoint("TOPLEFT", 16, -60)
  t:SetPoint("TOPRIGHT", -16, -60)
  t:SetJustifyH("LEFT")
  t:SetJustifyV("TOP")
  t:SetText((B and B.Loc) and B:Loc("TEXT_PLACEHOLDER_UNAVAILABLE") or "不可用/敬请期待")

  return page
end

local function register(id, titleKey, order)
  B:RegisterModule(id, {
    titleKey = titleKey,
    order = order,
    Create = function(self, parent) return CreatePlaceholder(parent, titleKey) end,
  })
end

register("story_collection", 'MODULE_STORY_COLLECTION', 20)

-- "jukebox" 可能会被其他模块（如 BrMusic）注册。
-- 这里仅在尚未注册时提供占位页面，避免覆盖真实实现。
if not (B.GetModule and B:GetModule("jukebox")) then
  register("jukebox", 'MODULE_BRMUSIC', 30)
end
