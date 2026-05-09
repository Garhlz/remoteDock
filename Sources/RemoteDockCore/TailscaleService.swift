import Foundation

/// 负责读取本机 Tailscale CLI 状态。
///
/// 与 `PingService` 类似，这里也采用“真实实现 + 可注入依赖”的设计，
/// 这样既能在运行时调用系统命令，也能在测试里稳定模拟各种边界情况。
public enum TailscaleService {
    /// 面向 UI 的结构化错误类型。
    /// 这些 case 更强调“当前失败该如何理解”，而不是单纯暴露底层实现细节。
    ///
    /// 例如 `cliNotFound` 和 `commandFailed` 虽然最终都意味着没拿到状态，
    /// 但前者是“本机环境缺少工具”，后者是“工具存在但执行失败”，处理建议完全不同。
    public enum Error: LocalizedError {
        case cliNotFound
        case unreadableStatus
        case commandFailed(output: String)
        case processError(String)

        public var errorDescription: String? {
            switch self {
            case .cliNotFound:
                "Tailscale CLI not found. Install the Tailscale app or expose the `tailscale` command in your PATH."
            case .unreadableStatus:
                "Unable to read Tailscale status."
            case .commandFailed(let output):
                output
            case .processError(let description):
                "Unable to read Tailscale status: \(description)"
            }
        }
    }

    /// 对命令执行结果做一个轻量封装，避免直接把 `Process` 暴露到上层逻辑。
    struct CommandResult {
        let terminationStatus: Int32
        let output: String
    }

    /// 用依赖容器把“文件是否可执行”和“如何运行命令”两个可变行为收拢起来。
    private final class Dependencies: @unchecked Sendable {
        let lock = NSLock()
        var isExecutableFile: (String) -> Bool = { path in
            FileManager.default.isExecutableFile(atPath: path)
        }
        var runCommand: (String, [String]) throws -> CommandResult = { executablePath, arguments in
            let process = Process()
            let outputPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            try process.run()
            process.waitUntilExit()

            let output = String(
                data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return CommandResult(
                terminationStatus: process.terminationStatus,
                output: output
            )
        }
    }

    private static let dependencies = Dependencies()

    /// 读取并返回当前设备的 `tailscale status` 文本。
    ///
    /// 整体流程是：
    /// 1. 先找 CLI 可执行文件；
    /// 2. 再运行 `tailscale status`；
    /// 3. 最后根据退出码和输出内容映射为成功或失败。
    ///
    /// 这里返回 `Result` 而不是直接抛错，是因为这条链路本质上更像“探测状态”，
    /// 调用方通常需要分支展示成功文本或失败原因，而不是沿调用栈继续传播异常。
    public static func status() -> Result<String, Error> {
        guard let executablePath = executablePath() else {
            return .failure(.cliNotFound)
        }

        do {
            let result = try withDependencies { dependencies in
                try dependencies.runCommand(executablePath, ["status"])
            }

            guard result.terminationStatus == 0 else {
                if result.output.isEmpty {
                    return .failure(.unreadableStatus)
                }

                return .failure(.commandFailed(output: result.output))
            }

            return .success(result.output.isEmpty ? "Tailscale returned no output." : result.output)
        } catch {
            return .failure(.processError(error.localizedDescription))
        }
    }

    /// 在几个常见安装位置里查找可执行文件。
    /// 这样既兼容 App Bundle，也兼容 Homebrew 或手工安装路径。
    ///
    /// 这里显式列出候选路径，而不是依赖 shell 的 PATH 搜索，
    /// 是为了让 CLI 在 GUI App 环境下也更可预测；图形应用的 PATH 往往和终端会话不同。
    static func executablePath() -> String? {
        let candidatePaths = [
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
            "/opt/homebrew/bin/tailscale",
            "/usr/local/bin/tailscale",
            "/usr/bin/tailscale"
        ]

        return withDependencies { dependencies in
            candidatePaths.first(where: dependencies.isExecutableFile)
        }
    }

    /// 测试注入点：替换“文件是否存在且可执行”的判断逻辑。
    static func setIsExecutableFile(_ closure: @escaping (String) -> Bool) {
        withDependenciesMutation { dependencies in
            dependencies.isExecutableFile = closure
        }
    }

    /// 测试注入点：替换真实命令执行逻辑。
    static func setRunCommand(_ closure: @escaping (String, [String]) throws -> CommandResult) {
        withDependenciesMutation { dependencies in
            dependencies.runCommand = closure
        }
    }

    /// 把依赖恢复成真实实现，避免测试中替换过的闭包泄漏到后续用例。
    static func resetDependencies() {
        withDependenciesMutation { dependencies in
            dependencies.isExecutableFile = { path in
                FileManager.default.isExecutableFile(atPath: path)
            }
            dependencies.runCommand = { executablePath, arguments in
                let process = Process()
                let outputPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                process.standardOutput = outputPipe
                process.standardError = outputPipe

                try process.run()
                process.waitUntilExit()

                let output = String(
                    data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                return CommandResult(
                    terminationStatus: process.terminationStatus,
                    output: output
                )
            }
        }
    }

    /// 与 `PingService` 相同，依赖访问通过锁保护，保证并发下的可预测性。
    private static func withDependencies<T>(_ body: (Dependencies) throws -> T) rethrows -> T {
        dependencies.lock.lock()
        defer { dependencies.lock.unlock() }
        return try body(dependencies)
    }

    /// 写依赖时也统一通过同一把锁保护，确保替换动作本身是原子的。
    private static func withDependenciesMutation(_ body: (Dependencies) -> Void) {
        dependencies.lock.lock()
        defer { dependencies.lock.unlock() }
        body(dependencies)
    }
}
