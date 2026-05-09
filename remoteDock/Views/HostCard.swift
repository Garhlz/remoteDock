//
//  HostCard.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI
import RemoteDockCore

/// 右侧详情页中的主操作卡片，集中展示打开、复制和管理动作。
///
/// 设计上它只关心“展示哪些按钮、点下去调用哪个闭包”，
/// 并不关心按钮背后到底是打开终端、复制到剪贴板，还是修改配置文件。
/// 这种写法能让视图保持轻量，把副作用留在上层处理。
struct HostCard: View {
    let preferredOpenMode: PreferredOpenMode
    let status: HostStatus
    let copiedLabel: String?
    let openPreferred: () -> Void
    let copySSHCommand: () -> Void
    let copyIPAddress: () -> Void
    let copyHostDetails: () -> Void
    let copyHostConfiguration: () -> Void
    let openSSH: () -> Void
    let openDefaultTerminal: () -> Void
    let openVSCodeRemote: () -> Void
    let showTailscaleStatus: () -> Void
    let showsTailscaleStatusAction: Bool
    let ping: () -> Void
    let duplicate: () -> Void
    let edit: () -> Void
    let delete: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
    @State private var isShowingAlternateOpenMenu = false

    var body: some View {
        /// 这个卡片的结构分三层：
        /// 1. 顶部：标题、排序、状态、更多菜单；
        /// 2. 中间：主打开动作 + 备用打开方式；
        /// 3. 底部：复制、Ping、Tailscale 等快捷操作。
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Actions")
                        .font(.headline)

                    Label("Primary: \(preferredOpenMode.title)", systemImage: preferredOpenMode.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                reorderButtons
                statusBadge
                moreMenu
            }

            HStack(spacing: 10) {
                primaryActionButton

                alternateOpenButton
            }

            Divider()

            HStack(spacing: 8) {
                quickActionButtons

                if showsTailscaleStatusAction {
                    actionPill(
                        title: "Local Tailscale",
                        systemImage: "wave.3.right.circle",
                        action: showTailscaleStatus
                    )
                }

                Spacer(minLength: 0)
            }
            .buttonStyle(.bordered)
        }
        .padding(22)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary)
        }
        .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
    }

    private var statusBadge: some View {
        /// 右上角状态胶囊和详情页顶部状态保持同一套颜色/图标语义，
        /// 这样用户在不同区域看到的是一致的状态表达。
        Label(status.rawValue, systemImage: status.systemImage)
            .font(.caption)
            .foregroundStyle(status.color)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.12))
            .clipShape(Capsule())
    }

    /// “更多”菜单承载低频动作，避免把主区域塞满按钮。
    private var moreMenu: some View {
        Menu {
            Section("Copy") {
                Button(action: copyHostDetails) {
                    Label(
                        copiedLabel == "Host" ? "Copied Host Info" : "Copy Host Info",
                        systemImage: copiedLabel == "Host" ? "checkmark" : "list.bullet.rectangle"
                    )
                }

                Button(action: copyHostConfiguration) {
                    Label(
                        copiedLabel == "HostConfig" ? "Copied Host Config" : "Copy Host Config",
                        systemImage: copiedLabel == "HostConfig" ? "checkmark" : "curlybraces"
                    )
                }
            }

            Section("Manage") {
                Button(action: duplicate) {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }

                Button(action: edit) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(role: .destructive, action: delete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .imageScale(.large)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28, height: 28)
        .help("More host actions")
    }

    private var reorderButtons: some View {
        /// 上下移动只改变同组内顺序，所以这里配的是“局部排序”按钮，而不是全局拖拽列表。
        HStack(spacing: 4) {
            Button(action: moveUp) {
                Image(systemName: "arrow.up")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveUp)
            .help("Move host up")

            Button(action: moveDown) {
                Image(systemName: "arrow.down")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveDown)
            .help("Move host down")
        }
        .foregroundStyle(.secondary)
    }

    /// 主按钮永远执行“当前首选打开方式”，因此它的标题和图标都随配置变化。
    private var primaryActionButton: some View {
        Button(action: openPreferred) {
            actionButtonLabel(
                title: preferredOpenMode.actionTitle,
                systemImage: preferredOpenMode.systemImage,
                foregroundStyle: .white,
                backgroundStyle: Color.accentColor,
                isProminent: true
            )
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.plain)
        .help(primaryHelpText)
    }

    /// 次级打开方式不直接平铺在页面上，而是放进一个轻量 popover，
    /// 让用户在保留主按钮显眼性的同时，仍能快速切换其他打开策略。
    private var alternateOpenButton: some View {
        Button {
            isShowingAlternateOpenMenu = true
        } label: {
            actionButtonLabel(
                title: "More Options",
                systemImage: "chevron.down.circle",
                foregroundStyle: .primary,
                backgroundStyle: Color(nsColor: .controlColor),
                isProminent: false
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingAlternateOpenMenu, arrowEdge: .bottom) {
            alternateOpenPopover
        }
        .help("Open this host with another configured action")
    }

    private var alternateOpenPopover: some View {
        /// popover 中只展示“不是当前首选”的打开方式，
        /// 这样可以避免主动作和备选动作重复出现。
        VStack(alignment: .leading, spacing: 10) {
            Text("Open With")
                .font(.headline)

            ForEach(secondaryOpenActions) { action in
                Button {
                    isShowingAlternateOpenMenu = false
                    action.handler()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: action.mode.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.mode.actionTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)

                            Text(action.helpText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(width: 260)
    }

    private var primaryHelpText: String {
        /// tooltip 文案与首选打开方式一一对应，用来解释主按钮背后的真实行为。
        switch preferredOpenMode {
        case .ghostty:
            "Open Ghostty and start an SSH session"
        case .defaultTerminal:
            "Open an SSH session using the default SSH URL handler"
        case .vscode:
            "Open the host's remote directory in Visual Studio Code"
        }
    }

    private var secondaryOpenActions: [OpenAction] {
        /// 这里先过滤掉当前主方式，再把剩余模式转成视图更容易消费的展示模型。
        PreferredOpenMode.allCases
            .filter { $0 != preferredOpenMode }
            .map { mode in
                OpenAction(
                    mode: mode,
                    helpText: helpText(for: mode),
                    handler: handler(for: mode)
                )
            }
    }

    private func helpText(for mode: PreferredOpenMode) -> String {
        /// 备用打开方式的说明文案与 tooltip 分开维护，
        /// 这样 popover 里的描述可以保持更适合“列表说明”的语气。
        switch mode {
        case .ghostty:
            "Open Ghostty and start an SSH session"
        case .defaultTerminal:
            "Open an SSH session using the default SSH URL handler"
        case .vscode:
            "Open the host's remote directory in Visual Studio Code"
        }
    }

    private func actionButtonLabel(
        title: String,
        systemImage: String,
        foregroundStyle: Color,
        backgroundStyle: Color,
        isProminent: Bool
    ) -> some View {
        /// 主按钮和“More Options”按钮共用这一套外观，减少重复布局代码。
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .foregroundStyle(foregroundStyle)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(isProminent ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.10))
        }
    }

    /// 把 `PreferredOpenMode` 映射成真正要执行的闭包。
    /// 视图层只做分发，不接触服务层细节。
    private func handler(for mode: PreferredOpenMode) -> () -> Void {
        switch mode {
        case .ghostty:
            openSSH
        case .defaultTerminal:
            openDefaultTerminal
        case .vscode:
            openVSCodeRemote
        }
    }

    private func actionPill(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        /// 底部小按钮统一抽成 pill 风格，保证复制、Ping、Tailscale 这些次级动作有一致视觉层级。
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .controlSize(.regular)
        .help(title)
    }

    @ViewBuilder
    private var quickActionButtons: some View {
        /// quick actions 只放高频且即时的动作：
        /// 复制 SSH、复制 IP、Ping。
        /// 更低频、更解释性的动作则放进 more menu。
        actionPill(
            title: copiedLabel == "SSH" ? "Copied SSH" : "Copy SSH",
            systemImage: copiedLabel == "SSH" ? "checkmark" : "doc.on.doc",
            action: copySSHCommand
        )

        actionPill(
            title: copiedLabel == "IP" ? "Copied IP" : "Copy IP",
            systemImage: copiedLabel == "IP" ? "checkmark" : "network",
            action: copyIPAddress
        )

        actionPill(
            title: status == .checking ? "Checking" : "Ping",
            systemImage: "wave.3.right",
            action: ping
        )
        .disabled(status == .checking)
    }

    private struct OpenAction: Identifiable {
        /// 这是 popover 内部使用的轻量展示模型，把模式、说明和点击行为捆在一起。
        let mode: PreferredOpenMode
        let helpText: String
        let handler: () -> Void

        var id: PreferredOpenMode { mode }
    }
}
