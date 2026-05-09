import SwiftUI

/// 展示本机 Tailscale 状态文本的弹窗。
///
/// 这个视图不负责自己去执行 `tailscale status`，
/// 而是只接收上层已经准备好的纯文本结果。
/// 这样它可以专注在“如何阅读、复制和关闭”，而不是命令执行细节。
struct TailscaleStatusSheetView: View {
    let statusText: String
    let dismiss: () -> Void
    let copy: () -> Void

    var body: some View {
        /// 使用等宽字体显示 CLI 输出，可以最大程度保留终端排版结构。
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
