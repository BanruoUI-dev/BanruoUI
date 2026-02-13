# v1.13.34 · NewOverlay 右列恢复显示（ThemeMinimal ↔ Full）

## 目标
- ThemeMinimal：右列（预设模板区：标题+滚动条+内容）UI层面隐藏且不占位置
- Full/Dev：右列必须恢复显示（不能“隐藏一次后永久隐藏”）

## 修改点
- 将右列显隐逻辑从 BuildNewOverlay()（创建阶段）移动到可重复执行的 UI:_ApplyNewOverlayMode()
- 在 ApplyUIWhitelist() 与 OpenNewOverlay() 中调用 UI:_ApplyNewOverlayMode()，确保切换 ThemeMinimal 后即时生效
- BuildNewOverlay() 仅缓存 rightBlock/scroll 引用，不再一次性 Hide

