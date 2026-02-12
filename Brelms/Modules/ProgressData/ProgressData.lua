-- Bre/Modules/ProgressData/ProgressData.lua
-- ProgressData (L2): Real-time data source for progress bars
-- Version: v2.18.14
-- Changes: Fixed UNIT_POWER_UPDATE duplicate notifications - same unit multiple power types now work

local addonName, Bre = ...
Bre = Bre or {}

Bre.ProgressData = Bre.ProgressData or {
  version = "2.18.14",
  -- L2 module capability declaration (v1.5 mandatory)
  runtime_required = true,
  authoring_required = false,
}

local M = Bre.ProgressData

-- Internal data sources registry
M._sources = M._sources or {}
M._subscribers = M._subscribers or {}
M._cache = M._cache or {}

-- Event frame for listening to game events
local eventFrame = nil

-- Unit-event registration state (Retail 12.0): UNIT_* must be registered per-unit.
M._unitRegs = M._unitRegs or { Health = {} } -- sourceType -> set(unit)=true

-- NOTE (Retail 12.0): UNIT_* events fire reliably via RegisterEvent on a normal frame.
-- Using RegisterUnitEvent on a shared frame is brittle because each call replaces the
-- unit filter for that event on that frame. ElvUI(oUF) uses RegisterEvent for Retail.

-----------------------------------------------------------
-- Built-in Data Sources
-----------------------------------------------------------


-- Health data source (WoW 12.0 compatible)
local function HealthGetValue(unit)
  unit = unit or "player"
  -- Return numeric 0-1 percent if API available; never do math on secret values here.
  if UnitHealthPercent then
    local p = UnitHealthPercent(unit) -- usually 0-100 number
    if type(p) == "number" then
      if p < 0 then p = 0 elseif p > 100 then p = 100 end
      return p / 100
    end
  end
  return nil
end

-- Register built-in Health source
M._sources["Health"] = {
  getValue = HealthGetValue,
  events = {
    -- WoW 12.0 Retail events (following oUF pattern)
    "UNIT_HEALTH",
    "UNIT_MAXHEALTH",
    "UNIT_MAX_HEALTH_MODIFIERS_CHANGED",
  },
  defaultColor = { r = 0.19, g = 0.81, b = 0.15, a = 1 },  -- 绿色 (49, 207, 37)
}

-----------------------------------------------------------
-- Power data sources (WoW 12.0 compatible)
-- Note: All use UnitPower/UnitPowerMax which return secret values
-----------------------------------------------------------

-- Generic power getValue function
-- @param unit: string - "player", "target", etc.
-- @param powerType: number - Enum.PowerType index
-- @return: number (0-1) or nil
local function PowerGetValue(unit, powerType)
  unit = unit or "player"
  if not powerType then return nil end
  
  local cur = UnitPower(unit, powerType)
  local max = UnitPowerMax(unit, powerType)
  
  if not cur or not max or max == 0 then return nil end
  
  -- WoW 12.0: cur and max may be secret values, but division still works
  -- Return as 0-1 percent for compatibility
  if type(cur) == "number" and type(max) == "number" then
    return cur / max
  end
  
  return nil
end

-- Mana (法力值) - Enum.PowerType.Mana = 0
local function ManaGetValue(unit)
  return PowerGetValue(unit, 0)
end

M._sources["Mana"] = {
  getValue = ManaGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
  defaultColor = { r = 0, g = 0.8, b = 1, a = 1 },  -- 蓝色
}

-- Energy (能量) - Enum.PowerType.Energy = 3
local function EnergyGetValue(unit)
  return PowerGetValue(unit, 3)
end

M._sources["Energy"] = {
  getValue = EnergyGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
  defaultColor = { r = 1, g = 1, b = 0, a = 1 },  -- 黄色
}

-- Rage (怒气) - Enum.PowerType.Rage = 1
local function RageGetValue(unit)
  return PowerGetValue(unit, 1)
end

M._sources["Rage"] = {
  getValue = RageGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
  defaultColor = { r = 1, g = 0, b = 0, a = 1 },  -- 红色
}

-- Focus (集中值) - Enum.PowerType.Focus = 2
local function FocusGetValue(unit)
  return PowerGetValue(unit, 2)
end

M._sources["Focus"] = {
  getValue = FocusGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
  defaultColor = { r = 1, g = 0.5, b = 0.25, a = 1 },  -- 橙色
}

-- RunicPower (符文能量) - Enum.PowerType.RunicPower = 6
local function RunicPowerGetValue(unit)
  return PowerGetValue(unit, 6)
end

M._sources["RunicPower"] = {
  getValue = RunicPowerGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
  defaultColor = { r = 0, g = 0.8, b = 1, a = 1 },  -- 青色
}

-- Insanity (疯狂值) - Enum.PowerType.Insanity = 13
local function InsanityGetValue(unit)
  return PowerGetValue(unit, 13)
end

M._sources["Insanity"] = {
  getValue = InsanityGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
  defaultColor = { r = 0.4, g = 0, b = 0.8, a = 1 },  -- 紫色
}

-- LunarPower (星界能量/月能量) - Enum.PowerType.LunarPower = 8
local function LunarPowerGetValue(unit)
  return PowerGetValue(unit, 8)
end

M._sources["LunarPower"] = {
  getValue = LunarPowerGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
  defaultColor = { r = 0.3, g = 0.5, b = 0.85, a = 1 },  -- 月光蓝
}

-- Fury (魔怒) - Enum.PowerType.Fury = 17
local function FuryGetValue(unit)
  return PowerGetValue(unit, 17)
end

M._sources["Fury"] = {
  getValue = FuryGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
  defaultColor = { r = 0.8, g = 0.26, b = 0.8, a = 1 },  -- 紫红
}

-- Pain (痛苦) - Enum.PowerType.Pain = 18
local function PainGetValue(unit)
  return PowerGetValue(unit, 18)
end

M._sources["Pain"] = {
  getValue = PainGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
  defaultColor = { r = 1, g = 0.6, b = 0, a = 1 },  -- 橙红
}

-- Maelstrom (漩涡值) - Enum.PowerType.Maelstrom = 11
local function MaelstromGetValue(unit)
  return PowerGetValue(unit, 11)
end

M._sources["Maelstrom"] = {
  getValue = MaelstromGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
  defaultColor = { r = 0, g = 0.5, b = 1, a = 1 },  -- 深蓝
}

-----------------------------------------------------------
-- Reserved Power Sources (未启用 - 需对应UI模板)
-----------------------------------------------------------
--[[
启用方法：
1. 取消以下对应能量的注释块
2. 在 DrawerSpec_ProgressMat.lua 添加对应下拉菜单选项
3. 在 Locales 确认多语言已添加
4. 测试对应职业的能量显示

注意：
- ComboPoints/Runes 等职业专属能量需要对应职业才能测试
- Alternate 仅在特定副本/场景中可用

-- ComboPoints (连击点) - Enum.PowerType.ComboPoints = 4
-- 盗贼、德鲁伊（野性/守护）
local function ComboPointsGetValue(unit)
  return PowerGetValue(unit, 4)
end

M._sources["ComboPoints"] = {
  getValue = ComboPointsGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
}

-- SoulShards (灵魂碎片) - Enum.PowerType.SoulShards = 7
-- 术士
local function SoulShardsGetValue(unit)
  return PowerGetValue(unit, 7)
end

M._sources["SoulShards"] = {
  getValue = SoulShardsGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
}

-- HolyPower (圣能) - Enum.PowerType.HolyPower = 9
-- 圣骑士
local function HolyPowerGetValue(unit)
  return PowerGetValue(unit, 9)
end

M._sources["HolyPower"] = {
  getValue = HolyPowerGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
}

-- Chi (真气) - Enum.PowerType.Chi = 12
-- 武僧
local function ChiGetValue(unit)
  return PowerGetValue(unit, 12)
end

M._sources["Chi"] = {
  getValue = ChiGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
}

-- ArcaneCharges (奥术充能) - Enum.PowerType.ArcaneCharges = 16
-- 法师（奥术专精）
local function ArcaneChargesGetValue(unit)
  return PowerGetValue(unit, 16)
end

M._sources["ArcaneCharges"] = {
  getValue = ArcaneChargesGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
}

-- Essence (精华) - Enum.PowerType.Essence = 19
-- 唤魔师 (WoW 10.0+)
local function EssenceGetValue(unit)
  return PowerGetValue(unit, 19)
end

M._sources["Essence"] = {
  getValue = EssenceGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
}

-- Runes (符文) - Enum.PowerType.Runes = 5
-- 死亡骑士
-- 注意：符文系统较特殊，有6个独立符文槽位，可能需要单独处理
local function RunesGetValue(unit)
  return PowerGetValue(unit, 5)
end

M._sources["Runes"] = {
  getValue = RunesGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
    "RUNE_POWER_UPDATE",  -- 符文专用事件
  },
}

-- Alternate (替代能量) - Enum.PowerType.Alternate = 10
-- 特殊副本机制（如围攻奥格/永恒黎明等）
local function AlternateGetValue(unit)
  return PowerGetValue(unit, 10)
end

M._sources["Alternate"] = {
  getValue = AlternateGetValue,
  events = {
    "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER",
  },
}
]]

-----------------------------------------------------------
-- Public API
-----------------------------------------------------------

-- Get current health values (WoW 12.0 secret value compatible)
-- @param unit: string - "player", "target", "focus", etc.
-- @return: cur, max (secret values, can be passed directly to StatusBar:SetValue)
function M:GetHealthValues(unit)
  if not unit or unit == "" then unit = "player" end
  
  -- Get secret values from WoW API
  local cur = UnitHealth(unit)
  local max = UnitHealthMax(unit)
  
  if Bre.DEBUG then
    -- issecretvalue() check
    local curIsSecret = issecretvalue and issecretvalue(cur) or false
    local maxIsSecret = issecretvalue and issecretvalue(max) or false
    print(string.format("[ProgressData] GetHealthValues: unit=%s, curIsSecret=%s, maxIsSecret=%s", 
      unit, tostring(curIsSecret), tostring(maxIsSecret)))
  end
  
  return cur, max
end

-- Get current power values (WoW 12.0 secret value compatible)
-- @param unit: string - "player", "target", "focus", etc.
-- @param powerType: number - Enum.PowerType index (0=Mana, 1=Rage, 3=Energy, etc.)
-- @return: cur, max (secret values, can be passed directly to StatusBar:SetValue)
function M:GetPowerValues(unit, powerType)
  if not unit or unit == "" then unit = "player" end
  if not powerType then powerType = 0 end  -- Default to Mana
  
  -- Get secret values from WoW API
  local cur = UnitPower(unit, powerType)
  local max = UnitPowerMax(unit, powerType)
  
  if Bre.DEBUG then
    local curIsSecret = issecretvalue and issecretvalue(cur) or false
    local maxIsSecret = issecretvalue and issecretvalue(max) or false
    print(string.format("[ProgressData] GetPowerValues: unit=%s, powerType=%d, curIsSecret=%s, maxIsSecret=%s", 
      unit, powerType, tostring(curIsSecret), tostring(maxIsSecret)))
  end
  
  return cur, max
end

-- DEPRECATED: Get current value for a data source (v2.15.x)
-- Use GetHealthValues instead for WoW 12.0 compatibility
-- @param sourceType: string - "Health", "Power", etc.
-- @param unit: string - "player", "target", "focus", etc.
-- @return: number (0-1) or nil if not available
function M:GetValue(sourceType, unit)
  if type(sourceType) ~= "string" then return nil end
  if not unit or unit == "" then unit = "player" end
  
  if Bre.DEBUG then
    print(string.format("[ProgressData] GetValue called: %s %s", sourceType, unit))
  end
  local source = self._sources[sourceType]
  if not source or type(source.getValue) ~= "function" then
    return nil
  end
  
  -- Get fresh value (don't use cache on explicit GetValue call)
  local ok, value = pcall(source.getValue, unit)
  if not ok then
    return nil
  end
  
  if value == nil then
    return nil
  end
  
  -- Cache the value
  local cacheKey = sourceType .. ":" .. unit
  self._cache[cacheKey] = value
  if Bre.DEBUG then
    print(string.format("[ProgressData] ✓ GetValue: %s %s = %.2f", sourceType, unit, value))
  end
end

-- Register a custom data source (reserved for future expansion)
-- @param name: string - unique name for the source
-- @param config: table - {getValue = function(unit), events = {}}
function M:RegisterSource(name, config)
  if type(name) ~= "string" or type(config) ~= "table" then return end
  if type(config.getValue) ~= "function" then return end
  
  self._sources[name] = {
    getValue = config.getValue,
    events = config.events or {},
  }
end

-- Subscribe to data changes (internal use)
-- @param elementId: string
-- @param sourceType: string
-- @param unit: string
function M:Subscribe(elementId, sourceType, unit)
  if type(elementId) ~= "string" then 
    return 
  end
  if not sourceType or sourceType == "" then 
    return 
  end
  if not unit or unit == "" then unit = "player" end
  
  self._subscribers[elementId] = {
    sourceType = sourceType,
    unit = unit,
  }
  if Bre.DEBUG then
    print(string.format("[ProgressData] ✓ Subscribed: %s to %s %s", elementId, sourceType, unit))
  end
  
  -- Initialize events if not done yet
  if not eventFrame then
    self:InitEvents()
  end
end

-- Count subscribers (for debug)
function M:CountSubscribers()
  local count = 0
  for _ in pairs(self._subscribers) do
    count = count + 1
  end
  return count
end

-- Unsubscribe from data changes
-- @param elementId: string
function M:Unsubscribe(elementId)
  if type(elementId) ~= "string" then return end
  self._subscribers[elementId] = nil
end

-- Clear cache (called on events)
function M:ClearCache(sourceType, unit)
  if sourceType and unit then
    local cacheKey = sourceType .. ":" .. unit
    self._cache[cacheKey] = nil
  else
    -- Clear all cache
    self._cache = {}
  end
end

-----------------------------------------------------------
-- Event Handling
-----------------------------------------------------------

-- Initialize event frame and register events
function M:InitEvents()
  if eventFrame then return end
  
  eventFrame = CreateFrame("Frame")

  -- Register ALL events from sources (following oUF Retail pattern)
  -- WoW 12.0: Use RegisterEvent (not RegisterUnitEvent) for UNIT_* events
  -- Events will fire for all units; we filter by unit in OnEvent
  local registered = {}
  for _, source in pairs(self._sources) do
    if type(source.events) == "table" then
      for _, event in ipairs(source.events) do
        if type(event) == "string" and not registered[event] then
          eventFrame:RegisterEvent(event)
          registered[event] = true
          if Bre.DEBUG then
            print(string.format("[ProgressData] InitEvents: registered %s", event))
          end
        end
      end
    end
  end

  -- Event handler
  eventFrame:SetScript("OnEvent", function(self, event, ...)
    M:OnEvent(event, ...)
  end)
end

-- Event callback
function M:OnEvent(event, unit)
  -- UNIT_* events always have unit parameter
  if not unit then 
    if Bre.DEBUG then
      print(string.format("[ProgressData] OnEvent: %s with no unit (skipped)", event))
    end
    return 
  end

  -- Health-related events (WoW 12.0 Retail)
  if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_MAX_HEALTH_MODIFIERS_CHANGED" then
    -- Only process if we have subscribers for this unit
    local hasSubscriber = false
    for _, sub in pairs(self._subscribers) do
      if sub.sourceType == "Health" and sub.unit == unit then
        hasSubscriber = true
        break
      end
    end
    
    if hasSubscriber then
      self:ClearCache("Health", unit)
      self:NotifySubscribers("Health", unit)
      if Bre.DEBUG then
        print(string.format("[ProgressData] OnEvent: %s for %s → notified", event, unit))
      end
    end
  -- Power-related events (WoW 12.0 Retail)
  elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
    -- Collect unique sourceTypes that need notification (avoid duplicate notifications)
    local notifiedTypes = {}
    for _, sub in pairs(self._subscribers) do
      if sub.unit == unit and sub.sourceType ~= "Health" then
        -- Only notify each sourceType once
        if not notifiedTypes[sub.sourceType] then
          notifiedTypes[sub.sourceType] = true
          self:ClearCache(sub.sourceType, unit)
          self:NotifySubscribers(sub.sourceType, unit)
          if Bre.DEBUG then
            print(string.format("[ProgressData] OnEvent: %s for %s %s → notified", event, sub.sourceType, unit))
          end
        end
      end
    end
  end
end

-- Notify subscribers that data has changed
function M:NotifySubscribers(sourceType, unit)
  local count = 0
  for elementId, sub in pairs(self._subscribers) do
    if sub.sourceType == sourceType and sub.unit == unit then
      count = count + 1
      
      -- Refresh Move (runtime region) - this is what user sees
      local Move = Bre.Gate and Bre.Gate.Get and Bre.Gate:Get("Move")
      if Move and Move.Refresh then
        pcall(Move.Refresh, Move, elementId)
      end
      
      -- Refresh Render (preview/fallback)
      local Render = Bre.Gate and Bre.Gate.Get and Bre.Gate:Get("Render")
      if Render and Render.ShowForElement then
        local GetData = Bre.GetData
        if GetData then
          local el = GetData(elementId)
          if el then
            pcall(Render.ShowForElement, Render, elementId, el)
          end
        end
      end
    end
  end
  
  if Bre.DEBUG and count > 0 then
    print(string.format("[ProgressData] NotifySubscribers: %s %s → refreshed %d elements", sourceType, unit, count))
  end
end

-----------------------------------------------------------
-- Module Initialization
-----------------------------------------------------------

-- Initialize on load
function M:Init()
  self:InitEvents()
end

return M