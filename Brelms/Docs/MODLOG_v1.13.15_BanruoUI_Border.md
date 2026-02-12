MODLOG v1.13.15 — BanruoUI Border on Bre Main Frame

基线：Bre_v1.13.14_NewAlwaysOn_AutoCompact.zip

改动目标
- 仅将 Bre 主面板外框（背景+边框）替换为 BanruoUI 同款 DialogBox 边框。
- 其它一律不动（布局/尺寸/按钮/内面板/分隔线/黄线/逻辑均不改）。

修改文件
1) Bre/Core/UI.lua
- 修改函数：applyMainBackdrop(frame)

修改前
- 主面板外框：Bre 自身的 Panel 边框（Skin:ApplyPanelBackdrop / applyPanelBackdrop）。

修改后
- 主面板外框：BanruoUI 同款 DialogBox 外框：
  - bgFile  = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
  - edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border"
  - tile = true, tileSize = 32
  - edgeSize = 32
  - insets = { left = 11, right = 12, top = 12, bottom = 11 }
  - SetBackdropColor(0, 0, 0, 0.92)

自查
- 仅修改主面板外框函数 applyMainBackdrop；未改动任何子面板边框/按钮/布局逻辑。OK
- 未新增任何自动调用链路；不影响 HostAPI.Open/Show/Toggle 的逻辑结构。OK
