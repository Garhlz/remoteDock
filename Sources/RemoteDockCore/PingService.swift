import Foundation

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

public enum PingService {
    public static let defaultAttemptCount = 3
    public static let packetsPerAttempt = 3
    public static let retryDelayNanoseconds: UInt64 = 250_000_000

    private final class Dependencies: @unchecked Sendable {
        let lock = NSLock()
        var runPing: (String) async -> PingResult = { address in
            await defaultPingRunner(address)
        }
    }

    private static let dependencies = Dependencies()

    public static func check(address: String, attempts: Int = defaultAttemptCount) async -> Bool {
        await checkResult(address: address, attempts: attempts).isReachable
    }

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

    static func setRunPing(_ closure: @escaping (String) async -> PingResult) {
        withDependenciesMutation { dependencies in
            dependencies.runPing = closure
        }
    }

    static func resetDependencies() {
        withDependenciesMutation { dependencies in
            dependencies.runPing = { address in
                await defaultPingRunner(address)
            }
        }
    }

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

    private static func withDependencies<T>(_ body: (Dependencies) -> T) -> T {
        dependencies.lock.lock()
        defer { dependencies.lock.unlock() }
        return body(dependencies)
    }

    private static func withDependenciesMutation(_ body: (Dependencies) -> Void) {
        dependencies.lock.lock()
        defer { dependencies.lock.unlock() }
        body(dependencies)
    }
}
