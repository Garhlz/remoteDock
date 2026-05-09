# Services (`remoteDock/Services/`)

这个目录包含 **App 层的系统集成服务**。

它们和 `RemoteDockCore` 的区别在于：这里允许直接依赖 macOS 环境，例如：

- `AppKit`
- 系统剪贴板
- AppleScript / `osascript`
- 本机安装的 VS Code

这些服务通常由 `ContentView` 或菜单栏视图调用，用来把“用户点击了一个动作”翻译成真实的系统行为。

## 当前文件

- `ClipboardService.swift`
  - 负责把文本写入系统剪贴板

- `TerminalService.swift`
  - 通过 AppleScript 控制 Ghostty
  - 把 SSH 命令发送到 Ghostty 新窗口或当前窗口

- `VSCodeService.swift`
  - 查找本机可用的 VS Code / VS Code Insiders CLI
  - 调用 `code --remote` 打开远程目录

## 设计位置

这一层主要处理“副作用”：

- 调外部应用
- 调系统命令
- 写剪贴板

而像 SSH 命令应该长什么样、主机配置怎么存、Ping 结果怎么解析，这些更偏纯逻辑的内容则放在 `RemoteDockCore`。
