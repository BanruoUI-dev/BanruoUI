# 结构健康点（Step8 封存）

本版本目的：在不改变任何运行时行为的前提下，封存“结构健康点”，作为后续演进的基准线。

## 健康点（必须持续保持）
- 1 Core / 1 底盘（L1）/ 多 L2 可拔插
- 所有跨模块调用统一经 Gate（禁止旁路）
- 模块 off 必须是真断链（stub/no-op 可预测）
- UI 刷新必须无副作用（Refresh 与 Commit 分离）
- PropertyService / SelectionService / EditGuard 三保险丝集中治理
- 右侧面板 RefreshRight 结构性进入 EditGuard（Step5）
- Gate:Get 返回 proxy，消灭缓存真实模块表导致的软旁路（Step4）

## 验收基准（回归必测）
- /bres 可打开/关闭
- 切换节点、展开收起、切换右侧 tab：无残留、无报错
- /bres mod <L1> off：系统可用、不旁路
- UI 刷新（SetValue/SetText/SetChecked）不触发提交链

本文件为“终审冻结点”，后续新增能力不得破坏以上条目。
