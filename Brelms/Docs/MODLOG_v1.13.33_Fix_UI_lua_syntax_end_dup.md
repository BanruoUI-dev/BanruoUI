# v1.13.33 · Fix UI.lua syntax error (extra end)

## Change
- Removed a duplicated `if scroll and scroll.scrollBar ... end` block that introduced an extra `end` and caused:
  - `UI.lua:<line>: '<eof>' expected near 'end'`

## Files
- `BanruoUI_elms/Core/UI.lua`
