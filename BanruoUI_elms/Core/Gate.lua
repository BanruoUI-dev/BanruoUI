--[[
  ✅ ARCH CONSOLIDATION (Step6)
  Responsibility:
  - Gate: Cross-module access & invocation bus (single entrypoint).
  - Gate must NOT own registration/discovery semantics beyond a thin mapping.
  Notes:
  - Step6 is "semantic consolidation": documentation + boundary markers only.
  - No behavior changes.
]]


--[[
  ✅ ARCH HARDENING (Step3)
  Gate is the ONLY cross-module access bus.
  Rules (policy-level, no behavior change in Step3):
  - All modules must be accessed via Gate:Get(<ModuleId>).
  - Any off/disabled module MUST be represented by a stub/no-op returned from Gate.
  - UI/L2 must NOT cache "real module" references or bypass Gate.
  Notes:
  - Step3 adds documentation/guardrails ONLY (no logic changes).
]]

-- Bre/Core/Gate.lua
-- Gate = single entrypoint for cross-module access.
-- Default behavior returns stub (safe no-op) to keep the addon from erroring when modules are disabled.

local addonName, Bre = ...
Bre = Bre or {}

Bre.Gate = Bre.Gate or {
  version = "2.14.69",
  _ifaces = {},   -- real implementations
  _stubs = {},    -- stub implementations
  _meta  = {},    -- iface -> {owner=moduleId, policy=...}
}

local Gate = Bre.Gate



-- Step4 fix: initialize proxies AFTER Gate is defined
Gate._proxies = Gate._proxies or {}
local function noop() end

local function default_stub(policy)
  -- policy: no-op | safe-return | empty-table
  if policy == "empty-table" then
    return setmetatable({}, { __index = function() return noop end })
  end
  if policy == "safe-return" then
    return setmetatable({}, { __index = function() return function() return nil end end })
  end
  -- default: no-op
  return setmetatable({}, { __index = function() return noop end })
end

function Gate:RegisterStub(iface, stub, meta)
  if type(iface) ~= "string" or iface == "" then return end
  Gate._stubs[iface] = stub or default_stub((meta and meta.policy) or "no-op")
  Gate._meta[iface] = meta or Gate._meta[iface] or {}
end

function Gate:Set(iface, impl, meta)
  if type(iface) ~= "string" or iface == "" then return end
  if impl == nil then
    Gate._ifaces[iface] = nil
  else
    Gate._ifaces[iface] = impl
  end
  if meta then Gate._meta[iface] = meta end
end

function Gate:Clear(iface)
  Gate._ifaces[iface] = nil
end

-- Gate:Get is the canonical module access point (returns stub when disabled).


function Gate:_Resolve(iface)
  local impl = Gate._ifaces[iface]
  if impl ~= nil then return impl end
  local stub = Gate._stubs[iface]
  if stub ~= nil then return stub end
  -- late default
  stub = default_stub("no-op")
  Gate._stubs[iface] = stub
  return stub
end

function Gate:Get(iface)
  -- Return a stable proxy to prevent soft-bypass via cached module references.
  -- The proxy resolves the current impl/stub on each access/call.
  local p = Gate._proxies[iface]
  if p ~= nil then return p end

  p = { __iface = iface }
  setmetatable(p, {
    __index = function(self, k)
      local impl = Gate:_Resolve(self.__iface)
      if self.__iface == "PropertyService" and k == "PreviewApply" then
        if type(impl) == "table" then
          -- no-op (removed dead loop)
        end
      end
      local v = impl[k]
      if type(v) == "function" then
        -- Preserve ":" call style: proxy:Method(...) will delegate to impl:Method(...)
        return function(_, ...)
          return v(impl, ...)
        end
      end
      return v
    end,
    __newindex = function(self, k, v)
      -- Avoid writing into live modules through Gate.
      rawset(self, k, v)
    end,
  })

  Gate._proxies[iface] = p
  return p
end


function Gate:Has(iface)
  return Gate._ifaces[iface] ~= nil
end

function Gate:Meta(iface)
  return Gate._meta[iface]
end
