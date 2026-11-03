import AppIntents
import SwiftUI
import WidgetKit

struct WaterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WaterWidget", provider: DayProvider()) { entry in
            WaterWidgetView(snapshot: entry.snapshot)
                .widgetURL(DeepLink.water.url)
        }
        .configurationDisplayName("Water")
        .description("Je water van vandaag, met een knop om meteen een glas toe te voegen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct WaterWidgetView: View {
    let snapshot: DaySnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: snapshot.waterProgress) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Text("\(Int(snapshot.waterProgress * 100))")
            }
            .gaugeStyle(.accessoryCircular)
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Water", systemImage: "drop.fill").font(.headline).widgetAccentable()
                Text("\(snapshot.waterML) / \(snapshot.waterGoal) ml").font(.caption).monospacedDigit()
                ProgressView(value: snapshot.waterProgress).tint(Theme.Palette.water)
            }
            .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            Label("\(snapshot.waterML) / \(snapshot.waterGoal) ml", systemImage: "drop.fill")
                .containerBackground(for: .widget) { Color.clear }
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                WidgetRing(progress: snapshot.waterProgress, tint: Theme.Palette.water, symbol: "drop.fill")
                    .frame(width: 52, height: 52)
                Spacer()
            }
            Spacer(minLength: 0)
            Text("\(snapshot.waterML) ml")
                .font(.title3.weight(.bold).monospacedDigit())
                .contentTransition(.numericText(value: Double(snapshot.waterML)))
                .foregroundStyle(Theme.Palette.ink)
            Text("van \(snapshot.waterGoal) ml").font(.caption).foregroundStyle(Theme.Palette.inkSecondary)
            Button(intent: AddWaterIntent(amount: 250)) {
                Label("250 ml", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Palette.water)
            .controlSize(.small)
        }
        .containerBackground(for: .widget) { WidgetBackground(soft: Theme.Palette.waterSoft) }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetRing(progress: snapshot.waterProgress, tint: Theme.Palette.water, symbol: "drop.fill")
                    .frame(width: 64, height: 64)
                Spacer(minLength: 0)
                Text("\(snapshot.waterML) ml")
                    .font(.title2.weight(.bold).monospacedDigit())
                    .contentTransition(.numericText(value: Double(snapshot.waterML)))
                    .foregroundStyle(Theme.Palette.ink)
                Text(snapshot.waterML >= snapshot.waterGoal ? "Doel gehaald 💧" : "nog \(snapshot.waterGoal - snapshot.waterML) ml")
                    .font(.caption).foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer(minLength: 0)
            VStack(spacing: 8) {
                ForEach(Array(Prefs.glassSizes.prefix(3)), id: \.self) { size in
                    Button(intent: AddWaterIntent(amount: size)) {
                        Text("+\(size) ml")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.Palette.water)
                }
            }
            .frame(width: 120)
        }
        .containerBackground(for: .widget) { WidgetBackground(soft: Theme.Palette.waterSoft) }
    }
}

struct WidgetRing: View {
    let progress: Double
    let tint: Color
    let symbol: String

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbol).font(.body.weight(.semibold)).foregroundStyle(tint)
        }
        .widgetAccentable()
    }
}

struct WidgetBackground: View {
    let soft: Color
    var body: some View {
        LinearGradient(colors: [soft, Theme.Palette.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Control Center / toegangsscherm / Actieknop: één tik = 250 ml.
struct WaterControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "nl.michelvanderput.projectme.water-control") {
            ControlWidgetButton(action: AddWaterIntent(amount: 250)) {
                Label("+250 ml water", systemImage: "drop.fill")
            }
        }
        .displayName("Water toevoegen")
        .description("Voeg met één tik 250 ml water toe.")
    }
}
