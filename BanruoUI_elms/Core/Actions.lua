-- Bre/Core/Actions.lua
-- Unified Action entry for UI context menu + /brs commands (M3)

local addonName, Bre = ...
Bre = Bre or {}

local Gate = Bre.Gate
local Registry = Bre.Registry

local Actions = { __id = "Actions" }

local function _UI()
  if Gate and Gate.Get then return Gate:Get("UI") end
end

local function _Move()
  if Gate and Gate.Get then return Gate:Get("Move") end
end

local function _IO()
  if Gate and Gate.Get then return Gate:Get("IO") end
end

local function _IterIds(ids)
  if type(ids) ~= "table" then
    return function() return nil end
  end
  return coroutine.wrap(function()
    for k, v in pairs(ids) do
      if type(k) == "string" and v == true then
        coroutine.yield(k)
      elseif type(k) == "number" and type(v) == "string" then
        coroutine.yield(v)
      end
    end
  end)
end

function Actions:GetId()
  return self.__id
end

function Actions:Execute(action, ctx)
  action = tostring(action or "")
  ctx = ctx or {}

  local UI = _UI()
  local Move = _Move()
  local IO = _IO()

  if action == "rename" then
    if UI and UI.BeginInlineRename and ctx.nodeId then
      UI:BeginInlineRename(ctx.nodeId)
    end
    return
  end

  if action == "copy" then
    if Move and Move.DuplicateSubtree and ctx.nodeId then
      local newId = Move:DuplicateSubtree(ctx.nodeId)
      if newId and UI and UI.frame then
        UI.frame._selectedId = newId
      end
    end
    if UI and UI.RefreshTree then UI:RefreshTree() end
    if UI and UI.RefreshRight then UI:RefreshRight() end
    return
  end

  if action == "delete" then
    if not ctx.nodeId then return end
    if UI and UI.ConfirmDelete then
      UI:ConfirmDelete(ctx.nodeId, function()
        if Move and Move.DeleteSubtree then Move:DeleteSubtree(ctx.nodeId) end
        if UI.RefreshTree then UI:RefreshTree() end
        if UI.RefreshRight then UI:RefreshRight() end
      end)
    else
      if Move and Move.DeleteSubtree then Move:DeleteSubtree(ctx.nodeId) end
    end
    return
  end

  if action == "export" then
    if not (IO and IO.ExportSubtreeToString and ctx.nodeId) then return end

    -- Export is only allowed for group nodes.
    local API = Gate and Gate.Get and Gate:Get("API_Data") or nil
    local C = Gate and Gate.Get and Gate:Get("Contract") or nil
    local data = (API and API.GetData and API:GetData(ctx.nodeId)) or nil
    local isGroup = (C and C.IsGroup and C:IsGroup(data and data.regionType)) and true or false
    if not isGroup then return end

    local s = IO:ExportSubtreeToString(ctx.nodeId)
    if UI and UI.ShowExportBox then UI:ShowExportBox(s) end
    return
  end


  if action == "load" or action == "unload" then
    if not ctx.nodeId then return end

    -- Step4: execution must not create extra commit side-effects.
    -- Only write via Gate->Move (or stub/no-op when off), then refresh UI inside EditGuard.
    if Move and Move.CommitLoadNever then
      if action == "unload" then
        Move:CommitLoadNever({ id = ctx.nodeId, value = true })
      else
        -- BrA-like: 'load' clears never, returning to tri-state evaluation (true/false/nil).
        Move:CommitLoadNever({ id = ctx.nodeId, value = nil })
      end
    end

    local function _refresh()
      if UI and UI.RefreshTree then UI:RefreshTree() end
      if UI and UI.RefreshRight then UI:RefreshRight() end
    end

    local EG = Gate and Gate.Get and Gate:Get("EditGuard") or nil
    if EG and EG.RunGuarded then
      EG:RunGuarded("LoadUnloadRefresh", _refresh)
    elseif EG and EG.Begin and EG.End then
      EG:Begin("LoadUnloadRefresh")
      _refresh()
      EG:End("LoadUnloadRefresh")
    else
      _refresh()
    end

    return
  end


  if action == "align_center" then
    if not (Move and Move.AlignToScreenCenter) then return end
    local any = false
    for id in _IterIds(ctx.ids) do
      any = true
      Move:AlignToScreenCenter(id)
    end
    if not any and ctx.nodeId then
      Move:AlignToScreenCenter(ctx.nodeId)
    end
    if UI and UI.RefreshTree then UI:RefreshTree() end
    if UI and UI.RefreshRight then UI:RefreshRight() end
    return
  end

  if action == "align_first" then
    if not (Move and Move.AlignToElement) then return end
    local refId = ctx.refId or ctx.nodeId
    if not refId then return end
    local any = false
    for id in _IterIds(ctx.ids) do
      any = true
      Move:AlignToElement(id, refId)
    end
    if not any then
      Move:AlignToElement(refId, refId)
    end
    if UI and UI.RefreshTree then UI:RefreshTree() end
    if UI and UI.RefreshRight then UI:RefreshRight() end
    return
  end
end

-- -------------------------------------------------------------------
-- Module registration (Registry -> Linker -> Gate)

local function _stub()
  return { Execute = function() end }
end

if Registry and Registry.Register then
  Registry:Register({
    id = "Actions",
    layer = "L1",
    desc = "Unified action router (context menu + slash commands)",
    exports = { "Actions" },
    defaults = {
      { iface = "Actions", policy = "no-op", stub = _stub() },
    },
    init = function()
      return Actions
    end,
  })
end

Bre.Actions = Actions
return Actions
