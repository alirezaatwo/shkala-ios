import Foundation

// معادل data/remote/dto/CartDto.kt اپ اندروید

struct CartResponse: ShkDTO {
    let status: String
    let items: [CartItemDto]
    let totalPrice: Int64
    let totalDiscount: Int64
    let totalFinalPrice: Int64
    enum CodingKeys: String, CodingKey {
        case status, items, totalPrice = "total_price", totalDiscount = "total_discount", totalFinalPrice = "total_final_price"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        items = c.lossyList(CartItemDto.self, .items) ?? []
        totalPrice = c.lenientInt64(.totalPrice) ?? 0
        totalDiscount = c.lenientInt64(.totalDiscount) ?? 0
        totalFinalPrice = c.lenientInt64(.totalFinalPrice) ?? 0
    }
}

/// پیش‌فاکتور سبد خرید: آدرس امضاشده و موقت صفحه‌ی پیش‌فاکتور سایت برای وب‌ویو
struct CartPrefactorLinkResponse: ShkDTO {
    let status: String?
    let url: String?
    let validHours: Int?
    let expiresIn: Int?
    let message: String?
    enum CodingKeys: String, CodingKey { case status, url, validHours = "valid_hours", expiresIn = "expires_in", message }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        url = c.lenientString(.url)
        validHours = c.lenientInt(.validHours)
        expiresIn = c.lenientInt(.expiresIn)
        message = c.lenientString(.message)
    }
}

struct AddToCartResponse: ShkDTO {
    let status: String
    let message: String?
    let item: CartItemDto?
    enum CodingKeys: String, CodingKey { case status, message, item }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        item = try? c.decodeIfPresent(CartItemDto.self, forKey: .item)
    }
}

struct CartItemResponse: ShkDTO {
    let status: String
    let item: CartItemDto?
    enum CodingKeys: String, CodingKey { case status, item }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        item = try? c.decodeIfPresent(CartItemDto.self, forKey: .item)
    }
}

struct CartPropDto: Decodable, Equatable {
    let id: Int?
    let name: String?
    let type: String?
    let value: JSONValue?
    enum CodingKeys: String, CodingKey { case id, name, type, value }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id)
        name = c.lenientString(.name)
        type = c.lenientString(.type)
        value = try? c.decodeIfPresent(JSONValue.self, forKey: .value)
    }

    /// بعضی ویژگی‌ها (مثل رنگ) مقدارشون یه شیء کامله، نه یه متن ساده
    var displayValue: String? {
        switch value {
        case .string(let s): return s
        case .object(let o): return o["label"]?.stringValue ?? o["title"]?.stringValue
        default: return nil
        }
    }

    /// فقط برای ویژگی‌های رنگی - کد رنگ (مثلاً #000000) رو برمی‌گردونه
    var colorHex: String? {
        if case .object(let o) = value { return o["color"]?.stringValue }
        return nil
    }

    var isColorType: Bool { type == "color" }
}

struct CartOptionDto: Decodable, Equatable {
    let id: Int?
    let title: String?
    let price: Double?
    enum CodingKeys: String, CodingKey { case id, title, price }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id)
        title = c.lenientString(.title)
        price = c.lenientDouble(.price)
    }
}

struct CartStoreDto: ShkDTO, Equatable {
    let id: Int
    let name: String?
    enum CodingKeys: String, CodingKey { case id, name }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        name = c.lenientString(.name)
    }
}

struct CartProductDto: ShkDTO, Equatable {
    let id: Int
    let title: String
    let slug: String
    let image: String?
    enum CodingKeys: String, CodingKey { case id, title, slug, image }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        image = c.lenientString(.image)
    }
}

struct CartItemDto: ShkDTO, Equatable, Identifiable {
    let id: Int
    let consignmentId: Int
    let inventoryId: Int
    let count: Int
    let price: Int64
    let discount: Int64
    let maxAvailableCount: Int
    let props: [CartPropDto]?
    let options: [CartOptionDto]?
    let formattedPrice: String?
    let formattedDiscount: String?
    let fullCountPrice: Int64
    let product: CartProductDto?
    let store: CartStoreDto?

    enum CodingKeys: String, CodingKey {
        case id, count, price, discount, product, store
        case consignmentId = "consignment_id", inventoryId = "inventory_id", maxAvailableCount = "max_available_count"
        case props = "get_props", options = "get_options", formattedPrice = "get_formatted_price"
        case formattedDiscount = "get_formatted_discount", fullCountPrice = "get_full_count_price"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        consignmentId = c.lenientInt(.consignmentId) ?? 0
        inventoryId = c.lenientInt(.inventoryId) ?? 0
        count = c.lenientInt(.count) ?? 0
        price = c.lenientInt64(.price) ?? 0
        discount = c.lenientInt64(.discount) ?? 0
        maxAvailableCount = c.lenientInt(.maxAvailableCount) ?? 0
        props = c.lossyList(CartPropDto.self, .props)
        options = c.lossyList(CartOptionDto.self, .options)
        formattedPrice = c.lenientString(.formattedPrice)
        formattedDiscount = c.lenientString(.formattedDiscount)
        fullCountPrice = c.lenientInt64(.fullCountPrice) ?? 0
        product = try? c.decodeIfPresent(CartProductDto.self, forKey: .product)
        store = try? c.decodeIfPresent(CartStoreDto.self, forKey: .store)
    }

    var hasDiscount: Bool { discount > 0 }
    var unitOriginalPrice: Int64 { price + discount }
}
