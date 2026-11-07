import Foundation

/// معادل data/AccountRepository.kt اپ اندروید (بخش سفارش‌ها) - همان پیام‌های خطا
struct AccountRepository {

    /**
     * پاسخ کامل لیست سفارش‌ها (گروه‌های سفارش + pagination + rejected_orders).
     * rejected_orders فقط در صفحه‌ی ۱ پر می‌شه؛ [search] = جستجو بر اساس شماره‌ی سفارش.
     */
    func getMyOrdersPage(_ page: Int = 1, search: String? = nil) async -> ApiResult<OrdersListResponse> {
        await safeCall {
            let q = search.flatMap { $0.isBlankShk ? nil : $0 }
            let r = try await ApiService.getMyOrders(page: page, search: q)
            if r.isSuccessful, let body = r.body { return .success(body) }
            return .error("دریافت سفارش‌ها با خطا مواجه شد.")
        }
    }

    func getMyOrderDetail(_ orderId: Int) async -> ApiResult<OrderDetailDto> {
        await safeCall {
            let r = try await ApiService.getMyOrderDetail(id: orderId)
            if r.isSuccessful, let order = r.body?.order { return .success(order) }
            return .error(r.body?.message ?? "دریافت جزئیات سفارش با خطا مواجه شد.")
        }
    }

    func getMyOrderReceiptBytes(_ orderId: Int) async -> ApiResult<Data> {
        await safeCall {
            let r = try await ApiService.getMyOrderReceipt(id: orderId)
            if r.isSuccessful, let data = r.body { return .success(data) }
            return .error("دریافت عکس رسید با خطا مواجه شد.")
        }
    }

    func getInvoiceBridge(_ orderId: Int) async -> ApiResult<InvoiceBridgeResponse> {
        await safeCall {
            let r = try await ApiService.getInvoiceBridge(id: orderId)
            if r.isSuccessful, let body = r.body, body.invoiceUrl != nil { return .success(body) }
            return .error(r.body?.message ?? "دریافت فاکتور با خطا مواجه شد.")
        }
    }

    func getAccountSummary() async -> ApiResult<AccountSummaryResponse> {
        await safeCall {
            let r = try await ApiService.getAccountSummary()
            if r.isSuccessful, let body = r.body { return .success(body) }
            return .error("دریافت آمار حساب با خطا مواجه شد.")
        }
    }

    func getTransactions(_ page: Int = 1, search: String? = nil, accepted: Bool? = nil, rejected: Bool? = nil,
                         deposit: Bool? = nil, withdrawal: Bool? = nil) async -> ApiResult<TransactionsResponse> {
        await safeCall {
            let r = try await ApiService.getTransactions(page: page, search: search, accepted: accepted, rejected: rejected, deposit: deposit, withdrawal: withdrawal)
            if r.isSuccessful, let body = r.body { return .success(body) }
            return .error("دریافت تراکنش‌ها با خطا مواجه شد.")
        }
    }

    func getNotifications(_ page: Int = 1) async -> ApiResult<NotificationsResponse> {
        await safeCall {
            let r = try await ApiService.getNotifications(page: page)
            if r.isSuccessful, let body = r.body { return .success(body) }
            return .error("دریافت اعلان‌ها با خطا مواجه شد.")
        }
    }

    func markNotificationAsRead(_ id: String) async -> ApiResult<Void> {
        await safeCall {
            let r = try await ApiService.markNotificationAsRead(id)
            if r.isSuccessful { return .success(()) }
            return .error("علامت‌گذاری اعلان با خطا مواجه شد.")
        }
    }

    private func safeCall<T>(_ block: () async throws -> ApiResult<T>) async -> ApiResult<T> {
        do {
            return try await block()
        } catch {
            return .error("خطا در اتصال به اینترنت.")
        }
    }
}
