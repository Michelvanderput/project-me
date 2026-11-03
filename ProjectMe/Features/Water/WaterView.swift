import Charts
import SwiftData
import SwiftUI

struct WaterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(PrefKey.waterGoalML, store: AppGroup.defaults) private var goal = 2000
    @Query private var todayLogs: [WaterLog]
    @Query private var weekLogs: [WaterLog]
    @State private var custom = 200
    @State private var bump = 0
    @State private var liveActive = LiveActivityService.isWaterActive

    init() {
        let start = Date.now.startOfDay
        let end = Date.now.endOfDay
        let weekStart = start.adding(days: -6)
        _todayLogs = Query(filter: #Predicate<WaterLog> { $0.date >= start && $0.date < end },
                           sort: \WaterLog.date, order: .reverse)
        _weekLogs = Query(filter: #Predicate<WaterLog> { $0.date >= weekStart }, sort: \WaterLog.date)
    }

    private var total: Int { todayLogs.reduce(0) { $0 + $1.amountML } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: Theme.Space.m) {
                        ZStack {
                            ProgressRing(progress: Double(total) / Double(max(goal, 1)), tint: Theme.Palette.water, lineWidth: 18)
                            VStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .font(.title)
                                    .foregroundStyle(Theme.Palette.water)
                                    .symbolEffect(.bounce, value: bump)
                                Text("\(total.formatted()) ml")
                                    .font(.title.weight(.bold).monospacedDigit())
                                    .contentTransition(.numericText(value: Double(total)))
                                Text("van \(goal.formatted()) ml").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 210, height: 210)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Space.s)

                        HStack(spacing: Theme.Space.xs) {
                            ForEach(Prefs.glassSizes, id: \.self) { size in
                                Button { add(size) } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: size >= 400 ? "waterbottle.fill" : "cup.and.saucer.fill")
                                        Text("\(size)").font(.subheadline.weight(.semibold).monospacedDigit())
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 60)
                                }
                                .buttonStyle(.glass)
                                .tint(Theme.Palette.water)
                                .accessibilityLabel("\(size) milliliter toevoegen")
                            }
                        }
                        HStack {
                            Stepper("\(custom) ml", value: $custom, in: 50...1000, step: 50)
                                .monospacedDigit()
                            Button("Voeg toe") { add(custom) }
                                .buttonStyle(.glassProminent).tint(Theme.Palette.water)
                        }
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: bump)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Toggle(isOn: Binding(get: { liveActive }, set: toggleLive)) {
                        Label("Toon in Dynamic Island", systemImage: "platter.filled.top.iphone")
                    }
                    .tint(Theme.Palette.water)
                } footer: {
                    Text("Je voortgang staat dan op je toegangsscherm en in de Dynamic Island. Tik daar op + om meteen een glas toe te voegen.")
                }

                Section("Deze week") {
                    Chart {
                        ForEach(weekTotals, id: \.day) { item in
                            BarMark(x: .value("Dag", item.day, unit: .day), y: .value("ml", item.ml))
                                .foregroundStyle(item.ml >= goal ? Theme.Palette.water : Theme.Palette.water.opacity(0.45))
                                .cornerRadius(6)
                        }
                        RuleMark(y: .value("Doel", goal))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .foregroundStyle(Theme.Palette.inkSecondary)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { _ in AxisValueLabel(format: .dateTime.weekday(.narrow)) }
                    }
                    .frame(height: 160)
                    .accessibilityLabel("Water per dag deze week")
                }

                Section("Vandaag") {
                    if todayLogs.isEmpty {
                        Text("Nog niets gedronken. Begin met een glas, je lichaam wacht erop. 💧")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(todayLogs) { log in
                        HStack {
                            Label("\(log.amountML) ml", systemImage: "drop")
                                .foregroundStyle(Theme.Palette.ink)
                            Spacer()
                            Text(log.date, format: .dateTime.hour().minute())
                                .foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { WaterStore.remove(todayLogs[index], in: context) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { AmbientBackground(tone: .water) }
            .navigationTitle("Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .onAppear { custom = LearningEngine.preferredGlassSize(in: context) }
    }

    private var weekTotals: [DayTotal] {
        let grouped = Dictionary(grouping: weekLogs, by: { $0.date.startOfDay })
        return (0..<7).map { offset in
            let day = Date.now.startOfDay.adding(days: offset - 6)
            return DayTotal(day: day, ml: grouped[day]?.reduce(0) { $0 + $1.amountML } ?? 0)
        }
    }

    struct DayTotal { let day: Date; let ml: Int }

    private func add(_ ml: Int) {
        WaterStore.add(ml, in: context)
        bump += 1
        Task { await NotificationService.shared.rescheduleWater(context: context) }
    }

    private func toggleLive(_ on: Bool) {
        if on { LiveActivityService.startWater(context: context) } else { Task { await LiveActivityService.endWater() } }
        liveActive = on
    }
}
