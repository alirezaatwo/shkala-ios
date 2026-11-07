import Foundation

/// نتیجه‌ی اعمال کد تخفیف: یا applied پره، یا خطا (پیام سرور + در صورت وجود جزئیات حداقل مبلغ)
struct DiscountApplyOutcome {
    var applied: DiscountResponse? = nil
    var errorMessage: String? = nil
    var minAmount: DiscountMinAmountDto? = nil
}

/// معادل data/CheckoutRepository.kt اپ اندروید - همان پیام‌های خطا
struct CheckoutRepository {

    func getAddresses() async -> ApiResult<[AddressDto]> {
        await safeCall {
            let r = try await ApiService.getAddresses()
            if r.isSuccessful, let body = r.body { return .success(body.addresses) }
            return .error("دریافت آدرس‌ها با خطا مواجه شد.")
        }
    }

    func createAddress(
        firstName: String, lastName: String, state: String, city: String,
        phone: String, postalCode: String, fullAddress: String,
        mapLat: Double? = nil, mapLng: Double? = nil
    ) async -> ApiResult<AddressDto> {
        await safeCall {
            let r = try await ApiService.createAddress(
                firstName: firstName, lastName: lastName, state: state, city: city, phone: phone,
                postalCode: postalCode, fullAddress: fullAddress, mapLat: mapLat, mapLng: mapLng
            )
            if r.isSuccessful, let address = r.body?.address { return .success(address) }
            return .error("ثبت آدرس با خطا مواجه شد.")
        }
    }

    func updateAddress(
        id: Int, firstName: String, lastName: String, state: String, city: String,
        phone: String, postalCode: String, fullAddress: String,
        mapLat: Double? = nil, mapLng: Double? = nil
    ) async -> ApiResult<AddressDto> {
        await safeCall {
            let r = try await ApiService.updateAddress(
                id: id, firstName: firstName, lastName: lastName, state: state, city: city, phone: phone,
                postalCode: postalCode, fullAddress: fullAddress, mapLat: mapLat, mapLng: mapLng
            )
            if r.isSuccessful, let address = r.body?.address { return .success(address) }
            return .error("ویرایش آدرس با خطا مواجه شد.")
        }
    }

    func selectAddress(_ id: Int) async -> ApiResult<AddressDto> {
        await safeCall {
            let r = try await ApiService.selectAddress(id: id)
            if r.isSuccessful, let address = r.body?.address { return .success(address) }
            return .error("انتخاب آدرس با خطا مواجه شد.")
        }
    }

    func deleteAddress(_ id: Int) async -> ApiResult<Void> {
        await safeCall {
            let r = try await ApiService.deleteAddress(id: id)
            return r.isSuccessful ? .success(()) : .error("حذف آدرس با خطا مواجه شد.")
        }
    }

    func getShipping() async -> ApiResult<ShippingResponse> {
        await safeCall {
            let r = try await ApiService.getShipping()
            if r.isSuccessful, let body = r.body { return .success(body) }
            return .error("دریافت اطلاعات ارسال با خطا مواجه شد.")
        }
    }

    func selectShippingMethod(type: String, consignmentUuid: String, sendMethodUuid: String) async -> ApiResult<Void> {
        await safeCall {
            let r = try await ApiService.selectShippingMethod(type: type, consignmentUuid: consignmentUuid, sendMethodUuid: sendMethodUuid)
            return r.isSuccessful ? .success(()) : .error("انتخاب روش ارسال با خطا مواجه شد.")
        }
    }

    func selectShopAddress(_ receptionCenterId: String) async -> ApiResult<Void> {
        await safeCall {
            let r = try await ApiService.selectShopAddress(receptionCenterId: receptionCenterId)
            return r.isSuccessful ? .success(()) : .error("انتخاب شعبه با خطا مواجه شد.")
        }
    }

    func getPaymentGateways() async -> ApiResult<[PaymentGatewayDto]> {
        await safeCall {
            let r = try await ApiService.getPaymentGateways()
            if r.isSuccessful, let body = r.body { return .success(body.gateways) }
            return .error("دریافت درگاه‌های پرداخت با خطا مواجه شد.")
        }
    }

    /** فاز ۱۴: اعمال کد تخفیف - جمع مالی جدید رو برمی‌گردونه تا فوراً در صفحه به‌روز بشه */
    func applyDiscount(_ code: String) async -> ApiResult<DiscountApplyOutcome> {
        await safeCall {
            let r = try await ApiService.applyDiscount(code: code)
            if r.isSuccessful, let body = r.body {
                return .success(DiscountApplyOutcome(applied: body))
            }
            if !r.isSuccessful {
                // پاسخ ۴۲۲ سرور: بدنه‌ی خطا فقط در errorBody هست
                let parsed = r.errorBody.flatMap { try? ShkJSON.decoder.decode(DiscountErrorBody.self, from: $0) }
                let message = parsed?.message
                return .success(DiscountApplyOutcome(
                    errorMessage: (message?.isBlankShk == false ? message : nil) ?? "کد تخفیف نامعتبر است.",
                    minAmount: parsed?.minAmount
                ))
            }
            return .success(DiscountApplyOutcome(errorMessage: "کد تخفیف نامعتبر است."))
        }
    }

    func removeDiscount() async -> ApiResult<DiscountResponse> {
        await safeCall {
            let r = try await ApiService.removeDiscount()
            if r.isSuccessful, let body = r.body { return .success(body) }
            return .error(r.body?.message ?? "حذف کد تخفیف با خطا مواجه شد.")
        }
    }

    func pay(paymentGateway: String, description: String? = nil, useWallet: Bool = false) async -> ApiResult<PayResponse> {
        await safeCall {
            let r = try await ApiService.pay(paymentGateway: paymentGateway, description: description, useWallet: useWallet ? 1 : nil)
            if r.isSuccessful, let body = r.body, body.action != nil || body.paidByWallet { return .success(body) }
            return .error(r.body?.message ?? "شروع پرداخت با خطا مواجه شد.")
        }
    }

    /** فاز ۱۵: پرداخت ترکیبی کیف پول + کارت‌به‌کارت - اگه کل مبلغ با کیف پول پوشش داده بشه receipt نال می‌مونه */
    func payCardToCard(receipt: Data?, useWallet: Bool = false) async -> ApiResult<String> {
        await safeCall {
            let part = receipt.map { data -> MultipartPart in
                let isPng = isPngData(data)
                return MultipartPart(
                    name: "receipt", data: data,
                    fileName: "receipt_\(Int64(Date().timeIntervalSince1970 * 1000)).\(isPng ? "png" : "jpg")",
                    mimeType: isPng ? "image/png" : "image/jpeg"
                )
            }
            let r = try await ApiService.payCardToCard(receipt: part, useWallet: useWallet)
            if r.isSuccessful, let uuid = r.body?.orderUuid { return .success(uuid) }
            return .error(r.body?.message ?? "ثبت سفارش با خطا مواجه شد.")
        }
    }

    /** پرداخت با هماهنگی کارشناس فروشگاه - خروجی: شناسه‌ی سفارش ثبت‌شده */
    func payCoordinated(description: String? = nil) async -> ApiResult<String> {
        await safeCall {
            let r = try await ApiService.payCoordinated(description: description ?? "")
            if r.isSuccessful, let uuid = r.body?.orderUuid { return .success(uuid) }
            return .error(r.body?.message ?? parseMessage(r.errorBody) ?? "ثبت سفارش با خطا مواجه شد.")
        }
    }

    func getOrderStatus(_ uuid: String) async -> ApiResult<String> {
        await safeCall {
            let r = try await ApiService.getOrderStatus(uuid: uuid)
            if r.isSuccessful, let order = r.body?.order { return .success(order.orderStatus) }
            return .error("دریافت وضعیت سفارش با خطا مواجه شد.")
        }
    }

    private func parseMessage(_ data: Data?) -> String? {
        guard let data else { return nil }
        let message = (try? ShkJSON.decoder.decode(ApiErrorResponse.self, from: data))?.message
        return message?.isBlankShk == false ? message : nil
    }

    private func safeCall<T>(_ block: () async throws -> ApiResult<T>) async -> ApiResult<T> {
        do {
            return try await block()
        } catch is URLError {
            return .error("خطا در اتصال به اینترنت.")
        } catch {
            // پاسخ به سرور رسیده ولی قابل پردازش نبود (نه قطعی اینترنت) - پیام جدا تا کاربر به
            // اشتباه سراغ اینترنتش نره
            return .error("دریافت اطلاعات با خطا مواجه شد؛ لطفاً دوباره تلاش کنید.")
        }
    }
}
