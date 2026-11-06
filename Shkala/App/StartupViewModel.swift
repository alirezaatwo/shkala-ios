import Foundation

/// معادل StartupViewModel اپ اندروید: بارگذاری واقعی اپ هم‌زمان با اسپلش، با درصد پیشرفت.
///
/// مرحله‌ی ۱ (اسکلت): فقط بررسی اتصال اینترنت و در دسترس بودن سرور (api/v2/site-info).
/// مراحل کامل اندروید (وضعیت بروزرسانی سایت، اطلاعات پایه، ماژول‌های صفحه‌ی اصلی) در
/// مرحله‌ی ۲ (لایه‌ی API) دقیقاً با همان وزن‌ها اضافه می‌شن.
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

    @MainActor
    private func run() async {
        // مرحله‌ی ۰: اگه گوشی اصلاً به اینترنت وصل نیست، بی‌دلیل منتظر تایم‌اوت درخواست‌ها نمی‌مونیم
        try? await Task.sleep(nanoseconds: 300_000_000) // فرصت برای اولین گزارش وضعیت شبکه
        if !NetworkMonitor.shared.isInternetAvailable {
            offlineMessage = Self.MESSAGE_NO_INTERNET
            return
        }
        progress = Self.WEIGHT_AUTH

        // مرحله‌ی ۲: در دسترس بودن سرور فروشگاه
        var request = URLRequest(url: URL(string: "\(ApiConstants.BASE_URL)api/v2/site-info")!)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let reachable: Bool
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            reachable = (response as? HTTPURLResponse).map { $0.statusCode < 500 || $0.statusCode == 503 } ?? false
        } catch {
            reachable = false
        }
        if offlineMessage != nil { return }
        if !reachable {
            offlineMessage = NetworkMonitor.shared.isInternetAvailable ? Self.MESSAGE_SERVER_UNREACHABLE : Self.MESSAGE_NO_INTERNET
            return
        }
        progress = Self.WEIGHT_AUTH + Self.WEIGHT_SITE_INFO
        progress = 100
    }
}

enum ApiConstants {
    /// آدرس سایت (با اسلش انتهایی) - همان BASE_URL اپ اندروید
    static let BASE_URL = "https://shkala.com/"
}
