import SwiftUI

// ===================================================================================
// بازطراحی: ساخت و باز کردن لینک شبکه‌های اجتماعی + کاشی‌های مشترک آن‌ها
// (سایدبار همبرگری و صفحه‌ی «تماس با ما» هر دو از همین‌ها استفاده می‌کنن تا دقیقاً یکسان باشن).
//
// مقادیر از همون Setting های سایت میان (telegram_phone، whatsapp_phone، instagram_support،
// bale_support). سایت instagram_support و bale_support رو «مستقیم» به‌عنوان href استفاده
// می‌کنه (در دیتابیس به‌صورت آدرس کامل ذخیره شدن)، پس اگه مقدار با http شروع بشه همون
// استفاده می‌شه و فقط اگه آیدیِ خالی باشه پیشوند اضافه می‌شه.
// ===================================================================================

/// رنگ‌های برند - دقیقاً همون رنگ‌هایی که سایت برای آیکن‌ها استفاده می‌کنه (WhatsappColor در MaintenanceGate.swift)
let TelegramColor = Color(argb: 0xFF00A8FF)
let InstagramColor = Color(argb: 0xFFDF155E)

enum SocialLinkBuilder {
    private static func startsWithHttp(_ v: String) -> Bool { v.lowercased().hasPrefix("http") }
    private static func removeAt(_ v: String) -> String { v.hasPrefix("@") ? String(v.dropFirst()) : v }

    static func instagramUrl(_ value: String) -> String {
        startsWithHttp(value) ? value : "https://instagram.com/\(removeAt(value))"
    }

    static func baleUrl(_ value: String) -> String {
        startsWithHttp(value) ? value : "https://ble.ir/\(removeAt(value))"
    }

    static func whatsappUrl(_ value: String) -> String {
        startsWithHttp(value) ? value : "https://wa.me/\(normalizePhone(value) ?? value)"
    }

    /// شماره‌ی ایرانی (۰۹۱۲...، +۹۸۹۱۲...، ۹۸۹۱۲...) → ۹۸۹۱۲... ؛ اگه شماره نباشه nil
    static func normalizePhone(_ value: String) -> String? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        let digits = cleaned.hasPrefix("+") ? String(cleaned.dropFirst()) : cleaned
        if digits.isEmpty || !digits.allSatisfy({ $0.isASCII && $0.isNumber }) { return nil }
        if digits.hasPrefix("00") { return String(digits.dropFirst(2)) }
        if digits.hasPrefix("0") { return "98" + digits.dropFirst() }
        return digits
    }

    /// تلگرام: چون دامنه‌ی t.me از دسترس خارج شده، اول مستقیماً خودِ اپ تلگرام با لینک
    /// داخلی tg://resolve باز می‌شه. اگه تلگرام روی گوشی نصب نباشه، آدرس telegram.org باز می‌شه.
    static func openTelegram(_ value: String) {
        let raw = value.trimmingCharacters(in: .whitespacesAndNewlines)
        // اگه مقدار یه آدرس کامل بود (t.me/… یا telegram.me/…) فقط شناسه‌ی آخرش رو برمی‌داریم
        var id = raw
        if raw.contains("/") {
            var t = raw
            while t.hasSuffix("/") { t.removeLast() }
            id = t.components(separatedBy: "/").last ?? t
        }
        let phone = normalizePhone(id)
        let appUri = phone != nil ? "tg://resolve?phone=\(phone!)" : "tg://resolve?domain=\(removeAt(id))"
        tryOpen(appUri) { opened in
            if !opened {
                tryOpen("https://telegram.org/\(phone != nil ? "+\(phone!)" : removeAt(id))")
            }
        }
    }

    static func tryOpen(_ url: String, completion: ((Bool) -> Void)? = nil) {
        guard let u = URL(string: url) else { completion?(false); return }
        UIApplication.shared.open(u, options: [:]) { ok in completion?(ok) }
    }
}

/// ردیف کاشی‌های شبکه‌های اجتماعی (تلگرام، واتساپ، اینستاگرام، بله و در صورت نیاز آپارات).
/// [aparatUrl] فقط در صفحه‌ی «تماس با ما» پاس داده می‌شه.
struct SocialChannelsRow: View {
    let social: SocialLinksResponse?
    var aparatUrl: String? = nil
    var tileColor: Color? = nil

    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 8) {
            if let telegram = social?.telegramPhone, !telegram.isBlankShk {
                SocialTile(label: "تلگرام", remixIcon: RemixIcons.TelegramFill, tint: TelegramColor, color: tileColor) {
                    SocialLinkBuilder.openTelegram(telegram)
                }
            }
            if let whatsapp = social?.whatsappPhone, !whatsapp.isBlankShk {
                SocialTile(label: "واتساپ", remixIcon: RemixIcons.WhatsappFill, tint: WhatsappColor, color: tileColor) {
                    SocialLinkBuilder.tryOpen(SocialLinkBuilder.whatsappUrl(whatsapp))
                }
            }
            if let instagram = social?.instagram, !instagram.isBlankShk {
                SocialTile(label: "اینستاگرام", remixIcon: RemixIcons.InstagramFill, tint: InstagramColor, color: tileColor) {
                    SocialLinkBuilder.tryOpen(SocialLinkBuilder.instagramUrl(instagram))
                }
            }
            if let bale = social?.baleSupport, !bale.isBlankShk {
                SocialTile(label: "بله", imageName: "ic_social_bale", color: tileColor) {
                    SocialLinkBuilder.tryOpen(SocialLinkBuilder.baleUrl(bale))
                }
            }
            if let aparatUrl {
                SocialTile(label: "آپارات", imageName: "ic_social_aparat", imageSize: 24, color: tileColor) {
                    SocialLinkBuilder.tryOpen(aparatUrl)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// کاشیِ یک شبکه‌ی اجتماعی: آیکن رسمی (Remix یا تصویر) + نام زیرش، داخل کادر
struct SocialTile: View {
    let label: String
    var remixIcon: String? = nil
    var tint: Color? = nil
    var imageName: String? = nil
    var imageSize: CGFloat = 22
    var color: Color? = nil
    let onClick: () -> Void

    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 0) {
                ZStack {
                    if let remixIcon {
                        RemixIcon(remixIcon, contentDescription: label, tint: tint, size: 26)
                    } else if let imageName {
                        Image(uiImage: UIImage(named: imageName) ?? UIImage())
                            .resizable().scaledToFit()
                            .frame(width: imageSize, height: imageSize)
                            .accessibilityLabel(label)
                    }
                }
                .frame(width: 26, height: 26)
                Spacer().frame(height: 4)
                Text(label)
                    .shkFont(10, lineHeight: 14)
                    .foregroundColor(colors.onSurfaceVariant)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color ?? colors.surface))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(SitePressStyle())
    }
}
