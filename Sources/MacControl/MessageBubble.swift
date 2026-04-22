import SwiftUI

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.isUser { Spacer(minLength: 80) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 5) {
                // ── sender + time ──
                HStack(spacing: 6) {
                    if message.isUser {
                        Text(message.timestamp)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                        Text(message.sender)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.userC)
                    } else {
                        Text(message.sender)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        Text(message.timestamp)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                    }
                }

                // ── bubble ──
                if message.isUser {
                    userBubble
                } else if isMonoList {
                    listBubble
                } else {
                    sysBubble
                }
            }

            if !message.isUser { Spacer(minLength: 80) }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }

    // User bubble — purple gradient
    private var userBubble: some View {
        Text(message.text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.text)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#4B42A8"), Color(hex: "#7C6AF7")],
                            startPoint: .bottomLeading,
                            endPoint: .topTrailing
                        )
                    )
            )
    }

    // System bubble — left accent border
    private var sysBubble: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Theme.accent.opacity(0.55))
                .frame(width: 3)
            Text(message.text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
        }
        .background(Theme.surf3)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // Monospaced scrollable list — left accent border
    private var listBubble: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Theme.accent.opacity(0.55))
                .frame(width: 3)
            ScrollView {
                Text(message.text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.subtext)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 210)
        }
        .background(Theme.surf3)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var isMonoList: Bool {
        let lines = message.text.components(separatedBy: "\n")
        return lines.count > 6 && lines.allSatisfy { $0.count < 60 }
    }
}
