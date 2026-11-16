import Foundation

/**
 * معادل data/OnlineScreen.kt اپ اندروید (۳.۵).
 * صفحه‌ی فعلی اپ برای «آمار ← کاربران آنلاین» در پنل سایت (همراه پرسش دوره‌ای api/v2/app/status
 * به‌صورت هدر فرستاده می‌شه). محصول/دسته/جست‌وجو آدرس همون صفحه در سایت رو می‌فرستن تا مدیر بتونه
 * بازش کنه؛ بقیه‌ی صفحه‌ها فقط اسم صفحه. شناسه‌ی گفتینو هم برای شروع چت از پنل مدیر.
 */
enum OnlineScreen {
    // اسم صفحه‌ها دقیقاً همون الگوی مسیر اندروید (Routes) تا پنل برای هر دو اپ یکی نشون بده
    static var route: String? = nil
    static var pageUrl: String? = nil
    static var pageLabel: String? = nil
    static var goftinoUserId: String? = nil

    private static let sitePageRoutes: Set<String> = ["product", "category", "search-results"]

    private static let titles: [String: String] = [
        "home": "صفحه‌ی اصلی",
        "categories": "دسته‌بندی‌ها",
        "account": "حساب کاربری",
        "checkout": "سبد خرید / تسویه",
        "cart-prefactor": "پیش‌فاکتور سبد",
        "payment-webview": "درگاه پرداخت",
        "card-to-card": "کارت به کارت",
        "order-result": "نتیجه‌ی سفارش",
        "orders-list": "سفارش‌های من",
        "order-detail": "جزئیات سفارش",
        "wallet": "کیف پول",
        "wallet-charge": "شارژ کیف پول",
        "favorites-list": "علاقه‌مندی‌ها",
        "recently-viewed": "بازدیدهای اخیر",
        "tickets-list": "تیکت‌ها",
        "ticket-detail": "تیکت",
        "create-ticket": "ثبت تیکت",
        "addresses": "آدرس‌ها",
        "compare": "مقایسه",
        "brand": "برند",
        "magazine": "مجله",
        "faq-list": "سوالات متداول",
        "contact-us-page": "تماس با ما",
        "tools": "ابزارها",
        "prefactors-list": "پیش‌فاکتورها",
    ]

    /** نام صفحه‌ی فعلی؛ معادل الگوی مسیر ناوبری اندروید (مثل «product/{slug}» ← «product») */
    static func updateRoute(tab: AppTab, current: AppRoute?) {
        route = androidRouteName(tab: tab, current: current)
    }

    private static func isSitePage() -> Bool { route.map { sitePageRoutes.contains($0) } ?? false }

    /** مقدار هدر X-Shk-Screen: مسیر صفحه در سایت (/product/..) یا «app:اسم‌صفحه» */
    static func screenHeader() -> String? {
        if isSitePage(), let url = pageUrl, let pathAndQuery = sitePathAndQuery(url) {
            if pathAndQuery.count <= 200 { return pathAndQuery }
            // مثل اندروید: اگه بلند بود فقط مسیر (بدون کوئری)، بریده از مرز کامل نویسه (نه وسط %XX)
            let path = pathAndQuery.split(separator: "?", maxSplits: 1).first.map(String.init) ?? pathAndQuery
            return cutEncoded(path, max: 200)
        }
        guard let route else { return nil }
        let clean = route.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "/") }
        return "app:" + String(clean.prefix(60))
    }

    /** مقدار هدر X-Shk-Screen-Title (url-encode شده چون هدر فقط ASCII می‌پذیره) */
    static func titleHeader() -> String? {
        let title: String?
        if isSitePage() {
            title = (pageLabel?.isBlankShk ?? true) ? nil : pageLabel
        } else {
            title = route.flatMap { titles[$0] }
        }
        return title.map { String($0.prefix(160)) }?.addingPercentEncoding(withAllowedCharacters: uriUnreserved)
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
        }
    }
}
