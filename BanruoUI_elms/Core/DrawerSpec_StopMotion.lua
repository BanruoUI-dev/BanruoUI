-- Bre/Core/DrawerSpec_StopMotion.lua
-- Functional Drawer SHELL for Stop Motion element (UI only)
-- Step2: Show full parameter controls without playback/render wiring.
-- Constitution v1.4 compliant:
-- - UI only, no DB writes, no Move calls, no side effects
-- - Refresh is no-op (shell); user can type/change without errors

local addonName, Bre = ...
Bre = Bre or {}

Bre.DrawerSpec_StopMotion = {
  drawerId = "StopMotion",
  title = "ELEM_STOPMOTION_TITLE",

  -- Shell UI: controls only (no wiring to data)
  specificContent = {
    -- Path
    { type = "label",   text = "ELEM_STOPMOTION_PATH", x = 18, y = -10 },
    { type = "editbox", id   = "path",                 x = 24, y = -32, width = 150 },

    -- Frame slicing
    { type = "label",   text = "ELEM_STOPMOTION_SLICE", x = 18, y = -74 },

    { type = "label",      text = "ELEM_STOPMOTION_GRID",    x = 18,  y = -96 },
    { type = "numericbox", id   = "grid",                    x = 68,  y = -92 },

    { type = "label",      text = "ELEM_STOPMOTION_FRAMES",  x = 158, y = -96 },
    { type = "numericbox", id   = "frames",                  x = 218, y = -92 },

    -- Advanced slicing (optional)
    { type = "checkbox", id = "useAdvanced", text = "ELEM_STOPMOTION_ADV", x = 18, y = -150 },

    { type = "label",      text = "ELEM_STOPMOTION_FILE_W",  x = 18,  y = -182 },
    { type = "numericbox", id   = "fileW",                   x = 68, y = -178 },

    { type = "label",      text = "ELEM_STOPMOTION_FILE_H",  x = 148,  y = -182 },
    { type = "numericbox", id   = "fileH",                   x = 198, y = -178 },

    { type = "label",      text = "ELEM_STOPMOTION_FRAME_W", x = 18,  y = -212 },
    { type = "numericbox", id   = "frameW",                  x = 68, y = -208 },

    { type = "label",      text = "ELEM_STOPMOTION_FRAME_H", x = 148,  y = -212 },
    { type = "numericbox", id   = "frameH",                  x = 198, y = -208 },

    -- Playback params (shell)
    { type = "label",   text = "ELEM_STOPMOTION_PLAY", x = 18, y = -260},

    { type = "label",      text = "ELEM_STOPMOTION_FPS",     x = 160,  y = -286 },
    { type = "numericbox", id   = "fps",                      x = 198, y = -282 },

    { type = "label",    text = "ELEM_STOPMOTION_MODE",  x = 20,  y = -324 },
    { type = "dropdown", id   = "mode",                  x = 60,  y = -316, width = 150 ,
      items = {
        { value = "loop",   textKey = "ELEM_STOPMOTION_MODE_LOOP" },
        { value = "once",   textKey = "ELEM_STOPMOTION_MODE_ONCE" },
        { value = "bounce", textKey = "ELEM_STOPMOTION_MODE_BOUNCE" },
      },
    },

    { type = "checkbox", id   = "inverse", text = "ELEM_STOPMOTION_INVERSE", x = 18, y = -282 },
  },

  attributes = "default",
  position = "default",
}

function Bre.DrawerSpec_StopMotion:Refresh(ctx)
  -- Step2: Backfill basic params: path + rows/cols/frames (基础功能·路径/行/列/总帧数)
  -- Constitution v1.4:
  -- - Refresh is explicit backfill only (no side effects)
  -- - UI state is not trusted; element.table is the single source of truth
  local c = ctx and ctx.controls
  if not c then return end
  if not (c.path and c.path.SetText) then return end

  local data = ctx and ctx.data
  local path = ""
  local grid = ""
  local rowsN, colsN = nil, nil
  local frames = ""
  local fileW = ""
  local fileH = ""
  local frameW = ""
  local frameH = ""
  local fps = ""
  local mode = "loop"
  local inverse = false
  local useAdvanced = false
  if type(data) == "table" then
    -- data.stopmotion.path is the only authoritative field for this drawer.
    if type(data.stopmotion) == "table" then
      if type(data.stopmotion.path) == "string" then
        path = data.stopmotion.path
      end
      if type(data.stopmotion.rows) == "number" then
        rowsN = math.floor(data.stopmotion.rows)
      end
      if type(data.stopmotion.cols) == "number" then
        colsN = math.floor(data.stopmotion.cols)
      end
      if type(data.stopmotion.frames) == "number" then
        frames = tostring(math.floor(data.stopmotion.frames))
      end

      -- Normal slicing is square grid: grid = min(rows, cols) (fallback)
      if rowsN and colsN and rowsN > 0 and colsN > 0 then
        local n = rowsN
        if colsN < n then n = colsN end
        if n < 0 then n = 0 end
        grid = tostring(n)
      elseif rowsN and rowsN > 0 then
        grid = tostring(rowsN)
      elseif colsN and colsN > 0 then
        grid = tostring(colsN)
      end

      if type(data.stopmotion.fileW) == "number" then
        fileW = tostring(math.floor(data.stopmotion.fileW))
      end
      if type(data.stopmotion.fileH) == "number" then
        fileH = tostring(math.floor(data.stopmotion.fileH))
      end
      if type(data.stopmotion.frameW) == "number" then
        frameW = tostring(math.floor(data.stopmotion.frameW))
      end
      if type(data.stopmotion.frameH) == "number" then
        frameH = tostring(math.floor(data.stopmotion.frameH))
      end

      if type(data.stopmotion.fps) == "number" then
        fps = tostring(math.floor(data.stopmotion.fps))
      end
      if type(data.stopmotion.mode) == "string" then
        mode = data.stopmotion.mode
      end
      if data.stopmotion.inverse then
        inverse = true
      end
      if data.stopmotion.useAdvanced then
        useAdvanced = true
      end
    end
  end

  -- Bind edit target to prevent selection-change mis-commit.
  c.path._editBindNodeId = ctx and ctx.nodeId
  if c.grid then c.grid._editBindNodeId = ctx and ctx.nodeId end
  if c.frames then c.frames._editBindNodeId = ctx and ctx.nodeId end
  if c.fileW then c.fileW._editBindNodeId = ctx and ctx.nodeId end
  if c.fileH then c.fileH._editBindNodeId = ctx and ctx.nodeId end
  if c.frameW then c.frameW._editBindNodeId = ctx and ctx.nodeId end
  if c.frameH then c.frameH._editBindNodeId = ctx and ctx.nodeId end
  if c.fps then c.fps._editBindNodeId = ctx and ctx.nodeId end
  if c.inverse then c.inverse._editBindNodeId = ctx and ctx.nodeId end
  if c.useAdvanced then c.useAdvanced._editBindNodeId = ctx and ctx.nodeId end
  if c.mode then c.mode._editBindNodeId = ctx and ctx.nodeId end

  if c.path.GetText and c.path:GetText() ~= path then
    c.path:SetText(path)
  end

  if c.grid and c.grid.SetText and c.grid.GetText and c.grid:GetText() ~= grid then
    c.grid:SetText(grid)
  end
  if c.frames and c.frames.SetText and c.frames.GetText and c.frames:GetText() ~= frames then
    c.frames:SetText(frames)
  end

  if c.fileW and c.fileW.SetText and c.fileW.GetText and c.fileW:GetText() ~= fileW then
    c.fileW:SetText(fileW)
  end
  if c.fileH and c.fileH.SetText and c.fileH.GetText and c.fileH:GetText() ~= fileH then
    c.fileH:SetText(fileH)
  end
  if c.frameW and c.frameW.SetText and c.frameW.GetText and c.frameW:GetText() ~= frameW then
    c.frameW:SetText(frameW)
  end
  if c.frameH and c.frameH.SetText and c.frameH.GetText and c.frameH:GetText() ~= frameH then
    c.frameH:SetText(frameH)
  end

  if c.fps and c.fps.SetText and c.fps.GetText and c.fps:GetText() ~= fps then
    c.fps:SetText(fps)
  end
  if c.useAdvanced and c.useAdvanced.SetChecked then
    c.useAdvanced:SetChecked(useAdvanced and true or false)
  end

  if c.inverse and c.inverse.SetChecked then
    c.inverse:SetChecked(inverse and true or false)
  end
  if c.mode and UIDropDownMenu_SetText then
    -- Ensure dropdown shows current mode (no commit).
    local txtKey = (mode == "once" and "ELEM_STOPMOTION_MODE_ONCE") or (mode == "bounce" and "ELEM_STOPMOTION_MODE_BOUNCE") or "ELEM_STOPMOTION_MODE_LOOP"
    local label = (Bre and Bre.L and Bre.L(txtKey)) or mode
    UIDropDownMenu_SetText(c.mode, label)
    c.mode.__value = mode
  end


  -- Toggle enable states: only one source of truth is editable.
  local function _SetEnabled(ctrl, enabled)
    if not ctrl then return end
    if ctrl.SetEnabled then
      pcall(ctrl.SetEnabled, ctrl, enabled and true or false)
    elseif enabled and ctrl.Enable then
      pcall(ctrl.Enable, ctrl)
    elseif (not enabled) and ctrl.Disable then
      pcall(ctrl.Disable, ctrl)
    end
    if (not enabled) and ctrl.ClearFocus then
      pcall(ctrl.ClearFocus, ctrl)
    end
  end

  if useAdvanced then
    _SetEnabled(c.grid, false)
    _SetEnabled(c.frames, false)
    _SetEnabled(c.fileW, true)
    _SetEnabled(c.fileH, true)
    _SetEnabled(c.frameW, true)
    _SetEnabled(c.frameH, true)
  else
    _SetEnabled(c.grid, true)
    _SetEnabled(c.frames, true)
    _SetEnabled(c.fileW, false)
    _SetEnabled(c.fileH, false)
    _SetEnabled(c.frameW, false)
    _SetEnabled(c.frameH, false)
  end
end
