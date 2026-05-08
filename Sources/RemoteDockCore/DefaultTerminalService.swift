import Foundation

public enum DefaultTerminalService {
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

    public static func openSSHSession(for host: RemoteHost) -> Error? {
        guard let url = SSHURLBuilder.url(for: host) else {
            return .invalidSSHURL
        }

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
