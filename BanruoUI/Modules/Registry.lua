-- Modules/Registry.lua
-- 模块注册表：Core 只读注册表并渲染；具体页面由 Modules 自己创建
local B = BanruoUI
if not B then return end

B._modules = B._modules or {}       -- id -> def
B._moduleOrder = B._moduleOrder or {} -- ordered ids

function B:RegisterModule(id, def)
  if type(id) ~= "string" or id == "" then return false end
  if type(def) ~= "table" then return false end
  def.id = id
  -- 为支持模块列表多语言：模块注册时推荐提供 titleKey（如 "MODULE_THEME_PREVIEW"）
  -- UI 渲染时再用 B:Loc(titleKey) 取词，避免加载期缓存成 key/旧语言。
  def.titleKey = def.titleKey or def.title_key
  def.title = def.title or id
  def.order = tonumber(def.order or 999) or 999
  self._modules[id] = def

  -- rebuild order list (stable by order then title)
  local ids = {}
  for mid in pairs(self._modules) do table.insert(ids, mid) end
  table.sort(ids, function(a,b)
    local da, db = self._modules[a], self._modules[b]
    if da.order ~= db.order then return da.order < db.order end
    -- 用 titleKey/标题做稳定排序（不依赖当前语言取词）
    return tostring(da.titleKey or da.title) < tostring(db.titleKey or db.title)
  end)
  self._moduleOrder = ids
  return true
end

function B:GetModules()
  local out = {}
  for _, id in ipairs(self._moduleOrder or {}) do
    table.insert(out, self._modules[id])
  end
  return out
end

function B:GetModule(id)
  return id and self._modules and self._modules[id] or nil
end
