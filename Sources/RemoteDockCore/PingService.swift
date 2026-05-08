import Foundation

public enum PingService {
    private final class Dependencies: @unchecked Sendable {
        let lock = NSLock()
        var runPing: (String) async -> Bool = { address in
            await Task.detached(priority: .userInitiated) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                process.arguments = ["-c", "1", "-W", "1000", address]

                do {
                    try process.run()
                    process.waitUntilExit()
                    return process.terminationStatus == 0
                } catch {
                    return false
                }
            }.value
        }
    }

    private static let dependencies = Dependencies()

    public static func check(address: String) async -> Bool {
        let runPing = withDependencies { dependencies in
            dependencies.runPing
        }
        return await runPing(address)
    }

    static func setRunPing(_ closure: @escaping (String) async -> Bool) {
        withDependenciesMutation { dependencies in
            dependencies.runPing = closure
        }
    }

    static func resetDependencies() {
        withDependenciesMutation { dependencies in
            dependencies.runPing = { address in
                await Task.detached(priority: .userInitiated) {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/sbin/ping")
                    process.arguments = ["-c", "1", "-W", "1000", address]

                    do {
                        try process.run()
                        process.waitUntilExit()
                        return process.terminationStatus == 0
                    } catch {
                        return false
                    }
                }.value
            }
        }
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
