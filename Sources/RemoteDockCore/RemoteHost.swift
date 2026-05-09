import Foundation

/// 单台远程主机的核心配置模型。
///
/// 这个类型是一个“值类型”配置对象。
/// 对不熟悉 Swift 的读者来说，可以把它理解成一个不可变倾向很强的配置快照：
/// 每次修改通常不是就地改字段，而是生成一个新的 `RemoteHost` 值。
/// 这和 SwiftUI 的数据流非常契合，因为界面更容易追踪“新旧值发生了什么变化”。
public struct RemoteHost: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let username: String
    public let address: String
    public let port: Int?
    public let groupID: UUID?
    public let remoteDirectory: String?
    public let startupCommand: String?
    public let preferredOpenMode: PreferredOpenMode?
    public let autoPingIntervalMinutes: Int?
    public let autoPingDisabled: Bool?

    /// 当主机和全局设置都没有给出更细粒度值时，默认使用 5 分钟。
    public static let defaultAutoPingIntervalMinutes = 5

    public init(
        id: UUID = UUID(),
        name: String,
        username: String,
        address: String,
        port: Int? = nil,
        groupID: UUID? = nil,
        remoteDirectory: String? = nil,
        startupCommand: String? = nil,
        preferredOpenMode: PreferredOpenMode? = nil,
        autoPingIntervalMinutes: Int? = nil,
        autoPingDisabled: Bool? = nil
    ) {
        /// 构造时立即做归一化，确保后续所有逻辑都基于“干净数据”运行。
        /// 例如：
        /// - 非法端口会被清成 `nil`
        /// - 空字符串目录会被视为未设置
        /// - 非法自动 ping 间隔会回退为 `nil`
        self.id = id
        self.name = name
        self.username = username
        self.address = address
        self.port = Self.normalizedPort(port)
        self.groupID = groupID
        self.remoteDirectory = Self.normalizedRemoteDirectory(remoteDirectory)
        self.startupCommand = Self.normalizedStartupCommand(startupCommand)
        self.preferredOpenMode = preferredOpenMode
        self.autoPingIntervalMinutes = Self.normalizedAutoPingIntervalMinutes(autoPingIntervalMinutes)
        self.autoPingDisabled = Self.normalizedAutoPingDisabled(autoPingDisabled)
    }

    /// 生成用于本地终端直接执行的 SSH 命令。
    ///
    /// 这是最贴近 shell 的表示，适合复制给用户或交给终端服务。
    public var sshCommand: String {
        if let port {
            return "ssh -p \(port) \(sshTarget)"
        }

        return "ssh \(sshTarget)"
    }

    /// 生成界面展示用的地址文本，必要时附带端口。
    public var displayAddress: String {
        if let port {
            return "\(sshTarget):\(port)"
        }

        return sshTarget
    }

    /// 生成 `user@host` 形式的 SSH 目标字符串。
    /// 这是多个上层字段的公共基石。
    public var sshTarget: String {
        "\(username)@\(address)"
    }

    /// 生成 VS Code Remote 等场景使用的 authority 文本。
    /// 它和 `sshCommand` 的区别是：这里产出的不是完整命令，而是连接标识符的一部分。
    public var sshAuthority: String {
        if let port {
            return "\(sshTarget):\(port)"
        }

        return sshTarget
    }

    /// 这是一个轻量判断，用于决定 UI 是否展示与 Tailscale 相关的辅助动作。
    public var usesTailscale: Bool {
        Self.looksLikeTailscaleAddress(address)
    }

    /// 返回适合复制或展示的主机摘要文本。
    /// 这里强调“主机本身的配置”，不包含界面运行时信息，例如分组名和当前在线状态。
    public var fullDetailsText: String {
        [
            "Name: \(name)",
            "Username: \(username)",
            "Address: \(address)",
            "Port: \(port.map(String.init) ?? "Default")",
            "SSH Target: \(sshTarget)",
            "Preferred Open Mode: \(effectiveOpenMode.title)",
            "Auto Ping Interval: \(effectiveAutoPingDescription)",
            "Remote Directory: \(effectiveRemoteDirectory)",
            "Startup Command: \(preferredStartupCommand ?? "Default behavior")"
        ]
        .joined(separator: "\n")
    }

    /// `preferredXxx` 表示“用户是否手动配置过”。
    /// 如果返回 `nil`，通常意味着应交给全局默认值或推导值处理。
    public var preferredRemoteDirectory: String? {
        Self.normalizedRemoteDirectory(remoteDirectory)
    }

    /// 若返回 `nil`，表示没有主机级自定义启动命令，应由默认 follow-up 逻辑接手。
    public var preferredStartupCommand: String? {
        Self.normalizedStartupCommand(startupCommand)
    }

    /// 主机级打开方式如果为 `nil`，通常表示“交给上层全局设置决定”。
    public var preferredOpenModeOrNil: PreferredOpenMode? {
        preferredOpenMode
    }

    /// 主机级自动 Ping 间隔如果为 `nil`，表示没有覆盖全局默认值。
    public var preferredAutoPingIntervalMinutesOrNil: Int? {
        autoPingIntervalMinutes
    }

    /// 对上层来说，这里暴露成 Bool 更方便消费；内部仍保留 `nil` 表达“未显式配置”。
    public var preferredAutoPingDisabledOrNil: Bool {
        autoPingDisabled == true
    }

    /// `effectiveXxx` 表示“最终真正生效的值”。
    /// 它会把用户自定义、默认值和推导逻辑合并后给上层使用。
    public var effectiveOpenMode: PreferredOpenMode {
        preferredOpenMode ?? .ghostty
    }

    /// 最终生效的自动 Ping 分钟值，主要用于简单展示或在没有全局覆盖参与时的默认行为。
    public var effectiveAutoPingIntervalMinutes: Int {
        autoPingIntervalMinutes ?? Self.defaultAutoPingIntervalMinutes
    }

    /// 这个描述字符串主要面向 UI 和复制文本，而不是存储层。
    public var effectiveAutoPingDescription: String {
        if preferredAutoPingDisabledOrNil {
            return "Never"
        }

        return "\(effectiveAutoPingIntervalMinutes) min"
    }

    public var effectiveRemoteDirectory: String {
        preferredRemoteDirectory ?? suggestedRemoteDirectory
    }

    /// 当前 VS Code 直接复用最终远程目录；单独保留这个属性是为了让上层语义更明确。
    public var vscodeRemoteDirectory: String {
        effectiveRemoteDirectory
    }

    /// Windows 判断既看目录，也看名称，是因为有些主机在初始阶段还没填目录。
    public var isWindowsHost: Bool {
        Self.looksLikeWindowsPath(effectiveRemoteDirectory) || Self.looksLikeWindowsName(name)
    }

    /// 当用户没有显式填写远程目录时，按主机名称做一个启发式推断。
    public var suggestedRemoteDirectory: String {
        let lowercasedName = name.lowercased()

        if lowercasedName.contains("windows") || lowercasedName.contains("win") {
            return "C:/Users/\(username)"
        }

        if lowercasedName.contains("mac") {
            return "/Users/\(username)"
        }

        return "/home/\(username)"
    }

    /// Windows 主机默认补一条启动命令，便于在进入远程后自动切到目标目录。
    public var suggestedStartupCommand: String? {
        guard isWindowsHost else {
            return nil
        }

        return #"call "%USERPROFILE%\bin\remote.cmd" "{remoteDirectory}""#
    }

    /// 以格式化 JSON 文本导出当前主机配置。
    public func formattedJSON() throws -> String {
        try JSONExportFormatter.formattedString(from: self)
    }

    /// 基于当前主机复制出一个新实例，并替换显示名称。
    /// 新实例会自动生成新的 UUID，因此可以与原主机并存。
    public func duplicated(named name: String) -> RemoteHost {
        RemoteHost(
            name: name,
            username: username,
            address: address,
            port: port,
            groupID: groupID,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes,
            autoPingDisabled: autoPingDisabled
        )
    }

    /// 根据已存在名称集合生成不冲突的副本名称。
    ///
    /// 规则示例：
    /// - `Foo` -> `Foo copy`
    /// - 若已存在 `Foo copy`，则变成 `Foo copy 2`
    /// - 若当前名称本来就是 `Foo copy 2`，也会先归一化回 `Foo copy` 再递增
    public func suggestedDuplicateName(takenNames: some Sequence<String>) -> String {
        let existingNames = Set(takenNames)
        let baseName = Self.duplicateBaseName(from: name)

        if !existingNames.contains(baseName) {
            return baseName
        }

        var copyIndex = 2
        while existingNames.contains("\(baseName) \(copyIndex)") {
            copyIndex += 1
        }

        return "\(baseName) \(copyIndex)"
    }

    /// 返回一个仅远程目录不同的新主机值。
    /// 这类 `withXxx` 方法让调用方可以在不破坏值语义的前提下做局部修改。
    public func withRemoteDirectory(_ remoteDirectory: String?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            port: port,
            groupID: groupID,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes,
            autoPingDisabled: autoPingDisabled
        )
    }

    /// 返回一个仅启动命令不同的新主机值。
    public func withStartupCommand(_ startupCommand: String?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            port: port,
            groupID: groupID,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes,
            autoPingDisabled: autoPingDisabled
        )
    }

    /// 返回一个仅首选打开方式不同的新主机值。
    public func withPreferredOpenMode(_ preferredOpenMode: PreferredOpenMode?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            port: port,
            groupID: groupID,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes,
            autoPingDisabled: autoPingDisabled
        )
    }

    /// 返回一个仅自动 Ping 间隔不同的新主机值。
    public func withAutoPingIntervalMinutes(_ autoPingIntervalMinutes: Int?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            port: port,
            groupID: groupID,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes,
            autoPingDisabled: autoPingDisabled
        )
    }

    /// 返回一个仅自动 Ping 禁用状态不同的新主机值。
    public func withAutoPingDisabled(_ autoPingDisabled: Bool?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            port: port,
            groupID: groupID,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes,
            autoPingDisabled: autoPingDisabled
        )
    }

    /// 返回一个仅分组标识不同的新主机值。
    public func withGroupID(_ groupID: UUID?) -> RemoteHost {
        RemoteHost(
            id: id,
            name: name,
            username: username,
            address: address,
            port: port,
            groupID: groupID,
            remoteDirectory: remoteDirectory,
            startupCommand: startupCommand,
            preferredOpenMode: preferredOpenMode,
            autoPingIntervalMinutes: autoPingIntervalMinutes,
            autoPingDisabled: autoPingDisabled
        )
    }

    /// 端口只接受 1...65535；非法值直接视为“未填写”。
    private static func normalizedPort(_ value: Int?) -> Int? {
        guard let value, (1 ... 65535).contains(value) else {
            return nil
        }

        return value
    }

    /// 主机级自动 ping 间隔限制在 1 分钟到 1440 分钟之间。
    private static func normalizedAutoPingIntervalMinutes(_ value: Int?) -> Int? {
        guard let value, (1 ... 1440).contains(value) else {
            return nil
        }

        return value
    }

    /// 这里有意把 `false` 归一化为 `nil`，这样 JSON 中只在“明确禁用”时才保存字段。
    private static func normalizedAutoPingDisabled(_ value: Bool?) -> Bool? {
        value == true ? true : nil
    }

    /// 把空白目录视为未设置，避免把 `"   "` 这样的值写进配置。
    private static func normalizedRemoteDirectory(_ value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }

    /// 启动命令与目录采用同样的空白清洗策略。
    private static func normalizedStartupCommand(_ value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }

    /// 通过盘符前缀判断是否像 Windows 路径，例如 `C:/Users/...`。
    private static func looksLikeWindowsPath(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z]:[/\\]"#, options: .regularExpression) != nil
    }

    /// 当路径还没填时，再通过主机名称做一次启发式判断。
    private static func looksLikeWindowsName(_ value: String) -> Bool {
        let lowercasedValue = value.lowercased()
        return lowercasedValue.contains("windows") || lowercasedValue.contains("win")
    }

    /// 根据 Tailscale 常见地址形式做轻量识别。
    /// 这里只是 UI 层面的启发式判断，不是严格协议校验。
    private static func looksLikeTailscaleAddress(_ value: String) -> Bool {
        let lowercasedValue = value.lowercased()

        if lowercasedValue.hasSuffix(".ts.net") {
            return true
        }

        if lowercasedValue.hasPrefix("fd7a:115c:a1e0:") {
            return true
        }

        let components = value.split(separator: ".")
        guard components.count == 4,
              let firstOctet = Int(components[0]),
              let secondOctet = Int(components[1]),
              (0 ... 255).contains(firstOctet),
              (0 ... 255).contains(secondOctet) else {
            return false
        }

        return firstOctet == 100 && (64 ... 127).contains(secondOctet)
    }

    /// 去掉结尾已有的 `copy` / `copy N`，再统一生成副本基础名。
    private static func duplicateBaseName(from value: String) -> String {
        let pattern = #"\s+copy(?:\s+\d+)?$"#
        let strippedValue = value.replacingOccurrences(
            of: pattern,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        return "\(strippedValue) copy"
    }
}
