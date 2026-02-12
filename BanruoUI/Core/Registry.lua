-- Core/Registry.lua
-- 只负责：BRE / ElvUI 字符串“仓库”与注册接口
-- 兼容：保留 RegisterWA/GetWA 作为别名（历史主题包可继续用）
-- 不负责：主题注册（主题注册在 Core/Bootstrap.lua 里）

local B = BanruoUI
if not B then return end

-- BRE pool (id -> {id,name,data})
B._brePool = B._brePool or {}
-- ElvUI pool
B._elvPool = B._elvPool or {}

-- -----------------------------------------------------------------------------
-- BRE registry (primary)
-- -----------------------------------------------------------------------------
function B:RegisterBRE(def)
  if type(def) ~= "table" then return false end
  if not def.id or not def.data then return false end
  self._brePool[tostring(def.id)] = def
  return true
end

function B:GetBRE(id)
  if not id then return nil end
  return self._brePool[tostring(id)]
end

-- -----------------------------------------------------------------------------
-- ElvUI registry
-- -----------------------------------------------------------------------------
function B:RegisterElvUIProfile(def)
  if type(def) ~= "table" then return false end
  if not def.id or not def.data then return false end
  self._elvPool[tostring(def.id)] = def
  return true
end

function B:GetElvUIProfile(id)
  if not id then return nil end
  return self._elvPool[tostring(id)]
end

-- -----------------------------------------------------------------------------
-- Compatibility (WA is legacy)
-- -----------------------------------------------------------------------------
-- Old theme packs may still call RegisterWA/GetWA.
-- We route them into the BRE pool so BanruoUI only has one source of truth.
function B:RegisterWA(def)
  return self:RegisterBRE(def)
end

function B:GetWA(id)
  return self:GetBRE(id)
end
