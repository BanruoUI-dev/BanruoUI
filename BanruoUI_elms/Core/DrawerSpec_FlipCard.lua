-- Bre/Core/DrawerSpec_FlipCard.lua
-- Flip Card drawer (v1.1): Front/Back + simulated flip tuning.

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

    { type = "label", text = "ELEM_FLIPCARD_AXIS", x = 18, y = -208 },
    { type = "dropdown", id = "axis", x = 0, y = -230, width = 150,
      items = {
        { value = "y", textKey = "ELEM_FLIPCARD_AXIS_Y" },
        { value = "x", textKey = "ELEM_FLIPCARD_AXIS_X" },
      },
    },

    { type = "label", text = "ELEM_FLIPCARD_PIVOT", x = 210, y = -208 },
    { type = "dropdown", id = "pivot", x = 192, y = -230, width = 168,
      items = {
        { value = "center", textKey = "ELEM_FLIPCARD_PIVOT_CENTER" },
        { value = "left", textKey = "ELEM_FLIPCARD_PIVOT_LEFT" },
        { value = "right", textKey = "ELEM_FLIPCARD_PIVOT_RIGHT" },
        { value = "top", textKey = "ELEM_FLIPCARD_PIVOT_TOP" },
        { value = "bottom", textKey = "ELEM_FLIPCARD_PIVOT_BOTTOM" },
      },
    },

    { type = "label", text = "ELEM_FLIPCARD_PERSPECTIVE", x = 18, y = -266 },
    { type = "numericbox", id = "perspective", x = 126, y = -262 },

    { type = "label", text = "ELEM_FLIPCARD_SHADOW", x = 210, y = -266 },
    { type = "numericbox", id = "shadow", x = 315, y = -262 },

    { type = "label", text = "ELEM_FLIPCARD_OVERSHOOT", x = 18, y = -302 },
    { type = "numericbox", id = "overshoot", x = 126, y = -298 },

    { type = "label", text = "ELEM_FLIPCARD_STATUS", x = 18, y = -340 },
    { type = "editbox", id = "status", x = 80, y = -336, width = 120 },

    { type = "button", id = "trigger", text = "ELEM_FLIPCARD_TRIGGER", x = 210, y = -338, width = 150, height = 22 },
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
  local axis = (flip.axis == "x") and "x" or "y"

  local pivot = tostring(flip.pivot or "center")
  if pivot ~= "left" and pivot ~= "right" and pivot ~= "top" and pivot ~= "bottom" then
    pivot = "center"
  end

  local dur = tonumber(flip.duration) or 0.35
  if dur < 0.05 then dur = 0.05 end
  if dur > 3 then dur = 3 end

  local perspective = tonumber(flip.perspective) or 0.45
  if perspective < 0 then perspective = 0 end
  if perspective > 1 then perspective = 1 end

  local shadow = tonumber(flip.shadow) or 0.4
  if shadow < 0 then shadow = 0 end
  if shadow > 1 then shadow = 1 end

  local overshoot = tonumber(flip.overshoot) or 0.08
  if overshoot < 0 then overshoot = 0 end
  if overshoot > 0.2 then overshoot = 0.2 end

  local statusKey = (flip.isFlipping and "ELEM_FLIPCARD_STATUS_FLIPPING") or "ELEM_FLIPCARD_STATUS_IDLE"
  local statusText = (Bre and Bre.L and Bre.L(statusKey)) or statusKey

  local bindId = ctx and ctx.nodeId
  if c.frontPath then c.frontPath._editBindNodeId = bindId end
  if c.backPath then c.backPath._editBindNodeId = bindId end
  if c.duration then c.duration._editBindNodeId = bindId end
  if c.currentFace then c.currentFace._editBindNodeId = bindId end
  if c.axis then c.axis._editBindNodeId = bindId end
  if c.pivot then c.pivot._editBindNodeId = bindId end
  if c.perspective then c.perspective._editBindNodeId = bindId end
  if c.shadow then c.shadow._editBindNodeId = bindId end
  if c.overshoot then c.overshoot._editBindNodeId = bindId end
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
  if c.perspective and c.perspective.GetText and c.perspective:GetText() ~= string.format("%.2f", perspective) then
    c.perspective:SetText(string.format("%.2f", perspective))
  end
  if c.shadow and c.shadow.GetText and c.shadow:GetText() ~= string.format("%.2f", shadow) then
    c.shadow:SetText(string.format("%.2f", shadow))
  end
  if c.overshoot and c.overshoot.GetText and c.overshoot:GetText() ~= string.format("%.2f", overshoot) then
    c.overshoot:SetText(string.format("%.2f", overshoot))
  end

  if c.currentFace and UIDropDownMenu_SetText then
    local key = (face == "back") and "ELEM_FLIPCARD_FACE_BACK" or "ELEM_FLIPCARD_FACE_FRONT"
    UIDropDownMenu_SetText(c.currentFace, (Bre and Bre.L and Bre.L(key)) or face)
    c.currentFace.__value = face
  end

  if c.axis and UIDropDownMenu_SetText then
    local axisKey = (axis == "x") and "ELEM_FLIPCARD_AXIS_X" or "ELEM_FLIPCARD_AXIS_Y"
    UIDropDownMenu_SetText(c.axis, (Bre and Bre.L and Bre.L(axisKey)) or axis)
    c.axis.__value = axis
  end

  if c.pivot and UIDropDownMenu_SetText then
    local pivotKey = "ELEM_FLIPCARD_PIVOT_CENTER"
    if pivot == "left" then pivotKey = "ELEM_FLIPCARD_PIVOT_LEFT"
    elseif pivot == "right" then pivotKey = "ELEM_FLIPCARD_PIVOT_RIGHT"
    elseif pivot == "top" then pivotKey = "ELEM_FLIPCARD_PIVOT_TOP"
    elseif pivot == "bottom" then pivotKey = "ELEM_FLIPCARD_PIVOT_BOTTOM" end
    UIDropDownMenu_SetText(c.pivot, (Bre and Bre.L and Bre.L(pivotKey)) or pivot)
    c.pivot.__value = pivot
  end

  if c.status and c.status.SetText then
    if c.status.GetText and c.status:GetText() ~= statusText then
      c.status:SetText(statusText)
    end
    if c.status.SetEnabled then c.status:SetEnabled(false) end
  end
end

return Bre.DrawerSpec_FlipCard

