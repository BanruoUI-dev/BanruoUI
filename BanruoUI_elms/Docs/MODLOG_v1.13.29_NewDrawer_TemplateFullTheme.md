# MODLOG v1.13.29 — New Drawer template (FULL/DEV + THEME)

目标：
- 新建抽屉（New overlay）接入 FULL/DEV 的统一网格规则（DrawerTemplate）。
- THEME 模式：单列显示，隐藏“预设模板（组）”整块。

修改点：
1) Core/UI.lua
- 重写 `UI:BuildNewOverlay(parent)`：
  - 删除旧的写死布局（X=60/300、colW=160、scroll:SetSize(...) 等）。
  - 改为从 `Bre.DrawerTemplate.LAYOUT` 读取 `COL1_X / COL2_X / SCROLL_RIGHT` 进行定位与滚动条预留。
  - 按钮尺寸统一为 180×28，行距 10（FULL/DEV 一致）。
  - THEME 模式下隐藏右列标题与滚动区域（单列）。

2) BanruoUI_elms.toc
- 版本号：1.13.28 → 1.13.29

修改前：
- 新建抽屉使用写死坐标与写死滚动区域尺寸，导致整体右飘、滚动条容易被挤出。

修改后：
- 新建抽屉按 DrawerTemplate 网格对齐；FULL/DEV 双列；THEME 单列并隐藏预设模板区；滚动条保持在面板内。
