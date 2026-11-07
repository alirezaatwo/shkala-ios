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
}
