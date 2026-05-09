# RemoteDock TODO

这个文件用于记录 RemoteDock 接下来的开发计划。任务尽量保持小而清晰，并优先选择能明显提升日常可用性的工作。

## 推荐路线

主机管理、双栏 UI 和核心远程动作已经基本成型。下一阶段更值得投入的是“设置集中化”“连接策略补完”和“macOS 原生体验”。

建议顺序：

1. 设置与连接策略整理
2. 导航与信息组织
3. macOS 原生体验补完
4. 安全与密钥管理

## 第一优先级：设置与连接策略

- [x] 增加 VS Code Remote 命令支持。
- [x] 为每台主机增加可配置的默认远程目录。
- [x] 为 Tailscale 主机增加本机 `tailscale status` 查看操作。
- [x] 增加复制完整主机信息的操作。
- [x] 支持启动时自动 Ping 一次所有主机。
- [x] 为每台主机显示 `Last checked` 时间。
- [x] 为左侧列表增加状态筛选，例如 `All / Online / Offline / Unchecked`。
- [x] 为每台主机增加可选 SSH 端口。
- [x] 为每台主机增加可选自动 Ping 间隔，并在后台按间隔执行心跳检查。
- [x] 为错误提示和复制反馈增加更明确的短暂提示样式。
- [x] 增加一个简单的 `Settings` 入口，集中放置全局配置。
- [x] 将全局默认打开方式和全局默认心跳间隔接入 `Settings`。
- [x] 将全局心跳模式扩展为秒级 / 分钟级 / 仅手动，并支持关闭启动时自动检测。
- [x] 为“默认打开方式”增加快捷键，支持按默认方式打开当前选中主机。
- [x] 增加快捷键方式 Ping 当前选中主机。
- [x] 将快捷键预设做成可配置项，并放入 `Settings`。
- [x] 为单主机心跳策略增加 `Never`，允许禁用该主机的后台心跳。
- [x] 增加菜单栏图标开关，并提供基础主机快捷操作菜单。
- [x] 为菜单栏补充状态摘要、`Ping All`、简单分组和最近检测时间。
- [x] 为在线主机显示平均延迟，并将单次采样改成 3 包 `ping` 结果。
- [ ] 评估是否需要支持完全自定义快捷键，而不只是预设组合。
- [ ] 扩展心跳机制选项：
  - 评估是否需要秒级的单主机覆盖
  - 区分全局默认值和更细粒度的主机策略展示
  - 评估是否需要把延迟显示从“单轮 3 包采样”升级成最近几次的滚动平均
- [ ] 为默认终端路径补充失败提示，明确当前系统没有可处理 `ssh://` 的应用时该怎么处理。

## 第二优先级：导航与信息组织

- [x] 调整 `Open SSH` 文案，明确它会在 Ghostty 中打开并执行 SSH。
- [x] 增加 Ghostty 未安装时的明确错误提示。
- [x] 增加 Automation 权限失败时的提示文案。
- [x] 去掉基于固定 `delay` 的 follow-up 命令注入，避免慢速 SSH 登录时把命令打到本地 shell、密码提示或 host key 提示上。
- [x] 把 SSH 后续动作改成单条远程命令模式，不再依赖 `delay 1.5`。
- [x] 增加“默认终端”打开方式，减少对 Ghostty 的耦合。
- [x] 为每台主机增加可选的“首选打开方式”，允许在 Ghostty、默认终端和 VS Code 之间切换。
- [ ] 为左侧 hosts 列表增加用户自定义分组：
  - [x] 定义 `HostGroup` / `RemoteDockConfiguration` 数据结构，并保留旧 `hosts.json` 的迁移兼容。
  - [x] 支持“未分组主机”视图，保证旧主机和退出分组的主机仍可正常显示。
  - [x] 支持创建分组、重命名分组、删除分组。
  - [x] 支持调整分组顺序。
  - [x] 支持主机加入分组、切换分组、退出分组。
  - [x] 支持左侧 sidebar 按自定义分组展示主机，并保留搜索 / 状态筛选逻辑。
  - [x] 菜单栏主机分组复用自定义分组，并为未分组主机保留 `Ungrouped`。
- [ ] 增加“复制配置”动作：
  - 复制单主机 JSON 片段
  - 评估是否增加“导出当前主机配置”

## 第三优先级：macOS 原生体验

- [x] 增加菜单栏图标模式。
- [x] 增加是否显示菜单栏图标的开关。
- [ ] 增加 Dock / 菜单栏模式切换。
- [ ] 增加快捷键支持。
- [ ] 继续优化窗口尺寸、小屏显示和窄宽度下的布局切换。
- [ ] 添加应用图标，并做最后一轮视觉 polish。
- [ ] 评估是否需要重新开启 App Sandbox，并改用更合适的网络检测方式。

## 第四优先级：架构、安全与测试

当前 `RemoteDockCore` 已有 `53` 个测试，覆盖 `6` 个 suite。

- [x] 修正 `Ping All` 的进行中状态判断，避免首个主机返回后按钮重新可点，导致重复并发检测。
- [x] 把纯 Swift 逻辑抽成 `RemoteDockCore` Swift Package。
- [x] 为 `RemoteDockCore` 增加 `RemoteDockCoreTests` test target。
- [x] 为 `RemoteHost` 增加单元测试：
  - 默认远程目录推导
  - Windows 主机识别
  - Tailscale 地址识别
  - SSH 命令 / authority / display address 的端口拼接
  - `startupCommand` / `remoteDirectory` 归一化
- [x] 为 `HostStore` 增加单元测试：
  - 默认主机写入
  - 现有 JSON 读取
  - 旧配置迁移默认远程目录
  - 旧配置迁移 Windows `startupCommand`
  - 非法 JSON 的错误返回
- [x] 为 SSH 命令生成增加单元测试：
  - 默认 Linux 登录命令
  - 带端口的 SSH 命令
  - 带远程目录的 follow-up 命令
  - 自定义 `startupCommand`
  - Windows wrapper 命令生成
- [x] 为默认终端 URL 生成增加单元测试：
  - 默认端口
  - 自定义端口
  - 用户名与 host 组合
- [x] 为 Tailscale 状态读取增加可替换执行层，便于测试、路径探测和错误注入。
- [x] 为 `TailscaleService` 增加单元测试：
  - 可执行文件路径探测优先级
  - CLI 缺失时的错误
  - 空输出和非零退出码处理
- [x] 为 Ping 状态更新逻辑增加可测试封装。
- [x] 为 `PingService` 增加单元测试或命令执行抽象：
  - 成功返回 online
  - 非零退出码返回 offline
  - 进程启动失败返回 offline
- [x] 梳理错误类型，避免服务层只返回字符串。
- [ ] 评估 SSH 密钥管理方案：
  - 是否只依赖系统 `ssh-agent` / Keychain
  - 是否需要 UI 层面的密钥提示或状态展示
  - 明确不在应用内直接托管私钥，还是增加只读辅助能力

### 测试实施顺序

1. 建 `RemoteDockCoreTests` target，并先覆盖 `RemoteHost`
2. 补 `HostStore`，把 JSON 读写和迁移稳定住
3. 提炼 SSH / URL 生成逻辑，让命令测试不依赖 UI 层
4. 给 `TailscaleService` / `PingService` 引入可替换执行层，再补测试
5. 梳理错误类型，把现在的字符串错误逐步改成结构化错误

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
- [x] 将主机模型、配置读写和部分系统命令调用抽到 `RemoteDockCore` Swift Package。
- [x] 为 SSH、默认终端和 VS Code Remote 增加可选端口支持。
- [x] 为每台主机增加首选打开方式，并让详情页主按钮随之变化。
- [x] 优化右侧详情区和左侧选中态，突出当前主机的核心动作和连接方式。

## 备注

- Xcode 项目继续作为 macOS App 外壳使用。
- `RemoteDockCore` 现在承载纯 Swift 逻辑；后续优先为它补测试，而不是继续把逻辑堆回 App target。
- 在手动工作流足够稳定之前，暂时不要急着增加配置同步、自动发现或后台常驻功能。
- Windows 远程 shell 当前建议通过本机 wrapper 脚本启动，并避免在远程专用 profile 中直接初始化依赖 Scoop shim 的 `starship` / `zoxide`。
