import Foundation

struct RecentlyViewedProduct: Codable, Equatable {
    let slug: String
    let title: String
    let imageUrl: String?
    let bestPrice: Int64?
}

/// معادل RecentlyViewedManager اپ اندروید: بازدیدهای اخیر - دقیقاً مثل سایت (که با نشست مرورگر
/// کار می‌کنه)، این هم کاملاً محلی (رو خود گوشی) نگه داشته می‌شه، نه سرور.
final class RecentlyViewedManager: ObservableObject {
    static let shared = RecentlyViewedManager()
    static let EXTENDED_LIMIT = 15

    private let defaults = UserDefaults(suiteName: "shkala_recently_viewed") ?? .standard
    private let KEY_PRODUCTS = "recently_viewed_json"
    private let KEY_EXTENDED = "recently_viewed_extended_json"

    /// فهرست ۸تایی (صفحه‌ی بازدیدهای اخیر)
    @Published private(set) var recentlyViewed: [RecentlyViewedProduct] = []
    /// حداکثر ۱۵ بازدید اخیر (جدیدترین اول) - اگه هنوز فهرست بلند ساخته نشده، همون فهرست قبلی
    @Published private(set) var recentlyViewedExtended: [RecentlyViewedProduct] = []

    private init() { reload() }

    private func parse(_ key: String) -> [RecentlyViewedProduct]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([RecentlyViewedProduct].self, from: data)
    }

    private func reload() {
        recentlyViewed = parse(KEY_PRODUCTS) ?? []
        recentlyViewedExtended = parse(KEY_EXTENDED) ?? parse(KEY_PRODUCTS) ?? []
    }

    func recordView(_ product: RecentlyViewedProduct) {
        let current = parse(KEY_PRODUCTS) ?? []
        let updated = Array(([product] + current.filter { $0.slug != product.slug }).prefix(8))
        defaults.set(try? JSONEncoder().encode(updated), forKey: KEY_PRODUCTS)

        // فهرست بلندتر (۱۵تایی) برای ماژول «آخرین محصولاتی که مشاهده کردید» صفحه‌ی اصلی
        let currentExtended = parse(KEY_EXTENDED) ?? current
        let updatedExtended = Array(([product] + currentExtended.filter { $0.slug != product.slug }).prefix(Self.EXTENDED_LIMIT))
        defaults.set(try? JSONEncoder().encode(updatedExtended), forKey: KEY_EXTENDED)
        DispatchQueue.main.async { self.reload() }
    }
}
