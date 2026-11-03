import SwiftUI
import WidgetKit

/// Je dagritme in één oogopslag: ochtend, water, avond en het volgende stapje.
struct DayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DayWidget", provider: DayProvider()) { entry in
            DayWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Mijn dag")
        .description("Je ochtend, water en avond, plus het fijnste volgende stapje.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct DayWidgetView: View {
    let snapshot: DaySnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let next = snapshot.nextStep
        Group {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Label("Project Me", systemImage: "sparkles").font(.caption.weight(.semibold)).widgetAccentable()
                    Text(next.title).font(.headline).lineLimit(1)
                    Text("💧 \(snapshot.waterML)/\(snapshot.waterGoal) ml").font(.caption).monospacedDigit()
                }
                .containerBackground(for: .widget) { Color.clear }
            case .systemSmall:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nu").font(.caption.weight(.semibold)).foregroundStyle(Theme.Palette.inkSecondary)
                    Image(systemName: next.symbol).font(.title).foregroundStyle(Theme.Palette.accent)
                    Text(next.title).font(.headline).foregroundStyle(Theme.Palette.ink).lineLimit(2)
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        dot(snapshot.morningDone, Theme.Palette.dawn)
                        dot(snapshot.waterML >= snapshot.waterGoal, Theme.Palette.water)
                        dot(snapshot.eveningDone, Theme.Palette.dusk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerBackground(for: .widget) { WidgetBackground(soft: Theme.Palette.dawnSoft) }
            default:
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(greeting).font(.headline).foregroundStyle(Theme.Palette.ink)
                        Spacer()
                        Image(systemName: "sparkles").foregroundStyle(Theme.Palette.accent)
                    }
                    HStack(spacing: 8) {
                        RhythmItem(title: "Ochtend", symbol: "sunrise.fill", tint: Theme.Palette.dawn,
                                   done: snapshot.morningDone, link: .morning)
                        RhythmItem(title: "Water", symbol: "drop.fill", tint: Theme.Palette.water,
                                   done: snapshot.waterML >= snapshot.waterGoal, link: .water,
                                   progress: snapshot.waterProgress)
                        RhythmItem(title: "Avond", symbol: "moon.stars.fill", tint: Theme.Palette.dusk,
                                   done: snapshot.eveningDone, link: .evening)
                    }
                    Link(destination: next.link.url) {
                        HStack {
                            Image(systemName: next.symbol)
                            Text(next.title).fontWeight(.semibold)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold))
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Theme.Palette.accent.opacity(0.15), in: .capsule)
                        .foregroundStyle(Theme.Palette.accent)
                    }
                    if family == .systemLarge {
                        Divider()
                        Text("Lief berichtje").font(.caption.weight(.semibold)).foregroundStyle(Theme.Palette.rose)
                        Text(snapshot.motivation)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Theme.Palette.ink)
                        if let happy = snapshot.lastHappyMoment {
                            Spacer(minLength: 0)
                            Text("Uit je boekje").font(.caption.weight(.semibold)).foregroundStyle(Theme.Palette.dusk)
                            Text("“\(happy)”")
                                .font(.system(.callout, design: .serif).italic())
                                .foregroundStyle(Theme.Palette.inkSecondary)
                                .lineLimit(3)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .containerBackground(for: .widget) { WidgetBackground(soft: Theme.Palette.dawnSoft) }
            }
        }
        .widgetURL(next.link.url)
    }

    private var greeting: String {
        let base = switch Date.now.dayPart {
        case .morning: "Goedemorgen"
        case .afternoon: "Goedemiddag"
        case .evening: "Goedenavond"
        case .night: "Welterusten"
        }
        return snapshot.name.isEmpty ? base : "\(base), \(snapshot.name)"
    }

    private func dot(_ done: Bool, _ tint: Color) -> some View {
        Circle()
            .fill(done ? tint : tint.opacity(0.2))
            .frame(width: 10, height: 10)
    }
}

private struct RhythmItem: View {
    let title: String
    let symbol: String
    let tint: Color
    let done: Bool
    let link: DeepLink
    var progress: Double? = nil

    var body: some View {
        Link(destination: link.url) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(tint.opacity(done ? 1 : 0.15))
                    if let progress, !done {
                        Circle().trim(from: 0, to: progress)
                            .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    Image(systemName: done ? "checkmark" : symbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(done ? .white : tint)
                }
                .frame(width: 40, height: 40)
                Text(title).font(.caption2.weight(.medium)).foregroundStyle(Theme.Palette.inkSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Het lieve berichtje van vandaag op je beginscherm.
struct MotivationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MotivationWidget", provider: DayProvider()) { entry in
            MotivationWidgetView(snapshot: entry.snapshot)
                .widgetURL(DeepLink.motivation.url)
        }
        .configurationDisplayName("Lief berichtje")
        .description("Elke dag een warm berichtje, afgestemd op wat jij fijn vindt.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct MotivationWidgetView: View {
    let snapshot: DaySnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .accessoryRectangular {
            Text(snapshot.motivation)
                .font(.caption)
                .lineLimit(3)
                .containerBackground(for: .widget) { Color.clear }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "heart.fill").foregroundStyle(Theme.Palette.rose)
                Text(snapshot.motivation)
                    .font(.system(family == .systemSmall ? .callout : .title3, design: .serif))
                    .foregroundStyle(Theme.Palette.ink)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if !snapshot.name.isEmpty {
                    Text("voor \(snapshot.name)")
                        .font(.caption.italic()).foregroundStyle(Theme.Palette.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { WidgetBackground(soft: Theme.Palette.roseSoft) }
        }
    }
}
