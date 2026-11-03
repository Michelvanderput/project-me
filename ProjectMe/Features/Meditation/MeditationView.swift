import SwiftData
import SwiftUI

/// Geleide meditatie met ademcirkel, haptiek, optionele stem en Live Activity in de Dynamic Island.
struct MeditationView: View {
    let kind: MeditationKind

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var length: MeditationLength = .normal
    @State private var phases: [MeditationPhase] = []
    @State private var startedAt: Date?
    @State private var pausedAt: Date?
    @State private var pausedTotal: TimeInterval = 0
    @State private var phaseIndex = 0
    @State private var finished = false
    @State private var ticker: Task<Void, Never>?

    private var tint: Color { kind == .morning ? Theme.Palette.dawn : Theme.Palette.dusk }
    private var totalSeconds: Int { phases.reduce(0) { $0 + $1.seconds } }
    private var isRunning: Bool { startedAt != nil && pausedAt == nil && !finished }

    var body: some View {
        ZStack {
            AmbientBackground(tone: kind == .morning ? .dawn : .dusk)
            VStack(spacing: Theme.Space.l) {
                topBar
                Spacer()
                if finished {
                    completion
                } else if startedAt == nil {
                    intro
                } else {
                    session
                }
                Spacer()
                controls
            }
            .padding(.horizontal, Theme.Space.gutter)
            .padding(.bottom, Theme.Space.m)
        }
        .interactiveDismissDisabled(startedAt != nil && !finished)
        .onAppear { phases = MeditationScripts.phases(for: kind, length: length) }
        .onChange(of: length) { _, value in phases = MeditationScripts.phases(for: kind, length: value) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { tick() } }
        .onDisappear {
            ticker?.cancel()
            SpeechGuide.shared.stop()
            if !finished { Task { await LiveActivityService.endMeditation(immediately: true) } }
        }
    }

    // MARK: Onderdelen

    private var topBar: some View {
        HStack {
            Label(kind.title, systemImage: kind.symbol)
                .font(.headline)
                .foregroundStyle(tint)
            Spacer()
            Button("Sluiten", systemImage: "xmark") { dismiss() }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .frame(minWidth: Theme.minTouchTarget, minHeight: Theme.minTouchTarget)
        }
        .padding(.top, Theme.Space.m)
    }

    private var intro: some View {
        VStack(spacing: Theme.Space.l) {
            BreathingCircle(tint: tint, isActive: true)
                .frame(width: 220, height: 220)
            VStack(spacing: Theme.Space.xs) {
                Text(kind == .morning ? "Een rustige start" : "Zacht de nacht in")
                    .font(.title.weight(.bold))
                Text(kind == .morning
                     ? "Ademhaling, dankbaarheid en je intentie voor vandaag."
                     : "Een bodyscan met extra aandacht voor kaak, nek en schouders.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.inkSecondary)
            }
            Picker("Lengte", selection: $length) {
                ForEach(MeditationLength.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
        }
    }

    private var session: some View {
        let phase = phases[safe: phaseIndex]
        return VStack(spacing: Theme.Space.l) {
            BreathingCircle(tint: tint, isActive: isRunning)
                .frame(width: 240, height: 240)
                .overlay {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(remainingText)
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.Palette.ink)
                            .contentTransition(.numericText(countsDown: true))
                    }
                }
            VStack(spacing: Theme.Space.s) {
                Text(phase?.title ?? "")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint)
                    .contentTransition(.opacity)
                Text(phase?.guidance ?? "")
                    .font(.journal(.title3))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .id(phaseIndex)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.6), value: phaseIndex)
            .accessibilityElement(children: .combine)
            StepDots(count: phases.count, current: phaseIndex, tint: tint)
        }
    }

    private var completion: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: kind == .morning ? "sun.max.fill" : "moon.zzz.fill")
                .font(.system(size: 80))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: finished)
            Text("Mooi gedaan").font(.largeTitle.weight(.bold))
            Text(kind == .morning
                 ? "Je hebt je dag goed voor jezelf gestart. Neem deze rust mee."
                 : "Je hebt je dag liefdevol afgesloten. Slaap lekker.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.inkSecondary)
        }
        .sensoryFeedback(.success, trigger: finished)
    }

    @ViewBuilder
    private var controls: some View {
        if finished {
            PrimaryButton(title: "Klaar", symbol: "checkmark", tint: tint) { dismiss() }
        } else if startedAt == nil {
            PrimaryButton(title: "Begin", symbol: "play.fill", tint: tint, action: start)
        } else {
            HStack(spacing: Theme.Space.s) {
                Button(isRunning ? "Pauze" : "Verder", systemImage: isRunning ? "pause.fill" : "play.fill") {
                    isRunning ? pause() : resume()
                }
                .buttonStyle(.glassProminent).tint(tint)
                .controlSize(.large)
                Button("Afronden", systemImage: "stop.fill") { finish() }
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
        }
    }

    // MARK: Timing (wandklok, zodat het klopt na vergrendelen)

    private var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        let end = pausedAt ?? .now
        return max(0, end.timeIntervalSince(startedAt) - pausedTotal)
    }

    private var remainingText: String {
        let remaining = max(0, totalSeconds - Int(elapsed))
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private var sessionEnd: Date { Date.now.addingTimeInterval(TimeInterval(totalSeconds) - elapsed) }

    private func start() {
        startedAt = .now
        phaseIndex = 0
        if let first = phases.first {
            SpeechGuide.shared.speak(first.guidance)
            LiveActivityService.startMeditation(kind: kind, phase: first.title, start: .now, end: sessionEnd)
        }
        ticker = Task { @MainActor in
            while !Task.isCancelled && !finished {
                tick()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func tick() {
        guard startedAt != nil, !finished, pausedAt == nil else { return }
        let t = Int(elapsed)
        if t >= totalSeconds { finish(); return }
        var cumulative = 0
        var index = 0
        for (i, phase) in phases.enumerated() {
            cumulative += phase.seconds
            if t < cumulative { index = i; break }
        }
        if index != phaseIndex {
            phaseIndex = index
            let phase = phases[index]
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            SpeechGuide.shared.speak(phase.guidance)
            LiveActivityService.updateMeditation(phase: phase.title, start: startedAt ?? .now, end: sessionEnd)
        }
    }

    private func pause() {
        pausedAt = .now
        SpeechGuide.shared.stop()
    }

    private func resume() {
        if let pausedAt { pausedTotal += Date.now.timeIntervalSince(pausedAt) }
        pausedAt = nil
        if let phase = phases[safe: phaseIndex] {
            LiveActivityService.updateMeditation(phase: phase.title, start: startedAt ?? .now, end: sessionEnd)
        }
    }

    private func finish() {
        guard !finished, let startedAt else { return }
        ticker?.cancel()
        let seconds = Int(elapsed)
        withAnimation(Theme.Motion.gentle) { finished = true }
        SpeechGuide.shared.speak(kind == .morning ? "Mooi gedaan. Fijne dag." : "Mooi gedaan. Slaap lekker.")
        Task { await LiveActivityService.endMeditation() }

        // Alleen meetellen als je er echt even voor ging zitten.
        guard seconds >= 45 else { return }
        context.insert(MeditationSession(kind: kind, seconds: seconds))
        let today = Date.now.startOfDay
        switch kind {
        case .morning:
            let d = FetchDescriptor<MorningCheckIn>(predicate: #Predicate { $0.day == today })
            if let checkIn = try? context.fetch(d).first {
                checkIn.meditationCompleted = true
                checkIn.meditationMinutes = max(1, seconds / 60)
            } else {
                context.insert(MorningCheckIn(meditationCompleted: true, meditationMinutes: max(1, seconds / 60)))
            }
        case .evening:
            let d = FetchDescriptor<EveningCheckIn>(predicate: #Predicate { $0.day == today })
            if let checkIn = try? context.fetch(d).first {
                checkIn.meditationCompleted = true
            } else {
                context.insert(EveningCheckIn(meditationCompleted: true))
            }
        }
        try? context.save()
        HealthService.shared.saveMindful(start: startedAt, end: .now)
    }
}

/// Ademcirkel: 4 tellen in, 6 tellen uit. Bij 'Verminder beweging' pulseert alleen de helderheid.
struct BreathingCircle: View {
    var tint: Color
    var isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isActive)) { context in
            let cycle = 10.0
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
            // 0…4s inademen (groter), 4…10s uitademen (kleiner), met zachte easing.
            let raw = t < 4 ? t / 4 : 1 - (t - 4) / 6
            let eased = (1 - cos(raw * .pi)) / 2
            let scale = reduceMotion ? 1 : 0.72 + 0.28 * eased
            ZStack {
                Circle().fill(tint.opacity(0.10)).scaleEffect(scale * 1.12)
                Circle().fill(tint.opacity(0.16)).scaleEffect(scale)
                Circle()
                    .fill(RadialGradient(colors: [tint.opacity(0.55), tint.opacity(0.18)],
                                         center: .center, startRadius: 4, endRadius: 140))
                    .scaleEffect(scale * 0.78)
                    .opacity(reduceMotion ? 0.6 + 0.4 * eased : 1)
            }
        }
        .accessibilityHidden(true)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
