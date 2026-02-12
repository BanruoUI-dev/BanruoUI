-- Bre/Core/CustomMat.lua
-- CustomMat (L2): gating boundary for the Custom Material panel.
-- Step0 (v2.10.1): provide a real module for /brs mod CustomMat off|on.

local addonName, Bre = ...
Bre = Bre or {}

Bre.CustomMat = Bre.CustomMat or {
	    version = "2.10.32",
	    -- L2 module capability declaration (v1.5 mandatory)
	    runtime_required = true,
	    authoring_required = true,
}

local M = Bre.CustomMat

local function _ensureRegion(data)
  data.region = type(data.region) == "table" and data.region or {}
  data.region.color = type(data.region.color) == "table" and data.region.color or { r = 1, g = 1, b = 1, a = 1 }
  if data.alpha == nil then data.alpha = 1 end
  return data
end

function M:ApplyToTexture(texObj, region, alphaVal)
  if not texObj or not texObj.SetTexture then return end
  region = type(region) == "table" and region or {}
  local path = region.texture
  if path and path ~= "" then
    texObj:SetTexture(path)
  else
    texObj:SetColorTexture(0, 0, 0, 0)
  end

  -- texcoord: default full, but allow StopMotion slicing to provide explicit coords.
  local mirror = region.mirror and true or false
  local l, r, t, b = 0, 1, 0, 1
  local smtc = region.stopmotionTexCoord
  if type(smtc) == "table" and smtc[1] and smtc[2] and smtc[3] and smtc[4] then
    l, r, t, b = tonumber(smtc[1]) or 0, tonumber(smtc[2]) or 1, tonumber(smtc[3]) or 0, tonumber(smtc[4]) or 1
  end
  if mirror then
    l, r = r, l
  end
  if texObj.SetTexCoord then
    texObj:SetTexCoord(l, r, t, b)
  end


  -- fade (desaturate / grayscale)
  local desat = region.desaturate and true or false
  if texObj.SetDesaturated then
    texObj:SetDesaturated(desat)
  elseif texObj.SetDesaturation then
    texObj:SetDesaturation(desat and 1 or 0)
  end

  -- tint
  if texObj.SetVertexColor then
    if region.useColor then
      local c = region.color or { r = 1, g = 1, b = 1, a = 1 }
      texObj:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
    else
      texObj:SetVertexColor(1, 1, 1, 1)
    end
  end

  -- blend
  if region.blendMode and texObj.SetBlendMode then
    texObj:SetBlendMode(region.blendMode)
  end

  -- alpha
  if texObj.SetAlpha then
    texObj:SetAlpha(tonumber(alphaVal) or 1)
  end

  -- rotation (degrees -> radians)
  if texObj.SetRotation and region.rotation then
    local deg = tonumber(region.rotation) or 0
    texObj:SetRotation(deg * math.pi / 180)
  end
end

-- Commit changes coming from UI controls.
-- NOTE: UI layout stays in Core/UI.lua. This module only owns data writes & preview apply.
function M:CommitFromUI(args)
  if type(args) ~= "table" then return end
  local id, data = args.id, args.data
  if not id or type(data) ~= "table" then return end

  data = _ensureRegion(data)

  local v = tostring(args.textureText or "")
  v = v:gsub("^%s+", ""):gsub("%s+$", "")
  if v == "" then v = nil end

  data.region.texture = v
  data.material = type(data.material) == "table" and data.material or {}
  data.material.path = v

  data.region.useColor = args.useColor and true or false
  -- NOTE (v2.12.4+): generic attributes are owned by PropertyService (L1):
  -- alpha/rotation/mirror/desaturate(blend)/size. This module must not write them.

  if type(Bre.SetData) == "function" then
    Bre.SetData(id, data)
  end

  -- live preview
  if args.previewTex then
    self:ApplyToTexture(args.previewTex, data.region, data.alpha)
  end

  -- sync runtime mover body (screen)
  local UI = Bre.UI
  if UI and UI._SyncMoverBody then
    pcall(UI._SyncMoverBody, UI)
  end

  -- refresh runtime region body (Move-owned) to avoid stale texcoord/visuals until next Move action
  local Gate = Bre.Gate
--[[
  ⚠️ ARCH NOTE (Step7)
  Cached module reference detected at file scope:
    local Move = Gate:Get("Move")
  Policy:
  - Avoid caching real module refs at load time.
  - Prefer resolving via Gate:Get(...) at call time or rely on Gate proxy.
  - Step7 does NOT change behavior; this is a guidance marker.
]]
  local Move = Gate:Get('Move')
  if Move and Move.Refresh then
    pcall(Move.Refresh, Move, id)
  end
end

function M:CommitColorFromUI(args)
  if type(args) ~= "table" then return end
  local id, data = args.id, args.data
  if not id or type(data) ~= "table" then return end

  data = _ensureRegion(data)
  local c = data.region.color
  c.r = tonumber(args.r) or (c.r or 1)
  c.g = tonumber(args.g) or (c.g or 1)
  c.b = tonumber(args.b) or (c.b or 1)
  c.a = tonumber(args.a) or (c.a or 1)

  if type(Bre.SetData) == "function" then
    Bre.SetData(id, data)
  end

  if args.previewTex then
    self:ApplyToTexture(args.previewTex, data.region, data.alpha)
  end

  local UI = Bre.UI
  if UI and UI._SyncMoverBody then
    pcall(UI._SyncMoverBody, UI)
  end

  local Gate = Bre.Gate
  local Move = Gate:Get('Move')
  if Move and Move.Refresh then
    pcall(Move.Refresh, Move, id)
  end
end

-- ---------------------------------------------------------------------------
-- Preview Provider (static)
-- L2 registers provider through Gate -> View (L1). No DB writes.
-- ---------------------------------------------------------------------------
function M:OnInit(ctx)
  local Gate = Bre.Gate
  if not Gate or not Gate.Get then return end
  local View = Gate:Get('View')
  if not View or not View.RegisterPreviewProvider then return end
  local PT = Bre.PreviewTypes

  View:RegisterPreviewProvider("CustomMat", function(id)
    local data = (type(Bre.GetData) == "function") and Bre.GetData(id) or nil
    if type(data) ~= "table" then
      return (PT and PT.None and PT.None()) or { kind = "none" }
    end
    local region = type(data.region) == "table" and data.region or {}
    local mat = type(data.material) == "table" and data.material or {}
    local path = region.texture or mat.path
    if type(path) == "string" and path ~= "" then
      if PT and PT.Texture then return PT.Texture(path) end
      return { kind = "texture", tex = path }
    end
    return (PT and PT.None and PT.None()) or { kind = "none" }
  end, 10)
end

function M:OnShutdown(ctx)
  local Gate = Bre.Gate
  if not Gate or not Gate.Get then return end
  local View = Gate:Get('View')
  if not View or not View.UnregisterPreviewProvider then return end
  View:UnregisterPreviewProvider("CustomMat")
end
