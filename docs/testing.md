# 测试说明

## 当前测试覆盖什么

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

## 为什么重点测试 `RemoteDockCore`

这在 SwiftUI 项目里是很常见的做法：先把容易回归、容易写错的纯逻辑锁住。

这一层更适合保护：

- 推导规则
- 配置迁移
- 命令生成
- 文本解析
- 错误映射

## 测试目录结构

测试位于：

```text
Tests/RemoteDockCoreTests/
```

当前主要包括：

- `RemoteHostTests.swift`
- `HostStoreTests.swift`
- `SSHCommandBuilderTests.swift`
- `SSHURLBuilderTests.swift`
- `PingServiceTests.swift`
- `TailscaleServiceTests.swift`

## 示例配置如何参与测试

仓库根目录的 `Examples/` 中有两份示例配置：

- `Examples/current-config.json`
- `Examples/legacy-hosts-array.json`

它们不只是文档示例，也会被 `HostStoreTests.swift` 直接读取：

- 当前格式示例会被解码校验
- 旧格式示例会被加载、迁移并重新持久化

这样做的好处是：示例配置不会随着模型演进慢慢过期。
