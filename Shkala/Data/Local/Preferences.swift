import Foundation
import Network

/// معادل IntroPreferenceManager اپ اندروید: اینترو فقط یک‌بار نمایش داده می‌شه
enum IntroPreferenceManager {
    private static let key = "shkala_intro.has_seen_intro"

    static func hasSeenIntro() -> Bool { UserDefaults.standard.bool(forKey: key) }
    static func markIntroAsSeen() { UserDefaults.standard.set(true, forKey: key) }
}

/// معادل ThemePreferenceManager اپ اندروید: انتخاب دستی کاربر بین تم روشن/تاریک.
/// تا وقتی کاربر خودش تم رو عوض نکرده، پیش‌فرض همیشه تم روشنه (مستقل از تنظیم گوشی).
final class ThemePreferenceManager: ObservableObject {
    private static let key = "shkala_theme.is_dark_theme"

    @Published private(set) var isDarkTheme: Bool

    init() {
        isDarkTheme = UserDefaults.standard.object(forKey: Self.key) as? Bool ?? false
    }

    func setDarkTheme(_ isDark: Bool) {
        UserDefaults.standard.set(isDark, forKey: Self.key)
        isDarkTheme = isDark
    }
}

/// معادل isInternetAvailable / internetAvailabilityFlow اپ اندروید (NetworkUtils.kt).
/// (تشخیص VPN در مرحله‌ی دیالوگ‌های شروع اضافه می‌شه)
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    /// آیا گوشی الان به یک شبکه‌ی دارای اینترنت وصله؟ (تا اولین گزارش سیستم: true تا اپ بی‌دلیل قفل نشه)
    @Published private(set) var isInternetAvailable = true

    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            DispatchQueue.main.async {
                self?.isInternetAvailable = available
            }
        }
        monitor.start(queue: DispatchQueue(label: "shkala.network"))
    }
}
