# App Target (`remoteDock/`)

这个目录包含 RemoteDock 的 **macOS App 层代码**。

它主要负责：

- SwiftUI 主窗口与子视图
- 设置面板和菜单栏入口
- 与系统能力交互，例如剪贴板、Ghostty、VS Code

从分层上看，这里更接近应用外壳与界面层；真正偏纯逻辑、可测试的核心能力则放在 `Sources/RemoteDockCore/`。

## 主要文件

- `remoteDockApp.swift`：应用入口，声明主窗口、设置页和菜单栏 Scene
- `ContentView.swift`：主窗口页面级协调器，负责状态、加载配置和动作分发
- `RemoteDockCommands.swift`：App 菜单中的命令组和快捷键入口

## 子目录

- `Models/`：App 层使用的状态模型与桥接类型
- `Services/`：依赖 macOS 环境的系统集成服务
- `Views/`：SwiftUI 视图组件
- `Assets.xcassets/`：图标、颜色等资源

整体调用链通常是：

```text
View -> ContentView -> App Services / RemoteDockCore -> system
```

也就是说，这一层更关注“如何展示”和“如何把用户动作转成系统调用”。
