-- Bre/Core/TargetResolver.lua
-- v2.11.13
-- ResolveTargetFrame(nodeId): read-only resolver for anchor targets.
-- MUST NOT create runtime frames or cause any movement.

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate

Bre.TargetResolver = Bre.TargetResolver or {}
local R = Bre.TargetResolver

R.version = "2.11.13"

local function _isRectCapable(obj)
  if not obj then return false end
  local ok, l, b, w, h = pcall(obj.GetRect, obj)
  return ok and l and b and w and h and w > 0 and h > 0
end

function R:ResolveTargetFrame(nodeId)
  if type(nodeId) ~= "string" or nodeId == "" then return nil end
  local Move = Gate and Gate:Get("Move")
  if not Move or type(Move.GetRuntimeRegion) ~= "function" then return nil end

  local region = Move:GetRuntimeRegion(nodeId)
  if not region then return nil end

  -- Preferred: return the visible, rect-capable root object for screen picking/highlight.
  if type(region) == "table" then
    local u = region[0]
    if u and _isRectCapable(u) then return u end
    if region._root and _isRectCapable(region._root) then return region._root end
    if region.frame and _isRectCapable(region.frame) then return region.frame end
    if region.region and _isRectCapable(region.region) then return region.region end
    if region._tex and _isRectCapable(region._tex) then return region._tex end
    if u ~= nil then return u end
    return nil
  end

  if _isRectCapable(region) then return region end
  return region
end

-- Allow Gate:Get('ResolveTargetFrame')(nodeId) style (callable table)
setmetatable(R, {
  __call = function(self, nodeId)
    if type(self.ResolveTargetFrame) == "function" then
      return self:ResolveTargetFrame(nodeId)
    end
    return nil
  end,
})
