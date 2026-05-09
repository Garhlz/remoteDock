# RemoteDock

RemoteDock 是一个小型 macOS SwiftUI 应用，用来管理常用远程主机，并快速执行 SSH、VS Code Remote、Ping、配置复制等日常操作。

它更像一个**远程连接工作台**，而不是终端模拟器本身：主机配置保存在本地 JSON 中，界面负责组织入口，真正的终端、编辑器和系统能力仍然交给 Ghostty、默认终端、VS Code、Tailscale 等工具处理。

## 适合什么场景

RemoteDock 主要面向这类日常工作流：

- 在几台固定 Linux / Windows / Tailscale 主机之间来回切换
- 需要记住用户名、端口、远程目录、默认打开方式
- 希望在 GUI 和命令行之间保留一个轻量桥梁
- 偶尔需要复制 SSH 命令、单主机配置或完整配置 JSON

## 当前功能概览

- 主机与分组管理
- `Open in Ghostty` / `Open in Default Terminal` / `Open in VS Code`
- 单主机 Ping、`Ping All`、延迟与最近检测时间
- 全局与主机级自动 Ping 策略
- 菜单栏入口、菜单命令、快捷键与可隐藏的状态栏图标
- Tailscale 状态辅助查看
- 配置复制、导出和示例配置参考
- 应用图标与菜单栏图标已接入

## 仓库结构

```text
remoteDock/
├── docs/                     # 详细文档
├── Examples/                 # 示例配置
├── Sources/RemoteDockCore/   # 核心逻辑 Swift Package
├── Tests/RemoteDockCoreTests/# 核心测试
├── remoteDock/               # macOS App 代码
├── Package.swift
├── README.md
└── remoteDock.xcodeproj/
```

项目分成两层：

1. **App 层**：`remoteDock/` + `remoteDock.xcodeproj`，负责 SwiftUI 界面、AppKit 状态栏集成和系统能力接入
2. **Core 层**：`Sources/RemoteDockCore/` + `Package.swift`，负责模型、配置、SSH 命令、Ping、Tailscale 等纯逻辑

## 快速开始

### 用 Xcode 运行

```bash
open remoteDock.xcodeproj
```

然后在 Xcode 中选择：

- Scheme：`remoteDock`
- Destination：`My Mac`

### 用命令行验证

```bash
swift test

xcodebuild \
  -project remoteDock.xcodeproj \
  -scheme remoteDock \
  -destination 'platform=macOS' \
  -derivedDataPath .DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 文档导航

更详细的说明已经拆到 `docs/`：

- [`docs/features.md`](docs/features.md)：功能介绍、典型工作流、菜单栏与打开方式
- [`docs/project-structure.md`](docs/project-structure.md)：项目结构、目录职责、Xcode 工程与 Swift Package 的关系
- [`docs/build-and-run.md`](docs/build-and-run.md)：环境要求、Xcode 使用、命令行构建与日常开发流程
- [`docs/configuration.md`](docs/configuration.md)：`hosts.json` 结构、示例配置、迁移兼容、`startupCommand` 与 Windows wrapper
- [`docs/design-notes.md`](docs/design-notes.md)：设计思路、分层方式和系统集成取舍
- [`docs/testing.md`](docs/testing.md)：测试结构、当前覆盖范围和示例配置如何参与测试

## 相关入口

- 根目录 `Examples/`：当前格式和旧格式的示例配置
- `remoteDock/README.md`：App 层说明
- `Sources/RemoteDockCore/README.md`：核心逻辑层说明
- `Tests/RemoteDockCoreTests/README.md`：测试目录说明
