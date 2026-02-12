# Bre 架构地图（1页版）+ Gate Key 索引
基线包：Bre_v2_15_55.zip

## A) 1页架构地图（阅读路径 = 跑起来的路径）

### A1. 启动链（加载 → 接线 → 可用）
1. **TOC**：`Bre/Bre.toc`  
2. **L0/L1/L2 声明**：`Core/Registry.lua` 预声明模块 spec  
3. **Gate 就绪**：`Core/Gate.lua`  
4. **接线 Bootstrap**：`Core/Core.lua` → `Bre.Linker:Bootstrap()`  
   - 内部：`Linker:InitStubs()` → `Linker:EnableLayer(L0→L1→L2)`  
5. **DB 确保 Saved**：`Core/Core.lua` → `Gate:Get("DB"):EnsureSaved()`  
6. **/bres 可用**：`Core/Core.lua`（UI Toggle / mod on|off / verify）

---

### A2. UI Toggle（/bres 的最短链）
- `/bres` → `Core/Core.lua` → `Gate:Get("UI"):Toggle()`  
- UI 的“壳构建/刷新”核心在：`Core/UI.lua`

---

### A3. Tree 点击（选中 → 右侧抽屉刷新）
- Tree 点击行 → `SelectionService:OnTreeClick(...)`（`Core/SelectionService.lua`）  
- UI 刷右侧 → `UI:RefreshRight()`（`Core/UI.lua`）  
- 预览/显隐：走 `Gate:Get("View")`（`Core/ViewService.lua`）

---

### A4. 显隐（眼睛）与预览（previewBox）
- 裁决：`ViewService`（导出 Key = `"View"`）  
- 落点：`Move:SetHidden(...)`（`Core/Move.lua`）  
- 预览：`View:GetNodePreview(nodeId)`（Provider 机制可注册/注销）

---

### A5. 提交链（属性 → 唯一提交口）
- 任何属性写入收口：`PropertyService`（`Core/PropertyService.lua`）  
- 当前包里 `PropertyService` 为骨架位（skeleton 标注）：结构正确，commit 策略后续点亮。

---

### A6. 位置/结构唯一执行者（Move）
- 拖拽/微调/对齐/删除/复制/改父子关系：最终都应落到 `Move`。

---

## B) Gate Key 索引表（插线地图）
> Key 来自 `Core/Registry.lua` 的 exports；接线发生在 `Core/Linker.lua`。

### B1. 核心 Key（L0）
- **"Const"** → `Core/Const.lua`
- **"Contract"** → `Core/Contract_BanruoUI.lua`
- **"DB"** → `Core/DB.lua`
- **"Events"** → `Core/Events.lua`
- **"Locale"** → `Core/Locale.lua`（+ `Locales/*.lua`）

### B2. 连接器 Key（L1）
- **"API_Data"** → `Core/API_Data.lua`
- **"TreeIndex"** → `Core/TreeIndex.lua`
- **"LoadState"** → `Core/LoadState.lua`
- **"UIBindings"** → `Core/UI_Bindings.lua`
- **"Skin"** → `Core/Skin.lua`（配 `Skins/Default.lua`）
- **"Render"** → `Core/Render.lua`
- **"Move"** → `Core/Move.lua`
- **"PropertyService"** → `Core/PropertyService.lua`
- **"SelectionService"** → `Core/SelectionService.lua`
- **"EditGuard"** → `Core/EditGuard.lua`
- **"DevCheck"** →（Registry 声明存在，用于开发自检/开关）
- **"ResolveTargetFrame"** → `Core/TargetResolver.lua`
- **"AnchorRetry"** → `Core/AnchorRetry.lua`
- **"View"** → `Core/ViewService.lua`
- **"IO"** → `Core/IO.lua`

### B3. 功能模块 Key（L2）
- **"CustomMat"** → `Modules/CustomMat/CustomMat.lua`
- **"ProgressMat"** → `Modules/ProgressMat/ProgressMat.lua`
- **"ProgressData"** → `Modules/ProgressData/ProgressData.lua`
- **"UI"** → `Core/UI.lua`
- **"TreePanel_Resize"** → `Core/TreePanel_Resize.lua`

---

## C) 新增模块：最稳“接 3 条线”模板
1. `Modules/<X>/<X>.lua`：写模块 iface（对外 API 表）  
2. `Core/Registry.lua`：注册 `<X>`（layer=L2，exports 含 `<X>`）  
3. `Core/Linker.lua`：Bootstrap 后自动注入 Gate；UI/其它模块只用 `Gate:Get("<X>")`（禁止 require 旁路）

断链验收：
- `/bres mod <X> off`：退化为空实现/默认值、无报错  
- `/bres mod <X> on`：恢复正常
