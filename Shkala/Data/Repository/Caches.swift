import Foundation

/// معادل SiteInfoCache اپ اندروید: کش سبک و درون‌حافظه‌ای اطلاعات پایه‌ی سایت (نام سایت + لوگو).
/// همون درخواستی که در زمان بارگذاری اولیه‌ی اپ (StartupViewModel) زده می‌شه، نتیجه‌ش رو اینجا
/// ذخیره می‌کنه؛ صفحه‌ها اول این کش رو چک می‌کنن.
enum SiteInfoCache {
    private(set) static var siteName: String? = nil
    private(set) static var logoUrl: String? = nil
    // نسخه‌ی لوگوی تم تاریک (logo_dark_url)
    private(set) static var logoDarkUrl: String? = nil
    private static var timestampMs: Int64 = 0
    private static let TTL_MS: Int64 = 5 * 60 * 1000

    static func isFresh() -> Bool { siteName != nil && nowMs() - timestampMs < TTL_MS }

    static func prime(name: String?, logo: String? = nil, logoDark: String? = nil) {
        siteName = name
        logoUrl = logo
        logoDarkUrl = logoDark
        timestampMs = nowMs()
    }
}

/// معادل AppStatusCache اپ اندروید: آخرین پاسخ موفق api/v2/app/status در طول اجرای اپ.
final class AppStatusCache: ObservableObject {
    static let shared = AppStatusCache()
    @Published private(set) var status: AppStatusResponse? = nil

    /// پاپ‌آپ فعال فعلی (null = نیست یا هنوز وضعیت دریافت نشده)
    var popup: AppPopupDto? { status?.popup }
    /// اطلاعیه‌ی فعال فعلی
    var announcement: AppAnnouncementDto? { status?.announcement }

    func update(_ status: AppStatusResponse) {
        if Thread.isMainThread { self.status = status } else { DispatchQueue.main.async { self.status = status } }
    }
}

/// زمان فعلی به میلی‌ثانیه (System.currentTimeMillis)
func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
