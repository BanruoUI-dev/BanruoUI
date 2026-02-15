-- Bre/Core/Core.lua
local addonName, Bre = ...
Bre = Bre or {}
_G.Bre = Bre

local Gate = Bre.Gate
local Profile = Bre.Profile
local Identity = Bre.Identity
local function _UI() return Gate:Get('UI') end
local function _Move() return Gate:Get('Move') end

local function Print(msg)
  local name = (Identity and Identity.displayName) or "Bre"
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. name .. "|r: " .. tostring(msg))
end

-- Slash command (per Profile):
-- DEV   : /bres
-- THEME : /brt
-- FULL  : /bre
-- <slash>           -> toggle UI
-- <slash> center    -> align selected/current to screen center
-- <slash> first     -> align selected to current (first)
local function RegisterSlashCommands()
  local slash = (Profile and Profile.GetSlashCommand and Profile:GetSlashCommand()) or "/bres"
  SLASH_BRECMD1 = slash
  SlashCmdList["BRECMD"] = function(msg)
  local raw = tostring(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local lower = raw:lower()
  if lower == "verify" then
    if Bre.Verify and Bre.Verify.RunIsolation then
      Bre.Verify:RunIsolation()
    else
      Print("Verify not available")
    end
    return
  end

  local cmd, a, b = raw:match("^(%S+)%s+(%S+)%s*(%S*)$")
  -- devcheck (development-only self-check hooks)
  if cmd and cmd:lower() == "devcheck" and a and a ~= "" then
    local on = (a:lower() == "on")
    local Modules = Bre.Modules
    if Modules and Modules.SetEnabled then
      Modules:SetEnabled("DevCheck", on, true)
--[[
  ⚠️ ARCH NOTE (Step7)
  Cached module reference detected at file scope:
    local Dev = Gate:Get("DevCheck")
  Policy:
  - Avoid caching real module refs at load time.
  - Prefer resolving via Gate:Get(...) at call time or rely on Gate proxy.
  - Step7 does NOT change behavior; this is a guidance marker.
]]
      local Dev = Gate:Get("DevCheck")
      if Dev and Dev.SetEnabled then
        pcall(function() Dev:SetEnabled(on) end)
      end
    end
    Print("devcheck = " .. (on and "on" or "off"))
    return
  end

  if cmd and cmd:lower() == "mod" and a and a ~= "" then
    -- IMPORTANT: ModuleId is case-sensitive in Registry.
    -- Do NOT lower-case the id argument.
    local id = a
    local action = (b and b ~= "" and b:lower()) or ""
    local Modules = Bre.Modules
    if not Modules or not Modules.SetEnabled then
      Print("Modules manager missing")
      return
    end
    if action == "" then
      Print("usage: " .. slash .. " mod <ModuleId> on|off")
      return
    end
    if action == "on" then
      local ok = Modules:SetEnabled(id, true, true)
      Print("mod " .. id .. " = on" .. (ok and "" or " (failed)"))
      return
    elseif action == "off" then
      local ok = Modules:SetEnabled(id, false, true)
      Print("mod " .. id .. " = off" .. (ok and "" or " (failed)"))
      return
    else
      Print("usage: " .. slash .. " mod <ModuleId> on|off")
      return
    end
  end

if lower == "center" then
    local Actions = Gate:Get("Actions")
    local SS = Gate:Get("SelectionService")
    local UI = _UI()
    if Actions and Actions.Execute and UI and UI.frame then
      local f = UI.frame
      local st = (SS and SS.GetState and SS:GetState()) or nil
      local ids = (st and st.set) or nil
      local nodeId = (st and st.active) or nil
      Actions:Execute("align_center", { ids = ids, nodeId = nodeId })
    end
    return
  end

  if lower == "first" then
    local Actions = Gate:Get("Actions")
    local SS = Gate:Get("SelectionService")
    local UI = _UI()
    if Actions and Actions.Execute and UI and UI.frame then
      local f = UI.frame
      local st = (SS and SS.GetState and SS:GetState()) or nil
      local ids = (st and st.set) or nil
      local nodeId = (st and st.active) or nil
      Actions:Execute("align_first", { ids = ids, refId = nodeId, nodeId = nodeId })
    end
    return
  end


  local UI = _UI()
  if UI and UI.Toggle then
    UI:Toggle()
  else
    Print("UI not ready")
  end
  end
end

if Profile and Profile.AllowSlashCommands and Profile:AllowSlashCommands() then
  RegisterSlashCommands()
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
  if name ~= addonName then return end
  BreSaved = BreSaved or {}
  BreSaved.modules = BreSaved.modules or {}
  if Bre.Linker and Bre.Linker.Bootstrap then
    pcall(function() Bre.Linker:Bootstrap() end)
  end

  -- Centralized DB initialization (Gate→DB). Avoid scattered InitSaved calls in UI/Events.
  local DB = Gate and Gate.Get and Gate:Get('DB') or nil
  if DB and DB.EnsureSaved then
    pcall(function() DB:EnsureSaved() end)
  elseif DB and DB.InitSaved then
    pcall(function() DB:InitSaved() end)
  end

  if Profile and Profile.AllowSlashCommands and Profile:AllowSlashCommands() then
    local s = (Profile and Profile.GetSlashCommand and Profile:GetSlashCommand()) or "/bres"
    Print("loaded. Type " .. s)
  else
    Print("loaded.")
  end
end)

-- v2.9.0 visibility core (BrA-like)
function Bre.ApplyVisibility(node)
  if not node or not node.__frame then return end
  if node.hidden then
    node.__frame:Hide()
  else
    node.__frame:Show()
  end
end