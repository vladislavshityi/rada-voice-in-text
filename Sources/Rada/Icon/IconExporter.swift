import AppKit
import SwiftUI

/// Renders the app icon (mascot on a soft squircle) into an `.iconset` folder.
@MainActor
enum IconExporter {
    static func exportIconset(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let suffix = scale == 1 ? "" : "@2x"
                let url = directory.appending(path: "icon_\(points)x\(points)\(suffix).png")
                write(AppIconView(), pixels: points * scale, to: url)
            }
        }
    }

    private static func write(_ view: some View, pixels: Int, to url: URL) {
        let renderer = ImageRenderer(content: view.frame(width: 1024, height: 1024))
        renderer.scale = CGFloat(pixels) / 1024
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else { return }
        try? png.write(to: url)
    }
}

/// macOS icon grid: an 824 pt squircle centered in a 1024 pt canvas.
private struct AppIconView: View {
    var body: some View {
        let squircle = RoundedRectangle(cornerRadius: 185, style: .continuous)
        ZStack {
            LinearGradient(
                colors: [Color(red: 1, green: 0.97, blue: 0.99), Color(red: 0.94, green: 0.90, blue: 1)],
                startPoint: .top, endPoint: .bottom
            )
            // A soft pink halo under the sphere, kept inside the squircle.
            Circle()
                .fill(Color(red: 0.94, green: 0.37, blue: 0.65).opacity(0.28))
                .frame(width: 560, height: 560)
                .blur(radius: 60)
                .offset(y: 60)
            MascotPortrait(glow: false)
                .frame(width: 860, height: 860)
        }
        .frame(width: 824, height: 824)
        .clipShape(squircle)
        .overlay(squircle.strokeBorder(Color.white.opacity(0.7), lineWidth: 3))
        .shadow(color: .black.opacity(0.2), radius: 14, y: 10)
        .frame(width: 1024, height: 1024)
    }
}
