# MODLOG v1.13.17 - Profile Total Switch (DEV/THEME/FULL)

## Goal
Introduce a single runtime Profile switch to unify:
- UIWhitelist (UI hide/show)
- SizeMode (560x560 vs original)
- ThemeMinimal element drawer routing (the "third template")

Profiles:
- DEV   : Full authoring UI, default SizeMode = DEFAULT (560)
- THEME : ThemeMinimal UI (whitelist ON + ThemeMinimal routing), SizeMode = DEFAULT (560)
- FULL  : Full authoring UI, SizeMode = LEGACY (original)

## Changes
### Core/Profile.lua
- Add persisted runtime mode: `BreSaved.ui.profile_mode`
- Add API:
  - `Bre.Profile:GetMode()`
  - `Bre.Profile:SetMode(mode)`  -- mode: DEV|THEME|FULL
  - `Bre.Profile:Apply(ui)`      -- applies SizeMode + UIWhitelist + ThemeMinimal routing

### Core/UI.lua
- Replace hardcoded auto-apply COMPACT during show flow with `Bre.Profile:Apply(UI)`.

### Core/UI_SizeMode.lua
- Align SizeMode names with user commands:
  - DEFAULT / COMPACT => 560x560 (with BanruoUI border padding)
  - LEGACY / ORIGINAL => original size
- Toggle switches between DEFAULT <-> LEGACY.

## Usage (manual)
- `/run Bre.Profile:SetMode("THEME")`
- `/run Bre.Profile:SetMode("DEV")`
- `/run Bre.Profile:SetMode("FULL")`

## Notes
- Profile Apply is safe and idempotent.
- Refresh is UI-only; no implicit commit is introduced.
