import Foundation

/// 使用系统默认的 `ssh://` 处理器打开远程终端会话。
///
/// 与 `TerminalService` 不同，这里不依赖 Ghostty 或 AppleScript，
/// 而是使用 macOS 的 `/usr/bin/open` 打开一个 `ssh://...` URL，
/// 由系统决定交给哪个默认终端/应用处理。
public enum DefaultTerminalService {
    /// 错误类型重点描述“默认终端这条链路为什么没走通”，便于直接反馈给 UI。
    public enum Error: LocalizedError {
        case invalidSSHURL
        case launchFailed(output: String?)
        case processError(String)

        public var errorDescription: String? {
            switch self {
            case .invalidSSHURL:
                "Unable to build the SSH URL for the default terminal."
            case .launchFailed(let output):
                if let output, !output.isEmpty {
                    "Unable to open the default terminal: \(output)"
                } else {
                    "Unable to open the default terminal."
                }
            case .processError(let description):
                "Unable to open the default terminal: \(description)"
            }
        }
    }

    /// 打开流程：
    /// 1. 先把主机配置转换成 `ssh://` URL；
    /// 2. 用 `open` 命令交给系统；
    /// 3. 若启动失败则把输出翻译成结构化错误。
    public static func openSSHSession(for host: RemoteHost) -> Error? {
        guard let url = SSHURLBuilder.url(for: host) else {
            return .invalidSSHURL
        }

        /// `/usr/bin/open` 是 macOS 打开 URL 的标准入口，
        /// 这里相当于把“ssh://...” 交回系统默认处理器决定。
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let output = String(
                    data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                )?.trimmingCharacters(in: .whitespacesAndNewlines)

                return .launchFailed(output: output)
            }

            return nil
        } catch {
            return .processError(error.localizedDescription)
        }
    }
}
