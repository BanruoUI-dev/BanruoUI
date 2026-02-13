# MODLOG v1.13.7

## 修改目标
- 修复：Theme 白名单已启用但右侧 Tab（输入条件/输出动作/自定义函数）仍会被重新显示的问题。

## 修改点
### 1) Bre/Core/UI.lua
- **修改前**：`UI:_ApplyRightTabLayout()` 会无条件 `Show()` 所有右侧 Tab（Element/Conditions/Actions/LoadIO/CustomFn），导致白名单隐藏被覆盖。
- **修改后**：`UI:_ApplyRightTabLayout()` 若检测到 `Bre.UIWhitelist` 已启用且启用 drawers 白名单，则按 `W.config.drawers.allow` 决定每个 Tab 的 `SetShown()`；否则保持原逻辑显示全部。

## 影响范围
- 仅影响右侧 Tab 的显示/隐藏逻辑。
- 不改变运行链、不改变抽屉实现。
