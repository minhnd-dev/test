import SwiftUI

struct FloatingPanelView: View {
    var text: String
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "text.viewfinder")
                    .foregroundColor(.accentColor)
                Text("Captured Text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                Text(text)
                    .textSelection(.enabled)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .frame(minWidth: 280, minHeight: 120)
    }
}
