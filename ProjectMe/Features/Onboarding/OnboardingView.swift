import SwiftUI

/// Rustige kennismaking in vijf stappen.
struct OnboardingView: View {
    var onFinish: () -> Void

    @AppStorage(PrefKey.userName, store: AppGroup.defaults) private var name = ""
    @AppStorage(PrefKey.wakeMinutes, store: AppGroup.defaults) private var wake = 420
    @AppStorage(PrefKey.bedMinutes, store: AppGroup.defaults) private var bed = 1380
    @AppStorage(PrefKey.morningReminderMinutes, store: AppGroup.defaults) private var morningAt = 450
    @AppStorage(PrefKey.eveningReminderMinutes, store: AppGroup.defaults) private var eveningAt = 1290
    @AppStorage(PrefKey.waterGoalML, store: AppGroup.defaults) private var waterGoal = 2000
    @AppStorage(PrefKey.painFocus, store: AppGroup.defaults) private var painFocus = PainArea.both.rawValue

    @State private var page = 0
    @FocusState private var nameFocused: Bool
    private let pages = 5

    var body: some View {
        VStack(spacing: 0) {
            StepDots(count: pages, current: page, tint: Theme.Palette.accent)
                .padding(.top, Theme.Space.m)
            ScrollView {
                Group {
                    switch page {
                    case 0: welcome
                    case 1: about
                    case 2: rhythm
                    case 3: water
                    default: reminders
                    }
                }
                .padding(.horizontal, Theme.Space.gutter)
                .padding(.top, Theme.Space.xl)
                .id(page)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: Theme.Space.xs) {
                PrimaryButton(title: page == pages - 1 ? "Meldingen toestaan" : (page == 0 ? "Laten we beginnen" : "Verder"),
                              symbol: page == pages - 1 ? "bell.fill" : "arrow.right") { next() }
                if page == pages - 1 {
                    Button("Later") { onFinish() }
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: Theme.minTouchTarget)
                }
            }
            .padding(.horizontal, Theme.Space.gutter)
            .padding(.bottom, Theme.Space.s)
        }
        .background { AmbientBackground() }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Palette.accent)
                .symbolEffect(.breathe, options: .repeating)
            Text("Project Me").font(.system(.largeTitle, design: .serif).weight(.bold))
            Text("Werken aan jezelf. Focussen op jezelf.")
                .font(.title3).foregroundStyle(Theme.Palette.inkSecondary)
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                feature("sunrise.fill", Theme.Palette.dawn, "Ochtend", "Dankbaarheid en een korte meditatie.")
                feature("heart.fill", Theme.Palette.rose, "Middag", "Een lief berichtje, precies wanneer je het nodig hebt.")
                feature("drop.fill", Theme.Palette.water, "Hele dag", "Zachtjes naar je 2 liter water.")
                feature("moon.stars.fill", Theme.Palette.dusk, "Avond", "Je blije moment, kaak & nek, en ontspannen.")
                feature("brain.head.profile", Theme.Palette.sage, "Leert van jou", "Herinneringen, berichtjes en oefeningen passen zich aan.")
            }
            .padding(.top, Theme.Space.s)
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Kennismaken", title: "Hoe mag ik je noemen?")
            TextField("Je naam", text: $name)
                .font(.title2)
                .textContentType(.givenName)
                .focused($nameFocused)
                .padding(Theme.Space.m)
                .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.control))
                .onAppear { nameFocused = true }
            StepTitle(eyebrow: "Je lichaam", title: "Waar heb je vooral last van?")
            HStack(spacing: Theme.Space.xs) {
                ForEach(PainArea.allCases) { area in
                    Chip(title: area.title, symbol: area.symbol, isOn: painFocus == area.rawValue) {
                        painFocus = area.rawValue
                    }
                }
            }
        }
    }

    private var rhythm: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Je ritme", title: "Hoe ziet je dag eruit?",
                      subtitle: "Zo plan ik herinneringen op fijne momenten. Je kunt dit altijd aanpassen.")
            Card {
                DatePicker("Ik sta meestal op om", selection: minutes($wake), displayedComponents: .hourAndMinute)
                Divider()
                DatePicker("Ik ga meestal slapen om", selection: minutes($bed), displayedComponents: .hourAndMinute)
            }
            .onChange(of: wake) { _, value in morningAt = value + 30 }
            .onChange(of: bed) { _, value in eveningAt = max(18 * 60, value - 90) }
        }
    }

    private var water: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Water", title: "Je dagdoel",
                      subtitle: "Twee liter is een fijn doel. Water helpt ook bij spierspanning.")
            Card(tint: Theme.Palette.water) {
                HStack {
                    Image(systemName: "drop.fill").font(.largeTitle).foregroundStyle(Theme.Palette.water)
                    Text(waterGoal.litersText)
                        .font(.largeTitle.weight(.bold).monospacedDigit())
                        .contentTransition(.numericText(value: Double(waterGoal)))
                    Spacer()
                }
                Stepper("Dagdoel", value: $waterGoal, in: 1000...4000, step: 250)
                    .labelsHidden()
            }
            .animation(Theme.Motion.quick, value: waterGoal)
        }
    }

    private var reminders: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Herinneringen", title: "Mag ik je af en toe een seintje geven?",
                      subtitle: "Een ochtend check-in, een lief berichtje 's middags, water als je achterloopt, en je avond check-in. Nooit meer dan nodig.")
            Image(systemName: "bell.and.waves.left.and.right")
                .font(.system(size: 72))
                .foregroundStyle(Theme.Palette.accent)
                .symbolEffect(.breathe, options: .repeating)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.l)
                .accessibilityHidden(true)
        }
    }

    private func feature(_ symbol: String, _ tint: Color, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.s) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func next() {
        nameFocused = false
        if page < pages - 1 {
            withAnimation(Theme.Motion.standard) { page += 1 }
        } else {
            Task {
                await NotificationService.shared.requestAuthorization()
                onFinish()
            }
        }
    }

    private func minutes(_ binding: Binding<Int>) -> Binding<Date> {
        Binding(get: { Date.today(atMinutes: binding.wrappedValue) },
                set: { binding.wrappedValue = $0.minutesSinceMidnight })
    }
}
