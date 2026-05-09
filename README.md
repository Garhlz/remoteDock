# RemoteDock

RemoteDock 是一个小型 macOS SwiftUI 应用，用来快速连接个人常用的远程主机。

这个项目目前主要作为 SwiftUI、macOS App 开发、以及日常远程连接工作流的练手项目。

当前仓库同时包含：

- `remoteDock.xcodeproj`：macOS SwiftUI App 外壳
- `RemoteDockCore`：通过 Swift Package Manager 管理的纯 Swift 逻辑模块

## 当前功能

- 显示本地配置的 SSH 主机列表。
- 一键复制 SSH 命令到剪贴板。
- 一键复制主机 IP 地址。
- 一键复制完整主机信息，包含名称、SSH 目标、远程目录和启动命令。
- 支持为每台主机配置可选端口，适配非默认 SSH 端口。
- 支持为每台主机配置首选打开方式，让主按钮优先使用 Ghostty、默认终端或 VS Code。
- 支持为每台主机配置自动 Ping 间隔；留空时使用默认的 5 分钟心跳检查。
- 打开 Ghostty 并启动 SSH 会话；Linux 会使用兼容的 `TERM=xterm-256color`，如果配置了远程目录，会在登录后进入该目录，也支持为每台主机配置自定义启动命令。
- 使用系统默认 SSH URL 处理器打开默认终端，减少对 Ghostty 的耦合。
- 打开 VS Code Remote - SSH 并进入主机的默认远程目录。
- 对 Tailscale 主机显示 `Local Tailscale` 操作，查看本机 `tailscale status` 输出，并支持复制结果。
- Ping 主机并显示 Online、Offline 或 Checking 状态。
- 一键 Ping 所有主机。
- 启动后自动执行一次全量 Ping，快速得到初始在线状态。
- 当复制、打开终端或读取状态失败时，在界面顶部显示短暂反馈条。
- 支持 Tailscale IP，也支持任何当前网络可访问的主机地址。
- 从本地 JSON 配置文件加载主机列表。
- 首次启动时自动创建默认主机配置。
- 在窗口底部显示配置文件路径，并支持复制路径。
- 在界面中新增、编辑、删除主机。
- 调整主机显示顺序，并自动保存到 JSON。
- 为每台主机配置默认远程目录，供 VS Code Remote 使用。
- 为每台主机配置可选端口，供 SSH、默认终端和 VS Code Remote 使用。
- 为每台主机配置可选的启动命令，覆盖默认 SSH 登录后的启动行为。
- 为每台主机配置可选的自动 Ping 间隔，控制后台心跳检查频率。
- 使用双栏布局：左侧主机列表，右侧详情与操作面板。
- 左侧支持主机搜索和状态筛选，可按名称、用户名、地址、远程目录以及在线状态过滤。
- 为每台主机显示最近一次检测时间，便于判断状态是否过期。
- 为状态、操作和特殊标记增加 tooltip，降低图标理解成本。
- 右侧详情页会把首选打开方式作为主按钮突出显示，并将其他打开方式整理为次级动作。
- 统一使用结构化错误类型，并在界面层映射为明确的失败提示。
- 将主机模型、配置读写、Ping、默认终端和 Tailscale 状态读取抽到 `RemoteDockCore` Swift Package，便于复用和后续测试。
- `RemoteDockCore` 现已带有 Swift Testing 测试集，覆盖主机模型、配置读写、SSH 命令生成、默认终端 URL、Tailscale 状态和 Ping 执行层。

## 项目结构

```text
remoteDock/
├── Package.swift
├── Sources/
│   └── RemoteDockCore/
│       ├── DefaultTerminalService.swift
│       ├── HostStore.swift
│       ├── PingService.swift
│       ├── RemoteHost.swift
│       ├── SSHCommandBuilder.swift
│       ├── SSHURLBuilder.swift
│       └── TailscaleService.swift
├── Tests/
│   └── RemoteDockCoreTests/
│       ├── HostStoreTests.swift
│       ├── PingServiceTests.swift
│       ├── RemoteHostTests.swift
│       ├── SSHCommandBuilderTests.swift
│       ├── SSHURLBuilderTests.swift
│       └── TailscaleServiceTests.swift
├── remoteDock.xcodeproj
├── remoteDock/
│   ├── remoteDockApp.swift
│   ├── ContentView.swift
│   ├── Models/
│   │   ├── HostStatus.swift
│   ├── Services/
│   │   ├── ClipboardService.swift
│   │   ├── TerminalService.swift
│   │   └── VSCodeService.swift
│   ├── Views/
│   │   ├── HostCard.swift
│   │   └── HostEditorView.swift
│   └── Assets.xcassets
├── README.md
└── TODO.md
```

`ContentView.swift` 负责主窗口状态、双栏布局、反馈条和主机选择；`RemoteDockCore` 负责不依赖 SwiftUI / AppKit 的纯逻辑；终端自动化、VS Code 打开和剪贴板等 macOS 集成功能继续留在 App target 中。`Tests/RemoteDockCoreTests` 负责这部分核心逻辑的单元测试。

## 当前界面

当前版本使用双栏桌面工具布局：

- 左侧：主机导航列表，支持搜索和选择。
- 右侧：当前主机的详情页，包含状态、操作按钮和连接配置。
- 顶部：概览统计和全局操作。
- 底部：配置文件路径与重新加载入口。

`Open in Ghostty`、`Open in VS Code`、`Open in Default Terminal` 和 `Local Tailscale` 是右侧的主要操作；复制 SSH、复制 IP、复制完整主机信息、Ping 和管理动作作为次级操作保留在同一区域。

其中 `Local Tailscale` 只会在地址看起来属于 Tailscale 网络的主机上显示。这个按钮展示的是本机的 `tailscale status`，用于快速确认当前 Mac 是否已经连上 tailnet，不代表远端主机自身状态。

左侧列表现在还支持按状态筛选 `All / Online / Offline / Unchecked`，并显示每台主机的 `Last checked` 相对时间。

当前复制动作和大部分失败操作都会在顶部显示自动消失的反馈条，不再只依赖按钮文案变化或模态弹窗。

应用启动后会先执行一次全量 Ping，之后再按每台主机的自动 Ping 间隔做后台检查；如果主机没有单独配置，就使用默认的 5 分钟。

## 下一步规划

当前更值得投入的方向，不是继续堆连接动作，而是把“设置集中化”和“长期使用体验”补完整。

建议优先级：

1. `Settings` 入口与全局选项：集中放置默认打开方式、全局心跳默认值、菜单栏显示等配置。
2. 心跳策略补完：支持秒级间隔、`Never` / 仅手动检查，以及全局默认值和单主机覆盖。
3. 快捷键：至少支持“按默认方式打开当前主机”。
4. 左侧导航增强：支持简单分组，例如按系统类型、连接方式或自定义分组名。
5. 复制配置动作：复制单主机 JSON 片段，并评估是否需要导出当前主机配置。
6. SSH 密钥管理评估：优先复用系统 `ssh-agent` / Keychain，而不是在应用内直接托管私钥。

## 主机配置

RemoteDock 会从本地 JSON 文件加载主机列表。首次启动时，如果配置文件不存在，应用会自动创建一个默认配置。

配置文件位置：

```text
~/Library/Application Support/RemoteDock/hosts.json
```

也可以在应用窗口底部直接查看并复制当前配置路径。

配置示例：

```json
[
  {
    "address": "100.117.140.113",
    "id": "00000000-0000-0000-0000-000000000001",
    "name": "Arch T480s",
    "autoPingIntervalMinutes": 5,
    "preferredOpenMode": "ghostty",
    "port": 22,
    "remoteDirectory": "/home/elaine",
    "startupCommand": "cd -- {remoteDirectory} && exec zsh -l",
    "username": "elaine"
  }
]
```

如果 JSON 格式损坏，RemoteDock 会在界面上显示错误，并临时回退到默认主机列表。它不会自动覆盖损坏的配置文件。

主机也可以直接在 App 界面中新增、编辑、删除和排序。保存后会立即写回 `hosts.json`。如果目标机器使用非默认 SSH 端口，也可以直接填写 `port`。`preferredOpenMode` 可选值为 `ghostty`、`defaultTerminal` 和 `vscode`，它决定右侧详情页主按钮默认打开哪种连接方式。`autoPingIntervalMinutes` 可以覆盖默认的后台心跳检查间隔；留空时使用 5 分钟默认值。如果要使用 `Open in VS Code`，请为对应主机填写可访问的远程目录，例如 Linux 的 `/home/elaine/project` 或 Windows 的 `C:/Users/elaine/project`。

如果某台主机有特殊 shell 或启动流程，也可以填写 `startupCommand`。这个命令会在 SSH 登录后直接执行，`{remoteDirectory}` 会被替换成当前主机配置中的目录。比如：

- Linux: `cd -- {remoteDirectory} && exec zsh -l`
- Windows: `call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}"`

### Windows 主机建议配置

当前更稳定的做法是：不要在 `startupCommand` 中直接拼复杂的 `pwsh` 启动逻辑，而是在 Windows 主机本机放一个 wrapper 脚本，再让 RemoteDock 调它。

推荐把脚本放在：

```text
%USERPROFILE%\bin\remote.cmd
```

推荐内容：

```bat
@echo off
set "TARGET=%~1"
if not defined TARGET set "TARGET=%USERPROFILE%"
cd /d "%TARGET%"
"C:\Users\Elaine\scoop\apps\pwsh\7.6.0\pwsh.exe" -NoLogo -NoExit -NoProfile -Command ". '%USERPROFILE%\Documents\PowerShell\RemoteDockProfile.ps1'"
```

对应的 `startupCommand`：

```text
call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}"
```

之所以推荐这种方式，是因为在 Windows OpenSSH 的远程命令场景里，Scoop 的 `current` junction 和 shim 可执行文件经常不稳定。直接在 wrapper 里写实际版本路径会更可靠。

### Windows 远程专用 PowerShell Profile

如果你希望远程连接时保留 `pwsh` 的常用体验，建议单独维护：

```text
%USERPROFILE%\Documents\PowerShell\RemoteDockProfile.ps1
```

RemoteDock 当前验证通过的方案是：

- `remote.cmd` 使用 `-NoProfile`
- 再手动加载 `RemoteDockProfile.ps1`
- 暂时不要在这份远程专用 profile 里初始化依赖 Scoop shim 的 `starship` / `zoxide`

这是因为它们在远程启动链路里仍可能通过 `current` shim 间接启动，导致初始化失败。

## 环境要求

- macOS
- Xcode 26 或更新版本
- SwiftUI
- 可选：VS Code 用于编辑代码

## 使用 Xcode 运行

打开项目：

```bash
open remoteDock.xcodeproj
```

然后选择 `My Mac`，按 `Cmd + R` 运行。

## 使用命令行构建

```bash
xcodebuild \
  -project remoteDock.xcodeproj \
  -scheme remoteDock \
  -destination 'platform=macOS' \
  -derivedDataPath .DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

运行构建后的 App：

```bash
open .DerivedData/Build/Products/Debug/remoteDock.app
```

如果只想验证纯逻辑包本身，也可以直接运行：

```bash
swift build
```

运行核心测试：

```bash
swift test
```

当前测试主要覆盖：

- `RemoteHost`：主机识别、默认目录、端口、字段归一化
- `HostStore`：默认配置写入、JSON 读写、旧配置迁移、非法 JSON
- `SSHCommandBuilder`：Linux / Windows SSH 命令与 follow-up 命令生成
- `SSHURLBuilder`：默认终端 `ssh://` URL 生成
- `TailscaleService`：路径探测、结构化错误和命令执行结果处理
- `PingService`：执行层注入和结果传递

## macOS 权限说明

RemoteDock 当前通过 Ghostty 的 AppleScript 接口打开终端，并把 SSH 命令发送到新窗口或当前启动窗口中执行。

第一次使用 `Open in Ghostty` 时，macOS 可能会弹出 Automation 权限提示，询问是否允许 `remoteDock` 控制 `Ghostty`。需要允许后，这个功能才会正常工作。

如果不希望依赖 Ghostty 自动化，也可以使用 `Open in Default Terminal`。这个入口会把 `ssh://user@host` 交给系统默认的 SSH URL 处理器，不会附带 Ghostty 的额外启动逻辑。

`Local Tailscale` 会优先查找 Tailscale.app 自带的 CLI，其次再尝试常见的 Homebrew 路径。因此即使图形界面 App 的 `PATH` 不完整，只要本机安装了 Tailscale，也可以正常读取状态。

当前实现的实际效果是：

1. Ghostty 先打开一个本地 shell。
2. RemoteDock 再把 `/usr/bin/ssh user@host` 发送到终端。
3. shell 执行 SSH，并进入远程主机。

因此，终端中先看到本地提示符、再看到一条 SSH 命令，是当前设计下的正常表现。

由于这个本地工具会启动 `ping` 等系统命令，当前项目关闭了 App Sandbox。
