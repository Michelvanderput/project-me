import SwiftUI

/// Zacht bewegende mesh-achtergrond die meekleurt met het moment van de dag.
/// Staat stil bij 'Verminder beweging'.
struct AmbientBackground: View {
    var tone: Tone = .auto
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    enum Tone { case auto, dawn, dusk, water, sage, rose }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            MeshGradient(
                width: 3, height: 3,
                points: points(t),
                colors: colors
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func points(_ t: Double) -> [SIMD2<Float>] {
        let a = Float(sin(t / 7) * 0.08)
        let b = Float(cos(t / 9) * 0.08)
        return [
            [0, 0], [0.5 + a, 0], [1, 0],
            [0, 0.5 + b], [0.5 - a, 0.5 + a], [1, 0.5 - b],
            [0, 1], [0.5 + b, 1], [1, 1],
        ]
    }

    private var resolved: Tone {
        guard tone == .auto else { return tone }
        switch Date.now.dayPart {
        case .morning: return .dawn
        case .afternoon: return .rose
        case .evening, .night: return .dusk
        }
    }

    private var colors: [Color] {
        let base = Theme.Palette.canvas
        let (soft, strong): (Color, Color) = switch resolved {
        case .dawn, .auto: (Theme.Palette.dawnSoft, Theme.Palette.dawn)
        case .dusk: (Theme.Palette.duskSoft, Theme.Palette.dusk)
        case .water: (Theme.Palette.waterSoft, Theme.Palette.water)
        case .sage: (Theme.Palette.sageSoft, Theme.Palette.sage)
        case .rose: (Theme.Palette.roseSoft, Theme.Palette.rose)
        }
        let glow = strong.opacity(colorScheme == .dark ? 0.28 : 0.22)
        return [
            soft, base, soft,
            base, glow, base,
            soft, base, base,
        ]
    }
}
