import SwiftUI

/// 主窗口底部的配置栏，提供配置路径、配置复制和重载入口。
///
/// 这一块的定位更像“调试/维护工具条”：
/// 平时不一定频繁使用，但当用户想确认配置文件在哪、复制完整 JSON、
/// 或手动从磁盘重新加载配置时，这里提供了固定入口。
struct ConfigPathFooterView: View {
    let configPath: String
    let didCopyConfig: Bool
    let didCopyPath: Bool
    let copyConfig: () -> Void
    let copyPath: () -> Void
    let reload: () -> Void

    var body: some View {
        /// 左边展示路径，右边集中放低频但实用的维护动作。
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Config File", systemImage: "doc.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .help("RemoteDock host configuration file")

                Text(configPath.isEmpty ? "Config path unavailable" : configPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            Button(action: copyConfig) {
                Label(didCopyConfig ? "Copied Config" : "Copy Config", systemImage: didCopyConfig ? "checkmark" : "curlybraces")
            }
            .buttonStyle(.bordered)
            .help("Copy the full configuration JSON")

            Button(action: copyPath) {
                Label(didCopyPath ? "Copied" : "Copy Path", systemImage: didCopyPath ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .disabled(configPath.isEmpty)
            .help("Copy the config file path")

            Button(action: reload) {
                Label("Reload", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .help("Reload hosts from disk")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        }
    }
}
