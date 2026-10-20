import SwiftUI

/// A compact status label.
struct Badge: View {
    enum Style {
        case neutral, success, warning, danger, accent

        var tint: Color {
            switch self {
            case .neutral: .secondary
            case .success: .green
            case .warning: .orange
            case .danger: .red
            case .accent: Theme.accent
            }
        }
    }

    var text: String
    var style: Style = .neutral
    var symbol: String?

    init(_ text: String, style: Style = .neutral, symbol: String? = nil) {
        self.text = text
        self.style = style
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol).font(.system(size: 9, weight: .bold)) }
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(style.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(style.tint.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(style.tint.opacity(0.18), lineWidth: 0.5))
    }
}
