import Foundation

/// 单次 ping 检查的结果模型。
///
/// 之所以不直接只返回 Bool，是因为 UI 还需要延迟和丢包等附加信息，
/// 这些信息在 sidebar、详情页和菜单栏里都能提升可读性。
public struct PingResult: Sendable, Equatable {
    public let isReachable: Bool
    public let averageLatencyMilliseconds: Double?
    public let packetLossPercentage: Double?

    public init(
        isReachable: Bool,
        averageLatencyMilliseconds: Double?,
        packetLossPercentage: Double? = nil
    ) {
        self.isReachable = isReachable
        self.averageLatencyMilliseconds = averageLatencyMilliseconds
        self.packetLossPercentage = packetLossPercentage
    }
}

/// 主机连通性检测服务，负责重试、延迟解析和测试注入点。
///
/// 这个类型的设计重点不是“怎么调用 ping 命令”本身，
/// 而是把几个需求放在一起统一解决：
/// - 真实运行时能调用系统 `/sbin/ping`
/// - 测试时可以注入假的 ping 行为
/// - UI 层既可以拿到简单布尔值，也可以拿到完整结果
public enum PingService {
    /// 默认重试次数和单次采样包数，决定了“速度”和“稳定性”之间的平衡。
    public static let defaultAttemptCount = 3
    public static let packetsPerAttempt = 3
    public static let retryDelayNanoseconds: UInt64 = 250_000_000

    /// 用一个受锁保护的依赖容器保存可替换实现，
    /// 避免在测试中直接改全局静态函数带来竞态问题。
    private final class Dependencies: @unchecked Sendable {
        let lock = NSLock()
        var runPing: (String) async -> PingResult = { address in
            await defaultPingRunner(address)
        }
    }

    private static let dependencies = Dependencies()

    /// 只返回主机是否可达的简化检测接口。
    public static func check(address: String, attempts: Int = defaultAttemptCount) async -> Bool {
        await checkResult(address: address, attempts: attempts).isReachable
    }

    /// 返回包含可达性、平均延迟和丢包信息的完整检测结果。
    ///
    /// 逻辑是：
    /// - 最多尝试 `attempts` 次
    /// - 任何一次成功就立即返回
    /// - 如果一直失败，则返回最后一次失败结果
    public static func checkResult(address: String, attempts: Int = defaultAttemptCount) async -> PingResult {
        let runPing = withDependencies { dependencies in
            dependencies.runPing
        }

        let normalizedAttempts = max(1, attempts)
        var lastResult = PingResult(isReachable: false, averageLatencyMilliseconds: nil, packetLossPercentage: nil)

        for attempt in 1 ... normalizedAttempts {
            let result = await runPing(address)
            lastResult = result

            if result.isReachable {
                return result
            }

            if attempt < normalizedAttempts {
                try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }
        }

        return lastResult
    }

    /// 测试注入点：允许用假的 ping 实现替换真实系统命令。
    static func setRunPing(_ closure: @escaping (String) async -> PingResult) {
        withDependenciesMutation { dependencies in
            dependencies.runPing = closure
        }
    }

    /// 把依赖恢复成真实实现，避免测试替换逻辑污染后续用例。
    static func resetDependencies() {
        withDependenciesMutation { dependencies in
            dependencies.runPing = { address in
                await defaultPingRunner(address)
            }
        }
    }

    /// 默认实现通过子进程调用系统 `ping`。
    /// 由于 `waitUntilExit()` 是阻塞操作，因此放进 detached task 里避免卡住调用方。
    private static func defaultPingRunner(_ address: String) async -> PingResult {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            let outputPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            process.arguments = ["-c", "\(packetsPerAttempt)", "-W", "1000", address]
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let averageLatency = parseAverageLatencyMilliseconds(from: output)
                let packetLoss = parsePacketLossPercentage(from: output)
                let isReachable = averageLatency != nil || (packetLoss.map { $0 < 100 } ?? (process.terminationStatus == 0))

                return PingResult(
                    isReachable: isReachable,
                    averageLatencyMilliseconds: averageLatency,
                    packetLossPercentage: packetLoss
                )
            } catch {
                return PingResult(isReachable: false, averageLatencyMilliseconds: nil, packetLossPercentage: nil)
            }
        }.value
    }

    /// 从 ping 输出中解析平均延迟，例如 `min/avg/max/stddev = 1.2/3.4/5.6/0.7 ms` 的 avg 部分。
    static func parseAverageLatencyMilliseconds(from output: String) -> Double? {
        guard let range = output.range(
            of: #"=\s*[0-9.]+/([0-9.]+)/"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let matchedText = String(output[range])
        guard let captureRange = matchedText.range(
            of: #"/([0-9.]+)/"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let captureText = matchedText[captureRange]
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return Double(captureText)
    }

    /// 从 ping 输出中解析丢包率，例如 `0.0% packet loss`。
    static func parsePacketLossPercentage(from output: String) -> Double? {
        guard let range = output.range(
            of: #"([0-9.]+)%\s+packet loss"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let matchedText = String(output[range])
        guard let captureRange = matchedText.range(
            of: #"([0-9.]+)%"#,
            options: .regularExpression
        ) else {
            return nil
        }

        let captureText = matchedText[captureRange]
            .replacingOccurrences(of: "%", with: "")

        return Double(captureText)
    }

    /// 读依赖和写依赖都通过锁保护，避免并发测试或异步调用时读写冲突。
    private static func withDependencies<T>(_ body: (Dependencies) -> T) -> T {
        dependencies.lock.lock()
        defer { dependencies.lock.unlock() }
        return body(dependencies)
    }

    /// 写依赖时也通过同一把锁保护，避免注入与读取交错发生。
    private static func withDependenciesMutation(_ body: (Dependencies) -> Void) {
        dependencies.lock.lock()
        defer { dependencies.lock.unlock() }
        body(dependencies)
    }
}
