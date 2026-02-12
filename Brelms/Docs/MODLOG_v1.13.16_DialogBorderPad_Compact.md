MODLOG v1.13.16 — Compact DialogBox border padding (Scheme A)

基线：v1.13.15_BanruoUIBorder.zip

目标
- 使用 BanruoUI 的 UI-DialogBox 边框后，修复“外框包不住内容”的问题
- 采用方案A：扩大主面板外框尺寸（Compact 档位），让边框厚度不压到内容

修改点
1) Bre/Core/UI_SizeMode.lua
- COMPACT 尺寸从 560x560（outer）改为：560 + (11+12) by 560 + (12+11)
- 即 outer = 583x583，用于包住 560x560 内容

2) Bre/Core/UI.lua
- Compact 档位主面板尺寸改为 COMPACT_OUTER_W/H（583x583）
- Compact 档位 body 区域增加 DialogBox inset，保证内容不顶到边框

不变项
- 不改任何按钮/字体/黄线/逻辑
- 不改默认 900x650 档位行为
