-- Bre/Modules/ProgressMat/ProgressMat.lua
-- ProgressMat (L2): gating boundary for Progress Material rendering.
-- Progress bar rendering with shape and direction support
-- Version: v2.31.0
-- Changes: Separated Blizzard and Custom material rendering
--   - Blizzard materials use simple SetTexCoord (StatusBar native method)
--   - Custom materials use TextureCoords system (supports circular textures)
--   - Added progressAlgorithm: Linear（圆形/线形）or Circular（扇形/环形/指针形）
--   - Blizzard materials can only use Linear algorithm

local addonName, Bre = ...
Bre = Bre or {}

-- Enable debug mode: /run Bre.DEBUG = true
Bre.DEBUG = Bre.DEBUG or false

Bre.ProgressMat = Bre.ProgressMat or {
  version = "2.16.0",  -- WoW 12.0 StatusBar + Secret Value
  -- L2 module capability declaration (v1.5 mandatory)
  runtime_required = true,
  authoring_required = true,
}

local M = Bre.ProgressMat

local DEFAULT_FG_PATH = "Interface\\AddOns\\Bre\\Media\\Textures\\foreground_w1.tga"
-----------------------------------------------------------
-- v2.16.0: StatusBar + MaskTexture System (WoW 12.0)
-----------------------------------------------------------

-- Setup StatusBar with secret values (WoW 12.0 compatible)
-- @param statusBar: StatusBar frame
-- @param bgTex: background texture (optional)
-- @param data: element data (foreground, mask, direction, colors, etc.)
-- @param cur: current health (secret value from UnitHealth)
-- @param max: max health (secret value from UnitHealthMax)
function M:SetupStatusBar(statusBar, bgTex, data, cur, max)
  if not statusBar then return end

  data = data or {}

  -- Debug (guarded)
  if Bre.DEBUG then
    print("[ProgressMat v2.16.4] SetupStatusBar")
    print("  foreground:", tostring(data.foreground))
    print("  background:", tostring(data.background))
    print("  mask:", tostring(data.mask))
    print("  direction:", tostring(data.progressDirection))
  end

  -- 1) Drive with raw (possibly secret) values. Do NOT do math here.
  statusBar:SetMinMaxValues(0, max or 0)
  statusBar:SetValue(cur or 0)

  -- 2) Linear direction (4-way only)
  local direction = data.progressDirection or "BottomToTop"
  if direction == "LeftToRight" or direction == "RightToLeft" then
    statusBar:SetOrientation("HORIZONTAL")
    statusBar:SetReverseFill(direction == "RightToLeft")
  else
    statusBar:SetOrientation("VERTICAL")
    statusBar:SetReverseFill(direction == "TopToBottom")
  end

  -- 3) Foreground (fill) texture: StatusBarTexture is the single source of truth.
  local fgPath = data.foreground
  if type(fgPath) == "string" then
    fgPath = fgPath:gsub("^%s+", ""):gsub("%s+$", "")
    if fgPath == "" then fgPath = nil end
  else
    fgPath = nil
  end

  if not fgPath then fgPath = DEFAULT_FG_PATH end

  statusBar:SetStatusBarTexture(fgPath)

  local fillTex = statusBar:GetStatusBarTexture()
  if fillTex and fillTex.SetVertexColor then
    local c = data.fgColor or { r = 1, g = 1, b = 1, a = 1 }
    local a = (c.a or 1) * (tonumber(data.alpha) or 1)
    fillTex:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, a)
  end

  -- 4) Mask (shape): attach to the fill texture (and bg if present).
  local maskPath = data.mask
  if type(maskPath) == "string" then
    maskPath = maskPath:gsub("^%s+", ""):gsub("%s+$", "")
    if maskPath == "" then maskPath = nil end
  else
    maskPath = nil
  end

  local mask = statusBar._brElmsMask
  if maskPath then
    if not mask then
      -- Create mask on the fill texture when possible (most consistent)
      if fillTex and fillTex.CreateMaskTexture then
        mask = fillTex:CreateMaskTexture()
      else
        mask = statusBar:CreateMaskTexture()
      end
      statusBar._brElmsMask = mask

      -- Attach once
      if fillTex and fillTex.AddMaskTexture then
        pcall(fillTex.AddMaskTexture, fillTex, mask)
      end
      if bgTex and bgTex.AddMaskTexture then
        pcall(bgTex.AddMaskTexture, bgTex, mask)
      end

      if mask.SetTexelSnappingBias then mask:SetTexelSnappingBias(0) end
      if mask.SetSnapToPixelGrid then mask:SetSnapToPixelGrid(false) end
    end

    if mask and mask.SetTexture then
      pcall(mask.SetTexture, mask, maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    if mask and mask.SetAllPoints then
      -- Align with fill texture to avoid padding/edge artifacts
      if fillTex then
        mask:SetAllPoints(fillTex)
      else
        mask:SetAllPoints(statusBar)
      end
    end
  else
    -- No mask: detach if present
    if mask then
      if fillTex and fillTex.RemoveMaskTexture then
        pcall(fillTex.RemoveMaskTexture, fillTex, mask)
      end
      if bgTex and bgTex.RemoveMaskTexture then
        pcall(bgTex.RemoveMaskTexture, bgTex, mask)
      end
    end
    statusBar._brElmsMask = nil
  end

  -- 5) Background (optional)
  if bgTex and bgTex.SetTexture then
    local bgPath = data.background
    if type(bgPath) == "string" then
      bgPath = bgPath:gsub("^%s+", ""):gsub("%s+$", "")
      if bgPath == "" then bgPath = nil end
    else
      bgPath = nil
    end

    if bgPath then
      pcall(bgTex.SetTexture, bgTex, bgPath)
      if bgTex.SetVertexColor then
        local c = data.bgColor or { r = 0.3, g = 0.3, b = 0.3, a = 1 }
        bgTex:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, c.a or 1)
      end
      bgTex:Show()
    else
      bgTex:Hide()
    end
  end

  statusBar:Show()
end

-----------------------------------------------------------
-- TextureCoords System (DEPRECATED v2.15.x)
-- Kept for reference, not used in v2.16.0+
-----------------------------------------------------------

-- Default texture coordinates for full display
local defaultTexCoord = {
  ULx = 0, ULy = 0,  -- Upper Left
  LLx = 0, LLy = 1,  -- Lower Left
  URx = 1, URy = 0,  -- Upper Right
  LRx = 1, LRy = 1,  -- Lower Right
}

-- Exact coordinates for 45° angles (0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°)
local exactAngles = {
  {0.5, 0},  -- 0°
  {1, 0},    -- 45°
  {1, 0.5},  -- 90°
  {1, 1},    -- 135°
  {0.5, 1},  -- 180°
  {0, 1},    -- 225°
  {0, 0.5},  -- 270°
  {0, 0}     -- 315°
}

-- Convert angle (0-360°) to texture coordinate (0-1)
local function angleToCoord(angle)
  angle = angle % 360
  
  -- Use exact values for 45° increments
  if (angle % 45 == 0) then
    local index = math.floor(angle / 45) + 1
    return exactAngles[index][1], exactAngles[index][2]
  end
  
  -- Calculate coordinates for arbitrary angles using tangent
  if (angle < 45) then
    return 0.5 + math.tan(math.rad(angle)) / 2, 0
  elseif (angle < 135) then
    return 1, 0.5 + math.tan(math.rad(angle - 90)) / 2
  elseif (angle < 225) then
    return 0.5 - math.tan(math.rad(angle)) / 2, 1
  elseif (angle < 315) then
    return 0, 0.5 - math.tan(math.rad(angle - 90)) / 2
  elseif (angle < 360) then
    return 0.5 + math.tan(math.rad(angle)) / 2, 0
  end
end

-- Point order for texture coordinate calculation
local pointOrder = { "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR", "LL", "UL", "UR", "LR" }

-- Transform a point through crop/scale/rotation/mirror
local function TransformPoint(x, y, scalex, scaley, texRotation, mirror_h, mirror_v)
  -- 1) Translate to center
  x = x - 0.5
  y = y - 0.5
  
  -- 2) Shrink by 1/sqrt(2) to prevent clipping during rotation
  x = x * 1.4142
  y = y * 1.4142
  
  -- 3) Scale
  x = x / scalex
  y = y / scaley
  
  -- 4) Mirror
  if mirror_h then x = -x end
  if mirror_v then y = -y end
  
  -- 5) Rotate
  local cos_rotation = math.cos(texRotation)
  local sin_rotation = math.sin(texRotation)
  x, y = cos_rotation * x - sin_rotation * y, sin_rotation * x + cos_rotation * y
  
  -- 6) Translate back
  x = x + 0.5
  y = y + 0.5
  
  return x, y
end

-- TextureCoords class
local TextureCoords = {}
TextureCoords.__index = TextureCoords

function TextureCoords:new(texture)
  
  local obj = {
    texture = texture,
    -- Texture coordinates
    ULx = 0, ULy = 0,
    LLx = 0, LLy = 1,
    URx = 1, URy = 0,
    LRx = 1, LRy = 1,
    -- Vertex offsets
    ULvx = 0, ULvy = 0,
    LLvx = 0, LLvy = 0,
    URvx = 0, URvy = 0,
    LRvx = 0, LRvy = 0,
  }
  setmetatable(obj, self)
  return obj
end

function TextureCoords:MoveCorner(width, height, corner, x, y)
  local rx = defaultTexCoord[corner .. "x"] - x
  local ry = defaultTexCoord[corner .. "y"] - y
  self[corner .. "vx"] = -rx * width
  self[corner .. "vy"] = ry * height
  
  self[corner .. "x"] = x
  self[corner .. "y"] = y
end

function TextureCoords:SetFull()
  self.ULx, self.ULy = 0, 0
  self.LLx, self.LLy = 0, 1
  self.URx, self.URy = 1, 0
  self.LRx, self.LRy = 1, 1
  
  self.ULvx, self.ULvy = 0, 0
  self.LLvx, self.LLvy = 0, 0
  self.URvx, self.URvy = 0, 0
  self.LRvx, self.LRvy = 0, 0
end

function TextureCoords:SetAngle(width, height, angle1, angle2)
  local index = math.floor((angle1 + 45) / 90)
  
  local middleCorner = pointOrder[index + 1]
  local startCorner = pointOrder[index + 2]
  local endCorner1 = pointOrder[index + 3]
  local endCorner2 = pointOrder[index + 4]
  
  self:MoveCorner(width, height, middleCorner, 0.5, 0.5)
  self:MoveCorner(width, height, startCorner, angleToCoord(angle1))
  
  local edge1 = math.floor((angle1 - 45) / 90)
  local edge2 = math.floor((angle2 - 45) / 90)
  
  if (edge1 == edge2) then
    self:MoveCorner(width, height, endCorner1, angleToCoord(angle2))
  else
    self:MoveCorner(width, height, endCorner1, 
                    defaultTexCoord[endCorner1 .. "x"], 
                    defaultTexCoord[endCorner1 .. "y"])
  end
  
  self:MoveCorner(width, height, endCorner2, angleToCoord(angle2))
end

-- Linear progress fill methods (WA-style)
-- Horizontal fill: progress goes from left to right
function TextureCoords:SetLinearHorizontal(width, height, startProgress, endProgress)
  -- Left edge at startProgress
  self:MoveCorner(width, height, "UL", startProgress, 0)
  self:MoveCorner(width, height, "LL", startProgress, 1)
  
  -- Right edge at endProgress
  self:MoveCorner(width, height, "UR", endProgress, 0)
  self:MoveCorner(width, height, "LR", endProgress, 1)
end

-- Vertical fill: progress goes from bottom to top
function TextureCoords:SetLinearVertical(width, height, startProgress, endProgress)
  -- Top edge at endProgress position (inverted: 1 - endProgress)
  self:MoveCorner(width, height, "UL", 0, 1 - endProgress)
  self:MoveCorner(width, height, "UR", 1, 1 - endProgress)
  
  -- Bottom edge at startProgress position (inverted: 1 - startProgress)
  self:MoveCorner(width, height, "LL", 0, 1 - startProgress)
  self:MoveCorner(width, height, "LR", 1, 1 - startProgress)
end

-- Right to left fill
function TextureCoords:SetLinearHorizontalInverse(width, height, startProgress, endProgress)
  -- Left edge at (1 - endProgress)
  self:MoveCorner(width, height, "UL", 1 - endProgress, 0)
  self:MoveCorner(width, height, "LL", 1 - endProgress, 1)
  
  -- Right edge at (1 - startProgress)
  self:MoveCorner(width, height, "UR", 1 - startProgress, 0)
  self:MoveCorner(width, height, "LR", 1 - startProgress, 1)
end

-- Top to bottom fill
function TextureCoords:SetLinearVerticalInverse(width, height, startProgress, endProgress)
  -- Top edge at startProgress
  self:MoveCorner(width, height, "UL", 0, startProgress)
  self:MoveCorner(width, height, "UR", 1, startProgress)
  
  -- Bottom edge at endProgress
  self:MoveCorner(width, height, "LL", 0, endProgress)
  self:MoveCorner(width, height, "LR", 1, endProgress)
end

function TextureCoords:Transform(scalex, scaley, texRotation, mirror_h, mirror_v)
  self.ULx, self.ULy = TransformPoint(self.ULx, self.ULy, scalex, scaley, texRotation, mirror_h, mirror_v)
  self.LLx, self.LLy = TransformPoint(self.LLx, self.LLy, scalex, scaley, texRotation, mirror_h, mirror_v)
  self.URx, self.URy = TransformPoint(self.URx, self.URy, scalex, scaley, texRotation, mirror_h, mirror_v)
  self.LRx, self.LRy = TransformPoint(self.LRx, self.LRy, scalex, scaley, texRotation, mirror_h, mirror_v)
end

function TextureCoords:Apply()
  local tex = self.texture
  if not tex then return end
  
  -- Check if SetVertexOffset exists (WoW 8.0+)
  if tex.SetVertexOffset then
    -- Apply vertex offsets using correct vertex indices
    -- UPPER_LEFT_VERTEX = 1, LOWER_LEFT_VERTEX = 2, UPPER_RIGHT_VERTEX = 3, LOWER_RIGHT_VERTEX = 4
    tex:SetVertexOffset(1, self.ULvx, self.ULvy)  -- UPPER_LEFT_VERTEX
    tex:SetVertexOffset(2, self.LLvx, self.LLvy)  -- LOWER_LEFT_VERTEX
    tex:SetVertexOffset(3, self.URvx, self.URvy)  -- UPPER_RIGHT_VERTEX
    tex:SetVertexOffset(4, self.LRvx, self.LRvy)  -- LOWER_RIGHT_VERTEX
  end
  
  -- Apply texture coordinates
  tex:SetTexCoord(self.ULx, self.ULy, self.LLx, self.LLy, 
                  self.URx, self.URy, self.LRx, self.LRy)
end

function TextureCoords:Hide()
  if self.texture then self.texture:Hide() end
end

function TextureCoords:Show()
  self:Apply()
  if self.texture then self.texture:Show() end
end

-----------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------


-- Helper: Migrate legacy data format to new format
local function _migrateData(data)
  -- Step 2: Field rename - progressShape -> progressAlgorithm
  if data.progressShape and not data.progressAlgorithm then
    data.progressAlgorithm = data.progressShape
    data.progressShape = nil  -- Remove old field
  end
  
  -- Step 2: Value migration - Circle/Ring -> Radial
  if data.progressAlgorithm == "Circle" or data.progressAlgorithm == "Ring" then
    data.progressAlgorithm = "Radial"
  end
  
  return data
end

-- Helper: Ensure data structure
local function _ensureData(data)
  -- First migrate legacy data
  data = _migrateData(data)
  
  if Bre.DEBUG then
    print("[ProgressMat _ensureData] START")
    print("[ProgressMat _ensureData] foreground=" .. tostring(data.foreground))
    print("[ProgressMat _ensureData] background=" .. tostring(data.background))
    print("[ProgressMat _ensureData] materialType(before)=" .. tostring(data.materialType))
    print("[ProgressMat _ensureData] progressDirection(before)=" .. tostring(data.progressDirection))
  end
  
  data.foreground = data.foreground or ""
  if data.foreground == "" then
    data.foreground = DEFAULT_FG_PATH
  end
  data.background = data.background or nil
  if data.background == "" then data.background = nil end
  data.mask = data.mask or nil
  if data.mask == "" then data.mask = nil end
  
  -- Material type: auto-derived from inputs (UI has no manual selector).
  -- Rule: foreground(custom) wins; otherwise background(blizzard); otherwise keep stored/default.
  local fg = tostring(data.foreground or "")
  local bg = tostring(data.background or "")
  if fg ~= "" then
    data.materialType = "Custom"
  elseif bg ~= "" then
    data.materialType = "Blizzard"
  elseif not data.materialType or data.materialType == "" then
    data.materialType = "Custom"
  end
  
  if Bre.DEBUG then
    print("[ProgressMat _ensureData] fg=" .. fg .. ", bg=" .. bg)
    print("[ProgressMat _ensureData] materialType(after)=" .. tostring(data.materialType))
  end
  
  data.progressType = data.progressType or "PROG_TYPE_CUSTOM"  -- Default to Custom
  
  -- Set progressAlgorithm default based on materialType
  if not data.progressAlgorithm or data.progressAlgorithm == "None" then
    if data.materialType == "Custom" then
      data.progressAlgorithm = "Linear"  -- 圆形/线形（默认）
    else
      data.progressAlgorithm = "Linear"  -- 暴雪材质固定Linear
    end
  end
  
  -- Blizzard material can only use Linear algorithm
  if data.materialType == "Blizzard" and data.progressAlgorithm ~= "Linear" then
    data.progressAlgorithm = "Linear"
    if Bre.DEBUG then
      print("[ProgressMat _ensureData] Forced Blizzard material to use Linear algorithm")
    end
  end
  
  -- Set default direction based on materialType and algorithm
  if not data.progressDirection or data.progressDirection == "" then
    if data.materialType == "Custom" then
      -- Custom material: default to BottomToTop
      data.progressDirection = "BottomToTop"
      if Bre.DEBUG then
        print("[ProgressMat _ensureData] Set default direction to BottomToTop (Custom material)")
      end
    else
      -- Blizzard material: default to LeftToRight
      data.progressDirection = "LeftToRight"
      if Bre.DEBUG then
        print("[ProgressMat _ensureData] Set default direction to LeftToRight (Blizzard material)")
      end
    end
  end
  
  -- Note: Both Custom and Blizzard materials can use any direction now
  -- The rendering system will handle it appropriately with TextureCoords
  local isCircularDir = (data.progressDirection == "Clockwise" or data.progressDirection == "Anticlockwise")
  
  if Bre.DEBUG then
    print("[ProgressMat _ensureData] progressDirection=" .. tostring(data.progressDirection))
    print("[ProgressMat _ensureData] isCircularDir=" .. tostring(isCircularDir))
    print("[ProgressMat _ensureData] FINAL progressDirection=" .. tostring(data.progressDirection))
    print("[ProgressMat _ensureData] END")
  end
  
  data.fgColor = type(data.fgColor) == "table" and data.fgColor or {r=1, g=1, b=1, a=1}
  data.bgColor = type(data.bgColor) == "table" and data.bgColor or {r=0.3, g=0.3, b=0.3, a=1}
  data.fade = data.fade or false
  data.mirror = data.mirror or false
  if data.alpha == nil then data.alpha = 1 end
  
  -- Migrate CounterClockwise to Anticlockwise (BrAuras compatibility)
  if data.progressDirection == "CounterClockwise" then
    data.progressDirection = "Anticlockwise"
  end
  
  -- Circular progress parameters (only set defaults)
  data.startAngle = data.startAngle or 180  -- Default: start from bottom (6 o'clock)
  data.endAngle = data.endAngle or 540      -- Default: full circle (180 + 360)
  
  -- Health type + Custom material: ensure circular parameters
  if (data.progressType == "Health" or data.progressType == "PROG_TYPE_HEALTH") 
     and data.materialType == "Custom" then
    -- Force circular parameters for Health with custom material
    data.startAngle = 180   -- Start from bottom
    data.endAngle = 540     -- Full circle
  end
  
  return data
end

-- Apply progress bar to texture objects
-- @param fgTexArray: array of 3 foreground texture objects (for circular progress)
-- @param bgTexObj: background texture object (optional)
-- @param data: progress bar data
-- @param progress: progress value 0-1
function M:ApplyToTextures(fgTexArray, bgTexObj, data, progress)
  data = _ensureData(data)
  progress = tonumber(progress) or 0
  if progress < 0 then progress = 0 end
  if progress > 1 then progress = 1 end
  
  -- Debug output (v2.15.47)
  if Bre.DEBUG then
    print("[ProgressMat] ApplyToTextures called:")
    print("  foreground: " .. tostring(data.foreground))
    print("  background: " .. tostring(data.background))
    print("  mask: " .. tostring(data.mask))
    print("  algorithm: " .. tostring(data.progressAlgorithm))
    print("  direction: " .. tostring(data.progressDirection))
    print("  progress: " .. tostring(progress))
  end
  
  local algorithm = data.progressAlgorithm or "None"
  local direction = data.progressDirection or "LeftToRight"
  
  -- Determine if circular based on direction (ignore algorithm parameter)
  local isCircular = (direction == "Clockwise" or direction == "Anticlockwise")
  
  -- For non-circular, only use first texture
  local fgTexObj = fgTexArray[1]
  
  -- Apply foreground texture
  if fgTexObj and fgTexObj.SetTexture then
    local fgPath = data.foreground
    if fgPath and fgPath ~= "" then
      -- Load custom texture from path
      local ok = pcall(fgTexObj.SetTexture, fgTexObj, fgPath)
      if not ok and Bre.DEBUG then
        print("[ProgressMat] ERROR: Failed to load foreground texture: " .. tostring(fgPath))
      end
      
      -- Apply foreground color
      if fgTexObj.SetVertexColor then
        local c = data.fgColor or {r=1, g=1, b=1, a=1}
        fgTexObj:SetVertexColor(c.r or 1, c.g or 1, c.b or 1)
      end
      
      -- Apply alpha
      if fgTexObj.SetAlpha then
        fgTexObj:SetAlpha((tonumber(data.alpha) or 1) * (data.fgColor.a or 1))
      end
      
      -- Apply fade (desaturate)
      if data.fade and fgTexObj.SetDesaturated then
        fgTexObj:SetDesaturated(true)
      elseif fgTexObj.SetDesaturated then
        fgTexObj:SetDesaturated(false)
      end
      
      -- Apply mirror
      local mirror = data.mirror and true or false
      
      -- Apply progress fill based on direction and material type
      if isCircular then
        -- Circular progress: use 3 textures with TextureCoords (Custom material only)
        self:_ApplyRadialProgress(fgTexArray, progress, direction, mirror, data, fgPath)
      elseif data.materialType == "Blizzard" then
        -- Blizzard material: use simple SetTexCoord (no SetVertexOffset)
        if direction == "TopToBottom" or direction == "BottomToTop" or 
           direction == "LeftToRight" or direction == "RightToLeft" then
          self:_ApplyBlizzardLinear(fgTexObj, progress, direction)
          if fgTexArray[2] then fgTexArray[2]:Hide() end
          if fgTexArray[3] then fgTexArray[3]:Hide() end
        else
          -- Default: full display
          fgTexObj:SetTexCoord(0, 1, 0, 1)
          fgTexObj:Show()
          if fgTexArray[2] then fgTexArray[2]:Hide() end
          if fgTexArray[3] then fgTexArray[3]:Hide() end
        end
      else
        -- Custom material: use TextureCoords system (supports circular textures)
        if direction == "TopToBottom" or direction == "BottomToTop" then
          -- Vertical linear progress
          self:_ApplyVerticalProgress(fgTexObj, progress, direction, mirror)
          if fgTexArray[2] then fgTexArray[2]:Hide() end
          if fgTexArray[3] then fgTexArray[3]:Hide() end
        elseif direction == "LeftToRight" or direction == "RightToLeft" then
          -- Horizontal linear progress
          self:_ApplyHorizontalProgress(fgTexObj, progress, direction, mirror)
          if fgTexArray[2] then fgTexArray[2]:Hide() end
          if fgTexArray[3] then fgTexArray[3]:Hide() end
        else
          -- Default: full display
          fgTexObj:SetTexCoord(0, 1, 0, 1)
          fgTexObj:Show()
          if fgTexArray[2] then fgTexArray[2]:Hide() end
          if fgTexArray[3] then fgTexArray[3]:Hide() end
        end
      end
    else
      -- No foreground path: show white color texture as default (v2.16.0)
      if fgTexObj.SetColorTexture then
        fgTexObj:SetColorTexture(1, 1, 1, 1)  -- Pure white
      end
      
      -- Apply alpha
      if fgTexObj.SetAlpha then
        fgTexObj:SetAlpha(tonumber(data.alpha) or 1)
      end
      
      -- Apply mirror
      local mirror = data.mirror and true or false
      
      -- Apply progress fill (white texture still needs progress animation)
      if direction == "TopToBottom" or direction == "BottomToTop" then
        self:_ApplyVerticalProgress(fgTexObj, progress, direction, mirror)
        if fgTexArray[2] then fgTexArray[2]:Hide() end
        if fgTexArray[3] then fgTexArray[3]:Hide() end
      elseif direction == "LeftToRight" or direction == "RightToLeft" then
        self:_ApplyHorizontalProgress(fgTexObj, progress, direction, mirror)
        if fgTexArray[2] then fgTexArray[2]:Hide() end
        if fgTexArray[3] then fgTexArray[3]:Hide() end
      else
        -- Default: full display
        fgTexObj:SetTexCoord(0, 1, 0, 1)
        fgTexObj:Show()
        if fgTexArray[2] then fgTexArray[2]:Hide() end
        if fgTexArray[3] then fgTexArray[3]:Hide() end
      end
    end
  end
  
  -- Apply background texture
  if bgTexObj and bgTexObj.SetTexture then
    local bgPath = data.background
    if bgPath and bgPath ~= "" then
      bgTexObj:SetTexture(bgPath)
      
      -- Apply background color
      if bgTexObj.SetVertexColor then
        local c = data.bgColor or {r=0.3, g=0.3, b=0.3, a=1}
        bgTexObj:SetVertexColor(c.r or 1, c.g or 1, c.b or 1)
      end
      
      -- Apply alpha
      if bgTexObj.SetAlpha then
        bgTexObj:SetAlpha((tonumber(data.alpha) or 1) * (data.bgColor.a or 1))
      end
      
      -- Background always shows full texture
      if bgTexObj.SetTexCoord then
        if mirror then
          bgTexObj:SetTexCoord(1, 0, 0, 1)
        else
          bgTexObj:SetTexCoord(0, 1, 0, 1)
        end
      end
      
      bgTexObj:Show()
    else
      bgTexObj:Hide()
    end
  end
  
  -- Apply mask texture to foreground textures (for circular health bar)
  local maskPath = data.mask
  if maskPath and maskPath ~= "" then
    -- Apply mask to all 3 foreground textures
    for i = 1, 3 do
      local tex = fgTexArray[i]
      if tex then
        -- Create or get existing mask texture
        local mask = tex._brElmsMask
        if not mask and tex.CreateMaskTexture then
          mask = tex:CreateMaskTexture()
          tex._brElmsMask = mask
          if tex.AddMaskTexture then
            pcall(tex.AddMaskTexture, tex, mask)
          end
        end
        
        -- Apply mask texture
        if mask then
          if mask.ClearAllPoints then mask:ClearAllPoints() end
          if mask.SetAllPoints then mask:SetAllPoints(tex) end
          if mask.SetTexture then 
            local ok = pcall(mask.SetTexture, mask, maskPath)
            if not ok and Bre.DEBUG then
              print("[ProgressMat] ERROR: Failed to load mask texture: " .. maskPath)
            end
          end
          if mask.Show then pcall(mask.Show, mask) end
          tex._brElmsMaskPath = maskPath
          
          if Bre.DEBUG then
            print("[ProgressMat] Applied mask to fgTex[" .. i .. "]: " .. maskPath)
          end
        end
      end
    end
  else
    -- No mask: hide existing masks
    for i = 1, 3 do
      local tex = fgTexArray[i]
      if tex and tex._brElmsMask then
        if tex._brElmsMask.Hide then
          pcall(tex._brElmsMask.Hide, tex._brElmsMask)
        end
      end
    end
  end
end

-- Apply rectangle progress fill
function M:_ApplyRectangleProgress(texObj, progress, direction, mirror)
  if not texObj or not texObj.SetTexCoord then return end
  
  -- DEBUG
  print("[ProgressMat Rectangle] progress:", progress, "direction:", direction, "mirror:", mirror)
  
  local left, right, top, bottom = 0, 1, 0, 1
  
  if direction == "LeftToRight" then
    right = progress
  elseif direction == "RightToLeft" then
    left = 1 - progress
  elseif direction == "TopToBottom" then
    bottom = progress
  elseif direction == "BottomToTop" then
    top = 1 - progress
  end
  
  -- Apply mirror
  if mirror then
    left, right = right, left
  end
  
  -- DEBUG
  print("[ProgressMat Rectangle] SetTexCoord:", left, right, top, bottom)
  
  texObj:SetTexCoord(left, right, top, bottom)
end

-- Apply radial progress fill (true circular implementation)
-- Uses 3 textures to cover up to 360° with TextureCoords system
function M:_ApplyRadialProgress(fgTexArray, progress, direction, mirror, data, texturePath)
  if not fgTexArray or #fgTexArray < 3 then return end
  
  -- Initialize TextureCoords for all 3 textures if not already done
  if not self._circularCoords then
    self._circularCoords = {}
    for i = 1, 3 do
      self._circularCoords[i] = TextureCoords:new(fgTexArray[i])
    end
  end
  
  -- Get dimensions from data.size (not from parentFrame to avoid stretching)
  -- BrAuras uses options.width/height, we use data.size.width/height
  local width = 72
  local height = 72
  if data and type(data.size) == "table" then
    width = tonumber(data.size.width) or 72
    height = tonumber(data.size.height) or 72
  end
  
  -- For circular progress, enforce square dimensions (use smaller value)
  -- This prevents ellipse distortion when frame is not square
  local size = math.min(width, height)
  width = size
  height = size
  
  -- DEBUG: Show actual dimensions
  if Bre.DEBUG then
    print("[ProgressMat Circular] enforced square size=" .. size)
  end
  
  -- Adjust texture anchors to be square (centered in frame)
  -- This ensures textures display as circles even if frame is rectangular
  local parentFrame = fgTexArray[1]:GetParent()
  if parentFrame then
    local frameWidth = parentFrame:GetWidth() or size
    local frameHeight = parentFrame:GetHeight() or size
    
    -- Calculate offsets to center the square texture
    local xOffset = (frameWidth - size) / 2
    local yOffset = (frameHeight - size) / 2
    
    -- Apply square anchors to all 3 textures
    for i = 1, 3 do
      local tex = fgTexArray[i]
      if tex and tex.ClearAllPoints and tex.SetPoint then
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", xOffset, -yOffset)
        tex:SetPoint("BOTTOMRIGHT", parentFrame, "TOPLEFT", xOffset + size, -yOffset - size)
      end
    end
    
    if Bre.DEBUG then
      print("[ProgressMat Circular] Texture anchors: xOffset=" .. xOffset .. ", yOffset=" .. yOffset .. ", size=" .. size)
    end
  end
  
  -- Get start and end angles from data
  local startAngle = tonumber(data.startAngle) or 180
  local endAngle = tonumber(data.endAngle) or 540
  
  -- Normalize angles: if endAngle <= startAngle, add 360
  if endAngle <= startAngle then
    endAngle = endAngle + 360
  end
  
  -- Calculate progress angle based on direction
  local angle1, angle2
  
  if direction == "Clockwise" then
    -- Clockwise: fill from startAngle to progressAngle
    local progressAngle = (endAngle - startAngle) * progress + startAngle
    angle1 = startAngle
    angle2 = progressAngle
  elseif direction == "Anticlockwise" then
    -- Anticlockwise: drain from endAngle to progressAngle
    local progressAngle = (endAngle - startAngle) * (1 - progress) + startAngle
    angle1 = progressAngle
    angle2 = endAngle
  else
    -- Fallback: treat as Clockwise
    local progressAngle = (endAngle - startAngle) * progress + startAngle
    angle1 = startAngle
    angle2 = progressAngle
  end
  
  -- Handle full circle (360°+)
  if (angle2 - angle1 >= 360) then
    -- Show full texture in first slot
    self._circularCoords[1]:SetFull()
    self._circularCoords[1]:Transform(1, 1, 0, mirror, false)
    self._circularCoords[1]:Show()
    
    self._circularCoords[2]:Hide()
    self._circularCoords[3]:Hide()
    
    -- Apply texture to first slot
    local tex = fgTexArray[1]
    if tex and tex.SetTexture then
      pcall(tex.SetTexture, tex, texturePath)
      if tex.SetVertexColor then
        local c = data.fgColor or {r=1, g=1, b=1, a=1}
        tex:SetVertexColor(c.r or 1, c.g or 1, c.b or 1)
      end
      if tex.SetAlpha then
        tex:SetAlpha((tonumber(data.alpha) or 1) * ((data.fgColor and data.fgColor.a) or 1))
      end
      if data.fade and tex.SetDesaturated then
        tex:SetDesaturated(true)
      elseif tex.SetDesaturated then
        tex:SetDesaturated(false)
      end
    end
    return
  end
  
  -- Handle empty (0°)
  if (angle1 == angle2) then
    self._circularCoords[1]:Hide()
    self._circularCoords[2]:Hide()
    self._circularCoords[3]:Hide()
    return
  end
  
  -- Apply texture and color to all 3 textures
  for i = 1, 3 do
    local tex = fgTexArray[i]
    if tex and tex.SetTexture then
      -- Set texture
      pcall(tex.SetTexture, tex, texturePath)
      
      -- Apply color
      if tex.SetVertexColor then
        local c = data.fgColor or {r=1, g=1, b=1, a=1}
        tex:SetVertexColor(c.r or 1, c.g or 1, c.b or 1)
      end
      
      -- Apply alpha
      if tex.SetAlpha then
        tex:SetAlpha((tonumber(data.alpha) or 1) * ((data.fgColor and data.fgColor.a) or 1))
      end
      
      -- Apply desaturation
      if data.fade and tex.SetDesaturated then
        tex:SetDesaturated(true)
      elseif tex.SetDesaturated then
        tex:SetDesaturated(false)
      end
    end
  end
  
  -- Calculate which 90° segments are covered
  local index1 = math.floor((angle1 + 45) / 90)
  local index2 = math.floor((angle2 + 45) / 90)
  
  -- Split into 1, 2, or 3 segments based on angle range
  if (index1 + 1 >= index2) then
    -- Single segment (< 90°)
    self._circularCoords[1]:SetAngle(width, height, angle1, angle2)
    self._circularCoords[1]:Transform(1, 1, 0, mirror, false)
    self._circularCoords[1]:Show()
    
    self._circularCoords[2]:Hide()
    self._circularCoords[3]:Hide()
  elseif (index1 + 3 >= index2) then
    -- Two segments (90-270°)
    local firstEndAngle = (index1 + 1) * 90 + 45
    
    self._circularCoords[1]:SetAngle(width, height, angle1, firstEndAngle)
    self._circularCoords[1]:Transform(1, 1, 0, mirror, false)
    self._circularCoords[1]:Show()
    
    self._circularCoords[2]:SetAngle(width, height, firstEndAngle, angle2)
    self._circularCoords[2]:Transform(1, 1, 0, mirror, false)
    self._circularCoords[2]:Show()
    
    self._circularCoords[3]:Hide()
  else
    -- Three segments (270-360°)
    local firstEndAngle = (index1 + 1) * 90 + 45
    local secondEndAngle = firstEndAngle + 180
    
    self._circularCoords[1]:SetAngle(width, height, angle1, firstEndAngle)
    self._circularCoords[1]:Transform(1, 1, 0, mirror, false)
    self._circularCoords[1]:Show()
    
    self._circularCoords[2]:SetAngle(width, height, firstEndAngle, secondEndAngle)
    self._circularCoords[2]:Transform(1, 1, 0, mirror, false)
    self._circularCoords[2]:Show()
    
    self._circularCoords[3]:SetAngle(width, height, secondEndAngle, angle2)
    self._circularCoords[3]:Transform(1, 1, 0, mirror, false)
    self._circularCoords[3]:Show()
  end
end

-- Apply vertical progress fill (texture coordinate cropping)
function M:_ApplyVerticalProgress(texObj, progress, direction, mirror)
  if not texObj then return end
  
  -- Use TextureCoords system for proper handling of circular textures
  if not self._linearCoord then
    self._linearCoord = TextureCoords:new(texObj)
  end
  
  -- Get texture dimensions
  local width = texObj:GetWidth() or 200
  local height = texObj:GetHeight() or 200
  
  -- Reset to full coordinates
  self._linearCoord:SetFull()
  
  -- Apply linear vertical fill (0 = empty, 1 = full)
  if direction == "BottomToTop" then
    -- Fill from bottom to top (0 to progress)
    self._linearCoord:SetLinearVertical(width, height, 0, progress)
  else -- TopToBottom
    -- Fill from top to bottom (1-progress to 1)
    self._linearCoord:SetLinearVerticalInverse(width, height, 1 - progress, 1)
  end
  
  -- Apply the coordinates
  self._linearCoord:Apply()
  texObj:Show()
end

-- Apply horizontal progress fill (texture coordinate cropping)
function M:_ApplyHorizontalProgress(texObj, progress, direction, mirror)
  if not texObj then return end
  
  -- Use TextureCoords system for proper handling of circular textures
  if not self._linearCoord then
    self._linearCoord = TextureCoords:new(texObj)
  end
  
  -- Get texture dimensions
  local width = texObj:GetWidth() or 200
  local height = texObj:GetHeight() or 200
  
  -- Reset to full coordinates
  self._linearCoord:SetFull()
  
  -- Apply linear horizontal fill (0 = empty, 1 = full)
  if direction == "LeftToRight" then
    -- Fill from left to right (0 to progress)
    self._linearCoord:SetLinearHorizontal(width, height, 0, progress)
  else -- RightToLeft
    -- Fill from right to left
    self._linearCoord:SetLinearHorizontalInverse(width, height, 0, progress)
  end
  
  -- Apply the coordinates
  self._linearCoord:Apply()
  texObj:Show()
end

-- Apply Blizzard material linear progress (simple SetTexCoord only)
function M:_ApplyBlizzardLinear(texObj, progress, direction)
  if not texObj or not texObj.SetTexCoord then return end
  
  -- Simple texture coordinate cropping for Blizzard materials
  local left, right, top, bottom = 0, 1, 0, 1
  
  if direction == "BottomToTop" then
    top = 1 - progress
  elseif direction == "TopToBottom" then
    bottom = progress
  elseif direction == "LeftToRight" then
    right = progress
  elseif direction == "RightToLeft" then
    left = 1 - progress
  end
  
  texObj:SetTexCoord(left, right, top, bottom)
  texObj:Show()
end

-- Commit changes from UI controls
function M:CommitFromUI(args)
  if type(args) ~= "table" then return end
  local id, data = args.id, args.data
  if not id or type(data) ~= "table" then return end
  
  data = _ensureData(data)
  
  -- Store data via Bre.SetData
  if type(Bre.SetData) == "function" then
    Bre.SetData(id, data)
  end
  
  -- PropertyService will trigger render automatically (v2.15.8)
end

-- Commit color changes from UI
function M:CommitColorFromUI(args)
  if type(args) ~= "table" then return end
  local id, data = args.id, args.data
  if not id or type(data) ~= "table" then return end
  
  -- Color data is already in args (r, g, b, a)
  -- This will be handled by PropertyService Set calls
  
  -- PropertyService will trigger render automatically (v2.15.8)
end

return M
