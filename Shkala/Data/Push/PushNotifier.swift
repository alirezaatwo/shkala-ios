import Foundation
import SwiftUI
import UserNotifications

/**
 * معادل data/push/PushNotifier.kt: نمایش اعلان‌های اپ در مرکز اعلان گوشی (بدون FCM/APNs - اعلان‌ها رو خود اپ از
 * سایت می‌گیره و به‌صورت اعلان محلی نشون می‌ده). لمس اعلان (یا دکمه‌ی «مشاهده») اپ رو باز می‌کنه؛ کلیک به سرور
 * گزارش می‌شه و صفحه‌ی محصول / لینک داخل اپ باز می‌شه.
 * تفاوت‌های اجباری iOS: کانال اعلان، آیکن کوچک و رنگ برند در iOS وجود نداره (آیکن خود اپ نمایش داده می‌شه)؛
 * تصویر بزرگ به‌صورت پیوست اعلان (با کشیدن/نگه داشتن اعلان بزرگ می‌شه).
 */
enum PushNotifier {
    static let CATEGORY_ID = "shkala_store_notifications"
    private static let ACTION_VIEW = "shkala_push_view"

    // اطلاعات اعلان در userInfo
    static let EXTRA_PUSH_ID = "shkala_push_id"
    static let EXTRA_PRODUCT_ID = "shkala_push_product_id"
    static let EXTRA_PRODUCT_SLUG = "shkala_push_product_slug"
    static let EXTRA_LINK = "shkala_push_link"

    // دانلود تصویر بزرگ اعلان: حداکثر ~۱۰ ثانیه، حداکثر ۱٫۵ مگابایت
    private static let IMAGE_TIMEOUT: TimeInterval = 10
    private static let IMAGE_MAX_BYTES = 1_500_000

    /// ثبت دسته‌ی اعلان با دکمه‌ی «مشاهده» و delegate (از شروع اپ)
    static func setup() {
        let center = UNUserNotificationCenter.current()
        let view = UNNotificationAction(identifier: ACTION_VIEW, title: "مشاهده", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: CATEGORY_ID, actions: [view], intentIdentifiers: [], options: []),
        ])
        center.delegate = PushNotificationDelegate.shared
    }

    /// اجازه‌ی نمایش اعلان داریم؟
    static func canNotify() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    /// نمایش یک اعلان؛ false = اجازه‌ی نمایش نیست (یا خطا)
    static func show(_ item: PushNotificationDto) async -> Bool {
        guard await canNotify() else { return false }
        let content = UNMutableNotificationContent()
        content.title = item.title.flatMap { $0.isBlankShk ? nil : $0 } ?? "shkala"
        content.body = item.body ?? ""
        content.sound = .default
        content.categoryIdentifier = CATEGORY_ID
        var info: [String: Any] = [EXTRA_PUSH_ID: NSNumber(value: item.id)]
        if let productId = item.productId { info[EXTRA_PRODUCT_ID] = NSNumber(value: productId) }
        if let slug = item.productSlug, !slug.isBlankShk { info[EXTRA_PRODUCT_SLUG] = slug }
        if let link = item.link, !link.isBlankShk { info[EXTRA_LINK] = link }
        content.userInfo = info
        if let imageUrl = item.imageUrl, !imageUrl.isBlankShk, let attachment = await downloadAttachment(imageUrl, id: item.id) {
            content.attachments = [attachment]
        }
        let request = UNNotificationRequest(identifier: "shkala_push_\(item.id)", content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    /// دانلود تصویر بزرگ اعلان در یک فایل موقت (null = نشد: آدرس غیر https، خطای شبکه، حجم زیاد یا تصویر نامعتبر)
    private static func downloadAttachment(_ url: String, id: Int64) async -> UNNotificationAttachment? {
        guard url.lowercased().hasPrefix("https://"), let remote = URL(string: url) else { return nil }
        var request = URLRequest(url: remote, timeoutInterval: IMAGE_TIMEOUT)
        request.setValue("image/webp,image/*;q=0.8", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              !data.isEmpty, data.count <= IMAGE_MAX_BYTES,
              let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.9) else { return nil }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("shkala_push_\(id)_\(UUID().uuidString).jpg")
        guard (try? jpeg.write(to: file)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "image", url: file, options: nil)
    }

    /// اطلاعات اعلانِ داخل userInfo (null = این اعلان از اپ نیومده)
    static func openRequest(from info: [AnyHashable: Any]) -> PushOpenRequest? {
        let id = (info[EXTRA_PUSH_ID] as? NSNumber)?.int64Value ?? 0
        guard id > 0 else { return nil }
        let productId = (info[EXTRA_PRODUCT_ID] as? NSNumber)?.int64Value
        return PushOpenRequest(
            notificationId: id,
            productId: productId.flatMap { $0 > 0 ? $0 : nil },
            productSlug: (info[EXTRA_PRODUCT_SLUG] as? String).flatMap { $0.isBlankShk ? nil : $0 },
            link: (info[EXTRA_LINK] as? String).flatMap { $0.isBlankShk ? nil : $0 }
        )
    }
}

/// درخواست باز کردن یک اعلان داخل اپ (معادل PushOpenRequest - از لمس اعلان به AppRoot)
struct PushOpenRequest: Equatable {
    let notificationId: Int64
    let productId: Int64?
    let productSlug: String?
    let link: String?
}

/// اعلانی که کاربر لمس کرده و هنوز داخل اپ باز نشده (معادل pushOpenState اکتیویتی اندروید)
@MainActor
final class PushOpenCenter: ObservableObject {
    static let shared = PushOpenCenter()
    @Published var pending: PushOpenRequest? = nil
}

/// لمس اعلان و نمایش اعلان وقتی اپ بازه (اندروید همیشه اعلان رو در نوار اعلان نشون می‌ده)
final class PushNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let request = PushNotifier.openRequest(from: response.notification.request.content.userInfo) {
            PushSync.reportClick(request.notificationId)
            Task { @MainActor in PushOpenCenter.shared.pending = request }
        }
        completionHandler()
    }
}
