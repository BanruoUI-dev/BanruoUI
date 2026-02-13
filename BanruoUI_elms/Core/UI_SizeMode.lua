-- Bre/Core/UI_SizeMode.lua
-- Safe SizeMode addition (v1.13.10)
-- IMPORTANT: This file must be loaded by .toc (before UI.lua). It does NOT auto-apply.

local addonName, Bre = ...
Bre = Bre or {}
Bre.UI = Bre.UI or {}

local UI = Bre.UI

local BORDER_PAD_W = 11 + 12  -- BanruoUI DialogBox insets (L+R)
local BORDER_PAD_H = 12 + 11  -- BanruoUI DialogBox insets (T+B)

local SIZE_MODES = {
  -- LEGACY / ORIGINAL: old plugin size (formerly DEFAULT)
  LEGACY  = { W = 900, H = 650 },
  ORIGINAL = { W = 900, H = 650 },

  -- DEFAULT / COMPACT: 560x560 content with BanruoUI border padding
  DEFAULT = { W = 560 + BORDER_PAD_W, H = 560 + BORDER_PAD_H },
  COMPACT = { W = 560 + BORDER_PAD_W, H = 560 + BORDER_PAD_H },
}

function UI:SetSizeMode(mode)
  mode = (mode or "DEFAULT"):upper()
  local s = SIZE_MODES[mode]
  if not s then
    error(("Bre.UI:SetSizeMode invalid mode '%s'"):format(tostring(mode)))
    return
  end
  if not self.frame or not self.frame.SetSize then
    -- UI not ready / not created: safe exit
    return
  end

  local w, h = s.W, s.H
  w = math.floor(w + 0.5)
  h = math.floor(h + 0.5)

  -- Main panel
  pcall(function() self.frame:SetSize(w, h) end)

  -- Right pane follow (best-effort)
  if self.rightPane and self.rightPane.SetSize then
    pcall(function()
      local treeW = self.treeFrame and (self.treeFrame:GetWidth() or 200) or 200
      local rightW = math.max(200, w - treeW - 20)
      if mode == "COMPACT" then rightW = 240 end
      local topH = (self.topBar and self.topBar:GetHeight()) or 40
      local rightH = math.max(200, h - topH - 20)
      self.rightPane:SetSize(rightW, rightH)
    end)
  end

  if self.OnSizeModeApplied then
    pcall(function() self:OnSizeModeApplied(mode) end)
  end
end

function UI:ToggleSizeMode()
  local cur = (UI._currentSizeMode or "DEFAULT"):upper()
  -- Toggle between DEFAULT (560) and LEGACY (original)
  local next = (cur == "DEFAULT" or cur == "COMPACT") and "LEGACY" or "DEFAULT"
  UI._currentSizeMode = next
  UI:SetSizeMode(next)
end
