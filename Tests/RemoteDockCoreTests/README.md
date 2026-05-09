# RemoteDockCoreTests (`Tests/RemoteDockCoreTests/`)

这个目录包含 `RemoteDockCore` 的测试代码。

测试重点放在核心逻辑层，而不是 SwiftUI 界面层。  
这样做的好处是：

- 运行速度更快
- 行为更稳定
- 更容易覆盖边界情况
- 对重构更有保护作用

## 当前测试文件

- `RemoteHostTests.swift`
  - 覆盖主机模型的字段归一化、默认值推导、复制命名规则等

- `HostStoreTests.swift`
  - 覆盖配置文件创建、保存、读取、迁移和错误处理
  - 也会直接读取仓库中的 `Examples/*.json`，确保示例配置和真实模型保持同步

- `SSHCommandBuilderTests.swift`
  - 覆盖 SSH 命令拼接、路径转义、Linux / Windows follow-up 命令

- `SSHURLBuilderTests.swift`
  - 覆盖默认终端使用的 `ssh://` URL 生成

- `PingServiceTests.swift`
  - 覆盖 Ping 重试、结果传递和输出解析

- `TailscaleServiceTests.swift`
  - 覆盖 Tailscale CLI 路径探测、命令执行结果和错误映射

## 测试风格

这些测试大多围绕“输入一段配置或命令输出，应该得到什么结果”来写。  
因此它们比较适合保护：

- 推导规则
- 迁移逻辑
- 文本解析
- 命令生成

也正因为如此，这一层的测试对重构很有价值：只要行为没变，内部实现通常可以自由调整。
