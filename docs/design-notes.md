# 设计说明

## 设计思路与取舍

### 1. 配置优先，而不是会话优先

RemoteDock 的核心数据是“主机配置”，不是“终端会话”。

它更关心：

- 这台机器是谁
- 该怎么打开它
- 该怎么保存它的元数据

而不关心：

- 终端里滚了多少输出
- 会话历史怎么回放
- 多标签页怎么托管

RemoteDock 管“入口”和“配置”，终端本身仍由 Ghostty / 系统终端 / VS Code 处理。

### 2. 轻自动化，而不是重接管

项目会调用：

- AppleScript 控制 Ghostty
- `open` 调默认终端
- `code --remote`
- `ping`
- `tailscale status`

但它并不打算重新实现这些工具本身。设计上更像是：

- 复用成熟工具
- 统一它们的入口
- 把上下文配置补上

### 3. 数据可导出、可理解、可手改

本地配置使用 JSON，而不是隐藏数据库。

这样做的好处是：

- 容易备份
- 容易 diff
- 容易迁移
- 容易临时手改

所以项目里保留了：

- 复制单主机 JSON
- 复制完整配置 JSON
- 显示配置路径

### 4. 主窗口是完整入口，菜单栏是轻入口

项目明确区分：

- **主窗口**：管理、编辑、看细节
- **菜单栏**：快速访问、快速判断、快速操作

### 5. 核心逻辑尽量从 SwiftUI 中抽离

从代码组织上看，项目刻意把这些内容抽到了 `RemoteDockCore`：

- 模型
- 配置读写
- 命令生成
- Ping
- Tailscale

这样更适合：

- 复用
- 测试
- 独立思考
- 在未来被界面替换

### 6. 优先做可解释的功能，而不是隐藏魔法

很多行为在项目里都被设计得比较“显性”：

- 可以看到当前配置文件路径
- 可以知道主机属于哪个组
- 可以看到当前状态是何时检测出来的
- 可以复制导出的 JSON
- 可以区分全局默认值和主机级覆盖值

### 7. 默认行为尽量安全、可预测

例如：

- 搜索时改成扁平 `Results`
- 删除分组后让主机回到 `Ungrouped`
- 自动 Ping 可以主机级禁用
- 复制动作给明确反馈
- 打开方式有全局默认，也允许局部覆盖

## macOS 权限与系统集成说明

### Ghostty 自动化

`Open in Ghostty` 通过 AppleScript 控制 Ghostty。

第一次使用时，macOS 可能会弹出 Automation 权限提示。你需要允许 `RemoteDock` 控制 `Ghostty`。

### 默认终端

`Open in Default Terminal` 不依赖 Ghostty。它会把 `ssh://user@host[:port]` 交给系统默认 SSH URL 处理器。

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

## 当前仓库适合做什么

这个项目很适合用来练这些内容：

- SwiftUI 基础状态驱动界面
- macOS App 基础结构
- Swift Package Manager
- Xcode 工程与本地 package 依赖
- 纯逻辑层与 UI 层分离
- 用测试保护核心业务逻辑
