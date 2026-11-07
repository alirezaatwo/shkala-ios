import SwiftUI

/// معادل CheckoutUiState اپ اندروید
struct CheckoutUiState {
    var isLoading = true
    var errorMessage: String? = nil
    var addresses: [AddressDto] = []
    var receptionCenters: [ReceptionCenterDto] = []
    var selectedAddress: SelectedAddressDto? = nil
    var consignments: [ConsignmentEntry] = []
    var financial: FinancialDto? = nil
    var itemsCount = 0
    var isMutating = false
    // کشیدن صفحه به پایین برای بروزرسانی
    var isRefreshing = false
    // فاز ۱۴: کد تخفیف + کسر از کیف پول در تسویه‌حساب
    var walletBalance: Int64 = 0
    var useWallet = false
    var discountCode = ""
    var isApplyingDiscount = false
    var discountMessage: String? = nil
    var discountIsError = false
    // تخفیف خودکار، برچسب وضعیت تخفیف و جزئیات رد شدن کد به‌خاطر حداقل مبلغ
    var autoDiscount: AutoDiscountDto? = nil
    var discountLabel: DiscountLabelDto? = nil
    var discountMinAmount: DiscountMinAmountDto? = nil
    // ادغام تسویه‌حساب و انتخاب درگاه: درگاه‌های پرداخت در همین صفحه انتخاب می‌شن
    var gateways: [PaymentGatewayDto] = []
    var isLoadingGateways = true
    var gatewaysError: String? = nil
    var selectedGatewayId: String? = nil
    var isPlacingOrder = false
    // وضعیت کسر از کیف پول قبل از انتخاب روش آفلاین - وقتی کاربر دوباره درگاه بانکی
    // رو انتخاب کنه، دوباره اعمال می‌شه
    var savedUseWallet = false

    /** روش‌هایی که (طبق منطق کارت‌به‌کارت اسکریپت) کیف پول در اون‌ها اعمال نمی‌شه؛ کد تخفیف اعمال می‌شه */
    var isOfflineMethod: Bool { isOfflineGateway(selectedGatewayId) }

    /** برآورد مبلغی که اگه درگاه بانکی انتخاب بشه به درگاه می‌ره (برای سقف زرین‌پال) */
    var onlinePayableEstimate: Int64 {
        if !isOfflineMethod { return payableAfterWallet }
        let total = financial?.totalFinalPrice ?? 0
        return savedUseWallet ? max(0, total - walletBalance) : total
    }

    /** سقف مبلغ درگاه (زرین‌پال: از تنظیمات سایت، در غیر این صورت ۴۰۰ میلیون تومان) */
    func gatewayLimit(_ gateway: PaymentGatewayDto) -> Int64? {
        gateway.maxAmount ?? (gateway.id == ZARINPAL_ID ? ZARINPAL_DEFAULT_LIMIT : nil)
    }

    func isGatewayDisabled(_ gateway: PaymentGatewayDto) -> Bool {
        if isOfflineGateway(gateway.id) { return false }
        guard let max = gatewayLimit(gateway) else { return false }
        return max > 0 && onlinePayableEstimate > max
    }

    func overLimitMessage(_ gateway: PaymentGatewayDto) -> String {
        if let m = gateway.maxAmountMessage, !m.isBlankShk { return m }
        return ZARINPAL_DEFAULT_MESSAGE
    }

    /** درگاه انتخاب‌شده، فقط اگه معتبر و قابل‌استفاده باشه */
    var selectedGateway: PaymentGatewayDto? {
        gateways.first { $0.id == selectedGatewayId && !isGatewayDisabled($0) }
    }

    /** آیا در حال حاضر کد تخفیفی روی سبد خرید اعمال شده */
    var hasAppliedDiscount: Bool { (financial?.totalCouponDiscountPrice ?? 0) > 0 }

    /** مبلغ نهایی قابل‌پرداخت با در نظر گرفتن کسر از کیف پول (برای نمایش لحظه‌ای) */
    var payableAfterWallet: Int64 {
        let total = financial?.totalFinalPrice ?? 0
        return useWallet ? max(0, total - walletBalance) : total
    }

    /** مقداری که واقعاً از کیف پول کسر می‌شه (بیشتر از مبلغ نهایی نمی‌شه) */
    var walletDeductionAmount: Int64 {
        let total = financial?.totalFinalPrice ?? 0
        return useWallet ? min(walletBalance, total) : 0
    }

    var selectedAddressType: String? { selectedAddress?.type }
    var hasSelectedAddress: Bool { selectedAddressType != nil }
    var allShippingMethodsSelected: Bool {
        selectedAddressType == "shop" || consignments.allSatisfy { $0.value.sendMethod != nil }
    }

    /** متن قابل‌نمایش برای اینکه کاربر دقیقاً بدونه چی انتخاب کرده */
    var deliverySummaryText: String {
        guard selectedAddress != nil else { return "برای انتخاب یا افزودن آدرس ضربه بزنید" }

        if selectedAddressType == "shop" {
            let centerId = selectedAddress.selectedShopCenterId()
            if let center = receptionCenters.first(where: { $0.id == centerId }) {
                return "تحویل حضوری از شعبه: \(center.city ?? "") - \(center.fullAddress ?? "")"
            }
            return "تحویل حضوری از شعبه‌ی فروشگاه"
        }

        let addressId = selectedAddress.selectedUserAddressId()
        let address = addresses.first { $0.id == addressId }
        var methodTitles: [String] = []
        for c in consignments {
            if let t = c.value.sendMethod.selectedPostWayTitle(), !methodTitles.contains(t) { methodTitles.append(t) }
        }

        let addressPart = address != nil ? "ارسال به \(address!.city)" : "ارسال به آدرس"
        let methodPart = !methodTitles.isEmpty ? " — روش: \(methodTitles.joined(separator: "، "))" : " — روش ارسال هنوز انتخاب نشده"
        return addressPart + methodPart
    }
}

let ZARINPAL_ID = "zarinpal"
let ZARINPAL_DEFAULT_LIMIT: Int64 = 400_000_000
let ZARINPAL_DEFAULT_MESSAGE = "برای پرداخت سفارشات با مبالغ بالای ۴۰۰ میلیون تومان خواهشمندیم از سایر شیوه‌های پرداخت استفاده نمایید."
let COORDINATED_GATEWAY_ID = "coordinated"

func isOfflineGateway(_ id: String?) -> Bool { id == "card_to_card" || id == COORDINATED_GATEWAY_ID }

/// معادل ui/checkout/CheckoutViewModel.kt
@MainActor
final class CheckoutViewModel: ObservableObject {
    @Published private(set) var uiState = CheckoutUiState()
    private let repository = CheckoutRepository()

    /** فقط وقتی به صفحه‌ی آدرس‌ها رفتیم، برگشتن به این صفحه باید اطلاعات رو از سرور تازه کنه
     * (بارگذاری دوباره، کد تخفیف رو روی سرور پاک می‌کنه) */
    var reloadOnResume = false

    init() {
        load()
        loadGateways()
    }

    func loadGateways() {
        uiState.isLoadingGateways = true
        uiState.gatewaysError = nil
        Task {
            switch await repository.getPaymentGateways() {
            case .success(let list):
                uiState.isLoadingGateways = false
                uiState.gateways = list
            case .error(let message):
                uiState.isLoadingGateways = false
                uiState.gatewaysError = message
            }
            ensureDefaultGateway()
        }
    }

    /** اولین درگاه بانکیِ قابل‌استفاده به‌صورت پیش‌فرض انتخاب می‌شه (نه روش‌های آفلاین) */
    private func ensureDefaultGateway() {
        let s = uiState
        if s.selectedGatewayId != nil || s.financial == nil || s.gateways.isEmpty { return }
        if let first = s.gateways.first(where: { !isOfflineGateway($0.id) && !s.isGatewayDisabled($0) }) {
            uiState.selectedGatewayId = first.id
        }
    }

    /**
     * انتخاب روش پرداخت. دقیقاً طبق منطق کارت‌به‌کارت اسکریپت: با رفتن به کارت‌به‌کارت/پرداخت با
     * هماهنگی فقط کسر از کیف پول خاموش می‌شه (کد تخفیف دست نمی‌خوره)؛ با برگشتن به درگاه بانکی،
     * وضعیت قبلی کیف پول برمی‌گرده.
     */
    func selectGateway(_ id: String) {
        let s = uiState
        if id == s.selectedGatewayId || s.isApplyingDiscount || s.isPlacingOrder { return }
        guard let gateway = s.gateways.first(where: { $0.id == id }) else { return }
        if s.isGatewayDisabled(gateway) { return }

        let wasOffline = s.isOfflineMethod
        let willOffline = isOfflineGateway(id)
        if !wasOffline && willOffline {
            uiState.selectedGatewayId = id
            uiState.savedUseWallet = s.useWallet
            uiState.useWallet = false
        } else if wasOffline && !willOffline {
            uiState.selectedGatewayId = id
            uiState.useWallet = s.savedUseWallet && s.walletBalance > 0
            uiState.savedUseWallet = false
        } else {
            uiState.selectedGatewayId = id
        }
    }

    /** ثبت سفارش «پرداخت با هماهنگی» */
    func placeCoordinatedOrder(onPlaced: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        if uiState.isPlacingOrder { return }
        uiState.isPlacingOrder = true
        Task {
            switch await repository.payCoordinated() {
            case .success(let uuid):
                uiState.isPlacingOrder = false
                onPlaced(uuid)
            case .error(let message):
                uiState.isPlacingOrder = false
                onError(message)
            }
        }
    }

    func load(silently: Bool = false) {
        if !silently {
            uiState.isLoading = true
            uiState.errorMessage = nil
        }
        Task {
            switch await repository.getShipping() {
            case .success(let body):
                applyShipping(body)
                ensureDefaultGateway()
            case .error(let message):
                if !silently {
                    uiState.isLoading = false
                    uiState.errorMessage = message
                }
            }
        }
    }

    private func applyShipping(_ body: ShippingResponse) {
        uiState.isLoading = false
        uiState.errorMessage = nil
        uiState.addresses = body.addresses ?? []
        uiState.receptionCenters = body.receptionCenters ?? []
        uiState.selectedAddress = body.selectedAddress
        uiState.consignments = body.consignments ?? []
        uiState.financial = body.financial
        uiState.itemsCount = body.itemsCount ?? 0
        uiState.walletBalance = body.walletBalance ?? 0
        // بارگذاری صفحه‌ی ارسال، کد تخفیف قبلی رو روی سرور پاک می‌کنه
        // (دقیقاً مثل سایت) - پس فیلد کد تخفیف اینجا هم خالی می‌شه
        uiState.discountCode = ""
        uiState.discountMessage = nil
        uiState.discountIsError = false
        uiState.autoDiscount = body.autoDiscount
        uiState.discountLabel = body.discountLabel
    }

    /**
     * کشیدن صفحه به پایین: اطلاعات ارسال و درگاه‌ها بی‌صدا از سرور تازه می‌شن.
     * در صورت خطا محتوای قبلی حفظ می‌شه و پیام خطا به onError داده می‌شه.
     */
    func refresh(onError: @escaping (String) -> Void = { _ in }) async {
        let s = uiState
        if s.isRefreshing || s.isMutating || s.isApplyingDiscount || s.isPlacingOrder { return }
        uiState.isRefreshing = true
        async let shipping = repository.getShipping()
        async let gateways = repository.getPaymentGateways()
        let shippingResult = await shipping
        let gatewaysResult = await gateways

        if case .success(let body) = shippingResult { applyShipping(body) }
        switch gatewaysResult {
        case .success(let newGateways):
            // اگه درگاه انتخاب‌شده دیگه در فهرست نیست، انتخاب پاک می‌شه تا پیش‌فرض دوباره انتخاب بشه
            let keepSelected = newGateways.contains { $0.id == uiState.selectedGatewayId }
            uiState.gateways = newGateways
            uiState.isLoadingGateways = false
            uiState.gatewaysError = nil
            if !keepSelected { uiState.selectedGatewayId = nil }
        case .error(let message):
            if uiState.gateways.isEmpty {
                uiState.isLoadingGateways = false
                uiState.gatewaysError = message
            }
        }
        ensureDefaultGateway()
        uiState.isRefreshing = false

        var error: String? = nil
        if case .error(let m) = shippingResult { error = m } else if case .error(let m) = gatewaysResult { error = m }
        if let error { onError(error) }
    }

    func selectAddress(_ addressId: Int, onDone: @escaping () -> Void = {}) {
        uiState.isMutating = true
        Task {
            _ = await repository.selectAddress(addressId)
            uiState.isMutating = false
            load()
            onDone()
        }
    }

    func selectShopAddress(_ receptionCenterId: String, onDone: @escaping () -> Void = {}) {
        uiState.isMutating = true
        Task {
            _ = await repository.selectShopAddress(receptionCenterId)
            uiState.isMutating = false
            load()
            onDone()
        }
    }

    func selectShippingMethod(type: String, consignmentUuid: String, sendMethodUuid: String) {
        uiState.isMutating = true
        Task {
            _ = await repository.selectShippingMethod(type: type, consignmentUuid: consignmentUuid, sendMethodUuid: sendMethodUuid)
            uiState.isMutating = false
            load()
        }
    }

    /** فاز ۱۴: کسر از کیف پول - فقط یه محاسبه‌ی لحظه‌ای محلیه، نیازی به سرور نداره */
    func toggleWallet(_ enabled: Bool) {
        if uiState.isOfflineMethod { return }
        uiState.useWallet = enabled
    }

    /** اعمال کد لینک کمپین (یک‌بار، بعد از آماده شدن صفحه) */
    func applyCampaignCode(_ code: String) {
        if code.isBlankShk || uiState.isApplyingDiscount || uiState.hasAppliedDiscount { return }
        uiState.discountCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        applyDiscount()
    }

    func updateDiscountCode(_ code: String) {
        uiState.discountCode = code
        uiState.discountMessage = nil
        uiState.discountIsError = false
    }

    /** اعمال کد تخفیف - جمع مالی رو مستقیم از پاسخ همین درخواست به‌روز می‌کنه
     * (نه با صدا زدن دوباره‌ی load()، چون بارگذاری صفحه‌ی ارسال خودش تخفیف رو پاک می‌کنه) */
    func applyDiscount() {
        let code = uiState.discountCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if code.isEmpty || uiState.isApplyingDiscount { return }

        uiState.isApplyingDiscount = true
        uiState.discountMessage = nil
        uiState.discountIsError = false
        Task {
            switch await repository.applyDiscount(code) {
            case .success(let outcome):
                if let applied = outcome.applied {
                    uiState.isApplyingDiscount = false
                    uiState.financial = applied.financial ?? uiState.financial
                    uiState.consignments = applied.consignments ?? uiState.consignments
                    uiState.walletBalance = applied.walletBalance ?? uiState.walletBalance
                    uiState.discountMessage = applied.message ?? "کد تخفیف اعمال شد."
                    uiState.discountIsError = false
                    uiState.autoDiscount = nil
                    uiState.discountMinAmount = nil
                } else {
                    // رد شدن کد: جمع مالی و برچسب‌ها دوباره از سرور گرفته می‌شن (پیام خطا حفظ می‌شه)
                    await failDiscount(outcome.errorMessage ?? "کد تخفیف نامعتبر است.", outcome.minAmount)
                }
            case .error(let message):
                await failDiscount(message, nil)
            }
        }
    }

    private func failDiscount(_ message: String, _ minAmount: DiscountMinAmountDto?) async {
        let refreshed = await repository.getShipping()
        if case .success(let body) = refreshed {
            uiState.financial = body.financial ?? uiState.financial
            uiState.consignments = body.consignments ?? uiState.consignments
            uiState.walletBalance = body.walletBalance ?? uiState.walletBalance
            uiState.autoDiscount = body.autoDiscount
            uiState.discountLabel = body.discountLabel
        }
        uiState.isApplyingDiscount = false
        uiState.discountMessage = message
        uiState.discountIsError = true
        uiState.discountMinAmount = minAmount
    }

    func dismissMinAmountDialog() { uiState.discountMinAmount = nil }

    func removeDiscount() {
        if uiState.isApplyingDiscount { return }
        uiState.isApplyingDiscount = true
        Task {
            switch await repository.removeDiscount() {
            case .success(let body):
                uiState.isApplyingDiscount = false
                uiState.financial = body.financial ?? uiState.financial
                uiState.consignments = body.consignments ?? uiState.consignments
                uiState.walletBalance = body.walletBalance ?? uiState.walletBalance
                uiState.discountCode = ""
                uiState.discountMessage = nil
                uiState.discountIsError = false
                uiState.autoDiscount = nil
                uiState.discountMinAmount = nil
                // بعد از حذف، برچسب «در انتظار» (در صورت وجود) از سرور تازه می‌شه
                if case .success(let refreshed) = await repository.getShipping() {
                    uiState.discountLabel = refreshed.discountLabel
                }
            case .error(let message):
                uiState.isApplyingDiscount = false
                uiState.discountMessage = message
                uiState.discountIsError = true
            }
        }
    }
}

/// معادل PaymentFlowViewModel اندروید (مشترک در سطح Activity): وضعیت جریان پرداخت بین صفحه‌ها
@MainActor
final class PaymentFlowState: ObservableObject {
    static let shared = PaymentFlowState()
    @Published var pendingPayment: PayResponse? = nil
    @Published var pendingGatewayId: String? = nil
    @Published var pendingCardToCardGateway: PaymentGatewayDto? = nil
    @Published var lastOrderUuid: String? = nil
    @Published var lastWasSuccessful = false
    // فاز ۱۴: آیا کاربر گزینه‌ی «کسر از کیف پول» رو در تسویه‌حساب فعال کرده
    @Published var useWallet = false
    // فاز ۳۱: مبلغ نهایی قابل‌پرداخت (بعد از کسر کیف پول)
    @Published var payableAmount: Int64 = 0
    // فاز ۱۶: پیام واقعی خطا (از سرور یا وب‌ویو) وقتی پرداخت ناموفق می‌شه
    @Published var lastErrorMessage: String? = nil
}

/// معادل LocationPickFlowViewModel اندروید: مختصات انتخاب‌شده روی نقشه برای فرم آدرس
@MainActor
final class LocationPickFlowState: ObservableObject {
    static let shared = LocationPickFlowState()
    @Published var pickedLat: Double? = nil
    @Published var pickedLng: Double? = nil

    func clear() {
        pickedLat = nil
        pickedLng = nil
    }
}
