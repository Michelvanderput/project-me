import SwiftData
import SwiftUI

/// Tab "Lichaam": oefeningen voor kaak en nek, met suggesties die van je leren.
struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Query(sort: \EveningCheckIn.day, order: .reverse) private var evenings: [EveningCheckIn]
    @Query(sort: \ExerciseSession.date, order: .reverse) private var sessions: [ExerciseSession]
    @AppStorage(PrefKey.painFocus, store: AppGroup.defaults) private var focusRaw = PainArea.both.rawValue
    @State private var filter: PainArea = .both

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    forYou
                    Picker("Gebied", selection: $filter) {
                        ForEach(PainArea.allCases) { area in
                            Text(area == .both ? "Alles" : area.title).tag(area)
                        }
                    }
                    .pickerStyle(.segmented)

                    LazyVStack(spacing: Theme.Space.s) {
                        ForEach(ExerciseLibrary.filtered(filter)) { exercise in
                            Button { router.sheet = .exercise(exercise.id) } label: {
                                ExerciseRow(exercise: exercise, reason: nil, timesDone: count(for: exercise))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    jawCheck

                    Text(ExerciseLibrary.disclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Theme.Space.gutter)
                .padding(.bottom, Theme.Space.xl)
            }
            .background { AmbientBackground(tone: .sage) }
            .navigationTitle("Lichaam")
            .onAppear { filter = PainArea(rawValue: focusRaw) ?? .both }
        }
    }

    private var forYou: some View {
        let last = evenings.first
        let suggestions = LearningEngine.suggestions(jaw: last?.jawPain ?? 3, neck: last?.neckPain ?? 3, in: context)
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionLabel(title: "Voor jou vandaag", symbol: "sparkles", color: Theme.Palette.sage)
            if let last {
                Text("Gebaseerd op je laatste check-in: kaak \(last.jawPain), nek \(last.neckPain).")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(suggestions) { suggestion in
                        Button { router.sheet = .exercise(suggestion.exercise.id) } label: {
                            SuggestionTile(suggestion: suggestion)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private var jawCheck: some View {
        Card(tint: Theme.Palette.sage) {
            SectionLabel(title: "Kaak-check", symbol: "mouth", color: Theme.Palette.sage)
            Text("Lippen samen, tanden los, tong rustig tegen je gehemelte.")
                .font(.journal(.title3))
            Text("Doe deze check een paar keer per dag, bijvoorbeeld bij elk glas water. Zo merk je eerder wanneer je klemt.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func count(for exercise: Exercise) -> Int {
        sessions.filter { $0.exerciseID == exercise.id }.count
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    var reason: String?
    var timesDone: Int = 0

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: exercise.symbol)
                .font(.title3)
                .foregroundStyle(Theme.Palette.sage)
                .frame(width: 52, height: 52)
                .background(Theme.Palette.sageSoft, in: .rect(cornerRadius: Theme.Radius.small))
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.title).font(.headline).foregroundStyle(Theme.Palette.ink)
                Text(reason ?? exercise.summary)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: Theme.Space.xs) {
                    Label(exercise.durationLabel, systemImage: "clock")
                    Text("·")
                    Text(exercise.area.title)
                    if timesDone > 0 {
                        Text("·")
                        Text("\(timesDone)× gedaan")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.Palette.inkSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(Theme.Space.s)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.control))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Start de oefening")
    }
}

private struct SuggestionTile: View {
    let suggestion: LearningEngine.Suggestion

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Image(systemName: suggestion.exercise.symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Theme.Palette.sage.gradient, in: .circle)
            Spacer(minLength: 0)
            Text(suggestion.exercise.title)
                .font(.headline)
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(2)
            Text(suggestion.reason)
                .font(.caption)
                .foregroundStyle(Theme.Palette.inkSecondary)
                .lineLimit(2)
            Label(suggestion.exercise.durationLabel, systemImage: "play.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Palette.sage)
        }
        .padding(Theme.Space.m)
        .frame(width: 190, height: 210, alignment: .leading)
        .background(Theme.Palette.surface, in: .rect(cornerRadius: Theme.Radius.card))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}
