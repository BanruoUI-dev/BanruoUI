# MODLOG v1.13.12 — SizeMode DEFAULT: 560×560 (Tree 320 + Right 240)

- 基线：v1.13.11 (Bre_v1.13.11_SizeMode560_2col.zip)
- 目标：在 **不自动调用 SetSize** 的前提下，调整 DEFAULT 模式的两列宽度为：
  - Panel：560 × 560
  - Tree：320
  - Drawer：240

## 变更点
1) `Bre/Core/UI.lua`
- DEFAULT 固定列宽：
  - `TREE_W_FIXED`：350 → 320
  - `RIGHT_W_FIXED`：210 → 240
- 其余布局逻辑保持不变（仍仅在显式调用 SizeMode 时切换）。

2) `Bre/Core/UI_SizeMode.lua`
- 仅更新 DEFAULT 注释说明（逻辑不变）。

3) `Bre/Bre.toc`
- 版本号：v1.13.11 → v1.13.12

## 自查
- ✅ 未在 Create/Show/Open/Apply 等 UI 创建/显示流程中新增任何 SetSize 调用
- ✅ 仅显式调用 `Bre.UI:SetSizeMode("DEFAULT")` / `ToggleSizeMode()` 才会应用尺寸与列宽
- ✅ LEGACY 模式不受影响
