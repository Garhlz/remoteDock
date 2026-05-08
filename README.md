# RemoteDock

RemoteDock 是一个小型 macOS SwiftUI 应用，用来快速连接个人常用的远程主机。

这个项目目前主要作为 SwiftUI、macOS App 开发、以及日常远程连接工作流的练手项目。

## 当前功能

- 显示本地配置的 SSH 主机列表。
- 一键复制 SSH 命令到剪贴板。
- 一键复制主机 IP 地址。
- 打开 Ghostty 并启动 SSH 会话。
- Ping 主机并显示 Online、Offline 或 Checking 状态。
- 一键 Ping 所有主机。
- 当打开 SSH 失败时，在界面上显示错误信息。
- 支持 Tailscale IP，也支持任何当前网络可访问的主机地址。
- 从本地 JSON 配置文件加载主机列表。
- 首次启动时自动创建默认主机配置。
- 在窗口底部显示配置文件路径，并支持复制路径。
- 在界面中新增、编辑、删除主机。
- 调整主机显示顺序，并自动保存到 JSON。

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
│   │   └── TerminalService.swift
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
    "username": "elaine"
  }
]
```

如果 JSON 格式损坏，RemoteDock 会在界面上显示错误，并临时回退到默认主机列表。它不会自动覆盖损坏的配置文件。

主机也可以直接在 App 界面中新增、编辑、删除和排序。保存后会立即写回 `hosts.json`。

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
