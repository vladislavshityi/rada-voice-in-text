import SwiftUI

/// Renders a shortcut as individual key caps: ⌥ Space.
struct KeyCaps: View {
    var tokens: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                Text(token)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .padding(.horizontal, 7)
                    .frame(minWidth: 24, minHeight: 22)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            }
        }
    }
}
