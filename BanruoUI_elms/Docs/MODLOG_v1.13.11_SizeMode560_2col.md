# MODLOG v1.13.11 — SizeMode DEFAULT 560×560 + 两列固定

基线：v1.13.10 (Bre_v1.13.10_SizeModeSafe_v2.zip)

## 修改点
1) Bre/Core/UI_SizeMode.lua
- DEFAULT：725×570 → 560×560
- DEFAULT：RightPane 跟随宽度固定 210（best-effort）

2) Bre/Core/UI.lua
- 新增 UI:OnSizeModeApplied(mode)，仅由 SetSizeMode 显式触发
- DEFAULT：Body 横向铺满；Tree=350；Right=210
- 列间增加分隔线（视觉线），不额外占用列宽
- LEGACY：恢复原布局（保持旧间距行为）

3) Bre/Bre.toc
- Version：v1.13.10 → v1.13.11

## 自查
- Create/Show/Open 流程中无任何 SetSizeMode 自动调用
- 显式调用 Bre.UI:SetSizeMode("DEFAULT") 后布局为 560×560，Tree=350，Right=210
