-- Bre/Core/Events.lua
-- Lifecycle events: initialize SavedVariables at correct time. v2.8.9

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate
local function _DB() return Gate:Get('DB') end
local function _Move() return Gate:Get('Move') end

local evt = CreateFrame("Frame")
evt:RegisterEvent("ADDON_LOADED")
evt:RegisterEvent("PLAYER_LOGIN")

evt:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= addonName then return end
    -- DB initialization is centralized in Core (Gate→DB) to avoid scattered InitSaved calls.
  elseif event == "PLAYER_LOGIN" then
    -- BrA-style: runtime is owned by core and restored on login/reload (not gated by editor UI).
    local Move = _Move()
    if Move and Move.RestoreAll then
      pcall(Move.RestoreAll, Move)
    end
  end
end)
