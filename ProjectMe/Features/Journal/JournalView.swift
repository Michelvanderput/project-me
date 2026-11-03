import SwiftData
import SwiftUI

/// "Het boekje": al je blije momenten en dankbaarheid, als een persoonlijk dagboek.
struct JournalView: View {
    @Query(sort: \EveningCheckIn.day, order: .reverse) private var evenings: [EveningCheckIn]
    @Query(sort: \MorningCheckIn.day, order: .reverse) private var mornings: [MorningCheckIn]
    @Environment(Router.self) private var router

    enum Part: String, CaseIterable, Identifiable {
        case happy = "Blije momenten", gratitude = "Dankbaarheid"
        var id: String { rawValue }
    }

    @State private var section: Part = .happy
    @State private var search = ""
    @State private var reading: EveningCheckIn?

    private var happy: [EveningCheckIn] {
        evenings.filter { !$0.happyMoment.isEmpty || $0.happyPhoto != nil }
            .filter { search.isEmpty || $0.happyMoment.localizedStandardContains(search) }
    }
    private var grateful: [MorningCheckIn] {
        mornings.filter { !$0.gratitudes.filter { !$0.isEmpty }.isEmpty }
            .filter { search.isEmpty || $0.gratitudes.contains { $0.localizedStandardContains(search) } || $0.intention.localizedStandardContains(search) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Picker("Onderdeel", selection: $section) {
                        ForEach(Part.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch section {
                    case .happy: happyList
                    case .gratitude: gratitudeList
                    }
                }
                .padding(.horizontal, Theme.Space.gutter)
                .padding(.bottom, Theme.Space.xl)
            }
            .background { AmbientBackground(tone: .dusk) }
            .navigationTitle("Mijn boekje")
            .searchable(text: $search, prompt: "Zoek in je boekje")
            .fullScreenCover(item: $reading) { entry in
                BookReader(entries: happy, start: entry)
            }
        }
    }

    @ViewBuilder
    private var happyList: some View {
        if happy.isEmpty {
            EmptyJournal(symbol: "book.closed", title: "Je boekje is nog leeg",
                         text: "Elke avond schrijf je hier een blij moment in. Over een tijdje heb je een heel boek vol mooie herinneringen.",
                         action: ("Schrijf je eerste blije moment", { router.sheet = .evening }))
        } else {
            ForEach(groupedByMonth(happy, date: \.day)) { group in
                let month = group.id, entries = group.items
                SectionLabel(title: month, symbol: "calendar")
                    .padding(.top, Theme.Space.s)
                ForEach(entries) { entry in
                    Button { reading = entry } label: { HappyPage(entry: entry, compact: true) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var gratitudeList: some View {
        if grateful.isEmpty {
            EmptyJournal(symbol: "sun.max", title: "Nog geen dankbaarheid",
                         text: "Elke ochtend noteer je drie dingen waar je dankbaar voor bent.",
                         action: ("Ochtend check-in", { router.sheet = .morning }))
        } else {
            ForEach(groupedByMonth(grateful, date: \.day)) { group in
                let month = group.id, entries = group.items
                SectionLabel(title: month, symbol: "calendar")
                    .padding(.top, Theme.Space.s)
                ForEach(entries) { entry in
                    PaperCard {
                        Text(entry.day, format: .dateTime.weekday(.wide).day().month())
                            .font(.journal(.footnote).italic())
                            .foregroundStyle(Theme.Palette.inkSecondary)
                        ForEach(entry.gratitudes.filter { !$0.isEmpty }, id: \.self) { item in
                            Label(item, systemImage: "heart.fill")
                                .font(.journal(.body))
                                .labelStyle(TintedIconLabelStyle(tint: Theme.Palette.dawn))
                        }
                        if !entry.intention.isEmpty {
                            Text("Intentie: \(entry.intention)")
                                .font(.journal(.subheadline).italic())
                                .foregroundStyle(Theme.Palette.inkSecondary)
                        }
                    }
                }
            }
        }
    }

    private func groupedByMonth<T>(_ items: [T], date: KeyPath<T, Date>) -> [MonthGroup<T>] {
        var order: [String] = []
        var groups: [String: [T]] = [:]
        for item in items {
            let key = item[keyPath: date].formatted(.dateTime.month(.wide).year())
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(item)
        }
        return order.map { MonthGroup(id: $0, items: groups[$0] ?? []) }
    }
}

struct MonthGroup<T>: Identifiable {
    let id: String
    let items: [T]
}

/// Een pagina uit het boekje.
struct HappyPage: View {
    let entry: EveningCheckIn
    var compact = false

    var body: some View {
        PaperCard {
            Text(entry.day, format: .dateTime.weekday(.wide).day().month(.wide).year())
                .font(.journal(.footnote).italic())
                .foregroundStyle(Theme.Palette.inkSecondary)
            if let data = entry.happyPhoto, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 160 : 320)
                    .clipShape(.rect(cornerRadius: Theme.Radius.small))
                    .accessibilityLabel("Foto bij blij moment")
            }
            Text(entry.happyMoment)
                .font(.journal(compact ? .body : .title2))
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(compact ? 4 : nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) { content }
            .padding(Theme.Space.m + 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .overlay(alignment: .leading) {
                        // Zachte "boekrug"-lijn.
                        Rectangle().fill(Theme.Palette.dusk.opacity(0.25)).frame(width: 3)
                            .padding(.vertical, Theme.Space.m)
                    }
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
            }
    }
}

/// Bladeren door je blije momenten, als in een echt boekje.
private struct BookReader: View {
    let entries: [EveningCheckIn]
    let start: EveningCheckIn
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PersistentIdentifier?

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(entries) { entry in
                    ScrollView {
                        HappyPage(entry: entry)
                            .padding(Theme.Space.gutter)
                    }
                    .tag(Optional(entry.persistentModelID))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: entries.count > 1 ? .automatic : .never))
            .background { AmbientBackground(tone: .dusk) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sluiten", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .onAppear { selection = start.persistentModelID }
    }
}

private struct EmptyJournal: View {
    let symbol: String
    let title: String
    let text: String
    let action: (String, () -> Void)

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: symbol)
                .font(.system(size: 56))
                .foregroundStyle(Theme.Palette.dusk)
                .symbolEffect(.breathe, options: .repeating)
            Text(title).font(.title3.weight(.semibold))
            Text(text).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button(action.0, action: action.1)
                .buttonStyle(.glassProminent).tint(Theme.Palette.dusk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xxl)
    }
}
