import Foundation
import SwiftData

enum PainArea: String, Codable, CaseIterable, Identifiable, Sendable {
    case jaw, neck, both
    var id: String { rawValue }
    var title: String {
        switch self {
        case .jaw: "Kaak"
        case .neck: "Nek"
        case .both: "Kaak & nek"
        }
    }
    var symbol: String {
        switch self {
        case .jaw: "mouth"
        case .neck: "figure.mind.and.body"
        case .both: "figure.cooldown"
        }
    }
}

enum Mood: Int, CaseIterable, Identifiable, Sendable {
    case heavy = 1, low, okay, good, bright
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .heavy: "Zwaar"
        case .low: "Matig"
        case .okay: "Oké"
        case .good: "Goed"
        case .bright: "Stralend"
        }
    }
    var symbol: String {
        switch self {
        case .heavy: "cloud.rain"
        case .low: "cloud"
        case .okay: "cloud.sun"
        case .good: "sun.max"
        case .bright: "sparkles"
        }
    }
}

@Model
final class MorningCheckIn {
    var day: Date = Date.now.startOfDay
    var createdAt: Date = Date.now
    var mood: Int = 3
    var gratitudes: [String] = []
    var intention: String = ""
    var meditationCompleted: Bool = false
    var meditationMinutes: Int = 0

    init(day: Date = .now, mood: Int = 3, gratitudes: [String] = [], intention: String = "",
         meditationCompleted: Bool = false, meditationMinutes: Int = 0) {
        self.day = day.startOfDay
        self.createdAt = .now
        self.mood = mood
        self.gratitudes = gratitudes
        self.intention = intention
        self.meditationCompleted = meditationCompleted
        self.meditationMinutes = meditationMinutes
    }
}

@Model
final class EveningCheckIn {
    var day: Date = Date.now.startOfDay
    var createdAt: Date = Date.now
    var meditationCompleted: Bool = false
    var happyMoment: String = ""
    @Attribute(.externalStorage) var happyPhoto: Data?
    var jawPain: Int = 0      // 0...10
    var neckPain: Int = 0     // 0...10
    var triggers: [String] = []
    var note: String = ""

    init(day: Date = .now, meditationCompleted: Bool = false, happyMoment: String = "",
         happyPhoto: Data? = nil, jawPain: Int = 0, neckPain: Int = 0, triggers: [String] = [], note: String = "") {
        self.day = day.startOfDay
        self.createdAt = .now
        self.meditationCompleted = meditationCompleted
        self.happyMoment = happyMoment
        self.happyPhoto = happyPhoto
        self.jawPain = jawPain
        self.neckPain = neckPain
        self.triggers = triggers
        self.note = note
    }

    var maxPain: Int { max(jawPain, neckPain) }
}

@Model
final class WaterLog {
    var date: Date = Date.now
    var amountML: Int = 250

    init(date: Date = .now, amountML: Int) {
        self.date = date
        self.amountML = amountML
    }
}

@Model
final class ExerciseSession {
    var date: Date = Date.now
    var exerciseID: String = ""
    /// -1 = hielp niet, 0 = onbekend/neutraal, 1 = hielp
    var helpfulness: Int = 0

    init(date: Date = .now, exerciseID: String, helpfulness: Int = 0) {
        self.date = date
        self.exerciseID = exerciseID
        self.helpfulness = helpfulness
    }
}

@Model
final class MotivationReaction {
    var date: Date = Date.now
    var messageID: String = ""
    var category: String = ""
    var liked: Bool = true

    init(date: Date = .now, messageID: String, category: String, liked: Bool) {
        self.date = date
        self.messageID = messageID
        self.category = category
        self.liked = liked
    }
}

@Model
final class MeditationSession {
    var date: Date = Date.now
    var kind: String = MeditationKind.morning.rawValue
    var seconds: Int = 0

    init(date: Date = .now, kind: MeditationKind, seconds: Int) {
        self.date = date
        self.kind = kind.rawValue
        self.seconds = seconds
    }
}

enum MeditationKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case morning, evening
    var id: String { rawValue }
    var title: String { self == .morning ? "Ochtendmeditatie" : "Avondmeditatie" }
    var symbol: String { self == .morning ? "sunrise.fill" : "moon.stars.fill" }
}
