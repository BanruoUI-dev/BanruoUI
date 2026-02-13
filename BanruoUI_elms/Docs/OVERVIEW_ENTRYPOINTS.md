# Bre 总览入口说明（Overview & Entry Points · 文件映射）
基线包：Bre_v2_15_55.zip  
⚠️ 注意：`Bre/Bre.toc` 中写的 Version 是 **v2.15.25**（与你 zip 名 v2.15.55 不一致，建议统一）

## 0. 加载顺序真源
- **`Bre/Bre.toc`**：唯一加载顺序真源（Core→Modules→UI→Events→Core入口）

当前 TOC 关键尾部链路（决定“能不能 /bres 打开”）：
- `Core/UI.lua`
- `Core/Events.lua`
- `Core/Core.lua`
- `Bindings.xml`

---

## 1. 运行入口（从哪“进”）
### 1.1 Slash 命令入口（你验收最常用）
- **`Bre/Core/Core.lua`**
  - `/bres`：UI Toggle
  - `/bres mod <ModuleId> on|off`：模块断链/接线验收入口
  - `/bres verify`：隔离自检（若 Verify 实现存在）
  - `/bres center`、`/bres first`：对齐动作（走 Actions）

### 1.2 ADDON_LOADED 入口（加载即初始化）
- **`Bre/Core/Core.lua`**
  - 初始化 SavedVariables：`BreSaved.modules`
  - `Bre.Linker:Bootstrap()`（接线：Registry → Gate）
  - DB 初始化：`Gate:Get("DB"):EnsureSaved()`（或兼容 InitSaved）

---

## 2. L0（单核心）真实分布（不可拔）
> 这些是“系统生命 + 总线 + 数据”的最小集合。

- **Registry**：`Bre/Core/Registry.lua`
- **Gate**：`Bre/Core/Gate.lua`
- **DB**：`Bre/Core/DB.lua`
- **Events**：`Bre/Core/Events.lua`
- **Locale（多语言入口）**
  - `Bre/Core/Locale.lua`
  - `Bre/Locales/enUS.lua`
  - `Bre/Locales/zhCN.lua`
- **Contract / Schema**
  - `Bre/Core/Contract_BanruoUI.lua`
  - `Bre/Core/Schema_Element.lua`
  - `Bre/Core/API_Data.lua`
- **Const / PreviewTypes**
  - `Bre/Core/Const.lua`
  - `Bre/Core/PreviewTypes.lua`

---

## 3. L1（底盘/连接器）真实分布（可断链服务）
> 这些是“连接器能力”，L2 必须经 Gate 使用它们。

- **UIBindings**：`Bre/Core/UI_Bindings.lua`
- **TreeIndex**：`Bre/Core/TreeIndex.lua`
- **SelectionService**：`Bre/Core/SelectionService.lua`
- **ViewService（导出名为 View）**：`Bre/Core/ViewService.lua`
- **Move**：`Bre/Core/Move.lua`
- **PropertyService**：`Bre/Core/PropertyService.lua`（当前骨架：skeleton 标注）
- **EditGuard**：`Bre/Core/EditGuard.lua`
- **Render**：`Bre/Core/Render.lua`
- **IO**：`Bre/Core/IO.lua`
- **Actions**：`Bre/Core/Actions.lua`
- **TargetResolver / TargetService**
  - `Bre/Core/TargetResolver.lua`（导出名 ResolveTargetFrame）
  - `Bre/Core/TargetService.lua`
- **AnchorRetry**：`Bre/Core/AnchorRetry.lua`
- **LoadState**：`Bre/Core/LoadState.lua`
- **Skin**：`Bre/Core/Skin.lua` + `Bre/Skins/Default.lua`
- **TreePanel_Resize（在 Registry 里声明为 L2 导出，但功能属性更像 UI 辅助）**
  - `Bre/Core/TreePanel_Resize.lua`

---

## 4. 抽屉（Drawer）入口：模板/控件/Spec 真源
- 模板：`Bre/Core/DrawerTemplate.lua`
- 控件：`Bre/Core/DrawerControls.lua`
- Spec：
  - `Bre/Core/DrawerSpec_CustomMat.lua`
  - `Bre/Core/DrawerSpec_ProgressMat.lua`

---

## 5. Linker / ModuleManager：模块启停与接线
- **Linker（接线：把 Registry 的 exports 注入 Gate）**：`Bre/Core/Linker.lua`
- **ModuleManager（/bres mod 的实现主体）**：`Bre/Core/ModuleManager.lua`

---

## 6. L2（功能模块）现状：哪些“真正运行”
TOC 已加载、会运行的 L2：
- `Bre/Modules/CustomMat/CustomMat.lua`
- `Bre/Modules/ProgressMat/ProgressMat.lua`
- `Bre/Modules/ProgressData/ProgressData.lua`

ZIP 内还有库存模块，但 **未写入 TOC，因此当前不运行**（只是拆件储备）。

---

## 7. UI 页面层（展示内容）
- Pages：`Bre/UI/Pages/*.lua`
  - `Home.lua / Theme.lua / Debug.lua / Import.lua / About.lua / ElementSwitch.lua`
- Widgets：`Bre/UI/Widgets/Header.lua`、`Bre/UI/Widgets/Nav.lua`

---

## 8. 你只需要记住的 6 个“主入口文件”
1) `Bre/Bre.toc`（加载顺序真源）  
2) `Bre/Core/Core.lua`（/bres + ADDON_LOADED 入口）  
3) `Bre/Core/Registry.lua`（模块声明）  
4) `Bre/Core/Gate.lua`（跨模块总线）  
5) `Bre/Core/Linker.lua`（接线：exports → Gate）  
6) `Bre/Core/UI.lua`（面板壳：Tree + Drawer + 交互路由）
