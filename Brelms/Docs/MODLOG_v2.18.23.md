# MODLOG v2.18.23

## 改动摘要
- 修复【输出动作】面板“新增”按钮无法点击的问题（被 NineSlice 视觉层吃鼠标）。
- “新增”按钮改用暴雪 `UIPanelButtonTemplate` 皮肤。

## 修改点
### 1) 输出动作顶部条交互层级修复
- 文件：`Bre/Core/UI.lua`
- 区域：`UI:BuildActionsPane(p)` 顶部 Top 区

**修改前**
- 顶部容器（actionsTop）可能附带 NineSlice 视觉层，鼠标命中落在 NineSlice 的 Center/Corner 上，导致按钮无法获得点击。
- 新增按钮为自绘 Backdrop 按钮，命中/层级更容易被遮挡。

**修改后**
- 顶部容器禁止吃鼠标：`top:EnableMouse(false)`
- 新增 `topUI` 作为“交互层”，并提升 FrameLevel（+200）
- 新增按钮提升 FrameLevel（额外 +200）确保始终位于最上层
- 新增按钮改为 `UIPanelButtonTemplate`

