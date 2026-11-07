import Foundation

/// معادل data/ContentRepository.kt اپ اندروید (فاز ۱۳): ریپازیتوری تب‌های «برندها» و «مقالات»
/// در بخش دسته‌بندی‌های منوی ناوبری پایین اپ - همان پیام‌های خطا.
struct ContentRepository {

    func getBrandsList() async -> ApiResult<[BrandListItemDto]> {
        do {
            let response = try await ApiService.getBrandsList()
            if response.isSuccessful, let body = response.body?.brands {
                return .success(body)
            }
            return .error("دریافت فهرست برندها با خطا مواجه شد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    func getArticleCategories() async -> ApiResult<[ArticleCategoryDto]> {
        do {
            let response = try await ApiService.getArticleCategories()
            if response.isSuccessful, let body = response.body?.categories {
                return .success(body)
            }
            return .error("دریافت دسته‌بندی‌های مقاله با خطا مواجه شد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    // فاز ۳۱: پرسش‌های متداول
    func getFaqs() async -> ApiResult<[FaqDto]> {
        do {
            let response = try await ApiService.getFaqs()
            if response.isSuccessful, let body = response.body?.faqs { return .success(body) }
            return .error("دریافت پرسش‌های متداول با خطا مواجه شد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    // فاز ۳۲: صفحات ثابت اسکریپت (مثل «قوانین و شرایط») - محتوای HTML خام
    func getPage(_ slug: String) async -> ApiResult<PageDto> {
        do {
            let response = try await ApiService.getPage(slug)
            if response.isSuccessful, let body = response.body?.page { return .success(body) }
            return .error("صفحه یافت نشد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }
}
