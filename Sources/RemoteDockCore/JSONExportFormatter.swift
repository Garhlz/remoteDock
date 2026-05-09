import Foundation

/// 统一生成稳定、可读的 JSON 导出文本。
///
/// 之所以单独抽一个 helper，是为了让：
/// - 导出整个配置
/// - 导出单个主机
/// 共享完全一致的 JSON 编码策略，避免不同入口导出的格式不一致。
enum JSONExportFormatter {
    /// 使用 pretty printed + sorted keys 输出稳定文本，
    /// 便于复制、阅读、比对和测试断言。
    static func formattedString<T: Encodable>(from value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)

        guard let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }

        return string
    }
}
