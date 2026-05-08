# RemoteDock

RemoteDock 是一个小型 macOS SwiftUI 应用，用来快速连接个人常用的远程主机。

这个项目目前主要作为 SwiftUI、macOS App 开发、以及日常远程连接工作流的练手项目。

## 当前功能

- 显示本地配置的 SSH 主机列表。
- 一键复制 SSH 命令到剪贴板。
- 一键复制主机 IP 地址。
- 打开 Ghostty 并启动 SSH 会话；Linux 会使用兼容的 `TERM=xterm-256color`，如果配置了远程目录，会在登录后进入该目录，也支持为每台主机配置自定义启动命令。
- 打开 VS Code Remote - SSH 并进入主机的默认远程目录。
- Ping 主机并显示 Online、Offline 或 Checking 状态。
- 一键 Ping 所有主机。
- 当打开 SSH 失败时，在界面上显示错误信息。
- 支持 Tailscale IP，也支持任何当前网络可访问的主机地址。
- 从本地 JSON 配置文件加载主机列表。
- 首次启动时自动创建默认主机配置。
- 在窗口底部显示配置文件路径，并支持复制路径。
- 在界面中新增、编辑、删除主机。
- 调整主机显示顺序，并自动保存到 JSON。
- 为每台主机配置默认远程目录，供 VS Code Remote 使用。
- 为每台主机配置可选的启动命令，覆盖默认 SSH 登录后的启动行为。

## 项目结构

```text
remoteDock/
├── remoteDock.xcodeproj
├── remoteDock/
│   ├── remoteDockApp.swift
│   ├── ContentView.swift
│   ├── Models/
│   │   ├── HostStatus.swift
│   │   └── RemoteHost.swift
│   ├── Services/
│   │   ├── ClipboardService.swift
│   │   ├── HostStore.swift
│   │   ├── PingService.swift
│   │   ├── TerminalService.swift
│   │   └── VSCodeService.swift
│   ├── Views/
│   │   ├── HostCard.swift
│   │   └── HostEditorView.swift
│   └── Assets.xcassets
├── README.md
└── TODO.md
```

`ContentView.swift` 负责主窗口状态和整体交互；模型、服务和主机卡片视图已经拆分到独立文件中。

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
    "remoteDirectory": "/home/elaine",
    "startupCommand": "cd -- {remoteDirectory} && exec zsh -l",
    "username": "elaine"
  }
]
```

如果 JSON 格式损坏，RemoteDock 会在界面上显示错误，并临时回退到默认主机列表。它不会自动覆盖损坏的配置文件。

主机也可以直接在 App 界面中新增、编辑、删除和排序。保存后会立即写回 `hosts.json`。如果要使用 `Open in VS Code`，请为对应主机填写可访问的远程目录，例如 Linux 的 `/home/elaine/project` 或 Windows 的 `C:/Users/elaine/project`。

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

## macOS 权限说明

RemoteDock 当前通过 Ghostty 的 AppleScript 接口打开终端，并把 SSH 命令发送到新窗口或当前启动窗口中执行。

第一次使用 `Open SSH` 时，macOS 可能会弹出 Automation 权限提示，询问是否允许 `remoteDock` 控制 `Ghostty`。需要允许后，这个功能才会正常工作。

当前实现的实际效果是：

1. Ghostty 先打开一个本地 shell。
2. RemoteDock 再把 `/usr/bin/ssh user@host` 发送到终端。
3. shell 执行 SSH，并进入远程主机。

因此，终端中先看到本地提示符、再看到一条 SSH 命令，是当前设计下的正常表现。

由于这个本地工具会启动 `ping` 等系统命令，当前项目关闭了 App Sandbox。
