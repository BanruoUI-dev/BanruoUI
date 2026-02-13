# Bre v2.18.22 - 输出动作抽屉：新增按钮修复

## 修改点 1：新增按钮无响应（OnClick 作用域错误）
- 修改了什么：修复“新增”按钮点击无反应的问题。
- 修改前：OnClick 回调里使用 `self.frame` 取 UI.frame，但此处 `self` 实际是按钮本身，导致 frame 为 nil，直接 return。
- 修改后：OnClick 回调改为使用 `UI.frame` 获取当前 UI 实例的 frame，从而正确拿到选中节点并插入动作条目。

### 位置
- 文件：`Bre/Core/UI.lua`
- 区域：`UI:BuildActionsPane(p)` 内 `btnAdd:SetScript("OnClick", ...)`
