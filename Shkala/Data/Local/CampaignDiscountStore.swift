import Foundation

/**
 * معادل data/local/CampaignDiscountStore.kt: کد تخفیفِ لینک کمپین (سایت/discount/کد): کاربر لینک رو باز می‌کنه،
 * کد اینجا ذخیره می‌شه و وقتی وارد صفحه‌ی تسویه‌حساب شد یک‌بار به‌صورت خودکار اعمال می‌شه.
 */
enum CampaignDiscountStore {
    private static let KEY_CODE = "shkala_campaign.discount_code"

    static func save(_ code: String) {
        UserDefaults.standard.set(code.trimmingCharacters(in: .whitespacesAndNewlines), forKey: KEY_CODE)
    }

    static func peek() -> String? {
        guard let code = UserDefaults.standard.string(forKey: KEY_CODE)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else { return nil }
        return code
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: KEY_CODE)
    }
}

/// معادل isVpnActive اندروید (NetworkUtils.kt). تفاوت iOS: سیستم API مستقیمی برای این کار نداره؛
/// رابط‌های شبکه‌ی VPN (tun/tap/ppp/ipsec) از تنظیمات پراکسی سیستم خونده می‌شن.
func isVpnActive() -> Bool {
    guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
          let scoped = settings["__SCOPED__"] as? [String: Any] else { return false }
    return scoped.keys.contains { key in
        ["tap", "tun", "ppp", "ipsec"].contains { key.lowercased().contains($0) }
    }
}
