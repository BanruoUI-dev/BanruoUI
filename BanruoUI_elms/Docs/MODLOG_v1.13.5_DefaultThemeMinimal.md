Bre v1.13.5 · 修改日志

目标
- 仅修改一个位置：让 UIWhitelist 默认进入 ThemeMinimal 精简模式。
- RL 后回到精简模式可接受（按用户要求，不做持久化）。

修改点
1) Bre/Core/UIWhitelist.lua
- 修改前：W.state 默认全部为 false（不启用白名单、不启用精简抽屉路由）。
- 修改后：W.state 默认开启（enabled / top_buttons / drawers / theme_minimal_mode 均为 true）。

影响范围
- 仅影响默认启动时的 UIWhitelist 行为。
- 不改任何运行链、不改 DB、不改抽屉实现。
