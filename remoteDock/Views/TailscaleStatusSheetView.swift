import SwiftUI

struct TailscaleStatusSheetView: View {
    let statusText: String
    let dismiss: () -> Void
    let copy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Local Tailscale Status")
                    .font(.title2.bold())

                Spacer()

                Button("Done", action: dismiss)
            }

            ScrollView {
                Text(statusText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(14)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Spacer()

                Button("Copy", action: copy)
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(minWidth: 640, minHeight: 420)
    }
}
