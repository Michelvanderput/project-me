# Project Me

**Werken aan jezelf. Focussen op jezelf.**
Een native iOS-app (SwiftUI, iOS 26) voor een rustig dagritme: dankbaarheid en meditatie in de ochtend, een lief berichtje in de middag, water door de dag heen, en 's avonds een blij moment, een check van kaak- en nekpijn, passende oefeningen en een avondmeditatie. De app leert van je, op je eigen toestel.

## Wat zit erin

| Moment | Functie |
|---|---|
| **Ochtend** | Stemming, *daily gratitude* (3 dingen), intentie, geleide **ochtendmeditatie** (3, 5 of 10 min) |
| **Middag** | **Popup met een lief motivatieberichtje** (melding én in-app sheet), met ❤️ / "iets anders" |
| **Hele dag** | **Water** bijhouden naar 2 liter: snelle knoppen, slimme herinneringen alleen als je achterloopt, actieknoppen in de melding (+250 / +500 ml) |
| **Avond** | **Blij moment in je boekje** (met foto), **kaak- en nekpijn 0–10** met triggers, **oefeningen voor kaak/nek**, **avondmeditatie** (bodyscan met aandacht voor kaak, nek en schouders) |
| **Boekje** | Al je blije momenten en dankbaarheid, per maand, doorzoekbaar, en te lezen als een echt boekje |
| **Lichaam** | 16 oefeningen (goudvis, rustpositie, tegendruk, massage, warmte, kin intrekken, nekrekken, ademhaling…) met een stap-voor-stap-speler |
| **Inzicht** | Grafieken (Swift Charts) van pijn en water, en wat de app over je geleerd heeft. Geen streaks: een gemiste dag is geen mislukking |

### De app leert van je (lokaal, privé)
`ProjectMe/Services/LearningEngine.swift`
- **Herinneringstijden** schuiven mee naar wanneer jij echt incheckt (mediaan van de laatste 14 keer, net iets eerder).
- **Motivatieberichtjes** worden gewogen naar je ❤️'s per categorie en per bericht.
- **Oefeningen** worden gerangschikt op waar de pijn zit, jouw "hielp dit?"-antwoorden en of je pijn de dag erna lager was.
- **Water**: je favoriete glasgrootte en je eigen tempo over de dag.
- **Patronen**: water ↔ pijn, avondmeditatie ↔ pijn de volgende dag, triggers op zware dagen, trend per week.
- **Apple Intelligence** (Foundation Models, on-device): als het beschikbaar is, schrijft de app een persoonlijk middagberichtje op basis van je stemming, intentie, pijn en water. Anders valt hij terug op de bibliotheek.

### Widgets, Dynamic Island en meer
- **Widgets** (beginscherm + toegangsscherm): *Water* (interactieve +knoppen), *Mijn dag* (ritme + volgende stapje + berichtje + boekje), *Lief berichtje*.
- **Dynamic Island / Live Activities**: water-voortgang met + knoppen, en een lopende meditatie met live afteltimer.
- **Control Center / Actieknop**: "+250 ml water".
- **Siri & Shortcuts**: "Voeg water toe in Project Me", "Start mijn ochtend in Project Me", enz.
- **Gezondheid** (optioneel): water en mindful minuten.
- **Gesproken begeleiding** (optioneel, Nederlandse stem) bij meditaties en oefeningen.

## Design-aanpak
Gebaseerd op de stack-library (Apple Human Interface Guidelines, WCAG 2.2, `prefers-reduced-motion`, 44pt touch targets, beweging 150–300 ms voor feedback en 300–500 ms voor overgangen), vertaald naar native SwiftUI in plaats van React Native, omdat de wens een volledig Apple-native app was:
- **Tokens** in `Shared/Support/Theme.swift`: kleuren per dagdeel (dageraad, schemering, water, salie, roos), 4pt-ruimtegrid, rondingen, beweging.
- **Liquid Glass** (iOS 26) voor bediening (`.glass`, `.glassProminent`), rustige ondoorzichtige kaarten voor inhoud, zoals de HIG aanraadt.
- Zacht bewegende **MeshGradient**-achtergrond die meekleurt met het dagdeel en stilstaat bij *Verminder beweging*.
- Systeemtypografie met Dynamic Type, rounded voor de interface en serif voor het boekje. SF Symbols-animaties en haptiek met mate.
- VoiceOver-labels, verstelbare pijnschalen, duidelijke contrasten in licht en donker.

## Bouwen

Vereist **Xcode 26** en [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

```bash
open ProjectMe.xcodeproj
```

Daarna in Xcode:
1. Kies bij *Signing & Capabilities* je eigen **Team** voor beide targets (`ProjectMe` en `ProjectMeWidgets`), of zet `DEVELOPMENT_TEAM` in `project.yml`.
2. Pas zo nodig de bundle-ID's en de App Group (`group.nl.michelvanderput.projectme`) aan. De App Group moet in beide targets gelijk zijn (ook in `Shared/Support/AppGroup.swift`).
3. Run op een iPhone (Live Activities en de Dynamic Island werken het best op een echt toestel).

De CI-workflow in `.github/workflows/ios.yml` bouwt de app bij elke push voor de simulator.

## Structuur

```
project.yml                 XcodeGen-project (app + widget-extensie)
Shared/                     Gedeeld door app en widgets
  Models/                   SwiftData-modellen (in de App Group)
  Intents/                  AddWaterIntent (widgets, Dynamic Island, Siri, Control Center)
  Support/                  Theme, voorkeuren, WaterStore, Live Activity-types, motivatiebibliotheek
ProjectMe/
  App/                      Entry point en tab-structuur
  Design/                   Componenten en achtergrond
  Features/                 Vandaag, Ochtend, Avond, Meditatie, Oefeningen, Water, Boekje, Inzicht, Instellingen, Onboarding
  Services/                 Notificaties, LearningEngine, Motivatie (Apple Intelligence), Live Activities, Gezondheid, spraak, router, App Shortcuts
ProjectMeWidgets/           Widgets, Control, Live Activities
```

## Let op
Project Me geeft geen medisch advies. De oefeningen zijn mild en algemeen bekend. Houden klachten aan, overleg dan met je huisarts, tandarts of (kaak)fysiotherapeut. Alle gegevens blijven op je eigen iPhone.
