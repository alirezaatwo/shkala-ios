import Foundation
import UIKit
import CryptoKit

/**
 * معادل data/telemetry/AppDeviceInfo.kt: اطلاعات دستگاه و نصب اپ که در heartbeat، گزارش خطا و مودال بروزرسانی
 * استفاده می‌شه.
 * تفاوت‌های اجباری iOS:
 *  - منبع نصب (سیب‌اپ / سیب من / سیبچه) در iOS قابل تشخیص نیست (فروشگاه‌ها اپ رو دوباره امضا می‌کنن)؛ installer = «ios»
 *  - device_key = sha256 از identifierForVendor (معادل ANDROID_ID؛ خودِ شناسه ارسال نمی‌شه)
 *  - android_sdk نداریم؛ نسخه‌ی iOS در device_model میاد
 */
@MainActor
enum AppDeviceInfo {
    /// installer اپ iOS (سرور: منبع «آیفون (iOS)»)
    nonisolated static let INSTALLER = "ios"

    /// معادل AppDeviceInfo.isEmulator() اندروید: اجرای اپ روی شبیه‌ساز (Xcode یا CI گیت‌هاب برای عکس صفحه‌ها) -
    /// در این حالت heartbeat فرستاده نمی‌شه تا در آمار نصب سایت ثبت نشه (سرور هم مدل arm64/x86_64 رو رد می‌کنه).
    nonisolated static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// sha256 (hex) از identifierForVendor - بین اجراهای اپ ثابته
    static func deviceKey() -> String? {
        guard let id = UIDevice.current.identifierForVendor?.uuidString, !id.isEmpty else { return nil }
        return SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// مدل سخت‌افزار (مثل iPhone15,2) + نسخه‌ی iOS: «iPhone15,2 (iOS 17.5)»
    static func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        let machine = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) { String(cString: $0) }
        }
        let model = machine.trimmingCharacters(in: .whitespaces).isEmpty ? UIDevice.current.model : machine
        return "\(model) (iOS \(UIDevice.current.systemVersion))".prefix(120).description
    }

    nonisolated static func versionName() -> String { currentAppVersionName() }

    nonisolated static func versionCode() -> Int64 {
        Int64(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }
}
