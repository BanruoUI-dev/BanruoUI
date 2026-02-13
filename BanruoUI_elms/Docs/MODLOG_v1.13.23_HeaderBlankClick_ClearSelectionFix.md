# MODLOG v1.13.23 — HeaderBlank Click: ClearSelection Fix

## 修改目标
- 顶部 Header 空白区：单击取消选择（保持拖拽移动功能不变）。

## 问题回溯
- v1.13.22：Header 空白区点击事件调用 SelectionService:Clear() + RefreshAll()，
  但未走 UI:ClearSelection() 的同步与隐藏逻辑，表现为“点击无效果”。

## 修改点
- 文件：Bre/Core/UI.lua
- 修改前：
  - SelectionService:Clear("header")
  - UI:RefreshAll()
- 修改后：
  - UI:ClearSelection()（内部完成：同步选择、隐藏 mover/render、刷新 Tree/Right）

## 预期结果
- Header 空白区：
  - 左键拖拽：移动窗口 ✅
  - 左键单击：取消选择 ✅
- 不做 UI 外点击取消选择（按需求保持不做）。
