# v1.13.32 · ThemeMinimal 隐藏右列预设区块（修复条件）

## 修改点
- 修复：新建抽屉右列「预设模板（组）」在 ThemeMinimal 模式下未隐藏的问题。
- 范围：仅 UI 层隐藏（不占位置），包含：标题 + ScrollFrame + 滚动条。

## 修改前
- 使用 `Bre.Profile:IsTheme()` 作为判断条件。
- 实际运行时 Profile 多为 DEV/FULL，条件不触发 → 右列仍显示。

## 修改后
- 改为使用 `Bre.UIWhitelist.state.theme_minimal_mode`（并要求 `state.enabled`）作为唯一判断条件。
- ThemeMinimal 为 true 时：右列整块隐藏，并额外隐藏 ScrollBar 句柄作为防御。

## 文件
- BanruoUI_elms/Core/UI.lua
- BanruoUI_elms/BanruoUI_elms.toc
