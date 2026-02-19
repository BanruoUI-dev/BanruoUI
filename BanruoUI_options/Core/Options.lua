-- BreOptions/Core/Options.lua
-- Load-on-demand options panel. Registers itself into Bre Registry/Gate as an unpluggable L2 module.

local addonName, BreOptions = ...

local Bre = _G.Bre
if type(Bre) ~= "table" then
  -- Bre not loaded (should not happen due to RequiredDeps), fail safely.
  return
end

-- Locale helper: use Bre.L if available, otherwise fallback to enUS
local function L(key)
  if Bre.L then return Bre.L(key) end
  local fallback = {
    OPTIONS_PANEL_SUB  = "BreOptions v2.0.14  |  Type /brs to open the editor",
    OPTIONS_BTN_OPEN   = "Open /brs",
  }
  return fallback[key] or key
end

local Registry = Bre.Registry
local Gate = Bre.Gate


local Font = Bre.Font
if Font and Font.Init then Font:Init() end
-- Ensure a stub exists even if Linker:InitStubs already ran before this LoD addon loaded.
if type(Gate) == "table" and Gate.RegisterStub then
  Gate:RegisterStub("Options", nil, { owner = "Options", policy = "no-op" })
end

-- Minimal Options implementation (UI wiring is intentionally tiny and safe)
local Options = {}

function Options:Open()
  -- If Settings API exists (retail), open to the category; otherwise no-op.
  if Settings and Settings.OpenToCategory then
    Settings.OpenToCategory("BanruoUI_elms")
  elseif InterfaceOptionsFrame_OpenToCategory then
    -- Classic fallback
    InterfaceOptionsFrame_OpenToCategory("BanruoUI_elms")
    InterfaceOptionsFrame_OpenToCategory("BanruoUI_elms")
  end
end

local function CreatePanel()
  local panel = CreateFrame("Frame")
  panel.name = "BanruoUI_elms"

  local title = panel:CreateFontString(nil, "ARTWORK", (Bre.Font and Bre.Font:Large() or "GameFontNormalLarge"))
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("BanruoUI_elms")

  local sub = panel:CreateFontString(nil, "ARTWORK", (Bre.Font and Bre.Font:HighlightSmall() or "GameFontHighlightSmall"))
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetText(L("OPTIONS_PANEL_SUB"))

  local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  btn:SetSize(180, 22)
  btn:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
  btn:SetText(L("OPTIONS_BTN_OPEN"))
  btn:SetScript("OnClick", function()
    if Bre and Bre.UI and Bre.UI.Toggle then
      Bre.UI:Toggle()
    end
  end)

  return panel
end

local function RegisterPanel()
  local panel = CreatePanel()

  -- Retail Settings (Dragonflight+)
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    return
  end

  -- Legacy InterfaceOptions
  if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

-- Register module spec into central registry (declaration + init) if available.
if type(Registry) == "table" and Registry.Register then
  Registry:Register({
    id = "Options",
    layer = "L2",
    desc = "BreOptions (LoD) panel",
    exports = { "Options" },
    requires = { { iface = "UI", optional = true } },
    defaults = { { iface = "Options", policy = "no-op" } },
    init = function(ctx)
      -- Safe registration of the options panel
      pcall(RegisterPanel)
      return Options
    end,
    shutdown = function(ctx)
      -- UI panels cannot be reliably unregistered in WoW; keep as no-op.
    end,
  })
end

-- Since this is LoD, opt-in to enable itself when loaded.
if Bre.Linker and Bre.Linker.Enable then
  pcall(function() Bre.Linker:Enable("Options") end)
end
