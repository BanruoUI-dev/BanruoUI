# MODLOG - v1.13 (基于 v1.12 基线)

## 目标（本次仅做机制，不默认启用）
- 建立「顶部按钮白名单」与「抽屉级白名单」的数据结构
- 建立开关与 Apply 分发器（默认 OFF，不改变现有 UI 显示）
- 结构可扩展：预留 drawer_sections / controls 两层，后续可细化

## 1) 新增文件
- `Bre/Core/UIWhitelist.lua`
  - 白名单配置：TopButtons / Drawers（已填）
  - 预留：DrawerSections / Controls（空表）
  - 开关：enabled + enable_top_buttons + enable_drawers（默认 false）
  - Apply 分发器：按开关调用 UI 的 Apply* 方法

## 2) 修改文件
- `Bre/Bre.toc`
  - 版本号：`v1.13`
  - 加载顺序：在 `Core/UI.lua` 前新增 `Core/UIWhitelist.lua`

- `Bre/Core/UI.lua`
  - 新增三处方法（仅提供入口，不自动启用）：
    - `UI:ApplyUIWhitelist()`
    - `UI:ApplyTopButtonsWhitelist(cfg)`
    - `UI:ApplyDrawersWhitelist(cfg)`
  - 在 `UI:EnsureFrame()` 中记录白名单所需引用：
    - `f._topBar` 与 `top._btns`（New/Import/Close）
    - `f._rightPanel`（用于访问 right._tabBtns）

## 3) 默认行为（重要）
- 默认不开启白名单：UI 显示与 v1.12 完全一致
- 只有当外部将开关置为 ON 并调用 Apply 时，才会按白名单显隐
