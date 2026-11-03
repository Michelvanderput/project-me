import Foundation
import SwiftData
import UserNotifications

/// Plant alle herinneringen lokaal in. We plannen losse meldingen voor de komende dagen
/// (in plaats van een vaste herhaling), zodat:
/// - een herinnering vervalt als je vandaag al hebt ingecheckt;
/// - het tijdstip met je mee kan leren;
/// - elke middag een ander lief berichtje komt.
@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()

    enum Category {
        static let morning = "MORNING"
        static let evening = "EVENING"
        static let motivation = "MOTIVATION"
        static let water = "WATER"
    }
    enum Action {
        static let like = "LIKE"
        static let dislike = "DISLIKE"
        static let water250 = "WATER_250"
        static let water500 = "WATER_500"
        static let open = "OPEN"
    }

    private let center = UNUserNotificationCenter.current()
    private let horizonDays = 7

    func configure() {
        center.delegate = self
        let open = UNNotificationAction(identifier: Action.open, title: "Openen", options: [.foreground])
        let like = UNNotificationAction(identifier: Action.like, title: "Fijn bericht ❤️", options: [],
                                        icon: UNNotificationActionIcon(systemImageName: "heart"))
        let dislike = UNNotificationAction(identifier: Action.dislike, title: "Liever iets anders", options: [],
                                           icon: UNNotificationActionIcon(systemImageName: "arrow.triangle.2.circlepath"))
        let w250 = UNNotificationAction(identifier: Action.water250, title: "+250 ml", options: [],
                                        icon: UNNotificationActionIcon(systemImageName: "drop"))
        let w500 = UNNotificationAction(identifier: Action.water500, title: "+500 ml", options: [],
                                        icon: UNNotificationActionIcon(systemImageName: "drop.fill"))
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Category.morning, actions: [open], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.evening, actions: [open], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.motivation, actions: [like, dislike], intentIdentifiers: []),
            UNNotificationCategory(identifier: Category.water, actions: [w250, w500], intentIdentifiers: []),
        ])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    var isAuthorized: Bool {
        get async { await center.notificationSettings().authorizationStatus == .authorized }
    }

    // MARK: Plannen

    func rescheduleAll(context: ModelContext) async {
        guard await isAuthorized else { return }
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let ours = pending.filter { $0.hasPrefix("pm.") }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let d = AppGroup.defaults
        let name = Prefs.userName
        let today = Date.now.startOfDay
        let morningDone = hasMorning(on: today, context: context)
        let eveningDone = hasEvening(on: today, context: context)

        let morningMinutes = LearningEngine.effectiveReminderMinutes(.morning, in: context)
        let eveningMinutes = LearningEngine.effectiveReminderMinutes(.evening, in: context)
        let motivationMinutes = d.integer(forKey: PrefKey.motivationMinutes)

        for offset in 0..<horizonDays {
            let day = today.adding(days: offset)

            if d.bool(forKey: PrefKey.morningReminderOn), !(offset == 0 && morningDone) {
                let content = UNMutableNotificationContent()
                content.title = greeting(name: name, part: .morning)
                content.body = Self.morningBodies[offset % Self.morningBodies.count]
                content.categoryIdentifier = Category.morning
                content.threadIdentifier = "checkin"
                content.userInfo = ["link": DeepLink.morning.rawValue]
                content.interruptionLevel = .timeSensitive
                content.sound = .default
                add("pm.morning.\(offset)", content, day: day, minutes: morningMinutes)
            }

            if d.bool(forKey: PrefKey.motivationOn) {
                let message = MotivationLibrary.pick(for: day)
                let content = UNMutableNotificationContent()
                content.title = name.isEmpty ? "Een lief berichtje" : "Voor jou, \(name)"
                if offset == 0, let generated = MotivationService.cachedGeneratedText(for: day) {
                    content.body = generated
                    content.userInfo = ["link": DeepLink.motivation.rawValue, "messageID": "ai"]
                } else {
                    content.body = message.text
                    content.userInfo = ["link": DeepLink.motivation.rawValue, "messageID": message.id]
                }
                content.categoryIdentifier = Category.motivation
                content.threadIdentifier = "motivation"
                content.sound = .default
                content.relevanceScore = 0.6
                add("pm.motivation.\(offset)", content, day: day, minutes: motivationMinutes)
            }

            if d.bool(forKey: PrefKey.eveningReminderOn), !(offset == 0 && eveningDone) {
                let content = UNMutableNotificationContent()
                content.title = greeting(name: name, part: .evening)
                content.body = Self.eveningBodies[offset % Self.eveningBodies.count]
                content.categoryIdentifier = Category.evening
                content.threadIdentifier = "checkin"
                content.userInfo = ["link": DeepLink.evening.rawValue]
                content.interruptionLevel = .timeSensitive
                content.sound = .default
                add("pm.evening.\(offset)", content, day: day, minutes: eveningMinutes)
            }
        }
        await rescheduleWater(context: context)
    }

    /// Slimme waterherinneringen: alleen op momenten waarop je achterloopt op je eigen ritme.
    func rescheduleWater(context: ModelContext) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("pm.water.") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard AppGroup.defaults.bool(forKey: PrefKey.waterRemindersOn), await isAuthorized else { return }

        let d = AppGroup.defaults
        let wake = d.integer(forKey: PrefKey.wakeMinutes)
        let bed = d.integer(forKey: PrefKey.bedMinutes)
        let goal = Prefs.waterGoalML
        let total = WaterStore.total(in: context)
        let glass = LearningEngine.preferredGlassSize(in: context)
        let slots = stride(from: wake + 90, through: bed - 90, by: 120).map { $0 }

        let nowMinutes = Date.now.minutesSinceMidnight
        for (index, slot) in slots.enumerated() where slot > nowMinutes + 20 {
            let expected = LearningEngine.expectedWater(at: Date.today(atMinutes: slot))
            guard total < expected, total < goal else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Tijd voor wat water 💧"
            content.body = "Je zit op \(total) ml. Een glas van \(glass) ml brengt je weer lekker op schema."
            content.categoryIdentifier = Category.water
            content.threadIdentifier = "water"
            content.interruptionLevel = .passive
            content.userInfo = ["link": DeepLink.water.rawValue]
            add("pm.water.today.\(index)", content, day: .now, minutes: slot)
        }
        // Morgen: de eerste twee herinneringen staan alvast klaar, ook als je de app niet opent.
        for (index, slot) in slots.prefix(2).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Goedemorgen, water?"
            content.body = "Begin je dag met een glas water. Je lichaam (en je kaak) zeggen dankjewel."
            content.categoryIdentifier = Category.water
            content.threadIdentifier = "water"
            content.interruptionLevel = .passive
            content.userInfo = ["link": DeepLink.water.rawValue]
            add("pm.water.tomorrow.\(index)", content, day: Date.now.adding(days: 1), minutes: slot)
        }
    }

    private func add(_ id: String, _ content: UNMutableNotificationContent, day: Date, minutes: Int) {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        components.hour = minutes / 60
        components.minute = minutes % 60
        guard let fireDate = Calendar.current.date(from: components), fireDate > .now else { return }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func hasMorning(on day: Date, context: ModelContext) -> Bool {
        let d = FetchDescriptor<MorningCheckIn>(predicate: #Predicate { $0.day == day })
        return ((try? context.fetchCount(d)) ?? 0) > 0
    }
    private func hasEvening(on day: Date, context: ModelContext) -> Bool {
        let d = FetchDescriptor<EveningCheckIn>(predicate: #Predicate { $0.day == day })
        return ((try? context.fetchCount(d)) ?? 0) > 0
    }

    private func greeting(name: String, part: Date.DayPart) -> String {
        let base = part == .morning ? "Goedemorgen" : "Goedenavond"
        let emoji = part == .morning ? "☀️" : "🌙"
        return name.isEmpty ? "\(base) \(emoji)" : "\(base), \(name) \(emoji)"
    }

    static let morningBodies = [
        "Drie dingen waar je dankbaar voor bent, en vijf minuten rust. Klaar voor je dag?",
        "Even inchecken? Een rustige start maakt de hele dag zachter.",
        "Je ochtendmoment staat klaar: dankbaarheid en een korte meditatie.",
        "Nieuwe dag, nieuwe kansen. Waar ben je vandaag dankbaar voor?",
        "Neem even vijf minuten voor jezelf, voordat de dag begint.",
    ]
    static let eveningBodies = [
        "Tijd om je dag af te sluiten: een blij moment, je kaak en nek, en even ontspannen.",
        "Wat was vandaag je blije moment? Je boekje wacht op je.",
        "Laat de dag los met je avondmeditatie. Hoe voelen je kaak en nek?",
        "Even terugkijken en ontspannen. Je hebt vandaag je best gedaan.",
        "Schrijf je blije moment op en geef je kaak wat rust.",
    ]
}

// MARK: - Reacties op meldingen

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        let link = info["link"] as? String
        let messageID = info["messageID"] as? String
        await handle(action: action, link: link, messageID: messageID)
    }

    private func handle(action: String, link: String?, messageID: String?) async {
        let context = SharedModelContainer.shared.mainContext
        switch action {
        case Action.like:
            if let messageID { LearningEngine.recordReaction(messageID: messageID, liked: true, in: context) }
        case Action.dislike:
            if let messageID { LearningEngine.recordReaction(messageID: messageID, liked: false, in: context) }
        case Action.water250:
            WaterStore.add(250, in: context)
            await rescheduleWater(context: context)
        case Action.water500:
            WaterStore.add(500, in: context)
            await rescheduleWater(context: context)
        default:
            if let link, let deepLink = DeepLink(rawValue: link) { Router.shared.open(deepLink) }
        }
    }
}
