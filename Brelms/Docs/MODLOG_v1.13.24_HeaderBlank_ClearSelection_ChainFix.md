# MODLOG v1.13.24 · HeaderBlank ClearSelection Chain Fix

## Summary
Fix: clicking the blank header area should clear selection through the **same UI chain** as other clear-selection interactions, while preserving header drag.

## What changed
- Header blank click now calls `UI:ClearSelection()` (via `safeCall`) instead of only `SelectionService:Clear()` + `UI:RefreshAll()`.
- Fallback kept for safety if `UI:ClearSelection()` is unavailable.

## Why
`SelectionService:Clear()` alone does not fully synchronize UI-visible selection state (overlay/mover/frames), causing "no reaction" even though the service state changed.

## Behavior
- Drag on header blank: still works.
- Single click on header blank (no drag, no focused editbox): clears selection reliably.
