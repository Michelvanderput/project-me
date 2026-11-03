import Foundation

struct MeditationPhase: Hashable, Sendable {
    let title: String
    let guidance: String
    let seconds: Int
}

enum MeditationLength: Int, CaseIterable, Identifiable, Sendable {
    case short = 3, normal = 5, long = 10
    var id: Int { rawValue }
    var label: String { "\(rawValue) min" }
}

/// Geleide teksten. Duur schaalt mee met de gekozen lengte.
enum MeditationScripts {
    static func phases(for kind: MeditationKind, length: MeditationLength) -> [MeditationPhase] {
        let base = kind == .morning ? morning : evening
        let baseTotal = Double(base.reduce(0) { $0 + $1.seconds })
        let factor = Double(length.rawValue * 60) / baseTotal
        return base.map { MeditationPhase(title: $0.title, guidance: $0.guidance, seconds: max(15, Int(Double($0.seconds) * factor))) }
    }

    static let morning: [MeditationPhase] = [
        .init(title: "Aankomen",
              guidance: "Ga lekker zitten. Voel waar je lichaam de stoel of de grond raakt. Je hoeft nu even niets.",
              seconds: 30),
        .init(title: "Ademen",
              guidance: "Adem rustig in door je neus… en langzaam uit. Volg je adem, zonder hem te veranderen.",
              seconds: 60),
        .init(title: "Zacht worden",
              guidance: "Laat je schouders zakken. Je kaak mag los, je tong rust tegen je gehemelte.",
              seconds: 45),
        .init(title: "Dankbaarheid",
              guidance: "Denk aan iets waar je dankbaar voor bent. Voel hoe dat warm wordt in je borst.",
              seconds: 60),
        .init(title: "Je intentie",
              guidance: "Neem je intentie voor vandaag in gedachten. Zeg hem zacht tegen jezelf.",
              seconds: 45),
        .init(title: "De dag in",
              guidance: "Adem nog één keer diep in… en uit. Open je ogen als je er klaar voor bent. Fijne dag.",
              seconds: 60),
    ]

    static let evening: [MeditationPhase] = [
        .init(title: "Landen",
              guidance: "Ga liggen of zitten zoals het fijn is. De dag is voorbij. Je mag nu alles even neerleggen.",
              seconds: 30),
        .init(title: "Lange uitademing",
              guidance: "Adem vier tellen in… en zes tellen uit. Bij elke uitademing zak je iets dieper weg.",
              seconds: 60),
        .init(title: "Gezicht",
              guidance: "Breng je aandacht naar je voorhoofd en je ogen. Laat ze glad en zacht worden.",
              seconds: 40),
        .init(title: "Kaak",
              guidance: "Voel je kaak. Laat je tanden los van elkaar komen. Je kaak mag zwaar worden, alsof hij smelt.",
              seconds: 50),
        .init(title: "Nek & schouders",
              guidance: "Adem naar je nek en schouders. Bij de uitademing laat je ze zakken, weg van je oren.",
              seconds: 50),
        .init(title: "Lichaam",
              guidance: "Laat de rust zich verspreiden door je armen, je buik, je benen, tot in je tenen.",
              seconds: 40),
        .init(title: "Blij moment",
              guidance: "Denk terug aan je blije moment van vandaag. Glimlach er zacht bij, als je wilt.",
              seconds: 30),
    ]
}
