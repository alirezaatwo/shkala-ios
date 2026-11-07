import Foundation

/**
 * معادل ViewedOrdersManager اپ اندروید: پیگیری اینکه کاربر کدوم سفارش‌ها رو تا حالا باز کرده - چون
 * سایت چیزی برای «خونده‌شده/نشده» نداره، این کاملاً محلی (رو خود گوشی) نگه داشته می‌شه.
 */
@MainActor
final class ViewedOrdersManager: ObservableObject {
    static let shared = ViewedOrdersManager()

    private let defaults = UserDefaults(suiteName: "shkala_viewed_orders") ?? .standard
    private let KEY_VIEWED_ORDER_IDS = "viewed_order_ids"

    @Published private(set) var viewedOrderIds: Set<String> = []

    private init() {
        viewedOrderIds = Set(defaults.stringArray(forKey: KEY_VIEWED_ORDER_IDS) ?? [])
    }

    func markOrderAsViewed(_ orderId: Int) {
        var current = Set(defaults.stringArray(forKey: KEY_VIEWED_ORDER_IDS) ?? [])
        current.insert(String(orderId))
        defaults.set(Array(current), forKey: KEY_VIEWED_ORDER_IDS)
        viewedOrderIds = current
    }

    func isOrderViewed(_ orderId: Int) -> Bool { viewedOrderIds.contains(String(orderId)) }
}
