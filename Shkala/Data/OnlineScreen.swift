import Foundation

/**
 * معادل data/OnlineScreen.kt اپ اندروید (۳.۹).
 * صفحه‌ی فعلی اپ برای «آمار ← کاربران آنلاین» در پنل سایت. با هر جابه‌جایی صفحه فوراً (api/v2/app/presence)
 * و همراه پرسش دوره‌ای api/v2/app/status به‌صورت هدر فرستاده می‌شه.
 * - X-Shk-Screen: مسیر همون صفحه در سایت (محصول، دسته، جست‌وجو، برند، صفحه‌ی وب) تا مدیر بتونه بازش کنه؛
 *   بقیه‌ی صفحه‌ها «app:اسم‌صفحه».
 * - X-Shk-Screen-Title: اسم فارسی صفحه با جزئیاتش (اسم محصول، عبارت جست‌وجو، شماره‌ی سفارش و ...).
 * - X-Shk-Goftino: شناسه‌ی کاربر در گفتینو برای شروع چت از پنل مدیر.
 */
enum OnlineScreen {
    // اسم صفحه‌ها دقیقاً همون الگوی مسیر اندروید (Routes) تا پنل برای هر دو اپ یکی نشون بده
    static var route: String? = nil
    static var pageUrl: String? = nil
    static var pageLabel: String? = nil
    static var goftinoUserId: String? = nil

    private static var args: [String: String] = [:]
    private static let siteHosts: Set<String> = ["shkala.com", "www.shkala.com", "shkcctv.com", "www.shkcctv.com"]

    private static let titles: [String: String] = [
        "home": "صفحه‌ی اصلی",
        "categories": "دسته‌بندی‌ها",
        "account": "حساب کاربری",
        "product": "صفحه‌ی محصول",
        "product-description": "توضیحات محصول",
        "full-specs": "مشخصات کامل محصول",
        "category": "فهرست محصولات",
        "search-results": "نتیجه‌ی جست‌وجو",
        "checkout": "سبد خرید / تسویه حساب",
        "addresses": "آدرس‌ها",
        "address-form": "ثبت / ویرایش آدرس",
        "map-picker": "انتخاب آدرس روی نقشه",
        "payment-webview": "درگاه پرداخت",
        "card-to-card": "پرداخت کارت به کارت",
        "order-result": "نتیجه‌ی پرداخت سفارش",
        "webpage": "صفحه‌ی وب سایت",
        "orders-list": "سفارش‌های من",
        "order-detail": "جزئیات سفارش",
        "wallet": "کیف پول",
        "wallet-charge": "شارژ کیف پول",
        "wallet-charge-webview": "درگاه شارژ کیف پول",
        "wallet-charge-result": "نتیجه‌ی شارژ کیف پول",
        "wallet-withdrawal": "برداشت از کیف پول",
        "wallet-add-card": "افزودن کارت بانکی",
        "wallet-edit-card": "ویرایش کارت بانکی",
        "transactions-list": "تراکنش‌ها",
        "prefactors-list": "پیش‌فاکتورها",
        "prefactor-detail": "جزئیات پیش‌فاکتور",
        "prefactor-addresses": "آدرس پیش‌فاکتور",
        "cart-prefactor": "پیش‌فاکتور سبد خرید",
        "tickets-list": "تیکت‌های پشتیبانی",
        "create-ticket": "ثبت تیکت جدید",
        "ticket-detail": "تیکت پشتیبانی",
        "favorites-list": "علاقه‌مندی‌ها",
        "my-comments-list": "دیدگاه‌های من",
        "recently-viewed": "بازدیدهای اخیر",
        "in-carts-now": "محصولات داخل سبد دیگران",
        "active-sessions": "دستگاه‌های فعال",
        "partner-request": "درخواست همکاری",
        "partner-commissions": "پورسانت همکاری",
        "edit-profile": "ویرایش پروفایل",
        "notifications-list": "اعلان‌ها",
        "compare": "مقایسه‌ی محصولات",
        "brand": "صفحه‌ی برند",
        "article-list": "مقالات",
        "faq-list": "سوالات متداول",
        "terms": "قوانین و مقررات",
        "magazine": "مجله",
        "form": "فرم",
        "contact-us-page": "تماس با ما",
        "announcement": "اطلاعیه",
        "tools": "ابزارها",
        "tools/hdd-calculator": "ماشین‌حساب هارد دوربین",
    ]

    /** مسیر فعلی و آرگومان‌هاش؛ معادل الگوی مسیر ناوبری اندروید (مثل «product/{slug}» ← «product») */
    static func updateRoute(tab: AppTab, current: AppRoute?) {
        route = androidRouteName(tab: tab, current: current)
        args = routeArgs(current)
    }

    private static func arg(_ key: String) -> String? {
        guard let v = args[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
        return v
    }

    /** آرگومان‌های مسیر با همون اسم‌های اندروید (slug، title، query، id، url) */
    private static func routeArgs(_ current: AppRoute?) -> [String: String] {
        guard let current else { return [:] }
        switch current {
        case .productDetail(let slug): return ["slug": slug]
        case .categoryProducts(let slug, let title): return ["slug": slug, "title": title]
        case .searchResults(let query, let cat): return ["query": query, "cat": cat ?? ""]
        case .brand(let slug): return ["slug": slug]
        case .webpage(let url): return ["url": url]
        case .articleList(let slug, let title): return ["slug": slug, "title": title]
        case .dynamicForm(let slug, let title): return ["slug": slug, "title": title]
        case .orderDetail(let id): return ["id": String(id)]
        case .ticketDetail(let id): return ["id": String(id)]
        case .prefactorDetail(let uuid), .prefactorAddresses(let uuid): return ["uuid": uuid]
        default: return [:]
        }
    }

    /** آدرس صفحه‌ی همین محصول/دسته که خود صفحه ثبت کرده (فقط وقتی مال همین صفحه‌ست، نه صفحه‌ی قبلی) */
    private static func ownPageUrl() -> String? {
        guard let url = pageUrl else { return nil }
        switch route ?? "" {
        case "product", "product-description", "full-specs": return url.contains("/product/") ? url : nil
        case "category": return url.contains("/products") && !url.contains("search=") ? url : nil
        case "search-results": return url.contains("search=") ? url : nil
        default: return nil
        }
    }

    /** مسیر و کوئری آدرسِ سایت خودمون (آدرس سایت‌های دیگه = null) */
    private static func siteUrl(_ url: String?) -> String? {
        guard let url, !url.isBlankShk else { return nil }
        if let scheme = url.range(of: "://") {
            let afterScheme = url[scheme.upperBound...]
            let hostEnd = afterScheme.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? afterScheme.endIndex
            let host = afterScheme[..<hostEnd].lowercased().split(separator: ":").first.map(String.init) ?? ""
            guard siteHosts.contains(host) else { return nil }
            return sitePathAndQuery(url)
        }
        // آدرس نسبی (/page/..)
        guard url.hasPrefix("/") else { return nil }
        return sitePathAndQuery("https://shkala.com" + url)
    }

    /** مقدار هدر X-Shk-Screen */
    static func screenHeader() -> String? {
        let site: String?
        switch route ?? "" {
        case "brand": site = arg("slug").flatMap { $0.addingPercentEncoding(withAllowedCharacters: uriUnreserved) }.map { "/brand/" + $0 }
        case "webpage": site = siteUrl(arg("url"))
        default: site = siteUrl(ownPageUrl())
        }
        if let site { return cutEncoded(site, max: 300) }
        guard let route else { return nil }
        let clean = route.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "/") }
        return "app:" + String(clean.prefix(60))
    }

    /** اسم فارسی صفحه با جزئیاتش */
    private static func title() -> String? {
        guard let route, let base = titles[route] else { return nil }
        let label: String? = ownPageUrl() != nil ? ((pageLabel?.isBlankShk ?? true) ? nil : pageLabel) : nil
        let detail: String?
        switch route {
        case "product", "product-description", "full-specs": detail = label
        case "category": detail = label ?? arg("title").flatMap { $0.hasPrefix("__") ? nil : $0 }
        case "search-results": detail = arg("query").map { "«\($0)»" }
        case "brand": detail = arg("slug")
        case "article-list": detail = arg("title").flatMap { $0.hasPrefix("__") ? nil : $0 }
        case "form": detail = arg("title")
        case "order-detail", "ticket-detail": detail = arg("id").map { "#\($0)" }
        case "webpage": detail = arg("url").flatMap { URLComponents(string: $0)?.path }
        default: detail = nil
        }
        guard let detail, !detail.isBlankShk else { return base }
        return route == "product" ? detail : "\(base): \(detail)"
    }

    /** مقدار هدر X-Shk-Screen-Title (url-encode شده چون هدر فقط ASCII می‌پذیره) */
    static func titleHeader() -> String? {
        title().map { String($0.prefix(160)) }?.addingPercentEncoding(withAllowedCharacters: uriUnreserved)
    }

    static func goftinoHeader() -> String? {
        guard let id = goftinoUserId, id.range(of: "^[A-Za-z0-9_\\-]{6,64}$", options: .regularExpression) != nil else { return nil }
        return id
    }

    // ---- کمکی‌ها ----

    // معادل Uri.encode اندروید (حروف/ارقام و _-!.~'()* بدون تغییر)
    private static let uriUnreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-!.~'()*")
    // نویسه‌های مجاز مسیر در سرور (AppStatusController)؛ بقیه (مثل اسلاگ فارسی) percent-encode می‌شن
    private static let sitePathAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-/.:?=&%+")

    /** «/product/..» یا «/products?cat=..» از آدرس کامل صفحه در سایت (هدر HTTP فقط ASCII) */
    private static func sitePathAndQuery(_ url: String) -> String? {
        guard let scheme = url.range(of: "://") else { return nil }
        let afterHost = url[scheme.upperBound...]
        guard let slash = afterHost.firstIndex(of: "/") else { return nil }
        var raw = String(afterHost[slash...])
        if let hash = raw.firstIndex(of: "#") { raw = String(raw[..<hash]) }
        if raw.hasSuffix("?") { raw.removeLast() }
        guard raw.count > 1 || raw == "/" else { return nil }
        return raw.addingPercentEncoding(withAllowedCharacters: sitePathAllowed)
    }

    /** بریدن رشته‌ی percent-encode شده تا max نویسه از مرز کامل یک نویسه (نه وسط %XX یا وسط بایت‌های UTF-8) */
    private static func cutEncoded(_ s: String, max: Int) -> String {
        let chars = Array(s)
        var out = ""
        var i = 0
        while i < chars.count {
            var len = 1
            if chars[i] == "%", i + 2 < chars.count, let b = UInt8(String(chars[(i + 1)...(i + 2)]), radix: 16) {
                // تعداد بایت‌های نویسه از بایت اول UTF-8
                let bytes = b >= 0xF0 ? 4 : b >= 0xE0 ? 3 : b >= 0xC0 ? 2 : 1
                len = 3 * bytes
            }
            if i + len > chars.count || out.count + len > max { break }
            out += String(chars[i..<(i + len)])
            i += len
        }
        return out
    }

    /** نام مسیر اندروید (Routes) برای مسیر فعلی iOS */
    private static func androidRouteName(tab: AppTab, current: AppRoute?) -> String {
        guard let current else {
            switch tab {
            case .HOME: return "home"
            case .CATEGORIES: return "categories"
            case .ACCOUNT: return "account"
            }
        }
        switch current {
        case .productDetail: return "product"
        case .categoryProducts: return "category"
        case .searchResults: return "search-results"
        case .brand: return "brand"
        case .webpage: return "webpage"
        case .announcement: return "announcement"
        case .notificationsList: return "notifications-list"
        case .inCartsNow: return "in-carts-now"
        case .tools: return "tools"
        case .hddCalculator: return "tools/hdd-calculator"
        case .contactUs: return "contact-us-page"
        case .terms: return "terms"
        case .magazine: return "magazine"
        case .articleList: return "article-list"
        // صفحه‌ی مقاله در اندروید همون مسیر توضیحات محصوله
        case .articleDetail: return "product-description"
        case .faqList: return "faq-list"
        case .checkout: return "checkout"
        case .cartPrefactor: return "cart-prefactor"
        case .productDescription: return "product-description"
        case .fullSpecs: return "full-specs"
        case .compare: return "compare"
        case .addresses: return "addresses"
        case .addressForm: return "address-form"
        case .mapPicker: return "map-picker"
        case .paymentWebView: return "payment-webview"
        case .cardToCard: return "card-to-card"
        case .orderResult: return "order-result"
        case .ordersList: return "orders-list"
        case .orderDetail: return "order-detail"
        case .wallet: return "wallet"
        case .walletCharge: return "wallet-charge"
        case .walletChargeWebView: return "wallet-charge-webview"
        case .walletChargeResult: return "wallet-charge-result"
        case .walletWithdrawal: return "wallet-withdrawal"
        case .walletAddCard: return "wallet-add-card"
        case .walletEditCard: return "wallet-edit-card"
        case .transactionsList: return "transactions-list"
        case .prefactorsList: return "prefactors-list"
        case .dynamicForm: return "form"
        case .prefactorDetail: return "prefactor-detail"
        case .prefactorAddresses: return "prefactor-addresses"
        case .ticketsList: return "tickets-list"
        case .createTicket: return "create-ticket"
        case .ticketDetail: return "ticket-detail"
        case .favoritesList: return "favorites-list"
        case .myCommentsList: return "my-comments-list"
        case .recentlyViewed: return "recently-viewed"
        case .activeSessions: return "active-sessions"
        case .editProfile: return "edit-profile"
        case .partnerRequest: return "partner-request"
        case .partnerCommissions: return "partner-commissions"
        }
    }
}
