---@meta

-- ============================================================
-- Geometry
-- ============================================================

---@class Point
---@field x number  East/West offset in units
---@field y number  North/South offset in units

-- ============================================================
-- Bot semantic types
-- ============================================================

---@alias TargetSpecifier "self"|"pet"|"group"|string
--- Who a buff should be cast on.
--- - `"self"`  — the casting character
--- - `"pet"`   — the caster's pet
--- - `"group"` — all group members and their pets
--- - any other string — a named PC in the zone

---@class BuffEntry
---@field spellName string           Exact name as it appears in the spellbook
---@field refreshTime number         Recast when remaining duration drops below this (seconds)
---@field targets TargetSpecifier[]  Who receives the buff

---@class ResolvedTarget
---@field spawn spawn                Resolved MQ2 spawn TLO
---@field label string               Human-readable name used in status messages
