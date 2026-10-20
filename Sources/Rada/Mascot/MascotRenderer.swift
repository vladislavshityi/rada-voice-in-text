import SwiftUI

/// Draws the Rada sphere: a soft glossy orb with flowing color inside and a face.
enum MascotRenderer {
    private enum Palette {
        static let cream = Color(red: 1.00, green: 0.89, blue: 0.95)
        static let pink = Color(red: 1.00, green: 0.55, blue: 0.77)
        static let rose = Color(red: 0.94, green: 0.37, blue: 0.65)
        static let magenta = Color(red: 0.94, green: 0.28, blue: 0.60)
        static let violet = Color(red: 0.55, green: 0.42, blue: 1.00)
        static let lavender = Color(red: 0.73, green: 0.64, blue: 1.00)
        static let peach = Color(red: 1.00, green: 0.69, blue: 0.60)
        static let plum = Color(red: 0.17, green: 0.07, blue: 0.27)
        static let blush = Color(red: 1.00, green: 0.24, blue: 0.55)
    }

    /// Fraction of the canvas taken by the sphere radius; leaves room for glow and motion.
    static let radiusRatio: CGFloat = 0.36

    static func draw(_ frame: MascotFrame, in context: inout GraphicsContext, size: CGSize, glow: Bool = true) {
        let pose = frame.pose
        let radius = min(size.width, size.height) * radiusRatio * pose.scale
        let center = CGPoint(x: size.width / 2 + pose.shake * radius, y: size.height / 2 + pose.hop * radius)
        let outline = outlinePath(center: center, radius: radius, wobble: pose.wobble, time: frame.time)

        if glow { drawGlow(outline, radius: radius, energy: pose.energy, in: context) }
        drawBody(outline, center: center, radius: radius, in: context)
        drawFluid(outline, center: center, radius: radius, frame: frame, in: context)
        drawLighting(outline, center: center, radius: radius, in: context)
        drawFace(center: center, radius: radius, frame: frame, in: context)
    }

    // MARK: - Sphere

    /// A circle whose radius breathes with a few slow sine harmonics.
    static func outlinePath(center: CGPoint, radius: CGFloat, wobble: CGFloat, time: TimeInterval) -> Path {
        let steps = 96
        let t = CGFloat(time)
        var path = Path()
        for step in 0...steps {
            let angle = CGFloat(step) / CGFloat(steps) * 2 * .pi
            let distortion = 0.55 * sin(3 * angle + 1.1 * t)
                + 0.30 * sin(5 * angle - 1.6 * t + 1.7)
                + 0.15 * sin(2 * angle + 0.7 * t + 0.4)
            let r = radius * (1 + wobble * distortion)
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private static func drawGlow(_ outline: Path, radius: CGFloat, energy: CGFloat, in context: GraphicsContext) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.32))
            layer.opacity = 0.35 + 0.25 * energy
            layer.translateBy(x: 0, y: radius * 0.12)
            layer.fill(outline, with: .color(Palette.rose))
        }
    }

    private static func drawBody(_ outline: Path, center: CGPoint, radius: CGFloat, in context: GraphicsContext) {
        let gradient = Gradient(stops: [
            .init(color: Palette.cream, location: 0),
            .init(color: Palette.pink, location: 0.38),
            .init(color: Palette.rose, location: 0.66),
            .init(color: Palette.violet, location: 1),
        ])
        context.fill(outline, with: .radialGradient(
            gradient,
            center: CGPoint(x: center.x - radius * 0.32, y: center.y - radius * 0.42),
            startRadius: 0, endRadius: radius * 1.65
        ))
    }

    /// Colored clouds orbiting inside the sphere — the «alive» part.
    private static func drawFluid(_ outline: Path, center: CGPoint, radius: CGFloat, frame: MascotFrame, in context: GraphicsContext) {
        let phase = frame.swirlPhase
        let clouds: [(color: Color, orbit: CGFloat, size: CGFloat, angle: CGFloat)] = [
            (Palette.magenta, 0.55, 0.72, phase * 1.0),
            (Palette.violet, 0.62, 0.80, -phase * 0.8 + 2.1),
            (Palette.peach, 0.50, 0.58, phase * 1.3 + 4.2),
            (Palette.lavender, 0.34, 0.52, -phase * 1.7 + 1.0),
        ]
        context.drawLayer { layer in
            layer.clip(to: outline)
            layer.addFilter(.blur(radius: radius * 0.3))
            layer.opacity = 0.42 + 0.48 * frame.pose.energy
            for cloud in clouds {
                let position = CGPoint(
                    x: center.x + cos(cloud.angle) * cloud.orbit * radius,
                    y: center.y + sin(cloud.angle) * cloud.orbit * radius * 0.85
                )
                let size = cloud.size * radius
                layer.fill(
                    Path(ellipseIn: CGRect(x: position.x - size / 2, y: position.y - size / 2, width: size, height: size)),
                    with: .color(cloud.color)
                )
            }
        }
    }

    private static func drawLighting(_ outline: Path, center: CGPoint, radius: CGFloat, in context: GraphicsContext) {
        // Shade at the bottom gives volume.
        context.drawLayer { layer in
            layer.clip(to: outline)
            layer.addFilter(.blur(radius: radius * 0.22))
            let shade = CGRect(x: center.x - radius * 0.85, y: center.y + radius * 0.45, width: radius * 1.7, height: radius * 0.8)
            layer.fill(Path(ellipseIn: shade), with: .color(Palette.plum.opacity(0.2)))
        }
        // Soft specular highlight, upper left.
        context.drawLayer { layer in
            layer.clip(to: outline)
            layer.addFilter(.blur(radius: radius * 0.07))
            layer.translateBy(x: center.x - radius * 0.36, y: center.y - radius * 0.5)
            layer.rotate(by: .radians(-0.5))
            let highlight = CGRect(x: -radius * 0.3, y: -radius * 0.15, width: radius * 0.6, height: radius * 0.3)
            layer.fill(Path(ellipseIn: highlight), with: .color(.white.opacity(0.62)))
        }
        // Thin rim light.
        context.stroke(
            outline,
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0.55), .white.opacity(0), .white.opacity(0.18)]),
                startPoint: CGPoint(x: center.x, y: center.y - radius),
                endPoint: CGPoint(x: center.x, y: center.y + radius)
            ),
            lineWidth: max(0.6, radius * 0.022)
        )
    }

    // MARK: - Face

    private static func drawFace(center: CGPoint, radius: CGFloat, frame: MascotFrame, in context: GraphicsContext) {
        let pose = frame.pose
        let eyeWidth = radius * 0.17 * pose.eyeScale
        let eyeHeight = radius * 0.30 * pose.eyeScale

        // Blush.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.06))
            layer.opacity = 0.22 + 0.35 * pose.smile
            for side: CGFloat in [-1, 1] {
                let cheek = CGRect(
                    x: center.x + side * radius * 0.5 - radius * 0.1, y: center.y + radius * 0.14,
                    width: radius * 0.2, height: radius * 0.1
                )
                layer.fill(Path(ellipseIn: cheek), with: .color(Palette.blush))
            }
        }

        for side: CGFloat in [-1, 1] {
            let eyeCenter = CGPoint(
                x: center.x + side * radius * 0.3 + pose.lookX * radius * 0.1,
                y: center.y - radius * 0.04 + pose.lookY * radius * 0.09
            )
            drawRoundEye(at: eyeCenter, side: side, width: eyeWidth, height: eyeHeight, pose: pose, in: context)
            drawHappyEye(at: eyeCenter, width: eyeWidth, height: eyeHeight, pose: pose, in: context)
        }

        if pose.dots > 0.01 { drawThinkingDots(center: center, radius: radius, frame: frame, in: context) }
    }

    private static func drawRoundEye(at point: CGPoint, side: CGFloat, width: CGFloat, height: CGFloat, pose: MascotPose, in context: GraphicsContext) {
        guard pose.smile < 0.99 else { return }
        var eye = context
        eye.opacity = 1 - pose.smile
        eye.translateBy(x: point.x, y: point.y)
        // Worried eyes lean their tops outward.
        eye.rotate(by: .radians(side * pose.eyeTilt))
        let openHeight = max(height * pose.eyeOpenness, width * 0.42)
        let rect = CGRect(x: -width / 2, y: -openHeight / 2, width: width, height: openHeight)
        eye.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(Palette.plum))

        let glint = max(0, (pose.eyeOpenness - 0.5) * 2)
        guard glint > 0 else { return }
        let glintSize = width * 0.42
        let glintRect = CGRect(x: -width * 0.05, y: -openHeight * 0.36, width: glintSize, height: glintSize)
        eye.fill(Path(ellipseIn: glintRect), with: .color(.white.opacity(0.9 * glint)))
    }

    private static func drawHappyEye(at point: CGPoint, width: CGFloat, height: CGFloat, pose: MascotPose, in context: GraphicsContext) {
        guard pose.smile > 0.01 else { return }
        var arc = Path()
        arc.move(to: CGPoint(x: point.x - width * 0.8, y: point.y + height * 0.14))
        arc.addQuadCurve(
            to: CGPoint(x: point.x + width * 0.8, y: point.y + height * 0.14),
            control: CGPoint(x: point.x, y: point.y - height * 0.55)
        )
        var layer = context
        layer.opacity = pose.smile
        layer.stroke(arc, with: .color(Palette.plum), style: StrokeStyle(lineWidth: width * 0.52, lineCap: .round))
    }

    /// Three pulsing dots while Rada is thinking.
    private static func drawThinkingDots(center: CGPoint, radius: CGFloat, frame: MascotFrame, in context: GraphicsContext) {
        for index in 0..<3 {
            let pulse = 0.5 + 0.5 * CGFloat(sin(frame.time * 5.5 - Double(index) * 0.9))
            let size = radius * 0.085 * (0.8 + 0.35 * pulse)
            let position = CGPoint(x: center.x + CGFloat(index - 1) * radius * 0.16, y: center.y + radius * 0.36)
            let dot = CGRect(x: position.x - size / 2, y: position.y - size / 2, width: size, height: size)
            context.fill(Path(ellipseIn: dot), with: .color(Palette.plum.opacity(frame.pose.dots * (0.35 + 0.65 * pulse))))
        }
    }
}
