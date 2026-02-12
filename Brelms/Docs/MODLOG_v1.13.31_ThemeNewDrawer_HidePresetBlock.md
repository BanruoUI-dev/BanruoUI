# MODLOG v1.13.31 — THEME: New Drawer hide Preset block (UI-only, no layout slot)

## Goal
In THEME single-column mode, the right-side "Presets (Group)" section must be hidden at UI level and must NOT occupy any layout slot (including the title), so it will not push/affect scrollbars or spacing.

## Changes
- Core/UI.lua
  - BuildNewOverlay(): wrap the Preset section (title + scrollframe + content) into `rightBlock`.
  - THEME mode: `rightBlock:Hide()` (UI-only hide, removes the whole block).
  - Extra safety: also hide possible scrollbar handles on some templates.

## Notes
- FULL/DEV behavior unchanged (two columns).
- THEME becomes single column by hiding the entire preset block (title + scrollframe).
