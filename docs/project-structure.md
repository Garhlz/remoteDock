# 项目结构

## 项目整体结构

这个项目实际上由 **两层** 组成：

### 1. App 层：`remoteDock/` + `remoteDock.xcodeproj`

这一层是 macOS 应用本身，负责：

- SwiftUI 界面
- 菜单栏入口
- 设置面板
- 调用剪贴板、Ghostty、VS Code 这些 macOS / 本地应用能力

### 2. Core 层：`Package.swift` + `Sources/RemoteDockCore/`

这一层是一个单独的 Swift Package，负责：

- 主机模型
- 配置文件读写
- SSH 命令拼接
- Ping 逻辑
- Tailscale 状态读取

这种拆分的好处是：

- UI 和业务逻辑分离
- 核心逻辑更容易写测试
- 将来如果想复用核心逻辑，也不用把整个 App 一起搬走

## 为什么仓库里同时有 `remoteDock.xcodeproj` 和 `Package.swift`

### `remoteDock.xcodeproj`

这是 **Xcode 工程文件**，主要给 Xcode 用。它描述：

- 这是一个 macOS App target
- App 入口是什么
- 资源文件在哪里
- 用什么 Scheme 构建
- 依赖哪个本地 Swift Package

### `Package.swift`

这是 **Swift Package Manager（SPM）** 的清单文件。它描述：

- 包的名字是什么
- 有哪些 target
- 哪些 target 是测试
- 支持什么平台

在这个项目里，两者的关系是：

- `remoteDock.xcodeproj`：构建 **整个 macOS App**
- `Package.swift`：构建和测试 **RemoteDockCore 核心逻辑**

## 仓库结构详解

```text
remoteDock/
├── docs/
├── Examples/
├── Package.swift
├── README.md
├── TODO.md
├── Sources/
├── Tests/
├── remoteDock/
└── remoteDock.xcodeproj/
```

### `Examples/`

这里放的是仓库内维护的示例配置文件。

- `current-config.json`：当前推荐的完整配置文档
- `legacy-hosts-array.json`：旧版只保存主机数组的历史格式

这两个文件也会被测试直接读取。

### `Sources/RemoteDockCore/`

这是核心逻辑源码目录。这里的文件大多是“纯 Swift 逻辑”，不负责画界面。

当前主要包含：

- `RemoteHost.swift`：单台主机的配置模型
- `RemoteDockConfiguration.swift`：整个配置文档模型
- `HostStore.swift`：读取 / 保存 / 迁移 `hosts.json`
- `SSHCommandBuilder.swift`：拼接最终 SSH 命令
- `SSHURLBuilder.swift`：生成 `ssh://` URL
- `PingService.swift`：运行 ping、解析延迟和丢包
- `TailscaleService.swift`：读取 `tailscale status`
- `DefaultTerminalService.swift`：用系统默认 SSH URL 处理器打开终端
- `HostGroup.swift`：分组模型
- `PreferredOpenMode.swift`：首选打开方式枚举
- `JSONExportFormatter.swift`：稳定输出 JSON 文本

### `Tests/RemoteDockCoreTests/`

这是核心逻辑的测试目录。

当前测试集中在 `RemoteDockCore`，因为这些逻辑更容易脱离界面测试。

例如：

- `RemoteHostTests.swift`
- `HostStoreTests.swift`
- `SSHCommandBuilderTests.swift`
- `SSHURLBuilderTests.swift`
- `PingServiceTests.swift`
- `TailscaleServiceTests.swift`

### `remoteDock/`

这是 **App target 的源码目录**。

其中主要又分成：

- `remoteDockApp.swift`：应用入口
- `ContentView.swift`：主窗口页面级协调器
- `Views/`：SwiftUI 视图组件
- `Services/`：App 层系统集成服务
- `Models/`：更贴近 App / UI 的模型和桥接类型

### `remoteDock.xcodeproj/`

这是 Xcode 工程文件目录。通常不需要手动编辑，除非在做 target 配置、build setting、资源或依赖调整。

## 当前代码分层可以怎么理解

如果把整个项目粗略拆成一条调用链，大致是这样：

```text
SwiftUI View
  -> ContentView / 页面状态
    -> App Services（Clipboard / Ghostty / VS Code）
    -> RemoteDockCore（配置 / SSH 命令 / Ping / Tailscale）
      -> 本地文件 / 系统命令 / 外部 App
```

## 对第一次读 SwiftUI 项目的人，一个简单阅读顺序

推荐顺序：

1. `README.md`
2. `Package.swift`
3. `remoteDock/remoteDockApp.swift`
4. `remoteDock/ContentView.swift`
5. `remoteDock/Views/`
6. `Sources/RemoteDockCore/RemoteHost.swift`
7. `Sources/RemoteDockCore/HostStore.swift`
8. `Sources/RemoteDockCore/SSHCommandBuilder.swift`
9. `Sources/RemoteDockCore/PingService.swift`
10. `Tests/RemoteDockCoreTests/`
