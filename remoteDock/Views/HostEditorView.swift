//
//  HostEditorView.swift
//  remoteDock
//
//  Created by Elaine on 2026/5/8.
//

import SwiftUI
import RemoteDockCore

/// 新增或编辑主机时使用的表单视图。
///
/// 这是典型的“编辑草稿”视图：
/// - 打开时先把 `RemoteHost` 拆成一组适合表单编辑的字符串/枚举状态；
/// - 用户修改的是这些草稿值，而不是直接修改原模型；
/// - 点击保存后再统一校验，并重新组装成新的 `RemoteHost`。
struct HostEditorView: View {
    /// 打开方式在 UI 中多了一个 “Use Global Default” 选项，
    /// 所以这里不能直接绑定 `PreferredOpenMode?`，需要一个专门的表单枚举。
    private enum OpenModeSelection: String, CaseIterable, Identifiable {
        case useDefault
        case ghostty
        case defaultTerminal
        case vscode

        var id: String { rawValue }
    }

    /// 自动 ping 也同理：表单需要把“跟随全局 / 自定义 / 永不”表达成更适合用户理解的选项。
    private enum AutoPingSelection: String, CaseIterable, Identifiable {
        case useGlobal
        case customMinutes
        case never

        var id: String { rawValue }
    }

    let title: String
    let originalHost: RemoteHost?
    let availableGroups: [HostGroup]
    let save: (RemoteHost) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.defaultOpenModeKey) private var defaultOpenModeRawValue = AppSettings.defaultOpenMode.rawValue
    @AppStorage(AppSettings.defaultAutoPingModeKey) private var defaultAutoPingModeRawValue = AppSettings.defaultAutoPingMode.rawValue
    @AppStorage(AppSettings.defaultAutoPingIntervalValueKey) private var defaultAutoPingIntervalValue = AppSettings.defaultAutoPingIntervalValue
    @State private var name: String
    @State private var username: String
    @State private var address: String
    @State private var port: String
    @State private var selectedGroupID: UUID?
    @State private var autoPingSelection: AutoPingSelection
    @State private var autoPingIntervalMinutes: String
    @State private var remoteDirectory: String
    @State private var startupCommand: String
    @State private var openModeSelection: OpenModeSelection
    @State private var validationMessage: String?
    private let startupCommandPlaceholder: String

    /// 初始化时把原模型拆成可编辑字段。
    /// 例如端口和自动 ping 间隔在表单中要显示成字符串，而不是 Int。
    init(title: String, host: RemoteHost?, availableGroups: [HostGroup], save: @escaping (RemoteHost) -> Void) {
        self.title = title
        self.originalHost = host
        self.availableGroups = availableGroups
        self.save = save
        self.startupCommandPlaceholder = host?.suggestedStartupCommand ?? #"call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}""#
        _name = State(initialValue: host?.name ?? "")
        _username = State(initialValue: host?.username ?? "")
        _address = State(initialValue: host?.address ?? "")
        _port = State(initialValue: host?.port.map(String.init) ?? "")
        _selectedGroupID = State(initialValue: host?.groupID)
        _autoPingSelection = State(initialValue: Self.autoPingSelection(for: host))
        _autoPingIntervalMinutes = State(initialValue: host?.preferredAutoPingIntervalMinutesOrNil.map(String.init) ?? "")
        _remoteDirectory = State(initialValue: host?.remoteDirectory ?? "")
        _startupCommand = State(initialValue: host?.startupCommand ?? "")
        _openModeSelection = State(initialValue: Self.selection(for: host?.preferredOpenModeOrNil))
    }

    var body: some View {
        /// 这里的说明文本刻意写得比较“翻译业务规则”，
        /// 让用户不用理解实现细节也知道不同选项最终会如何生效。
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2.bold())

            Form {
                Section("Host") {
                    TextField("Name", text: $name)
                    TextField("Username", text: $username)
                    TextField("Address", text: $address)
                    TextField("Port", text: $port, prompt: Text("22"))

                    LabeledContent("Group") {
                        Picker("Group", selection: $selectedGroupID) {
                            Text("Ungrouped").tag(UUID?.none)

                            ForEach(availableGroups) { group in
                                Text(group.name).tag(group.id as UUID?)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200, alignment: .trailing)
                    }
                }

                Section("Open") {
                    LabeledContent("Open Mode") {
                        Picker("Open Mode", selection: $openModeSelection) {
                            Text("Use Global Default").tag(OpenModeSelection.useDefault)

                            Divider()

                            ForEach(OpenModeSelection.allCases.filter { $0 != .useDefault }, id: \.self) { mode in
                                Text(title(for: mode)).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200, alignment: .trailing)
                    }

                    LabeledContent("Auto Ping") {
                        Picker("Auto Ping", selection: $autoPingSelection) {
                            Text("Use Global").tag(AutoPingSelection.useGlobal)
                            Text("Custom Interval").tag(AutoPingSelection.customMinutes)
                            Text("Never").tag(AutoPingSelection.never)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 200, alignment: .trailing)
                    }

                    if autoPingSelection == .customMinutes {
                        TextField(
                            "Auto Ping Interval (min)",
                            text: $autoPingIntervalMinutes,
                            prompt: Text(hostAutoPingPrompt)
                        )
                    }
                    TextField("Remote Directory", text: $remoteDirectory, prompt: Text("/home/elaine"))
                    TextField("Startup Command", text: $startupCommand, prompt: Text(startupCommandPlaceholder))
                }
            }

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Preferred Open Mode controls the primary action in the host detail view.")
                Text("Use Global Default currently resolves to \(resolvedDefaultOpenMode.title).")
                Text("Auto Ping controls how often this host is checked in the background. Use Global follows \(globalHeartbeatDescription), and Never disables background checks for this host.")
                Text("Remote Directory is used by VS Code Remote and can be left empty for now.")
                Text("Startup Command is optional. It runs after SSH login, and you can use {remoteDirectory} as a placeholder.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    saveHost()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 430)
    }

    /// 保存动作的顺序非常重要：
    /// 1. 先 trim；
    /// 2. 再逐项校验；
    /// 3. 最后统一构造 `RemoteHost`。
    ///
    /// 这种写法能保证错误提示更聚焦，也避免半合法数据提前写入模型。
    private func saveHost() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAutoPingIntervalMinutes = autoPingIntervalMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRemoteDirectory = remoteDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedStartupCommand = startupCommand.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            validationMessage = "Name cannot be empty."
            return
        }

        guard !trimmedUsername.isEmpty else {
            validationMessage = "Username cannot be empty."
            return
        }

        guard isValidAddress(trimmedAddress) else {
            validationMessage = "Address cannot be empty or contain spaces."
            return
        }

        guard isValidRemoteDirectory(trimmedRemoteDirectory) else {
            validationMessage = "Remote directory cannot contain line breaks."
            return
        }

        guard isValidPort(trimmedPort) else {
            validationMessage = "Port must be empty or a number between 1 and 65535."
            return
        }

        guard isValidAutoPingIntervalMinutes(trimmedAutoPingIntervalMinutes) else {
            validationMessage = "Auto ping interval must be empty or a number between 1 and 1440."
            return
        }

        guard isValidStartupCommand(trimmedStartupCommand) else {
            validationMessage = "Startup command cannot contain line breaks."
            return
        }

        /// 真正构造模型时，再把字符串字段解析回更适合持久化的类型。
        let host = RemoteHost(
            id: originalHost?.id ?? UUID(),
            name: trimmedName,
            username: trimmedUsername,
            address: trimmedAddress,
            port: parsedPort(from: trimmedPort),
            groupID: selectedGroupID,
            remoteDirectory: trimmedRemoteDirectory,
            startupCommand: trimmedStartupCommand,
            preferredOpenMode: preferredOpenMode(from: openModeSelection),
            autoPingIntervalMinutes: parsedAutoPingIntervalMinutes(from: trimmedAutoPingIntervalMinutes),
            autoPingDisabled: autoPingSelection == .never ? true : nil
        )

        save(host)
        dismiss()
    }

    /// 地址当前只做轻量校验：不能为空且不能带空白字符。
    /// 这里允许域名、IPv4、IPv6、Tailscale 域名等多种形式。
    private func isValidAddress(_ value: String) -> Bool {
        !value.isEmpty && !value.contains(where: { $0.isWhitespace })
    }

    /// 路径允许为空，但不允许换行，避免破坏配置文件或命令拼接。
    private func isValidRemoteDirectory(_ value: String) -> Bool {
        !value.contains(where: \.isNewline)
    }

    /// 端口字段可以留空；只要填了，就必须能被解析成合法端口。
    private func isValidPort(_ value: String) -> Bool {
        value.isEmpty || parsedPort(from: value) != nil
    }

    private func parsedPort(from value: String) -> Int? {
        guard !value.isEmpty else {
            return nil
        }

        guard let port = Int(value), (1 ... 65535).contains(port) else {
            return nil
        }

        return port
    }

    /// 自定义 auto ping 只有在 `customMinutes` 模式下才必须可解析。
    private func isValidAutoPingIntervalMinutes(_ value: String) -> Bool {
        autoPingSelection != .customMinutes || parsedAutoPingIntervalMinutes(from: value) != nil
    }

    private func parsedAutoPingIntervalMinutes(from value: String) -> Int? {
        guard !value.isEmpty else {
            return nil
        }

        guard let minutes = Int(value), (1 ... 1440).contains(minutes) else {
            return nil
        }

        return minutes
    }

    /// 启动命令目前允许任意单行文本，避免过早限制高级用户的自定义能力。
    private func isValidStartupCommand(_ value: String) -> Bool {
        !value.contains(where: \.isNewline)
    }

    private var resolvedDefaultOpenMode: PreferredOpenMode {
        PreferredOpenMode(rawValue: defaultOpenModeRawValue) ?? AppSettings.defaultOpenMode
    }

    private var resolvedDefaultAutoPingMode: AppSettings.AutoPingMode {
        AppSettings.effectiveAutoPingMode(rawValue: defaultAutoPingModeRawValue)
    }

    private var globalHeartbeatDescription: String {
        AppSettings.heartbeatDescription(
            mode: resolvedDefaultAutoPingMode,
            value: defaultAutoPingIntervalValue
        )
    }

    /// 给输入框 prompt 用的文案，会根据全局设置变化，让用户更直观看到“留空后会继承什么”。
    private var hostAutoPingPrompt: String {
        switch resolvedDefaultAutoPingMode {
        case .seconds:
            "Use global (\(globalHeartbeatDescription))"
        case .minutes:
            "Use global (\(globalHeartbeatDescription))"
        case .manual:
            "Manual only unless overridden"
        }
    }

    /// 把模型状态恢复成表单枚举，用于编辑已有主机时回填 UI。
    private static func autoPingSelection(for host: RemoteHost?) -> AutoPingSelection {
        if host?.preferredAutoPingDisabledOrNil == true {
            return .never
        }

        if host?.preferredAutoPingIntervalMinutesOrNil != nil {
            return .customMinutes
        }

        return .useGlobal
    }

    /// 表单值转回真正存储到模型中的 `PreferredOpenMode?`。
    /// 其中 `useDefault` 被编码成 `nil`，表示“不要写主机级覆盖值”。
    private func preferredOpenMode(from selection: OpenModeSelection) -> PreferredOpenMode? {
        switch selection {
        case .useDefault:
            nil
        case .ghostty:
            .ghostty
        case .defaultTerminal:
            .defaultTerminal
        case .vscode:
            .vscode
        }
    }

    /// 与 `preferredOpenMode(from:)` 反向对应，用于编辑已有值时的回填。
    private static func selection(for mode: PreferredOpenMode?) -> OpenModeSelection {
        switch mode {
        case nil:
            .useDefault
        case .ghostty:
            .ghostty
        case .defaultTerminal:
            .defaultTerminal
        case .vscode:
            .vscode
        }
    }

    private func title(for selection: OpenModeSelection) -> String {
        switch selection {
        case .useDefault:
            "Use Global Default"
        case .ghostty:
            PreferredOpenMode.ghostty.title
        case .defaultTerminal:
            PreferredOpenMode.defaultTerminal.title
        case .vscode:
            PreferredOpenMode.vscode.title
        }
    }
}
