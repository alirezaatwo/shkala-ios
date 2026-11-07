import Foundation

/// معادل data/CartRepository.kt اپ اندروید
struct CartRepository {
    /// پیام نشانه‌ی «نیاز به ورود» (پاسخ 401) - به کاربر نمایش داده نمی‌شه
    static let LOGIN_REQUIRED = "__login_required__"

    func getCart() async -> ApiResult<CartResponse> {
        do {
            let response = try await ApiService.getCart()
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error("دریافت سبد خرید با خطا مواجه شد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    /// آدرس صفحه‌ی پیش‌فاکتور سبد خرید فعلی (امضاشده و موقت)
    func getPrefactorLink() async -> ApiResult<String> {
        do {
            let response = try await ApiService.getCartPrefactorLink()
            if response.isSuccessful, let url = response.body?.url, !url.isBlankShk { return .success(url) }
            if response.code == 401 { return .error(Self.LOGIN_REQUIRED) }
            return .error(parseServerError(response.errorBodyString) ?? "دریافت پیش‌فاکتور با خطا مواجه شد.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    func addToCart(inventoryId: Int, count: Int = 1) async -> ApiResult<CartItemDto> {
        do {
            let response = try await ApiService.addToCart(inventoryId: inventoryId, count: count)
            if response.isSuccessful, let item = response.body?.item { return .success(item) }
            // کاربر وارد حسابش نشده: به‌جای پیام خام سرور، مودال ورود نمایش داده می‌شه
            if response.code == 401 { return .error(Self.LOGIN_REQUIRED) }
            return .error(parseServerError(response.errorBodyString) ?? "افزودن به سبد خرید ناموفق بود.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    func increase(consignmentItemId: Int, inventoryId: Int) async -> ApiResult<CartItemDto> {
        do {
            let response = try await ApiService.increaseCartItem(consignmentItemId: consignmentItemId, inventoryId: inventoryId)
            if response.isSuccessful, let item = response.body?.item { return .success(item) }
            return .error(parseServerError(response.errorBodyString) ?? "افزایش تعداد ممکن نیست.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    func decrease(consignmentItemId: Int, inventoryId: Int) async -> ApiResult<CartItemDto> {
        do {
            let response = try await ApiService.decreaseCartItem(consignmentItemId: consignmentItemId, inventoryId: inventoryId)
            if response.isSuccessful, let item = response.body?.item { return .success(item) }
            return .error(parseServerError(response.errorBodyString) ?? "کاهش تعداد ممکن نیست.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    func remove(consignmentItemId: Int) async -> ApiResult<Void> {
        do {
            let response = try await ApiService.removeCartItem(consignmentItemId: consignmentItemId)
            if response.isSuccessful { return .success(()) }
            return .error("حذف از سبد خرید ناموفق بود.")
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }

    private func parseServerError(_ rawBody: String?) -> String? {
        guard let rawBody, !rawBody.isBlankShk, let data = rawBody.data(using: .utf8) else { return nil }
        return (try? ShkJSON.decoder.decode(ApiErrorResponse.self, from: data))?.message
    }
}
