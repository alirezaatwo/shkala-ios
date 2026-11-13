import Foundation

// ===================================================================================
// معادل HomeExtrasDto.kt + TrustSealDto.kt اپ اندروید - ماژول‌های جدید صفحه‌ی اصلی:
//  - GET api/v2/home/in-carts-now : «همین لحظه در سبد خرید دیگران»
//  - GET api/v2/home/ui           : رنگ‌های ماژول «پیشنهاد شگفت‌انگیز» (از پنل)
//  - GET api/v2/home/amazing-offer: پیشنهاد شگفت‌انگیز (ماژول ProductList1 قالب فعال سایت)
//  - GET api/v2/stories           : استوری‌های سایت (همون کلید روشن/خاموش اسکریپت)
//  - POST api/v2/stories/{id}/like
//  - GET api/v2/site-info/trust-seals و social-links: انتهای منوی همبرگری
// ===================================================================================

struct InCartsNowResponse: ShkDTO {
    let status: String?
    let products: [ProductListItemDto]?
    // کمتر از این تعداد = ماژول نمایش داده نمی‌شه
    let minCount: Int?
    // تعداد کارت‌های کاروسل؛ بیشتر از این = دکمه‌ی «بیشتر»
    let carouselLimit: Int?

    enum CodingKeys: String, CodingKey { case status, products, minCount = "min_count", carouselLimit = "carousel_limit" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        products = c.lossyList(ProductListItemDto.self, .products)
        minCount = c.lenientInt(.minCount)
        carouselLimit = c.lenientInt(.carouselLimit)
    }
}

struct HomeUiResponse: ShkDTO {
    let status: String?
    // null = ماژول خاموش در پنل → رنگ‌های پیش‌فرض اپ
    let amazingOfferColors: AmazingOfferColorsDto?

    enum CodingKeys: String, CodingKey { case status, amazingOfferColors = "amazing_offer_colors" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        amazingOfferColors = try? c.decodeIfPresent(AmazingOfferColorsDto.self, forKey: .amazingOfferColors)
    }
}

struct AmazingOfferColorsDto: ShkDTO, Equatable {
    let light: AmazingOfferThemeColorsDto?
    let dark: AmazingOfferThemeColorsDto?
    enum CodingKeys: String, CodingKey { case light, dark }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        light = try? c.decodeIfPresent(AmazingOfferThemeColorsDto.self, forKey: .light)
        dark = try? c.decodeIfPresent(AmazingOfferThemeColorsDto.self, forKey: .dark)
    }
}

/// هر رنگ «#RRGGBB» یا null (= رنگ پیش‌فرض اپ)
struct AmazingOfferThemeColorsDto: ShkDTO, Equatable {
    let background: String?
    let title: String?
    let titleBar: String?
    let buttonBackground: String?
    let buttonText: String?
    let arrowsBackground: String?
    let arrowsIcon: String?

    enum CodingKeys: String, CodingKey {
        case background, title, titleBar = "title_bar", buttonBackground = "button_background"
        case buttonText = "button_text", arrowsBackground = "arrows_background", arrowsIcon = "arrows_icon"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        background = c.lenientString(.background)
        title = c.lenientString(.title)
        titleBar = c.lenientString(.titleBar)
        buttonBackground = c.lenientString(.buttonBackground)
        buttonText = c.lenientString(.buttonText)
        arrowsBackground = c.lenientString(.arrowsBackground)
        arrowsIcon = c.lenientString(.arrowsIcon)
    }
}

struct StoriesResponse: ShkDTO {
    let status: String?
    // کلید «نمایش استوری‌ها» پنل ادمین اسکریپت
    let enabled: Bool?
    let stories: [StoryDto]?

    enum CodingKeys: String, CodingKey { case status, enabled, stories }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        enabled = c.lenientBool(.enabled)
        stories = c.lossyList(StoryDto.self, .stories)
    }
}

struct StoryDto: ShkDTO, Identifiable, Equatable {
    let id: Int
    // image | video
    let type: String?
    let title: String?
    let cover: String?
    let file: String?
    var like: Int?
    var isLiked: Bool?
    // همون متن «... پیش» سایت
    let createdAgo: String?
    let link: StoryLinkDto?
    let product: ProductListItemDto?

    var isVideo: Bool { type == "video" }

    enum CodingKeys: String, CodingKey {
        case id, type, title, cover, file, like, isLiked = "is_liked", createdAgo = "created_ago", link, product
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        type = c.lenientString(.type)
        title = c.lenientString(.title)
        cover = c.lenientString(.cover)
        file = c.lenientString(.file)
        like = c.lenientInt(.like)
        isLiked = c.lenientBool(.isLiked)
        createdAgo = c.lenientString(.createdAgo)
        link = try? c.decodeIfPresent(StoryLinkDto.self, forKey: .link)
        product = try? c.decodeIfPresent(ProductListItemDto.self, forKey: .product)
    }
}

struct StoryLinkDto: ShkDTO, Equatable {
    let title: String?
    let url: String?
    enum CodingKeys: String, CodingKey { case title, url }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = c.lenientString(.title)
        url = c.lenientString(.url)
    }
}

struct StoryLikeResponse: ShkDTO {
    let status: String?
    let like: Int?
    let isLiked: Bool?
    enum CodingKeys: String, CodingKey { case status, like, isLiked = "is_liked" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        like = c.lenientInt(.like)
        isLiked = c.lenientBool(.isLiked)
    }
}

/**
 * ۳.۳: GET api/v2/home/category-tabs - همه‌ی ماژول‌های «تب دسته‌ها با فیلتر» (ProductList6) قالب فعال سایت،
 * با ترتیب تب‌ها دقیقاً همون ترتیبی که مدیر در صفحه‌ساز با کشیدن تعیین کرده (api_contract §23).
 */
struct HomeCategoryTabsResponse: ShkDTO {
    let status: String?
    let modules: [HomeCategoryTabsModuleDto]?

    enum CodingKeys: String, CodingKey { case status, modules }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        modules = c.lossyList(HomeCategoryTabsModuleDto.self, .modules)
    }
}

struct HomeCategoryTabsModuleDto: ShkDTO {
    let id: String?
    let title: String?
    let filter: String?
    let tabs: [HomeCategoryTabDto]?

    enum CodingKeys: String, CodingKey { case id, title, filter, tabs }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id)
        title = c.lenientString(.title)
        filter = c.lenientString(.filter)
        tabs = c.lossyList(HomeCategoryTabDto.self, .tabs)
    }
}

struct HomeCategoryTabDto: ShkDTO {
    let id: Int?
    let title: String?
    let slug: String?
    let url: String?
    let products: [ProductListItemDto]?

    enum CodingKeys: String, CodingKey { case id, title, slug, url, products }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id)
        title = c.lenientString(.title)
        slug = c.lenientString(.slug)
        url = c.lenientString(.url)
        products = c.lossyList(ProductListItemDto.self, .products)
    }
}

// پیشنهاد شگفت‌انگیز = ماژول ProductList1 قالب فعال سایت (همون منبع و همون محصولات صفحه‌ی اصلی سایت)
struct AmazingOfferResponse: ShkDTO {
    // false = قالب سایت این ماژول رو نداره (سایت هم نشونش نمی‌ده)
    let found: Bool?
    // عنوان همون ماژول در سایت (نام دسته یا لیست)
    let title: String?
    let source: AmazingOfferSourceDto?
    let products: [ProductListItemDto]?

    enum CodingKeys: String, CodingKey { case found, title, source, products }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        found = c.lenientBool(.found)
        title = c.lenientString(.title)
        source = try? c.decodeIfPresent(AmazingOfferSourceDto.self, forKey: .source)
        products = c.lossyList(ProductListItemDto.self, .products)
    }
}

struct AmazingOfferSourceDto: ShkDTO, Equatable {
    // category | list
    let type: String?
    // پارامترهای دکمه‌ی «مشاهده محصولات» سایت: cat=slug یا discount/latest/most_viewed/popular/most_sale/vip = true
    let archive: [String: JSONValue]?
    // آدرس کامل همون دکمه در سایت (/products?...)
    let url: String?

    enum CodingKeys: String, CodingKey { case type, archive, url }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = c.lenientString(.type)
        archive = try? c.decodeIfPresent([String: JSONValue].self, forKey: .archive)
        url = c.lenientString(.url)
    }

    var categorySlug: String? {
        guard let s = archive?["cat"]?.stringValue, !s.isBlankShk else { return nil }
        return s
    }

    func hasFlag(_ key: String) -> Bool {
        switch archive?[key] {
        case .bool(true): return true
        case .string("1"): return true
        case .number(1): return true
        default: return false
        }
    }
}

// ---- فاز ۳۱: نمادهای اعتماد و لینک‌های شبکه‌های اجتماعی - انتهای منوی همبرگری ----

struct TrustSealsResponse: ShkDTO {
    let status: String?
    let seals: [TrustSealDto]?
    enum CodingKeys: String, CodingKey { case status, seals }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        seals = c.lossyList(TrustSealDto.self, .seals)
    }
}

struct TrustSealDto: ShkDTO, Equatable {
    let name: String
    let label: String
    let imageUrl: String
    let verifyUrl: String
    enum CodingKeys: String, CodingKey { case name, label, imageUrl = "image_url", verifyUrl = "verify_url" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.lenientString(.name) ?? ""
        label = c.lenientString(.label) ?? ""
        imageUrl = c.lenientString(.imageUrl) ?? ""
        verifyUrl = c.lenientString(.verifyUrl) ?? ""
    }
}

struct SocialLinksResponse: ShkDTO, Equatable {
    let status: String?
    let instagram: String?
    let telegramPhone: String?
    let whatsappPhone: String?
    let baleSupport: String?
    enum CodingKeys: String, CodingKey {
        case status, instagram, telegramPhone = "telegram_phone", whatsappPhone = "whatsapp_phone", baleSupport = "bale_support"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        instagram = c.lenientString(.instagram)
        telegramPhone = c.lenientString(.telegramPhone)
        whatsappPhone = c.lenientString(.whatsappPhone)
        baleSupport = c.lenientString(.baleSupport)
    }
}
