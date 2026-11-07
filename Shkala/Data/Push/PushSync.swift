import Foundation
import BackgroundTasks

/**
 * معادل data/push/PushSync.kt: گرفتن اعلان‌های جدید از سایت (بدون FCM / APNs):
 *  - after_id = آخرین شناسه‌ی دیده‌شده؛ سرور فقط اعلان‌های مخصوص همین نصب رو می‌ده و برای نصب تازه فقط
 *    اعلان‌های ساخته‌شده از یک روز قبل از اولین اجرای اپ به بعد (قانون سمت سرور)
 *  - هر اعلان نمایش داده می‌شه و «دریافت» به سرور گزارش می‌شه
 *  - بعد از پردازش، latest_id سرور به‌عنوان آخرین شناسه ذخیره می‌شه
 * از سه جا صدا زده می‌شه: بررسی پس‌زمینه‌ی سیستم (BGAppRefresh)، شروع اپ / برگشتن اپ به جلو، و وقتی پرسش
 * دوره‌ای وضعیت اپ (هر ۱۵ ثانیه در حالت باز) شناسه‌ی جدیدتری گزارش کنه.
 * تفاوت اجباری iOS: اندروید هر ۱۵ دقیقه با JobScheduler بررسی می‌کنه؛ در iOS زمان اجرای بررسی پس‌زمینه کاملاً
 * دست سیستم‌عامله (ممکنه ساعت‌ها عقب بیفته یا اگه کاربر اپ رو از لیست برنامه‌ها ببنده، اجرا نشه). وقتی اپ بازه،
 * اعلان‌ها مثل اندروید تقریباً فوری از پرسش وضعیت اپ گرفته می‌شن.
 */
actor PushSync {
    static let shared = PushSync()

    /// شناسه‌ی بررسی پس‌زمینه (BGTaskSchedulerPermittedIdentifiers در Info.plist)
    static let BACKGROUND_TASK_ID = "com.shkala.app.push-refresh"

    // جلوگیری از پرسش‌های پشت‌سرهم (مثلاً برگشتن مکرر اپ به جلو)
    private static let MIN_INTERVAL_MS: Int64 = 20_000

    private var lastCheckAt: Int64 = 0
    private var running = false

    /// بررسی در پس‌زمینه (fire-and-forget)؛ [force] = بدون محدودیت فاصله‌ی زمانی
    static func checkNow(force: Bool = false) {
        Task.detached(priority: .utility) { await shared.checkIfDue(force: force) }
    }

    private func checkIfDue(force: Bool) async {
        let now = nowMs()
        if !force && now - lastCheckAt < Self.MIN_INTERVAL_MS { return }
        lastCheckAt = now
        _ = await sync()
    }

    /// پرسش وضعیت اپ شناسه‌ی جدیدتری گزارش کرد؟ (فقط اگه از آخرین شناسه‌ی دیده‌شده بزرگ‌تر باشه)
    static func onLatestIdFromStatus(_ latestId: Int64?) {
        guard let latestId, latestId > 0 else { return }
        Task.detached(priority: .utility) {
            if latestId > AppMetaPreferenceManager.getLastPushId() {
                await shared.markChecked()
                _ = await shared.sync()
            }
        }
    }

    private func markChecked() { lastCheckAt = nowMs() }

    /// یک دور کامل گرفتن/نمایش/گزارش؛ false = خطای شبکه یا سرور (یا دور دیگه‌ای در جریانه)
    func sync() async -> Bool {
        if ScreenshotMode.isActive { return true }
        // معادل mutex: پرسش‌های هم‌زمان پشت هم اجرا نمی‌شن (دور دوم همین‌جا رد می‌شه)
        if running { return true }
        running = true
        defer { running = false }

        let installId = AppMetaPreferenceManager.getOrCreateInstallId()
        let afterId = AppMetaPreferenceManager.getLastPushId()
        guard let response = try? await ApiService.getAppNotifications(afterId: afterId, installId: installId),
              response.isSuccessful, let body = response.body else { return false }

        var maxProcessed = afterId
        for item in (body.notifications ?? []).sorted(by: { $0.id < $1.id }) {
            if item.id <= afterId { continue }
            let shown = await PushNotifier.show(item)
            if shown {
                _ = try? await ApiService.markAppNotificationReceived(id: item.id, PushEventRequest(installId: installId))
            }
            if item.id > maxProcessed { maxProcessed = item.id }
        }
        // latest_id سرور (بزرگ‌ترین شناسه در لحظه‌ی پرسش) - اعلان‌های دیگرانِ (آزمایشی) دوباره پرسیده نمی‌شن
        let newLast = max(maxProcessed, body.latestId ?? 0)
        if newLast > afterId { AppMetaPreferenceManager.setLastPushId(newLast) }
        return true
    }

    /// گزارش کلیک روی اعلان (fire-and-forget)
    static func reportClick(_ notificationId: Int64) {
        Task.detached(priority: .utility) {
            let installId = AppMetaPreferenceManager.getOrCreateInstallId()
            _ = try? await ApiService.markAppNotificationClicked(id: notificationId, PushEventRequest(installId: installId))
        }
    }

    /// زمان‌بندی بررسی پس‌زمینه‌ی بعدی (معادل PushWorker.schedule - حداقل ۱۵ دقیقه‌ی بعد)
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BACKGROUND_TASK_ID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
