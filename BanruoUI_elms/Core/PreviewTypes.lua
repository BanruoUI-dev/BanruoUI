-- Bre/Core/PreviewTypes.lua
-- Preview descriptor types (read-only data structure)
-- Step17: define preview schema (static preview; no live updates yet)

local addonName, Bre = ...
Bre = Bre or {}

Bre.PreviewTypes = Bre.PreviewTypes or {}

-- kind enums
Bre.PreviewTypes.KIND_NONE    = "none"
Bre.PreviewTypes.KIND_TEXTURE = "texture"

-- factory helpers (pure data; no side effects)
function Bre.PreviewTypes.None()
  return { kind = Bre.PreviewTypes.KIND_NONE }
end

-- tex: file/atlas path; optional: texCoord {l,r,t,b}, color {r,g,b,a}
function Bre.PreviewTypes.Texture(tex, texCoord, color)
  return {
    kind = Bre.PreviewTypes.KIND_TEXTURE,
    tex = tex,
    texCoord = texCoord,
    color = color,
  }
end
