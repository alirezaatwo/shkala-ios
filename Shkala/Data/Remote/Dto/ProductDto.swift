import Foundation

// معادل بخش محصول CatalogDto.kt + InventoryDto.kt + ProductExtrasDto.kt + ProductCommentsDto.kt +
// ProductQuestionsDto.kt اپ اندروید (صفحه‌ی محصول)

// MARK: - جزئیات محصول

struct ProductDetailResponse: ShkDTO {
    let status: String
    let product: ProductDetailDto
    enum CodingKeys: String, CodingKey { case status, product }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        product = try c.decode(ProductDetailDto.self, forKey: .product)
    }
}

struct ProductTabDto: Decodable, Equatable {
    let title: String
    let content: String?
    enum CodingKeys: String, CodingKey { case title, content }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.lenientString(.title) ?? ""
        content = c.lenientString(.content)
    }
}

struct SpecificationKeyDto: Decodable, Equatable, Hashable {
    let id: Int
    let key: String
    let value: String?
    enum CodingKeys: String, CodingKey { case id, key, value }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        key = c.lenientString(.key) ?? ""
        value = c.lenientString(.value)
    }
}

struct SpecificationGroupDto: Decodable, Equatable, Hashable {
    let id: Int
    let title: String
    let keys: [SpecificationKeyDto]
    enum CodingKeys: String, CodingKey { case id, title, keys }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        keys = c.lossyList(SpecificationKeyDto.self, .keys) ?? []
    }
}

/// فاز PA: یک ردیف از «خصوصیات برجسته»ی محصول (get_attrs خودِ اسکریپت: key/value)
struct ProductFeatureDto: Decodable, Equatable {
    let key: String?
    let value: String?
    enum CodingKeys: String, CodingKey { case key, value }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = c.lenientString(.key)
        value = c.lenientString(.value)
    }
}

/**
 * A14: یک درگاه پرداخت قسطیِ فعال (اسنپ‌پی، ترب‌پی، دیجی‌پی) برای کارت «هر قسط با ...» زیر دکمه‌ی
 * افزودن به سبد (product.installment_gateways - app/Services/Main/Products/InstallmentCards.php).
 * name = نام کوتاه، title = برچسب کامل مثل «هر قسط با اسنپ‌پی:»، max_amount = سقف مبلغ درگاه (تومان).
 */
struct InstallmentGatewayDto: ShkDTO, Equatable {
    let id: String?
    let name: String?
    let title: String?
    let description: String?
    let icon: String?
    let installments: Int?
    let maxAmount: Int64?

    enum CodingKeys: String, CodingKey {
        case id, name, title, description, icon, installments
        case maxAmount = "max_amount"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id)
        name = c.lenientString(.name)
        title = c.lenientString(.title)
        description = c.lenientString(.description)
        icon = c.lenientString(.icon)
        installments = c.lenientInt(.installments)
        maxAmount = c.lenientInt64(.maxAmount)
    }
}

struct ProductDetailDto: ShkDTO, Equatable {
    let id: Int
    let title: String
    let slug: String
    let content: String?
    let guide: String?
    let images: [ProductImageDto]
    let allImages: [ProductImageDto]?
    let inventory: Bool
    let bestPrice: Double?
    let bestNormalPrice: BestNormalPriceDto?
    let hasDiscount: Bool
    let commentsInfo: CommentsInfoDto?
    let brand: SimpleBrandDto?
    let specifications: [SpecificationGroupDto]?
    let bestInventory: BestInventoryDto?
    let isFavorite: Bool
    // فاز ۷: تب‌های محتوایی اضافه‌ی محصول (راهنمای خرید، گارانتی و...)
    let tabs: [ProductTabDto]?
    // فاز ۲۶: دسته‌بندیِ محصول (همون فرمت brand - id/title/slug)
    let category: SimpleBrandDto?
    // فاز ۳۴ (کد ۱۱): متن هشدار/اطلاعیه‌ی محصول
    let warnings: String?
    // فاز ۳۴ (کد ۱۲): ۰ = تاریخ فارسیِ خوانا، ۱ = Y/m/d، ۲ = ساعت+تاریخ، ۳ = «چند وقت پیش»
    let jalaliUpdatedAt: [String]?
    let titleEn: String?
    let uuid: String?
    let buyerImages: [ProductImageDto]?
    let outstandingFeatures: [ProductFeatureDto]?
    let viewCount: Int64?
    let favoritesCount: Int64?
    let cartCount: Int64?
    let productStatisticsStatus: String?
    // A14: درگاه‌های قسطیِ فعال (کلید افزوده؛ اگه سرور نفرسته، کارت قسطی نمایش داده نمی‌شه)
    let installmentGateways: [InstallmentGatewayDto]?

    enum CodingKeys: String, CodingKey {
        case id, title, slug, content, guide, images, inventory, brand, specifications, tabs, category, warnings, uuid
        case allImages = "all_images", bestPrice = "best_price", bestNormalPrice = "best_normal_price"
        case hasDiscount = "has_discount", commentsInfo = "comments_info", bestInventory = "best_inventory"
        case isFavorite = "is_favorite", jalaliUpdatedAt = "jalali_updated_at", titleEn = "title_en"
        case buyerImages = "get_buyer_images", outstandingFeatures = "outstanding_features"
        case viewCount = "view_count", favoritesCount = "favorites_count", cartCount = "cart_count"
        case productStatisticsStatus = "product_statistics_status"
        case installmentGateways = "installment_gateways"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        content = c.lenientString(.content)
        guide = c.lenientString(.guide)
        images = c.lossyList(ProductImageDto.self, .images) ?? []
        allImages = c.lossyList(ProductImageDto.self, .allImages)
        inventory = c.lenientBool(.inventory) ?? false
        bestPrice = c.lenientDouble(.bestPrice)
        bestNormalPrice = try? c.decodeIfPresent(BestNormalPriceDto.self, forKey: .bestNormalPrice)
        hasDiscount = c.lenientBool(.hasDiscount) ?? false
        commentsInfo = try? c.decodeIfPresent(CommentsInfoDto.self, forKey: .commentsInfo)
        brand = try? c.decodeIfPresent(SimpleBrandDto.self, forKey: .brand)
        specifications = c.lossyList(SpecificationGroupDto.self, .specifications)
        bestInventory = try? c.decodeIfPresent(BestInventoryDto.self, forKey: .bestInventory)
        isFavorite = c.lenientBool(.isFavorite) ?? false
        tabs = c.lossyList(ProductTabDto.self, .tabs)
        category = try? c.decodeIfPresent(SimpleBrandDto.self, forKey: .category)
        warnings = c.lenientString(.warnings)
        jalaliUpdatedAt = c.lossyList(String.self, .jalaliUpdatedAt)
        titleEn = c.lenientString(.titleEn)
        uuid = c.lenientString(.uuid)
        buyerImages = c.lossyList(ProductImageDto.self, .buyerImages)
        outstandingFeatures = c.lossyList(ProductFeatureDto.self, .outstandingFeatures)
        viewCount = c.lenientInt64(.viewCount)
        favoritesCount = c.lenientInt64(.favoritesCount)
        cartCount = c.lenientInt64(.cartCount)
        productStatisticsStatus = c.lenientString(.productStatisticsStatus)
        installmentGateways = c.lossyList(InstallmentGatewayDto.self, .installmentGateways)
    }

    var galleryImages: [ProductImageDto] {
        if let allImages, !allImages.isEmpty { return allImages }
        return images
    }

    var minQuantity: Int {
        if let m = bestInventory?.minSale, m > 0 { return m }
        return 1
    }

    var maxQuantity: Int { min(bestInventory?.maxSale ?? Int.max, bestInventory?.count ?? Int.max) }
}

// MARK: - موجودی‌ها (انتخاب نوع)

struct ProductInventoriesResponse: ShkDTO {
    let status: String
    let inventories: [ProductInventoryDto]
    enum CodingKeys: String, CodingKey { case status, inventories }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        inventories = c.lossyList(ProductInventoryDto.self, .inventories) ?? []
    }
}

struct ProductInventoryDto: Decodable, Equatable, Identifiable {
    let id: Int
    let price: Int64
    let discountPrice: Int64?
    let isDiscountValid: Bool
    let finalPrice: Int64
    let count: Int
    let minSale: Int?
    let maxSale: Int?
    let props: [CartPropDto]

    enum CodingKeys: String, CodingKey {
        case id, price, count, props
        case discountPrice = "discount_price", isDiscountValid = "is_discount_valid", finalPrice = "final_price"
        case minSale = "min_sale", maxSale = "max_sale"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        price = c.lenientInt64(.price) ?? 0
        discountPrice = c.lenientInt64(.discountPrice)
        isDiscountValid = c.lenientBool(.isDiscountValid) ?? false
        finalPrice = c.lenientInt64(.finalPrice) ?? 0
        count = c.lenientInt(.count) ?? 0
        minSale = c.lenientInt(.minSale)
        maxSale = c.lenientInt(.maxSale)
        props = c.lossyList(CartPropDto.self, .props) ?? []
    }

    var minQuantity: Int {
        if let m = minSale, m > 0 { return m }
        return 1
    }

    var maxQuantity: Int { min(maxSale ?? Int.max, count) }

    /// کلید یکتا برای یه ترکیب مشخص از انتخاب‌ها (مثلاً "رنگ:سیاه|گارانتی:۱۲ماهه")
    func selectionKey() -> String {
        props.sorted { ($0.name ?? "") < ($1.name ?? "") }
            .map { "\($0.name ?? "null"):\($0.displayValue ?? "null")" }
            .joined(separator: "|")
    }
}

// MARK: - فروشنده‌ها، محصولات مرتبط و اعلان‌ها (extras)

struct ProductExtrasResponse: ShkDTO, Equatable {
    let status: String?
    let sellers: [ProductSellerDto]
    let relatedProducts: [RelatedProductDto]
    let inStock: Bool
    let hasDiscount: Bool
    // فاز ۲۹ (اصلاحیه): دقیقاً همون $product->inventory که بک‌اند برای اعلان «موجود شدن» چک می‌کنه
    let inventory: Bool
    var hasInventoryNotification: Bool
    var hasDiscountNotification: Bool
    // فاز PA: نام/آیکن فروشگاه اصلی برای موجودی‌های بدون فروشنده
    let mainShop: MainShopDto?

    enum CodingKeys: String, CodingKey {
        case status, sellers, inventory
        case relatedProducts = "related_products", inStock = "in_stock", hasDiscount = "has_discount"
        case hasInventoryNotification = "has_inventory_notification", hasDiscountNotification = "has_discount_notification"
        case mainShop = "main_shop"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        sellers = c.lossyList(ProductSellerDto.self, .sellers) ?? []
        relatedProducts = c.lossyList(RelatedProductDto.self, .relatedProducts) ?? []
        inStock = c.lenientBool(.inStock) ?? true
        hasDiscount = c.lenientBool(.hasDiscount) ?? false
        inventory = c.lenientBool(.inventory) ?? true
        hasInventoryNotification = c.lenientBool(.hasInventoryNotification) ?? false
        hasDiscountNotification = c.lenientBool(.hasDiscountNotification) ?? false
        mainShop = try? c.decodeIfPresent(MainShopDto.self, forKey: .mainShop)
    }
}

/// فاز PA: اطلاعات فروشگاه اصلی (همون چیزی که صفحه‌ی وب برای store == null نشون می‌ده)
struct MainShopDto: ShkDTO, Equatable {
    let name: String?
    let logo: String?
    enum CodingKeys: String, CodingKey { case name, logo }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.lenientString(.name)
        logo = c.lenientString(.logo)
    }
}

struct ProductSellerDto: Decodable, Equatable {
    let inventoryId: Int
    let price: Int64?
    let formattedPrice: String?
    let discountPrice: Int64?
    let formattedDiscountPrice: String?
    let isDiscountValid: Bool
    let finalPrice: Int64?
    let formattedFinalPrice: String?
    let count: Int?
    let minSale: Int?
    let maxSale: Int?
    let rawProps: [String: String]?
    let discountTree: [DiscountTierDto]?
    let customerClubScore: CustomerClubScoreDto?
    // فاز ۶: تاریخچه‌ی قیمت همین موجودی - برای دکمه‌ی «نمودار قیمت»
    let priceChangesChart: PriceChangesChartDto?
    // فاز ۷: برچسب «آخرین به‌روزرسانی قیمت» به‌صورت نسبی
    let priceUpdatedAtAgo: String?
    let store: StoreDto?
    // فاز PA: شرط لیبل «بهترین قیمت در ۳۰ روز گذشته»
    let isBestPrice: Bool?
    // فاز PA: زمان ارسال همین موجودی (send_time اسکریپت؛ خالی = «آماده ارسال»)
    let sendTime: String?

    enum CodingKeys: String, CodingKey {
        case price, count, store
        case inventoryId = "inventory_id", formattedPrice = "get_formatted_price", discountPrice = "discount_price"
        case formattedDiscountPrice = "get_formatted_discount_price", isDiscountValid = "is_discount_valid"
        case finalPrice = "get_final_price", formattedFinalPrice = "get_formatted_final_price"
        case minSale = "min_sale", maxSale = "max_sale", rawProps = "raw_props", discountTree = "discount_tree"
        case customerClubScore = "customer_club_score", priceChangesChart = "price_changes_chart"
        case priceUpdatedAtAgo = "price_updated_at_ago", isBestPrice = "is_best_price", sendTime = "send_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        inventoryId = c.lenientInt(.inventoryId) ?? 0
        price = c.lenientInt64(.price)
        formattedPrice = c.lenientString(.formattedPrice)
        discountPrice = c.lenientInt64(.discountPrice)
        formattedDiscountPrice = c.lenientString(.formattedDiscountPrice)
        isDiscountValid = c.lenientBool(.isDiscountValid) ?? false
        finalPrice = c.lenientInt64(.finalPrice)
        formattedFinalPrice = c.lenientString(.formattedFinalPrice)
        count = c.lenientInt(.count)
        minSale = c.lenientInt(.minSale)
        maxSale = c.lenientInt(.maxSale)
        if case .object(let o)? = try? c.decodeIfPresent(JSONValue.self, forKey: .rawProps) {
            var map: [String: String] = [:]
            for (k, v) in o {
                switch v {
                case .string(let s): map[k] = s
                case .number(let n): map[k] = n == n.rounded() ? String(Int64(n)) : String(n)
                case .bool(let b): map[k] = b ? "true" : "false"
                default: break
                }
            }
            rawProps = map
        } else {
            rawProps = nil
        }
        discountTree = c.lossyList(DiscountTierDto.self, .discountTree)
        customerClubScore = try? c.decodeIfPresent(CustomerClubScoreDto.self, forKey: .customerClubScore)
        priceChangesChart = try? c.decodeIfPresent(PriceChangesChartDto.self, forKey: .priceChangesChart)
        priceUpdatedAtAgo = c.lenientString(.priceUpdatedAtAgo)
        store = try? c.decodeIfPresent(StoreDto.self, forKey: .store)
        isBestPrice = c.lenientBool(.isBestPrice)
        sendTime = c.lenientString(.sendTime)
    }
}

/// تاریخچه‌ی قیمت یک موجودی: دو آرایه‌ی هم‌طول price و date
struct PriceChangesChartDto: ShkDTO, Equatable {
    let price: [Int64]
    let date: [String]
    enum CodingKeys: String, CodingKey { case price, date }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawPrices = c.lossyList(JSONValue.self, .price) ?? []
        price = rawPrices.compactMap { v in
            switch v {
            case .number(let n): return Int64(n)
            case .string(let s): return Int64(s.trimmingCharacters(in: .whitespaces)) ?? Double(s).map { Int64($0) }
            default: return nil
            }
        }
        date = c.lossyList(String.self, .date) ?? []
    }
}

struct NotifyToggleResponse: ShkDTO {
    let status: String?
    let enabled: Bool
    let message: String?
    enum CodingKeys: String, CodingKey { case status, enabled, message }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        enabled = c.lenientBool(.enabled) ?? false
        message = c.lenientString(.message)
    }
}

/// یک پله از قیمت پله‌ای (خرید عمده): از تعداد count به بالا، قیمت واحد price می‌شود.
struct DiscountTierDto: Decodable, Equatable {
    let count: Int?
    let price: Int64?
    enum CodingKeys: String, CodingKey { case count, price }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = c.lenientInt(.count)
        price = c.lenientInt64(.price)
    }
}

struct CustomerClubScoreDto: ShkDTO, Equatable {
    let score: Int64?
    let formattedScore: String?
    enum CodingKeys: String, CodingKey { case score, formattedScore = "formatted_score" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        score = c.lenientInt64(.score)
        formattedScore = c.lenientString(.formattedScore)
    }
}

struct StoreLogoDto: Equatable {
    var id: Int? = nil
    var url: String? = nil
    var alt: String? = nil
}

struct StoreDto: ShkDTO, Equatable {
    let id: Int
    let uuid: String?
    let name: String?
    let bio: String?
    /// accessor get_logo هم رشته (آدرس) و هم شیء می‌تونه باشه - هر دو پشتیبانی می‌شه
    let logo: StoreLogoDto?
    let meta: StoreMetaDto?
    let directPost: Bool

    enum CodingKeys: String, CodingKey { case id, uuid, name, bio, logo = "get_logo", meta = "get_meta", directPost = "direct_post" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        uuid = c.lenientString(.uuid)
        name = c.lenientString(.name)
        bio = c.lenientString(.bio)
        switch try? c.decodeIfPresent(JSONValue.self, forKey: .logo) {
        case .string(let s)?:
            logo = StoreLogoDto(url: s.isBlankShk ? nil : s)
        case .object(let o)?:
            var id: Int? = nil
            if case .number(let n)? = o["id"] { id = Int(n) }
            logo = StoreLogoDto(id: id, url: o["url"]?.stringValue, alt: o["alt"]?.stringValue)
        default:
            logo = nil
        }
        meta = try? c.decodeIfPresent(StoreMetaDto.self, forKey: .meta)
        directPost = c.lenientBool(.directPost) ?? false
    }
}

struct StoreMetaDto: ShkDTO, Equatable {
    let commitmentToSend: Int?
    let returnedPercent: Int?
    let productSatisfaction: Int?
    let commentsCount: Int?
    // مقدار یکی از: '-', 'awful', 'weak', 'average', 'good', 'best'
    let performance: String?
    enum CodingKeys: String, CodingKey {
        case performance
        case commitmentToSend = "commitment_to_send", returnedPercent = "returned_percent"
        case productSatisfaction = "product_satisfaction", commentsCount = "comments_count"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        commitmentToSend = c.lenientInt(.commitmentToSend)
        returnedPercent = c.lenientInt(.returnedPercent)
        productSatisfaction = c.lenientInt(.productSatisfaction)
        commentsCount = c.lenientInt(.commentsCount)
        performance = c.lenientString(.performance)
    }
}

struct RelatedProductDto: Decodable, Equatable, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let inventory: Bool
    let hasVariants: Bool
    /// همون DTO ای که ProductCard اصلی استفاده می‌کنه (toProductListItemDto اندروید) - تا کارت کاروسل
    /// محصولات مرتبط عیناً همون سبک (دکمه‌ی خرید + تنظیم‌کننده‌ی تعداد) رو داشته باشه
    let listItem: ProductListItemDto

    enum CodingKeys: String, CodingKey { case id, title, slug, inventory, hasVariants = "has_variants" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        inventory = c.lenientBool(.inventory) ?? true
        hasVariants = c.lenientBool(.hasVariants) ?? false
        // کلیدهای get_images / comments_info / best_normal_price / best_price / best_inventory / has_variants
        // دقیقاً همون کلیدهای ProductListItemDto هستن
        listItem = try ProductListItemDto(from: decoder, forceInventory: c.lenientBool(.inventory) ?? true)
    }

    func toProductListItemDto() -> ProductListItemDto { listItem }
}

// MARK: - علاقه‌مندی و مقایسه

struct ToggleFavoriteResponse: ShkDTO {
    let status: String
    let isFavorite: Bool
    let message: String?
    enum CodingKeys: String, CodingKey { case status, isFavorite = "is_favorite", message }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        isFavorite = c.lenientBool(.isFavorite) ?? false
        message = c.lenientString(.message)
    }
}

struct CompareListResponse: ShkDTO {
    let status: String?
    let compares: [CompareProductDto]
    enum CodingKeys: String, CodingKey { case status, compares }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        compares = c.lossyList(CompareProductDto.self, .compares) ?? []
    }
}

struct CompareProductDto: Decodable, Equatable {
    let compareId: Int
    let id: Int
    let title: String
    let slug: String
    let images: [ProductImageDto]?
    let inStockStatus: Bool
    let inventory: Bool
    let bestNormalPrice: BestNormalPriceDto?
    let specifications: [SpecificationGroupDto]?
    enum CodingKeys: String, CodingKey {
        case compareId = "compare_id", id, title, slug, inventory
        case images = "get_images", inStockStatus = "in_stock_status", bestNormalPrice = "best_normal_price", specifications = "get_specifications"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        compareId = c.lenientInt(.compareId) ?? 0
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        images = c.lossyList(ProductImageDto.self, .images)
        inStockStatus = c.lenientBool(.inStockStatus) ?? true
        inventory = c.lenientBool(.inventory) ?? true
        bestNormalPrice = try? c.decodeIfPresent(BestNormalPriceDto.self, forKey: .bestNormalPrice)
        specifications = c.lossyList(SpecificationGroupDto.self, .specifications)
    }
}

struct CompareActionResponse: ShkDTO {
    let status: String?
    let message: String?
    enum CodingKeys: String, CodingKey { case status, message }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        message = c.lenientString(.message)
    }
}

// MARK: - دیدگاه‌ها

struct ProductCommentsResponse: ShkDTO {
    let status: String?
    let commentsInfo: CommentsInfoDto?
    let comments: CommentsPageDto?
    // تفکیک امتیازها (۵ تا ۱ ستاره) برای نمودار خلاصه‌ی دیدگاه‌ها
    let ratingBreakdown: [RatingBreakdownDto]?
    // آیا کاربر فعلی این محصول را خریده (برای نمایش امکان افزودن تصویر به دیدگاه)
    let viewerIsBuyer: Bool?
    enum CodingKeys: String, CodingKey {
        case status, comments
        case commentsInfo = "comments_info", ratingBreakdown = "rating_breakdown", viewerIsBuyer = "viewer_is_buyer"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        commentsInfo = try? c.decodeIfPresent(CommentsInfoDto.self, forKey: .commentsInfo)
        comments = try? c.decodeIfPresent(CommentsPageDto.self, forKey: .comments)
        ratingBreakdown = c.lossyList(RatingBreakdownDto.self, .ratingBreakdown)
        viewerIsBuyer = c.lenientBool(.viewerIsBuyer)
    }
}

/// یک ردیف از نمودار تفکیک امتیاز
struct RatingBreakdownDto: Decodable, Equatable {
    let star: Int
    let count: Int
    let percent: Double?
    enum CodingKeys: String, CodingKey { case star, count, percent }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        star = c.lenientInt(.star) ?? 0
        count = c.lenientInt(.count) ?? 0
        percent = c.lenientDouble(.percent)
    }
}

/// تصویر پیوست دیدگاه (خروجی accessor get_images سایت: id/url/alt)
struct CommentImageDto: Decodable, Equatable {
    let id: Int?
    let url: String?
    let alt: String?
    enum CodingKeys: String, CodingKey { case id, url, alt }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id)
        url = c.lenientString(.url)
        alt = c.lenientString(.alt)
    }
}

/// پاسخ فروشگاه به دیدگاه (خروجی accessor get_answer سایت: user.name + content)
struct CommentAnswerDto: ShkDTO, Equatable {
    let userName: String?
    let content: String?
    enum CodingKeys: String, CodingKey { case user, content }
    enum UserKeys: String, CodingKey { case name }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let u = try? c.nestedContainer(keyedBy: UserKeys.self, forKey: .user) {
            userName = u.lenientString(.name)
        } else {
            userName = nil
        }
        content = c.lenientString(.content)
    }
}

/// خروجی paginate لاراول: data + current_page + last_page
struct CommentsPageDto: ShkDTO, Equatable {
    let data: [ProductCommentDto]
    let currentPage: Int
    let lastPage: Int
    enum CodingKeys: String, CodingKey { case data, currentPage = "current_page", lastPage = "last_page" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = c.lossyList(ProductCommentDto.self, .data) ?? []
        currentPage = c.lenientInt(.currentPage) ?? 1
        lastPage = c.lenientInt(.lastPage) ?? 1
    }
}

struct ProductCommentDto: Decodable, Equatable, Identifiable {
    let id: Int
    let content: String?
    let strengths: [String]?
    let weakness: [String]?
    let isBuyer: Bool
    let buySuggest: Int?
    let jalaliCreatedAt: [String]?
    var voteUp: Int
    var voteDown: Int
    let images: [CommentImageDto]?
    let answer: CommentAnswerDto?
    let userName: String?

    enum CodingKeys: String, CodingKey {
        case id, content, user
        case strengths = "get_strengths", weakness = "get_weakness", isBuyer = "is_buyer", buySuggest = "buy_suggest"
        case jalaliCreatedAt = "jalali_created_at", voteUp = "vote_up", voteDown = "vote_down"
        case images = "get_images", answer = "get_answer"
    }
    enum UserKeys: String, CodingKey { case name = "get_name" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        content = c.lenientString(.content)
        strengths = c.lossyList(String.self, .strengths)
        weakness = c.lossyList(String.self, .weakness)
        isBuyer = c.lenientBool(.isBuyer) ?? false
        buySuggest = c.lenientInt(.buySuggest)
        jalaliCreatedAt = c.lossyList(String.self, .jalaliCreatedAt)
        voteUp = c.lenientInt(.voteUp) ?? 0
        voteDown = c.lenientInt(.voteDown) ?? 0
        images = c.lossyList(CommentImageDto.self, .images)
        answer = try? c.decodeIfPresent(CommentAnswerDto.self, forKey: .answer)
        if let u = try? c.nestedContainer(keyedBy: UserKeys.self, forKey: .user) {
            userName = u.lenientString(.name)
        } else {
            userName = nil
        }
    }
}

struct CommentVoteResponse: ShkDTO {
    let status: String?
    let voteUp: Int
    let voteDown: Int
    enum CodingKeys: String, CodingKey { case status, voteUp = "vote_up", voteDown = "vote_down" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        voteUp = c.lenientInt(.voteUp) ?? 0
        voteDown = c.lenientInt(.voteDown) ?? 0
    }
}

// MARK: - پرسش و پاسخ

struct QuestionsInfoDto: ShkDTO, Equatable {
    /// مقدار خام count (عدد یا رشته)
    let count: JSONValue?
    enum CodingKeys: String, CodingKey { case count }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = try? c.decodeIfPresent(JSONValue.self, forKey: .count)
    }
}

struct ProductQuestionsResponse: ShkDTO {
    let status: String?
    let questionsInfo: QuestionsInfoDto?
    let questions: QuestionsPageDto?
    enum CodingKeys: String, CodingKey { case status, questionsInfo = "questions_info", questions }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        questionsInfo = try? c.decodeIfPresent(QuestionsInfoDto.self, forKey: .questionsInfo)
        questions = try? c.decodeIfPresent(QuestionsPageDto.self, forKey: .questions)
    }
}

struct QuestionsPageDto: ShkDTO, Equatable {
    let data: [ProductQuestionDto]
    let currentPage: Int
    let lastPage: Int
    enum CodingKeys: String, CodingKey { case data, currentPage = "current_page", lastPage = "last_page" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = c.lossyList(ProductQuestionDto.self, .data) ?? []
        currentPage = c.lenientInt(.currentPage) ?? 1
        lastPage = c.lenientInt(.lastPage) ?? 1
    }
}

struct ProductQuestionDto: Decodable, Equatable, Identifiable {
    let id: Int
    let question: String?
    let answers: [QuestionAnswerDto]
    enum CodingKeys: String, CodingKey { case id, question, answers }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        question = c.lenientString(.question)
        answers = c.lossyList(QuestionAnswerDto.self, .answers) ?? []
    }
}

struct QuestionAnswerDto: Decodable, Equatable, Identifiable {
    let id: Int
    let answer: String?
    let isBuyer: Bool
    let voteUp: Int
    let voteDown: Int
    let status: String?
    let userName: String?
    let userType: String?
    let userIsSeller: Bool
    enum CodingKeys: String, CodingKey { case id, answer, isBuyer = "is_buyer", voteUp = "vote_up", voteDown = "vote_down", status, user }
    enum UserKeys: String, CodingKey { case name = "get_name", type, seller }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        answer = c.lenientString(.answer)
        isBuyer = c.lenientBool(.isBuyer) ?? false
        voteUp = c.lenientInt(.voteUp) ?? 0
        voteDown = c.lenientInt(.voteDown) ?? 0
        status = c.lenientString(.status)
        if let u = try? c.nestedContainer(keyedBy: UserKeys.self, forKey: .user) {
            userName = u.lenientString(.name)
            userType = u.lenientString(.type)
            userIsSeller = u.lenientBool(.seller) ?? false
        } else {
            userName = nil
            userType = nil
            userIsSeller = false
        }
    }
}

struct SubmitResponse: ShkDTO {
    let status: String?
    let published: Bool
    let message: String?
    enum CodingKeys: String, CodingKey { case status, published, message }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        published = c.lenientBool(.published) ?? false
        message = c.lenientString(.message)
    }
}

/// فاز ۹: جست‌وجوی محصول هم‌دسته برای افزودن به مقایسه
struct CompareSearchResponse: ShkDTO {
    let status: String?
    let products: CompareSearchPageDto?
    enum CodingKeys: String, CodingKey { case status, products }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        products = try? c.decodeIfPresent(CompareSearchPageDto.self, forKey: .products)
    }
}

struct CompareSearchPageDto: ShkDTO {
    let currentPage: Int
    let lastPage: Int
    let data: [CompareSearchProductDto]
    enum CodingKeys: String, CodingKey { case currentPage = "current_page", lastPage = "last_page", data }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = c.lenientInt(.currentPage) ?? 1
        lastPage = c.lenientInt(.lastPage) ?? 1
        data = c.lossyList(CompareSearchProductDto.self, .data) ?? []
    }
}

struct CompareSearchProductDto: ShkDTO, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let images: [ProductImageDto]?
    let bestNormalPrice: BestNormalPriceDto?
    let inventory: Bool
    enum CodingKeys: String, CodingKey { case id, title, slug, inventory, images = "get_images", bestNormalPrice = "best_normal_price" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        images = c.lossyList(ProductImageDto.self, .images)
        bestNormalPrice = try? c.decodeIfPresent(BestNormalPriceDto.self, forKey: .bestNormalPrice)
        inventory = c.lenientBool(.inventory) ?? true
    }
}
