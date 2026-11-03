import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Water in de Dynamic Island

struct WaterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WaterActivityAttributes.self) { context in
            WaterLockScreenView(state: context.state)
                .activityBackgroundTint(Theme.Palette.waterSoft.opacity(0.85))
                .activitySystemActionForegroundColor(Theme.Palette.water)
                .widgetURL(DeepLink.water.url)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WidgetRing(progress: state.progress, tint: Theme.Palette.water, symbol: "drop.fill")
                        .frame(width: 44, height: 44)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 0) {
                        Text("\(state.totalML) ml")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .contentTransition(.numericText(value: Double(state.totalML)))
                        Text(state.remainingML == 0 ? "Doel gehaald! 💧" : "nog \(state.remainingML) ml")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int(state.progress * 100))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Theme.Palette.water)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        ForEach([150, 250, 500], id: \.self) { size in
                            Button(intent: AddWaterIntent(amount: size)) {
                                Label("\(size)", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(Theme.Palette.water)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "drop.fill").foregroundStyle(Theme.Palette.water)
            } compactTrailing: {
                Text(compactML(state.totalML))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.Palette.water)
                    .contentTransition(.numericText(value: Double(state.totalML)))
            } minimal: {
                Gauge(value: state.progress) { Image(systemName: "drop.fill") }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(Theme.Palette.water)
            }
            .keylineTint(Theme.Palette.water)
            .widgetURL(DeepLink.water.url)
        }
    }
}

private func compactML(_ ml: Int) -> String {
    ml >= 1000 ? (Double(ml) / 1000).formatted(.number.precision(.fractionLength(1))) + "L" : "\(ml)"
}

private struct WaterLockScreenView: View {
    let state: WaterActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            WidgetRing(progress: state.progress, tint: Theme.Palette.water, symbol: "drop.fill")
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text("Water vandaag").font(.caption.weight(.semibold)).foregroundStyle(Theme.Palette.inkSecondary)
                Text("\(state.totalML) / \(state.goalML) ml")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.Palette.ink)
                    .contentTransition(.numericText(value: Double(state.totalML)))
                Text(state.remainingML == 0 ? "Doel gehaald, goed zo!" : "Nog \(state.remainingML) ml te gaan")
                    .font(.caption).foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer()
            VStack(spacing: 6) {
                Button(intent: AddWaterIntent(amount: 250)) {
                    Label("250", systemImage: "plus").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Palette.water)
                Button(intent: AddWaterIntent(amount: 500)) {
                    Label("500", systemImage: "plus").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Theme.Palette.water)
            }
        }
        .padding(16)
    }
}

// MARK: - Meditatie in de Dynamic Island

struct MeditationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeditationActivityAttributes.self) { context in
            MeditationLockScreenView(kind: context.attributes.kind, state: context.state)
                .activityBackgroundTint(meditationTint(context.attributes.kind).opacity(0.12))
                .widgetURL((context.attributes.kind == .morning ? DeepLink.meditationMorning : .meditationEvening).url)
        } dynamicIsland: { context in
            let kind = context.attributes.kind
            let state = context.state
            let color = meditationTint(kind)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: kind.symbol)
                        .font(.title2)
                        .foregroundStyle(color)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(kind.title).font(.caption).foregroundStyle(.secondary)
                        Text(state.phase).font(.headline).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if state.isFinished {
                        Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(color)
                    } else {
                        Text(timerInterval: state.sessionStart...state.sessionEnd, countsDown: true)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(color)
                            .frame(width: 56)
                            .multilineTextAlignment(.trailing)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !state.isFinished {
                        ProgressView(timerInterval: state.sessionStart...state.sessionEnd, countsDown: false) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(color)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                    }
                }
            } compactLeading: {
                Image(systemName: kind.symbol).foregroundStyle(color)
            } compactTrailing: {
                if state.isFinished {
                    Image(systemName: "checkmark").foregroundStyle(color)
                } else {
                    Text(timerInterval: state.sessionStart...state.sessionEnd, countsDown: true)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(color)
                        .frame(maxWidth: 44)
                }
            } minimal: {
                Image(systemName: kind.symbol).foregroundStyle(color)
            }
            .keylineTint(color)
        }
    }
}

private func meditationTint(_ kind: MeditationKind) -> Color {
    kind == .morning ? Theme.Palette.dawn : Theme.Palette.dusk
}

private struct MeditationLockScreenView: View {
    let kind: MeditationKind
    let state: MeditationActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: kind.symbol)
                .font(.title)
                .foregroundStyle(meditationTint(kind))
                .frame(width: 52, height: 52)
                .background(meditationTint(kind).opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title).font(.caption.weight(.semibold)).foregroundStyle(Theme.Palette.inkSecondary)
                Text(state.phase).font(.headline).foregroundStyle(Theme.Palette.ink)
                if !state.isFinished {
                    ProgressView(timerInterval: state.sessionStart...state.sessionEnd, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(meditationTint(kind))
                }
            }
            Spacer()
            if state.isFinished {
                Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(meditationTint(kind))
            } else {
                Text(timerInterval: state.sessionStart...state.sessionEnd, countsDown: true)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(meditationTint(kind))
                    .frame(width: 72)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(16)
    }
}
