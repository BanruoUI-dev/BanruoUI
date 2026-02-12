# MODLOG v1.13.3 - ThemeMinimal Drawer wiring + FrameStrata dropdown

## 目标
- ThemeMinimal 抽屉：单列布局，仅保留字段：
  - 高度 / 宽度
  - 框架层级（FrameStrata 下拉：自动/背景/低/中/高/对话框/全屏/全屏对话框/提示层）
  - X 偏移 / Y 偏移
- 默认不改变现有 UI 路由：仅提供可选开关（UIWhitelist.theme_minimal_mode），默认 OFF。

## 修改点列表

### 1) ThemeMinimal 抽屉改为可用控件并接入 Refresh/Wire
- 文件：`Bre/Core/DrawerSpec_ThemeMinimal.lua`
- 修改前：6 个 EditBox（含“框架层级数字输入”字段）仅做占位，不可用。
- 修改后：
  - 高度/宽度：NumericBox + Slider（复用 Attribute 控件命名：hNum/hSlider, wNum/wSlider）
  - 框架层级：Dropdown（复用 Position 控件命名：levelDD；仅显示下拉，不再提供数字输入）
  - X/Y：NumericBox + Slider（复用 Position 命名：xNum/xSlider, yNum/ySlider）
  - Refresh：调用 `DrawerTemplate:_RefreshAttributes/_RefreshPosition`
  - WireEvents：调用 `DrawerTemplate:_WireAttributeEvents/_WirePositionEvents`

### 2) DrawerTemplate 支持 Spec 级 Wiring（不影响默认行为）
- 文件：`Bre/Core/DrawerTemplate.lua`
- 修改前：仅对内置/已知 drawerId 做 wiring；Spec:WireEvents 不会被调用。
- 修改后：在 `DT:WireEvents` 末尾统一调用 `DT:CallSpecWireEvents(drawer, nodeId)`
  - 若 Spec 未实现 WireEvents，则无任何影响。

### 3) UI 注册 ThemeMinimal 抽屉，并提供可选路由开关
- 文件：`Bre/Core/UI.lua`
- 修改前：Element Pane 仅注册 ProgressMat/Model/StopMotion/CustomMat。
- 修改后：
  - 注册 ThemeMinimal drawer（但默认路由仍不使用）
  - RefreshRight：当 `Bre.UIWhitelist.state.enabled && theme_minimal_mode==true` 时，Element Pane 统一路由到 ThemeMinimal
  - RefreshRight：新增 ThemeMinimal 抽屉刷新调用（与 Model/StopMotion 同级）

### 4) UIWhitelist 新增 ThemeMinimal 模式开关（默认 OFF）
- 文件：`Bre/Core/UIWhitelist.lua`
- 新增：`state.theme_minimal_mode` + `SetThemeMinimalMode(on)`

## 风险与约束
- ThemeMinimal 复用现有 Attribute/Position 的提交白名单：
  - Slider：MouseUp 提交
  - NumericBox：EnterPressed / EditFocusLost 提交
  - Dropdown：Click 立即提交
- 默认 OFF，不改变现有用户路径。
