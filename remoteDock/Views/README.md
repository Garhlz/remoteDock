# Views (`remoteDock/Views/`)

这个目录包含 RemoteDock 的 **SwiftUI 视图组件**。

这些文件主要负责界面拆分和布局表达。  
它们通常不直接做复杂业务逻辑，而是：

- 接收上层传入的数据
- 渲染界面
- 在用户交互时调用闭包，把动作交回上层

这种结构使 `ContentView.swift` 保持页面级协调角色，而具体的 UI 片段可以保持独立和可读。

## 当前视图

- `DashboardHeaderView.swift`：顶部统计与全局操作
- `HostsSidebarView.swift`：左侧主机列表、搜索、筛选、分组展示
- `HostDetailView.swift`：右侧详情页容器
- `HostCard.swift`：右侧主操作卡片
- `HostEditorView.swift`：新增 / 编辑主机表单
- `GroupManagerView.swift`：分组管理弹窗
- `SettingsView.swift`：设置面板
- `MenuBarHostsView.swift`：菜单栏中的主机快捷菜单
- `FeedbackBannerView.swift`：顶部反馈条
- `ConfigPathFooterView.swift`：底部配置路径与维护动作
- `TailscaleStatusSheetView.swift`：Tailscale 状态弹窗

## 设计特点

这里的视图大多遵循同一种模式：

1. 上层准备好状态和数据
2. 视图只负责展示
3. 用户触发动作后，通过闭包回传给上层

这使 UI 组件更接近“声明式界面组件”，而不是隐含很多副作用的控制器。
