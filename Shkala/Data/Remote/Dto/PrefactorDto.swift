import Foundation

// معادل بخش جزئیات/پرداخت data/remote/dto/PrefactorDto.kt اپ اندروید (فهرست در AccountDto.swift)
// نکته: SelectedAddressDto، PostWayDto، FinancialDto و BankDetailDto از قبل در CheckoutDto.swift
// تعریف شدن (همون ساختاری که سرور برای تسویه‌حساب عادی هم برمی‌گردونه) - همون‌ها استفاده می‌شن.

struct PrefactorDetailResponse: ShkDTO {
    let status: String
    let message: String?
    let prefactor: PrefactorInfoDto?
    let addresses: [AddressDto]?
    let selectedAddress: SelectedAddressDto?
    let consignments: [PrefactorConsignmentEntry]?
    let financial: FinancialDto?
    let itemsCount: Int?
    // فاز ۳۱: شعبه‌های تحویل حضوری
    let receptionCenters: [ReceptionCenterDto]?

    enum CodingKeys: String, CodingKey {
        case status, message, prefactor, addresses, selectedAddress = "selected_address", consignments, financial
        case itemsCount = "items_count", receptionCenters = "reception_centers"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        prefactor = try? c.decodeIfPresent(PrefactorInfoDto.self, forKey: .prefactor)
        addresses = c.lossyList(AddressDto.self, .addresses)
        selectedAddress = try? c.decodeIfPresent(SelectedAddressDto.self, forKey: .selectedAddress)
        consignments = decodePrefactorConsignments(c, .consignments)
        financial = try? c.decodeIfPresent(FinancialDto.self, forKey: .financial)
        itemsCount = c.lenientInt(.itemsCount)
        receptionCenters = c.lossyList(ReceptionCenterDto.self, .receptionCenters)
    }
}

struct PrefactorConsignmentEntry: Identifiable {
    let key: String
    let value: ConsignmentInfoDto
    var id: String { key }
}

/// نقشه‌ی مرسوله‌ها (کلید «main» یا شناسه‌ی فروشنده)؛ PHP آرایه‌ی خالی رو [] می‌فرسته - پس تحمل‌پذیر.
/// (تفاوت iOS: Dictionary ترتیب کلیدها رو نگه نمی‌داره؛ «main» اول و بقیه به ترتیب شناسه مرتب می‌شن)
private func decodePrefactorConsignments<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> [PrefactorConsignmentEntry]? {
    guard c.contains(key), (try? c.decodeNil(forKey: key)) != true else { return nil }
    if let map = try? c.decode([String: JSONValueBox<ConsignmentInfoDto>].self, forKey: key) {
        return map.compactMap { k, v in v.value.map { PrefactorConsignmentEntry(key: k, value: $0) } }
            .sorted { a, b in
                if a.key == "main" { return b.key != "main" }
                if b.key == "main" { return false }
                if let x = Int(a.key), let y = Int(b.key) { return x < y }
                return a.key < b.key
            }
    }
    if let list = try? c.decode([JSONValueBox<ConsignmentInfoDto>].self, forKey: key) {
        return list.enumerated().compactMap { i, v in v.value.map { PrefactorConsignmentEntry(key: String(i), value: $0) } }
    }
    return nil
}

struct PrefactorInfoDto: ShkDTO {
    let id: Int
    let uuid: String
    let title: String?
    let jalaliExpiredAt: [JSONValue]?
    enum CodingKeys: String, CodingKey { case id, uuid, title, jalaliExpiredAt = "jalali_expired_at" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        uuid = c.lenientString(.uuid) ?? ""
        title = c.lenientString(.title)
        jalaliExpiredAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliExpiredAt)
    }
}

struct ConsignmentInfoDto: ShkDTO {
    let uuid: String?
    let sendMethod: [String: JSONValue]?
    let postWays: [PostWayDto]?
    let items: [PrefactorItemDto]?
    let sendPrice: Int64?
    enum CodingKeys: String, CodingKey { case uuid, sendMethod = "send_method", postWays = "get_post_ways", items, sendPrice }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenientString(.uuid)
        sendMethod = try? c.decodeIfPresent([String: JSONValue].self, forKey: .sendMethod)
        postWays = c.lossyList(PostWayDto.self, .postWays)
        items = c.lossyList(PrefactorItemDto.self, .items)
        sendPrice = c.lenientInt64(.sendPrice)
    }
}

struct PrefactorItemDto: ShkDTO, Identifiable {
    let id: Int
    let price: Int64
    let discount: Int64?
    let count: Int
    let props: [CartPropDto]?
    let fullCountPrice: Int64?
    let product: PrefactorItemProductDto?
    enum CodingKeys: String, CodingKey {
        case id, price, discount, count, props = "get_props", fullCountPrice = "get_full_count_price", product
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        price = c.lenientInt64(.price) ?? 0
        discount = c.lenientInt64(.discount)
        count = c.lenientInt(.count) ?? 0
        props = c.lossyList(CartPropDto.self, .props)
        fullCountPrice = c.lenientInt64(.fullCountPrice)
        product = try? c.decodeIfPresent(PrefactorItemProductDto.self, forKey: .product)
    }
}

struct PrefactorItemProductDto: ShkDTO {
    let title: String?
    let slug: String?
    let images: [ProductImageDto]?
    var mainImageUrl: String? { images?.first?.link }
    enum CodingKeys: String, CodingKey { case title, slug, images = "get_images" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.lenientString(.title)
        slug = c.lenientString(.slug)
        images = c.lossyList(ProductImageDto.self, .images)
    }
}

struct PrefactorGatewaysResponse: ShkDTO {
    let status: String
    let gateways: [PaymentGatewayDto]
    enum CodingKeys: String, CodingKey { case status, gateways }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        // PrefactorGatewayDto اندروید همون فیلدهای PaymentGatewayDto (id/label/icon/bank_details) رو داره
        gateways = c.lossyList(PaymentGatewayDto.self, .gateways) ?? []
    }
}

/// PrefactorPayResponse اندروید دقیقاً همون کلیدهای PayResponse رو داره
typealias PrefactorPayResponse = PayResponse
