import Foundation
import Testing
@testable import RemoteDockCore

@Suite(.serialized)
/// 覆盖 Ping 重试、结果解析和依赖注入的测试集合。
///
/// 由于真实 ping 会依赖网络环境，这个 suite 主要通过注入假 runner 来验证：
/// - 重试次数是否正确
/// - 成功后是否会提前返回
/// - 文本解析逻辑是否稳定
struct PingServiceTests {
    /// 最基本的成功路径：runner 返回 reachable 时，简化接口应返回 true。
    @Test
    func checkReturnsTrueWhenRunnerSucceeds() async {
        defer { PingService.resetDependencies() }

        PingService.setRunPing { address in
            PingResult(
                isReachable: address == "100.117.140.113",
                averageLatencyMilliseconds: 12.4,
                packetLossPercentage: 0
            )
        }

        let result = await PingService.check(address: "100.117.140.113")

        #expect(result)
    }

    /// 连续失败时，应保持 false。
    @Test
    func checkReturnsFalseForNonResponsiveHost() async {
        defer { PingService.resetDependencies() }

        PingService.setRunPing { _ in
            PingResult(isReachable: false, averageLatencyMilliseconds: nil, packetLossPercentage: 100)
        }

        let result = await PingService.check(address: "192.168.1.50")

        #expect(result == false)
    }

    /// 确认外部传入的地址确实会传给底层 runner，而不是被改写。
    @Test
    func checkPassesAddressToInjectedRunner() async {
        defer { PingService.resetDependencies() }

        var receivedAddress: String?
        PingService.setRunPing { address in
            receivedAddress = address
            return PingResult(isReachable: true, averageLatencyMilliseconds: 9.8, packetLossPercentage: 0)
        }

        _ = await PingService.check(address: "server.example.com")

        #expect(receivedAddress == "server.example.com")
    }

    /// 如果始终失败，应重试到默认次数上限。
    @Test
    func checkRetriesBeforeReturningOffline() async {
        defer { PingService.resetDependencies() }

        var callCount = 0
        PingService.setRunPing { _ in
            callCount += 1
            return PingResult(isReachable: false, averageLatencyMilliseconds: nil, packetLossPercentage: 100)
        }

        let result = await PingService.check(address: "server.example.com")

        #expect(result == false)
        #expect(callCount == PingService.defaultAttemptCount)
    }

    /// 如果中途某次成功，应该立即停止后续重试。
    @Test
    func checkReturnsTrueWhenLaterRetrySucceeds() async {
        defer { PingService.resetDependencies() }

        var callCount = 0
        PingService.setRunPing { _ in
            callCount += 1
            return PingResult(
                isReachable: callCount == 2,
                averageLatencyMilliseconds: callCount == 2 ? 18.2 : nil,
                packetLossPercentage: callCount == 2 ? 0 : 100
            )
        }

        let result = await PingService.check(address: "server.example.com")

        #expect(result)
        #expect(callCount == 2)
    }

    /// 完整结果接口除了可达性，还要保留延迟和丢包信息。
    @Test
    func checkResultReturnsLatencyWhenPingSucceeds() async {
        defer { PingService.resetDependencies() }

        PingService.setRunPing { _ in
            PingResult(isReachable: true, averageLatencyMilliseconds: 11.7, packetLossPercentage: 0)
        }

        let result = await PingService.checkResult(address: "server.example.com")

        #expect(result.isReachable)
        #expect(result.averageLatencyMilliseconds == 11.7)
        #expect(result.packetLossPercentage == 0)
    }

    /// 这两项测试保护正则解析逻辑，避免系统 ping 输出格式解析回归。
    @Test
    func parseAverageLatencyMillisecondsExtractsAverageValue() {
        let output = """
        PING 100.117.140.113 (100.117.140.113): 56 data bytes
        64 bytes from 100.117.140.113: icmp_seq=0 ttl=64 time=16.321 ms

        --- 100.117.140.113 ping statistics ---
        1 packets transmitted, 1 packets received, 0.0% packet loss
        round-trip min/avg/max/stddev = 16.321/16.321/16.321/0.000 ms
        """

        #expect(PingService.parseAverageLatencyMilliseconds(from: output) == 16.321)
    }

    @Test
    func parsePacketLossPercentageExtractsLossValue() {
        let output = """
        PING 100.117.140.113 (100.117.140.113): 56 data bytes
        64 bytes from 100.117.140.113: icmp_seq=0 ttl=64 time=16.321 ms

        --- 100.117.140.113 ping statistics ---
        3 packets transmitted, 2 packets received, 33.3% packet loss
        round-trip min/avg/max/stddev = 15.842/16.321/16.800/0.479 ms
        """

        #expect(PingService.parsePacketLossPercentage(from: output) == 33.3)
    }
}
