import Foundation

// معادل بخش «نسخه‌ی اپ / heartbeat / گزارش خطا» از dto/AppStatusDto.kt و dto/PushDto.kt اپ اندروید - همان کلیدها.
// تفاوت اجباری iOS: android_sdk ارسال نمی‌شه؛ نسخه‌ی iOS داخل device_model میاد (مثل «iPhone15,2 (iOS 17.5)»)
// و installer = «ios» (سرور این نصب‌ها رو در آمار با منبع «آیفون (iOS)» نشون می‌ده).

/// آخرین نسخه‌ی منتشرشده (api/v2/app/latest-version) - اپ iOS با هدر X-Shk-Platform: ios نسخه‌ی iOS رو می‌گیره
struct AppLatestVersionResponse: ShkDTO {
    var status: String? = nil
    var available: Bool = false
    var versionName: String? = nil
    var url: String? = nil
    var sizeBytes: Int64? = nil
    var notes: String? = nil
    // خطوط «امکانات جدید» (notes خط‌به‌خط)
    var releaseNotes: [String]? = nil
    // راه‌های دریافت iOS: سیب‌اپ، سیب من، سیبچه
    var stores: AppStoresDto? = nil
    // بروزرسانی اجباری: اپ با نسخه‌ی پایین‌تر از min_version پنجره‌ی بروزرسانی غیرقابل‌بستن نشان می‌دهد
    var forceUpdate: Bool? = nil
    var minVersion: String? = nil

    enum CodingKeys: String, CodingKey {
        case status, available, url, notes, stores
        case versionName = "version_name"
        case sizeBytes = "size_bytes"
        case releaseNotes = "release_notes"
        case forceUpdate = "force_update"
        case minVersion = "min_version"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        available = c.lenientBool(.available) ?? false
        versionName = c.lenientString(.versionName)
        url = c.lenientString(.url)
        sizeBytes = c.lenientInt64(.sizeBytes)
        notes = c.lenientString(.notes)
        releaseNotes = try? c.decodeIfPresent([String?].self, forKey: .releaseNotes)?.compactMap { $0 }
        stores = try? c.decodeIfPresent(AppStoresDto.self, forKey: .stores)
        forceUpdate = c.lenientBool(.forceUpdate)
        minVersion = c.lenientString(.minVersion)
    }
}

struct AppStoresDto: ShkDTO {
    var sibapp: AppStoreLinkDto? = nil
    var sibeman: AppStoreLinkDto? = nil
    var sibche: AppStoreLinkDto? = nil

    enum CodingKeys: String, CodingKey { case sibapp, sibeman, sibche }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sibapp = try? c.decodeIfPresent(AppStoreLinkDto.self, forKey: .sibapp)
        sibeman = try? c.decodeIfPresent(AppStoreLinkDto.self, forKey: .sibeman)
        sibche = try? c.decodeIfPresent(AppStoreLinkDto.self, forKey: .sibche)
    }
}

/// یک راه دریافت؛ دکمه‌اش فقط وقتی نمایش داده می‌شه که enabled باشه و url داشته باشه
struct AppStoreLinkDto: ShkDTO {
    var enabled: Bool? = nil
    var url: String? = nil

    enum CodingKeys: String, CodingKey { case enabled, url }

    init(enabled: Bool? = nil, url: String? = nil) {
        self.enabled = enabled
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = c.lenientBool(.enabled)
        url = c.lenientString(.url)
    }

    var usableUrl: String? {
        guard enabled == true, let url, !url.isBlankShk else { return nil }
        return url
    }
}

// ---- گزارش حضور (heartbeat) و گزارش خطاهای اپ ----

struct AppHeartbeatRequest: Encodable {
    let installId: String
    let deviceKey: String?
    let appVersion: String
    let versionCode: Int64
    let deviceModel: String
    let installer: String?

    enum CodingKeys: String, CodingKey {
        case installer
        case installId = "install_id"
        case deviceKey = "device_key"
        case appVersion = "app_version"
        case versionCode = "version_code"
        case deviceModel = "device_model"
    }
}

struct AppErrorsUploadRequest: Encodable {
    let installId: String
    let appVersion: String
    let deviceModel: String
    let errors: [AppErrorItemDto]

    enum CodingKeys: String, CodingKey {
        case errors
        case installId = "install_id"
        case appVersion = "app_version"
        case deviceModel = "device_model"
    }
}

/// یک خطای ثبت‌شده. type: crash | api | error - occurred_at به ثانیه (unix)
struct AppErrorItemDto: Codable {
    let type: String
    let message: String
    var stacktrace: String? = nil
    var screen: String? = nil
    var endpoint: String? = nil
    var httpCode: Int? = nil
    let occurredAt: Int64

    enum CodingKeys: String, CodingKey {
        case type, message, stacktrace, screen, endpoint
        case httpCode = "http_code"
        case occurredAt = "occurred_at"
    }
}

struct AppTelemetryResponse: ShkDTO {
    var status: String? = nil
    var stored: Int? = nil

    enum CodingKeys: String, CodingKey { case status, stored }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        stored = c.lenientInt(.stored)
    }
}

// ---- اعلان‌های اپ بدون FCM (معادل dto/PushDto.kt) ----

/**
 * GET api/v2/app/notifications?after_id=...: اعلان‌های جدیدتر از آخرین شناسه‌ای که اپ دیده (حداکثر ۵ مورد،
 * قدیمی ← جدید) + [latestId] = بزرگ‌ترین شناسه‌ی اعلان سرور در لحظه‌ی پرسش (بعد از پردازش ذخیره می‌شه)
 */
struct PushNotificationsResponse: ShkDTO {
    var notifications: [PushNotificationDto]? = nil
    var latestId: Int64? = nil

    enum CodingKeys: String, CodingKey {
        case notifications
        case latestId = "latest_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notifications = try? c.decodeIfPresent([PushNotificationDto].self, forKey: .notifications)
        latestId = c.lenientInt64(.latestId)
    }
}

struct PushNotificationDto: ShkDTO {
    var id: Int64 = 0
    // شماره‌ی خوانای اعلان مثل N-1001
    var code: String? = nil
    var title: String? = nil
    var body: String? = nil
    var productId: Int64? = nil
    // کلید افزوده‌ی سرور: صفحه‌ی محصول اپ با slug باز می‌شه
    var productSlug: String? = nil
    // لینک مقاله/دسته‌بندی/برند سایت (وقتی محصول انتخاب نشده)
    var link: String? = nil
    // تصویر بزرگ اعلان (https)؛ null = اعلان متنی
    var imageUrl: String? = nil
    var createdAt: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, code, title, body, link
        case productId = "product_id"
        case productSlug = "product_slug"
        case imageUrl = "image_url"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt64(.id) ?? 0
        code = c.lenientString(.code)
        title = c.lenientString(.title)
        body = c.lenientString(.body)
        productId = c.lenientInt64(.productId)
        productSlug = c.lenientString(.productSlug)
        link = c.lenientString(.link)
        imageUrl = c.lenientString(.imageUrl)
        createdAt = c.lenientString(.createdAt)
    }
}

/// بدنه‌ی POST .../notifications/{id}/received و /clicked
struct PushEventRequest: Encodable {
    let installId: String

    enum CodingKeys: String, CodingKey { case installId = "install_id" }
}
