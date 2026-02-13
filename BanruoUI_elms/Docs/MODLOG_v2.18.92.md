# MODLOG v2.18.92

## 改动摘要
- 修复【3D 模型】FileID 预设下拉菜单导致插件加载报错：`DrawerTemplate.lua: unexpected symbol near ')'`。

## 修改点
### 1) 下拉菜单初始化缺失 `end`
- 文件：`Bre/Core/DrawerTemplate.lua`
- 区域：ModelValue 预设下拉（`UIDropDownMenu_Initialize(dropdown, ...)`）

**修改前**
- `if mode == "unit" then ... else ...` 分支缺少收尾 `end`，函数闭包直接以 `end)` 结束，解析遇到 `)` 报错。

**修改后**
- 补齐 `end` 关闭 `if` 分支，再正常 `end)` 关闭 Initialize 回调。
