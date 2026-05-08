import Foundation

public enum TailscaleService {
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

    struct CommandResult {
        let terminationStatus: Int32
        let output: String
    }

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

    static func setIsExecutableFile(_ closure: @escaping (String) -> Bool) {
        withDependenciesMutation { dependencies in
            dependencies.isExecutableFile = closure
        }
    }

    static func setRunCommand(_ closure: @escaping (String, [String]) throws -> CommandResult) {
        withDependenciesMutation { dependencies in
            dependencies.runCommand = closure
        }
    }

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

    private static func withDependencies<T>(_ body: (Dependencies) throws -> T) rethrows -> T {
        dependencies.lock.lock()
        defer { dependencies.lock.unlock() }
        return try body(dependencies)
    }

    private static func withDependenciesMutation(_ body: (Dependencies) -> Void) {
        dependencies.lock.lock()
        defer { dependencies.lock.unlock() }
        body(dependencies)
    }
}
