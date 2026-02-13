-- Bre/Core/EditGuard.lua
-- L1: EditGuard - refresh lock / side-effect free refresh guard.
-- Step1 (v2.12.0): skeleton only; not yet wired into UI refresh.

local addonName, Bre = ...
Bre = Bre or {}

Bre.EditGuard = Bre.EditGuard or {}

local EG = Bre.EditGuard

EG._depth = EG._depth or 0

function EG:Begin(reason)
  EG._depth = (EG._depth or 0) + 1
end

function EG:End(reason)
  local d = (EG._depth or 0) - 1
  if d < 0 then d = 0 end
  EG._depth = d
end

function EG:IsGuarded()
  return (EG._depth or 0) > 0
end

function EG:RunGuarded(reason, fn)
  EG:Begin(reason)
  local ok, err = pcall(fn)
  EG:End(reason)
  if not ok then error(err) end
end

-- Module exported via Bre.EditGuard
