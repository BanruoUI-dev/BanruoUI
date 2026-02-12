# MODLOG v1.13.27

## Goal
- Policy B："New" 与 "Import" **同进退**（永远同显隐）。
- "New" 与 "Import" / "Close" 一样走 UIWhitelist 流程（不再是特殊按钮）。
- Header 点击热区（HitRectInsets）按**真实显示状态**计算，避免遮挡按钮。

## Changes
### 1) UIWhitelist 默认 allow 补齐
- Before: `top_buttons.allow = { Import = true, Close = true }`（New 缺省）
- After : `top_buttons.allow = { Import = true, New = true, Close = true }`

### 2) UI:ApplyTopButtonsWhitelist（Policy B 绑定）
- Before: 各按钮独立 `SetShown(allow[k] == true)`。
- After :
  - `Import`：按 `allow.Import`。
  - `New`：强制跟随 `Import`（`New = Import`）。
  - `Close`：仍按 `allow.Close` 独立。
  - Whitelist disabled（cfg=nil）时仍保持：三按钮全部 Show。

### 3) UI:UpdateHeaderHitInsets（修复遮挡）
- Before: 左侧只取 `Import`（若 Import 显示），否则才取 `New`。
  - 当 Import + New 同时显示时，会导致 HeaderHit 热区可能覆盖 New。
- After : 左侧取 **所有显示的左按钮**（Import/New）的最右边界（maxRight），再计算 leftInset。

## Manual test
- Whitelist enabled：
  - allow.Import=false, allow.New=true -> Import/New 均隐藏（绑定生效）。
  - allow.Import=true, allow.New=false -> Import/New 均显示（绑定生效）。
  - allow.Close=false -> Close 可单独隐藏。
- Whitelist disabled：Import/New/Close 全部恢复显示。
- Import/New 同时显示时：New 可点击，Header 空白区仍可拖动。
