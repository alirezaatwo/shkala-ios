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
