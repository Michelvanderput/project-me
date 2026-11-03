import Foundation

enum MotivationCategory: String, CaseIterable, Codable, Sendable {
    case zachtheid, rust, groei, lichaam, kracht, trots

    var title: String {
        switch self {
        case .zachtheid: "Zachtheid"
        case .rust: "Rust"
        case .groei: "Groei"
        case .lichaam: "Lichaam"
        case .kracht: "Kracht"
        case .trots: "Trots"
        }
    }
    var symbol: String {
        switch self {
        case .zachtheid: "heart"
        case .rust: "leaf"
        case .groei: "chart.line.uptrend.xyaxis"
        case .lichaam: "figure.mind.and.body"
        case .kracht: "bolt.heart"
        case .trots: "star"
        }
    }
}

struct MotivationMessage: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let text: String
    let category: MotivationCategory
}

/// Lieve berichtjes voor de middag. De app leert welke categorieën resoneren
/// (via ❤️-reacties) en kiest daar vaker uit, zonder steeds hetzelfde te herhalen.
enum MotivationLibrary {
    static let all: [MotivationMessage] = [
        .init(id: "z1", text: "Je hoeft vandaag niet perfect te zijn. Je bent al goed genoeg.", category: .zachtheid),
        .init(id: "z2", text: "Wees net zo lief voor jezelf als je voor een goede vriend zou zijn.", category: .zachtheid),
        .init(id: "z3", text: "Even een knuffel op afstand. Je doet het beter dan je denkt.", category: .zachtheid),
        .init(id: "z4", text: "Het is oké als het vandaag wat trager gaat. Langzaam is ook vooruit.", category: .zachtheid),
        .init(id: "z5", text: "Jij verdient dezelfde zorg die je anderen zo makkelijk geeft.", category: .zachtheid),
        .init(id: "z6", text: "Een moeilijke dag maakt jou geen moeilijk mens.", category: .zachtheid),
        .init(id: "r1", text: "Adem even diep in… en heel langzaam uit. Daar ben je weer.", category: .rust),
        .init(id: "r2", text: "Laat je schouders zakken. Ja, nog iets verder. Lekker zo.", category: .rust),
        .init(id: "r3", text: "Pauze nemen is ook productief. Je hoofd mag even ademen.", category: .rust),
        .init(id: "r4", text: "Niet alles hoeft nu. Kies één ding, de rest mag wachten.", category: .rust),
        .init(id: "r5", text: "Kijk eens drie seconden naar buiten. Wat zie je?", category: .rust),
        .init(id: "r6", text: "Rust is geen beloning die je moet verdienen. Je mag het gewoon nemen.", category: .rust),
        .init(id: "g1", text: "Elke kleine stap telt. Ook die van vanochtend.", category: .groei),
        .init(id: "g2", text: "Je bent niet achter. Je bent precies onderweg.", category: .groei),
        .init(id: "g3", text: "Wie je aan het worden bent, is iemand om trots op te zijn.", category: .groei),
        .init(id: "g4", text: "Vergelijk jezelf alleen met wie je gisteren was.", category: .groei),
        .init(id: "g5", text: "Gewoontes groeien stil. Je ziet het pas later, maar het gebeurt nu.", category: .groei),
        .init(id: "g6", text: "Fouten zijn bewijs dat je het probeert.", category: .groei),
        .init(id: "l1", text: "Tijd voor een slokje water? Je lichaam zegt alvast dankjewel. 💧", category: .lichaam),
        .init(id: "l2", text: "Check even je kaak: tanden los, lippen zacht, tong rustig op je gehemelte.", category: .lichaam),
        .init(id: "l3", text: "Rol je schouders drie keer naar achteren. Voelt dat beter?", category: .lichaam),
        .init(id: "l4", text: "Je lichaam draagt je de hele dag. Geef het even iets liefs terug.", category: .lichaam),
        .init(id: "l5", text: "Sta even op en strek je uit, als een kat in de zon.", category: .lichaam),
        .init(id: "l6", text: "Ontspan je voorhoofd en je kaak. Daar zit vaak meer spanning dan je denkt.", category: .lichaam),
        .init(id: "k1", text: "Je hebt al zoveel moeilijke dagen overleefd. Deze kan je ook aan.", category: .kracht),
        .init(id: "k2", text: "Moed is niet altijd luid. Soms is het gewoon doorgaan.", category: .kracht),
        .init(id: "k3", text: "Je bent sterker dan dat ene gevoel van nu.", category: .kracht),
        .init(id: "k4", text: "Wat er vanmiddag ook gebeurt: jij kiest hoe je ermee omgaat.", category: .kracht),
        .init(id: "k5", text: "Grenzen aangeven is een vorm van zelfrespect.", category: .kracht),
        .init(id: "k6", text: "Je hoeft het niet alleen te doen. Hulp vragen is ook kracht.", category: .kracht),
        .init(id: "t1", text: "Kijk eens wat je vandaag al gedaan hebt. Dat is echt iets.", category: .trots),
        .init(id: "t2", text: "Dat je aan jezelf werkt, zegt al zoveel. Ik ben trots op je.", category: .trots),
        .init(id: "t3", text: "Je bent een cadeau voor de mensen om je heen.", category: .trots),
        .init(id: "t4", text: "Jij bent de moeite waard. Vandaag, en elke dag.", category: .trots),
        .init(id: "t5", text: "Je bent jezelf aan het kiezen. Dat is mooi om te zien.", category: .trots),
        .init(id: "t6", text: "Vier vanavond iets kleins. Je hebt het verdiend.", category: .trots),
    ]

    static func message(id: String) -> MotivationMessage? { all.first { $0.id == id } }

    /// Kiest deterministisch per dag een bericht, gewogen naar wat de gebruiker fijn vindt.
    static func pick(for date: Date = .now,
                     weights: [String: Double] = Prefs.motivationWeights,
                     excluding recent: Set<String> = []) -> MotivationMessage {
        let candidates = all.filter { !recent.contains($0.id) }
        let pool = candidates.isEmpty ? all : candidates
        let dayNumber = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        var generator = SeededGenerator(seed: UInt64(dayNumber))

        let scored = pool.map { message -> (MotivationMessage, Double) in
            let categoryWeight = weights[message.category.rawValue] ?? 1.0
            let messageWeight = weights[message.id] ?? 1.0
            return (message, max(0.05, categoryWeight * messageWeight))
        }
        let totalWeight = scored.reduce(0) { $0 + $1.1 }
        var roll = Double.random(in: 0..<totalWeight, using: &generator)
        for (message, weight) in scored {
            roll -= weight
            if roll <= 0 { return message }
        }
        return pool[0]
    }
}

/// Simpele deterministische generator (SplitMix64) zodat widget en app hetzelfde bericht tonen.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
