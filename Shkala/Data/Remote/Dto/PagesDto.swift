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

// ---- معادل data/remote/dto/FormDto.kt ----

/**
 * فاز ۳۲: سیستم فرم‌ساز داینامیک اسکریپت (مدل Form) - «تماس با ما» یکی از فرم‌های
 * همین سیستمه (با اسلاگ ثابت contact-us). چون فیلدها کاملاً از پنل قابل تغییرن،
 * هیچ فیلدی این‌جا hardcode نشده - دقیقاً همون فیلدهای فعلیِ فرم رو از سرور می‌گیریم.
 */
struct FormResponse: ShkDTO {
    let status: String
    let form: FormDto?
    enum CodingKeys: String, CodingKey { case status, form }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        form = try? c.decodeIfPresent(FormDto.self, forKey: .form)
    }
}

struct FormDto: ShkDTO {
    let id: Int
    let title: String
    let slug: String
    let description: String?
    let fields: [FormFieldDto]
    enum CodingKeys: String, CodingKey { case id, title, slug, description, fields }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
        description = c.lenientString(.description)
        fields = c.lossyList(FormFieldDto.self, .fields) ?? []
    }
}

struct FormFieldDto: ShkDTO {
    let id: String
    let title: String
    // مقادیر رایج: "text", "textarea", "email", "checkbox" (طبق سازنده‌ی فرم پنل ادمین)
    let type: String
    // "necessary" یا "optional"
    let status: String
    enum CodingKeys: String, CodingKey { case id, title, type, status }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id) ?? ""
        title = c.lenientString(.title) ?? ""
        type = c.lenientString(.type) ?? ""
        status = c.lenientString(.status) ?? ""
    }
}

/** بدنه‌ی درخواست ثبت پاسخ فرم - دقیقاً همون ساختاری که خودِ اسکریپت انتظار داره */
struct FormAnswerSubmitRequest: Encodable {
    let captchaArgs: CaptchaArgsDto
    let captcha: Int
    let answer: [FormAnswerFieldDto]
    enum CodingKeys: String, CodingKey { case captchaArgs = "captcha_args", captcha, answer }
}

struct CaptchaArgsDto: Encodable {
    let first: Int
    let two: Int
}

struct FormAnswerFieldDto: Encodable {
    let id: String
    let title: String
    let type: String
    let status: String
    let value: String
}

struct FormAnswerSubmitResponse: ShkDTO {
    let status: String
    let message: String?
    enum CodingKeys: String, CodingKey { case status, message }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
    }
}
