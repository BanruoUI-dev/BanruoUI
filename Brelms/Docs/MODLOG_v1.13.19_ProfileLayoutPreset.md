# MODLOG v1.13.19

目标：修复 THEME 的结构语义：THEME 不只是 560×560，而是固定两列布局（左 320 / 右 240）。

## 修改点

1) 新增 LayoutPreset 概念：
- LEGACY_DEFAULT：原布局
- THEME_320_240：主题布局（Tree 320 / Right 240，无间距）

2) Profile 总开关收口裁决：
- THEME => SizeMode = COMPACT（560×560） + LayoutPreset = THEME_320_240
- DEV  => SizeMode = LEGACY（原尺寸） + LayoutPreset = LEGACY_DEFAULT
- FULL => SizeMode = LEGACY（原尺寸） + LayoutPreset = LEGACY_DEFAULT

3) UI 内部布局应用从 SizeMode 解耦：
- UI:OnSizeModeApplied 不再用 SizeMode 决定内部列宽，仅负责触发 ApplyLayoutPreset。
- 兼容：当未设置 LayoutPreset 时，COMPACT 默认映射 THEME_320_240。

## 文件
- Bre/Core/UI.lua
- Bre/Core/Profile.lua
- Bre/Bre.toc
