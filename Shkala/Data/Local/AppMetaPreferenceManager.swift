import Foundation

/// معادل AppMetaPreferenceManager اپ اندروید: اطلاعات دائمی نصب اپ.
///  - شناسه‌ی نصب (UUID که یک‌بار ساخته می‌شه و تا حذف اپ ثابت می‌مونه)
///  - رضایت کاربر برای ارسال گزارش خطاها (null = هنوز جواب نداده)
///  - آخرین نسخه‌ای که سؤال رضایت در اون پرسیده شده
///  - سابقه‌ی نمایش پاپ‌آپ تبلیغاتی (برای تناوب «یک‌بار» و «روزی یک‌بار»)
///  - اعلان‌های اپ: آخرین شناسه‌ی اعلانِ دیده‌شده و اینکه اجازه‌ی نمایش اعلان پرسیده شده یا نه
enum AppMetaPreferenceManager {
    private enum Keys {
        static let INSTALL_ID = "shkala_app_meta.install_id"
        static let ERROR_REPORT_CONSENT = "shkala_app_meta.error_report_consent"
        static let CONSENT_PROMPTED_VERSION = "shkala_app_meta.consent_prompted_version"
        static let POPUP_SHOWN_ONCE_IDS = "shkala_app_meta.popup_shown_once_ids"
        static let POPUP_SHOWN_DAILY = "shkala_app_meta.popup_shown_daily"
        static let LAST_PUSH_ID = "shkala_app_meta.last_push_id"
        static let NOTIFICATION_PERMISSION_ASKED = "shkala_app_meta.notification_permission_asked"
    }

    private static let defaults = UserDefaults.standard
    // جلوگیری از ساخته شدن دو شناسه‌ی متفاوت در دو فراخوانی هم‌زمان
    private static let installIdLock = NSLock()

    /// آخرین شناسه‌ی نصبِ خونده‌شده (در حافظه) - برای هدر X-Shk-Install همه‌ی درخواست‌ها
    private(set) static var cachedInstallId: String? = nil

    /// شناسه‌ی نصب؛ اگه هنوز ساخته نشده، همین‌جا ساخته و ذخیره می‌شه
    @discardableResult
    static func getOrCreateInstallId() -> String {
        installIdLock.lock(); defer { installIdLock.unlock() }
        if let existing = defaults.string(forKey: Keys.INSTALL_ID), !existing.isEmpty {
            cachedInstallId = existing
            return existing
        }
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: Keys.INSTALL_ID)
        cachedInstallId = created
        return created
    }

    /// آخرین شناسه‌ی اعلان اپ که پردازش شده (۰ = هنوز هیچ)
    static func getLastPushId() -> Int64 { Int64(defaults.integer(forKey: Keys.LAST_PUSH_ID)) }

    /// فقط رو به جلو (هیچ‌وقت کوچک‌تر نمی‌شه)
    static func setLastPushId(_ id: Int64) {
        if id > getLastPushId() { defaults.set(Int(id), forKey: Keys.LAST_PUSH_ID) }
    }

    static func wasNotificationPermissionAsked() -> Bool { defaults.bool(forKey: Keys.NOTIFICATION_PERMISSION_ASKED) }
    static func markNotificationPermissionAsked() { defaults.set(true, forKey: Keys.NOTIFICATION_PERMISSION_ASKED) }

    /// null = کاربر هنوز انتخاب نکرده (پیش‌فرض: بدون رضایت)
    static func getErrorReportConsent() -> Bool? { defaults.object(forKey: Keys.ERROR_REPORT_CONSENT) as? Bool }
    static func setErrorReportConsent(_ consented: Bool) { defaults.set(consented, forKey: Keys.ERROR_REPORT_CONSENT) }

    static func getConsentPromptedVersion() -> String? { defaults.string(forKey: Keys.CONSENT_PROMPTED_VERSION) }
    static func setConsentPromptedVersion(_ version: String) { defaults.set(version, forKey: Keys.CONSENT_PROMPTED_VERSION) }

    /// آیا پاپ‌آپ با تناوب once قبلاً (برای همین شناسه) نمایش داده شده؟
    static func wasPopupShownOnce(_ popupId: String) -> Bool {
        (defaults.stringArray(forKey: Keys.POPUP_SHOWN_ONCE_IDS) ?? []).contains(popupId)
    }

    static func markPopupShownOnce(_ popupId: String) {
        // فقط ۳۰ شناسه‌ی آخر (جلوگیری از بزرگ شدن بی‌دلیل)
        let current = (defaults.stringArray(forKey: Keys.POPUP_SHOWN_ONCE_IDS) ?? []).filter { $0 != popupId }.suffix(29)
        defaults.set(Array(current) + [popupId], forKey: Keys.POPUP_SHOWN_ONCE_IDS)
    }

    /// آیا پاپ‌آپ روزانه امروز ([day] = yyyy-MM-dd) برای همین شناسه نمایش داده شده؟
    static func wasPopupShownOnDay(_ popupId: String, day: String) -> Bool {
        (defaults.stringArray(forKey: Keys.POPUP_SHOWN_DAILY) ?? []).contains("\(day)|\(popupId)")
    }

    static func markPopupShownOnDay(_ popupId: String, day: String) {
        // ورودی‌های روزهای قبل دیگه لازم نیستن
        let today = (defaults.stringArray(forKey: Keys.POPUP_SHOWN_DAILY) ?? []).filter { $0.hasPrefix("\(day)|") }
        defaults.set(Array(Set(today + ["\(day)|\(popupId)"])), forKey: Keys.POPUP_SHOWN_DAILY)
    }
}
