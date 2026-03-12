-- Bre/Core/DrawerSpec_FlipCard.lua
-- Flip Card drawer (v1): Front/Back + face state + one-shot trigger.

local addonName, Bre = ...
Bre = Bre or {}

Bre.DrawerSpec_FlipCard = {
  drawerId = "FlipCard",
  title = "ELEM_FLIPCARD_TITLE",

  specificContent = {
    { type = "label", text = "ELEM_FLIPCARD_FRONT", x = 18, y = -22 },
    { type = "combo_input", id = "frontPath", x = 18, y = -44, width = 342 },

    { type = "label", text = "ELEM_FLIPCARD_BACK", x = 18, y = -86 },
    { type = "combo_input", id = "backPath", x = 18, y = -108, width = 342 },

    { type = "label", text = "ELEM_FLIPCARD_FACE", x = 18, y = -150 },
    { type = "dropdown", id = "currentFace", x = 0, y = -172, width = 150,
      items = {
        { value = "front", textKey = "ELEM_FLIPCARD_FACE_FRONT" },
        { value = "back", textKey = "ELEM_FLIPCARD_FACE_BACK" },
      },
    },

    { type = "label", text = "ELEM_FLIPCARD_DURATION", x = 210, y = -150 },
    { type = "numericbox", id = "duration", x = 315, y = -146 },

    { type = "label", text = "ELEM_FLIPCARD_STATUS", x = 18, y = -208 },
    { type = "editbox", id = "status", x = 80, y = -204, width = 120 },

    { type = "button", id = "trigger", text = "ELEM_FLIPCARD_TRIGGER", x = 210, y = -206, width = 150, height = 22 },
  },

  attributes = "default",
  position = "default",
}

function Bre.DrawerSpec_FlipCard:Refresh(ctx)
  local c = ctx and ctx.controls
  local data = (ctx and ctx.data) or {}
  if not c then return end

  local flip = type(data.flip) == "table" and data.flip or {}
  local front = type(flip.frontPath) == "string" and flip.frontPath or ""
  local back = type(flip.backPath) == "string" and flip.backPath or ""
  local face = (flip.currentFace == "back") and "back" or "front"
  local dur = tonumber(flip.duration) or 0.35
  if dur < 0.05 then dur = 0.05 end
  if dur > 3 then dur = 3 end
  local statusKey = (flip.isFlipping and "ELEM_FLIPCARD_STATUS_FLIPPING") or "ELEM_FLIPCARD_STATUS_IDLE"
  local statusText = (Bre and Bre.L and Bre.L(statusKey)) or statusKey

  local bindId = ctx and ctx.nodeId
  if c.frontPath then c.frontPath._editBindNodeId = bindId end
  if c.backPath then c.backPath._editBindNodeId = bindId end
  if c.duration then c.duration._editBindNodeId = bindId end
  if c.currentFace then c.currentFace._editBindNodeId = bindId end
  if c.trigger then c.trigger._editBindNodeId = bindId end

  if c.frontPath and c.frontPath._editbox and c.frontPath._editbox.GetText and c.frontPath._editbox:GetText() ~= front then
    c.frontPath._editbox:SetText(front)
  end
  if c.backPath and c.backPath._editbox and c.backPath._editbox.GetText and c.backPath._editbox:GetText() ~= back then
    c.backPath._editbox:SetText(back)
  end

  if c.duration and c.duration.GetText and c.duration:GetText() ~= string.format("%.2f", dur) then
    c.duration:SetText(string.format("%.2f", dur))
  end

  if c.currentFace and UIDropDownMenu_SetText then
    local key = (face == "back") and "ELEM_FLIPCARD_FACE_BACK" or "ELEM_FLIPCARD_FACE_FRONT"
    UIDropDownMenu_SetText(c.currentFace, (Bre and Bre.L and Bre.L(key)) or face)
    c.currentFace.__value = face
  end

  if c.status and c.status.SetText then
    if c.status.GetText and c.status:GetText() ~= statusText then
      c.status:SetText(statusText)
    end
    if c.status.SetEnabled then c.status:SetEnabled(false) end
  end
end

return Bre.DrawerSpec_FlipCard
