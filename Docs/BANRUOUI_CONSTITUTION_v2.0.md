# BanruoUI 系统总宪章（完整版 · v2.0）

（对外不可争辩 · 对内不可违背）

内部命名裁决：

- `Bre` = `BanruoUI_elms` 的内部缩写名。
- `Bre` 仅为引擎代号，不代表独立发行物。

## 第一部分：BanruoUI 宪法（语义层 / 规则层 / 调度层）

### A1 系统定位原则

`BanruoUI` = 语义控制器。

负责：

- 定义规则
- 决定切换目标集合
- 调用 `HostAPI` 完成闭环

永远不负责：

- Tree 维护
- DB 存储
- 渲染重建
- 引擎扫描实现

一句话裁决：

`BanruoUI` 管“应该切什么”，不管“怎么切”。

### A2 世界边界原则（Root 是主题单位）

主题单位 = Root。

命名强制：

- `BANRUOUI[XXX]`

主题切换 = Root 互斥。

禁止：

- 拼主题
- 子树级主题
- Root 共享节点

### A3 elementId 语义原则

`elementId` 是 `BanruoUI` 的语义标签集合。

引擎无需理解语义意义。

`BanruoUI` 必须能稳定映射到：

```text
Root
 └─ Elements
    └─ elementGroup
       └─ variants
```

### A4 切换只改状态原则

`BanruoUI` 只能改：

- `load.never`

禁止：

- 删除节点
- 重建结构
- 改父子关系
- 修复子树

### A5 作用域铁律

主题切换：只写 Root 集合。  
元素切换：只写 `elementGroup` 的直系 children。

禁止扩大作用域。

### A6 刷新闭环原则

写 `never` 后必须：

- `Bre.HostAPI.Rebuild(目标集合)`

未 `Rebuild` = 切换未完成。

### A7 越权禁止原则

`BanruoUI` 只认：

- `_G.Bre.HostAPI`

禁止：

- 访问 TreeIndex
- 访问 DB
- 访问 Move
- 访问 Gate
- 访问 Registry

## 第二部分：BanruoUI_elms（Bre）宪法

### B1 单引擎原则

`Bre` 是唯一执行引擎。

负责：

- Tree
- DB
- 状态解释
- Scan/Load/Rebuild
- 渲染生效

不负责：

- 主题语义
- elementId 规则制定

### B2 Core（L0）单核心原则

Core 负责：

- 生命周期
- Registry
- Gate
- DB
- Events
- HostAPI

Core 不实现 L2 业务。

### B3 L1 底盘原则

L1 提供能力，不承载业务。

典型模块：

- TreeIndex
- Move
- PropertyService
- SelectionService
- EditGuard
- ViewService
- Condition

L2 必须通过 Gate 调用 L1。

### B4 L2 可拔插原则

所有功能为 L2 模块。

禁止：

- 直写 DB
- 旁路访问 Move
- 第二份状态

### B5 Registry 原则

模块必须注册。  
Core 只认 `ModuleId`。

### B6 Gate 原则

跨模块调用必须通过 Gate。  
禁止直连。

### B7 真断链原则

断链必须：

- 返回 stub/no-op
- 不报错
- 不旁路
- 不影响其它模块

### B8 禁止 fallback

模块 off 后：

- 不得偷偷直连
- 不得绕 Gate
- 不得写 DB

### B9 HostAPI 合同稳定原则

唯一对外入口：

- `_G.Bre.HostAPI`

能力族必须覆盖语义：

- Ready
- Import
- Query/Index
- Rebuild
- Open/Close

`HostAPI` 是合同，不是工具箱。

### B10 编辑链路安全原则

数据变更必须：

- UI -> Gate -> L1 -> DB

白名单提交窗口：

- MouseUp
- EnterPressed
- EditFocusLost
- ClickConfirm

禁止：

- Refresh 触发提交
- UI 直写 DB

### B11 Drawer 模板体系原则

Drawer 仅两态：

- Empty Drawer
- Functional Drawer

Functional Drawer 必须：

- 有独立 Refresh
- UI 状态由 Refresh 决定
- RL 可恢复
- 不直写 DB
- 只在白名单提交

## 第三部分：三形态 Policy 宪法

### C1 三形态定义（语义铁律）

`FULL`

- 运行链 + 作者入口 全开
- 完整编辑器

`DEV`

- `FULL` 的超集
- 允许额外调试/诊断能力
- 只增不减

`THEME`

- 运行链完整保留
- 作者入口尽可能隐藏
- 渲染结果必须与 `FULL` 等价

铁律：

- `DEV ⊇ FULL`
- `THEME ⊂ FULL`（UI 裁剪）
- `THEME` 运行效果 `≡ FULL`

### C2 Profile 与 Policy 分离原则

Profile 只负责：

- `mode = THEME / DEV / FULL`

Policy 负责：

- UI 裁剪策略
- 尺寸策略
- 模块断链策略
- Drawer 裁剪策略

禁止：

- 各模块自行判断 mode
- 白名单散落硬编码
- Drawer 自己判断模式

Policy 是唯一真相来源。

### C3 裁剪优先级原则

裁剪手段按安全等级排序：

1. UI 隐藏（首选）
2. 模块断链 stub（次选）
3. 不注册模块（危险，慎用）

`THEME` 默认只允许使用 `1`；必要时使用 `2`；避免使用 `3`。

### C4 L2 能力声明驱动裁剪原则

每个 L2 模块必须声明：

- `runtime_required`
- `authoring_required`

`THEME` 裁剪规则：

| runtime_required | authoring_required | THEME 行为 |
|---|---|---|
| true | true | 保留运行链，隐藏 UI |
| true | false | 保留运行链 |
| false | true | 可断链或隐藏 |
| false | false | 可移除 |

禁止人工判断模块能力。  
模块自身声明是唯一真相。

### C5 新模式扩展原则

新增模式时：

- 只修改 Policy
- 不修改模块实现
- 不修改 L1/L2 逻辑

否则视为架构失败。

## 第四部分：主题包宪法

### D1 命名铁律

- `BANRUOUI[XXX]`
- 身份 = Root 名

禁止模糊映射。

### D2 注册铁律

主题包必须：

- `RequiredDeps: BanruoUI`
- `RegisterTheme(...)`
- `RegisterBRE(...)`
- 只提供数据

### D3 Root 结构铁律

Root 下第一层必须：

- Core
- Elements
- Decor
- Layout

Elements 下：

```text
elementGroup
 └─ variants
```

不合规主题包 -> 非法主题。

## 第五部分：多语言（Lang）条款

### L1 多语言单一真源原则

`BanruoUI` 的语言文本只归 `BanruoUI` 自己管理（`BanruoUI/Core/Locale` + `Locales/*`）。  
`BanruoUI_elms（Bre）` 的语言文本只归 `Bre` 自己管理（`BanruoUI_elms/Core/Locale` + `Locales/*`）。

两者不得共享同一套全局语言表，不得互相读写对方的 Locale 数据。

一句话裁决：  
各管各的文案，各守各的边界。

### L2 取词唯一入口原则

UI/Drawer/L2 模块不得写死显示字符串（除非极少数 debug-only 且明确标注）。

所有可见文本必须通过 Lang 入口获取（例如 `L("key")` / `Lang:Get("key")`，具体函数名不限定，但必须是统一入口）。

禁止：

- 在 UI 里直接写 `"Height"` / `"宽度"` / `"导入"` 等硬编码显示文本

### L3 Key 稳定与命名空间原则

Key 必须稳定不随版本改名（除非提供兼容期映射）。

Key 必须带命名空间，避免冲突：

- BanruoUI：`BRUI_*`
- Bre：`BRE_*`
- Drawer：`BRE_DRAWER_*`
- 通用：`BRE_COMMON_*`

一句话裁决：  
Key 是 API，不是注释。

### L4 禁止隐式 fallback 原则

不允许“缺 key 就随便显示英文/中文”的隐式 fallback 乱跳。

允许且仅允许：

- 明确的默认语言回退（例如缺失时回退 `enUS`）
- 明确的缺失标记（例如 `[[MISSING:KEY]]`）用于开发阶段定位

禁止：

- UI 自己写 `or "xxx"` 作为兜底文案（会造成“半本地化”）

### L5 模块注册与加载时机原则

Lang 表必须在 Core 初始化阶段完成装载（可在 Enable 前后，但必须保证 UI 创建前可用）。

L2 模块只能“声明自己需要哪些 key”，不得在运行时动态注入语言表（避免散落真相）。

### L6 主题包语言边界原则（数据层不承载语言逻辑）

主题包（`BANRUOUI[XXX]`）只提供数据与 Root，不得提供语言系统，不得覆盖 `BanruoUI/Bre` 的 Lang。

若主题包需要展示名称：只允许提供“主题显示名字段”，由 `BanruoUI` 决定如何本地化展示（可选）。

## 终审条款

- 旁路 = Bug
- 写 never 不 Rebuild = Bug
- 刷新触发提交 = Bug
- HostAPI 漂移 = 架构缺陷
- DEV 少于 FULL = 架构错误
- THEME 运行效果 ≠ FULL = 架构错误
- 能力声明缺失 = 违规模块

违反宪章：不讨论，只修。

## 一句话拍板版（v2.0）

BanruoUI 决策语义；  
Bre 执行结构；  
Profile 只给模式；  
Policy 给裁剪真相；  
Root 是世界边界；  
never 是唯一切换手段；  
HostAPI 是唯一合同；  
Gate 是唯一通道；  
运行与作者入口分离；  
THEME 不破坏运行链。

## 附录 A

尺寸切换命令：

- THEME（560x560）
- DEV
- FULL

```lua
/run Bre.Profile:SetMode("THEME")
/run Bre.Profile:SetMode("DEV")
/run Bre.Profile:SetMode("FULL")
```

切换语言命令：

【BanruoUI】

```lua
/br lang
/br lang zhCN
/br lang enUS
/br lang auto
```

【BrE】

```lua
/bre lang
/bre lang zhCN
/bre lang enUS
/bre lang auto
```

仓库与视频：

- GitHub 仓库：https://github.com/BanruoUI-dev/BanruoUI
- GitHub 下载：https://github.com/BanruoUI-dev/BanruoUI.git
- B 站：https://www.bilibili.com/video/BV1pcc7zzE5L/
- YouTube：https://www.youtube.com/watch?v=4BI7JlxN_UQ
