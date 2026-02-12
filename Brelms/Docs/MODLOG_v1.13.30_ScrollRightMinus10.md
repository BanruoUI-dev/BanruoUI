# v1.13.30 · ScrollFrame Right Offset -10px

## 修改内容
- 将新建抽屉（New Overlay）相关 ScrollFrame 的右侧预留常量 `SCROLL_RIGHT` 向左调整 10px：
  - 修改前：`SCROLL_RIGHT = -29`
  - 修改后：`SCROLL_RIGHT = -39`

## 影响范围
- 仅影响使用 `DrawerTemplate.LAYOUT.SCROLL_RIGHT` 的滚动区域右边界（滚动条相对整体向左移动 10px）。
