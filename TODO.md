# RemoteDock TODO

这个文件用于记录 RemoteDock 接下来的开发计划。任务尽量保持小而清晰，并优先选择能明显提升日常可用性的工作。

## 推荐路线

主机管理、双栏 UI 和核心远程动作已经基本成型。下一阶段更值得投入的是“状态可读性”“测试可靠性”和“终端打开链路的可配置性”。

建议顺序：

1. 状态与筛选体验
2. 终端打开策略整理
3. 测试与服务层抽象
4. macOS 原生体验补完

## 下一步：状态与导航体验

- [x] 增加 VS Code Remote 命令支持。
- [x] 为每台主机增加可配置的默认远程目录。
- [x] 为 Tailscale 主机增加本机 `tailscale status` 查看操作。
- [x] 增加复制完整主机信息的操作。
- [x] 支持启动时自动 Ping 一次所有主机。
- [ ] 为每台主机显示 `Last checked` 时间。
- [ ] 为左侧列表增加状态筛选，例如 `All / Online / Offline / Unchecked`。
- [ ] 为错误提示和复制反馈增加更明确的短暂提示样式。

## 第二阶段：终端与连接策略

- [x] 调整 `Open SSH` 文案，明确它会在 Ghostty 中打开并执行 SSH。
- [x] 增加 Ghostty 未安装时的明确错误提示。
- [x] 增加 Automation 权限失败时的提示文案。
- [x] 去掉基于固定 `delay` 的 follow-up 命令注入，避免慢速 SSH 登录时把命令打到本地 shell、密码提示或 host key 提示上。
- [x] 把 SSH 后续动作改成单条远程命令模式，不再依赖 `delay 1.5`。
- [x] 增加“默认终端”打开方式，减少对 Ghostty 的耦合。
- [ ] 为每台主机增加可选的“首选打开方式”，允许在 Ghostty 与默认终端之间切换。
- [ ] 为默认终端路径补充失败提示，明确当前系统没有可处理 `ssh://` 的应用时该怎么处理。

## 第三阶段：架构与测试

- [x] 修正 `Ping All` 的进行中状态判断，避免首个主机返回后按钮重新可点，导致重复并发检测。
- [ ] 把纯 Swift 逻辑抽成 `RemoteDockCore` Swift Package。
- [ ] 为 SSH 命令生成增加单元测试。
- [ ] 为 JSON 配置读写增加单元测试。
- [ ] 为 Tailscale 状态读取增加可替换执行层，便于测试、路径探测和错误注入。
- [ ] 为 Ping 状态更新逻辑增加可测试封装。
- [ ] 梳理错误类型，避免服务层只返回字符串。

## 第四阶段：macOS 原生体验

- [ ] 考虑增加菜单栏模式。
- [ ] 增加 Dock / 菜单栏模式切换。
- [ ] 增加快捷键支持。
- [ ] 继续优化窗口尺寸、小屏显示和窄宽度下的布局切换。
- [ ] 添加应用图标，并做最后一轮视觉 polish。
- [ ] 评估是否需要重新开启 App Sandbox，并改用更合适的网络检测方式。

## 已完成

- [x] 显示固定主机列表。
- [x] 复制 SSH 命令。
- [x] 打开 Ghostty 并启动 SSH。
- [x] Ping 单台主机。
- [x] 关闭 App Sandbox，解决 `ping` 权限问题。
- [x] 拆分 `ContentView.swift`：
  - `Models/RemoteHost.swift`
  - `Models/HostStatus.swift`
  - `Views/HostCard.swift`
  - `Services/PingService.swift`
- [x] 当 `Open SSH` 失败时，在界面上显示明确的错误信息。
- [x] 为每台主机增加 `Copy IP` 操作。
- [x] 在顶部增加 `Ping All` 按钮，一次检测所有主机。
- [x] 定义 `HostStore`，负责加载和保存主机列表。
- [x] 把当前写死的主机列表移动到本地 JSON 文件。
- [x] 第一次启动时，如果没有 JSON 文件，就写入默认主机示例。
- [x] 增加配置文件路径说明，方便手动备份或编辑。
- [x] 为 JSON 读取失败增加错误提示和恢复策略。
- [x] 支持新增主机。
- [x] 支持修改主机名称、用户名和地址。
- [x] 支持删除主机。
- [x] 支持调整主机顺序。
- [x] 为地址输入增加基础校验，避免空地址或明显错误的 SSH 命令。
- [x] 保存编辑结果到 `hosts.json`。
- [x] 使用 Ghostty AppleScript 自动化打开 SSH，会话稳定可用。
- [x] 为每台主机增加可选的 `startupCommand` 配置。
- [x] 增加 VS Code Remote 入口，并支持默认远程目录。
- [x] 为旧配置自动迁移默认远程目录。
- [x] 为 Windows 主机默认建议 `call "%USERPROFILE%\\bin\\remote.cmd" "{remoteDirectory}"` 的 wrapper 方案。
- [x] 文档化 Windows 远程专用 `pwsh` / `RemoteDockProfile.ps1` 方案。
- [x] 将 SSH 登录后的目录切换 / 启动命令改为单条远程命令执行，移除基于时间延迟的注入。
- [x] 为 `Ping All` 增加独立运行状态，避免重复并发触发。
- [x] 为 Ghostty 未安装和 Automation 权限失败补充明确错误提示。
- [x] 将主按钮文案调整为 `Open in Ghostty`，对齐实际行为。
- [x] 将主界面重构为双栏布局，并将右侧整理为详情页式工作区。
- [x] 为左侧主机列表增加搜索能力。
- [x] 为左侧闪电标记、状态 badge 和关键按钮补充 tooltip。
- [x] 增加默认终端打开方式，降低对 Ghostty 的耦合。
- [x] 为 Tailscale 主机增加本机 Tailscale 状态查看与复制操作。
- [x] 增加复制完整主机信息的操作。
- [x] 支持启动后自动执行一次全量 Ping。

## 备注

- Xcode 项目继续作为 macOS App 外壳使用。
- 先把可复用、可测试的逻辑拆到独立 Swift 文件中；当逻辑变多后，再考虑 Swift Package。
- 在手动工作流足够稳定之前，暂时不要急着增加配置同步、自动发现或后台常驻功能。
- Windows 远程 shell 当前建议通过本机 wrapper 脚本启动，并避免在远程专用 profile 中直接初始化依赖 Scoop shim 的 `starship` / `zoxide`。
