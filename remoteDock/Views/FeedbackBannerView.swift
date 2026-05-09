import SwiftUI

struct FeedbackBannerView: View {
    let feedback: FeedbackMessage
    let dismiss: () -> Void

    var body: some View {
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
