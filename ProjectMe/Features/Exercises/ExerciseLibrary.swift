import Foundation

struct Exercise: Identifiable, Hashable, Sendable {
    struct Step: Hashable, Sendable {
        let text: String
        let seconds: Int
    }

    let id: String
    let title: String
    let area: PainArea
    let symbol: String
    let summary: String
    let benefit: String
    let steps: [Step]
    var repeats: Int = 1
    var caution: String? = nil
    var isGentle: Bool = false

    var totalSeconds: Int { steps.reduce(0) { $0 + $1.seconds } * repeats }
    var durationLabel: String {
        let minutes = Int((Double(totalSeconds) / 60).rounded(.up))
        return minutes <= 1 ? "± 1 min" : "± \(minutes) min"
    }
}

/// Bekende, milde oefeningen bij kaak- (TMD) en nekklachten.
/// Geen medisch advies: bij aanhoudende of hevige pijn → huisarts, tandarts of fysiotherapeut.
enum ExerciseLibrary {
    static let disclaimer = "Beweeg altijd binnen een pijnvrij bereik. Doet iets pijn? Stop dan. Houden klachten aan, overleg dan met je huisarts, tandarts of (kaak)fysiotherapeut."

    static let all: [Exercise] = [
        // MARK: Kaak
        Exercise(
            id: "jaw-rest", title: "Rustpositie van je kaak", area: .jaw, symbol: "mouth",
            summary: "Lippen zacht samen, tanden los, tong op je gehemelte.",
            benefit: "Haalt de spanning uit je kauwspieren. Fijn om vaak te herhalen.",
            steps: [
                .init(text: "Leg je tongpunt licht tegen je gehemelte, net achter je boventanden.", seconds: 10),
                .init(text: "Laat je tanden een klein stukje los van elkaar. Lippen blijven zacht samen.", seconds: 10),
                .init(text: "Adem rustig door je neus. Voel hoe je kaak zwaar en los wordt.", seconds: 30),
                .init(text: "Ontspan ook je voorhoofd en je wangen.", seconds: 20),
            ],
            isGentle: true
        ),
        Exercise(
            id: "jaw-goldfish-partial", title: "Goudvis (half open)", area: .jaw, symbol: "fish",
            summary: "Rustig half openen en sluiten met je tong op je gehemelte.",
            benefit: "Traint een soepele, rechte opening van het kaakgewricht.",
            steps: [
                .init(text: "Tong tegen je gehemelte. Eén vinger op je kaakgewricht, vlak voor je oor.", seconds: 8),
                .init(text: "Leg een vinger van je andere hand op je kin.", seconds: 5),
                .init(text: "Laat je onderkaak langzaam half zakken… en sluit weer. Zes keer.", seconds: 30),
            ],
            repeats: 2, isGentle: true
        ),
        Exercise(
            id: "jaw-goldfish-full", title: "Goudvis (helemaal open)", area: .jaw, symbol: "fish.fill",
            summary: "Zelfde als de goudvis, maar met de tong los voor een grotere opening.",
            benefit: "Vergroot rustig je bewegingsruimte.",
            steps: [
                .init(text: "Vingers weer op je kaakgewricht en je kin.", seconds: 6),
                .init(text: "Open je mond zo ver als comfortabel is, rustig en recht… en sluit weer. Zes keer.", seconds: 36),
            ],
            repeats: 2, caution: "Sla deze over als je kaak op slot schiet of als openen pijn doet."
        ),
        Exercise(
            id: "jaw-resisted-open", title: "Openen met tegendruk", area: .jaw, symbol: "hand.raised",
            summary: "Duim onder je kin, en langzaam openen tegen lichte druk in.",
            benefit: "Versterkt de spieren die je kaak openen, zodat de sluiters kunnen ontspannen.",
            steps: [
                .init(text: "Leg je duim onder je kin.", seconds: 5),
                .init(text: "Open langzaam terwijl je duim zachtjes tegendruk geeft. Houd 3 tot 6 tellen vast.", seconds: 8),
                .init(text: "Sluit rustig en ontspan.", seconds: 5),
            ],
            repeats: 5
        ),
        Exercise(
            id: "jaw-resisted-close", title: "Sluiten met tegendruk", area: .jaw, symbol: "hand.point.up.left",
            summary: "Duim en wijsvinger op je kin, en rustig sluiten tegen lichte druk.",
            benefit: "Geeft meer controle over je kaakbeweging.",
            steps: [
                .init(text: "Knijp je kin licht tussen duim en wijsvinger.", seconds: 5),
                .init(text: "Sluit je mond langzaam terwijl je met je vingers zacht tegenhoudt.", seconds: 8),
                .init(text: "Ontspan.", seconds: 5),
            ],
            repeats: 5
        ),
        Exercise(
            id: "jaw-side", title: "Zijwaarts schuiven", area: .jaw, symbol: "arrow.left.and.right",
            summary: "Je onderkaak rustig van links naar rechts schuiven.",
            benefit: "Maakt het gewricht soepel in alle richtingen.",
            steps: [
                .init(text: "Tanden een klein stukje los. Je kunt een potlood licht tussen je voortanden houden.", seconds: 8),
                .init(text: "Schuif je onderkaak langzaam naar links… en terug naar het midden.", seconds: 10),
                .init(text: "Nu naar rechts… en terug.", seconds: 10),
            ],
            repeats: 3, isGentle: true
        ),
        Exercise(
            id: "jaw-massage", title: "Kauwspiermassage", area: .jaw, symbol: "hand.draw",
            summary: "Kleine cirkeltjes op je kauwspier en slapen.",
            benefit: "Verzacht strakke kauwspieren na een dag klemmen of knarsen.",
            steps: [
                .init(text: "Zoek met je vingertoppen je kauwspier: bijt kort op elkaar en voel waar hij aanspant.", seconds: 10),
                .init(text: "Ontspan je kaak en maak er kleine, rustige cirkeltjes op.", seconds: 45),
                .init(text: "Ga verder naar je slapen. Rustige cirkels, zachte druk.", seconds: 40),
                .init(text: "Strijk tot slot langzaam van je slapen naar je kaaklijn.", seconds: 15),
            ],
            isGentle: true
        ),
        Exercise(
            id: "jaw-warmth", title: "Warmte op je kaak", area: .jaw, symbol: "flame",
            summary: "Een warm (niet heet) kompres op je kaak en wangen.",
            benefit: "Warmte helpt spieren ontspannen, fijn vóór het slapen.",
            steps: [
                .init(text: "Maak een washandje warm (niet heet) en leg het tegen je kaak en wangen.", seconds: 30),
                .init(text: "Leun achterover, laat je tanden los en adem rustig.", seconds: 300),
            ],
            isGentle: true
        ),

        // MARK: Nek
        Exercise(
            id: "neck-chin-tuck", title: "Kin intrekken", area: .both, symbol: "person.fill.viewfinder",
            summary: "Je kin recht naar achteren schuiven, alsof je een dubbele kin maakt.",
            benefit: "Corrigeert een vooruitgeschoven hoofd. Goed voor nek én kaak.",
            steps: [
                .init(text: "Zit of sta rechtop, schouders laag en ontspannen.", seconds: 6),
                .init(text: "Schuif je kin recht naar achteren. Houd 5 tellen vast.", seconds: 6),
                .init(text: "Laat rustig los.", seconds: 4),
            ],
            repeats: 8, isGentle: true
        ),
        Exercise(
            id: "neck-side-stretch", title: "Zijkant van je nek", area: .neck, symbol: "figure.flexibility",
            summary: "Oor richting schouder, de andere schouder blijft laag.",
            benefit: "Rekt de bovenste trapeziusspier, waar stress vaak zit.",
            steps: [
                .init(text: "Laat je rechteroor rustig richting je rechterschouder zakken.", seconds: 25),
                .init(text: "Kom langzaam terug naar het midden.", seconds: 5),
                .init(text: "Nu je linkeroor richting je linkerschouder.", seconds: 25),
                .init(text: "Terug naar het midden. Adem uit.", seconds: 5),
            ],
            repeats: 2, isGentle: true
        ),
        Exercise(
            id: "neck-levator", title: "Neus naar je oksel", area: .neck, symbol: "arrow.down.right",
            summary: "Een schuine rek voor de spier tussen nek en schouderblad.",
            benefit: "Verlicht die bekende stijve plek achter in je nek.",
            steps: [
                .init(text: "Draai je hoofd een beetje naar rechts en kijk omlaag, richting je rechteroksel.", seconds: 25),
                .init(text: "Kom rustig terug.", seconds: 5),
                .init(text: "Nu naar links: neus richting je linkeroksel.", seconds: 25),
                .init(text: "Terug naar het midden.", seconds: 5),
            ],
            repeats: 2
        ),
        Exercise(
            id: "neck-rotation", title: "Rustig omkijken", area: .neck, symbol: "arrow.triangle.2.circlepath",
            summary: "Langzaam over je schouder kijken, links en rechts.",
            benefit: "Houdt je nek soepel na lang stilzitten.",
            steps: [
                .init(text: "Kijk langzaam over je rechterschouder, zo ver als prettig is.", seconds: 10),
                .init(text: "Terug naar het midden.", seconds: 4),
                .init(text: "Nu over je linkerschouder.", seconds: 10),
                .init(text: "Terug naar het midden.", seconds: 4),
            ],
            repeats: 4, isGentle: true
        ),
        Exercise(
            id: "neck-shoulder-rolls", title: "Schouders rollen", area: .neck, symbol: "arrow.clockwise",
            summary: "Grote, trage cirkels met je schouders naar achteren.",
            benefit: "Losser in schouders en nek, in minder dan een minuut.",
            steps: [
                .init(text: "Trek je schouders omhoog richting je oren…", seconds: 4),
                .init(text: "…rol ze naar achteren en laat ze zwaar naar beneden zakken.", seconds: 4),
            ],
            repeats: 8, isGentle: true
        ),
        Exercise(
            id: "neck-scapula", title: "Schouderbladen samen", area: .neck, symbol: "figure.strengthtraining.functional",
            summary: "Je schouderbladen naar elkaar en omlaag trekken.",
            benefit: "Versterkt je bovenrug, zodat je nek minder hoeft te dragen.",
            steps: [
                .init(text: "Zit rechtop en trek je schouderbladen naar elkaar en een beetje omlaag.", seconds: 6),
                .init(text: "Houd 5 tellen vast, adem door.", seconds: 5),
                .init(text: "Laat los.", seconds: 4),
            ],
            repeats: 8
        ),

        // MARK: Allebei
        Exercise(
            id: "both-breath", title: "Ontspannende ademhaling", area: .both, symbol: "wind",
            summary: "Buikademhaling met een lange uitademing.",
            benefit: "Kalmeert je zenuwstelsel. Spanning in kaak en nek zakt vaak mee.",
            steps: [
                .init(text: "Leg een hand op je buik. Kaak los, schouders laag.", seconds: 10),
                .init(text: "Adem 4 tellen in door je neus, je buik komt naar voren.", seconds: 4),
                .init(text: "Houd 2 tellen vast.", seconds: 2),
                .init(text: "Adem 6 tellen heel langzaam uit door je mond.", seconds: 6),
            ],
            repeats: 6, isGentle: true
        ),
        Exercise(
            id: "both-pmr", title: "Spannen en loslaten", area: .both, symbol: "circle.dotted.and.circle",
            summary: "Kort aanspannen en dan bewust ontspannen: schouders, nek en gezicht.",
            benefit: "Leert je voelen wat ontspanning is, zodat je het eerder merkt als je klemt.",
            steps: [
                .init(text: "Trek je schouders hoog op en span ze aan.", seconds: 5),
                .init(text: "Laat los. Voel het verschil.", seconds: 12),
                .init(text: "Knijp je ogen en gezicht zacht samen.", seconds: 5),
                .init(text: "Laat los. Je voorhoofd wordt glad en zacht.", seconds: 12),
                .init(text: "Druk je lippen zacht samen, tanden los.", seconds: 5),
                .init(text: "Laat los. Je kaak hangt los en zwaar.", seconds: 15),
            ],
            isGentle: true
        ),
    ]

    static func exercise(id: String) -> Exercise? { all.first { $0.id == id } }

    static func filtered(_ area: PainArea?) -> [Exercise] {
        guard let area, area != .both else { return all }
        return all.filter { $0.area == area || $0.area == .both }
    }
}
