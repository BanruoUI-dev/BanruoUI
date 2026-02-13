# v1.13.28 · Top Drag Stable (HeaderHit single drag source)

## Goal
Fix floaty/unstable panel drag feeling when dragging from the top area.

## Changes
- Core/UI.lua
  - Removed main frame (f) direct RegisterForDrag/OnDragStart/OnDragStop.
  - Keep only headerHit as the single drag entry (headerHit -> f:StartMoving / StopMovingOrSizing).
  - Added UpdateHeaderHitInsets() call after f:Show() in UI:Toggle().
  - Hooked OnSizeChanged on main frame to refresh headerHit hit-rect insets.

## Result
- Drag from the top area feels stable (no double-drag capture).
- Import/New/Close click behavior unchanged.
