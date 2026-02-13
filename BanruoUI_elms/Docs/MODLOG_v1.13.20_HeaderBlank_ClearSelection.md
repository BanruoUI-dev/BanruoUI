Bre v1.13.20 - Header blank click clears selection

Modified Files
- Bre/Core/UI.lua
- Bre/Bre.toc

Change Log
1) Header blank click -> Cancel selection
- Before: clicking the header blank area did nothing and the current selection remained.
- After: clicking the header blank area clears selection via SelectionService:Clear("header") and then refreshes the UI (refresh is side-effect free).

Rules / Constraints
- Trigger only on LeftButton.
- If any EditBox currently has keyboard focus, do nothing (avoid accidental EditFocusLost commit).
- Does NOT capture clicks outside the addon frame.
- Buttons (New / Import / Close) are not affected; their click handlers remain unchanged.
