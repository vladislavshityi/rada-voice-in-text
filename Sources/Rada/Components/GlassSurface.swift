import SwiftUI

extension View {
    /// Liquid Glass on macOS 26+, translucent material on earlier systems.
    @ViewBuilder
    func glassSurface<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }
}
