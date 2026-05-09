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
    let isCompact: Bool
    let copyConfig: () -> Void
    let copyPath: () -> Void
    let reload: () -> Void

    var body: some View {
        /// 底部维护条在窄窗口里允许换行，避免路径和按钮彼此挤压。
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                pathBlock

                Spacer(minLength: 12)

                actionButtons
            }

            VStack(alignment: .leading, spacing: 10) {
                pathBlock
                actionButtons
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCompact ? 10 : 12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        }
    }

    private var pathBlock: some View {
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
    }

    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                copyConfigButton
                copyPathButton
                reloadButton
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    copyConfigButton
                    copyPathButton
                }

                reloadButton
            }
        }
    }

    private var copyConfigButton: some View {
        Button(action: copyConfig) {
            Label(didCopyConfig ? "Copied Config" : "Copy Config", systemImage: didCopyConfig ? "checkmark" : "curlybraces")
        }
        .buttonStyle(.bordered)
        .help("Copy the full configuration JSON")
    }

    private var copyPathButton: some View {
        Button(action: copyPath) {
            Label(didCopyPath ? "Copied" : "Copy Path", systemImage: didCopyPath ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.bordered)
        .disabled(configPath.isEmpty)
        .help("Copy the config file path")
    }

    private var reloadButton: some View {
        Button(action: reload) {
            Label("Reload", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .help("Reload hosts from disk")
    }
}
