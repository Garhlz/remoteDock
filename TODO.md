# RemoteDock TODO

这个文件用于记录 RemoteDock 接下来的开发计划。任务应该尽量保持小而清晰，最好每个任务都可以独立形成一次提交。

## 下一步

- [x] 拆分 `ContentView.swift`：
  - `Models/RemoteHost.swift`
  - `Models/HostStatus.swift`
  - `Views/HostCard.swift`
  - `Services/PingService.swift`
- [x] 当 `Open SSH` 失败时，在界面上显示明确的错误信息。
- [x] 为每台主机增加 `Copy IP` 操作。
- [x] 在顶部增加 `Ping All` 按钮，一次检测所有主机。

## 近期

- [ ] 把当前写死的主机列表移动到本地 JSON 文件。
- [ ] 增加一个基础主机编辑界面，用于修改名称、用户名和地址。
- [ ] 增加 VS Code Remote 命令支持。
- [ ] 增加 Tailscale 状态查看操作。
- [ ] 优化复制反馈，让 `Copy SSH` 和 `Copy IP` 的提示更清楚。
- [ ] 增加简单的状态更新时间，例如 `Last checked`。

## 以后

- [ ] 把纯 Swift 逻辑抽成 `RemoteDockCore` Swift Package。
- [ ] 为 SSH 命令生成和 Ping 状态解析增加单元测试。
- [ ] 考虑增加菜单栏模式。
- [ ] 添加应用图标，并做基础视觉优化。
- [ ] 为 Windows 主机增加可选的 RDP 或文件共享快捷入口。

## 备注

- Xcode 项目继续作为 macOS App 外壳使用。
- 先把可复用、可测试的逻辑拆到独立 Swift 文件中；当逻辑变多后，再考虑 Swift Package。
- 在手动工作流足够稳定之前，暂时不要急着增加配置同步、自动发现或后台常驻功能。
