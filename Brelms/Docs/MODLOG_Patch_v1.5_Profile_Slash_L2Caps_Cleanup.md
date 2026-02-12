# MODLOG - Patch (v1.5 对齐)

## 1) L2 模块能力声明（v1.5 新增铁律）
- 目的：支持 Bre_theme / Brelms 分包、Profile 裁剪、运行链与作者入口解耦
- 修改前：L2 模块未声明 `runtime_required / authoring_required`
- 修改后：以下 L2 模块在“模块自身定义处”新增能力字段：
  - `Bre/Modules/CustomMat/CustomMat.lua`（runtime_required=true, authoring_required=true）
  - `Bre/Modules/ProgressMat/ProgressMat.lua`（runtime_required=true, authoring_required=true）
  - `Bre/Modules/ProgressData/ProgressData.lua`（runtime_required=true, authoring_required=false）
  - `Bre/Core/UI.lua`（runtime_required=false, authoring_required=true）
  - `Bre/Core/TreePanel_Resize.lua`（runtime_required=false, authoring_required=true）
  - `Bre/Core/BlankDrawerSpec.lua`（runtime_required=false, authoring_required=false）
  - `Bre/Core/PropPosSpec.lua`（runtime_required=false, authoring_required=false）

## 2) Profile 默认策略与分包文档一致
- 修改前：仅 `THEME/FULL` 两档；`addonName != Brelms` 默认 THEME
- 修改后：三档 `DEV/THEME/FULL`
  - 覆盖优先：`_G.BRE_BUILD_PROFILE` in {DEV, THEME, FULL}
  - 无覆盖：`addonName == "Brelms"` => FULL；否则 => DEV
  - Authoring UI：DEV/FULL 允许；THEME 禁止
  - Slash：DEV=/bres；THEME=/brt；FULL=/bre

## 3) Slash 命令对齐（/bres）
- 修改前：固定 `/brs`（且文案/usage 硬编码）
- 修改后：`Bre/Core/Core.lua` 使用 `Profile:GetSlashCommand()` 动态注册
  - usage/help 文案同步使用当前 slash

## 4) 可疑/废料清理
- 删除：
  - `Bre/Core/UI.lua.tmp`
  - `Bre/Modules/ProgressMat/ProgressMat.lua.v2_15_backup`
  - `Bre/CHANGELOG*.txt`（发行包冗余）
  - `Bre/Docs/archive/`（归档文档冗余）
- 保留：`Bre/Docs/` 根目录（当前有效工程文档）

