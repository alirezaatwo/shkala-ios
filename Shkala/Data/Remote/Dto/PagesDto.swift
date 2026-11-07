import Foundation

// معادل data/remote/dto/FaqDto.kt و PageDto.kt اپ اندروید

struct FaqsResponse: ShkDTO {
    let status: String
    let faqs: [FaqDto]
    enum CodingKeys: String, CodingKey { case status, faqs }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        faqs = c.lossyList(FaqDto.self, .faqs) ?? []
    }
}

struct FaqDto: ShkDTO, Identifiable {
    let id: Int
    let question: String
    let answer: String
    enum CodingKeys: String, CodingKey { case id, question, answer }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        question = c.lenientString(.question) ?? ""
        answer = c.lenientString(.answer) ?? ""
    }
}

/**
 * فاز ۳۲: صفحات ثابت اسکریپت (مثل «قوانین و شرایط») - محتواشون یک رشته‌ی HTML خامه،
 * دقیقاً مثل توضیحات محصول/متن مقاله؛ در اپ با همون موتور نمایشِ محلی رندر می‌شه.
 */
struct PageResponse: ShkDTO {
    let status: String
    let page: PageDto?
    enum CodingKeys: String, CodingKey { case status, page }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        page = try? c.decodeIfPresent(PageDto.self, forKey: .page)
    }
}

struct PageDto: ShkDTO {
    let id: Int
    let title: String
    let slug: String
    let content: String?
    enum CodingKeys: String, CodingKey { case id, title, slug, content }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        content = c.lenientString(.content)
    }
}
