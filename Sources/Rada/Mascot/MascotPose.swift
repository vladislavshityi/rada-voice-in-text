import CoreGraphics

/// Every animatable parameter of the mascot. The animator blends between
/// poses, so mood changes are always smooth.
struct MascotPose {
    /// Overall size multiplier (breathing, voice).
    var scale: CGFloat = 1
    /// Amplitude of the organic wobble of the outline.
    var wobble: CGFloat = 0.012
    /// Speed of the fluid colors inside the sphere.
    var swirlSpeed: CGFloat = 0.35
    /// Saturation of the fluid colors (0 = calm, 1 = vivid).
    var energy: CGFloat = 0.3
    /// 1 = open eyes, 0 = closed.
    var eyeOpenness: CGFloat = 1
    /// 0 = round eyes, 1 = happy «^ ^» arcs.
    var smile: CGFloat = 0
    /// Tilt of the eyes in radians; positive looks worried.
    var eyeTilt: CGFloat = 0
    var eyeScale: CGFloat = 1
    /// Gaze direction, −1…1.
    var lookX: CGFloat = 0
    var lookY: CGFloat = 0
    /// Opacity of the «thinking» dots.
    var dots: CGFloat = 0
    /// Vertical hop, in sphere radii.
    var hop: CGFloat = 0
    /// Horizontal shake, in sphere radii.
    var shake: CGFloat = 0

    /// Linear interpolation toward `target` by `amount` (0…1).
    func blended(toward target: MascotPose, amount t: CGFloat) -> MascotPose {
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * t }
        return MascotPose(
            scale: mix(scale, target.scale), wobble: mix(wobble, target.wobble),
            swirlSpeed: mix(swirlSpeed, target.swirlSpeed), energy: mix(energy, target.energy),
            eyeOpenness: mix(eyeOpenness, target.eyeOpenness), smile: mix(smile, target.smile),
            eyeTilt: mix(eyeTilt, target.eyeTilt), eyeScale: mix(eyeScale, target.eyeScale),
            lookX: mix(lookX, target.lookX), lookY: mix(lookY, target.lookY),
            dots: mix(dots, target.dots), hop: mix(hop, target.hop), shake: mix(shake, target.shake)
        )
    }

    /// Resting pose for a mood, before time-based motion is added.
    static func base(for mood: MascotMood) -> MascotPose {
        switch mood {
        case .idle:
            MascotPose()
        case .listening:
            MascotPose(scale: 1.02, wobble: 0.018, swirlSpeed: 0.9, energy: 0.75, eyeScale: 1.08)
        case .thinking:
            MascotPose(wobble: 0.02, swirlSpeed: 1.8, energy: 0.6, eyeOpenness: 0.8, eyeScale: 0.92,
                       lookX: 0.45, lookY: -0.55, dots: 1)
        case .happy:
            MascotPose(scale: 1.04, wobble: 0.014, swirlSpeed: 0.7, energy: 0.8, smile: 1)
        case .concerned:
            MascotPose(scale: 0.97, wobble: 0.01, swirlSpeed: 0.25, energy: 0.15, eyeOpenness: 0.7,
                       eyeTilt: 0.32, eyeScale: 0.92, lookY: 0.25)
        case .sleepy:
            MascotPose(scale: 0.98, wobble: 0.008, swirlSpeed: 0.2, energy: 0.1, eyeOpenness: 0.06, lookY: 0.2)
        }
    }

    /// The pose used for the app icon and other still images.
    static let portrait = MascotPose(scale: 1, wobble: 0.012, swirlSpeed: 0, energy: 0.55, lookX: 0.05, lookY: -0.05)
}
