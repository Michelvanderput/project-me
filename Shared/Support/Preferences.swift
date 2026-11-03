import Foundation

/// Sleutels voor instellingen in de gedeelde UserDefaults (App Group).
/// In views via `@AppStorage(PrefKey.x, store: AppGroup.defaults)`.
enum PrefKey {
    static let onboardingDone = "onboardingDone"
    static let userName = "userName"
    static let wakeMinutes = "wakeMinutes"          // minuten sinds middernacht
    static let bedMinutes = "bedMinutes"
    static let morningReminderMinutes = "morningReminderMinutes"
    static let eveningReminderMinutes = "eveningReminderMinutes"
    static let motivationMinutes = "motivationMinutes"
    static let waterGoalML = "waterGoalML"
    static let glassSizes = "glassSizes"            // komma-gescheiden ml
    static let morningReminderOn = "morningReminderOn"
    static let eveningReminderOn = "eveningReminderOn"
    static let motivationOn = "motivationOn"
    static let waterRemindersOn = "waterRemindersOn"
    static let adaptiveTiming = "adaptiveTiming"
    static let voiceGuidance = "voiceGuidance"
    static let healthSync = "healthSync"
    static let appleIntelligence = "appleIntelligence"
    static let hapticsOn = "hapticsOn"
    static let painFocus = "painFocus"              // PainArea.rawValue
    static let motivationWeights = "motivationWeights" // [String: Double] als JSON
    static let todayMotivationID = "todayMotivationID"
    static let todayMotivationDay = "todayMotivationDay"
    static let generatedMotivation = "generatedMotivation" // tekst van Apple Intelligence
    static let generatedMotivationDay = "generatedMotivationDay"
}

/// Nonisolated, alleen-lezen toegang voor widgets en intents.
enum Prefs {
    static var d: UserDefaults { AppGroup.defaults }

    static func registerDefaults() {
        d.register(defaults: [
            PrefKey.wakeMinutes: 7 * 60,
            PrefKey.bedMinutes: 23 * 60,
            PrefKey.morningReminderMinutes: 7 * 60 + 30,
            PrefKey.eveningReminderMinutes: 21 * 60 + 30,
            PrefKey.motivationMinutes: 14 * 60,
            PrefKey.waterGoalML: 2000,
            PrefKey.glassSizes: "150,250,330,500",
            PrefKey.morningReminderOn: true,
            PrefKey.eveningReminderOn: true,
            PrefKey.motivationOn: true,
            PrefKey.waterRemindersOn: true,
            PrefKey.adaptiveTiming: true,
            PrefKey.voiceGuidance: false,
            PrefKey.healthSync: false,
            PrefKey.appleIntelligence: true,
            PrefKey.hapticsOn: true,
            PrefKey.painFocus: PainArea.both.rawValue,
        ])
    }

    static var userName: String { d.string(forKey: PrefKey.userName) ?? "" }
    static var waterGoalML: Int { max(500, d.integer(forKey: PrefKey.waterGoalML)) }
    static var glassSizes: [Int] {
        (d.string(forKey: PrefKey.glassSizes) ?? "250")
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 }
    }
    static var motivationWeights: [String: Double] {
        guard let data = d.data(forKey: PrefKey.motivationWeights),
              let dict = try? JSONDecoder().decode([String: Double].self, from: data) else { return [:] }
        return dict
    }
    static func setMotivationWeights(_ weights: [String: Double]) {
        d.set(try? JSONEncoder().encode(weights), forKey: PrefKey.motivationWeights)
    }
}

extension Int {
    /// 2000 → "2 liter", 2250 → "2,25 liter".
    var litersText: String {
        "\((Double(self) / 1000).formatted(.number.precision(.fractionLength(0...2)))) liter"
    }

    /// Minuten sinds middernacht → DateComponents.
    var asHourMinute: DateComponents { DateComponents(hour: self / 60, minute: self % 60) }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date { Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)! }
    var minutesSinceMidnight: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    func adding(days: Int) -> Date { Calendar.current.date(byAdding: .day, value: days, to: self)! }
    static func today(atMinutes minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }

    enum DayPart: Sendable { case morning, afternoon, evening, night }
    var dayPart: DayPart {
        switch Calendar.current.component(.hour, from: self) {
        case 5..<12: .morning
        case 12..<18: .afternoon
        case 18..<23: .evening
        default: .night
        }
    }
}
