import Foundation

// ===================================================================================
// معادل data/remote/dto/ToolsDto.kt - ابزارهای کاربردی (ماژول tools):
//  - GET api/v2/tools                              : فهرست ابزارهای فعال
//  - GET api/v2/tools/hdd-calculator               : پیکربندی ماشین‌حساب هارد (همون عددهای صفحه‌ی سایت)
//  - GET api/v2/tools/hdd-calculator/products?tb=4 : هاردهای پیشنهادی ظرفیت
// همه‌ی فیلدها اختیاری (مثل Gson که فیلدهای نیومده رو null می‌ذاره)
// ===================================================================================

struct ToolsResponse: ShkDTO {
    let status: String?
    let title: String?
    let intro: String?
    let url: String?
    let tools: [ToolItemDto]?
    enum CodingKeys: String, CodingKey { case status, title, intro, url, tools }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        title = c.lenientString(.title)
        intro = c.lenientString(.intro)
        url = c.lenientString(.url)
        tools = c.lossyList(ToolItemDto.self, .tools)
    }
}

/** key: شناسه‌ی ثابت ابزار (hdd_calculator = نیتیو)؛ ابزار ناشناخته با url در صفحه‌ی وب داخلی باز می‌شه */
struct ToolItemDto: ShkDTO {
    let key: String?
    let slug: String?
    let title: String?
    let summary: String?
    let icon: String?
    let url: String?
    // iconGlyph = کاراکتر فونت Remix (همون فونت اپ)، خالی = آیکن پیش‌فرض اپ
    let iconGlyph: String?
    // #rrggbb؛ خالی = رنگ اصلی
    let iconColor: String?
    // متن ساده: خط خالی = پاراگراف، **پررنگ**، «- » = فهرست؛ خالی = نمایش داده نشه
    let intro: String?
    let endTitle: String?
    let endText: String?
    enum CodingKeys: String, CodingKey {
        case key, slug, title, summary, icon, url, intro
        case iconGlyph = "icon_glyph", iconColor = "icon_color", endTitle = "end_title", endText = "end_text"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = c.lenientString(.key)
        slug = c.lenientString(.slug)
        title = c.lenientString(.title)
        summary = c.lenientString(.summary)
        icon = c.lenientString(.icon)
        url = c.lenientString(.url)
        iconGlyph = c.lenientString(.iconGlyph)
        iconColor = c.lenientString(.iconColor)
        intro = c.lenientString(.intro)
        endTitle = c.lenientString(.endTitle)
        endText = c.lenientString(.endText)
    }
}

struct HddToolResponse: ShkDTO {
    let status: String?
    let enabled: Bool?
    let tool: ToolItemDto?
    let config: HddConfigDto?
    enum CodingKeys: String, CodingKey { case status, enabled, tool, config }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        enabled = c.lenientBool(.enabled)
        tool = try? c.decodeIfPresent(ToolItemDto.self, forKey: .tool)
        config = try? c.decodeIfPresent(HddConfigDto.self, forKey: .config)
    }
}

/// عدد صحیح/اعشاری تحمل‌پذیر داخل آرایه (سرور ممکنه "4" یا 4 یا 4.0 بفرسته)
struct LenientNumber: Decodable {
    let value: Double?
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self) { value = Double(s) }
        else { value = nil }
    }
}

struct HddConfigDto: ShkDTO {
    let resolutions: [HddOptionDto]?
    let codecs: [HddOptionDto]?
    let fpsOptions: [Int]?
    let baseFps: Int?
    let modes: [HddOptionDto]?
    let marginPercent: Int?
    let tiersTb: [Double]?
    let defaults: HddDefaultsDto?
    let limits: HddLimitsDto?
    let moreUrl: String?
    // تنظیمات اختصاصی پنل (nil = رفتار قبلی)
    let tabs: [HddOptionDto]?
    let quickDays: [Int]?
    let showMargin: Bool?
    let showMonthly: Bool?
    let productsEnabled: Bool?
    let productsTitle: String?
    let moreLabel: String?
    let resultNote: String?
    enum CodingKeys: String, CodingKey {
        case resolutions, codecs, modes, defaults, limits, tabs
        case fpsOptions = "fps_options", baseFps = "base_fps", marginPercent = "margin_percent", tiersTb = "tiers_tb"
        case moreUrl = "more_url", quickDays = "quick_days", showMargin = "show_margin", showMonthly = "show_monthly"
        case productsEnabled = "products_enabled", productsTitle = "products_title", moreLabel = "more_label", resultNote = "result_note"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        resolutions = c.lossyList(HddOptionDto.self, .resolutions)
        codecs = c.lossyList(HddOptionDto.self, .codecs)
        fpsOptions = c.lossyList(LenientNumber.self, .fpsOptions)?.compactMap { $0.value.map { Int($0) } }
        baseFps = c.lenientInt(.baseFps)
        modes = c.lossyList(HddOptionDto.self, .modes)
        marginPercent = c.lenientInt(.marginPercent)
        tiersTb = c.lossyList(LenientNumber.self, .tiersTb)?.compactMap { $0.value }
        defaults = try? c.decodeIfPresent(HddDefaultsDto.self, forKey: .defaults)
        limits = try? c.decodeIfPresent(HddLimitsDto.self, forKey: .limits)
        moreUrl = c.lenientString(.moreUrl)
        tabs = c.lossyList(HddOptionDto.self, .tabs)
        quickDays = c.lossyList(LenientNumber.self, .quickDays)?.compactMap { $0.value.map { Int($0) } }
        showMargin = c.lenientBool(.showMargin)
        showMonthly = c.lenientBool(.showMonthly)
        productsEnabled = c.lenientBool(.productsEnabled)
        productsTitle = c.lenientString(.productsTitle)
        moreLabel = c.lenientString(.moreLabel)
        resultNote = c.lenientString(.resultNote)
    }
}

/** رزولوشن (kbps)، کدک (factor) یا نوع ضبط (factor) */
struct HddOptionDto: ShkDTO {
    let key: String?
    let label: String?
    let kbps: Int?
    let factor: Double?
    enum CodingKeys: String, CodingKey { case key, label, kbps, factor }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = c.lenientString(.key)
        label = c.lenientString(.label)
        kbps = c.lenientInt(.kbps)
        factor = c.lenientDouble(.factor)
    }
}

struct HddDefaultsDto: ShkDTO {
    let cameras: Int?
    let resolution: String?
    let codec: String?
    let fps: Int?
    let hours: Int?
    let mode: String?
    let days: Int?
    // need | days
    let tab: String?
    enum CodingKeys: String, CodingKey { case cameras, resolution, codec, fps, hours, mode, days, tab }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cameras = c.lenientInt(.cameras)
        resolution = c.lenientString(.resolution)
        codec = c.lenientString(.codec)
        fps = c.lenientInt(.fps)
        hours = c.lenientInt(.hours)
        mode = c.lenientString(.mode)
        days = c.lenientInt(.days)
        tab = c.lenientString(.tab)
    }
}

struct HddLimitsDto: ShkDTO {
    let camerasMin: Int?
    let camerasMax: Int?
    let groupsMax: Int?
    let hoursMin: Int?
    let hoursMax: Int?
    let daysMin: Int?
    let daysMax: Int?
    let disksMax: Int?
    enum CodingKeys: String, CodingKey {
        case camerasMin = "cameras_min", camerasMax = "cameras_max", groupsMax = "groups_max", hoursMin = "hours_min"
        case hoursMax = "hours_max", daysMin = "days_min", daysMax = "days_max", disksMax = "disks_max"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        camerasMin = c.lenientInt(.camerasMin)
        camerasMax = c.lenientInt(.camerasMax)
        groupsMax = c.lenientInt(.groupsMax)
        hoursMin = c.lenientInt(.hoursMin)
        hoursMax = c.lenientInt(.hoursMax)
        daysMin = c.lenientInt(.daysMin)
        daysMax = c.lenientInt(.daysMax)
        disksMax = c.lenientInt(.disksMax)
    }
}

struct HddProductsResponse: ShkDTO {
    let status: String?
    let requestedTb: Double?
    // ظرفیتی که محصولاتش برگشته (nil = محصولی نیست)؛ exact=false یعنی نزدیک‌ترین ظرفیت بزرگ‌تر
    let tierTb: Double?
    let exact: Bool?
    let products: [ProductListItemDto]?
    enum CodingKeys: String, CodingKey { case status, exact, products, requestedTb = "requested_tb", tierTb = "tier_tb" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        requestedTb = c.lenientDouble(.requestedTb)
        tierTb = c.lenientDouble(.tierTb)
        exact = c.lenientBool(.exact)
        products = c.lossyList(ProductListItemDto.self, .products)
    }
}
