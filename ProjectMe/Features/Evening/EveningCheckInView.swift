import PhotosUI
import SwiftData
import SwiftUI

/// Avond: blij moment → kaak & nek → oefeningen → avondmeditatie.
struct EveningCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router

    @State private var step = 0
    @State private var happyMoment = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var jawPain = 0
    @State private var neckPain = 0
    @State private var triggers: Set<String> = []
    @State private var note = ""
    @State private var existing: EveningCheckIn?
    @State private var playing: Exercise?
    @FocusState private var happyFocused: Bool

    private let steps = 4
    private let tint = Theme.Palette.dusk

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StepDots(count: steps, current: step, tint: tint)
                    .padding(.top, Theme.Space.s)
                ScrollView {
                    Group {
                        switch step {
                        case 0: happyStep
                        case 1: painStep
                        case 2: exerciseStep
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
            .background { AmbientBackground(tone: .dusk) }
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
            .sheet(item: $playing) { exercise in
                ExercisePlayerView(exercise: exercise)
            }
        }
        .onAppear(perform: load)
        .onChange(of: photoItem) { _, item in
            Task { photoData = try? await item?.loadTransferable(type: Data.self) }
        }
    }

    // MARK: Stappen

    private var happyStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Je boekje", title: "Wat was je blije moment vandaag?",
                      subtitle: "Iets wat je deed glimlachen, hoe klein ook.")
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.journal(.footnote).italic())
                    .foregroundStyle(Theme.Palette.inkSecondary)
                TextField("Vandaag was ik blij toen…", text: $happyMoment, axis: .vertical)
                    .font(.journal(.title3))
                    .lineLimit(4...10)
                    .focused($happyFocused)
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(maxHeight: 220)
                        .clipShape(.rect(cornerRadius: Theme.Radius.small))
                        .overlay(alignment: .topTrailing) {
                            Button("Verwijder foto", systemImage: "xmark.circle.fill") {
                                self.photoData = nil; photoItem = nil
                            }
                            .labelStyle(.iconOnly).font(.title2).foregroundStyle(.white, .black.opacity(0.4))
                            .padding(Theme.Space.xs)
                        }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photoData == nil ? "Foto toevoegen" : "Andere foto", systemImage: "photo.badge.plus")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.glass)
            }
            .padding(Theme.Space.m + 4)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(Theme.Palette.surface)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(tint.opacity(0.35)).frame(width: 3).padding(.vertical, Theme.Space.m)
                    }
            }
        }
        .onAppear { if happyMoment.isEmpty { happyFocused = true } }
    }

    private var painStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Je lichaam", title: "Hoe erg was de pijn vandaag?",
                      subtitle: "Kijk naar de dag als geheel, niet alleen naar nu.")
            Card {
                PainScale(title: "Kaak", symbol: "mouth", value: $jawPain)
            }
            Card {
                PainScale(title: "Nek", symbol: "figure.mind.and.body", value: $neckPain)
            }
            SectionLabel(title: "Speelde er iets mee?", symbol: "magnifyingglass")
            FlowLayout(spacing: Theme.Space.xs) {
                ForEach(Self.triggerOptions, id: \.self) { option in
                    Chip(title: option, isOn: triggers.contains(option), tint: tint) {
                        if triggers.contains(option) { triggers.remove(option) } else { triggers.insert(option) }
                    }
                }
            }
            TextField("Notitie (optioneel)", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .padding(Theme.Space.m)
                .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.control))
        }
    }

    private var exerciseStep: some View {
        let suggestions = LearningEngine.suggestions(jaw: jawPain, neck: neckPain, in: context)
        return VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Voor jou gekozen",
                      title: max(jawPain, neckPain) == 0 ? "Pijnvrij, wat fijn!" : "Even iets liefs voor je \(focusWord)",
                      subtitle: max(jawPain, neckPain) == 0
                        ? "Wil je toch even ontspannen? Deze oefeningen houden het zo."
                        : "Deze oefeningen passen bij hoe je je vandaag voelde. Ik leer wat bij jou helpt.")
            ForEach(suggestions) { suggestion in
                Button { playing = suggestion.exercise } label: {
                    ExerciseRow(exercise: suggestion.exercise, reason: suggestion.reason)
                }
                .buttonStyle(.plain)
            }
            Text(ExerciseLibrary.disclaimer)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var meditationStep: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            StepTitle(eyebrow: "Avondmeditatie", title: "Laat de dag los",
                      subtitle: "Een zachte bodyscan die extra aandacht geeft aan je kaak, gezicht, nek en schouders.")
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 88))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .symbolEffect(.breathe, options: .repeating)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Space.l)
                .accessibilityHidden(true)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: Theme.Space.xs) {
            if step < steps - 1 {
                PrimaryButton(title: step == 2 ? "Naar de meditatie" : "Verder", symbol: "arrow.right", tint: tint) {
                    go(step + 1)
                }
            } else {
                PrimaryButton(title: "Start avondmeditatie", symbol: "play.fill", tint: tint) {
                    save()
                    dismiss()
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        router.sheet = .meditation(.evening)
                    }
                }
                Button("Nu niet, alleen opslaan") { save(); dismiss() }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: Theme.minTouchTarget)
            }
        }
        .padding(.horizontal, Theme.Space.gutter)
        .padding(.bottom, Theme.Space.s)
    }

    private var focusWord: String {
        jawPain == neckPain ? "kaak en nek" : (jawPain > neckPain ? "kaak" : "nek")
    }

    // MARK: Logica

    private func go(_ newStep: Int) {
        happyFocused = false
        if newStep > step { save() }
        withAnimation(Theme.Motion.standard) { step = max(0, min(steps - 1, newStep)) }
    }

    private func load() {
        let today = Date.now.startOfDay
        let descriptor = FetchDescriptor<EveningCheckIn>(predicate: #Predicate { $0.day == today })
        guard let found = try? context.fetch(descriptor).first else { return }
        existing = found
        happyMoment = found.happyMoment
        photoData = found.happyPhoto
        jawPain = found.jawPain
        neckPain = found.neckPain
        triggers = Set(found.triggers)
        note = found.note
    }

    private func save() {
        let text = happyMoment.trimmingCharacters(in: .whitespacesAndNewlines)
        let compressed = photoData.flatMap { UIImage(data: $0)?.preparedForJournal() }
        if let existing {
            existing.happyMoment = text
            existing.happyPhoto = compressed
            existing.jawPain = jawPain
            existing.neckPain = neckPain
            existing.triggers = Array(triggers).sorted()
            existing.note = note
        } else {
            let new = EveningCheckIn(happyMoment: text, happyPhoto: compressed, jawPain: jawPain,
                                     neckPain: neckPain, triggers: Array(triggers).sorted(), note: note)
            context.insert(new)
            existing = new
        }
        try? context.save()
        Task { await NotificationService.shared.rescheduleAll(context: context) }
    }

    static let triggerOptions = ["Stress", "Klemmen of knarsen", "Slecht geslapen", "Veel schermtijd",
                                 "Lang gezeten", "Veel gepraat", "Hard of taai eten", "Weinig water",
                                 "Hoofdpijn", "Gespannen schouders", "Spannend gesprek"]
}

extension UIImage {
    /// Verkleint foto's voor het boekje (max 1600px, JPEG).
    func preparedForJournal() -> Data? {
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let image = UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return image.jpegData(compressionQuality: 0.8)
    }
}
