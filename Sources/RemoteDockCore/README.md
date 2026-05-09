# RemoteDockCore (`Sources/RemoteDockCore/`)

这个目录是项目的 **核心逻辑模块**。

它由 Swift Package Manager 管理，是仓库中最接近“可复用纯逻辑层”的部分。  
这里尽量不依赖 SwiftUI，也尽量避免直接依赖 AppKit。

## 主要职责

- 定义主机与配置文档模型
- 读取和保存本地 JSON 配置
- 兼容旧配置格式并做迁移
- 生成 SSH 命令与 `ssh://` URL
- 执行 Ping 并解析结果
- 读取 Tailscale CLI 状态
- 提供稳定的 JSON 导出格式

## 当前文件

- `RemoteHost.swift`：单台主机配置模型
- `RemoteDockConfiguration.swift`：完整配置文档模型
- `HostGroup.swift`：分组模型
- `PreferredOpenMode.swift`：首选打开方式枚举
- `HostStore.swift`：配置读写与迁移入口
- `SSHCommandBuilder.swift`：SSH 命令拼接
- `SSHURLBuilder.swift`：默认终端用的 `ssh://` URL 拼接
- `DefaultTerminalService.swift`：默认终端打开逻辑
- `PingService.swift`：Ping 执行与延迟 / 丢包解析
- `TailscaleService.swift`：Tailscale CLI 状态读取
- `JSONExportFormatter.swift`：稳定 JSON 输出工具

## 为什么这一层单独存在

把这些逻辑放在独立模块里有几个直接好处：

- 更容易测试
- 更容易在不打开 App 的情况下构建和验证
- 界面层改动不会直接搅乱核心逻辑
- 未来如果需要复用逻辑，边界更清晰

在仓库里，`swift build` 和 `swift test` 主要面向的就是这一层。
