# RemoteDock

RemoteDock 是一个小型 macOS SwiftUI 应用，用来管理常用远程主机，并快速执行 SSH、VS Code Remote、Ping、配置复制等日常操作。

这个仓库同时也是一个 **SwiftUI + macOS App + Swift Package Manager** 的练手项目。README 主要围绕下面几件事展开：

1. **这个仓库里每个目录是干什么的**
2. **为什么仓库里同时有 `remoteDock.xcodeproj` 和 `Package.swift`**
3. **应该用 Xcode 运行什么，用命令行运行什么**
4. **主窗口、核心逻辑、测试分别放在哪里**

---

## 这个项目解决什么问题

RemoteDock 的目标不是做一个“通用 SSH 客户端”，而是做一个偏个人工作流的小工具：

- 把常用主机保存在本地 JSON 配置里
- 在 macOS 上快速打开 SSH 会话
- 直接用 VS Code Remote - SSH 打开远程目录
- 查看主机是否在线、延迟大概是多少
- 复制 SSH 命令、主机信息、单主机 JSON、完整配置 JSON
- 用菜单栏入口做一些轻量快捷操作

它更像一个“远程连接工作台”，而不是终端模拟器本身。

更具体地说，这个项目关注的是下面这类高频但零碎的动作：

- 记住“我平时到底连哪些机器”
- 记住“每台机器该用哪个用户名、目录、端口、打开方式”
- 少做重复输入，例如反复敲 `ssh user@host`
- 在 GUI 和命令行之间保留一个轻量桥梁，而不是完全依赖某一种工作方式

它不想替代 Terminal、Ghostty、VS Code 或 Tailscale，而是想把它们组织成一个更顺手的入口。  
所以从产品定位上，它更接近：

- **远程主机启动器**
- **个人 SSH 工作流面板**
- **本地配置驱动的小型运维桌面工具**

### 典型使用场景

如果你平时会在几台固定机器之间切换，例如：

- 一台 Linux 开发机
- 一台 Windows 工作站
- 一台 NAS / 家用服务器
- 一两台通过 Tailscale 访问的笔记本或实验机

那么你经常会重复做这些事：

1. 找地址
2. 确认用户名
3. 决定是开终端还是开 VS Code
4. 想想远程目录该进哪个
5. 先看一眼机器是不是在线
6. 偶尔还要把当前配置分享或备份出来

RemoteDock 试图把这些步骤收束到一个统一界面里，并尽量减少“先打开终端 / 先打开笔记 / 先翻配置文件”的切换成本。

---

## 项目整体结构

这个项目实际上由 **两层** 组成：

### 1. App 层：`remoteDock/` + `remoteDock.xcodeproj`

这一层是 macOS 应用本身，负责：

- SwiftUI 界面
- 菜单栏入口
- 设置面板
- 调用剪贴板、Ghostty、VS Code 这些 macOS / 本地应用能力

这一层可以理解为应用外壳和桌面界面层。

### 2. Core 层：`Package.swift` + `Sources/RemoteDockCore/`

这一层是一个单独的 Swift Package，负责：

- 主机模型
- 配置文件读写
- SSH 命令拼接
- Ping 逻辑
- Tailscale 状态读取

这一层尽量不依赖 SwiftUI，偏“纯逻辑”。  
这一层更接近业务逻辑层和可测试的核心模块。

这种拆分的好处是：

- UI 和业务逻辑分离
- 核心逻辑更容易写测试
- 将来如果想复用核心逻辑，也不用把整个 App 一起搬走

---

## 为什么仓库里同时有 `remoteDock.xcodeproj` 和 `Package.swift`

对于同时包含 Xcode 工程和 Swift Package 的仓库，这一层关系通常最值得先说明。

### `remoteDock.xcodeproj`

这是 **Xcode 工程文件**，主要给 Xcode 用。它描述：

- 这是一个 macOS App target
- App 入口是什么
- 资源文件在哪里
- 用什么 Scheme 构建
- 依赖哪个本地 Swift Package

Xcode 中的运行、构建、预览和 target 配置主要都依赖它。

### `Package.swift`

这是 **Swift Package Manager（SPM）** 的清单文件。它描述：

- 包的名字是什么
- 有哪些 target
- 哪些 target 是测试
- 支持什么平台

命令行中的：

```bash
swift test
swift build
```

主要由它描述和驱动。

### 在这个项目里，两者的关系是

- `remoteDock.xcodeproj`：构建 **整个 macOS App**
- `Package.swift`：构建和测试 **RemoteDockCore 核心逻辑**

在这个项目里，两者的分工比较清晰：

- 完整 App 的运行和构建，使用 **Xcode / xcodebuild**
- 核心逻辑的构建和测试，使用 **swift build / swift test**

---

## 仓库结构详解

先看顶层结构：

```text
remoteDock/
├── Examples/
├── Package.swift
├── README.md
├── TODO.md
├── Sources/
├── Tests/
├── remoteDock/
└── remoteDock.xcodeproj/
```

下面按仓库中几个最重要的入口来说明。

### `Package.swift`

Swift Package Manager 的入口文件。  
这个文件声明了一个名为 `RemoteDockCore` 的本地 Swift Package。

在本项目里它大致表示：

- 产物：`RemoteDockCore` 库
- 源码：`Sources/RemoteDockCore/`
- 测试：`Tests/RemoteDockCoreTests/`
- 示例配置：`Examples/`

### `Examples/`

这里放的是仓库内维护的示例配置文件。

- `current-config.json`：当前推荐的完整配置文档
- `legacy-hosts-array.json`：旧版只保存主机数组的历史格式

这两个文件不仅用于阅读，也会被测试直接读取，确保示例内容不会和真实数据模型脱节。

### `Sources/RemoteDockCore/`

这是核心逻辑源码目录。  
这里的文件大多是“纯 Swift 逻辑”，不负责画界面。

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

如果用更常见的分层术语描述，这里大致可以视为 **domain + service** 层。

### `Tests/RemoteDockCoreTests/`

这是核心逻辑的测试目录。

当前测试集中在 `RemoteDockCore`，因为这些逻辑更容易脱离界面测试。

例如：

- `RemoteHostTests.swift`：测试主机字段归一化、推导目录、复制命名等
- `HostStoreTests.swift`：测试配置读写和旧格式迁移
- `SSHCommandBuilderTests.swift`：测试 SSH 命令和 follow-up 命令生成
- `SSHURLBuilderTests.swift`：测试 `ssh://` URL 拼装
- `PingServiceTests.swift`：测试 ping 重试和解析逻辑
- `TailscaleServiceTests.swift`：测试 CLI 路径探测和命令结果处理

### `remoteDock/`

这是 **App target 的源码目录**。  
在 Xcode 的项目树中，绝大多数界面相关代码都在这里。

它又分成几类：

#### `remoteDock/remoteDockApp.swift`

应用入口。  
相当于“这个 macOS App 从哪里启动、有哪些 Scene（主窗口、设置、菜单栏）”。

#### `remoteDock/ContentView.swift`

主窗口的页面级协调器。  
它负责：

- 加载配置
- 维护主机列表状态
- 管理搜索、筛选、选中项
- 把动作分发给子视图和服务层

它不是唯一的 UI 文件，但它是主窗口的数据流中心。

#### `remoteDock/Views/`

这里是拆分出来的 SwiftUI 视图组件。

例如：

- `DashboardHeaderView.swift`：顶部统计和全局操作
- `HostsSidebarView.swift`：左侧列表、搜索、筛选
- `HostDetailView.swift`：右侧详情页容器
- `HostCard.swift`：右侧动作卡片
- `HostEditorView.swift`：新增 / 编辑主机表单
- `GroupManagerView.swift`：分组管理弹窗
- `SettingsView.swift`：设置面板
- `MenuBarHostsView.swift`：菜单栏中的主机菜单
- `FeedbackBannerView.swift`：顶部反馈条
- `ConfigPathFooterView.swift`：底部配置路径栏
- `TailscaleStatusSheetView.swift`：Tailscale 状态弹窗

如果用前端语境来类比，这里可以近似理解成 **UI components**。

#### `remoteDock/Services/`

这些是 App 层的系统集成服务。  
和 `RemoteDockCore` 不同，这里允许依赖 AppKit、系统剪贴板、Ghostty、VS Code 等 macOS 环境。

当前主要有：

- `ClipboardService.swift`：复制文本到系统剪贴板
- `TerminalService.swift`：通过 AppleScript 控制 Ghostty
- `VSCodeService.swift`：调用 VS Code CLI 打开 Remote SSH

#### `remoteDock/Models/`

这里放的是更贴近 App / UI 的模型和桥接类型，而不是核心配置模型。

例如：

- `HostStatus.swift`：界面里的在线状态
- `AppSettings.swift`：设置项 key、默认值、解析逻辑
- `FocusedHostActions.swift`：把当前选中的主机动作暴露给菜单命令系统

### `remoteDock.xcodeproj/`

这是 Xcode 工程文件目录。  
通常不需要手动编辑它，除非在做：

- target 配置调整
- build setting 变更
- 新增资源
- package 依赖调整

大多数日常开发场景下，只需要在 Xcode 中打开它即可。

### `TODO.md`

项目规划和待办记录。

### `README.md`

你现在正在看的这份文档。

---

## 当前代码分层可以怎么理解

如果你把整个项目粗略拆成一条调用链，大致是这样：

```text
SwiftUI View
  -> ContentView / 页面状态
    -> App Services（Clipboard / Ghostty / VS Code）
    -> RemoteDockCore（配置 / SSH 命令 / Ping / Tailscale）
      -> 本地文件 / 系统命令 / 外部 App
```

更具体一点：

1. 用户在界面里点按钮
2. 视图把动作交回 `ContentView`
3. `ContentView` 决定要调用哪个服务
4. 服务层或 Core 层真正执行：
   - 读写 `hosts.json`
   - 调 `ping`
   - 调 `tailscale status`
   - 生成 SSH 命令
   - 调 Ghostty / VS Code
5. 结果再回到 `ContentView`
6. SwiftUI 根据最新状态刷新界面

这也是为什么项目里会有很多“视图只接收闭包，不直接做副作用”的写法：  
这样数据流会更清楚。

---

## 当前功能概览

这一节除了列出功能，也补充这些功能在项目中的定位。

### 主机管理

- 从本地 JSON 配置文件加载主机列表
- 首次启动时自动创建默认配置
- 在界面中新增、编辑、删除、排序主机
- 支持为主机设置分组，并在 sidebar 中分组展示
- 支持创建、重命名、删除、排序分组
- 删除分组后，原本属于该分组的主机会自动回到未分组状态
- 支持复制主机为新条目，默认名称为 `{old host} copy`

这一组功能的重点是把远程主机当成长期维护的数据，而不是一次性的临时命令。

整体上，RemoteDock 更倾向于把一组长期使用的机器沉淀为本地配置：

- 主机本身有稳定身份
- 主机可以归类到分组
- 主机顺序可以调整
- 主机可以被复制后再微调

相比“只存一行 SSH 命令”，这种方式更适合持续整理和维护远程环境。

### 连接与打开方式

- `Open in Ghostty`
- `Open in Default Terminal`
- `Open in VS Code`
- 每台主机可以设置自己的首选打开方式
- 如果主机没有单独设置，则使用全局默认打开方式

这一组功能对应的是“同一台主机，在不同场景下有不同入口”这一类需求。

典型场景包括：

- 排查问题时更适合直接进终端
- 修改项目代码时更适合直接进 VS Code Remote
- 某些主机长期偏向某一种打开方式

因此项目把“打开方式”设计成了一个明确的可配置策略：

- **全局默认值**：适合作为团队或个人的通用偏好
- **主机级覆盖**：适合某些特殊机器，例如只适合用 VS Code 打开的开发机，或只适合直接 SSH 的小型服务器

这也是为什么右侧会有一个“主按钮 + 备用打开方式”的结构：  
高频动作尽量一键完成，低频动作仍然保留但不抢占主界面。

### 配置与复制

- 复制 SSH 命令
- 复制 IP / 地址
- 复制主机详情摘要
- 复制单主机 JSON 配置片段
- 复制完整配置文档 JSON
- 复制配置文件路径

这一组功能主要面向三个目的：

1. **快速复用**  
   例如把 SSH 命令直接发到终端、文档、聊天工具里。

2. **配置可见性**  
   当你怀疑某台主机为什么打不开时，可以直接把它的配置复制出来核对。

3. **备份与迁移**  
   复制单主机 JSON 或完整配置 JSON，可以很方便地手动保存、分享或做临时迁移。

这里的设计重点是：  
应用内部虽然有自己的数据模型，但这些数据并不被锁定在 GUI 内部。  
配置仍然保持可查看、可复制、可导出，也保留了手工编辑的空间。

### 状态与检测

- 单主机 Ping
- 全量 Ping
- 显示 Online / Offline / Checking / Not checked
- 显示最近一次检测时间
- 显示平均延迟
- 启动时自动执行一次全量 Ping
- 支持全局和单主机级别的自动 Ping 策略

这一组功能主要提供连接前的轻量状态参考。

RemoteDock 并不尝试做完整监控系统，而是提供一层轻量的可达性反馈：

- **Online / Offline**：快速判断当前能不能连
- **Checking**：表示当前正在等待探测结果
- **Last checked**：表示当前状态的新鲜度
- **Latency**：给一个非常粗略但有参考价值的网络感觉

这里使用 `ping`，而不是更复杂的 SSH 握手探测，主要基于以下考虑：

- ping 足够轻量
- 没有引入额外认证和密钥处理复杂度
- 对大多数“先看机器是不是在线”的场景已经够用

同时，自动 Ping 又被设计成了“全局默认 + 主机级覆盖”的模式，原因是：

- 有些机器适合频繁心跳
- 有些机器不值得一直打
- 有些机器你只想手动检查

这里更偏向**行为可配置**，而不是固定的一刀切后台轮询。

### 菜单栏与全局操作

- 菜单栏入口显示主机和分组
- 菜单栏里可快速打开主机、Ping、复制 SSH 命令
- App 菜单里有 `RemoteDock` 命令组
- 支持为“打开当前主机”“Ping 当前主机”配置快捷键

这一组功能反映的是一个明确的使用假设：

> 远程操作并不总需要先进入完整主窗口。

因此除了主窗口，项目还提供了两个更轻量的入口：

- **菜单栏入口**：适合快速操作和状态查看
- **App 菜单命令 / 快捷键**：适合当前已经在主窗口里工作，只想更快触发动作

这样会形成三层入口：

1. **主窗口**：最完整，适合管理配置和查看细节
2. **菜单栏**：最轻量，适合快速打开和快速 Ping
3. **快捷键 / 菜单命令**：最直接，适合高频用户

这也是项目里一个比较核心的设计方向：  
**同一个功能，允许在不同交互密度下被使用。**

### Tailscale 相关

- 识别看起来像 Tailscale 的地址
- 提供 `Local Tailscale` 动作
- 显示并复制本机 `tailscale status`

这里有一个比较明确的设计选择：

`Local Tailscale` 展示的是**本机**的 Tailscale 状态，而不是远程主机自身的状态。

它的作用更偏向本地上下文确认，而不是远端监控：

- 当前 Mac 是否已经接入 tailnet
- 本地 Tailscale CLI 是否可用
- 某台 Tailscale 主机无法访问时，是否先从本机网络状态排查

因此这个按钮更像一个**上下文辅助工具**，而不是远端状态面板的一部分。

---

## 功能如何组合成一个完整工作流

从产品行为上看，RemoteDock 覆盖的是一条完整但轻量的本地工作流：

### 1. 维护主机配置

第一步是把常用机器整理成结构化数据：

- 名称
- 用户名
- 地址
- 端口
- 远程目录
- 分组
- 首选打开方式
- 自动 Ping 策略

### 2. 在主窗口里浏览和筛选

通过左侧 sidebar：

- 看所有机器
- 按组看
- 按状态看
- 按搜索词查找

### 3. 在右侧详情里执行核心动作

进入选中主机后，常见动作包括：

- 现在要不要直接打开
- 是复制命令还是复制配置
- 是否需要先 Ping
- 是否需要改分组、编辑、复制出一个副本

### 4. 在后台获得轻量状态更新

通过启动时全量 Ping 和后续自动 Ping，界面会逐步从“静态配置列表”变成“带一点实时感知的工作台”。

### 5. 在非主窗口场景下继续使用

在不打开主窗口的场景下，还可以：

- 从菜单栏快速打开某台主机
- 从菜单命令和快捷键直接操作当前选中主机

因此这个项目的重点并不在某一个孤立功能，而在于这些功能能否自然地衔接成完整链路。

---

## 设计思路与取舍

这一节更偏向设计说明，用来补充各个功能背后的取舍。

### 1. 配置优先，而不是会话优先

RemoteDock 的核心数据是“主机配置”，不是“终端会话”。

也就是说，应用更关心：

- 这台机器是谁
- 该怎么打开它
- 该怎么保存它的元数据

而不关心：

- 终端里滚了多少输出
- 会话历史怎么回放
- 多标签页怎么托管

这里的边界比较明确：  
RemoteDock 管“入口”和“配置”，终端本身仍由 Ghostty / 系统终端 / VS Code 处理。

### 2. 轻自动化，而不是重接管

项目确实会调用：

- AppleScript 控制 Ghostty
- `open` 调默认终端
- `code --remote`
- `ping`
- `tailscale status`

但它并不打算重新实现这些工具本身。

设计上更像是：

- **复用成熟工具**
- **统一它们的入口**
- **把上下文配置补上**

这种取向让项目保持在较小而清晰的范围内，也更符合个人长期维护工具的定位。

### 3. 数据可导出、可理解、可手改

本地配置使用 JSON，而不是隐藏数据库。

这是一个比较典型的工具型软件选择，因为它带来几个明显特点：

- 容易备份
- 容易 diff
- 容易迁移
- 容易临时手改
- 不必被 GUI 限制表达能力

所以项目里才会保留：

- 复制单主机 JSON
- 复制完整配置 JSON
- 显示配置路径

这些动作并不是面向极简消费级应用的取向，但和开发者工具的使用习惯很贴近。

### 4. 主窗口是完整入口，菜单栏是轻入口

项目没有试图把所有功能都塞进菜单栏，也没有只做菜单栏。

而是明确区分：

- **主窗口**：管理、编辑、看细节
- **菜单栏**：快速访问、快速判断、快速操作

背后对应的是一种按使用频率分层的界面组织方式：

- 低频但复杂的动作放主窗口
- 高频但简单的动作放菜单栏

### 5. 核心逻辑尽量从 SwiftUI 中抽离

从代码组织上看，项目刻意把这些内容抽到了 `RemoteDockCore`：

- 模型
- 配置读写
- 命令生成
- Ping
- Tailscale

这样拆分并不是为了形式上的分层，而是因为这些逻辑天然更适合：

- 复用
- 测试
- 独立思考
- 在未来被界面替换

这也是为什么当前测试重点覆盖的是 `RemoteDockCore`，而不是每一个 SwiftUI 视图。

### 6. 优先做可解释的功能，而不是隐藏魔法

很多行为在项目里都被设计得比较“显性”：

- 可以看到当前配置文件路径
- 可以知道主机属于哪个组
- 可以看到当前状态是何时检测出来的
- 可以复制导出的 JSON
- 可以区分全局默认值和主机级覆盖值

这更接近一种工程工具的设计取向：

> 信息更显性，行为也更容易理解。

### 7. 默认行为尽量安全、可预测

例如：

- 搜索时改成扁平 `Results`，避免分组信息干扰搜索理解
- 删除分组后让主机回到 `Ungrouped`，而不是保留无效引用
- 自动 Ping 可以主机级禁用
- 复制动作给明确反馈
- 打开方式有全局默认，也允许局部覆盖

这些都不是大功能，但它们共同决定了工具在长期使用中的稳定感和可预期性。

---

## 环境要求

- macOS
- Xcode 26 或更新版本
- Swift 6 工具链（Xcode 26 自带）
- 可选：
  - Ghostty
  - Visual Studio Code
  - Tailscale

如果你只是想看代码或跑核心测试，不一定需要安装 Ghostty / VS Code / Tailscale。  
但如果你想体验对应按钮的真实行为，就需要本机装好这些工具。

---

## 使用 Xcode 运行

对于完整 App 的体验，Xcode 仍然是最直接的入口。

### 1. 打开项目

```bash
open remoteDock.xcodeproj
```

这会启动 Xcode 并打开工程文件。

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
- 左侧导航栏：看项目文件
- 顶部报错区域 / Issue Navigator：看编译错误

---

## 使用命令行构建

如果更偏向终端工作流，这个仓库也提供了两种常见的命令行入口，对应不同层级的构建目标。

### 1. 只构建和测试核心逻辑：`swift build` / `swift test`

这套命令面向 `Package.swift`，也就是 **RemoteDockCore**。

#### 构建核心包

```bash
swift build
```

它会构建：

- `Sources/RemoteDockCore/` 中的代码

但**不会**生成完整的 `.app` 桌面应用。

#### 运行核心测试

```bash
swift test
```

它会运行：

- `Tests/RemoteDockCoreTests/`

这更适合：

- 验证核心逻辑有没有被改坏
- 不想打开 Xcode，只想快速跑测试

### 2. 构建完整 macOS App：`xcodebuild`

这套命令面向 `remoteDock.xcodeproj`，也就是 **整个 App**。

当前仓库常用的完整构建命令如下：

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
| `-destination 'platform=macOS'` | 说明这是 macOS 构建，不是 iPhone 模拟器 |
| `-derivedDataPath .DerivedData` | 把构建产物放到仓库里的 `.DerivedData`，方便查找 |
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

---

## 一个最实用的日常开发流程

如果你想改代码，通常可以按这个顺序：

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

---

## 核心测试现在覆盖什么

当前 `RemoteDockCore` 有 **63 个测试**，主要覆盖：

- `RemoteHost`
  - 主机识别
  - 默认目录推导
  - 端口归一化
  - 自动 Ping 字段
  - 复制命名规则
- `HostStore`
  - 默认配置写入
  - JSON 读写
  - 旧配置迁移
  - 非法 JSON 错误
  - 示例配置文件校验与迁移
- `SSHCommandBuilder`
  - Linux / Windows follow-up 命令
  - 路径与引号转义
- `SSHURLBuilder`
  - 默认终端 `ssh://` URL
- `TailscaleService`
  - CLI 路径探测
  - 命令输出和错误映射
- `PingService`
  - 重试逻辑
  - 延迟 / 丢包解析
  - 依赖注入

当前测试主要集中在核心逻辑层，而不是 SwiftUI 界面层。

这在 SwiftUI 项目里是很常见的做法：  
先把容易回归、容易写错的纯逻辑锁住。

---

## 配置文件在哪里

RemoteDock 会把主机配置保存在：

```text
~/Library/Application Support/RemoteDock/hosts.json
```

首次启动时，如果这个文件不存在，应用会自动创建一个默认配置。

你也可以在应用底部直接看到并复制这个路径。

---

## 配置文件长什么样

当前配置文件是一个**文档对象**，而不是单纯的主机数组。

也就是说，最外层不是：

```json
[
  { "name": "..." }
]
```

而是：

```json
{
  "groups": [...],
  "hosts": [...]
}
```

示例：

```json
{
  "groups": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "Lab"
    }
  ],
  "hosts": [
    {
      "address": "100.117.140.113",
      "autoPingIntervalMinutes": 5,
      "groupID": "11111111-1111-1111-1111-111111111111",
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Arch T480s",
      "preferredOpenMode": "ghostty",
      "port": 22,
      "remoteDirectory": "/home/elaine",
      "startupCommand": "cd -- {remoteDirectory} && exec zsh -l",
      "username": "elaine"
    }
  ]
}
```

仓库里也放了两份可直接参考的示例文件：

- `Examples/current-config.json`
  - 当前推荐的完整文档格式
- `Examples/legacy-hosts-array.json`
  - 旧版只保存 `[RemoteHost]` 的历史格式，方便理解迁移前后差异

### 字段说明

#### `groups`

一个分组数组。每个分组至少有：

- `id`
- `name`

#### `hosts`

一个主机数组。常见字段有：

- `id`：主机唯一标识
- `name`：显示名称
- `username`：SSH 用户名
- `address`：主机地址
- `port`：可选端口
- `groupID`：所属分组
- `remoteDirectory`：远程目录
- `startupCommand`：登录后执行的命令
- `preferredOpenMode`：首选打开方式
- `autoPingIntervalMinutes`：主机级自动 Ping 间隔
- `autoPingDisabled`：是否显式关闭自动 Ping

### 兼容旧配置

旧版本如果只保存了 `[RemoteHost]`，应用下次读取时会自动迁移到新格式。

如果 JSON 损坏，RemoteDock 会在界面里报错，并临时回退到默认主机列表；它不会悄悄覆盖坏文件。

---

## `startupCommand` 是做什么的

这个字段表示：

> SSH 登录成功以后，远端还要再执行什么命令

例如：

### Linux 示例

```text
cd -- {remoteDirectory} && exec zsh -l
```

含义是：

1. 进入远程目录
2. 再启动一个登录态的 zsh

### Windows 示例

```text
call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}"
```

含义是：

1. 调用远端 Windows 机器上的包装脚本
2. 包装脚本再负责切目录、打开 PowerShell、加载 profile 等

其中：

```text
{remoteDirectory}
```

会在运行时替换成当前主机配置里的目录。

---

## Windows 主机的推荐做法

如果目标是 Windows，推荐把复杂启动逻辑放到远端 wrapper 脚本里，而不是直接在 `startupCommand` 里写一大串 PowerShell 命令。

推荐远端脚本位置：

```text
%USERPROFILE%\bin\remote.cmd
```

示例：

```bat
@echo off
set "TARGET=%~1"
if not defined TARGET set "TARGET=%USERPROFILE%"
cd /d "%TARGET%"
"C:\Users\Elaine\scoop\apps\pwsh\7.6.0\pwsh.exe" -NoLogo -NoExit -NoProfile -Command ". '%USERPROFILE%\Documents\PowerShell\RemoteDockProfile.ps1'"
```

然后在 RemoteDock 里配置：

```text
call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}"
```

这么做的原因很实际：

- Windows 远程命令链路更脆弱
- Scoop shim / `current` junction 在远程 SSH 场景下不一定稳定
- wrapper 脚本更容易调试和维护

---

## 菜单栏和 App 菜单提供什么

如果启用了菜单栏图标，菜单栏入口会提供：

- `Show Main Window`
- `Ping All Hosts`
- 主机数量和状态摘要
- 按分组展示主机
- 每台主机的快捷子菜单
  - 按默认方式打开
  - Ping
  - 复制 SSH 命令
  - 复制主机详情
  - 查看状态、最近检测时间、延迟
- `Reload Hosts`
- `Quit RemoteDock`

App 菜单里还有 `RemoteDock` 命令组，用于：

- 打开当前选中的主机
- Ping 当前选中的主机

快捷键可以在 `Settings` 中修改或禁用。

---

## macOS 权限与系统集成说明

### Ghostty 自动化

`Open in Ghostty` 通过 AppleScript 控制 Ghostty。

第一次使用时，macOS 可能会弹出 Automation 权限提示。  
你需要允许 `RemoteDock` 控制 `Ghostty`，这个功能才会正常工作。

### 默认终端

`Open in Default Terminal` 不依赖 Ghostty。  
它会把 `ssh://user@host[:port]` 交给系统默认 SSH URL 处理器。

### Tailscale

`Local Tailscale` 会优先查找：

1. Tailscale.app 自带 CLI
2. Homebrew 常见安装路径
3. 常见系统路径

所以即使图形界面 App 的 PATH 不完整，也不一定影响这个功能。

### App Sandbox

这个工具需要：

- 启动系统命令
- 读取本地配置文件
- 调用 `ping`
- 调用外部应用

所以当前没有启用严格的 App Sandbox。

---

## 对第一次读 SwiftUI 项目的人，一个简单阅读顺序

如果你想从代码结构上看懂这个仓库，推荐顺序：

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

这个顺序比较符合“先看入口，再看页面，再看核心逻辑，最后看测试”的学习路径。

---

## 当前仓库适合做什么

这个项目很适合用来练这些内容：

- SwiftUI 基础状态驱动界面
- macOS App 基础结构
- Swift Package Manager
- Xcode 工程与本地 package 依赖
- 纯逻辑层与 UI 层分离
- 用测试保护核心业务逻辑

如果你是从前端或后端转来看 Swift，这个仓库的价值不在“功能特别大”，而在于它结构相对小、层次比较清楚，适合边跑边读。
