import Foundation
import HealthKit

/// Optionele koppeling met Gezondheid: water en mindful minuten.
@MainActor
final class HealthService {
    static let shared = HealthService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    private var isEnabled: Bool { AppGroup.defaults.bool(forKey: PrefKey.healthSync) && isAvailable }

    private var shareTypes: Set<HKSampleType> {
        [HKQuantityType(.dietaryWater), HKCategoryType(.mindfulSession)]
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: [HKQuantityType(.dietaryWater)])
            return true
        } catch {
            return false
        }
    }

    func saveWater(ml: Int, at date: Date) {
        guard isEnabled else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(ml))
        let sample = HKQuantitySample(type: HKQuantityType(.dietaryWater), quantity: quantity, start: date, end: date)
        store.save(sample) { _, _ in }
    }

    func saveMindful(start: Date, end: Date) {
        guard isEnabled, end > start else { return }
        let sample = HKCategorySample(type: HKCategoryType(.mindfulSession),
                                      value: HKCategoryValue.notApplicable.rawValue, start: start, end: end)
        store.save(sample) { _, _ in }
    }
}
