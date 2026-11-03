import SwiftData
import SwiftUI

/// Begeleidt een oefening stap voor stap, en vraagt daarna of het hielp (daar leert de app van).
struct ExercisePlayerView: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    enum Stage { case intro, running, feedback, done }
    @State private var stage: Stage = .intro
    @State private var round = 1
    @State private var stepIndex = 0
    @State private var stepEnds = Date.now
    @State private var isPaused = false
    @State private var remainingWhenPaused: TimeInterval = 0
    @State private var ticker: Task<Void, Never>?
    @State private var feedback: Int?

    private let tint = Theme.Palette.sage

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Space.l) {
                switch stage {
                case .intro: intro
                case .running: running
                case .feedback: feedbackView
                case .done: doneView
                }
            }
            .padding(.horizontal, Theme.Space.gutter)
            .padding(.bottom, Theme.Space.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { AmbientBackground(tone: .sage) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten", systemImage: "xmark") { dismiss() }
                }
            }
            .animation(Theme.Motion.standard, value: stage)
        }
        .onDisappear { ticker?.cancel(); SpeechGuide.shared.stop() }
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Image(systemName: exercise.symbol)
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(tint.gradient, in: .rect(cornerRadius: Theme.Radius.card))
                    Text(exercise.title).font(.largeTitle.weight(.bold))
                    HStack(spacing: Theme.Space.xs) {
                        Label(exercise.durationLabel, systemImage: "clock")
                        Text("·")
                        Text(exercise.area.title)
                        if exercise.repeats > 1 { Text("· \(exercise.repeats)×") }
                    }
                    .font(.subheadline).foregroundStyle(.secondary)
                    Text(exercise.summary).font(.title3)
                    Card(tint: tint) {
                        SectionLabel(title: "Waarom", symbol: "leaf", color: tint)
                        Text(exercise.benefit)
                    }
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        SectionLabel(title: "Stappen", symbol: "list.number")
                        ForEach(Array(exercise.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: Theme.Space.s) {
                                Text("\(index + 1)")
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .foregroundStyle(tint)
                                    .frame(width: 26, height: 26)
                                    .background(tint.opacity(0.15), in: .circle)
                                Text(step.text)
                            }
                        }
                    }
                    if let caution = exercise.caution {
                        Label(caution, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Palette.rose)
                    }
                    Text(ExerciseLibrary.disclaimer).font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.top, Theme.Space.s)
            }
            .scrollIndicators(.hidden)
            PrimaryButton(title: "Start", symbol: "play.fill", tint: tint, action: start)
        }
    }

    // MARK: Bezig

    private var running: some View {
        let step = exercise.steps[stepIndex]
        return VStack(spacing: Theme.Space.l) {
            Spacer()
            if exercise.repeats > 1 {
                Text("Ronde \(round) van \(exercise.repeats)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let remaining = isPaused ? remainingWhenPaused : max(0, stepEnds.timeIntervalSince(context.date))
                let progress = 1 - remaining / Double(max(step.seconds, 1))
                ZStack {
                    ProgressRing(progress: progress, tint: tint, lineWidth: 14)
                    Text("\(Int(remaining.rounded(.up)))")
                        .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                }
                .frame(width: 200, height: 200)
            }
            Text(step.text)
                .font(.journal(.title2))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .id("\(round)-\(stepIndex)")
                .transition(.opacity)
            StepDots(count: exercise.steps.count, current: stepIndex, tint: tint)
            Spacer()
            HStack(spacing: Theme.Space.s) {
                Button(isPaused ? "Verder" : "Pauze", systemImage: isPaused ? "play.fill" : "pause.fill") {
                    togglePause()
                }
                .buttonStyle(.glassProminent).tint(tint).controlSize(.large)
                Button("Volgende", systemImage: "forward.fill") { advance() }
                    .buttonStyle(.glass).controlSize(.large)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: stepIndex)
    }

    // MARK: Feedback

    private var feedbackView: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: stage)
            Text("Goed gedaan!").font(.largeTitle.weight(.bold))
            Text("Hielp deze oefening je?").font(.title3).foregroundStyle(.secondary)
            HStack(spacing: Theme.Space.s) {
                feedbackButton(value: 1, title: "Ja, fijn", symbol: "hand.thumbsup.fill")
                feedbackButton(value: 0, title: "Weet niet", symbol: "minus.circle")
                feedbackButton(value: -1, title: "Niet echt", symbol: "hand.thumbsdown")
            }
            Text("Ik gebruik je antwoord om je betere oefeningen voor te stellen.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
    }

    private func feedbackButton(value: Int, title: String, symbol: String) -> some View {
        Button {
            feedback = value
            save(helpfulness: value)
            stage = .done
        } label: {
            VStack(spacing: Theme.Space.xs) {
                Image(systemName: symbol).font(.title2)
                Text(title).font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.control))
            .foregroundStyle(value == 1 ? tint : Theme.Palette.ink)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: feedback)
    }

    private var doneView: some View {
        VStack(spacing: Theme.Space.l) {
            Spacer()
            Image(systemName: "heart.fill").font(.system(size: 64)).foregroundStyle(Theme.Palette.rose)
                .symbolEffect(.bounce, value: stage)
            Text(feedback == 1 ? "Fijn! Die onthoud ik voor je." : "Dankjewel, ik leer ervan.")
                .font(.title2.weight(.semibold)).multilineTextAlignment(.center)
            Spacer()
            PrimaryButton(title: "Klaar", symbol: "checkmark", tint: tint) { dismiss() }
        }
    }

    // MARK: Logica

    private func start() {
        stage = .running
        round = 1
        beginStep(0)
        ticker = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                if stage == .running, !isPaused, Date.now >= stepEnds { advance() }
            }
        }
    }

    private func beginStep(_ index: Int) {
        stepIndex = index
        let step = exercise.steps[index]
        stepEnds = Date.now.addingTimeInterval(TimeInterval(step.seconds))
        SpeechGuide.shared.speak(step.text)
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if stepIndex + 1 < exercise.steps.count {
            beginStep(stepIndex + 1)
        } else if round < exercise.repeats {
            round += 1
            beginStep(0)
        } else {
            ticker?.cancel()
            SpeechGuide.shared.speak("Goed gedaan.")
            stage = .feedback
        }
    }

    private func togglePause() {
        if isPaused {
            stepEnds = Date.now.addingTimeInterval(remainingWhenPaused)
            isPaused = false
        } else {
            remainingWhenPaused = max(0, stepEnds.timeIntervalSinceNow)
            isPaused = true
            SpeechGuide.shared.stop()
        }
    }

    private func save(helpfulness: Int) {
        context.insert(ExerciseSession(exerciseID: exercise.id, helpfulness: helpfulness))
        try? context.save()
    }
}
