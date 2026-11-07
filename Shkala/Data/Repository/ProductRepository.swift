import Foundation

// معادل بخش محصولِ CatalogRepository.kt + ProductExtrasRepository.kt + ProductReviewsRepository.kt +
// FavoriteRepository.kt + ProductCompareRepository.kt اپ اندروید

extension CatalogRepository {
    func getProductDetail(_ slug: String) async -> ApiResult<ProductDetailDto> {
        do {
            let response = try await ApiService.getProductDetail(slug)
            if response.isSuccessful, let body = response.body { return .success(body.product) }
            return .error("محصول یافت نشد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    func getProductInventories(_ slug: String) async -> ApiResult<[ProductInventoryDto]> {
        do {
            let response = try await ApiService.getProductInventories(slug)
            if response.isSuccessful, let body = response.body { return .success(body.inventories) }
            return .error("دریافت انتخاب‌های محصول با خطا مواجه شد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }
}

struct ProductExtrasRepository {
    func getProductExtras(_ slug: String) async -> ApiResult<ProductExtrasResponse> {
        do {
            let response = try await ApiService.getProductExtras(slug)
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error("خطا در دریافت اطلاعات فروشنده و محصولات مرتبط")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }

    /// فاز ۶: روشن/خاموش کردن اعلان قیمت یا موجود شدن. type باید "inventory" یا "discount" باشد.
    func toggleNotification(_ slug: String, type: String) async -> ApiResult<NotifyToggleResponse> {
        do {
            let response = try await ApiService.toggleProductNotification(slug, type: type)
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error(extractMessage(response.errorBody) ?? "خطا در ثبت اعلان قیمت")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }

    private func extractMessage(_ errorBody: Data?) -> String? {
        guard let errorBody else { return nil }
        return (try? ShkJSON.decoder.decode(NotifyToggleResponse.self, from: errorBody))?.message
    }
}

struct ProductReviewsRepository {
    /// دیدگاه‌ها با مرتب‌سازی سایت. sort یکی از "clatest"، "useful"، "buyers" یا nil (پیش‌فرض سایت)
    func getCommentsSorted(_ slug: String, page: Int = 1, sort: String? = nil) async -> ApiResult<ProductCommentsResponse> {
        do {
            let response = try await ApiService.getProductComments(
                slug, page: page,
                latest: sort == "clatest" ? 1 : nil,
                useful: sort == "useful" ? 1 : nil,
                buyers: sort == "buyers" ? 1 : nil
            )
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error("خطا در دریافت دیدگاه‌ها")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }

    /// پرسش‌ها با مرتب‌سازی سایت. sort یکی از "qlatest"، "noanswer"، "answer" یا nil
    func getQuestionsSorted(_ slug: String, page: Int = 1, sort: String? = nil) async -> ApiResult<ProductQuestionsResponse> {
        do {
            let response = try await ApiService.getProductQuestions(
                slug, page: page,
                latest: sort == "qlatest" ? 1 : nil,
                noAnswer: sort == "noanswer" ? 1 : nil,
                withAnswer: sort == "answer" ? 1 : nil
            )
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error("خطا در دریافت سؤالات")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }

    func submitComment(
        slug: String, content: String, rating: Int, suggestion: Bool?,
        strengths: [String], weakness: [String], images: [Data]?
    ) async -> ApiResult<SubmitResponse> {
        var parts: [MultipartPart] = [.text("content", content), .text("rating", String(rating))]
        if let suggestion { parts.append(.text("suggation", suggestion ? "suggest" : "not_suggest")) }
        parts += strengths.map { .text("strengths[]", $0) }
        parts += weakness.map { .text("weakness[]", $0) }
        // پسوند فایل از نوع واقعی تصویر گرفته می‌شه چون سرور پسوند را از نام فایل ذخیره می‌کند
        for (i, data) in (images ?? []).enumerated() {
            let png = isPngData(data)
            parts.append(MultipartPart(name: "images[]", data: data, fileName: "review_image_\(Int(Date().timeIntervalSince1970 * 1000))_\(i).\(png ? "png" : "jpg")", mimeType: png ? "image/png" : "image/jpeg"))
        }
        do {
            let response = try await ApiService.submitProductComment(slug, parts: parts)
            if response.isSuccessful, let body = response.body { return .success(body) }
            let message = response.errorBody.flatMap { try? ShkJSON.decoder.decode(SubmitResponse.self, from: $0) }?.message
            return .error(message ?? "خطا در ثبت دیدگاه (کد \(response.code))")
        } catch {
            return .error("خطا در اتصال به اینترنت")
        }
    }

    func voteComment(_ commentId: Int, up: Bool) async -> ApiResult<CommentVoteResponse> {
        do {
            let response = try await ApiService.voteProductComment(commentId, type: up ? "up" : "down")
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error("خطا در ثبت رأی")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }

    func submitQuestion(_ slug: String, question: String) async -> ApiResult<SubmitResponse> {
        do {
            let response = try await ApiService.submitProductQuestion(slug, question: question)
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error("خطا در ثبت سؤال")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }

    func submitAnswer(_ questionId: Int, answer: String) async -> ApiResult<SubmitResponse> {
        do {
            let response = try await ApiService.submitQuestionAnswer(questionId, answer: answer)
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error("خطا در ثبت پاسخ")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }
}

struct FavoriteRepository {
    func toggleFavorite(_ productId: Int) async -> ApiResult<Bool> {
        do {
            let r = try await ApiService.toggleFavorite(productId)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.isFavorite) }
            return .error(r.body?.message ?? "خطا در ثبت علاقه‌مندی.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }
}

struct ProductCompareRepository {
    func getCompares() async -> ApiResult<CompareListResponse> {
        do {
            let response = try await ApiService.getCompares()
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error("خطا در دریافت لیست مقایسه")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }

    /// type = "start" یعنی مقایسه‌ی فعلی پاک شود و فقط همین محصول اضافه شود؛ nil یعنی افزودن معمولی
    func addToCompare(_ slug: String, type: String? = nil) async -> ApiResult<CompareActionResponse> {
        do {
            let response = try await ApiService.addToCompare(slug, type: type)
            if response.isSuccessful, let body = response.body { return .success(body) }
            let message = response.errorBody.flatMap { try? ShkJSON.decoder.decode(CompareActionResponse.self, from: $0) }?.message
            return .error(message ?? "این محصول قابل افزودن به مقایسه نیست")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }

    func removeFromCompare(_ compareId: Int) async -> ApiResult<CompareActionResponse> {
        do {
            let response = try await ApiService.removeFromCompare(compareId)
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error("خطا در حذف از مقایسه")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }

    /// فاز ۹: جست‌وجوی لایو محصولات هم‌دسته برای افزودن به مقایسه
    func searchCompareProducts(search: String? = nil, page: Int = 1) async -> ApiResult<CompareSearchPageDto> {
        do {
            let response = try await ApiService.searchCompareProducts(search: search, page: page)
            if response.isSuccessful, let body = response.body?.products { return .success(body) }
            return .error("خطا در جست‌وجوی محصول")
        } catch {
            return .error("خطا در اتصال اینترنت")
        }
    }
}

/// امضای فایل PNG (برای تعیین نوع واقعی تصویر)
func isPngData(_ data: Data) -> Bool {
    data.count > 8 && data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
}

/// امضای فایل JPEG
func isJpegData(_ data: Data) -> Bool {
    data.count > 3 && data[data.startIndex] == 0xFF && data[data.startIndex + 1] == 0xD8
}
