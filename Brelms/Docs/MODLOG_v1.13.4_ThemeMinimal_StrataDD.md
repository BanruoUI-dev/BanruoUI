# MODLOG v1.13.4 — ThemeMinimal FrameStrata Dropdown Only

## 修改点
- ThemeMinimal：将框架层级下拉控件 id 从 `levelDD` 改为 `strataDD`（语义：Frame Strata；不涉及数字 FrameLevel）。
- DrawerTemplate：FrameStrata 下拉逻辑兼容 `controls.strataDD` 与旧的 `controls.levelDD`（不影响现有抽屉）。
- 版本号更新：Bre.toc → v1.13.4

## 修改前 / 修改后
- 修改前：ThemeMinimal 使用 `levelDD`（易与“数字层级”混淆）。
- 修改后：ThemeMinimal 使用 `strataDD`；且模板仍只提供下拉（AUTO/背景/低/中/高/对话框/全屏/全屏对话框/提示层）。
