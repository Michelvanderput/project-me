import Charts
import SwiftData
import SwiftUI

/// Wat de app over jou leert, en hoe je kaak, nek en water zich ontwikkelen.
/// Bewust zonder streaks: een gemiste dag is geen mislukking.
struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Query private var evenings: [EveningCheckIn]
    @Query private var mornings: [MorningCheckIn]
    @Query private var water: [WaterLog]
    @Query private var meditations: [MeditationSession]
    @State private var range: Period = .month

    enum Period: Int, CaseIterable, Identifiable {
        case week = 7, month = 30, quarter = 90
        var id: Int { rawValue }
        var label: String {
            switch self {
            case .week: "Week"
            case .month: "Maand"
            case .quarter: "3 mnd"
            }
        }
    }

    init() {
        let since = Date.now.adding(days: -90).startOfDay
        _evenings = Query(filter: #Predicate<EveningCheckIn> { $0.day >= since }, sort: \EveningCheckIn.day)
        _mornings = Query(filter: #Predicate<MorningCheckIn> { $0.day >= since }, sort: \MorningCheckIn.day)
        _water = Query(filter: #Predicate<WaterLog> { $0.date >= since }, sort: \WaterLog.date)
        _meditations = Query(filter: #Predicate<MeditationSession> { $0.date >= since })
    }

    private var start: Date { Date.now.startOfDay.adding(days: -(range.rawValue - 1)) }
    private var rangedEvenings: [EveningCheckIn] { evenings.filter { $0.day >= start } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Picker("Periode", selection: $range) {
                        ForEach(Period.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    summary
                    painChart
                    waterChart
                    learned
                }
                .padding(.horizontal, Theme.Space.gutter)
                .padding(.bottom, Theme.Space.xl)
            }
            .background { AmbientBackground(tone: .sage) }
            .navigationTitle("Inzicht")
            .animation(Theme.Motion.standard, value: range)
        }
    }

    // MARK: Samenvatting

    private var summary: some View {
        let morningCount = mornings.filter { $0.day >= start }.count
        let eveningCount = rangedEvenings.count
        let minutes = meditations.filter { $0.date >= start }.reduce(0) { $0 + $1.seconds } / 60
        let moments = rangedEvenings.filter { !$0.happyMoment.isEmpty }.count
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Space.s) {
            StatTile(value: "\(morningCount)", label: "ochtenden", symbol: "sunrise.fill", tint: Theme.Palette.dawn)
            StatTile(value: "\(eveningCount)", label: "avonden", symbol: "moon.stars.fill", tint: Theme.Palette.dusk)
            StatTile(value: "\(minutes)", label: "min. mediteren", symbol: "wind", tint: Theme.Palette.sage)
            StatTile(value: "\(moments)", label: "blije momenten", symbol: "heart.fill", tint: Theme.Palette.rose)
        }
    }

    // MARK: Pijn

    private var painChart: some View {
        Card {
            SectionLabel(title: "Kaak & nek", symbol: "waveform.path.ecg")
            if rangedEvenings.count < 2 {
                Text("Na een paar avond check-ins zie je hier hoe je pijn verloopt.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                HStack(spacing: Theme.Space.m) {
                    averageLabel("Kaak", rangedEvenings.map(\.jawPain), Theme.Palette.dawn)
                    averageLabel("Nek", rangedEvenings.map(\.neckPain), Theme.Palette.dusk)
                }
                Chart {
                    ForEach(rangedEvenings) { evening in
                        LineMark(x: .value("Dag", evening.day, unit: .day), y: .value("Pijn", evening.jawPain))
                            .foregroundStyle(by: .value("Gebied", "Kaak"))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Dag", evening.day, unit: .day), y: .value("Pijn", evening.neckPain))
                            .foregroundStyle(by: .value("Gebied", "Nek"))
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartForegroundStyleScale(["Kaak": Theme.Palette.dawn, "Nek": Theme.Palette.dusk])
                .chartYScale(domain: 0...10)
                .chartYAxis { AxisMarks(values: [0, 5, 10]) }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 200)
                .accessibilityLabel("Grafiek van kaak- en nekpijn")
            }
        }
    }

    private func averageLabel(_ title: String, _ values: [Int], _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Gem. \(title.lowercased())").font(.caption).foregroundStyle(.secondary)
            Text(LearningEngine.format(LearningEngine.average(values)))
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
        }
    }

    // MARK: Water

    private var waterChart: some View {
        let goal = Prefs.waterGoalML
        let grouped = Dictionary(grouping: water.filter { $0.date >= start }, by: { $0.date.startOfDay })
            .mapValues { $0.reduce(0) { $0 + $1.amountML } }
        let days = (0..<range.rawValue).map { start.adding(days: $0) }
        let hitDays = days.filter { (grouped[$0] ?? 0) >= goal }.count
        return Card {
            SectionLabel(title: "Water", symbol: "drop.fill", color: Theme.Palette.water)
            Text("\(hitDays) van de \(days.count) dagen je doel gehaald")
                .font(.subheadline).foregroundStyle(.secondary)
            Chart {
                ForEach(days, id: \.self) { day in
                    BarMark(x: .value("Dag", day, unit: .day), y: .value("ml", grouped[day] ?? 0))
                        .foregroundStyle((grouped[day] ?? 0) >= goal ? Theme.Palette.water : Theme.Palette.water.opacity(0.4))
                }
                RuleMark(y: .value("Doel", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            .frame(height: 160)
            .accessibilityLabel("Grafiek van water per dag")
        }
    }

    // MARK: Geleerd

    @ViewBuilder
    private var learned: some View {
        let insights = LearningEngine.insights(in: context)
        SectionLabel(title: "Wat ik over je leer", symbol: "brain.head.profile")
            .padding(.top, Theme.Space.s)
        if insights.isEmpty {
            Card {
                Text("Hoe vaker je incheckt, hoe beter ik je leer kennen. Na ongeveer een week zie je hier je eerste patronen.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(insights) { insight in
                Card(tint: color(insight.tint)) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title).font(.headline)
                            Text(insight.detail).font(.subheadline).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } icon: {
                        Image(systemName: insight.symbol).foregroundStyle(color(insight.tint)).font(.title3)
                    }
                }
            }
        }
    }

    private func color(_ tint: LearningEngine.InsightTint) -> Color {
        switch tint {
        case .water: Theme.Palette.water
        case .sage: Theme.Palette.sage
        case .dusk: Theme.Palette.dusk
        case .dawn: Theme.Palette.dawn
        case .rose: Theme.Palette.rose
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value).font(.title.weight(.bold).monospacedDigit()).contentTransition(.numericText())
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.control))
        .accessibilityElement(children: .combine)
    }
}
