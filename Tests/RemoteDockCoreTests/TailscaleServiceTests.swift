import Foundation
import Testing
@testable import RemoteDockCore

struct TailscaleServiceTests {
    @Test
    func executablePathUsesFirstAvailableCandidate() {
        let expectedPath = "/opt/homebrew/bin/tailscale"
        defer { TailscaleService.resetDependencies() }

        TailscaleService.setIsExecutableFile { path in
            path == expectedPath || path == "/usr/local/bin/tailscale"
        }

        #expect(TailscaleService.executablePath() == expectedPath)
    }

    @Test
    func statusFailsWhenNoExecutableIsFound() {
        defer { TailscaleService.resetDependencies() }

        TailscaleService.setIsExecutableFile { _ in false }

        let result = TailscaleService.status()

        guard case .failure(let error) = result else {
            Issue.record("Expected failure when no executable is found")
            return
        }

        #expect(error.localizedDescription.contains("Tailscale CLI not found"))
    }

    @Test
    func statusReturnsSuccessForNonEmptyOutput() {
        defer { TailscaleService.resetDependencies() }

        TailscaleService.setIsExecutableFile { _ in true }
        TailscaleService.setRunCommand { _, _ in
            .init(terminationStatus: 0, output: "100.64.0.1    macbook    online")
        }

        let result = TailscaleService.status()

        guard case .success(let output) = result else {
            Issue.record("Expected success result")
            return
        }

        #expect(output == "100.64.0.1    macbook    online")
    }

    @Test
    func statusReturnsFallbackMessageForEmptyOutput() {
        defer { TailscaleService.resetDependencies() }

        TailscaleService.setIsExecutableFile { _ in true }
        TailscaleService.setRunCommand { _, _ in
            .init(terminationStatus: 0, output: "")
        }

        let result = TailscaleService.status()

        guard case .success(let output) = result else {
            Issue.record("Expected success result")
            return
        }

        #expect(output == "Tailscale returned no output.")
    }

    @Test
    func statusReturnsGenericFailureForNonZeroExitWithoutOutput() {
        defer { TailscaleService.resetDependencies() }

        TailscaleService.setIsExecutableFile { _ in true }
        TailscaleService.setRunCommand { _, _ in
            .init(terminationStatus: 1, output: "")
        }

        let result = TailscaleService.status()

        guard case .failure(let error) = result else {
            Issue.record("Expected failure result")
            return
        }

        #expect(error.localizedDescription == "Unable to read Tailscale status.")
    }

    @Test
    func statusReturnsCommandOutputForNonZeroExitWithOutput() {
        defer { TailscaleService.resetDependencies() }

        TailscaleService.setIsExecutableFile { _ in true }
        TailscaleService.setRunCommand { _, _ in
            .init(terminationStatus: 1, output: "permission denied")
        }

        let result = TailscaleService.status()

        guard case .failure(let error) = result else {
            Issue.record("Expected failure result")
            return
        }

        #expect(error.localizedDescription == "permission denied")
    }

    @Test
    func statusReturnsProcessErrorDescription() {
        struct SampleError: LocalizedError {
            var errorDescription: String? { "spawn failed" }
        }

        defer { TailscaleService.resetDependencies() }

        TailscaleService.setIsExecutableFile { _ in true }
        TailscaleService.setRunCommand { _, _ in
            throw SampleError()
        }

        let result = TailscaleService.status()

        guard case .failure(let error) = result else {
            Issue.record("Expected failure result")
            return
        }

        #expect(error.localizedDescription == "Unable to read Tailscale status: spawn failed")
    }
}
