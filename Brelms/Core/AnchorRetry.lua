-- Bre/Core/AnchorRetry.lua
-- v2.11.11
-- Step3: BrA-style postpone + retry queue for anchor targets.
-- IMPORTANT: This module MUST NOT cause any movement or commit. It only tracks resolution readiness.

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate

Bre.AnchorRetry = Bre.AnchorRetry or {}
local AR = Bre.AnchorRetry

AR.version = "2.11.11"

-- activeId -> targetId (pending)
AR.pending = AR.pending or {}
-- activeId -> resolved frame userdata (or true)
AR.resolved = AR.resolved or {}

AR._ticker = AR._ticker or nil
AR._updateFrame = AR._updateFrame or nil
AR._accum = AR._accum or 0
AR._interval = 1.0

local function _now()
  if GetTime then return GetTime() end
  return 0
end

function AR:Postpone(activeId, targetId)
  if type(activeId) ~= "string" or activeId == "" then return false end
  if type(targetId) ~= "string" or targetId == "" then return false end
  AR.pending[activeId] = targetId
  AR.resolved[activeId] = nil
  return true
end

function AR:Clear(activeId)
  if type(activeId) ~= "string" or activeId == "" then return false end
  AR.pending[activeId] = nil
  AR.resolved[activeId] = nil
  return true
end

function AR:GetPending()
  return AR.pending
end

function AR:GetResolved()
  return AR.resolved
end

function AR:RetryOnce()
  local Resolve = Gate and Gate:Get("ResolveTargetFrame")
  if not Resolve then return 0 end

  local changed = 0
  for activeId, targetId in pairs(AR.pending) do
    local ok, frame = pcall(function() return Resolve(targetId) end)
    if ok and frame ~= nil then
      AR.resolved[activeId] = frame
      AR.pending[activeId] = nil
      changed = changed + 1
    end
  end
  return changed
end

function AR:StartRetry(intervalSec)
  if type(intervalSec) == "number" and intervalSec > 0 then
    AR._interval = intervalSec
  end

  -- Avoid starting twice
  if AR._ticker or AR._updateFrame then return true end

  if C_Timer and C_Timer.NewTicker then
    AR._ticker = C_Timer.NewTicker(AR._interval, function()
      pcall(function() AR:RetryOnce() end)
    end)
    return true
  end

  -- Fallback: OnUpdate polling
  if CreateFrame then
    local f = CreateFrame("Frame")
    AR._updateFrame = f
    AR._accum = 0
    f:SetScript("OnUpdate", function(_, elapsed)
      AR._accum = (AR._accum or 0) + (elapsed or 0)
      if AR._accum >= (AR._interval or 1.0) then
        AR._accum = 0
        pcall(function() AR:RetryOnce() end)
      end
    end)
    return true
  end

  return false
end

function AR:StopRetry()
  if AR._ticker and AR._ticker.Cancel then
    pcall(function() AR._ticker:Cancel() end)
  end
  AR._ticker = nil

  if AR._updateFrame then
    pcall(function() AR._updateFrame:SetScript("OnUpdate", nil) end)
  end
  AR._updateFrame = nil
  return true
end

-- callable table: AR(activeId, targetId) == Postpone
setmetatable(AR, {
  __call = function(self, activeId, targetId)
    return self:Postpone(activeId, targetId)
  end,
})
