import Foundation

/** معادل ViewedPrefactorsManager اپ اندروید: پیگیری اینکه کاربر کدوم پیش‌فاکتورها رو تا حالا باز کرده - محلی، رو خود گوشی */
@MainActor
final class ViewedPrefactorsManager: ObservableObject {
    static let shared = ViewedPrefactorsManager()

    private let defaults = UserDefaults(suiteName: "shkala_viewed_prefactors") ?? .standard
    private let KEY_VIEWED_PREFACTOR_UUIDS = "viewed_prefactor_uuids"

    @Published private(set) var viewedPrefactorUuids: Set<String> = []

    private init() {
        viewedPrefactorUuids = Set(defaults.stringArray(forKey: KEY_VIEWED_PREFACTOR_UUIDS) ?? [])
    }

    func markPrefactorAsViewed(_ uuid: String) {
        var current = Set(defaults.stringArray(forKey: KEY_VIEWED_PREFACTOR_UUIDS) ?? [])
        current.insert(uuid)
        defaults.set(Array(current), forKey: KEY_VIEWED_PREFACTOR_UUIDS)
        viewedPrefactorUuids = current
    }
}
