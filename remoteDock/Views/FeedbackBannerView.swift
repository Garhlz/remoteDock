import SwiftUI

/// 顶部自动消失的反馈横幅视图。
///
/// 这是整个应用统一的轻量反馈组件。
/// 上层只需要提供 `FeedbackMessage` 和关闭动作，
/// 它就会根据成功/失败自动切换图标、颜色和标题。
struct FeedbackBannerView: View {
    let feedback: FeedbackMessage
    let dismiss: () -> Void

    var body: some View {
        /// 成功和失败都走同一套布局，只通过 `feedback.kind` 切换视觉语义。
        HStack(spacing: 12) {
            Image(systemName: feedback.kind.systemImage)
                .font(.headline)
                .foregroundStyle(feedback.kind.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(feedback.kind.title)
                    .font(.subheadline.weight(.semibold))

                Text(feedback.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            Button(action: dismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(feedback.kind.tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(feedback.kind.tint.opacity(0.28))
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.18), value: feedback.id)
    }
}
