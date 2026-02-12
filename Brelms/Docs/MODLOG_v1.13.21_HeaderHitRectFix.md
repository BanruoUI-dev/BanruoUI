# MODLOG v1.13.21

## Fix
- Header 空白区点击取消选择：修复点击无反应问题。

## Root cause
- HeaderHit 点击层在 TopBar 下层级，且 TopBar 自身吃鼠标，导致点击事件被拦截。

## Change
- HeaderHit 改为 Button 且置于 TopBar 上方。
- 通过 SetHitRectInsets 排除左侧按钮区与右上角关闭按钮区，避免抢点击。
- 在 TopButtons 白名单应用后、以及 HeaderHit 重新锚定后自动重算 HitRect。
