# MODLOG v1.13.10 — Safe SizeMode addition

- 基线：Bre_v1.13.7_DefaultThemeMinimal_AutoApply_Tabs.zip
- 新增文件：Bre/Core/UI_SizeMode.lua
  - 新增安全接口：Bre.UI:SetSizeMode(mode)
  - 新增切换接口：Bre.UI:ToggleSizeMode()
  - 仅在显式 /run 调用时生效；不会在 Create/Show/Open/Whitelist Apply 等路径自动触发
- 修改文件：Bre/Core/UI.lua
  - 仅增加注释说明 SizeMode 文件由 .toc 加载，不插入任何自动调用
- 修改文件：Bre/Bre.toc
  - 版本号：v1.13.7 → v1.13.10
  - 加载：Core/UI_SizeMode.lua（放在 Core/UI.lua 之前）

## 手动命令
- /run Bre.UI:SetSizeMode("LEGACY")
- /run Bre.UI:SetSizeMode("DEFAULT")
- /run Bre.UI:ToggleSizeMode()

## 自查
- 未对 HostAPI.Open 链路做任何插入调用
- 新增文件仅注册函数，不做 SetSize
- UI 未创建时调用命令：静默 return（不会报错）
