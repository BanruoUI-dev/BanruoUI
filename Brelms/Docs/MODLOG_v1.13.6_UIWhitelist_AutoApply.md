# v1.13.6 · UIWhitelist Auto Apply

## 修改点
1) UI 主面板创建完成后，自动调用 UIWhitelist Apply（无需手动 /run）。
2) 默认 ThemeMinimal（enabled/top_buttons/drawers/theme_minimal_mode = true）现在会在首次打开面板时立即生效。

## 修改文件
- Bre/Core/UI.lua
  - 在 `self.frame = f` 之后调用 `self:ApplyUIWhitelist()`
- Bre/Bre.toc
  - Version 更新为 v1.13.6
