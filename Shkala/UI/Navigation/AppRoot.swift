import SwiftUI

/// مسیرهای غیرتبیِ اپ (معادل Routes اندروید). مسیرهایی که صفحه‌شون هنوز ساخته نشده موقتاً
/// صفحه‌ی «به‌زودی» نشون می‌دن و در مراحل ۴ و ۵ یکی‌یکی جایگزین می‌شن.
enum AppRoute: Hashable {
    case productDetail(slug: String)
    case categoryProducts(slug: String, title: String)
    case searchResults(query: String, categorySlug: String?)
    case brand(slug: String)
    case webpage(url: String)
    case announcement
    case notificationsList
    case inCartsNow
    case tools
    case hddCalculator
    case contactUs
    case terms
    case magazine
    case faqList

    /// اسلاگ‌های قراردادی فهرست‌های «مشاهده همه» صفحه‌ی اصلی (همون Routes.*_SLUG اندروید)
    static let DISCOUNT_PRODUCTS_SLUG = "__discount__"
    static let LATEST_PRODUCTS_SLUG = "__latest__"
    static let MOST_VIEWED_PRODUCTS_SLUG = "__most_viewed__"

    /// عنوان موقت صفحه (تا ساخته شدن صفحه‌ی واقعی)
    var placeholderTitle: String {
        switch self {
        case .productDetail: return "جزئیات محصول"
        case .categoryProducts(_, let title): return title
        case .searchResults(let query, _): return query
        case .brand: return "برند"
        case .webpage: return "صفحه"
        case .announcement: return "اطلاعیه"
        case .notificationsList: return "اعلان‌ها"
        case .inCartsNow: return IN_CARTS_NOW_TITLE
        case .tools: return TOOLS_TITLE
        case .hddCalculator: return "محاسبه‌گر هارد"
        case .contactUs: return "تماس با ما"
        case .terms: return "قوانین و شرایط"
        case .magazine: return "مجله"
        case .faqList: return "پرسش‌های متداول"
        }
    }
}

/// «ابزارهای کاربردی» (TOOLS_TITLE اندروید - ui/tools/ToolsScreen.kt)
let TOOLS_TITLE = "ابزارهای کاربردی"

/// پشته‌ی ناوبری اپ (معادل NavHostController اندروید) - برای اینکه لینک‌ها از هرجای اپ (پاپ‌آپ، استوری،
/// محتوای HTML) بتونن صفحه باز کنن
@MainActor
final class AppNavigator: ObservableObject {
    static let shared = AppNavigator()

    @Published var tab: AppTab = .HOME
    @Published var stack: [AppRoute] = []

    var currentRoute: AppRoute? { stack.last }

    func navigate(_ route: AppRoute) { stack.append(route) }

    func popBackStack() { if !stack.isEmpty { stack.removeLast() } }

    /// معادل navigate(tab) { popUpTo(start) { saveState = true }; launchSingleTop; restoreState }:
    /// صفحه‌های باز روی تب‌ها بسته می‌شن و state خودِ تب‌ها (اسکرول، داده) حفظ می‌شه
    func selectTab(_ t: AppTab) {
        stack.removeAll()
        tab = t
    }

    /// لینک پاپ‌آپ تبلیغاتی/استوری: لینک‌های محصول/برند/دسته‌بندیِ سایت داخل اپ، بقیه‌ی صفحات سایت در
    /// صفحه‌ی وب داخلی، و لینک‌های بیرونی با مرورگر/اپ مربوطه
    func openAppLink(_ rawUrl: String) {
        let url = rawUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.isEmpty { return }
        let components = URLComponents(string: url)
        let host = components?.host?.lowercased()
        let isSiteLink = host == nil || ["shkala.com", "www.shkala.com", "shkcctv.com", "www.shkcctv.com"].contains(host!)
        let path = components?.path ?? ""
        let productSlug = firstGroup(#"/product/([^/?]+)"#, path)
        let brandSlug = firstGroup(#"/brand/([^/?]+)"#, path)
        let categorySlug = components?.queryItems?.first(where: { $0.name == "cat" })?.value
        let trimmedPath = path.hasSuffix("/") ? String(path.dropLast()) : path
        if isSiteLink, let productSlug {
            navigate(.productDetail(slug: productSlug))
        } else if isSiteLink && trimmedPath == "/tools" {
            navigate(.tools)
        } else if isSiteLink && trimmedPath == "/tools/hdd-calculator" {
            navigate(.hddCalculator)
        } else if isSiteLink, let brandSlug {
            navigate(.brand(slug: brandSlug))
        } else if isSiteLink && path.contains("/products"), let categorySlug, !categorySlug.isBlankShk {
            navigate(.categoryProducts(slug: categorySlug, title: "محصولات"))
        } else if host != nil && isSiteLink {
            navigate(.webpage(url: url))
        } else {
            openLink(url)
        }
    }

    private func firstGroup(_ pattern: String, _ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}

/// معادل AppRoot اندروید: نوار پایین + تب‌ها + پشته‌ی صفحه‌ها (با محو شدن کوتاه) + سایدبار اصلی
struct AppRoot: View {
    var isDarkTheme: Bool = false
    var onToggleTheme: () -> Void = {}
    /// فقط برای عکس‌برداری CI: نمونه‌ی ViewModel صفحه‌ی اصلی و باز بودن منو
    var homeViewModel: HomeViewModel? = nil
    var initialDrawerOpen: Bool = false

    @ObservedObject private var navigator = AppNavigator.shared
    @ObservedObject private var tokenManager = TokenManager.shared
    @ObservedObject private var goftinoVm = GoftinoViewModel.shared
    @Environment(\.shkColors) private var colors

    // فاز ۲۶: سایدبار اصلی اپ - از پشت منوی همبرگری کنار لوگوی هدر باز می‌شه
    @State private var showAppDrawer = false
    // تب‌هایی که حداقل یک‌بار باز شدن (برای حفظ state، مثل saveState/restoreState اندروید)
    @State private var visitedTabs: Set<AppTab> = [.HOME]
    // سبد خرید (مرحله‌ی ۴)
    @State private var showCartSheet = false

    private var isLoggedIn: Bool { tokenManager.token != nil }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                BottomNavBar(
                    currentTab: navigator.stack.isEmpty ? navigator.tab : nil,
                    // تعداد کالای سبد خرید از مرحله‌ی ۴ (سبد خرید) وصل می‌شه
                    cartItemCount: 0,
                    isLoggedIn: isLoggedIn,
                    onTabClick: { t in
                        visitedTabs.insert(t)
                        navigator.selectTab(t)
                    },
                    onCartClick: { showCartSheet = true },
                    onChatClick: { goftinoVm.isChatVisible = true },
                    isChatOpen: goftinoVm.isChatVisible,
                    chatUnreadCount: goftinoVm.unreadCount
                )
            }
            .background(colors.background.ignoresSafeArea())

            AppDrawerOverlay(
                isPresented: $showAppDrawer,
                onOpenContact: { navigator.navigate(.contactUs) },
                onOpenGuaranty: { navigator.navigate(.webpage(url: ApiConstants.BASE_URL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/guaranty/")) },
                onOpenTerms: { navigator.navigate(.terms) },
                onOpenMagazine: { navigator.navigate(.magazine) },
                onOpenFaq: { navigator.navigate(.faqList) },
                onOpenTools: { navigator.navigate(.tools) }
            )

            ShkToastHost()
        }
        .sheet(isPresented: $showCartSheet) {
            ComingSoonScreen(title: "سبد خرید", icon: RemixIcons.ShoppingBasketLine, onBack: { showCartSheet = false })
        }
        .onAppear { if initialDrawerOpen { showAppDrawer = true } }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            // تب‌ها همیشه زنده می‌مونن تا اسکرول و داده‌شون حفظ بشه (saveState/restoreState اندروید)
            tabLayer(.HOME) { homeScreen }
            if visitedTabs.contains(.CATEGORIES) {
                tabLayer(.CATEGORIES) {
                    ComingSoonScreen(title: "دسته‌بندی", icon: RemixIcons.Apps2Line, onBack: nil)
                }
            }
            if visitedTabs.contains(.ACCOUNT) {
                tabLayer(.ACCOUNT) { accountScreen }
            }

            // صفحه‌های باز شده روی تب‌ها - بهینه‌سازی روانی: محو شدن کوتاه (ورود ۲۲۰ / خروج ۱۶۰ میلی‌ثانیه)
            ForEach(Array(navigator.stack.enumerated()), id: \.offset) { index, route in
                routeScreen(route)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colors.background.ignoresSafeArea(edges: .top))
                    .zIndex(Double(index + 1))
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.timingCurve(0, 0, 0.2, 1, duration: 0.22)),
                        removal: .opacity.animation(.linear(duration: 0.16))
                    ))
            }
        }
        .animation(.timingCurve(0, 0, 0.2, 1, duration: 0.22), value: navigator.tab)
    }

    private func tabLayer<V: View>(_ t: AppTab, @ViewBuilder _ view: () -> V) -> some View {
        let visible = navigator.tab == t
        return view()
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible && navigator.stack.isEmpty)
            .accessibilityHidden(!visible || !navigator.stack.isEmpty)
    }

    private var homeScreen: some View {
        HomeScreen(
            actions: HomeActions(
                onProductClick: { slug in navigator.navigate(.productDetail(slug: slug)) },
                onCategoryClick: { slug, title in navigator.navigate(.categoryProducts(slug: slug, title: title)) },
                onSearchSubmit: { query, cat in navigator.navigate(.searchResults(query: query, categorySlug: cat)) },
                onViewAllDiscountClick: { navigator.navigate(.categoryProducts(slug: AppRoute.DISCOUNT_PRODUCTS_SLUG, title: "پیشنهاد شگفت‌انگیز")) },
                onViewAllLatestClick: { navigator.navigate(.categoryProducts(slug: AppRoute.LATEST_PRODUCTS_SLUG, title: "جدیدترین محصولات")) },
                onViewAllMostViewedClick: { navigator.navigate(.categoryProducts(slug: AppRoute.MOST_VIEWED_PRODUCTS_SLUG, title: "پربازدیدترین محصولات")) },
                onOpenBrand: { slug in navigator.navigate(.brand(slug: slug)) },
                // فاز ۲۱: دکمه‌ی سبد خرید هدر دقیقاً همون کار دکمه‌ی سبد خریدِ نوار پایین
                onCartClick: { showCartSheet = true },
                onToggleTheme: onToggleTheme,
                onOpenMenu: { showAppDrawer = true },
                // آیکن کاربر در هدر - همون ناوبریِ دکمه‌ی «حساب من / ورود» نوار پایین
                onOpenAccount: {
                    visitedTabs.insert(.ACCOUNT)
                    navigator.selectTab(.ACCOUNT)
                },
                onOpenNotifications: { navigator.navigate(.notificationsList) },
                onOpenAnnouncement: { navigator.navigate(.announcement) },
                onViewAllInCartsClick: { navigator.navigate(.inCartsNow) },
                // دکمه‌ی لینک استوری: همون مسیریابی لینک‌های داخلی/خارجی اپ
                onOpenLink: { url in navigator.openAppLink(url) }
            ),
            cartItemCount: 0,
            isDarkTheme: isDarkTheme,
            isLoggedIn: isLoggedIn,
            viewModel: homeViewModel
        )
    }

    @ViewBuilder
    private var accountScreen: some View {
        if isLoggedIn {
            // صفحه‌ی حساب کاربری در مرحله‌ی ۵ ساخته می‌شه؛ فعلاً فقط امکان خروج برای آزمایش
            VStack(spacing: 0) {
                ComingSoonScreen(title: "حساب من", icon: RemixIcons.UserSmileLine, onBack: nil)
                SiteSecondaryButton(text: "خروج از حساب کاربری", onClick: { TokenManager.shared.clearSession() }, fillWidth: true)
                    .padding(16)
            }
        } else {
            // نیازی نیست کاری بکنیم؛ با تغییر توکن، همین صفحه خودکار به پروفایل تغییر می‌کنه
            AuthScreen(onLoginSuccess: {})
        }
    }

    @ViewBuilder
    private func routeScreen(_ route: AppRoute) -> some View {
        ComingSoonScreen(title: route.placeholderTitle, icon: RemixIcons.HammerLine, onBack: { navigator.popBackStack() })
    }
}

/// صفحه‌ی موقتِ مسیرهایی که هنوز ساخته نشدن (در مراحل بعدی با صفحه‌ی واقعی اندروید جایگزین می‌شن)
struct ComingSoonScreen: View {
    let title: String
    let icon: String
    let onBack: (() -> Void)?

    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            if let onBack {
                SitePageTopBar(title: title, onBack: onBack)
            }
            Spacer()
            SiteEmptyState(
                icon: icon,
                title: title,
                subtitle: "این بخش در مرحله‌ی بعدیِ ساخت اپ iOS، عیناً مثل اپ اندروید اضافه می‌شود."
            )
            .padding(.horizontal, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background.ignoresSafeArea(edges: .top))
    }
}
