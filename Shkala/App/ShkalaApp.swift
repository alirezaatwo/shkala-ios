import SwiftUI

@main
struct ShkalaApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // معادل ShkalaApplication.onCreate اندروید: گزارش خطا (هندلر کرش) و اعلان‌ها
        ErrorReporter.initialize()
        PushNotifier.setup()
        PushSync.scheduleBackgroundRefresh()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // برگشتن اپ به جلو: بررسی اعلان‌های جدید (معادل onResume اکتیویتی اندروید)
        .onChange(of: scenePhase) { phase in
            if phase == .active && !ScreenshotMode.isActive { PushSync.checkNow() }
        }
        // بررسی دوره‌ای اعلان‌ها در پس‌زمینه (معادل PushJobService اندروید؛ زمان اجرا دست iOS است)
        .backgroundTask(.appRefresh(PushSync.BACKGROUND_TASK_ID)) {
            PushSync.scheduleBackgroundRefresh()
            _ = await PushSync.shared.sync()
        }
    }
}

/// معادل MainActivity اپ اندروید: اسپلش ← اینترو (فقط بار اول) ← صفحه‌ی اصلی اپ
struct RootView: View {
    private enum AppStage { case splash, intro, main }

    @StateObject private var themePreference = ThemePreferenceManager()
    @State private var startupViewModel = StartupViewModel()
    @State private var stage: AppStage = .splash
    /// هر بار «تلاش مجدد» = بارگذاری مجدد کامل اپ از اسپلش (مثل recreate() اندروید)
    @State private var launchId = UUID()
    /// هشدار VPN موقع بالا اومدن اپ (معادل showStartupVpnWarning اندروید)
    @State private var showStartupVpnWarning = false

    private let screenshot = ScreenshotMode.current

    var body: some View {
        content
            .id(launchId)
            .shkalaTheme(darkTheme: screenshot?.dark ?? themePreference.isDarkTheme)
    }

    @ViewBuilder
    private var content: some View {
        if let screenshot {
            screenshotContent(screenshot)
        } else {
            switch stage {
            case .splash:
                SplashStage(viewModel: startupViewModel, onRetry: restart) {
                    showStartupVpnWarning = isVpnActive()
                    // آمار نصب، اعلان‌های جدید و صف گزارش خطا (یک‌بار در هر اجرا، در پس‌زمینه)
                    AppTelemetry.onStartupCompleted()
                    stage = IntroPreferenceManager.hasSeenIntro() ? .main : .intro
                }
            case .intro:
                IntroScreen(onFinish: {
                    IntroPreferenceManager.markIntroAsSeen()
                    stage = .main
                })
                .systemBarsBackground()
            case .main:
                // معادل MaintenanceGate { AppRoot } + لایه‌ی همیشگی گفتینو
                ZStack {
                    MaintenanceGate {
                        ZStack {
                            AppRoot(
                                isDarkTheme: themePreference.isDarkTheme,
                                onToggleTheme: { themePreference.setDarkTheme(!themePreference.isDarkTheme) }
                            )
                            // دیالوگ‌های شروع به‌ترتیب: هشدار VPN ← ...
                            StartupDialogsHost(
                                showVpnWarning: showStartupVpnWarning,
                                onVpnWarningDismiss: { showStartupVpnWarning = false }
                            )
                        }
                    }
                    GoftinoChatOverlay()
                }
                .systemBarsBackground()
            }
        }
    }

    private func restart() {
        startupViewModel = StartupViewModel()
        stage = .splash
        launchId = UUID()
    }

    @ViewBuilder
    private func screenshotContent(_ mode: ScreenshotMode) -> some View {
        switch mode.screen {
        case .splash(let ms):
            AppSplashScreen(progress: 60, fixedTimeMs: ms).systemBarsBackground()
        case .splashOffline:
            AppSplashScreen(offlineMessage: StartupViewModel.MESSAGE_NO_INTERNET, fixedTimeMs: SPLASH_LOGO_MOTION_MS)
                .systemBarsBackground()
        case .intro(let page):
            IntroScreen(onFinish: {}, initialPage: page).systemBarsBackground()
        case .main:
            // صفحه‌ی اصلی با داده‌ی زنده‌ی سایت (شبیه‌ساز CI به shkala.com دسترسی داره)
            AppRoot(isDarkTheme: mode.dark).systemBarsBackground()
        case .drawer:
            AppRoot(isDarkTheme: mode.dark, initialDrawerOpen: true).systemBarsBackground()
        case .auth(let state):
            AuthScreen(onLoginSuccess: {}, viewModel: ScreenshotMode.authViewModel(state)).systemBarsBackground()
        case .product(let slug):
            AppRoot(isDarkTheme: mode.dark)
                .systemBarsBackground()
                .task { await ScreenshotMode.openProduct(slug) }
        case .cart:
            AppRoot(isDarkTheme: mode.dark, initialCartOpen: true).systemBarsBackground()
        case .route(let name):
            AppRoot(isDarkTheme: mode.dark)
                .systemBarsBackground()
                .overlay { ScreenshotUpdateDialogHost() }
                .task { ScreenshotMode.openRoute(name) }
        case .maintenance(let countdown):
            MaintenanceScreen(
                title: nil,
                description: "برای ارائه‌ی تجربه‌ای بهتر، فروشگاه سیما حفاظ خزر در حال بروزرسانی است و به‌زودی با امکانات تازه برمی‌گردیم. از شکیبایی شما سپاسگزاریم.",
                contacts: AppContactsDto(
                    mobile1: "09120398602", mobile2: "09115585589", landline: "01333234659",
                    whatsappUrl: "http://wa.me/+989120398602", baleUrl: "https://web.bale.ai/chat?uid=1061321461"
                ),
                endsAtMillis: countdown ? nowMs() + ((2 * 3600 + 15 * 60 + 42) * 1000) : nil
            )
            .systemBarsBackground()
        }
    }
}

/// اسپلش + اجرای بارگذاری واقعی (معادل LaunchedEffect های MainActivity اندروید)
private struct SplashStage: View {
    @ObservedObject var viewModel: StartupViewModel
    @ObservedObject private var network = NetworkMonitor.shared
    let onRetry: () -> Void
    let onFinished: () -> Void

    var body: some View {
        AppSplashScreen(progress: viewModel.progress, offlineMessage: viewModel.offlineMessage, onRetry: onRetry)
            .systemBarsBackground()
            .task {
                let startup = await viewModel.startIfNeeded()
                // حداقل زمان نمایش اسپلش = طول لوگوموشن (بارگذاری هم‌زمان در جریانه)
                try? await Task.sleep(nanoseconds: UInt64(SPLASH_LOGO_MOTION_MS * 1_000_000))
                await startup.value
                if await !network.isInternetAvailable { await viewModel.markOffline() }
                // اینترنت قطع بود / قطع شد: روی اسپلش با پیام «عدم دسترسی» و دکمه‌ی تلاش مجدد می‌مونیم
                if await viewModel.offlineMessage != nil { return }
                // فرصت برای اینکه انیمیشن نوار به ۱۰۰٪ برسه و دیده بشه
                try? await Task.sleep(nanoseconds: 450_000_000)
                await MainActor.run { onFinished() }
            }
            // قطع شدن اینترنت در حین بارگذاری: ۲ ثانیه صبر و دوباره بررسی
            .onChange(of: network.isInternetAvailable) { available in
                if !available && viewModel.offlineMessage == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if !network.isInternetAvailable { viewModel.markOffline() }
                    }
                } else if available && viewModel.offlineMessage != nil {
                    // وصل شدن دوباره‌ی اینترنت: اپ خودکار از نو بارگذاری می‌شه
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if network.isInternetAvailable { onRetry() }
                    }
                }
            }
    }
}

/// حالت عکس‌برداری خودکار در CI: با آرگومان اجرای «-shkScreen <نام>» یک صفحه‌ی ثابت نمایش داده می‌شه.
/// نمونه‌ها: splash:1200 ، splash:3750 ، splash-offline ، intro:0 ، intro:5 ، main ، auth:code ، maintenance ،
/// maintenance-countdown ، drawer  (و «-shkDark» برای تم تاریک، «-shkScrollY 1200» برای اسکرول صفحه‌ی اصلی)
struct ScreenshotMode {
    enum Screen {
        case splash(Double)
        case splashOffline
        case intro(Int)
        case main
        case drawer
        case auth(String)
        case maintenance(Bool)
        // مرحله‌ی ۴: صفحه‌ی محصول (اسلاگ خالی = پربازدیدترین محصول موجود) و شیت سبد خرید
        case product(String)
        case cart
        // صفحه‌های تسویه‌حساب/پرداخت/سفارش‌ها که بدون ورود هم باز می‌شن (route:<نام>)
        case route(String)
    }

    /// فقط عکس‌برداری: باز کردن یک صفحه‌ی ثابت روی پشته‌ی ناوبری
    @MainActor
    static func openRoute(_ name: String) {
        let nav = AppNavigator.shared
        switch name {
        case "order-success": nav.navigate(.orderResult(kind: .SUCCESS, uuid: "8f3a21c7"))
        case "order-review": nav.navigate(.orderResult(kind: .PENDING_REVIEW, uuid: "8f3a21c7"))
        case "order-coordination": nav.navigate(.orderResult(kind: .PENDING_COORDINATION, uuid: "8f3a21c7"))
        case "order-failed": nav.navigate(.orderResult(kind: .FAILED, uuid: nil))
        case "address-form": nav.navigate(.addressForm(id: nil))
        case "map": nav.navigate(.mapPicker)
        case "orders": nav.navigate(.ordersList)
        case "checkout": nav.navigate(.checkout)
        // مرحله‌ی ۵ - بخش ۱: تب دسته‌بندی‌ها (سه تب)، فهرست‌ها، جستجو، برند و مجله
        case "categories": nav.selectTab(.CATEGORIES)
        case "categories-brands":
            PendingCategoriesTabViewModel.shared.requestedTab = 1
            nav.selectTab(.CATEGORIES)
        case "categories-articles":
            PendingCategoriesTabViewModel.shared.requestedTab = 2
            nav.selectTab(.CATEGORIES)
        case "discount": nav.navigate(.categoryProducts(slug: AppRoute.DISCOUNT_PRODUCTS_SLUG, title: "پیشنهاد شگفت‌انگیز"))
        case "latest": nav.navigate(.categoryProducts(slug: AppRoute.LATEST_PRODUCTS_SLUG, title: "جدیدترین محصولات"))
        case "search": nav.navigate(.searchResults(query: "دوربین", categorySlug: nil))
        case "magazine": nav.navigate(.magazine)
        // اولین دسته‌ی دارای زیردسته (برای دیدن کاروسل زیردسته‌ها)
        case "category-first", "category-list":
            Task {
                if case .success(let cats) = await CatalogRepository().getCategories(),
                   let c = cats.first(where: { !($0.childs ?? []).isEmpty }) ?? cats.first {
                    nav.navigate(.categoryProducts(slug: c.slug, title: c.title))
                }
            }
        // اولین برندِ دارای محصول
        case "brand-first":
            Task {
                if case .success(let brands) = await ContentRepository().getBrandsList(),
                   let b = brands.first(where: { $0.productsCount > 0 }) ?? brands.first {
                    nav.navigate(.brand(slug: b.slug))
                }
            }
        // مرحله‌ی ۵ - بخش ۴ تا ۷: ابزارها، پرسش‌ها، قوانین، تماس، مقاله‌ها، مقایسه، اطلاعیه و ...
        case "tools": nav.navigate(.tools)
        case "hdd": nav.navigate(.hddCalculator)
        case "faq": nav.navigate(.faqList)
        case "terms": nav.navigate(.terms)
        case "contact": nav.navigate(.contactUs)
        case "articles": nav.navigate(.articleList(slug: ALL_ARTICLES_SLUG, title: "مجله"))
        case "compare": nav.navigate(.compare)
        case "in-carts": nav.navigate(.inCartsNow)
        case "announcement": nav.navigate(.announcement)
        // مرحله‌ی ۶: مودال بروزرسانی (عادی / اجباری) با داده‌ی نمونه
        case "update": AppUpdateViewModel.shared.showScreenshotPreview(forced: false)
        case "update-forced": AppUpdateViewModel.shared.showScreenshotPreview(forced: true)
        case "guaranty": nav.navigate(.webpage(url: ApiConstants.BASE_URL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/guaranty/"))
        // اولین مقاله‌ی مجله (صفحه‌ی مقاله + دیدگاه‌ها)
        case "article-first":
            Task {
                let repo = ContentRepository()
                if case .success(let page) = await repo.getArticles(),
                   let a = page.items.first,
                   case .success(let detail) = await repo.getArticleDetail(a.slug) {
                    nav.navigate(.articleDetail(slug: a.slug, title: detail.title, html: detail.content ?? "", imageUrl: a.image?.url))
                }
            }
        default: break
        }
    }

    static var isActive: Bool { current != nil }

    /// وضعیت‌های نمایشی صفحه‌ی ورود: phone / phone-error / password / code / code-error / code-success
    @MainActor
    static func authViewModel(_ name: String) -> AuthViewModel {
        let vm = AuthViewModel()
        var s = AuthUiState()
        switch name {
        case "phone-error":
            s.phone = "0912"
            s.errorMessage = "شماره موبایل معتبر نیست. مثال: 09123456789"
        case "password":
            s.loginMode = .PASSWORD
            s.phone = "09123456789"
            s.password = "secret12"
        case "code":
            s.step = .ENTER_CODE
            s.phone = "09123456789"
            s.code = "48"
            s.remainingSeconds = 97
        case "code-error":
            s.step = .ENTER_CODE
            s.phone = "09123456789"
            s.code = "48213"
            s.remainingSeconds = 0
            s.otpStatus = .error
            s.errorMessage = "کد تایید اشتباه است."
        case "code-success":
            s.step = .ENTER_CODE
            s.phone = "09123456789"
            s.code = "48213"
            s.remainingSeconds = 45
            s.otpStatus = .success
        default:
            break
        }
        vm.debugSetState(s)
        return vm
    }

    /// فقط عکس‌برداری: باز کردن صفحه‌ی یک محصول؛ بدون اسلاگ، پربازدیدترین محصول موجود از سرور گرفته می‌شه
    @MainActor
    static func openProduct(_ slug: String) async {
        var target = slug
        if target.isEmpty {
            var filter = ProductSortFilter()
            filter.sort = .MOST_VIEWED
            filter.onlyAvailable = true
            if case .success(let page) = await CatalogRepository().getProducts(sortFilter: filter),
               let first = page.items.first {
                target = first.slug
            }
        }
        guard !target.isEmpty else { return }
        AppNavigator.shared.navigate(.productDetail(slug: target))
    }

    let screen: Screen
    let dark: Bool
    /// «-shkScrollY <عدد>»: اسکرول صفحه‌ی اصلی به این موقعیت (pt) برای عکس از بخش‌های پایین
    var scrollY: CGFloat = 0

    static let current: ScreenshotMode? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-shkScreen"), i + 1 < args.count else { return nil }
        let value = args[i + 1]
        let dark = args.contains("-shkDark")
        let parts = value.split(separator: ":").map(String.init)
        let screen: Screen
        switch parts.first {
        case "splash": screen = .splash(Double(parts.count > 1 ? parts[1] : "") ?? SPLASH_LOGO_MOTION_MS)
        case "splash-offline": screen = .splashOffline
        case "intro": screen = .intro(Int(parts.count > 1 ? parts[1] : "") ?? 0)
        case "auth": screen = .auth(parts.count > 1 ? parts[1] : "phone")
        case "drawer": screen = .drawer
        case "maintenance": screen = .maintenance(false)
        case "maintenance-countdown": screen = .maintenance(true)
        case "product": screen = .product(parts.count > 1 ? parts[1...].joined(separator: ":") : "")
        case "cart": screen = .cart
        case "route": screen = .route(parts.count > 1 ? parts[1] : "")
        default: screen = .main
        }
        var scrollY: CGFloat = 0
        if let j = args.firstIndex(of: "-shkScrollY"), j + 1 < args.count, let v = Double(args[j + 1]) { scrollY = CGFloat(v) }
        return ScreenshotMode(screen: screen, dark: dark, scrollY: scrollY)
    }()
}

/// فقط عکس‌برداری CI: پیدا کردن UIScrollView والد و اسکرول به موقعیت y (بعد از بارگذاری داده‌ها)
struct ScreenshotScrollOffset: UIViewRepresentable {
    let y: CGFloat

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        guard y > 0 else { return v }
        // چند بار تلاش، چون محتوای صفحه بعد از رسیدن داده‌های سرور بلند می‌شه
        for delay in [2.5, 4.0, 5.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak v] in
                var s = v?.superview
                while s != nil && !(s is UIScrollView) { s = s?.superview }
                guard let scroll = s as? UIScrollView else { return }
                let maxY = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                scroll.setContentOffset(CGPoint(x: 0, y: min(y, maxY) - scroll.adjustedContentInset.top), animated: false)
            }
        }
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// فقط عکس‌برداری: مودال بروزرسانی (در اپ واقعی داخل StartupDialogsHost رندر می‌شه)
private struct ScreenshotUpdateDialogHost: View {
    @ObservedObject private var viewModel = AppUpdateViewModel.shared
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .siteDialog(isPresented: $viewModel.showDialog, dismissOnClickOutside: false) {
                AppUpdateDialog(viewModel: viewModel)
            }
    }
}
