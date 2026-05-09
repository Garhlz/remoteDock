# Models (`remoteDock/Models/`)

这个目录放的是 **App 层使用的模型与桥接类型**。

这里的类型和 `RemoteDockCore` 中的核心配置模型不同：  
它们更贴近界面状态、设置读取和 SwiftUI / Commands 之间的连接。

## 当前文件

- `AppSettings.swift`
  - 定义设置项 key、默认值
  - 负责把 `UserDefaults` 中的字符串恢复成可用枚举
  - 为设置页和主窗口提供统一的设置解释逻辑

- `FocusedHostActions.swift`
  - 定义 `FocusedValueKey`
  - 把“打开当前主机”“Ping 当前主机”等动作从当前场景暴露给菜单命令系统

- `HostStatus.swift`
  - 定义界面中的主机状态语义
  - 为状态提供统一的颜色和图标映射

## 这一层的定位

这些类型通常不会直接负责：

- 配置文件读写
- SSH 命令拼接
- Ping 执行

它们更像是 UI 和底层逻辑之间的中间层，用于把系统设置、界面状态和命令入口组织起来。
