# MODLOG v1.13.25
## Goal
- "New" button should be hidden in THEME mode, visible in FULL/DEV.

## Changes
- UI:ApplyTopButtonsWhitelist no longer forces "New" always visible. All top buttons obey whitelist allow table when enabled.
- UIWhitelist: when disabled, actively restores all top buttons and drawer tabs (so switching THEME -> FULL/DEV restores visibility).

## Manual test
- SetMode("THEME"): New hidden; Import/Close shown; Element/LoadIO tabs shown.
- SetMode("FULL") or SetMode("DEV"): New shown again without reload; all tabs/buttons restored.
