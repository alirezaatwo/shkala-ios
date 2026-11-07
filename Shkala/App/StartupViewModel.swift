import Foundation

/// معادل StartupViewModel اپ اندروید: بارگذاری واقعی اپ هم‌زمان با اسپلش، با درصد پیشرفت.
///
/// همان مراحل و وزن‌های اندروید: ورود (۱۵)، وضعیت بروزرسانی سایت، اطلاعات پایه‌ی سایت (۱۵)،
/// ماژول‌های صفحه‌ی اصلی (۷۰ - همراه صفحه‌ی اصلی در مرحله‌ی ۳).
final class StartupViewModel: ObservableObject {
    @Published private(set) var progress = 0
    /// اگه بارگذاری اولیه به‌خاطر نبودِ اینترنت (یا در دسترس نبودن سرور) ممکن نشد، متن خطا اینجاست
    @Published private(set) var offlineMessage: String? = nil

    static let MESSAGE_NO_INTERNET = "عدم دسترسی به اینترنت؛ لطفاً اتصال اینترنت گوشی را بررسی کنید."
    static let MESSAGE_SERVER_UNREACHABLE = "ارتباط با فروشگاه برقرار نشد؛ لطفاً اتصال اینترنت را بررسی و دوباره تلاش کنید."

    private static let WEIGHT_AUTH = 15
    private static let WEIGHT_SITE_INFO = 15

    private var task: Task<Void, Never>? = nil

    @MainActor
    func markOffline() {
        if offlineMessage != nil { return }
        offlineMessage = Self.MESSAGE_NO_INTERNET
        task?.cancel()
    }

    /// فقط یک‌بار واقعاً اجرا می‌شه؛ صدا زدن دوباره همون اجرای مشترک رو برمی‌گردونه
    @MainActor
    func startIfNeeded() -> Task<Void, Never> {
        if let task { return task }
        let newTask = Task { @MainActor in await self.run() }
        task = newTask
        return newTask
    }

    /// تمام مراحل بارگذاری اولیه‌ی اپ رو به‌ترتیب اجرا می‌کنه (StartupViewModel.run اندروید)
    @MainActor
    private func run() async {
        // مرحله‌ی ۰: اگه گوشی اصلاً به اینترنت وصل نیست، بی‌دلیل منتظر تایم‌اوت درخواست‌ها نمی‌مونیم
        try? await Task.sleep(nanoseconds: 300_000_000) // فرصت برای اولین گزارش وضعیت شبکه
        if !NetworkMonitor.shared.isInternetAvailable {
            offlineMessage = Self.MESSAGE_NO_INTERNET
            return
        }

        // مرحله‌ی ۱: بررسی وضعیت ورود کاربر (خوندن توکن ذخیره‌شده)
        _ = TokenManager.shared.getTokenOnce()
        progress = Self.WEIGHT_AUTH / 2

        // مرحله‌ی ۱.۵: وضعیت «در حال بروزرسانی» سایت، قبل از نمایش هر صفحه‌ای از اپ؛
        // تا اگه سایت در حالت بروزرسانیه، کاربر مستقیم از اسپلش به صفحه‌ی بروزرسانی بره
        let status = await fetchMaintenanceStatus()
        MaintenanceStatusCache.prime(status)
        progress = Self.WEIGHT_AUTH
        if offlineMessage != nil || Task.isCancelled { return }
        if status?.maintenance == true {
            // در حالت بروزرسانی نیازی به بارگذاری صفحه‌ی اصلی نیست
            progress = 100
            return
        }

        // مرحله‌ی ۲: اطلاعات پایه‌ی سایت (نام فروشگاه و لوگو) - در SiteInfoCache نگه‌داری می‌شه
        let siteInfoResult = await CatalogRepository().getSiteInfo()
        if case .success(let info) = siteInfoResult {
            SiteInfoCache.prime(name: info.siteName, logo: info.logoUrl, logoDark: info.logoDarkUrl)
        } else if status == nil {
            // هیچ‌کدوم از دو درخواست اول به سرور نرسید: یا اینترنت قطع شده یا سرور در دسترس نیست؛
            // به‌جای ورود به اپِ خالی، صفحه‌ی «عدم دسترسی» با دکمه‌ی تلاش مجدد نمایش داده می‌شه
            offlineMessage = NetworkMonitor.shared.isInternetAvailable ? Self.MESSAGE_SERVER_UNREACHABLE : Self.MESSAGE_NO_INTERNET
            return
        }
        if offlineMessage != nil || Task.isCancelled { return }
        progress = Self.WEIGHT_AUTH + Self.WEIGHT_SITE_INFO

        // مرحله‌ی ۳: تمام ماژول‌های صفحه‌ی اصلی - همراه صفحه‌ی اصلی در مرحله‌ی ۳ اضافه می‌شه
        progress = 100
    }
}
