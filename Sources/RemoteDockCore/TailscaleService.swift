import Foundation

public enum TailscaleService {
    public enum StatusResult {
        case success(String)
        case failure(String)
    }

    public static func status() -> StatusResult {
        guard let executablePath = executablePath() else {
            return .failure("Tailscale CLI not found. Install the Tailscale app or expose the `tailscale` command in your PATH.")
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["status"]
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let output = String(
                data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard process.terminationStatus == 0 else {
                if output.isEmpty {
                    return .failure("Unable to read Tailscale status.")
                }

                return .failure(output)
            }

            return .success(output.isEmpty ? "Tailscale returned no output." : output)
        } catch {
            return .failure("Unable to read Tailscale status: \(error.localizedDescription)")
        }
    }

    private static func executablePath() -> String? {
        let candidatePaths = [
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
            "/opt/homebrew/bin/tailscale",
            "/usr/local/bin/tailscale",
            "/usr/bin/tailscale"
        ]

        return candidatePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }
}
