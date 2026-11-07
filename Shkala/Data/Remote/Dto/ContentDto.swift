import Foundation

// معادل ContentDto.kt اپ اندروید (فاز ۱۳): مدل‌های تب «برندها» و تب «مقالات» در بخش
// دسته‌بندی‌های منوی ناوبری پایین اپ - همان کلیدهای JSON.

// ---- فهرست برندها (با لوگو) ----

struct BrandListResponse: ShkDTO {
    let status: String?
    let brands: [BrandListItemDto]

    enum CodingKeys: String, CodingKey { case status, brands }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        brands = c.lossyList(BrandListItemDto.self, .brands) ?? []
    }
}

struct BrandListItemDto: ShkDTO, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let logo: String?
    let productsCount: Int

    enum CodingKeys: String, CodingKey { case id, title, slug, logo, productsCount = "products_count" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        logo = c.lenientString(.logo)
        productsCount = c.lenientInt(.productsCount) ?? 0
    }
}

// ---- دسته‌بندی‌های مقاله (هر کدوم با تصویر آخرین مقاله) ----

struct ArticleCategoriesResponse: ShkDTO {
    let status: String?
    let categories: [ArticleCategoryDto]

    enum CodingKeys: String, CodingKey { case status, categories }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        categories = c.lossyList(ArticleCategoryDto.self, .categories) ?? []
    }
}

struct ArticleCategoryDto: ShkDTO, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let image: String?
    let lastArticleImage: ArticleImageDto?
    let articlesCount: Int

    enum CodingKeys: String, CodingKey { case id, title, slug, image, lastArticleImage = "last_article_image", articlesCount = "articles_count" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        image = c.lenientString(.image)
        lastArticleImage = try? c.decodeIfPresent(ArticleImageDto.self, forKey: .lastArticleImage)
        articlesCount = c.lenientInt(.articlesCount) ?? 0
    }
}

struct ArticleImageDto: ShkDTO {
    let url: String?
    let alt: String?

    enum CodingKeys: String, CodingKey { case url, alt }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = c.lenientString(.url)
        alt = c.lenientString(.alt)
    }
}

// ---- صفحه‌ی برند (معادل BrandResponse / BrandDto در CatalogDto.kt) ----

struct BrandResponse: ShkDTO {
    let status: String?
    let brand: BrandDto?

    enum CodingKeys: String, CodingKey { case status, brand }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        brand = try? c.decodeIfPresent(BrandDto.self, forKey: .brand)
    }
}

struct BrandDto: ShkDTO {
    let id: Int
    let uuid: String?
    let title: String
    let titleEn: String?
    let slug: String
    let content: String?
    let logo: String?
    let banner: String?
    let productsCount: Int

    enum CodingKeys: String, CodingKey {
        case id, uuid, title, slug, content
        case titleEn = "title_en", logo = "get_logo", banner = "get_banner", productsCount = "products_count"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        uuid = c.lenientString(.uuid)
        title = c.lenientString(.title) ?? ""
        titleEn = c.lenientString(.titleEn)
        slug = c.lenientString(.slug) ?? ""
        content = c.lenientString(.content)
        logo = c.lenientString(.logo)
        banner = c.lenientString(.banner)
        productsCount = c.lenientInt(.productsCount) ?? 0
    }
}

// ---- معادل بخش مقالات ContentDto.kt (فهرست، جزئیات و دیدگاه‌های مقاله) ----

struct ArticleCommentsInfoDto: ShkDTO {
    let count: String?
    enum CodingKeys: String, CodingKey { case count }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = c.lenientString(.count)
    }
}

/// jalali_created_at آرایه‌ای از رشته‌هاست (تاریخ، ساعت، ...) - مقادیر عددی هم متن می‌شن
private func lenientStringList<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> [String]? {
    guard let raw = try? c.decodeIfPresent([JSONValue].self, forKey: key) else { return nil }
    return raw.map { v in
        switch v {
        case .string(let s): return s
        case .number(let d): return d == d.rounded() ? String(Int64(d)) : String(d)
        default: return ""
        }
    }
}

// ---- فهرست مقالات یک دسته‌بندی ----

struct ArticlesResponse: ShkDTO {
    let status: String?
    let articles: [ArticleListItemDto]
    let pagination: PaginationDto?
    enum CodingKeys: String, CodingKey { case status, articles, pagination }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        articles = c.lossyList(ArticleListItemDto.self, .articles) ?? []
        pagination = try? c.decodeIfPresent(PaginationDto.self, forKey: .pagination)
    }
}

struct ArticlesPage {
    let items: [ArticleListItemDto]
    let pagination: PaginationDto?
}

struct ArticleListItemDto: ShkDTO, Identifiable {
    let id: Int
    let title: String
    let slug: String
    let image: ArticleImageDto?
    let readTime: String?
    let commentsInfo: ArticleCommentsInfoDto?
    let jalaliCreatedAt: [String]?
    let category: ArticleCategoryDto?
    // بازطراحی: تعداد بازدید (فرمت‌شده) و نویسنده‌ی مقاله - برای متای کارت/صفحه‌ی مقاله
    let formattedViewCount: String?
    let author: ArticleCommentUserDto?
    enum CodingKeys: String, CodingKey {
        case id, title, slug, category
        case image = "get_image", readTime = "read_time", commentsInfo = "comments_info", jalaliCreatedAt = "jalali_created_at"
        case formattedViewCount = "get_formatted_view_count", author = "user"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        image = try? c.decodeIfPresent(ArticleImageDto.self, forKey: .image)
        readTime = c.lenientString(.readTime)
        commentsInfo = try? c.decodeIfPresent(ArticleCommentsInfoDto.self, forKey: .commentsInfo)
        jalaliCreatedAt = lenientStringList(c, .jalaliCreatedAt)
        category = try? c.decodeIfPresent(ArticleCategoryDto.self, forKey: .category)
        formattedViewCount = c.lenientString(.formattedViewCount)
        author = try? c.decodeIfPresent(ArticleCommentUserDto.self, forKey: .author)
    }
}

// ---- جزئیات کامل یک مقاله ----

struct ArticleDetailResponse: ShkDTO {
    let status: String?
    let article: ArticleDetailDto?
    enum CodingKeys: String, CodingKey { case status, article }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        article = try? c.decodeIfPresent(ArticleDetailDto.self, forKey: .article)
    }
}

struct ArticleDetailDto: ShkDTO {
    let id: Int
    let title: String
    let slug: String
    let image: ArticleImageDto?
    let content: String?
    let readTime: String?
    let commentsInfo: ArticleCommentsInfoDto?
    let jalaliCreatedAt: [String]?
    let category: ArticleCategoryDto?
    let formattedViewCount: String?
    let author: ArticleCommentUserDto?
    enum CodingKeys: String, CodingKey {
        case id, title, slug, category
        case image = "get_image", content = "get_content", readTime = "read_time", commentsInfo = "comments_info"
        case jalaliCreatedAt = "jalali_created_at", formattedViewCount = "get_formatted_view_count", author = "user"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        image = try? c.decodeIfPresent(ArticleImageDto.self, forKey: .image)
        content = c.lenientString(.content)
        readTime = c.lenientString(.readTime)
        commentsInfo = try? c.decodeIfPresent(ArticleCommentsInfoDto.self, forKey: .commentsInfo)
        jalaliCreatedAt = lenientStringList(c, .jalaliCreatedAt)
        category = try? c.decodeIfPresent(ArticleCategoryDto.self, forKey: .category)
        formattedViewCount = c.lenientString(.formattedViewCount)
        author = try? c.decodeIfPresent(ArticleCommentUserDto.self, forKey: .author)
    }
}

// ---- فاز ۱۶: دیدگاه‌های مقاله - دقیقاً همون شکلی که accessor «safe» مدل ArticleComment برمی‌گردونه ----

struct ArticleCommentsResponse: ShkDTO {
    let status: String?
    let comments: [ArticleCommentDto]
    enum CodingKeys: String, CodingKey { case status, comments }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        comments = c.lossyList(ArticleCommentDto.self, .comments) ?? []
    }
}

struct ArticleCommentDto: ShkDTO, Identifiable {
    let id: Int
    let content: String?
    let replyTo: Int?
    let voteUp: Int
    let voteDown: Int
    let status: String?
    let jalaliCreatedAt: [String]?
    let user: ArticleCommentUserDto?
    // پاسخ‌ها هر کدوم داخل یه پوشش {"safe": {...}} میان - دقیقاً مثل خروجی خود اسکریپت
    let answers: [ArticleCommentAnswerWrapperDto]
    enum CodingKeys: String, CodingKey {
        case id, content, status, user, answers
        case replyTo = "reply_to", voteUp = "vote_up", voteDown = "vote_down", jalaliCreatedAt = "jalali_created_at"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        content = c.lenientString(.content)
        replyTo = c.lenientInt(.replyTo)
        voteUp = c.lenientInt(.voteUp) ?? 0
        voteDown = c.lenientInt(.voteDown) ?? 0
        status = c.lenientString(.status)
        jalaliCreatedAt = lenientStringList(c, .jalaliCreatedAt)
        user = try? c.decodeIfPresent(ArticleCommentUserDto.self, forKey: .user)
        answers = c.lossyList(ArticleCommentAnswerWrapperDto.self, .answers) ?? []
    }
}

struct ArticleCommentAnswerWrapperDto: ShkDTO {
    let safe: ArticleCommentDto?
    enum CodingKeys: String, CodingKey { case safe }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        safe = try? c.decodeIfPresent(ArticleCommentDto.self, forKey: .safe)
    }
}

struct ArticleCommentUserDto: ShkDTO {
    let id: Int
    let name: String?
    let username: String?
    let avatar: String?
    enum CodingKeys: String, CodingKey { case id, username, name = "get_name", avatar = "get_avatar" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        name = c.lenientString(.name)
        username = c.lenientString(.username)
        avatar = c.lenientString(.avatar)
    }
}

struct ArticleAddCommentResponse: ShkDTO {
    let status: String?
    let message: String?
    let published: Bool
    enum CodingKeys: String, CodingKey { case status, message, published }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        message = c.lenientString(.message)
        published = c.lenientBool(.published) ?? false
    }
}
