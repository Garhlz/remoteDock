import SwiftUI

struct ConfigPathFooterView: View {
    let configPath: String
    let didCopyPath: Bool
    let copyPath: () -> Void
    let reload: () -> Void

    var body: some View {
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
