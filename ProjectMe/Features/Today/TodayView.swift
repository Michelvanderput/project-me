import SwiftData
import SwiftUI

/// Het hart van de app: je dagritme in één rustig overzicht.
struct TodayView: View {
    let day: Date
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @AppStorage(PrefKey.userName, store: AppGroup.defaults) private var name = ""
    @AppStorage(PrefKey.waterGoalML, store: AppGroup.defaults) private var waterGoal = 2000

    @Query private var mornings: [MorningCheckIn]
    @Query private var evenings: [EveningCheckIn]
    @Query private var waterLogs: [WaterLog]
    @Query(sort: \EveningCheckIn.day, order: .reverse) private var recentEvenings: [EveningCheckIn]

    init(day: Date) {
        self.day = day
        let start = day.startOfDay
        let end = day.endOfDay
        _mornings = Query(filter: #Predicate<MorningCheckIn> { $0.day == start })
        _evenings = Query(filter: #Predicate<EveningCheckIn> { $0.day == start })
        _waterLogs = Query(filter: #Predicate<WaterLog> { $0.date >= start && $0.date < end })
    }

    private var morning: MorningCheckIn? { mornings.first }
    private var evening: EveningCheckIn? { evenings.first }
    private var waterTotal: Int { waterLogs.reduce(0) { $0 + $1.amountML } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    header
                    MorningCard(checkIn: morning)
                    if Date.now.dayPart != .morning || morning != nil {
                        MotivationCard()
                    }
                    WaterCard(total: waterTotal, goal: waterGoal)
                    EveningCard(checkIn: evening)
                    BodyCard(lastEvening: recentEvenings.first)
                }
                .padding(.horizontal, Theme.Space.gutter)
                .padding(.bottom, Theme.Space.xl)
            }
            .scrollIndicators(.hidden)
            .background { AmbientBackground() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Instellingen", systemImage: "gearshape") { router.sheet = .settings }
                }
            }
            .toolbarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Palette.inkSecondary)
                .textCase(.lowercase)
            Text(greeting)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.Palette.ink)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
        .padding(.top, Theme.Space.xs)
        .padding(.bottom, Theme.Space.xs)
        .accessibilityElement(children: .combine)
    }

    private var greeting: String {
        let base = switch Date.now.dayPart {
        case .morning: "Goedemorgen"
        case .afternoon: "Goedemiddag"
        case .evening: "Goedenavond"
        case .night: "Slaap lekker"
        }
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var subtitle: String {
        switch (morning != nil, evening != nil) {
        case (false, _) where Date.now.dayPart == .morning: "Begin je dag met dankbaarheid en rust."
        case (true, false): "Mooi begonnen. Vergeet je water niet."
        case (_, true): "Je dag is rond. Wat ben je goed bezig."
        default: "Elk moment is goed om voor jezelf te kiezen."
        }
    }
}

// MARK: - Ochtend

private struct MorningCard: View {
    let checkIn: MorningCheckIn?
    @Environment(Router.self) private var router

    var body: some View {
        Card(tint: Theme.Palette.dawn) {
            HStack {
                SectionLabel(title: "Ochtend", symbol: "sunrise.fill", color: Theme.Palette.dawn)
                Spacer()
                if checkIn != nil { DoneBadge(tint: Theme.Palette.dawn) }
            }
            if let checkIn {
                let items = checkIn.gratitudes.filter { !$0.isEmpty }
                if !items.isEmpty {
                    Text("Dankbaar voor")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(items, id: \.self) { item in
                        Label(item, systemImage: "heart.fill")
                            .font(.journal(.body))
                            .labelStyle(TintedIconLabelStyle(tint: Theme.Palette.dawn))
                    }
                }
                if !checkIn.intention.isEmpty {
                    Text("“\(checkIn.intention)”")
                        .font(.journal(.callout).italic())
                        .foregroundStyle(Theme.Palette.inkSecondary)
                }
                HStack(spacing: Theme.Space.xs) {
                    if !checkIn.meditationCompleted {
                        Button("Ochtendmeditatie", systemImage: "play.fill") { router.sheet = .meditation(.morning) }
                            .buttonStyle(.glassProminent).tint(Theme.Palette.dawn)
                    } else {
                        Label("Gemediteerd", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium)).foregroundStyle(Theme.Palette.dawn)
                    }
                    Spacer()
                    Button("Aanpassen") { router.sheet = .morning }
                        .buttonStyle(.glass)
                }
            } else {
                Text("Dankbaarheid & ochtendmeditatie")
                    .font(.title3.weight(.semibold))
                Text("Drie dingen waar je dankbaar voor bent, je intentie, en vijf minuten rust.")
                    .font(.subheadline).foregroundStyle(.secondary)
                PrimaryButton(title: "Ochtend check-in", symbol: "sun.max.fill", tint: Theme.Palette.dawn) {
                    router.sheet = .morning
                }
            }
        }
    }
}

// MARK: - Motivatie

struct MotivationCard: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @State private var reacted: Bool?

    var body: some View {
        let today = MotivationService.today()
        Card(tint: Theme.Palette.rose) {
            HStack {
                SectionLabel(title: today.isPersonal ? "Voor jou geschreven" : "Lief berichtje",
                             symbol: today.isPersonal ? "apple.intelligence" : "heart.fill",
                             color: Theme.Palette.rose)
                Spacer()
            }
            Text(today.text)
                .font(.journal(.title3))
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button {
                    react(true, id: today.messageID)
                } label: {
                    Label("Fijn", systemImage: reacted == true ? "heart.fill" : "heart")
                }
                .buttonStyle(.glass)
                .tint(Theme.Palette.rose)
                .symbolEffect(.bounce, value: reacted == true)
                .sensoryFeedback(.success, trigger: reacted == true)

                Button {
                    react(false, id: today.messageID)
                } label: {
                    Label("Iets anders", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.glass)
                .disabled(reacted != nil)
                Spacer()
            }
            .font(.subheadline)
            if reacted != nil {
                Text("Dankjewel, ik onthoud wat jij fijn vindt.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(Theme.Motion.standard, value: reacted)
    }

    private func react(_ liked: Bool, id: String) {
        guard reacted == nil else { return }
        reacted = liked
        LearningEngine.recordReaction(messageID: id, liked: liked, in: context)
    }
}

// MARK: - Water

private struct WaterCard: View {
    let total: Int
    let goal: Int
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @State private var bump = 0

    var body: some View {
        let progress = Double(total) / Double(max(goal, 1))
        let expected = LearningEngine.expectedWater()
        Card(tint: Theme.Palette.water) {
            HStack {
                SectionLabel(title: "Water", symbol: "drop.fill", color: Theme.Palette.water)
                Spacer()
                if total >= goal { DoneBadge(tint: Theme.Palette.water) }
            }
            HStack(spacing: Theme.Space.m) {
                ZStack {
                    ProgressRing(progress: progress, tint: Theme.Palette.water, lineWidth: 10)
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.Palette.water)
                        .symbolEffect(.bounce, value: bump)
                }
                .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(total.formatted()) ml")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .contentTransition(.numericText(value: Double(total)))
                    Text("van \(goal.formatted()) ml")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(paceText(expected: expected))
                        .font(.footnote).foregroundStyle(Theme.Palette.water)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: Theme.Space.xs) {
                ForEach(Prefs.glassSizes.prefix(3), id: \.self) { size in
                    Button("+\(size)") {
                        WaterStore.add(size, in: context)
                        bump += 1
                        Task { await NotificationService.shared.rescheduleWater(context: context) }
                    }
                    .buttonStyle(.glass)
                    .tint(Theme.Palette.water)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .accessibilityLabel("\(size) milliliter toevoegen")
                }
                Spacer(minLength: 0)
                Button("Meer", systemImage: "chevron.right") { router.sheet = .water }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .accessibilityLabel("Water details")
            }
            .sensoryFeedback(.impact(weight: .light), trigger: bump)
        }
        .animation(Theme.Motion.gentle, value: total)
    }

    private func paceText(expected: Int) -> String {
        if total >= goal { return "Doel gehaald! Je lichaam is je dankbaar." }
        if total >= expected { return "Je ligt lekker op schema." }
        let behind = expected - total
        return "Een glaasje erbij brengt je op schema (\(behind) ml)."
    }
}

// MARK: - Avond

private struct EveningCard: View {
    let checkIn: EveningCheckIn?
    @Environment(Router.self) private var router

    var body: some View {
        Card(tint: Theme.Palette.dusk) {
            HStack {
                SectionLabel(title: "Avond", symbol: "moon.stars.fill", color: Theme.Palette.dusk)
                Spacer()
                if checkIn != nil { DoneBadge(tint: Theme.Palette.dusk) }
            }
            if let checkIn {
                if !checkIn.happyMoment.isEmpty {
                    Text("Blij moment")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(checkIn.happyMoment)
                        .font(.journal(.body))
                        .lineLimit(3)
                }
                HStack(spacing: Theme.Space.m) {
                    PainPill(title: "Kaak", value: checkIn.jawPain)
                    PainPill(title: "Nek", value: checkIn.neckPain)
                    Spacer()
                }
                HStack {
                    if !checkIn.meditationCompleted {
                        Button("Avondmeditatie", systemImage: "play.fill") { router.sheet = .meditation(.evening) }
                            .buttonStyle(.glassProminent).tint(Theme.Palette.dusk)
                    } else {
                        Label("Ontspannen", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium)).foregroundStyle(Theme.Palette.dusk)
                    }
                    Spacer()
                    Button("Aanpassen") { router.sheet = .evening }.buttonStyle(.glass)
                }
            } else {
                Text("Blij moment, kaak & nek, en ontspannen")
                    .font(.title3.weight(.semibold))
                Text("Schrijf je blije moment in je boekje, check je pijn en sluit de dag zacht af.")
                    .font(.subheadline).foregroundStyle(.secondary)
                PrimaryButton(title: "Avond check-in", symbol: "moon.fill", tint: Theme.Palette.dusk) {
                    router.sheet = .evening
                }
                .opacity(Date.now.dayPart == .morning ? 0.7 : 1)
            }
        }
    }
}

// MARK: - Lichaam

private struct BodyCard: View {
    let lastEvening: EveningCheckIn?
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router

    var body: some View {
        let jaw = lastEvening?.jawPain ?? 3
        let neck = lastEvening?.neckPain ?? 3
        let suggestion = LearningEngine.suggestions(jaw: jaw, neck: neck, limit: 1, in: context).first
        if let suggestion {
            Card(tint: Theme.Palette.sage) {
                SectionLabel(title: "Even voor je lichaam", symbol: "figure.mind.and.body", color: Theme.Palette.sage)
                Button {
                    router.sheet = .exercise(suggestion.exercise.id)
                } label: {
                    HStack(spacing: Theme.Space.s) {
                        Image(systemName: suggestion.exercise.symbol)
                            .font(.title2)
                            .foregroundStyle(Theme.Palette.sage)
                            .frame(width: 48, height: 48)
                            .background(Theme.Palette.sageSoft, in: .rect(cornerRadius: Theme.Radius.small))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.exercise.title).font(.headline).foregroundStyle(Theme.Palette.ink)
                            Text("\(suggestion.reason) · \(suggestion.exercise.durationLabel)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill").font(.title).foregroundStyle(Theme.Palette.sage)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Kleine onderdelen

struct DoneBadge: View {
    var tint: Color
    var body: some View {
        Label("Klaar", systemImage: "checkmark")
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(tint.opacity(0.16), in: .capsule)
            .foregroundStyle(tint)
    }
}

struct PainPill: View {
    let title: String
    let value: Int
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Theme.Palette.pain(value)).frame(width: 8, height: 8)
            Text("\(title) \(value)/10").font(.subheadline.weight(.medium).monospacedDigit())
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Theme.Palette.surfaceRaised, in: .capsule)
        .accessibilityLabel("\(title): \(value) van 10")
    }
}

struct TintedIconLabelStyle: LabelStyle {
    var tint: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
            configuration.icon.foregroundStyle(tint).imageScale(.small)
            configuration.title
        }
    }
}
