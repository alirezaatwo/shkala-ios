import Foundation

/**
 * معادل data/telemetry/AppTelemetry.kt: کارهای پس‌زمینه‌ی شروع اپ: گزارش حضور (heartbeat)، بررسی اعلان‌های جدید
 * و بعد ارسال صف گزارش خطاها. یک‌بار در هر اجرای اپ، بعد از پایان بارگذاری اولیه (اسپلش)؛ کاملاً در پس‌زمینه،
 * بدون معطل کردن رابط کاربری و با نادیده گرفتن همه‌ی خطاها.
 */
enum AppTelemetry {
    private static let lock = NSLock()
    private static var started = false

    static func onStartupCompleted() {
        lock.lock()
        if started { lock.unlock(); return }
        started = true
        lock.unlock()
        if ScreenshotMode.isActive { return }
        Task.detached(priority: .utility) {
            await sendHeartbeat()
            // اعلان‌های اپ: یک بررسی فوری بعد از شروع (بعد از heartbeat تا نصب در سرور ثبت شده باشه)
            _ = await PushSync.shared.sync()
            await ErrorReporter.uploadPending()
        }
    }

    private static func sendHeartbeat() async {
        // شبیه‌ساز در آمار نصب سایت ثبت نمی‌شه
        if AppDeviceInfo.isSimulator { return }
        // UIDevice فقط روی رشته‌ی اصلی
        let body = await MainActor.run {
            AppHeartbeatRequest(
                installId: AppMetaPreferenceManager.getOrCreateInstallId(),
                deviceKey: AppDeviceInfo.deviceKey(),
                appVersion: AppDeviceInfo.versionName(),
                versionCode: AppDeviceInfo.versionCode(),
                deviceModel: AppDeviceInfo.deviceModel(),
                installer: AppDeviceInfo.INSTALLER
            )
        }
        _ = try? await ApiService.sendAppHeartbeat(body)
    }
}
