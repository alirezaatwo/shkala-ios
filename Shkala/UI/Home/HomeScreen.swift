import SwiftUI

// فاز ۲۱: شماره‌ی تماس پشتیبانی - آیکن تلفن هدر صفحه‌ی اصلی
private let SUPPORT_PHONE_NUMBER = "01333234659"

/// ناوبری‌های صفحه‌ی اصلی (پارامترهای onXxx تابع HomeScreen اندروید)
struct HomeActions {
    var onProductClick: (String) -> Void = { _ in }
    var onCategoryClick: (_ slug: String, _ title: String) -> Void = { _, _ in }
    var onSearchSubmit: (_ query: String, _ categorySlug: String?) -> Void = { _, _ in }
    var onViewAllDiscountClick: () -> Void = {}
    var onViewAllLatestClick: () -> Void = {}
    var onViewAllMostViewedClick: () -> Void = {}
    var onOpenBrand: (String) -> Void = { _ in }
    var onCartClick: () -> Void = {}
    var onToggleTheme: () -> Void = {}
    // فاز ۲۶: منوی همبرگری کنار لوگوی هدر - سایدبار اصلیِ اپ رو باز می‌کنه
    var onOpenMenu: () -> Void = {}
    var onOpenAccount: () -> Void = {}
    var onOpenNotifications: () -> Void = {}
    // نوار اطلاعیه: دکمه‌ی «مشاهده» → صفحه‌ی جزئیات اطلاعیه
    var onOpenAnnouncement: () -> Void = {}
    // «بیشتر» ماژول «همین لحظه در سبد خرید دیگران» → فهرست کامل
    var onViewAllInCartsClick: () -> Void = {}
    // دکمه‌ی لینک استوری؛ null = همون رفتار لینک بنرها/اسلایدها
    var onOpenLink: ((String) -> Void)? = nil
}

struct HomeScreen: View {
    let actions: HomeActions
    // فاز ۲۵: بج تعداد کالای سبد خرید (کنار آیکن سبد خریدِ هدر) و تاگل تم روشن/تاریک
    var cartItemCount: Int = 0
    var isDarkTheme: Bool = false
    // آیکن اعلان‌ها در هدر - مثل سایت فقط برای کاربر واردشده
    var isLoggedIn: Bool = false

    @StateObject private var viewModel: HomeViewModel
    @ObservedObject private var appStatus = AppStatusCache.shared
    @ObservedObject private var recentlyViewed = RecentlyViewedManager.shared
    @Environment(\.shkColors) private var colors

    // اگه StartupViewModel موقع بارگذاری اولیه‌ی اپ از قبل نام سایت و لوگو رو گرفته، همون فوراً نشون داده می‌شه
    @State private var siteName: String? = SiteInfoCache.isFresh() ? SiteInfoCache.siteName : nil
    @State private var logoUrl: String? = SiteInfoCache.isFresh() ? SiteInfoCache.logoUrl : nil
    @State private var logoDarkUrl: String? = SiteInfoCache.isFresh() ? SiteInfoCache.logoDarkUrl : nil
    // تعداد اعلان‌های خوانده‌نشده برای نقطه‌ی قرمز آیکن اعلان (صفحه‌ی اعلان‌ها همراه حساب کاربری - مرحله‌ی ۵)
    @State private var unreadNotificationCount = 0

    init(actions: HomeActions, cartItemCount: Int = 0, isDarkTheme: Bool = false, isLoggedIn: Bool = false, viewModel: HomeViewModel? = nil) {
        self.actions = actions
        self.cartItemCount = cartItemCount
        self.isDarkTheme = isDarkTheme
        self.isLoggedIn = isLoggedIn
        _viewModel = StateObject(wrappedValue: viewModel ?? HomeViewModel())
    }

    var body: some View {
        let state = viewModel.uiState
        // اطلاعیه‌ی فعال (از api/v2/app/status؛ هر ۶۰ ثانیه به‌روز می‌شه)
        let announcement = appStatus.announcement.flatMap { ($0.text?.isBlankShk ?? true) ? nil : $0 }
        // نسخه‌ی مناسب لوگو بر اساس تمِ فعلی؛ اگه یکی خالی بود، همونی که موجوده
        let resolvedLogoUrl = isDarkTheme
            ? (logoDarkUrl.flatMap { $0.isBlankShk ? nil : $0 } ?? logoUrl)
            : (logoUrl.flatMap { $0.isBlankShk ? nil : $0 } ?? logoDarkUrl)

        ZStack {
            colors.background.ignoresSafeArea()
            if state.isLoading {
                MaterialSpinner(color: colors.primary, lineWidth: 4, size: 40)
            } else if let error = state.errorMessage {
                VStack(spacing: 0) {
                    Text(error).shkFont(.bodyMedium).foregroundColor(colors.onSurfaceVariant).multilineTextAlignment(.center)
                    Spacer().frame(height: 16)
                    SitePrimaryButton(text: "تلاش دوباره", onClick: { viewModel.loadHome() }, height: 40)
                }
                .padding(24)
            } else {
                HomeContent(
                    state: state,
                    actions: actions,
                    siteName: siteName,
                    logoUrl: resolvedLogoUrl,
                    cartItemCount: cartItemCount,
                    isDarkTheme: isDarkTheme,
                    isLoggedIn: isLoggedIn,
                    unreadNotificationCount: unreadNotificationCount,
                    announcementText: announcement?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                    announcementButtonText: announcement?.buttonText.flatMap { $0.isBlankShk ? nil : $0 } ?? "مشاهده",
                    announcementAboveHeader: announcement?.position == ANNOUNCEMENT_POSITION_ABOVE_HEADER,
                    onModuleTabSelect: { viewModel.selectModuleTab($0, $1) },
                    onSolarTabSelect: { viewModel.selectSolarTab($0) },
                    onStoryLike: { viewModel.likeStory($0) },
                    onRefresh: {
                        // کشیدن به پایین: بروزرسانی بی‌صدای ماژول‌ها + کارت‌های «بازدیدهای اخیر»
                        viewModel.refreshRecentlyViewed(recentlyViewed.recentlyViewedExtended.map(\.slug))
                        await viewModel.refresh()
                    }
                )
            }
        }
        // «آخرین محصولاتی که مشاهده کردید»: هر بار که فهرست ذخیره‌شده‌ی گوشی عوض می‌شه
        .onAppear { viewModel.refreshRecentlyViewed(recentlyViewed.recentlyViewedExtended.map(\.slug)) }
        .onChange(of: recentlyViewed.recentlyViewedExtended) { stored in
            viewModel.refreshRecentlyViewed(stored.map(\.slug))
        }
        .task {
            if SiteInfoCache.isFresh() { return }
            if case .success(let info) = await CatalogRepository().getSiteInfo() {
                siteName = info.siteName
                logoUrl = info.logoUrl
                logoDarkUrl = info.logoDarkUrl
                SiteInfoCache.prime(name: info.siteName, logo: info.logoUrl, logoDark: info.logoDarkUrl)
            }
        }
        .onChange(of: isLoggedIn) { logged in if !logged { unreadNotificationCount = 0 } }
    }
}

// MARK: - محتوای صفحه

private struct HomeContent: View {
    let state: HomeUiState
    let actions: HomeActions
    let siteName: String?
    let logoUrl: String?
    let cartItemCount: Int
    let isDarkTheme: Bool
    let isLoggedIn: Bool
    let unreadNotificationCount: Int
    let announcementText: String?
    let announcementButtonText: String
    let announcementAboveHeader: Bool
    let onModuleTabSelect: (HomeTabbedModule, Int) -> Void
    let onSolarTabSelect: (Int) -> Void
    let onStoryLike: (Int) -> Void
    let onRefresh: () async -> Void

    // نمایشگر استوری (null = بسته)
    @State private var storyViewerIndex: Int? = nil

    private var openStoryLink: (String) -> Void {
        actions.onOpenLink ?? { url in openHomeLinkTarget(url, actions) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 12) {
                // ۱.۶: جایگاه «بالای هدر» - بالاتر از همه چیز (همراه محتوا اسکرول می‌شه)
                if announcementAboveHeader, let text = announcementText, !text.isEmpty {
                    HomeAnnouncementBar(text: text, buttonText: announcementButtonText, onOpen: actions.onOpenAnnouncement)
                }

                // بازطراحی - مرحله ۲: هدر صفحه‌ی اصلی دقیقاً با ظاهر هدر موبایل سایت (HeaderType2)
                HomeHeader(
                    logoUrl: logoUrl,
                    siteName: siteName,
                    cartItemCount: cartItemCount,
                    isDarkTheme: isDarkTheme,
                    isLoggedIn: isLoggedIn,
                    unreadNotificationCount: unreadNotificationCount,
                    categories: state.categories,
                    actions: actions
                )
                .zIndex(10)

                // استوری‌های سایت: بین خط‌چین هدر و اسلایدر اصلی
                if !state.stories.isEmpty {
                    HomeStoriesBar(stories: state.stories) { storyViewerIndex = $0 }
                }

                // نوار اطلاعیه‌ی متحرک: زیر هدر/جستجو و بالای اولین ماژول - جایگاه پیش‌فرض
                if !announcementAboveHeader, let text = announcementText, !text.isEmpty {
                    HomeAnnouncementBar(text: text, buttonText: announcementButtonText, onOpen: actions.onOpenAnnouncement)
                }

                // فاز ۱۷: بنر اسلایدر صفحه‌ی اصلی
                if !state.homeSlides.isEmpty {
                    HomeSliderBanner(slides: state.homeSlides, heightDp: state.homeSliderHeight) { slide in
                        openHomeLinkTarget(slide.link, actions)
                    }
                }

                if !state.categories.isEmpty {
                    // بازطراحی - مرحله ۳: مثل CategoryList1 سایت - ۴ دسته در هر اسلاید
                    CategoryPagerSection(categories: state.categories, onCategoryClick: actions.onCategoryClick)
                }

                // ماژول ۱ - پیشنهاد شگفت‌انگیز
                if !state.amazingOfferProducts.isEmpty {
                    AmazingOfferSection(
                        title: "پیشنهاد شگفت‌انگیز",
                        products: state.amazingOfferProducts,
                        onProductClick: actions.onProductClick,
                        // «مشاهده محصولات» = همون مقصد دکمه‌ی سایت
                        onViewAllClick: {
                            openAmazingOfferSource(state.amazingOfferSource, state.amazingOfferSiteTitle, actions, openStoryLink)
                        },
                        colors: state.amazingOfferColors
                    )
                }

                // بنر دوتایی زیر کاروسل پیشنهاد شگفت‌انگیز - با عرض کامل و زیر هم
                if !state.homeBanners2.isEmpty {
                    HomeBannerColumn(banners: state.homeBanners2) { openHomeLinkTarget($0.link, actions) }
                }

                // ماژول ۲ - جدیدترین محصولات
                if !state.latestProducts.isEmpty {
                    ProductCarouselSection(
                        title: "جدیدترین محصولات",
                        products: state.latestProducts,
                        onProductClick: actions.onProductClick,
                        onViewAllClick: actions.onViewAllLatestClick
                    )
                }

                // ماژول ۳ - پربازدیدترین محصولات
                if !state.mostViewedProducts.isEmpty {
                    ProductCarouselSection(
                        title: "پربازدیدترین محصولات",
                        products: state.mostViewedProducts,
                        onProductClick: actions.onProductClick,
                        onViewAllClick: actions.onViewAllMostViewedClick
                    )
                }

                // «همین لحظه در سبد خرید دیگران» - کمتر از حداقل = نمایش داده نمی‌شه، بیشتر از سقف = «بیشتر»
                if state.inCartsProducts.count >= max(state.inCartsMinCount, 1) {
                    let limit = max(state.inCartsCarouselLimit, 1)
                    ProductCarouselSection(
                        title: IN_CARTS_NOW_TITLE,
                        products: Array(state.inCartsProducts.prefix(limit)),
                        onProductClick: actions.onProductClick,
                        onViewAllClick: state.inCartsProducts.count > limit ? actions.onViewAllInCartsClick : nil
                    )
                }

                // ماژول «سیستم نظارتی»
                TabbedModuleSection(
                    module: .SURVEILLANCE, state: state.surveillanceModule,
                    onTabSelect: onModuleTabSelect, onProductClick: actions.onProductClick, onCategoryClick: actions.onCategoryClick
                )

                // ماژول ۴ - انرژی خورشیدی
                HomeTabbedCarouselSection(
                    title: "انرژی خورشیدی",
                    tabLabels: SOLAR_ENERGY_TABS.map(\.label),
                    selectedTabIndex: state.solarSelectedTabIndex,
                    products: state.solarProducts,
                    isLoading: state.isSolarLoading,
                    onTabSelect: onSolarTabSelect,
                    onProductClick: actions.onProductClick,
                    onViewAllClick: {
                        let tab = SOLAR_ENERGY_TABS[state.solarSelectedTabIndex]
                        actions.onCategoryClick(tab.categorySlug, tab.label)
                    }
                )

                // ماژول «ملزومات نصب»
                TabbedModuleSection(
                    module: .INSTALLATION, state: state.installationModule,
                    onTabSelect: onModuleTabSelect, onProductClick: actions.onProductClick, onCategoryClick: actions.onCategoryClick
                )

                // ماژول ۵ - بنرهای ۴تایی (کاروسل ۴اسلایده با چرخش بی‌نهایت)
                if !state.homeBanners.isEmpty {
                    HomeBannerGrid(banners: state.homeBanners) { openHomeLinkTarget($0.link, actions) }
                }

                // ماژول ۶ - کاروسل دسته‌بندی‌های ۴تایی، دقیقاً زیر بنرهای ۴تایی
                if !state.categoryProductSlides.isEmpty {
                    CategoryProductsSlidesSection(slides: state.categoryProductSlides, onProductClick: actions.onProductClick, onCategoryClick: actions.onCategoryClick)
                }

                // «نخری بردن!» - محصولات موجودِ رو به اتمام
                if !state.lowStockProducts.isEmpty {
                    ProductCarouselSection(
                        title: "نخری بردن!",
                        products: state.lowStockProducts,
                        onProductClick: actions.onProductClick,
                        // فقط در این ماژول: تعداد باقی‌مونده‌ی موجودی بین تنظیم تعداد و دکمه‌ی خرید
                        showStockLeft: true
                    )
                }

                // «آخرین محصولاتی که مشاهده کردید» - ۱۵ بازدید اخیر، جدیدترین اول
                if !state.recentlyViewedProducts.isEmpty {
                    ProductCarouselSection(
                        title: "آخرین محصولاتی که مشاهده کردید",
                        products: state.recentlyViewedProducts,
                        onProductClick: actions.onProductClick
                    )
                }
            }
            .padding(16)
            // فقط عکس‌برداری CI: اسکرول به موقعیت دلخواه (-shkScrollY) برای دیدن بخش‌های پایین صفحه
            .background(ScreenshotScrollOffset(y: ScreenshotMode.current?.scrollY ?? 0))
        }
        .refreshable {
            // محدودیت سراسری: حداکثر ۲ بار در هر دقیقه (SitePullRefresh اندروید)
            if PullRefreshRateLimiter.tryAcquire() {
                await onRefresh()
            } else {
                ShkToast.shared.show(PULL_REFRESH_LIMIT_MESSAGE, long: true)
            }
        }
        .shkDropdownHost()
        .fullScreenCover(isPresented: Binding(get: { storyViewerIndex != nil && !state.stories.isEmpty }, set: { if !$0 { storyViewerIndex = nil } })) {
            StoryViewer(
                stories: state.stories,
                startIndex: storyViewerIndex ?? 0,
                onDismiss: { dismissStoryViewer() },
                onLike: onStoryLike,
                onOpenProduct: actions.onProductClick,
                onOpenLink: openStoryLink
            )
            .background(ClearFullScreenBackground())
        }
    }

    private func dismissStoryViewer() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { storyViewerIndex = nil }
    }
}

let IN_CARTS_NOW_TITLE = "همین لحظه در سبد خرید دیگران"

// MARK: - هدر

/// بازطراحی - مرحله ۲: هدر صفحه‌ی اصلی - دقیقاً با ظاهر هدر موبایل سایت (HeaderType2):
///  - سمت راست: دکمه‌ی منو (مربع ۴۰×۴۰ با گوشه‌ی ۱۴) + لوگو (ارتفاع ۳۲)
///  - سمت چپ: قرص با گوشه‌ی ۱۵ شامل: تغییر تم، اعلان‌ها، تلفن، | ، سبد خرید با بج قرمز
///  - زیرش: فیلد جستجو + خط‌چین
private struct HomeHeader: View {
    let logoUrl: String?
    let siteName: String?
    let cartItemCount: Int
    let isDarkTheme: Bool
    let isLoggedIn: Bool
    let unreadNotificationCount: Int
    let categories: [CategoryDto]
    let actions: HomeActions
    @Environment(\.shkColors) private var colors

    var body: some View {
        let helperBackground = colors.surface // روشن: سفید / تاریک: #353542
        let iconColor = colors.onSurface       // روشن: #1C1C25 / تاریک: سفید

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // ---- منو + لوگو (سمت راست) ----
                HStack(spacing: 0) {
                    Button(action: actions.onOpenMenu) {
                        RemixIcon(RemixIcons.Menu3Line, contentDescription: "منو", tint: iconColor, size: 20)
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(helperBackground))
                    }
                    .buttonStyle(SitePressStyle())
                    Spacer().frame(width: 16)
                    if let logoUrl, !logoUrl.isBlankShk {
                        RemoteImage(logoUrl, contentDescription: siteName ?? "لوگوی فروشگاه", contentScale: .wrap)
                            .frame(height: 32)
                    } else {
                        Text(siteName.flatMap { $0.isBlankShk ? nil : $0 } ?? "")
                            .shkFont(18, .bold, lineHeight: 26)
                            .foregroundColor(colors.primary)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(-1)

                Spacer(minLength: 8)

                // ---- قرص ابزارهای کاربر (سمت چپ) ----
                HStack(spacing: 6) {
                    HeaderHelperIcon(
                        icon: isDarkTheme ? RemixIcons.SunLine : RemixIcons.MoonLine,
                        contentDescription: isDarkTheme ? "تغییر به تم روشن" : "تغییر به تم تاریک",
                        tint: iconColor,
                        onClick: actions.onToggleTheme
                    )
                    // اعلان‌ها - فقط وقتی کاربر وارد شده؛ اعلان خوانده‌نشده = نقطه‌ی قرمزِ تپنده
                    if isLoggedIn {
                        HeaderHelperIcon(
                            icon: RemixIcons.Notification2Fill,
                            contentDescription: unreadNotificationCount > 0 ? "اعلان‌ها (\(unreadNotificationCount) خوانده‌نشده)" : "اعلان‌ها",
                            tint: iconColor,
                            onClick: actions.onOpenNotifications
                        )
                        .overlay(alignment: .topLeading) {
                            if unreadNotificationCount > 0 {
                                // absoluteOffset(x=-8, y=5) از گوشه‌ی بالا-راست (TopStart در RTL)
                                PulsingNotificationDot().offset(x: 8, y: 5)
                            }
                        }
                    }
                    // تماس با پشتیبانی - هر ۴ ثانیه یک‌بار قرمز می‌شه و می‌لرزه
                    RingingPhoneIcon(normalTint: iconColor) {
                        openLink("tel:\(SUPPORT_PHONE_NUMBER)")
                    }
                    // جداکننده‌ی «|» بین سبد خرید و بقیه‌ی آیکن‌ها
                    Rectangle().fill(iconColor.opacity(0.25)).frame(width: 1, height: 18)
                    // سبد خرید - اولین آیکن از سمت چپ
                    HeaderHelperIcon(icon: RemixIcons.ShoppingCartLine, contentDescription: "سبد خرید", tint: iconColor, onClick: actions.onCartClick)
                        .overlay(alignment: .topLeading) {
                            // بج تعداد سبد خرید - مثل سایت: مستطیل قرمز با گوشه‌ی ۴، گوشه‌ی بالا-راستِ
                            // آیکن (حتی وقتی سبد خالیه، مثل سایت عدد ۰ نمایش داده می‌شه)
                            Text(cartItemCount > 99 ? "+۹۹" : cartItemCount.toPersianDigits())
                                .shkFont(10, .bold, lineHeight: 10)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(colors.primary))
                                .fixedSize()
                                // absoluteOffset(x=1, y=2): در RTL مقدار x آینه می‌شه
                                .offset(x: -1, y: 2)
                                .allowsHitTesting(false)
                        }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(helperBackground))
                .fixedSize()
            }
            .padding(.bottom, 12)

            LiveSearchBar(
                categories: categories,
                initialCategorySlug: nil,
                onOpenProduct: actions.onProductClick,
                onSubmitSearch: actions.onSearchSubmit,
                placeholder: "جستجوی سراسری ..."
            )
            Spacer().frame(height: 10)
            DashedDivider(color: isDarkTheme ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider)
            Spacer().frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

/// یک آیکنِ داخل قرص ابزارهای هدر (۲۲، ناحیه‌ی لمس ۳۰)
private struct HeaderHelperIcon: View {
    let icon: String
    let contentDescription: String
    let tint: Color
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            RemixIcon(icon, contentDescription: contentDescription, tint: tint, size: 22)
                .frame(width: 30, height: 30)
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(SitePressStyle())
    }
}

/// نقطه‌ی قرمز اعلان خوانده‌نشده - مثل .notif-badage سایت: دایره‌ی قرمز ۵ که با انیمیشن circleLoop
/// (هر ۰٫۳۵ ثانیه) تا دو برابر بزرگ و دوباره کوچیک می‌شه.
private struct PulsingNotificationDot: View {
    @Environment(\.shkColors) private var colors
    @State private var big = false

    var body: some View {
        Circle()
            .fill(colors.error)
            .frame(width: 5, height: 5)
            .scaleEffect(big ? 2 : 1)
            .onAppear {
                withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.35).repeatForever(autoreverses: true)) { big = true }
            }
    }
}

/// آیکن تلفنِ تماس با پشتیبانی که هر ۴ ثانیه یک‌بار قرمز می‌شه و مثل زنگ‌زدن می‌لرزه (حدود ۰٫۷ ثانیه)
private struct RingingPhoneIcon: View {
    let normalTint: Color
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors
    @State private var ringStart: Date? = nil

    var body: some View {
        TimelineView(.animation(paused: ringStart == nil)) { context in
            let progress = ringStart.map { min(1, context.date.timeIntervalSince($0) / 0.7) } ?? 0
            // لرزش زنگ‌مانند: زاویه = سینوسیِ میرا (±۱۸ درجه)
            let angle = progress == 0 || progress >= 1 ? 0 : sin(progress * .pi * 8) * 18 * (1 - progress)
            HeaderHelperIcon(
                icon: RemixIcons.PhoneLine,
                contentDescription: "تماس با پشتیبانی",
                tint: ringStart != nil ? colors.primary : normalTint,
                onClick: onClick
            )
            .rotationEffect(.degrees(angle))
            .animation(.linear(duration: 0.2), value: ringStart != nil)
        }
        .task {
            if ScreenshotMode.isActive { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { return }
                ringStart = Date()
                try? await Task.sleep(nanoseconds: 700_000_000)
                ringStart = nil
            }
        }
    }
}

// MARK: - بخش‌های محصولات

/// فاز ۱۸: یک بخشِ عنوان‌دار + کاروسل افقی محصولات
private struct ProductCarouselSection: View {
    let title: String
    let products: [ProductListItemDto]
    let onProductClick: (String) -> Void
    var onViewAllClick: (() -> Void)? = nil
    var showStockLeft: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            sectionTitle
                .padding(.top, 8)
                .padding(.bottom, 12)
            ProductRow(products: products, onProductClick: onProductClick, showStockLeft: showStockLeft)
        }
    }

    @ViewBuilder private var sectionTitle: some View {
        if let onViewAllClick {
            SiteSectionTitle(title) { SiteMoreButton(onClick: onViewAllClick) }
        } else {
            SiteSectionTitle(title)
        }
    }
}

/// ردیف افقی کارت‌های محصول (LazyRow با فاصله‌ی ۱۰ و عرض کارت ۱۶۰) - تا لبه‌های صفحه اسکرول می‌خوره
private struct ProductRow: View {
    let products: [ProductListItemDto]
    let onProductClick: (String) -> Void
    var showStockLeft: Bool = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            // پیشگیری از کرش «Key already used»: محصول تکراری سرور اینجا یکتا می‌شه
            LazyHStack(spacing: 10) {
                ForEach(products.distinctById()) { product in
                    ProductCard(product: product, onClick: { onProductClick(product.slug) }, stockLeft: showStockLeft ? product.bestInventory?.count : nil)
                        .frame(width: PRODUCT_CARD_CAROUSEL_WIDTH)
                }
            }
        }
    }
}

/// ماژول‌های تب‌دار جدید («سیستم نظارتی» / «ملزومات نصب») با کش و لود تنبلِ هر تب
private struct TabbedModuleSection: View {
    let module: HomeTabbedModule
    let state: TabbedModuleState
    let onTabSelect: (HomeTabbedModule, Int) -> Void
    let onProductClick: (String) -> Void
    let onCategoryClick: (String, String) -> Void

    var body: some View {
        let selectedIndex = min(max(state.selectedIndex, 0), module.tabs.count - 1)
        HomeTabbedCarouselSection(
            title: module.title,
            tabLabels: module.tabs.map(\.label),
            selectedTabIndex: selectedIndex,
            products: state.selectedProducts,
            isLoading: state.isSelectedLoading,
            onTabSelect: { onTabSelect(module, $0) },
            onProductClick: onProductClick,
            onViewAllClick: {
                let tab = module.tabs[selectedIndex]
                onCategoryClick(tab.categorySlug, tab.label)
            }
        )
    }
}

/// ماژول تب‌دار مشترک صفحه‌ی اصلی (انرژی خورشیدی، سیستم نظارتی، ملزومات نصب): عنوان با خط قرمز +
/// دکمه‌ی «بیشتر» (دسته‌بندیِ تب انتخاب‌شده)، ردیف تب‌های قابل اسکرول و کاروسل محصولات همون تب.
private struct HomeTabbedCarouselSection: View {
    let title: String
    let tabLabels: [String]
    let selectedTabIndex: Int
    let products: [ProductListItemDto]
    let isLoading: Bool
    let onTabSelect: (Int) -> Void
    let onProductClick: (String) -> Void
    let onViewAllClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            SiteSectionTitle(title) { SiteMoreButton(onClick: onViewAllClick) }
                .padding(.top, 8)
                .padding(.bottom, 12)
            SiteScrollableTabs(labels: tabLabels, selectedIndex: selectedTabIndex, onSelect: onTabSelect)
            Spacer().frame(height: 8)
            if isLoading {
                SiteLoading(size: 44).frame(maxWidth: .infinity).frame(height: 140)
            } else if products.isEmpty {
                Text("محصولی در این دسته موجود نیست.")
                    .shkFont(.bodySmall)
                    .foregroundColor(colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
            } else {
                ProductRow(products: products, onProductClick: onProductClick)
            }
        }
    }
}

// MARK: - بنرها

/// فاز ۲۶: ماژول ۵ - کاروسل بنرهای ۴تایی با چرخش بی‌نهایت (هر ۷ ثانیه)؛ هر اسلاید دقیقاً ابعاد اصلیِ
/// خودِ تصویرش رو نشون می‌ده (FillWidth، بدون ارتفاع ثابت).
private struct HomeBannerGrid: View {
    let banners: [HomeBannerDto]
    let onBannerClick: (HomeBannerDto) -> Void
    @Environment(\.shkColors) private var colors
    @State private var page: Int

    init(banners: [HomeBannerDto], onBannerClick: @escaping (HomeBannerDto) -> Void) {
        self.banners = banners
        self.onBannerClick = onBannerClick
        _page = State(initialValue: banners.count > 1 ? infiniteStartPage(banners.count) : 0)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ShkPager(pageCount: banners.count > 1 ? INFINITE_PAGE_COUNT : 1, currentPage: $page, autoAdvanceSeconds: banners.count > 1 ? 7 : nil) { p in
                let banner = banners[p % banners.count]
                RemoteImage(banner.image, contentDescription: banner.alt, contentScale: .fillWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { if !(banner.link?.isBlankShk ?? true) { onBannerClick(banner) } }
            }
            if banners.count > 1 {
                HStack(spacing: 0) {
                    ForEach(banners.indices, id: \.self) { index in
                        let isSelected = page % banners.count == index
                        Circle()
                            .fill(isSelected ? colors.primary : colors.surface.opacity(0.6))
                            .frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6)
                            .padding(.horizontal, 3)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// فاز ۲۱: ماژول بنر دوتایی (Banner2th) - با عرض کامل و زیر هم، در سایز واقعیِ خودِ تصویر، گوشه‌ی ۱۵
private struct HomeBannerColumn: View {
    let banners: [HomeBannerDto]
    let onBannerClick: (HomeBannerDto) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(banners.enumerated()), id: \.offset) { _, banner in
                RemoteImage(banner.image, contentDescription: banner.alt, contentScale: .fillWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { if !(banner.link?.isBlankShk ?? true) { onBannerClick(banner) } }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// فاز ۱۷: لینک اسلاید/بنر: «/product/{slug}» = صفحه‌ی محصول، «/brand/{slug}» = صفحه‌ی برند،
/// «/products?cat={slug}» = صفحه‌ی دسته‌بندی - و هر آدرس دیگه‌ای بیرون از اپ باز می‌شه.
func openHomeLinkTarget(_ rawLink: String?, _ actions: HomeActions) {
    guard let link = rawLink?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty else { return }
    let components = URLComponents(string: link) ?? URLComponents(string: link.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
    let path = components?.percentEncodedPath.removingPercentEncoding ?? components?.path ?? ""
    let productSlug = firstMatch(#"/product/([^/?]+)"#, in: path)
    let brandSlug = firstMatch(#"/brand/([^/?]+)"#, in: path)
    let categorySlug = components?.queryItems?.first(where: { $0.name == "cat" })?.value

    if let productSlug {
        actions.onProductClick(productSlug)
    } else if let brandSlug {
        actions.onOpenBrand(brandSlug)
    } else if path.contains("/products"), let categorySlug, !categorySlug.isBlankShk {
        actions.onCategoryClick(categorySlug, "")
    } else {
        openLink(link)
    }
}

/// اولین گروه عبارت منظم (Regex.find(...).groupValues[1])
func firstMatch(_ pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
          m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
    return String(text[r])
}

// MARK: - دسته‌بندی‌های اصلی

/// فاز ۱۷: یک شکست خط دستی نزدیک به وسط عنوان دسته‌بندی اضافه می‌کنه تا همه‌ی عنوان‌ها دوخطی و
/// هم‌تراز باشن (عنوان چندکلمه‌ای: بین دو کلمه‌ای که به نصف کل عنوان نزدیک‌تره؛ تک‌کلمه‌ای: از وسط).
private func forceTwoLineTitle(_ title: String) -> String {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count <= 1 { return trimmed }
    let words = trimmed.split(separator: " ").map(String.init).filter { !$0.isBlankShk }
    if words.count <= 1 {
        let mid = (trimmed.count + 1) / 2
        return String(trimmed.prefix(mid)) + "\n" + String(trimmed.dropFirst(mid))
    }
    let totalLength = trimmed.count
    var bestSplitIndex = 1
    var bestDiff = Int.max
    var cumulative = 0
    for i in 0..<(words.count - 1) {
        cumulative += words[i].count + 1 // +1 برای فاصله
        let diff = abs(cumulative - totalLength / 2)
        if diff < bestDiff {
            bestDiff = diff
            bestSplitIndex = i + 1
        }
    }
    return words[0..<bestSplitIndex].joined(separator: " ") + "\n" + words[bestSplitIndex...].joined(separator: " ")
}

/// بازطراحی - مرحله ۳: دسته‌بندی‌های اصلی - مثل CategoryList1 سایت: در هر اسلاید ۴ دسته، هر دسته
/// داخل کادر خودش (گوشه‌ی ۱۰)، عنوان با خط قرمز و نقطه‌های اسلاید. هر ۱۰ ثانیه خودکار به اسلاید
/// بعدی می‌ره (و بعد از آخری به اولی برمی‌گرده).
private struct CategoryPagerSection: View {
    let categories: [CategoryDto]
    let onCategoryClick: (String, String) -> Void
    @Environment(\.shkColors) private var colors
    @State private var page = 0

    var body: some View {
        let pages = stride(from: 0, to: categories.count, by: 4).map { Array(categories[$0..<min($0 + 4, categories.count)]) }
        VStack(spacing: 0) {
            SiteSectionTitle("دسته‌بندی‌های اصلی") { SitePagerDots(pageCount: pages.count, currentPage: page) }
                .padding(.bottom, 12)
            ShkPager(pageCount: pages.count, currentPage: $page, autoAdvanceSeconds: pages.count > 1 ? 10 : nil, autoAdvanceWraps: true) { p in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(pages[p]) { category in
                        CategoryPagerItem(category: category) { onCategoryClick(category.slug, category.title) }
                            .frame(maxWidth: .infinity)
                    }
                    // اگه آخرین اسلاید کمتر از ۴ دسته داشت، جای خالی حفظ بشه تا کارت‌ها هم‌اندازه بمونن
                    ForEach(0..<(4 - pages[p].count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
        .padding(.top, 8)
        .onChange(of: categories.count) { _ in page = 0 }
    }
}

private struct CategoryPagerItem: View {
    let category: CategoryDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { g in
                RemoteImage(category.image, contentDescription: category.title, contentScale: .fit)
                    .frame(width: g.size.width * 0.85, height: g.size.width * 0.85)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .frame(maxWidth: .infinity)
            }
            .aspectRatio(1 / 0.85, contentMode: .fit)
            Spacer().frame(height: 10)
            // عنوان همیشه دوخطی و کامل؛ اگه خطی از عرض کادر بیشتر بشه، فونت کمی کوچیک می‌شه
            Text(forceTwoLineTitle(category.title))
                .shkFont(11, .medium, lineHeight: 17)
                .foregroundColor(colors.onSurface)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(8 / 11)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surface))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(perform: onClick)
    }
}

// MARK: - پیشنهاد شگفت‌انگیز

/// دکمه‌ی «مشاهده محصولات» پیشنهاد شگفت‌انگیز - همون مقصد سایت: دسته‌بندی → صفحه‌ی دسته‌ی اپ؛
/// تخفیف‌دار/جدیدترین/پربازدیدترین → فهرست‌های خود اپ؛ بقیه‌ی لیست‌ها → همون صفحه‌ی /products سایت؛
/// بدون منبع (سرور قدیمی) → فهرست تخفیف‌دارها
private func openAmazingOfferSource(_ source: AmazingOfferSourceDto?, _ siteTitle: String?, _ actions: HomeActions, _ onOpenLink: (String) -> Void) {
    guard let source else { actions.onViewAllDiscountClick(); return }
    if let slug = source.categorySlug {
        actions.onCategoryClick(slug, siteTitle.flatMap { $0.isBlankShk ? nil : $0 } ?? "پیشنهاد شگفت‌انگیز")
    } else if source.hasFlag("discount") {
        actions.onViewAllDiscountClick()
    } else if source.hasFlag("most_viewed") {
        actions.onViewAllMostViewedClick()
    } else if source.hasFlag("latest") {
        actions.onViewAllLatestClick()
    } else if let url = source.url, !url.isBlankShk {
        onOpenLink(url)
    } else {
        actions.onViewAllDiscountClick()
    }
}

/// «#RRGGBB» یا «#RGB» پنل → رنگ؛ مقدار خالی/نامعتبر = null (یعنی رنگ پیش‌فرض)
func parseHexColor(_ value: String?) -> Color? {
    guard var raw = value?.trimmingCharacters(in: .whitespaces) else { return nil }
    if raw.hasPrefix("#") { raw.removeFirst() }
    let hex: String
    switch raw.count {
    case 3: hex = raw.map { "\($0)\($0)" }.joined()
    case 6: hex = raw
    default: return nil
    }
    guard let rgb = UInt32(hex, radix: 16) else { return nil }
    return Color(argb: 0xFF000000 | rgb)
}

/// ارتفاع مشترکِ دکمه‌ی «مشاهده محصولات» و کنترلر فلش‌ها در ماژول پیشنهاد شگفت‌انگیز
private let AMAZING_CONTROL_HEIGHT: CGFloat = 26

/// بازطراحی - مرحله ۳: ماژول پیشنهاد شگفت‌انگیز با ظاهر ProductList1 سایت: کادرِ طوسی با گوشه‌ی ۲۰
/// (روشن: #DFE4E8 / تاریک: #353542)، عنوان با خط قرمز، دکمه‌ی سفید «مشاهده محصولات» و کنترلر
/// تیره‌ی «< | >» داخل کادر، و کاروسل با ۲ محصول در هر نما.
private struct AmazingOfferSection: View {
    let title: String
    let products: [ProductListItemDto]
    let onProductClick: (String) -> Void
    let onViewAllClick: () -> Void
    var colors: AmazingOfferColorsDto? = nil
    @Environment(\.shkIsDark) private var isDark
    @State private var firstVisible = 0
    @State private var itemOffsets: [Int: CGFloat] = [:]

    var body: some View {
        // رنگ‌های پنل (صفحه‌ی «رنگ‌های پیشنهاد شگفت‌انگیز»)؛ هر رنگی که ست نشده = همون پیش‌فرض اپ
        let custom = isDark ? colors?.dark : colors?.light
        let boxColor = parseHexColor(custom?.background) ?? (isDark ? ShkColors.DarkBox : Color(argb: 0xFFDFE4E8))
        let titleColor = parseHexColor(custom?.title)
        let titleBarColor = parseHexColor(custom?.titleBar)
        let buttonColor = parseHexColor(custom?.buttonBackground) ?? .white
        let buttonTextColor = parseHexColor(custom?.buttonText) ?? Color(argb: 0xFF1C1C25)
        let arrowsColor = parseHexColor(custom?.arrowsBackground) ?? Color(argb: 0xFF1C1C25)
        let arrowsIconColor = parseHexColor(custom?.arrowsIcon) ?? .white
        let unique = products.distinctById()

        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                SiteSectionTitle(title, titleColor: titleColor, barColor: titleBarColor) {
                    HStack(spacing: 0) {
                        // «مشاهده محصولات» - ارتفاعش دقیقاً برابر کنترلر فلش‌هاست
                        Button(action: onViewAllClick) {
                            Text("مشاهده محصولات")
                                .shkFont(10, .bold, lineHeight: 14)
                                .foregroundColor(buttonTextColor)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .frame(height: AMAZING_CONTROL_HEIGHT)
                                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(buttonColor))
                                .materialShadow(1)
                        }
                        .buttonStyle(SitePressStyle())
                        Spacer().frame(width: 6)
                        // کنترلر فلش‌ها (تیره، مثل .swiper-slider-controller سایت)
                        HStack(spacing: 0) {
                            SiteSliderArrow(icon: RemixIcons.ArrowRightSLine, contentDescription: "قبلی", onClick: {
                                scroll(proxy, to: max(firstVisible - 1, 0), unique)
                            }, tint: arrowsIconColor)
                            Text("|").shkFont(13).foregroundColor(arrowsIconColor.opacity(0.4))
                            SiteSliderArrow(icon: RemixIcons.ArrowLeftSLine, contentDescription: "بعدی", onClick: {
                                scroll(proxy, to: min(firstVisible + 1, max(unique.count - 1, 0)), unique)
                            }, tint: arrowsIconColor)
                        }
                        .padding(.horizontal, 2)
                        .frame(height: AMAZING_CONTROL_HEIGHT)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(arrowsColor))
                    }
                }
                .padding(.bottom, 12)

                GeometryReader { geo in
                    let itemWidth = (geo.size.width - 8) / 2
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(Array(unique.enumerated()), id: \.element.id) { index, product in
                                ProductCard(product: product, onClick: { onProductClick(product.slug) })
                                    .frame(width: itemWidth)
                                    .id(index)
                                    .background(GeometryReader { g in
                                        Color.clear.preference(key: AmazingItemOffsetKey.self, value: [index: g.frame(in: .named("amazingRow")).minX])
                                    })
                            }
                        }
                    }
                    .coordinateSpace(name: "amazingRow")
                    .onPreferenceChange(AmazingItemOffsetKey.self) { offsets in
                        // معادل firstVisibleItemIndex: کارتی که بیشترِ عرضش داخل نماست، از سمت شروع (راست)
                        let width = geo.size.width
                        let visible = offsets.filter { _, x in
                            let distFromStart = width - (x + itemWidth) // فاصله‌ی لبه‌ی راست کارت تا لبه‌ی راست نما
                            return distFromStart > -itemWidth / 2
                        }.keys
                        if let first = visible.min() { firstVisible = first }
                    }
                }
                .frame(height: PRODUCT_CARD_CAROUSEL_HEIGHT * 1.0)
                .frame(height: amazingRowHeight)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(boxColor))
        .padding(.top, 8)
    }

    /// ارتفاع کارت با عرض (عرض نما - ۸)/۲ : همون فرمول ارتفاع ثابت کارت‌ها
    private var amazingRowHeight: CGFloat {
        let screen = UIScreen.main.bounds.width
        let itemWidth = (screen - 32 - 24 - 8) / 2
        return PRODUCT_CARD_CAROUSEL_HEIGHT - PRODUCT_CARD_CAROUSEL_WIDTH + itemWidth
    }

    private func scroll(_ proxy: ScrollViewProxy, to index: Int, _ items: [ProductListItemDto]) {
        guard !items.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(index, anchor: .leading) }
        firstVisible = index
    }
}

private struct AmazingItemOffsetKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - کاروسل دسته‌بندی‌های ۴تایی

/// فاز ۲۱: ماژول ۶ - هر اسلاید یک دسته‌بندیه: بالای اسلاید نام دسته + نقطه‌ها + «بیشتر»، و زیرش
/// ۴ محصولِ موجود همون دسته به‌صورت یک شبکه‌ی دو‌در‌دو.
private struct CategoryProductsSlidesSection: View {
    let slides: [CategoryProductsSlide]
    let onProductClick: (String) -> Void
    let onCategoryClick: (String, String) -> Void
    @State private var page = 0

    var body: some View {
        ShkPager(pageCount: slides.count, currentPage: $page) { p in
            let slide = slides[p]
            VStack(spacing: 0) {
                SiteSectionTitle(slide.categoryTitle) {
                    HStack(spacing: 0) {
                        SitePagerDots(pageCount: slides.count, currentPage: page)
                        Spacer().frame(width: 10)
                        SiteMoreButton(onClick: { onCategoryClick(slide.categorySlug, slide.categoryTitle) })
                    }
                }
                .padding(.bottom, 12)
                VStack(spacing: 10) {
                    ForEach(Array(stride(from: 0, to: slide.products.count, by: 2)), id: \.self) { i in
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(slide.products[i..<min(i + 2, slide.products.count)]) { product in
                                ProductCard(product: product, onClick: { onProductClick(product.slug) })
                                    .frame(maxWidth: .infinity)
                            }
                            if min(i + 2, slide.products.count) - i == 1 {
                                Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                            }
                        }
                    }
                }
            }
            .padding(.trailing, 4)
        }
        .onChange(of: slides.count) { _ in page = 0 }
    }
}

// MARK: - محدودیت کشیدن برای بروزرسانی

/// محدودیت سراسری «کشیدن برای بروزرسانی»: حداکثر ۲ بار در هر ۶۰ ثانیه‌ی اخیر در کل اپ
enum PullRefreshRateLimiter {
    private static let MAX_REFRESHES = 2
    private static let WINDOW_S: TimeInterval = 60
    private static var timestamps: [TimeInterval] = []
    private static let lock = NSLock()

    /// اگه مجاز باشه، همین تلاش ثبت می‌شه و true برمی‌گرده
    static func tryAcquire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        let now = ProcessInfo.processInfo.systemUptime
        timestamps.removeAll { now - $0 >= WINDOW_S }
        if timestamps.count >= MAX_REFRESHES { return false }
        timestamps.append(now)
        return true
    }
}

let PULL_REFRESH_LIMIT_MESSAGE = "بازسازی صفحه در هر دقیقه تنها ۲ بار ممکن است؛ لطفاً کمی بعد دوباره تلاش کنید."
