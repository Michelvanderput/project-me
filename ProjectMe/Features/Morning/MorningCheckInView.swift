import SwiftData
import SwiftUI

/// Ochtend: stemming → dankbaarheid → intentie → meditatie.
struct MorningCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router

    @State private var step = 0
    @State private var mood: Mood = .okay
    @State private var gratitudes = ["", "", ""]
    @State private var intention = ""
    @State private var existing: MorningCheckIn?
    @FocusState private var focusedField: Int?

    private let steps = 4
    private let tint = Theme.Palette.dawn

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StepDots(count: steps, current: step, tint: tint)
                    .padding(.top, Theme.Space.s)
                ScrollView {
                    Group {
                        switch step {
                        case 0: moodStep
                        case 1: gratitudeStep
                        case 2: intentionStep
                        default: meditationStep
                        }
                    }
                    .padding(.horizontal, Theme.Space.gutter)
                    .padding(.top, Theme.Space.l)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                    .id(step)
                }
                .scrollDismissesKeyboard(.interactively)
                bottomBar
            }
            .background { AmbientBackground(tone: .dawn) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten", systemImage: "xmark") { dismiss() }
                }
                if step > 0 {
                    ToolbarItem(placement: .navigation) {
                        Button("Terug", systemImage: "chevron.left") { go(step - 1) }
                    }
                }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Stappen

    private var moodStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Goedemorgen", title: "Hoe voel je je nu?",
                      subtitle: "Er is geen goed of fout antwoord.")
            HStack(spacing: Theme.Space.xs) {
                ForEach(Mood.allCases) { option in
                    Button {
                        mood = option
                    } label: {
                        VStack(spacing: Theme.Space.xs) {
                            Image(systemName: option.symbol)
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .symbolEffect(.bounce, value: mood == option)
                            Text(option.title).font(.caption.weight(.medium))
                        }
                        .frame(maxWidth: .infinity, minHeight: 84)
                        .background(mood == option ? tint.opacity(0.2) : Theme.Palette.surface,
                                    in: .rect(cornerRadius: Theme.Radius.control))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .strokeBorder(mood == option ? tint : .clear, lineWidth: 2)
                        }
                        .foregroundStyle(mood == option ? tint : Theme.Palette.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityAddTraits(mood == option ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: mood)
        }
    }

    private var gratitudeStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Dankbaarheid", title: "Waar ben je dankbaar voor?",
                      subtitle: "Groot of piepklein. Een warme kop koffie telt ook.")
            ForEach(0..<3, id: \.self) { index in
                HStack(alignment: .top, spacing: Theme.Space.s) {
                    Text("\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(tint)
                        .frame(width: 32, height: 32)
                        .background(tint.opacity(0.15), in: .circle)
                    TextField(Self.gratitudePrompts[index], text: $gratitudes[index], axis: .vertical)
                        .font(.journal(.body))
                        .lineLimit(1...4)
                        .focused($focusedField, equals: index)
                        .submitLabel(index < 2 ? .next : .done)
                        .onSubmit { focusedField = index < 2 ? index + 1 : nil }
                }
                .padding(Theme.Space.m)
                .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.control))
            }
            SectionLabel(title: "Inspiratie", symbol: "sparkles")
            FlowLayout(spacing: Theme.Space.xs) {
                ForEach(Self.inspiration, id: \.self) { idea in
                    Chip(title: idea, isOn: false, tint: tint) { fillNext(with: idea) }
                }
            }
        }
        .onAppear { focusedField = gratitudes.firstIndex(where: \.isEmpty) }
    }

    private var intentionStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Intentie", title: "Waar wil je vandaag op focussen?",
                      subtitle: "Eén woord of een zin. Iets om naar terug te keren.")
            TextField("Vandaag wil ik…", text: $intention, axis: .vertical)
                .font(.journal(.title3))
                .lineLimit(1...4)
                .padding(Theme.Space.m)
                .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.control))
            FlowLayout(spacing: Theme.Space.xs) {
                ForEach(Self.intentions, id: \.self) { idea in
                    Chip(title: idea, isOn: intention == idea, tint: tint) { intention = idea }
                }
            }
        }
    }

    private var meditationStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Ochtendmeditatie", title: "Vijf minuten voor jezelf",
                      subtitle: "Een rustige ademhaling, je lichaam voelen en je intentie meenemen de dag in.")
            Image(systemName: "sunrise.fill")
                .font(.system(size: 88))
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.breathe, options: .repeating)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.l)
                .accessibilityHidden(true)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: Theme.Space.xs) {
            if step < steps - 1 {
                PrimaryButton(title: "Verder", symbol: "arrow.right", tint: tint) { go(step + 1) }
            } else {
                PrimaryButton(title: "Start meditatie", symbol: "play.fill", tint: tint) {
                    save()
                    dismiss()
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        router.sheet = .meditation(.morning)
                    }
                }
                Button("Nu niet, alleen opslaan") {
                    save()
                    dismiss()
                }
                .font(.subheadline.weight(.medium))
                .frame(minHeight: Theme.minTouchTarget)
            }
        }
        .padding(.horizontal, Theme.Space.gutter)
        .padding(.bottom, Theme.Space.s)
    }

    // MARK: Logica

    private func go(_ newStep: Int) {
        focusedField = nil
        if newStep > step { save() }
        withAnimation(Theme.Motion.standard) { step = max(0, min(steps - 1, newStep)) }
    }

    private func fillNext(with idea: String) {
        if let index = gratitudes.firstIndex(where: { $0.isEmpty }) {
            gratitudes[index] = idea + " "
            focusedField = index
        }
    }

    private func load() {
        let today = Date.now.startOfDay
        let descriptor = FetchDescriptor<MorningCheckIn>(predicate: #Predicate { $0.day == today })
        guard let found = try? context.fetch(descriptor).first else { return }
        existing = found
        mood = Mood(rawValue: found.mood) ?? .okay
        gratitudes = (found.gratitudes + ["", "", ""]).prefix(3).map { $0 }
        intention = found.intention
    }

    private func save() {
        let cleaned = gratitudes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let existing {
            existing.mood = mood.rawValue
            existing.gratitudes = cleaned
            existing.intention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let new = MorningCheckIn(mood: mood.rawValue, gratitudes: cleaned,
                                     intention: intention.trimmingCharacters(in: .whitespacesAndNewlines))
            context.insert(new)
            existing = new
        }
        try? context.save()
        Task { await NotificationService.shared.rescheduleAll(context: context) }
    }

    static let gratitudePrompts = ["Iemand die mijn dag mooier maakt…", "Iets kleins van gisteren…", "Iets aan mezelf…"]
    static let inspiration = ["Mijn bed", "Een goed gesprek", "Mijn lichaam", "De zon", "Muziek",
                              "Een vriend(in)", "Mijn huis", "Rust", "Lekker eten", "Een nieuwe dag"]
    static let intentions = ["Rust", "Geduld", "Lief zijn voor mezelf", "Kaak ontspannen",
                             "Genoeg water", "Eén ding tegelijk", "Grenzen bewaken", "Plezier"]
}

/// Titelblok dat in elke check-in-stap terugkomt.
struct StepTitle: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(eyebrow.uppercased())
                .font(.footnote.weight(.semibold)).kerning(0.6)
                .foregroundStyle(Theme.Palette.inkSecondary)
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle).font(.body).foregroundStyle(Theme.Palette.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
