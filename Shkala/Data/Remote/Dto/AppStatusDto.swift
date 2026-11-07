import Foundation

// معادل dto/AppStatusDto.kt اپ اندروید - همان کلیدها (فقط بخش‌هایی که اپ iOS مصرف می‌کنه؛
// گزارش حضور/خطا و نسخه‌ی APK در مراحل بعد اضافه می‌شن).

/// وضعیت «در حال بروزرسانی / غیرفعال»: بروزرسانی سایت (تنظیم maintenance خودِ اسکریپت)
struct AppStatusResponse: ShkDTO {
    var status: String? = nil
    var maintenance: Bool = false
    var maintenanceTitle: String? = nil
    // قابل تنظیم (خالی = مقدار پیش‌فرض اپ)
    var maintenanceDescription: String? = nil
    // زمان پایان بروزرسانی (ISO8601 به وقت UTC، مثل 2026-10-02T11:00:00Z)؛ null = بدون شمارش معکوس
    var maintenanceEndsAt: String? = nil
    // ساعت سرور (ISO8601 UTC) برای اصلاح اختلاف ساعت گوشی در شمارش معکوس
    var serverTime: String? = nil
    var contacts: AppContactsDto? = nil
    // پاپ‌آپ تبلیغاتی صفحه‌ی اصلی (null = پاپ‌آپ فعالی برای اپ نیست)
    var popup: AppPopupDto? = nil
    // پاپ‌آپ فعالی برای اپ هست؟ true = پاپ‌آپ‌های هر صفحه از api/v2/popups گرفته می‌شن
    var popupsLive: Bool? = nil
    // نوار اطلاعیه (null = اطلاعیه‌ی فعالی نیست)
    var announcement: AppAnnouncementDto? = nil
    // بزرگ‌ترین شناسه‌ی اعلان اپ در سرور
    var latestNotificationId: Int64? = nil

    enum CodingKeys: String, CodingKey {
        case status, maintenance, contacts, popup, announcement
        case maintenanceTitle = "maintenance_title"
        case maintenanceDescription = "maintenance_description"
        case maintenanceEndsAt = "maintenance_ends_at"
        case serverTime = "server_time"
        case popupsLive = "popups_live"
        case latestNotificationId = "latest_notification_id"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        maintenance = c.lenientBool(.maintenance) ?? false
        maintenanceTitle = c.lenientString(.maintenanceTitle)
        maintenanceDescription = c.lenientString(.maintenanceDescription)
        maintenanceEndsAt = c.lenientString(.maintenanceEndsAt)
        serverTime = c.lenientString(.serverTime)
        contacts = try c.decodeIfPresent(AppContactsDto.self, forKey: .contacts)
        popup = try? c.decodeIfPresent(AppPopupDto.self, forKey: .popup)
        popupsLive = c.lenientBool(.popupsLive)
        announcement = try? c.decodeIfPresent(AppAnnouncementDto.self, forKey: .announcement)
        latestNotificationId = c.lenientInt64(.latestNotificationId)
    }
}

/// پاپ‌آپ تبلیغاتی اپ. [id] وقتی تصویر/لینک/تنظیمات عوض بشه تغییر می‌کنه (برای «یک‌بار نمایش»).
/// [frequency]: once | daily | always
struct AppPopupDto: ShkDTO {
    let id: String?
    let pid: Int64?
    let trigger: String?
    let scroll: Int?
    let device: String?
    let imageUrl: String?
    let link: String?
    let frequency: String?
    let layout: String?
    let imageSide: String?
    let imageMobile: String?
    let width: Int?
    let delay: Int?
    let style: AppPopupStyleDto?
    let themeColor: String?
    let blocks: [AppPopupBlockDto]?

    enum CodingKeys: String, CodingKey {
        case id, pid, trigger, scroll, device, link, frequency, layout, width, delay, style, blocks
        case imageUrl = "image_url"
        case imageSide = "image_side"
        case imageMobile = "image_mobile"
        case themeColor = "theme_color"
    }
}

/// ظاهر پاپ‌آپ؛ رنگ خالی = رنگ پیش‌فرض (روز/شب)
struct AppPopupStyleDto: ShkDTO {
    let bg: String?
    let text: String?
    let accent: String?
    let accentText: String?
    let radius: Int?
    let overlay: Int?
    let padding: Int?
    let align: String?

    enum CodingKeys: String, CodingKey {
        case bg, text, accent, radius, overlay, padding, align
        case accentText = "accent_text"
    }
}

/// یک بلوک پاپ‌آپ. type: heading | text | image | button | coupon | countdown | newsletter | form | spacer | divider
struct AppPopupBlockDto: ShkDTO {
    let type: String?
    let key: String?
    let text: String?
    let size: Int?
    let imageUrl: String?
    let link: String?
    let maxHeight: Int?
    let variant: String?
    let full: Bool?
    let close: Bool?
    let code: String?
    let label: String?
    let endsTs: Int64?
    let accept: String?
    let placeholder: String?
    let button: String?
    let success: String?
    let height: Int?
    let showTitle: Bool?
    let form: AppPopupFormDto?

    enum CodingKeys: String, CodingKey {
        case type, key, text, size, link, variant, full, close, code, label, accept, placeholder, button, success, height, form
        case imageUrl = "image_url"
        case maxHeight = "max_height"
        case endsTs = "ends_ts"
        case showTitle = "show_title"
    }
}

/// فرم دلخواه پاپ‌آپ
struct AppPopupFormDto: ShkDTO {
    let id: Int?
    let slug: String?
    let title: String?
    let fields: [AppPopupFormFieldDto]?
}

/// type: text | textarea | email | checkbox | radio | select - status: necessary | optional
struct AppPopupFormFieldDto: ShkDTO {
    let id: String?
    let title: String?
    let type: String?
    let status: String?
    let options: [String]?
}

/// اطلاعیه‌ی متحرک بالای صفحه + صفحه‌ی جزئیات آن. [id] با تغییر متن/توضیحات عوض می‌شه
struct AppAnnouncementDto: ShkDTO {
    let id: String?
    let text: String?
    let title: String?
    let descriptionHtml: String?
    let buttonText: String?
    // جایگاه نوار در صفحه‌ی اصلی - "above_header" = بالای هدر؛ هر مقدار دیگه = زیر هدر
    let position: String?

    enum CodingKeys: String, CodingKey {
        case id, text, title, position
        case descriptionHtml = "description_html"
        case buttonText = "button_text"
    }
}

/// راه‌های ارتباطی صفحه‌ی «در حال بروزرسانی» (null = اون دکمه نمایش داده نمی‌شه)
struct AppContactsDto: ShkDTO {
    var mobile1: String? = nil
    var mobile2: String? = nil
    var landline: String? = nil
    var whatsappUrl: String? = nil
    var baleUrl: String? = nil

    enum CodingKeys: String, CodingKey {
        case landline
        case mobile1 = "mobile_1"
        case mobile2 = "mobile_2"
        case whatsappUrl = "whatsapp_url"
        case baleUrl = "bale_url"
    }

    init(mobile1: String? = nil, mobile2: String? = nil, landline: String? = nil, whatsappUrl: String? = nil, baleUrl: String? = nil) {
        self.mobile1 = mobile1
        self.mobile2 = mobile2
        self.landline = landline
        self.whatsappUrl = whatsappUrl
        self.baleUrl = baleUrl
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mobile1 = c.lenientString(.mobile1)
        mobile2 = c.lenientString(.mobile2)
        landline = c.lenientString(.landline)
        whatsappUrl = c.lenientString(.whatsappUrl)
        baleUrl = c.lenientString(.baleUrl)
    }
}
