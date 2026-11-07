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

    func getArticles(category: String? = nil, page: Int = 1) async -> ApiResult<ArticlesPage> {
        do {
            let response = try await ApiService.getArticles(category: category, page: page)
            if response.isSuccessful, let body = response.body {
                return .success(ArticlesPage(items: body.articles, pagination: body.pagination))
            }
            return .error("دریافت مقالات با خطا مواجه شد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    func getArticleDetail(_ slug: String) async -> ApiResult<ArticleDetailDto> {
        do {
            let response = try await ApiService.getArticleDetail(slug)
            if response.isSuccessful, let body = response.body?.article { return .success(body) }
            return .error("مقاله یافت نشد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    // فاز ۱۶: دیدگاه‌های مقاله
    func getArticleComments(_ slug: String) async -> ApiResult<[ArticleCommentDto]> {
        do {
            let response = try await ApiService.getArticleComments(slug)
            if response.isSuccessful, let body = response.body?.comments { return .success(body) }
            return .error("دریافت دیدگاه‌ها با خطا مواجه شد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    func addArticleComment(_ slug: String, content: String, replyTo: Int? = nil) async -> ApiResult<String> {
        do {
            let response = try await ApiService.addArticleComment(slug, content: content, replyTo: replyTo)
            if response.isSuccessful, let body = response.body {
                return .success(body.message ?? "دیدگاه شما ثبت شد.")
            }
            let message = response.errorBody.flatMap { try? ShkJSON.decoder.decode(ArticleAddCommentResponse.self, from: $0) }?.message
            return .error(message ?? "ثبت دیدگاه با خطا مواجه شد.")
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

    // فاز ۳۲: فرم‌های داینامیک اسکریپت (مثل «تماس با ما»)
    func getForm(_ slug: String) async -> ApiResult<FormDto> {
        do {
            let response = try await ApiService.getForm(slug)
            if response.isSuccessful, let body = response.body?.form { return .success(body) }
            return .error("فرم یافت نشد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    func submitFormAnswer(_ slug: String, body: FormAnswerSubmitRequest) async -> ApiResult<String> {
        do {
            let response = try await ApiService.submitFormAnswer(slug, body: body)
            if response.isSuccessful, let r = response.body, r.status == "ok" {
                return .success(r.message ?? "پیام شما با موفقیت ارسال شد.")
            }
            let message = response.errorBody.flatMap { try? ShkJSON.decoder.decode(FormAnswerSubmitResponse.self, from: $0) }?.message
            return .error(message ?? "ارسال پیام با خطا مواجه شد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }
}
