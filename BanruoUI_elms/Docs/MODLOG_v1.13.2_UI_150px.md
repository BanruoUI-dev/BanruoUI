# MODLOG v1.13.2 · UI 标准宽度 150px（视觉≈180px）

## 修改点（概览）
- 将「标准控件宽度」从 **180（逻辑）→ 150（逻辑）**。
  - 目的：在当前 UI Scale ≈ 0.818 的环境下，视觉宽度约等于 180px。
- 同步更新 StopMotion 与 ThemeMinimal 两个 DrawerSpec 中写死的 180 宽度为 150。
- 同步更新 Group 抽屉（UI.lua）里本地使用的 CW（此前为 180）为 150。

## 修改前 / 修改后
- 标准控件宽度
  - 修改前：180
  - 修改后：150

## 文件变更明细
### 1) Bre/Core/DrawerTemplate.lua
- 修改内容：`LAYOUT.CONTROL_WIDTH`
- 修改前：`CONTROL_WIDTH = 180`
- 修改后：`CONTROL_WIDTH = 150`

### 2) Bre/Core/DrawerSpec_StopMotion.lua
- 修改内容：控件宽度
- 修改前：`width = 180`
- 修改后：`width = 150`

### 3) Bre/Core/DrawerSpec_ThemeMinimal.lua
- 修改内容：控件宽度
- 修改前：`width = 180`
- 修改后：`width = 150`

### 4) Bre/Core/UI.lua
- 修改内容：Group 抽屉本地 `CW`
- 修改前：`local CW = 180`
- 修改后：`local CW = 150`

### 5) Bre/Bre.toc
- 修改内容：版本号
- 修改前：`v1.13.1`
- 修改后：`v1.13.2`
