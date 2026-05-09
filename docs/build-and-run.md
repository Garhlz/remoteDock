# 构建与运行

## 环境要求

- macOS
- Xcode 26 或更新版本
- Swift 6 工具链（Xcode 26 自带）
- 可选：
  - Ghostty
  - Visual Studio Code
  - Tailscale

如果你只是想看代码或跑核心测试，不一定需要安装 Ghostty / VS Code / Tailscale。

## 使用 Xcode 运行

对于完整 App 的体验，Xcode 仍然是最直接的入口。

### 1. 打开项目

```bash
open remoteDock.xcodeproj
```

### 2. 选择运行目标

在 Xcode 顶部工具栏中选择：

- Scheme：`remoteDock`
- Destination：`My Mac`

### 3. 运行

按：

```text
Cmd + R
```

运行过程大致会：

1. 编译 App
2. 启动一个本地调试版 macOS 应用
3. 打开主窗口

### 4. 常见操作

- `Cmd + B`：只构建，不运行
- `Cmd + R`：构建并运行
- `Cmd + Shift + K`：清理构建产物

## 使用命令行构建

### 1. 只构建和测试核心逻辑：`swift build` / `swift test`

这套命令面向 `Package.swift`，也就是 **RemoteDockCore**。

#### 构建核心包

```bash
swift build
```

#### 运行核心测试

```bash
swift test
```

### 2. 构建完整 macOS App：`xcodebuild`

这套命令面向 `remoteDock.xcodeproj`，也就是 **整个 App**。

```bash
xcodebuild \
  -project remoteDock.xcodeproj \
  -scheme remoteDock \
  -destination 'platform=macOS' \
  -derivedDataPath .DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

如果你不熟这些参数，可以这样理解：

| 参数 | 作用 |
| --- | --- |
| `-project remoteDock.xcodeproj` | 指定要构建哪个 Xcode 工程 |
| `-scheme remoteDock` | 指定要构建哪个 Scheme / 目标入口 |
| `-destination 'platform=macOS'` | 说明这是 macOS 构建 |
| `-derivedDataPath .DerivedData` | 把构建产物放到仓库里的 `.DerivedData` |
| `CODE_SIGNING_ALLOWED=NO` | 本地开发构建时跳过签名要求 |
| `build` | 执行构建动作 |

构建成功后，App 一般会出现在：

```text
.DerivedData/Build/Products/Debug/remoteDock.app
```

你可以直接打开它：

```bash
open .DerivedData/Build/Products/Debug/remoteDock.app
```

## 一个最实用的日常开发流程

### 方案 A：偏 Xcode 的工作流

1. `open remoteDock.xcodeproj`
2. 在 Xcode 里修改 UI 或 App 逻辑
3. `Cmd + R` 运行看看界面
4. 回到终端执行 `swift test`
5. 再执行一次 `xcodebuild ... build`

### 方案 B：偏终端的工作流

1. 用编辑器改代码
2. 跑 `swift test`
3. 跑 `xcodebuild ... build`
4. 用 `open .DerivedData/Build/Products/Debug/remoteDock.app` 打开 App

### 什么时候用哪一个

- 改 **SwiftUI 界面**：优先 Xcode
- 改 **核心逻辑**：终端 + `swift test` 很高效
- 想确认完整 App 能否编过：用 `xcodebuild`
