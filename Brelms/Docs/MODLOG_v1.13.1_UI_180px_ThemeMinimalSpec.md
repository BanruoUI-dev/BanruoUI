# MODLOG - v1.13.1 (基于 v1.13)

目标：
- 统一 UI 控件标准长度：260px → 180px（输入框/滑条/下拉等标准控件宽度）
- 行距与文本-控件间距：不新增/不覆盖自定义规则，沿用当前模板默认（视为暴雪默认风格）
- 新增一个 theme 专用抽屉模板（仅作为模板资产存在，不启用、不接线）

---

## 1) 控件标准长度统一为 180px

### 修改了什么
- DrawerTemplate 的标准控件宽度常量由 150 调整为 180。

### 修改前
- `DT.LAYOUT.CONTROL_WIDTH = 150`

### 修改后
- `DT.LAYOUT.CONTROL_WIDTH = 180`

文件：
- `Bre/Core/DrawerTemplate.lua`

---

## 2) StopMotion 抽屉显式宽度对齐 180px

### 修改了什么
- StopMotion 的路径输入框宽度从 260 调整为 180。
- StopMotion 的模式下拉宽度从 160 调整为 180。

文件：
- `Bre/Core/DrawerSpec_StopMotion.lua`

---

## 3) 新增 ThemeMinimal 抽屉 Spec（模板资产，不启用）

### 新增了什么
- 新增 `Bre/Core/DrawerSpec_ThemeMinimal.lua`
  - 单列布局
  - 仅包含 6 个字段：Height / Width / Strata / Level / XOffset / YOffset
  - 不接线、不写 DB、不调用 Move，仅作为未来 Bre_theme 的模板基础

### 引用关系
- 已在 `Bre/Bre.toc` 中加入加载顺序，但当前没有任何 Profile/注册逻辑引用该抽屉，因此不会影响现有行为。

---

## 自查 ✅
- 插件可正常加载：新增文件已被 toc 引入。
- 现有 UI/抽屉行为不改逻辑：仅标准宽度常量变更 + StopMotion 显式宽度对齐。
- 新增 ThemeMinimal Spec 未被引用：不会改变当前抽屉注册与显示。
