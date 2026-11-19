import Foundation

/**
 * معادل data/OnlinePresenceReporter.kt اپ اندروید (۳.۹).
 * «کاربران آنلاین» پنل سایت به‌صورت لحظه‌ای: با هر جابه‌جایی صفحه (کمی بعد، تا اسم محصول/دسته هم ثبت شده
 * باشه) صفحه‌ی فعلی فرستاده می‌شه و با رفتن اپ به پس‌زمینه، کاربر فوراً از فهرست آنلاین‌ها خارج می‌شه.
 * درخواست سبک و بدون پاسخ (api/v2/app/presence، 204)؛ خطا نادیده گرفته می‌شه.
 */
@MainActor
enum OnlinePresenceReporter {
    private static var pending: Task<Void, Never>?
    private static var lastKey: String?

    /** صفحه عوض شد (یا اپ دوباره جلو اومد) */
    static func screenChanged(force: Bool = false) {
        if ScreenshotMode.isActive { return }
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if Task.isCancelled { return }
            let screen = OnlineScreen.screenHeader()
            let title = OnlineScreen.titleHeader()
            let goftino = OnlineScreen.goftinoHeader()
            let key = "\(screen ?? "")|\(title ?? "")|\(goftino ?? "")"
            if !force && key == lastKey { return }
            lastKey = key
            await send(screen: screen, title: title, goftino: goftino, leave: false)
        }
    }

    /** اپ رفت پس‌زمینه / بسته شد */
    static func leave() {
        if ScreenshotMode.isActive { return }
        pending?.cancel()
        lastKey = nil
        Task { await send(screen: nil, title: nil, goftino: nil, leave: true) }
    }

    private static func send(screen: String?, title: String?, goftino: String?, leave: Bool) async {
        _ = try? await ApiService.sendAppPresence(
            installId: AppMetaPreferenceManager.getOrCreateInstallId(),
            appVersion: currentAppVersionName(),
            screen: screen, screenTitle: title, goftinoUserId: goftino,
            leave: leave ? "1" : nil
        )
    }
}
