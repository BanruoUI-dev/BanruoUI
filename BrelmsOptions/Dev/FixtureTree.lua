-- Bre/Core/FixtureTree.lua
-- FixtureTree disabled: no test nodes

-- NOTE: Runtime fixture (safe stub defaults). Must stay side-effect free.
local addonName, Bre = ...
Bre = Bre or {}
Bre.FixtureTree = Bre.FixtureTree or {}
local F = Bre.FixtureTree

function F:GetDisplays()
  return {}
end

function F:GetRootOrder()
  return {}
end
