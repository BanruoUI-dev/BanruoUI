# MODLOG v1.13.14 — New always visible + Auto Compact on Open

基线：Bre_v1.13.12_SizeMode560_320_240.zip

## 目标
- 【1】New（新建）按钮不参与白名单切换，始终显示。
- 【2】UI 创建/显示流程中自动应用 560×560（COMPACT），并且仍可在 900×650 与 560×560 间切换。

## 实现
### SizeMode
- 移除：LEGACY = 820×560
- 保留两档：
  - DEFAULT = 900×650
  - COMPACT = 560×560（左 320 / 右 240）

### 自动应用
- UI 打开（UI:Toggle 显示路径）时自动执行：SetSizeMode("COMPACT")

### New 按钮
- 白名单应用时跳过 New：不会再被 SetShown(false)。

## 修改文件
- Bre/Core/UI_SizeMode.lua
- Bre/Core/UI.lua
- Bre/Bre.toc

## 自查
- UI 打开即为 560×560（COMPACT）。
- ToggleSizeMode 仅在 DEFAULT(900×650) 与 COMPACT(560×560) 间切换。
- ApplyTopButtonsWhitelist 不再影响 New 可见性。
