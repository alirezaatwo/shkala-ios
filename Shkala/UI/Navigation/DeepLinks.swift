import Foundation

/**
 * معادل pendingDeepLink اپ اندروید (MainActivity ← AppRoot):
 * لینکی که از بیرون اپ (پیامک/تلگرام/دکمه‌ی «باز کردن در اپ» سایت) اپ رو باز کرده.
 * تا وقتی صفحه‌ی اصلی اپ (بعد از اسپلش/اینترو) بالا نیومده نگه داشته می‌شه.
 *
 * تفاوت اجباری iOS: لینک‌های https سایت (Universal Link) فقط وقتی به اپ می‌رسن که امضای اپ
 * Associated Domains داشته باشه و فایل apple-app-site-association سایت شناسه‌ی همون امضا رو بشناسه؛
 * لینک shkala://open همیشه کار می‌کنه.
 */
final class DeepLinkCenter: ObservableObject {
    static let shared = DeepLinkCenter()
    @Published var pending: URL? = nil
}

extension AppNavigator {
    private static let siteHosts: Set<String> = ["shkala.com", "www.shkala.com", "shkcctv.com", "www.shkcctv.com"]

    /// وقتی کاربر از بیرون اپ رو یه آدرس سایت کلیک می‌کنه، اینجا تشخیص می‌دیم دقیقاً باید کدوم صفحه‌ی اپ باز بشه
    func handleDeepLink(_ rawUri: URL) {
        // دکمه‌ی «باز کردن در اپ» سایت (shkala://open?url=آدرس صفحه): محصول، برند، دسته‌بندی و مقاله
        // در صفحه‌ی متناظر اپ باز می‌شن؛ بقیه‌ی صفحه‌ها فقط اپ رو (صفحه‌ی اصلی) باز می‌کنن
        if rawUri.scheme?.lowercased() == "shkala" {
            let target = (URLComponents(url: rawUri, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "url" })?.value ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let targetComponents = URLComponents(string: target)
            let targetHost = targetComponents?.host?.lowercased()
            let targetPath = targetComponents?.path ?? ""
            let isSite = targetHost.map { Self.siteHosts.contains($0) } ?? false
            let hasCategory = !(targetComponents?.queryItems?.first(where: { $0.name == "cat" })?.value?.isBlankShk ?? true)
            let trimmed = targetPath.hasSuffix("/") ? String(targetPath.dropLast()) : targetPath
            if isSite && (
                targetPath.hasPrefix("/product/") ||
                    targetPath.hasPrefix("/brand/") ||
                    targetPath.hasPrefix("/blog/article/") ||
                    trimmed == "/tools" || trimmed == "/tools/hdd-calculator" ||
                    (targetPath.hasPrefix("/products") && hasCategory)
            ) {
                openAppLink(target)
            }
            return
        }
        // لینک‌های دامنه‌ی قدیمی (shkcctv.com / www.shkcctv.com) به shkala.com تبدیل می‌شن
        var components = URLComponents(url: rawUri, resolvingAgainstBaseURL: false)
        let rawHost = rawUri.host?.lowercased()
        if rawHost == "shkcctv.com" || rawHost == "www.shkcctv.com" {
            components?.scheme = "https"
            components?.host = "shkala.com"
        }
        let uri = components?.url ?? rawUri
        let segments = uri.pathComponents.filter { $0 != "/" }

        if segments.count >= 2 && segments[0] == "product" {
            navigate(.productDetail(slug: segments[1]))
        } else if segments.count >= 2 && segments[0] == "p" && !segments[1].isBlankShk {
            // لینک همکاری در فروش (shkala.com/p/{uuid}?u=شناسه‌ی معرف): فقط وقتی خودِ لینک با اپ باز شده (Universal Link)
            // معرف ثبت می‌شه؛ لینک «باز کردن در اپ» سایت (shkala://) اصلاً به این‌جا نمی‌رسه. بعد صفحه‌ی محصول باز می‌شه
            let productUuid = segments[1]
            let rawAffiliate = components?.queryItems?.first(where: { $0.name == "u" })?.value?
                .trimmingCharacters(in: .whitespaces) ?? ""
            let affiliateId: Int64? = Int64(rawAffiliate).flatMap { $0 > 0 ? $0 : nil }
            let fallbackUrl = uri.absoluteString
            Task { @MainActor in
                let response = try? await ApiService.affiliateReferral(productUuid: productUuid, affiliateId: affiliateId)
                let slug = response.flatMap { $0.isSuccessful ? $0.body?.product?.slug : nil }
                if let slug, !slug.isBlankShk {
                    self.navigate(.productDetail(slug: slug))
                } else {
                    self.navigate(.webpage(url: fallbackUrl))
                }
            }
        } else if segments.count >= 2 && segments[0] == "discount" && !segments[1].isBlankShk {
            // لینک کمپین کد تخفیف: کد ذخیره می‌شه و در تسویه‌حساب خودکار اعمال می‌شه (صفحه‌ی اصلی می‌مونه)
            CampaignDiscountStore.save(segments[1])
            ShkToast.shared.show("کد تخفیف ذخیره شد و در مرحله‌ی پرداخت اعمال می‌شود.", long: true)
        } else if segments.count == 1 && segments[0] == "tools" {
            navigate(.tools)
        } else if segments.count == 2 && segments[0] == "tools" && segments[1] == "hdd-calculator" {
            navigate(.hddCalculator)
        } else {
            // برای صفحاتی که هنوز طراحی اختصاصی توی اپ ندارن (مثل مقالات)،
            // فعلاً همون صفحه رو داخل خود اپ (نه مرورگر بیرونی) نشون می‌دیم
            navigate(.webpage(url: uri.absoluteString))
        }
    }
}
