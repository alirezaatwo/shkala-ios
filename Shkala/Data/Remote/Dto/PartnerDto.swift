import Foundation

// ===================================================================================
// معادل data/remote/dto/PartnerDto.kt اپ اندروید
// «همکار شوید» و «پورسانت همکاری» (api_contract §25) - هر پاسخ عملیات، وضعیت تازه را هم دارد (partner)
// ===================================================================================

struct PartnerResponse: ShkDTO {
    let status: String?
    let message: String?
    let partner: PartnerStateDto?

    enum CodingKeys: String, CodingKey { case status, message, partner }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        message = c.lenientString(.message)
        partner = try? c.decodeIfPresent(PartnerStateDto.self, forKey: .partner)
    }
}

struct PartnerStateDto: ShkDTO {
    var ready: Bool = false
    // false = ثبت درخواست همکاری در تنظیمات خاموش است
    var enabled: Bool? = nil
    // none | draft | submitted | rejected | partner | suspended
    var state: String = "none"
    var editable: Bool = false
    var rejectReason: String? = nil
    var retryAt: String? = nil
    var submittedAt: String? = nil
    var steps: PartnerStepsDto? = nil
    var documents: [PartnerDocumentDto] = []
    var canSubmit: Bool = false
    var maxKb: Int = 10240

    enum CodingKeys: String, CodingKey {
        case ready, enabled, state, editable, steps, documents
        case rejectReason = "reject_reason", retryAt = "retry_at", submittedAt = "submitted_at"
        case canSubmit = "can_submit", maxKb = "max_kb"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ready = c.lenientBool(.ready) ?? false
        enabled = c.lenientBool(.enabled)
        state = c.lenientString(.state) ?? "none"
        editable = c.lenientBool(.editable) ?? false
        rejectReason = c.lenientString(.rejectReason)
        retryAt = c.lenientString(.retryAt)
        submittedAt = c.lenientString(.submittedAt)
        steps = try? c.decodeIfPresent(PartnerStepsDto.self, forKey: .steps)
        documents = c.lossyList(PartnerDocumentDto.self, .documents) ?? []
        canSubmit = c.lenientBool(.canSubmit) ?? false
        maxKb = c.lenientInt(.maxKb) ?? 10240
    }
}

struct PartnerStepsDto: ShkDTO {
    let account: PartnerAccountStepDto?
    let documents: PartnerOkDto?
    let instagram: PartnerInstagramStepDto?
    let bale: PartnerBaleStepDto?

    enum CodingKeys: String, CodingKey { case account, documents, instagram, bale }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        account = try? c.decodeIfPresent(PartnerAccountStepDto.self, forKey: .account)
        documents = try? c.decodeIfPresent(PartnerOkDto.self, forKey: .documents)
        instagram = try? c.decodeIfPresent(PartnerInstagramStepDto.self, forKey: .instagram)
        bale = try? c.decodeIfPresent(PartnerBaleStepDto.self, forKey: .bale)
    }
}

struct PartnerAccountStepDto: ShkDTO {
    let name: Bool
    let phone: Bool
    let address: Bool
    let ok: Bool

    enum CodingKeys: String, CodingKey { case name, phone, address, ok }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.lenientBool(.name) ?? false
        phone = c.lenientBool(.phone) ?? false
        address = c.lenientBool(.address) ?? false
        ok = c.lenientBool(.ok) ?? false
    }
}

struct PartnerOkDto: ShkDTO {
    let ok: Bool

    enum CodingKeys: String, CodingKey { case ok }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.lenientBool(.ok) ?? false
    }
}

struct PartnerInstagramStepDto: ShkDTO {
    let ok: Bool
    let pageUrl: String?

    enum CodingKeys: String, CodingKey { case ok, pageUrl = "page_url" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.lenientBool(.ok) ?? false
        pageUrl = c.lenientString(.pageUrl)
    }
}

struct PartnerBaleStepDto: ShkDTO {
    let ready: Bool
    let ok: Bool
    let linked: Bool
    let checkedAt: String?
    let code: String?
    let bot: String?
    let botUrl: String?
    let channelUrl: String?

    enum CodingKeys: String, CodingKey {
        case ready, ok, linked, code, bot
        case checkedAt = "checked_at", botUrl = "bot_url", channelUrl = "channel_url"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ready = c.lenientBool(.ready) ?? false
        ok = c.lenientBool(.ok) ?? false
        linked = c.lenientBool(.linked) ?? false
        checkedAt = c.lenientString(.checkedAt)
        code = c.lenientString(.code)
        bot = c.lenientString(.bot)
        botUrl = c.lenientString(.botUrl)
        channelUrl = c.lenientString(.channelUrl)
    }
}

struct PartnerDocumentDto: ShkDTO {
    let kind: String
    // documents | instagram
    let step: String
    let required: Bool
    let accept: String
    let uploaded: Bool
    let name: String?

    enum CodingKeys: String, CodingKey { case kind, step, required, accept, uploaded, name }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = c.lenientString(.kind) ?? ""
        step = c.lenientString(.step) ?? ""
        required = c.lenientBool(.required) ?? false
        accept = c.lenientString(.accept) ?? ""
        uploaded = c.lenientBool(.uploaded) ?? false
        name = c.lenientString(.name)
    }
}

struct PartnerCommissionsResponse: ShkDTO {
    let status: String?
    let message: String?
    let partnerStatus: String?
    let level: String?
    let products: [PartnerProductDto]
    let pagination: PaginationDto?

    enum CodingKeys: String, CodingKey {
        case status, message, level, products, pagination
        case partnerStatus = "partner_status"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        message = c.lenientString(.message)
        partnerStatus = c.lenientString(.partnerStatus)
        level = c.lenientString(.level)
        products = c.lossyList(PartnerProductDto.self, .products) ?? []
        pagination = try? c.decodeIfPresent(PaginationDto.self, forKey: .pagination)
    }
}

struct PartnerProductDto: ShkDTO, Identifiable {
    let id: Int
    let uuid: String
    let slug: String
    let title: String
    let image: String?
    let rates: [String: PartnerRateDto]
    let myRate: PartnerRateDto?
    let link: String

    enum CodingKeys: String, CodingKey {
        case id, uuid, slug, title, image, rates, link
        case myRate = "my_rate"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        uuid = c.lenientString(.uuid) ?? ""
        slug = c.lenientString(.slug) ?? ""
        title = c.lenientString(.title) ?? ""
        image = c.lenientString(.image)
        rates = (try? c.decodeIfPresent([String: PartnerRateDto].self, forKey: .rates)) ?? [:]
        myRate = try? c.decodeIfPresent(PartnerRateDto.self, forKey: .myRate)
        link = c.lenientString(.link) ?? ""
    }
}

struct PartnerRateDto: ShkDTO {
    let commission: Double?
    let max: Int64?
    let partner: Bool

    enum CodingKeys: String, CodingKey { case commission, max, partner }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        commission = c.lenientDouble(.commission)
        max = c.lenientInt64(.max)
        partner = c.lenientBool(.partner) ?? false
    }
}
