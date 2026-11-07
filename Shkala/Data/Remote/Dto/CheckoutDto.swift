import Foundation

// معادل data/remote/dto/CheckoutDto.kt اپ اندروید

// ---- آدرس‌ها ----

struct AddressesResponse: ShkDTO {
    let status: String
    let addresses: [AddressDto]
    enum CodingKeys: String, CodingKey { case status, addresses }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        addresses = c.lossyList(AddressDto.self, .addresses) ?? []
    }
}

struct AddressResponse: ShkDTO {
    let status: String
    let message: String?
    let address: AddressDto?
    enum CodingKeys: String, CodingKey { case status, message, address }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        address = try? c.decodeIfPresent(AddressDto.self, forKey: .address)
    }
}

struct AddressDto: ShkDTO, Identifiable, Equatable, Hashable {
    let id: Int
    let firstName: String
    let lastName: String
    let state: String
    let city: String
    let phone: String
    let postalCode: String
    let fullAddress: String
    let active: Bool

    var fullName: String { "\(firstName) \(lastName)" }

    enum CodingKeys: String, CodingKey {
        case id, firstName = "first_name", lastName = "last_name", state, city, phone
        case postalCode = "postal_code", fullAddress = "full_address", active
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.lenientInt(.id) else {
            throw DecodingError.keyNotFound(CodingKeys.id, .init(codingPath: c.codingPath, debugDescription: "id"))
        }
        self.id = id
        firstName = c.lenientString(.firstName) ?? ""
        lastName = c.lenientString(.lastName) ?? ""
        state = c.lenientString(.state) ?? ""
        city = c.lenientString(.city) ?? ""
        phone = c.lenientString(.phone) ?? ""
        postalCode = c.lenientString(.postalCode) ?? ""
        fullAddress = c.lenientString(.fullAddress) ?? ""
        active = c.lenientBool(.active) ?? false
    }
}

// ---- شعبه‌های حضوری ----

struct ReceptionCenterDto: ShkDTO, Identifiable, Equatable {
    let id: String
    let state: String?
    let city: String?
    let phone: String?
    let postalCode: String?
    let fullAddress: String?
    enum CodingKeys: String, CodingKey { case id, state, city, phone, postalCode = "postal_code", fullAddress = "full_address" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id) ?? ""
        state = c.lenientString(.state)
        city = c.lenientString(.city)
        phone = c.lenientString(.phone)
        postalCode = c.lenientString(.postalCode)
        fullAddress = c.lenientString(.fullAddress)
    }
}

// ---- روش ارسال ----

struct ShippingResponse: ShkDTO {
    let status: String
    let message: String?
    let addresses: [AddressDto]?
    let receptionCenters: [ReceptionCenterDto]?
    let selectedAddress: SelectedAddressDto?
    let consignments: [ConsignmentEntry]?
    let financial: FinancialDto?
    let itemsCount: Int?
    // فاز ۱۴: موجودی کیف پول - برای گزینه‌ی «کسر از کیف پول»
    let walletBalance: Int64?
    // تخفیف خودکار و برچسب وضعیت تخفیف (همه nullable: سرورهای قدیمی‌تر این فیلدها رو نمی‌فرستن)
    let autoDiscount: AutoDiscountDto?
    let discountLabel: DiscountLabelDto?

    enum CodingKeys: String, CodingKey {
        case status, message, addresses, receptionCenters = "reception_centers", selectedAddress = "selected_address"
        case consignments, financial, itemsCount = "items_count", walletBalance = "wallet_balance"
        case autoDiscount = "auto_discount", discountLabel = "discount_label"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        addresses = c.lossyList(AddressDto.self, .addresses)
        receptionCenters = c.lossyList(ReceptionCenterDto.self, .receptionCenters)
        selectedAddress = try? c.decodeIfPresent(SelectedAddressDto.self, forKey: .selectedAddress)
        consignments = decodeConsignmentsMap(c, .consignments)
        financial = try? c.decodeIfPresent(FinancialDto.self, forKey: .financial)
        itemsCount = c.lenientInt(.itemsCount)
        walletBalance = c.lenientInt64(.walletBalance)
        autoDiscount = try? c.decodeIfPresent(AutoDiscountDto.self, forKey: .autoDiscount)
        discountLabel = try? c.decodeIfPresent(DiscountLabelDto.self, forKey: .discountLabel)
    }
}

/// یک مرسوله با کلیدش (ترتیب مرسوله‌ها مثل LinkedTreeMap گسون حفظ می‌شه)
struct ConsignmentEntry: Identifiable {
    let key: String
    let value: ConsignmentShippingDto
    var id: String { key }
}

/// نقشه‌ی مرسوله‌ها (کلید = شناسه‌ی مرسوله)؛ PHP آرایه‌ی خالی رو [] می‌فرسته، نه {} - پس تحمل‌پذیر.
/// (تفاوت iOS: Dictionary ترتیب کلیدها رو نگه نمی‌داره؛ مرسوله‌ها بر اساس شناسه‌ی عددی - همون ترتیب ثبت - مرتب می‌شن)
private func decodeConsignmentsMap<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> [ConsignmentEntry]? {
    guard c.contains(key), (try? c.decodeNil(forKey: key)) != true else { return nil }
    if let map = try? c.decode([String: JSONValueBox<ConsignmentShippingDto>].self, forKey: key) {
        return map.compactMap { k, v in v.value.map { ConsignmentEntry(key: k, value: $0) } }
            .sorted { a, b in
                if let x = Int(a.key), let y = Int(b.key) { return x < y }
                return a.key < b.key
            }
    }
    if let list = try? c.decode(LossyArray<ConsignmentShippingDto>.self, forKey: key) {
        return list.items.enumerated().map { ConsignmentEntry(key: String($0.offset), value: $0.element) }
    }
    return nil
}

/// جعبه‌ی تحمل‌پذیر: عضو خراب = nil (به‌جای رد کل پاسخ)
struct JSONValueBox<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}

/** تخفیفی که سرور خودش روی سبد اعمال کرده (بدون وارد کردن کد) */
struct AutoDiscountDto: ShkDTO {
    let code: String?
    let title: String?
    let amount: Int64?
    enum CodingKeys: String, CodingKey { case code, title, amount }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = c.lenientString(.code)
        title = c.lenientString(.title)
        amount = c.lenientInt64(.amount)
    }
}

/** برچسب بالای کد تخفیف: type = active (اعمال شده) یا pending (با رسیدن به شرط اعمال می‌شود) */
struct DiscountLabelDto: ShkDTO {
    let type: String?
    let title: String?
    let message: String?
    enum CodingKeys: String, CodingKey { case type, title, message }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.lenientString(.type)
        title = c.lenientString(.title)
        message = c.lenientString(.message)
    }
}

/** جزئیات «حداقل مبلغ سبد» وقتی کد به‌خاطر کمبود مبلغ رد شده */
struct DiscountMinAmountDto: ShkDTO {
    let title: String?
    let code: String?
    let minAmount: Int64?
    let current: Int64?
    let shortfall: Int64?
    let restricted: Bool?
    enum CodingKeys: String, CodingKey { case title, code, minAmount = "min_amount", current, shortfall, restricted }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.lenientString(.title)
        code = c.lenientString(.code)
        minAmount = c.lenientInt64(.minAmount)
        current = c.lenientInt64(.current)
        shortfall = c.lenientInt64(.shortfall)
        restricted = c.lenientBool(.restricted)
    }
}

/** فاز ۱۴: پاسخ اعمال/حذف کد تخفیف - شامل جمع مالی تازه‌محاسبه‌شده */
struct DiscountResponse: ShkDTO {
    let status: String
    let message: String?
    let financial: FinancialDto?
    let consignments: [ConsignmentEntry]?
    let walletBalance: Int64?
    enum CodingKeys: String, CodingKey { case status, message, financial, consignments, walletBalance = "wallet_balance" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        financial = try? c.decodeIfPresent(FinancialDto.self, forKey: .financial)
        consignments = decodeConsignmentsMap(c, .consignments)
        walletBalance = c.lenientInt64(.walletBalance)
    }
}

/// پاسخ خطای اعمال کد تخفیف (۴۲۲): پیام + جزئیات حداقل مبلغ
struct DiscountErrorBody: ShkDTO {
    let message: String?
    let minAmount: DiscountMinAmountDto?
    enum CodingKeys: String, CodingKey { case message, minAmount = "min_amount" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        message = c.lenientString(.message)
        minAmount = try? c.decodeIfPresent(DiscountMinAmountDto.self, forKey: .minAmount)
    }
}

struct SelectedAddressDto: ShkDTO {
    let type: String // "user" یا "shop"
    let address: [String: JSONValue]? // شامل id (آدرس کاربر یا شعبه) + بقیه‌ی جزئیات خام
    enum CodingKeys: String, CodingKey { case type, address }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.lenientString(.type) ?? ""
        address = try? c.decodeIfPresent([String: JSONValue].self, forKey: .address)
    }
}

struct PostWayDto: ShkDTO, Equatable {
    let uuid: String
    let title: String?
    let price: String?
    enum CodingKeys: String, CodingKey { case uuid, title = "name", price }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenientString(.uuid) ?? ""
        title = c.lenientString(.title)
        price = c.lenientString(.price)
    }
}

struct ConsignmentShippingDto: ShkDTO {
    let uuid: String?
    let postWays: [PostWayDto]?
    let sendMethod: [String: JSONValue]?
    let totalFinalPrice: Int64?
    enum CodingKeys: String, CodingKey { case uuid, postWays = "get_post_ways", sendMethod = "send_method", totalFinalPrice }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenientString(.uuid)
        postWays = c.lossyList(PostWayDto.self, .postWays)
        sendMethod = try? c.decodeIfPresent([String: JSONValue].self, forKey: .sendMethod)
        totalFinalPrice = c.lenientInt64(.totalFinalPrice)
    }
}

struct FinancialDto: ShkDTO, Equatable {
    let totalPrice: Int64?
    let totalDiscount: Int64?
    let totalFinalPrice: Int64?
    let totalCouponDiscountPrice: Int64?
    let sendPrice: Int64?
    enum CodingKeys: String, CodingKey { case totalPrice, totalDiscount, totalFinalPrice, totalCouponDiscountPrice, sendPrice }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalPrice = c.lenientInt64(.totalPrice)
        totalDiscount = c.lenientInt64(.totalDiscount)
        totalFinalPrice = c.lenientInt64(.totalFinalPrice)
        totalCouponDiscountPrice = c.lenientInt64(.totalCouponDiscountPrice)
        sendPrice = c.lenientInt64(.sendPrice)
    }
}

// ---- درگاه‌های پرداخت ----

struct PaymentGatewaysResponse: ShkDTO {
    let status: String
    let gateways: [PaymentGatewayDto]
    enum CodingKeys: String, CodingKey { case status, gateways }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        gateways = c.lossyList(PaymentGatewayDto.self, .gateways) ?? []
    }
}

struct BankDetailDto: ShkDTO, Equatable, Hashable {
    let key: String
    let label: String
    let value: String?
    enum CodingKeys: String, CodingKey { case key, label, value }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = c.lenientString(.key) ?? ""
        label = c.lenientString(.label) ?? ""
        value = c.lenientString(.value)
    }
}

struct PaymentGatewayDto: ShkDTO, Identifiable, Equatable, Hashable {
    let id: String
    let label: String
    let icon: String?
    let bankDetails: [BankDetailDto]?
    // پکیج اختصاصی (قوانین پرداخت): توضیح گزینه و سقف مبلغ درگاه (مثلاً زرین‌پال ۴۰۰ میلیون تومان)
    let description: String?
    let maxAmount: Int64?
    let maxAmountMessage: String?
    enum CodingKeys: String, CodingKey {
        case id, label, icon, bankDetails = "bank_details", description
        case maxAmount = "max_amount", maxAmountMessage = "max_amount_message"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id) ?? ""
        label = c.lenientString(.label) ?? ""
        icon = c.lenientString(.icon)
        bankDetails = c.lossyList(BankDetailDto.self, .bankDetails)
        description = c.lenientString(.description)
        maxAmount = c.lenientInt64(.maxAmount)
        maxAmountMessage = c.lenientString(.maxAmountMessage)
    }
}

struct PayResponse: ShkDTO {
    let status: String
    let message: String?
    let action: String?
    let method: String?
    let inputs: [String: String]?
    let bridgeUrl: String?
    // فاز ۱۴: وقتی کل مبلغ با کیف پول پرداخت بشه، دیگه نیازی به وب‌ویوی بانک نیست
    let paidByWallet: Bool
    let orderUuid: String?
    enum CodingKeys: String, CodingKey {
        case status, message, action, method, inputs, bridgeUrl = "bridge_url", paidByWallet = "paid_by_wallet", orderUuid = "order_uuid"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        action = c.lenientString(.action)
        method = c.lenientString(.method)
        if let raw = try? c.decodeIfPresent([String: JSONValue].self, forKey: .inputs) {
            inputs = raw.compactMapValues { v in
                switch v {
                case .string(let s): return s
                case .number(let n): return n == n.rounded() ? String(Int64(n)) : String(n)
                case .bool(let b): return b ? "1" : "0"
                default: return nil
                }
            }
        } else {
            inputs = nil
        }
        bridgeUrl = c.lenientString(.bridgeUrl)
        paidByWallet = c.lenientBool(.paidByWallet) ?? false
        orderUuid = c.lenientString(.orderUuid)
    }
}

struct CardToCardResponse: ShkDTO {
    let status: String
    let message: String?
    let orderUuid: String?
    // فاز ۱۵: پرداخت ترکیبی کیف پول + کارت‌به‌کارت
    let paidByWallet: Bool
    let walletUsed: Int64?
    let cardToCardAmount: Int64?
    enum CodingKeys: String, CodingKey {
        case status, message, orderUuid = "order_uuid", paidByWallet = "paid_by_wallet"
        case walletUsed = "wallet_used", cardToCardAmount = "card_to_card_amount"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        orderUuid = c.lenientString(.orderUuid)
        paidByWallet = c.lenientBool(.paidByWallet) ?? false
        walletUsed = c.lenientInt64(.walletUsed)
        cardToCardAmount = c.lenientInt64(.cardToCardAmount)
    }
}

struct OrderStatusResponse: ShkDTO {
    let status: String
    let order: OrderStatusDto?
    enum CodingKeys: String, CodingKey { case status, order }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        order = try? c.decodeIfPresent(OrderStatusDto.self, forKey: .order)
    }
}

struct OrderStatusDto: ShkDTO {
    let id: Int
    let uuid: String
    let orderStatus: String
    enum CodingKeys: String, CodingKey { case id, uuid, orderStatus = "order_status" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        uuid = c.lenientString(.uuid) ?? ""
        orderStatus = c.lenientString(.orderStatus) ?? ""
    }
}

// ---- کمکی: استخراج مقادیر از نقشه‌های خام ----

extension JSONValue {
    var intValue: Int? {
        switch self {
        case .number(let n): return Int(n)
        case .string(let s): return Int(s)
        default: return nil
        }
    }
    var objectValue: [String: JSONValue]? { if case .object(let o) = self { return o }; return nil }
}

extension Optional where Wrapped == SelectedAddressDto {
    func selectedUserAddressId() -> Int? {
        guard let self, self.type == "user" else { return nil }
        return self.address?["id"]?.intValue
    }

    func selectedShopCenterId() -> String? {
        guard let self, self.type == "shop" else { return nil }
        return self.address?["id"]?.stringValue
    }
}

extension Optional where Wrapped == [String: JSONValue] {
    func selectedPostWayTitle() -> String? { self?["item"]?.objectValue?["name"]?.stringValue }
    func selectedPostWayUuid() -> String? { self?["item"]?.objectValue?["uuid"]?.stringValue }
}
