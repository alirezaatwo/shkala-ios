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
    // فهرست مقالات یک دسته‌بندی بلاگ (مرحله‌ی ۵ - بخش ۳)
    case articleList(slug: String, title: String)
    case faqList
    // مرحله‌ی ۴: تسویه‌ی حساب و پیش‌فاکتور سبد خرید
    case checkout
    case cartPrefactor
    // توضیحات کامل (یا تب محتوایی) و جدول کامل مشخصات محصول
    case productDescription(title: String, html: String)
    case fullSpecs(groups: [SpecificationGroupDto])
    // صفحه‌ی مقایسه‌ی محصولات (مرحله‌ی ۵)
    case compare
    // مرحله‌ی ۴: آدرس‌ها، نقشه، پرداخت و نتیجه‌ی سفارش
    case addresses
    case addressForm(id: Int?)
    case mapPicker
    case paymentWebView
    case cardToCard
    case orderResult(kind: OrderResultKind, uuid: String?)
    // سفارش‌های من
    case ordersList
    case orderDetail(id: Int)

    /// اسلاگ‌های قراردادی فهرست‌های «مشاهده همه» صفحه‌ی اصلی (همون Routes.*_SLUG اندروید)
    static let DISCOUNT_PRODUCTS_SLUG = "__discount__"
    static let LATEST_PRODUCTS_SLUG = "__latest__"
    static let MOST_VIEWED_PRODUCTS_SLUG = "__most_viewed__"

    /// عنوان موقت صفحه (تا ساخته شدن صفحه‌ی واقعی)
    var placeholderTitle: String {
        switch self {
        case .productDetail: return "جزئیات محصول"
        case .compare: return "مقایسه محصولات"
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
        case .articleList(_, let title): return title
        case .faqList: return "پرسش‌های متداول"
        case .checkout: return "تسویه حساب"
        case .cartPrefactor: return "پیش‌فاکتور"
        case .productDescription(let title, _): return title
        case .fullSpecs: return "مشخصات فنی محصول"
        case .addresses: return "آدرس‌ها و نحوه‌ی دریافت"
        case .addressForm(let id): return id == nil ? "افزودن آدرس" : "ویرایش آدرس"
        case .mapPicker: return "انتخاب موقعیت روی نقشه"
        case .paymentWebView: return "پرداخت"
        case .cardToCard: return "پرداخت کارت‌به‌کارت"
        case .orderResult: return "نتیجه‌ی سفارش"
        case .ordersList: return "سفارش‌های من"
        case .orderDetail: return "جزئیات سفارش"
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

    /// معادل navigate(route) { popUpTo(target) { inclusive } }: صفحه‌های بالای آخرین صفحه‌ی مطابق
    /// (و با inclusive خودش) بسته می‌شن، بعد صفحه‌ی جدید باز می‌شه
    func navigate(_ route: AppRoute, popUpTo target: (AppRoute) -> Bool, inclusive: Bool) {
        if let index = stack.lastIndex(where: target) {
            stack.removeSubrange((inclusive ? index : index + 1)...)
        }
        stack.append(route)
    }

    /// معادل navigate(route) { popUpTo(HOME) }: همه‌ی صفحه‌ها بسته می‌شن و صفحه‌ی جدید روی تب خانه باز می‌شه
    func navigateFromHome(_ route: AppRoute) {
        stack.removeAll()
        tab = .HOME
        stack.append(route)
    }

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
        let discountCode = firstGroup(#"^/discount/([^/?]+)"#, path)?.removingPercentEncoding
        if isSiteLink, let productSlug {
            navigate(.productDetail(slug: productSlug))
        } else if isSiteLink, let discountCode, !discountCode.isBlankShk {
            // لینک کمپین کد تخفیف: کد ذخیره می‌شه و در تسویه‌حساب خودکار اعمال می‌شه (صفحه‌ی اصلی می‌مونه)
            CampaignDiscountStore.save(discountCode)
            ShkToast.shared.show("کد تخفیف ذخیره شد و در مرحله‌ی پرداخت اعمال می‌شود.", long: true)
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
    /// فقط برای عکس‌برداری CI: باز بودن شیت سبد خرید
    var initialCartOpen: Bool = false

    @ObservedObject private var navigator = AppNavigator.shared
    @ObservedObject private var tokenManager = TokenManager.shared
    @ObservedObject private var goftinoVm = GoftinoViewModel.shared
    @ObservedObject private var cartViewModel = CartViewModel.shared
    @ObservedObject private var loginPrompt = LoginRequiredPrompt.shared
    @ObservedObject private var dialogCenter = ShkDialogCenter.shared
    @Environment(\.shkColors) private var colors

    // فاز ۲۶: سایدبار اصلی اپ - از پشت منوی همبرگری کنار لوگوی هدر باز می‌شه
    @State private var showAppDrawer = false
    // تب‌هایی که حداقل یک‌بار باز شدن (برای حفظ state، مثل saveState/restoreState اندروید)
    @State private var visitedTabs: Set<AppTab> = [.HOME]
    // سبد خرید (مرحله‌ی ۴)
    @State private var showCartSheet = false
    // شیت انتخاب نوعِ محصولِ چندگزینه‌ای (ProductQuickAddSheet) از روی کارت محصول
    @State private var quickAddProduct: ProductListItemDto? = nil
    // تب دسته‌بندی‌ها: شناسه‌ی ساخت دوباره و تب اولیه (requestedTab ?: lastVisitedTab ?: 0)
    @State private var categoriesEpoch = 0
    @State private var categoriesInitialTab = 0

    private var isLoggedIn: Bool { tokenManager.token != nil }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // مثل Scaffold اندروید (insets بالا): محتوای اسکرول زیر نوار وضعیت نمی‌ره
                    .clipped()
                BottomNavBar(
                    currentTab: navigator.stack.isEmpty ? navigator.tab : nil,
                    cartItemCount: cartViewModel.uiState.itemCount,
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
        // فاز ۱۴: سبد خرید تمام‌صفحه بالا میاد؛ پس‌زمینه‌ی شیت هم‌رنگ پس‌زمینه‌ی صفحه
        .sheet(isPresented: $showCartSheet) {
            CartSheetContent(
                onClose: { showCartSheet = false },
                onContinueShopping: {
                    showCartSheet = false
                    navigator.selectTab(.HOME)
                },
                onCheckout: {
                    showCartSheet = false
                    navigator.navigate(.checkout)
                },
                onPrefactor: {
                    showCartSheet = false
                    navigator.navigate(.cartPrefactor)
                }
            )
            .shkSheetEnvironment()
        }
        .sheet(item: $quickAddProduct) { product in
            ProductQuickAddSheet(productSlug: product.slug, productTitle: product.title, onDismiss: { quickAddProduct = nil })
                .shkSheetEnvironment()
                .presentationDetents([.medium, .large])
        }
        // مودال «لطفا به حساب کاربری خود وارد شوید» (مثلاً افزودن به سبد خرید توسط مهمان)؛
        // دکمه‌ی «ورود» همون ناوبریِ دکمه‌ی «حساب من / ورود» رو انجام می‌ده (صفحه‌ی ورود)
        .siteDialog(isPresented: Binding(get: { loginPrompt.isVisible }, set: { if !$0 { loginPrompt.dismiss() } })) {
            SiteDialogContent(
                title: "ورود به حساب کاربری",
                icon: RemixIcons.LoginBoxLine,
                message: "لطفا به حساب کاربری خود وارد شوید",
                confirmText: "ورود",
                onConfirm: {
                    loginPrompt.dismiss()
                    showCartSheet = false
                    visitedTabs.insert(.ACCOUNT)
                    navigator.selectTab(.ACCOUNT)
                },
                dismissText: "انصراف",
                onDismiss: { loginPrompt.dismiss() }
            )
        }
        // مودال‌های صفحه‌ها (روی کل پنجره، مثل SiteDialog اندروید)
        .siteDialog(isPresented: Binding(get: { dialogCenter.dialog != nil }, set: { if !$0 { dialogCenter.dismissFromOutside() } })) {
            dialogCenter.dialog
        }
        .onAppear {
            if initialDrawerOpen { showAppDrawer = true }
            if initialCartOpen { showCartSheet = true }
            installCartActions()
            // سبد خرید همون لحظه‌ی بالا اومدن اپ (و بعد از ورود به حساب) از سرور گرفته می‌شه تا
            // تعداد روی آیکن سبد درست باشه - نه فقط وقتی کاربر سبد رو باز می‌کنه
            if isLoggedIn { cartViewModel.loadCart(silently: true) }
        }
        // تب انتخاب‌شده از هر جای اپ (مثلاً منوی «مجله» یا لینک) هم زنده نگه داشته می‌شه
        .onChange(of: navigator.tab) { t in visitedTabs.insert(t) }
        .onChange(of: navigator.tab == .CATEGORIES && navigator.stack.isEmpty) { visible in
            guard visible else { return }
            // فاز ۳۲/۳۴: تب درخواستیِ «مجله» اولویت داره و بلافاصله پاک می‌شه؛ بعد آخرین تبی که کاربر داشت
            let pending = PendingCategoriesTabViewModel.shared
            categoriesInitialTab = pending.requestedTab ?? pending.lastVisitedTab ?? 0
            pending.requestedTab = nil
            categoriesEpoch += 1
        }
        .onChange(of: isLoggedIn) { loggedIn in
            if loggedIn { cartViewModel.loadCart(silently: true) } else { cartViewModel.clear() }
        }
    }

    /// اتصال دکمه‌ی «افزودن به سبد» کارت‌های محصول به سبد خرید مشترک اپ
    private func installCartActions() {
        ProductCartActions.addToCart = { inventoryId, quantity, onResult in
            CartViewModel.shared.addToCart(inventoryId: inventoryId, count: quantity, onResult: onResult)
        }
        ProductCartActions.openQuickAdd = { product in quickAddProduct = product }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            // تب‌ها همیشه زنده می‌مونن تا اسکرول و داده‌شون حفظ بشه (saveState/restoreState اندروید)
            tabLayer(.HOME) { homeScreen }
            if visitedTabs.contains(.CATEGORIES) {
                tabLayer(.CATEGORIES) { categoriesScreen }
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
            cartItemCount: cartViewModel.uiState.itemCount,
            isDarkTheme: isDarkTheme,
            isLoggedIn: isLoggedIn,
            viewModel: homeViewModel
        )
    }

    /// تب دسته‌بندی‌ها: در اندروید با هر بار ورود به این مقصد (از منوی پایین یا برگشت از برند/مقاله)
    /// صفحه از نو ساخته می‌شه؛ اینجا هم با عوض‌شدن شناسه همون اتفاق می‌افته
    private var categoriesScreen: some View {
        CategoriesScreen(
            onCategoryClick: { slug, title in navigator.navigate(.categoryProducts(slug: slug, title: title)) },
            onOpenBrand: { slug, currentTab in
                PendingCategoriesTabViewModel.shared.lastVisitedTab = currentTab
                navigator.navigate(.brand(slug: slug))
            },
            onOpenArticleCategory: { slug, title, currentTab in
                PendingCategoriesTabViewModel.shared.lastVisitedTab = currentTab
                navigator.navigate(.articleList(slug: slug, title: title))
            },
            initialTab: categoriesInitialTab
        )
        .id(categoriesEpoch)
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
        switch route {
        case .productDetail(let slug):
            ProductDetailScreen(
                slug: slug,
                onBack: { navigator.popBackStack() },
                onOpenDescription: { title, html in navigator.navigate(.productDescription(title: title, html: html)) },
                onOpenFullSpecs: { groups in navigator.navigate(.fullSpecs(groups: groups)) },
                onOpenRelatedProduct: { relatedSlug in navigator.navigate(.productDetail(slug: relatedSlug)) },
                onOpenCompare: { navigator.navigate(.compare) },
                onOpenBrand: { brandSlug in navigator.navigate(.brand(slug: brandSlug)) },
                onOpenCategory: { categorySlug, title in navigator.navigate(.categoryProducts(slug: categorySlug, title: title)) }
            )
            .id(slug)
        case .productDescription(let title, let html):
            ProductDescriptionScreen(title: title, html: html, onBack: { navigator.popBackStack() })
        case .fullSpecs(let groups):
            FullSpecsScreen(groups: groups, onBack: { navigator.popBackStack() })
        case .checkout:
            CheckoutScreen(
                onBack: { navigator.popBackStack() },
                onGoToAddresses: { navigator.navigate(.addresses) },
                // ادغام تسویه‌حساب و انتخاب درگاه: مستقیم به درگاه/کارت‌به‌کارت/نتیجه
                onOpenGateway: { navigator.navigate(.paymentWebView) },
                onOpenCardToCard: { navigator.navigate(.cardToCard) },
                onCoordinatedPlaced: { orderUuid in
                    navigator.navigate(.orderResult(kind: .PENDING_COORDINATION, uuid: orderUuid), popUpTo: { $0 == .checkout }, inclusive: true)
                }
            )
        case .cartPrefactor:
            CartPrefactorScreen(onBack: { navigator.popBackStack() })
        case .addresses:
            AddressListScreen(
                onBack: { navigator.popBackStack() },
                onAddAddress: { navigator.navigate(.addressForm(id: nil)) },
                onEditAddress: { address in navigator.navigate(.addressForm(id: address.id)) }
            )
        case .addressForm(let id):
            AddressFormScreen(
                addressId: id,
                onBack: { navigator.popBackStack() },
                onSaved: { navigator.popBackStack() },
                onPickLocation: { navigator.navigate(.mapPicker) }
            )
            .id(id ?? -1)
        case .mapPicker:
            MapPickerScreen(onBack: { navigator.popBackStack() }, onConfirm: { _, _ in navigator.popBackStack() })
        case .paymentWebView:
            PaymentWebViewScreen(onResult: { isSuccess, orderUuid in
                navigator.navigate(.orderResult(kind: isSuccess ? .SUCCESS : .FAILED, uuid: orderUuid),
                                   popUpTo: { $0 == .paymentWebView }, inclusive: true)
            })
        case .cardToCard:
            CardToCardScreen(
                onBack: { navigator.popBackStack() },
                onSubmitted: { orderUuid in
                    navigator.navigate(.orderResult(kind: .PENDING_REVIEW, uuid: orderUuid), popUpTo: { $0 == .checkout }, inclusive: true)
                }
            )
        case .orderResult(let kind, let uuid):
            OrderResultScreen(
                kind: kind,
                orderUuid: uuid?.isBlankShk == false ? uuid : nil,
                onBackToHome: { navigator.selectTab(.HOME) },
                // بازطراحی: دکمه‌ی ثانویه‌ی «مشاهده‌ی سفارش‌های من» در صفحه‌ی نتیجه
                onViewOrders: { navigator.navigateFromHome(.ordersList) }
            )
        case .ordersList:
            OrdersListScreen(
                onBack: { navigator.popBackStack() },
                onOrderClick: { orderId in navigator.navigate(.orderDetail(id: orderId)) }
            )
        case .orderDetail(let orderId):
            OrderDetailScreen(
                orderId: orderId,
                onBack: { navigator.popBackStack() },
                onProductClick: { slug in navigator.navigate(.productDetail(slug: slug)) }
            )
        case .categoryProducts(let slug, let title):
            let isDiscountPage = slug == AppRoute.DISCOUNT_PRODUCTS_SLUG
            let isLatestPage = slug == AppRoute.LATEST_PRODUCTS_SLUG
            let isMostViewedPage = slug == AppRoute.MOST_VIEWED_PRODUCTS_SLUG
            let isSentinelSlug = isDiscountPage || isLatestPage || isMostViewedPage
            CategoryProductsScreen(
                categorySlug: isSentinelSlug ? nil : slug,
                categoryTitle: title,
                onBack: { navigator.popBackStack() },
                onProductClick: { productSlug in navigator.navigate(.productDetail(slug: productSlug)) },
                onSearchSubmit: { query, cat in navigator.navigate(.searchResults(query: query, categorySlug: cat)) },
                forceDiscount: isDiscountPage,
                forceSort: isLatestPage ? .LATEST : (isMostViewedPage ? .MOST_VIEWED : nil),
                // فاز ۳۱: کاروسل زیردسته‌بندی‌ها - با زدن روی هرکدوم، همین صفحه دوباره برای زیردسته باز می‌شه
                onCategoryClick: { subSlug, subTitle in navigator.navigate(.categoryProducts(slug: subSlug, title: subTitle)) }
            )
        case .searchResults(let query, let cat):
            SearchResultsScreen(
                query: query,
                categorySlug: cat,
                onBack: { navigator.popBackStack() },
                onProductClick: { slug in navigator.navigate(.productDetail(slug: slug)) },
                onSearchSubmit: { newQuery, newCat in navigator.navigate(.searchResults(query: newQuery, categorySlug: newCat)) }
            )
        case .brand(let brandSlug):
            BrandScreen(
                brandSlug: brandSlug,
                onBack: { navigator.popBackStack() },
                onProductClick: { productSlug in navigator.navigate(.productDetail(slug: productSlug)) }
            )
        case .magazine:
            ArticleCategoriesScreen(
                onBack: { navigator.popBackStack() },
                onOpenArticleCategory: { slug, title in navigator.navigate(.articleList(slug: slug, title: title)) }
            )
        default:
            ComingSoonScreen(title: route.placeholderTitle, icon: RemixIcons.HammerLine, onBack: { navigator.popBackStack() })
        }
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
