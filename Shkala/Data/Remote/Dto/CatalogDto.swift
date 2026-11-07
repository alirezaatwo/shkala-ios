import Foundation

// معادل CatalogDto.kt اپ اندروید (data/remote/dto) - همان کلیدهای JSON.
// رمزگشایی مثل Gson تحمل‌پذیره: فیلد نیومده = مقدار پیش‌فرض (null/۰/false)، عدد/رشته جابه‌جا پذیرفته می‌شه.

// ---- دسته‌بندی‌ها ----

struct CategoriesResponse: ShkDTO {
    let status: String?
    let categories: [CategoryDto]

    enum CodingKeys: String, CodingKey { case status, categories }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        categories = c.lossyList(CategoryDto.self, .categories) ?? []
    }
}

struct CategoryDto: ShkDTO, Identifiable, Equatable {
    let id: Int
    let title: String
    let slug: String
    let image: String?
    let level: String
    let childs: [CategoryDto]?

    enum CodingKeys: String, CodingKey { case id, title, slug, image, level, childs }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        image = c.lenientString(.image)
        level = c.lenientString(.level) ?? ""
        childs = c.lossyList(CategoryDto.self, .childs)
    }

    init(id: Int, title: String, slug: String, image: String? = nil, level: String = "", childs: [CategoryDto]? = nil) {
        self.id = id; self.title = title; self.slug = slug; self.image = image; self.level = level; self.childs = childs
    }
}

// ---- محصولات ----

struct ProductsResponse: ShkDTO {
    let status: String?
    let products: [ProductListItemDto]
    let pagination: PaginationDto
    // فاز ۲۶ (اصلاحیه): فیلترهای اختصاصی هر دسته‌بندی (dynamics)
    let filters: ProductFiltersDto?

    enum CodingKeys: String, CodingKey { case status, products, pagination, filters }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        products = c.lossyList(ProductListItemDto.self, .products) ?? []
        pagination = (try? c.decodeIfPresent(PaginationDto.self, forKey: .pagination)) ?? PaginationDto()
        filters = try? c.decodeIfPresent(ProductFiltersDto.self, forKey: .filters)
    }
}

struct PaginationDto: ShkDTO, Equatable {
    var currentPage: Int = 0
    var lastPage: Int = 0
    var perPage: Int = 0
    var total: Int = 0

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page", lastPage = "last_page", perPage = "per_page", total
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = c.lenientInt(.currentPage) ?? 0
        lastPage = c.lenientInt(.lastPage) ?? 0
        perPage = c.lenientInt(.perPage) ?? 0
        total = c.lenientInt(.total) ?? 0
    }
}

struct ProductFiltersDto: ShkDTO, Equatable {
    let dynamics: [DynamicFilterDto]
    enum CodingKeys: String, CodingKey { case dynamics }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dynamics = c.lossyList(DynamicFilterDto.self, .dynamics) ?? []
    }
}

struct DynamicFilterDto: ShkDTO, Equatable, Identifiable {
    let id: Int
    let title: String
    let values: [String]
    enum CodingKeys: String, CodingKey { case id, title, values }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        values = c.lossyList(String.self, .values) ?? []
    }
}

struct ProductImageDto: ShkDTO, Equatable {
    let link: String
    let alt: String?
    enum CodingKeys: String, CodingKey { case link, alt }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        link = c.lenientString(.link) ?? ""
        alt = c.lenientString(.alt)
    }
}

struct CommentsInfoDto: ShkDTO, Equatable {
    let count: String
    let rating: Double?
    let ratingPercent: Double?
    let suggestionPercent: Double?

    enum CodingKeys: String, CodingKey {
        case count, rating, ratingPercent = "rating_percent", suggestionPercent = "suggation_percent"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = c.lenientString(.count) ?? "0"
        rating = c.lenientDouble(.rating)
        ratingPercent = c.lenientDouble(.ratingPercent)
        suggestionPercent = c.lenientDouble(.suggestionPercent)
    }
}

struct BestNormalPriceDto: ShkDTO, Equatable {
    let price: String?
    let discountPrice: String?
    let percent: Int?

    enum CodingKeys: String, CodingKey { case price, discountPrice = "discount_price", percent }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        price = c.lenientString(.price)
        discountPrice = c.lenientString(.discountPrice)
        percent = c.lenientInt(.percent)
    }
}

struct SimpleBrandDto: ShkDTO, Equatable {
    let id: Int
    let title: String
    let slug: String
    enum CodingKeys: String, CodingKey { case id, title, slug }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
    }
}

struct BestInventoryDto: ShkDTO, Equatable {
    let id: Int?
    let minSale: Int?
    let maxSale: Int?
    let count: Int?
    // اصالت کالا (true=اصل) و وضعیت کالا (true=کارکرده)
    let original: Bool?
    let used: Bool?

    enum CodingKeys: String, CodingKey { case id, minSale = "min_sale", maxSale = "max_sale", count, original, used }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id)
        minSale = c.lenientInt(.minSale)
        maxSale = c.lenientInt(.maxSale)
        count = c.lenientInt(.count)
        original = c.lenientBool(.original)
        used = c.lenientBool(.used)
    }
}

struct ProductListItemDto: ShkDTO, Identifiable, Equatable {
    let id: Int
    let title: String
    let slug: String
    let images: [ProductImageDto]
    let commentsInfo: CommentsInfoDto?
    let inventory: Bool
    let bestNormalPrice: BestNormalPriceDto?
    let bestPrice: Double?
    let isVip: Bool
    let brand: SimpleBrandDto?
    let bestInventory: BestInventoryDto?
    let hasVariants: Bool
    // false = «استعلام موجودی» سایت (فعلاً فقط کارت محصولِ داخل استوری استفاده می‌کنه)
    let inStockStatus: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, slug, images = "get_images", commentsInfo = "comments_info", inventory
        case bestNormalPrice = "best_normal_price", bestPrice = "best_price", isVip = "is_vip", brand
        case bestInventory = "best_inventory", hasVariants = "has_variants", inStockStatus = "in_stock_status"
    }

    init(from decoder: Decoder) throws {
        try self.init(from: decoder, forceInventory: nil)
    }

    /// forceInventory: برای RelatedProductDto که پیش‌فرض inventory اش true هست
    init(from decoder: Decoder, forceInventory: Bool?) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        images = c.lossyList(ProductImageDto.self, .images) ?? []
        commentsInfo = try? c.decodeIfPresent(CommentsInfoDto.self, forKey: .commentsInfo)
        inventory = forceInventory ?? c.lenientBool(.inventory) ?? false
        bestNormalPrice = try? c.decodeIfPresent(BestNormalPriceDto.self, forKey: .bestNormalPrice)
        bestPrice = c.lenientDouble(.bestPrice)
        isVip = c.lenientBool(.isVip) ?? false
        brand = try? c.decodeIfPresent(SimpleBrandDto.self, forKey: .brand)
        bestInventory = try? c.decodeIfPresent(BestInventoryDto.self, forKey: .bestInventory)
        hasVariants = c.lenientBool(.hasVariants) ?? false
        inStockStatus = c.lenientBool(.inStockStatus)
    }

    var hasDiscount: Bool { !(bestNormalPrice?.discountPrice?.isBlankShk ?? true) }

    var mainImageUrl: String? { images.first?.link }

    var minQuantity: Int {
        if let m = bestInventory?.minSale, m > 0 { return m }
        return 1
    }

    var maxQuantity: Int { min(bestInventory?.maxSale ?? Int.max, bestInventory?.count ?? Int.max) }
}

struct HomeProductListResponse: ShkDTO {
    let status: String?
    let products: [ProductListItemDto]?
    enum CodingKeys: String, CodingKey { case status, products }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        products = c.lossyList(ProductListItemDto.self, .products)
    }
}

// ---- فاز ۱۷: بنرهای اسلایدر صفحه‌ی اصلی ----

struct HomeSliderResponse: ShkDTO {
    let status: String?
    let slides: [HomeSlideDto]
    let mobileHeight: Int?
    enum CodingKeys: String, CodingKey { case status, slides, mobileHeight = "mobile_height" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        slides = c.lossyList(HomeSlideDto.self, .slides) ?? []
        mobileHeight = c.lenientInt(.mobileHeight)
    }
}

/// اسلاید اسلایدر / بنر صفحه‌ی اصلی (HomeSlideDto و HomeBannerDto اندروید ساختار یکسانی دارن)
struct HomeSlideDto: ShkDTO, Equatable {
    let image: String?
    let link: String?
    let alt: String?
    enum CodingKeys: String, CodingKey { case image, link, alt }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        image = c.lenientString(.image)
        link = c.lenientString(.link)
        alt = c.lenientString(.alt)
    }
}

typealias HomeBannerDto = HomeSlideDto

// ---- فاز ۱۸: ماژول بنرهای ۴تایی / دوتایی صفحه‌ی اصلی ----

struct HomeBannersResponse: ShkDTO {
    let status: String?
    let banners: [HomeBannerDto]
    enum CodingKeys: String, CodingKey { case status, banners }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        banners = c.lossyList(HomeBannerDto.self, .banners) ?? []
    }
}

extension KeyedDecodingContainer {
    func lenientDouble(_ key: Key) -> Double? {
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return v }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Double(s.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
}
