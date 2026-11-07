import Foundation

/// معادل CatalogRepository اپ اندروید (data/CatalogRepository.kt) - همان پیام‌های خطا.
/// مرحله‌ی ۲ فقط اطلاعات سایت؛ بقیه‌ی متدها همراه صفحه‌ی اصلی (مرحله‌ی ۳) اضافه می‌شن.
final class CatalogRepository {
    func getSiteInfo() async -> ApiResult<SiteInfoResponse> {
        do {
            let response = try await ApiService.getSiteInfo()
            if response.isSuccessful, let body = response.body {
                return .success(body)
            }
            return .error("دریافت اطلاعات سایت با خطا مواجه شد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }
}
