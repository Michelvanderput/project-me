import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @AppStorage(PrefKey.userName, store: AppGroup.defaults) private var name = ""
    @AppStorage(PrefKey.wakeMinutes, store: AppGroup.defaults) private var wake = 420
    @AppStorage(PrefKey.bedMinutes, store: AppGroup.defaults) private var bed = 1380
    @AppStorage(PrefKey.morningReminderOn, store: AppGroup.defaults) private var morningOn = true
    @AppStorage(PrefKey.morningReminderMinutes, store: AppGroup.defaults) private var morningAt = 450
    @AppStorage(PrefKey.eveningReminderOn, store: AppGroup.defaults) private var eveningOn = true
    @AppStorage(PrefKey.eveningReminderMinutes, store: AppGroup.defaults) private var eveningAt = 1290
    @AppStorage(PrefKey.motivationOn, store: AppGroup.defaults) private var motivationOn = true
    @AppStorage(PrefKey.motivationMinutes, store: AppGroup.defaults) private var motivationAt = 840
    @AppStorage(PrefKey.waterRemindersOn, store: AppGroup.defaults) private var waterOn = true
    @AppStorage(PrefKey.adaptiveTiming, store: AppGroup.defaults) private var adaptive = true
    @AppStorage(PrefKey.waterGoalML, store: AppGroup.defaults) private var waterGoal = 2000
    @AppStorage(PrefKey.glassSizes, store: AppGroup.defaults) private var glassSizes = "150,250,330,500"
    @AppStorage(PrefKey.voiceGuidance, store: AppGroup.defaults) private var voice = false
    @AppStorage(PrefKey.healthSync, store: AppGroup.defaults) private var health = false
    @AppStorage(PrefKey.appleIntelligence, store: AppGroup.defaults) private var intelligence = true
    @AppStorage(PrefKey.painFocus, store: AppGroup.defaults) private var painFocus = PainArea.both.rawValue

    @State private var confirmReset = false
    @State private var notificationsAllowed = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Over jou") {
                    TextField("Je naam", text: $name)
                        .textContentType(.givenName)
                    Picker("Waar heb je last van?", selection: $painFocus) {
                        ForEach(PainArea.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }

                Section {
                    DatePicker("Opstaan", selection: minutes($wake), displayedComponents: .hourAndMinute)
                    DatePicker("Slapen", selection: minutes($bed), displayedComponents: .hourAndMinute)
                } header: {
                    Text("Dagritme")
                } footer: {
                    Text("Hiermee verdeel ik je water over de dag en plan ik herinneringen op fijne momenten.")
                }

                Section {
                    if !notificationsAllowed {
                        Button("Meldingen aanzetten", systemImage: "bell.badge") { openSettings() }
                    }
                    Toggle("Ochtend check-in", isOn: $morningOn)
                    if morningOn {
                        DatePicker("Om", selection: minutes($morningAt), displayedComponents: .hourAndMinute)
                        learnedRow(.morning)
                    }
                    Toggle("Lief berichtje 's middags", isOn: $motivationOn)
                    if motivationOn {
                        DatePicker("Om", selection: minutes($motivationAt), displayedComponents: .hourAndMinute)
                    }
                    Toggle("Avond check-in", isOn: $eveningOn)
                    if eveningOn {
                        DatePicker("Om", selection: minutes($eveningAt), displayedComponents: .hourAndMinute)
                        learnedRow(.evening)
                    }
                    Toggle("Slimme waterherinneringen", isOn: $waterOn)
                    Toggle("Leer van mijn ritme", isOn: $adaptive)
                } header: {
                    Text("Herinneringen")
                } footer: {
                    Text("Met 'Leer van mijn ritme' schuiven herinneringen mee naar wanneer jij echt incheckt. Waterherinneringen komen alleen als je achterloopt.")
                }

                Section("Water") {
                    Stepper(value: $waterGoal, in: 1000...4000, step: 250) {
                        LabeledContent("Dagdoel", value: waterGoal.litersText)
                    }
                    TextField("Glasgroottes (ml, komma's)", text: $glassSizes)
                        .keyboardType(.numbersAndPunctuation)
                    LabeledContent("Jouw favoriete glas", value: "\(LearningEngine.preferredGlassSize(in: context)) ml")
                }

                Section {
                    Toggle("Gesproken begeleiding", isOn: $voice)
                    Toggle(isOn: $intelligence) {
                        VStack(alignment: .leading) {
                            Text("Persoonlijke berichtjes")
                            Text(MotivationService.isAppleIntelligenceAvailable
                                 ? "Met Apple Intelligence, privé op je iPhone"
                                 : "Apple Intelligence is niet beschikbaar, ik gebruik de bibliotheek")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Toggle("Bewaar in Gezondheid", isOn: Binding(get: { health }, set: setHealth))
                } header: {
                    Text("Ervaring")
                } footer: {
                    Text("Gezondheid: waterinname en mindful minuten van je meditaties.")
                }

                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Widgets en Dynamic Island").font(.headline)
                            Text("Houd je beginscherm of toegangsscherm ingedrukt, tik op 'Wijzig' en kies Project Me. Er zijn widgets voor water (met + knop), je dagritme en je lieve berichtje. Water en meditaties verschijnen ook in de Dynamic Island.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.grid.2x2").foregroundStyle(Theme.Palette.accent)
                    }
                }

                Section {
                    Text(ExerciseLibrary.disclaimer).font(.footnote).foregroundStyle(.secondary)
                    Button("Alle gegevens wissen", role: .destructive) { confirmReset = true }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Alles blijft op je eigen iPhone. Er gaat niets naar een server.")
                }
            }
            .navigationTitle("Instellingen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar", systemImage: "checkmark") { dismiss() }
                }
            }
            .confirmationDialog("Alles wissen?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Wis al mijn gegevens", role: .destructive, action: resetAll)
            } message: {
                Text("Je check-ins, boekje, water en oefeningen worden verwijderd. Dit kan niet ongedaan worden.")
            }
            .task { notificationsAllowed = await NotificationService.shared.isAuthorized }
            .onDisappear {
                Task { await NotificationService.shared.rescheduleAll(context: context) }
            }
        }
    }

    @ViewBuilder
    private func learnedRow(_ kind: LearningEngine.CheckInKind) -> some View {
        if adaptive, let learned = LearningEngine.learnedReminderMinutes(kind, in: context) {
            LabeledContent("Geleerd moment", value: LearningEngine.clock(learned))
                .foregroundStyle(.secondary)
        }
    }

    private func minutes(_ binding: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Date.today(atMinutes: binding.wrappedValue) },
            set: { binding.wrappedValue = $0.minutesSinceMidnight }
        )
    }

    private func setHealth(_ on: Bool) {
        health = on
        guard on else { return }
        Task { health = await HealthService.shared.requestAuthorization() }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func resetAll() {
        try? context.delete(model: MorningCheckIn.self)
        try? context.delete(model: EveningCheckIn.self)
        try? context.delete(model: WaterLog.self)
        try? context.delete(model: ExerciseSession.self)
        try? context.delete(model: MotivationReaction.self)
        try? context.delete(model: MeditationSession.self)
        try? context.save()
        Prefs.setMotivationWeights([:])
        WaterStore.didChange(total: 0)
    }
}
