import Foundation

// معادل data/remote/dto/OrderDto.kt اپ اندروید (بخش سفارش‌ها)

// ---- لیست سفارش‌ها ----

struct OrdersListResponse: ShkDTO {
    let status: String
    let orderGroups: [OrderGroupDto]
    let pagination: SimplePaginationDto?
    // سفارش‌های ردشده‌ی کارت‌به‌کارت/هماهنگی (فقط صفحه‌ی ۱؛ نسخه‌ی قدیمی API = null)
    let rejectedOrders: [RejectedOrderDto]?
    enum CodingKeys: String, CodingKey { case status, orderGroups = "order_groups", pagination, rejectedOrders = "rejected_orders" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        orderGroups = c.lossyList(OrderGroupDto.self, .orderGroups) ?? []
        pagination = try? c.decodeIfPresent(SimplePaginationDto.self, forKey: .pagination)
        rejectedOrders = c.lossyList(RejectedOrderDto.self, .rejectedOrders)
    }
}

/**
 * سفارش ردشده (اسکریپت خودِ سفارش رو هنگام رد حذف می‌کنه؛ این یک نسخه‌ی ذخیره‌شده‌ست).
 * method: card_to_card | coordinated - amount به تومان
 */
struct RejectedOrderDto: ShkDTO, Equatable, Identifiable {
    let uuid: String?
    let method: String?
    let amount: Int64?
    let jalaliCreatedAt: String?
    let jalaliRejectedAt: String?
    let reason: String?
    let items: [RejectedOrderItemDto]?
    // فقط برای نمایش شیت (شناسه‌ی یکتای محلی)
    let id = UUID()
    enum CodingKeys: String, CodingKey {
        case uuid, method, amount, reason, items
        case jalaliCreatedAt = "jalali_created_at", jalaliRejectedAt = "jalali_rejected_at"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uuid = c.lenientString(.uuid)
        method = c.lenientString(.method)
        amount = c.lenientInt64(.amount)
        jalaliCreatedAt = c.lenientString(.jalaliCreatedAt)
        jalaliRejectedAt = c.lenientString(.jalaliRejectedAt)
        reason = c.lenientString(.reason)
        items = c.lossyList(RejectedOrderItemDto.self, .items)
    }
}

struct RejectedOrderItemDto: ShkDTO, Equatable {
    let title: String?
    let image: String?
    let count: Int?
    enum CodingKeys: String, CodingKey { case title, image, count }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.lenientString(.title)
        image = c.lenientString(.image)
        count = c.lenientInt(.count)
    }
}

struct SimplePaginationDto: ShkDTO {
    let currentPage: Int
    let lastPage: Int
    let total: Int
    enum CodingKeys: String, CodingKey { case currentPage = "current_page", lastPage = "last_page", total }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = c.lenientInt(.currentPage) ?? 1
        lastPage = c.lenientInt(.lastPage) ?? 1
        total = c.lenientInt(.total) ?? 0
    }
}

struct OrderGroupDto: ShkDTO {
    let id: Int
    let uuid: String
    let status: String
    let jalaliCreatedAt: [JSONValue]?
    var orders: [OrderSummaryDto]
    enum CodingKeys: String, CodingKey { case id, uuid, status, jalaliCreatedAt = "jalali_created_at", orders }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        uuid = c.lenientString(.uuid) ?? ""
        status = c.lenientString(.status) ?? ""
        jalaliCreatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliCreatedAt)
        orders = c.lossyList(OrderSummaryDto.self, .orders) ?? []
    }
}

struct OrderSummaryDto: ShkDTO, Identifiable {
    let id: Int
    let uuid: String
    let sendBy: String?
    let status: String
    let jalaliCreatedAt: [JSONValue]?
    // فیلدهای افزوده (API خودمون): مرحله‌ی شروع پردازش، زمان ارسال/آخرین تغییر (epoch ثانیه)، دلیل لغو
    let startProcess: Bool?
    let sentAtTimestamp: Int64?
    let updatedAtTimestamp: Int64?
    let cancelReason: String?
    enum CodingKeys: String, CodingKey {
        case id, uuid, status, sendBy = "get_send_by", jalaliCreatedAt = "jalali_created_at"
        case startProcess = "start_process", sentAtTimestamp = "sent_at_timestamp"
        case updatedAtTimestamp = "updated_at_timestamp", cancelReason = "cancel_reason"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        uuid = c.lenientString(.uuid) ?? ""
        sendBy = c.lenientString(.sendBy)
        status = c.lenientString(.status) ?? ""
        jalaliCreatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliCreatedAt)
        startProcess = c.lenientBool(.startProcess)
        sentAtTimestamp = c.lenientInt64(.sentAtTimestamp)
        updatedAtTimestamp = c.lenientInt64(.updatedAtTimestamp)
        cancelReason = c.lenientString(.cancelReason)
    }
}

// ---- جزئیات سفارش ----

struct OrderDetailResponse: ShkDTO {
    let status: String
    let message: String?
    let order: OrderDetailDto?
    enum CodingKeys: String, CodingKey { case status, message, order }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        order = try? c.decodeIfPresent(OrderDetailDto.self, forKey: .order)
    }
}

struct OrderDetailDto: ShkDTO {
    let id: Int
    let uuid: String
    let orderGroupUuid: String
    let address: [String: JSONValue]?
    let postTrackingCode: String?
    let totalBill: TotalBillDto?
    let vaTaxPercent: Int?
    let taxAmount: Int64?
    let sendMethod: [String: JSONValue]?
    let paymentGatewayLabel: String?
    let hasReceipt: Bool?
    let sendTime: String?
    let isAllItemCancelled: Bool?
    let description: String?
    let jalaliCreatedAt: [JSONValue]?
    let status: String
    let consignments: [OrderConsignmentDto]
    // فیلدهای افزوده (API خودمون) - مثل لیست
    let startProcess: Bool?
    let sentAtTimestamp: Int64?
    let updatedAtTimestamp: Int64?
    let cancelReason: String?
    enum CodingKeys: String, CodingKey {
        case id, uuid, description, status, consignments
        case orderGroupUuid = "order_group_uuid", address = "get_address", postTrackingCode = "post_tracking_code"
        case totalBill = "get_total_bill", vaTaxPercent = "va_tax_percent", taxAmount = "tax_amount"
        case sendMethod = "get_send_method", paymentGatewayLabel = "payment_gateway_label", hasReceipt = "has_receipt"
        case sendTime = "send_time", isAllItemCancelled = "is_all_item_cancelled", jalaliCreatedAt = "jalali_created_at"
        case startProcess = "start_process", sentAtTimestamp = "sent_at_timestamp"
        case updatedAtTimestamp = "updated_at_timestamp", cancelReason = "cancel_reason"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        uuid = c.lenientString(.uuid) ?? ""
        orderGroupUuid = c.lenientString(.orderGroupUuid) ?? ""
        address = try? c.decodeIfPresent([String: JSONValue].self, forKey: .address)
        postTrackingCode = c.lenientString(.postTrackingCode)
        totalBill = try? c.decodeIfPresent(TotalBillDto.self, forKey: .totalBill)
        vaTaxPercent = c.lenientInt(.vaTaxPercent)
        taxAmount = c.lenientInt64(.taxAmount)
        sendMethod = try? c.decodeIfPresent([String: JSONValue].self, forKey: .sendMethod)
        paymentGatewayLabel = c.lenientString(.paymentGatewayLabel)
        hasReceipt = c.lenientBool(.hasReceipt)
        sendTime = c.lenientString(.sendTime)
        isAllItemCancelled = c.lenientBool(.isAllItemCancelled)
        description = c.lenientString(.description)
        jalaliCreatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliCreatedAt)
        status = c.lenientString(.status) ?? ""
        consignments = c.lossyList(OrderConsignmentDto.self, .consignments) ?? []
        startProcess = c.lenientBool(.startProcess)
        sentAtTimestamp = c.lenientInt64(.sentAtTimestamp)
        updatedAtTimestamp = c.lenientInt64(.updatedAtTimestamp)
        cancelReason = c.lenientString(.cancelReason)
    }
}

/** get_total_bill یه شیء ریزه، نه یه عدد ساده - قیمت، تخفیف، و هزینه‌ی ارسال جدا داره */
struct TotalBillDto: ShkDTO {
    let price: Int64?
    let discount: Int64?
    let sendPrice: Int64?
    enum CodingKeys: String, CodingKey { case price, discount, sendPrice = "send_price" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        price = c.lenientInt64(.price)
        discount = c.lenientInt64(.discount)
        sendPrice = c.lenientInt64(.sendPrice)
    }
}

/** خیلی از accessor های تاریخ این پروژه، یه آرایه‌ی ۵تایی (چند فرمت مختلف) برمی‌گردونن؛
 * عنصر اول همیشه فرمت خوانا و فارسی‌شده‌ست (مثلاً «۲۲ شهریور ۱۴۰۵») */
extension Optional where Wrapped == [JSONValue] {
    func jalaliDateLabel() -> String? { self?.first?.stringValue }
}

struct InvoiceBridgeResponse: ShkDTO {
    let status: String
    let message: String?
    let bridgeUrl: String?
    let invoiceUrl: String?
    enum CodingKeys: String, CodingKey { case status, message, bridgeUrl = "bridge_url", invoiceUrl = "invoice_url" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        bridgeUrl = c.lenientString(.bridgeUrl)
        invoiceUrl = c.lenientString(.invoiceUrl)
    }
}

struct OrderConsignmentDto: ShkDTO, Identifiable {
    let id: Int
    let status: String
    let items: [OrderConsignmentItemDto]
    let store: OrderStoreDto?
    enum CodingKeys: String, CodingKey { case id, status, items = "consignment_items", store }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        status = c.lenientString(.status) ?? ""
        items = c.lossyList(OrderConsignmentItemDto.self, .items) ?? []
        store = try? c.decodeIfPresent(OrderStoreDto.self, forKey: .store)
    }
}

struct OrderStoreDto: ShkDTO {
    let id: Int
    let name: String?
    enum CodingKeys: String, CodingKey { case id, name }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        name = c.lenientString(.name)
    }
}

struct OrderConsignmentItemDto: ShkDTO, Identifiable {
    let id: Int
    let title: String
    let props: [CartPropDto]?
    let options: [CartOptionDto]?
    let price: Int64?
    let discount: Int64?
    let fullCountPrice: Int64
    let count: Int
    let reason: String?
    let status: String
    let product: OrderProductDto?
    enum CodingKeys: String, CodingKey {
        case id, title, price, discount, count, reason, status, product
        case props = "get_props", options = "get_options", fullCountPrice = "get_full_count_price"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        props = c.lossyList(CartPropDto.self, .props)
        options = c.lossyList(CartOptionDto.self, .options)
        price = c.lenientInt64(.price)
        discount = c.lenientInt64(.discount)
        fullCountPrice = c.lenientInt64(.fullCountPrice) ?? 0
        count = c.lenientInt(.count) ?? 0
        reason = c.lenientString(.reason)
        status = c.lenientString(.status) ?? ""
        product = try? c.decodeIfPresent(OrderProductDto.self, forKey: .product)
    }
}

struct OrderProductDto: ShkDTO {
    let id: Int
    let uuid: String?
    let title: String
    let slug: String
    let images: [ProductImageDto]?
    enum CodingKeys: String, CodingKey { case id, uuid, title, slug, images = "get_images" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        uuid = c.lenientString(.uuid)
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        images = c.lossyList(ProductImageDto.self, .images)
    }

    var mainImageUrl: String? { images?.first?.link }
}
