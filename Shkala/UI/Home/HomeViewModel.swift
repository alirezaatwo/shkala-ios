import Foundation

/// فاز ۱۸: تب‌های کاروسل «انرژی خورشیدی» - اسلاگ واقعی هر دسته‌بندی، طبق دسته‌بندی‌های واقعی فروشگاه.
struct SolarTab: Equatable {
    let label: String
    let categorySlug: String
}

let SOLAR_ENERGY_TABS: [SolarTab] = [
    SolarTab(label: "باتری", categorySlug: "باتری-لیتیومی"),
    SolarTab(label: "اینورتر", categorySlug: "اینورتر-خورشیدی"),
    SolarTab(label: "پنل", categorySlug: "پنل-خورشیدی"),
    SolarTab(label: "پاور استیشن", categorySlug: "پاور-استیشن-و-ups"),
]

private let HOME_MODULE_ITEM_LIMIT = 15

/// ماژول‌های تب‌دار جدید صفحه‌ی اصلی (مثل «انرژی خورشیدی»). اسلاگ هر تب = نزدیک‌ترین
/// دسته‌بندی واقعیِ فروشگاه؛ فیلتر cat سرور زیردسته‌ها رو هم شامل می‌شه.
enum HomeTabbedModule: CaseIterable {
    case SURVEILLANCE, INSTALLATION

    var title: String {
        switch self {
        case .SURVEILLANCE: return "سیستم نظارتی"
        case .INSTALLATION: return "ملزومات نصب"
        }
    }

    var tabs: [SolarTab] {
        switch self {
        case .SURVEILLANCE:
            return [
                SolarTab(label: "دوربین HDCVI", categorySlug: "دوربین-hdcvi"),                 // id 13
                SolarTab(label: "دوربین IP", categorySlug: "دوربین-تحت-شبکه-ip"),              // id 15
                SolarTab(label: "دوربین هوشمند", categorySlug: "دوربین-هوشمند-wi-fi"),         // id 16
                SolarTab(label: "دستگاه XVR", categorySlug: "دستگاه-ضبط-تصویر-xvr"),           // id 32
                SolarTab(label: "دستگاه NVR", categorySlug: "دستگاه-ضبط-تصویر-nvr"),           // id 33
            ]
        case .INSTALLATION:
            return [
                SolarTab(label: "کابل و لوله", categorySlug: "کابل-و-لوله"),                   // id 63
                SolarTab(label: "رک و باکس", categorySlug: "باکس-و-رک-دیواری"),               // id 64
                SolarTab(label: "اتصالات", categorySlug: "تجهیزات-و-اتصالات-نصب"),             // id 65
                SolarTab(label: "آداپتور و پاور", categorySlug: "آداپتور-پاور-سوئیچ-و-باتری"), // id 66
                SolarTab(label: "ذخیره ساز", categorySlug: "هارد-دیسک"),                       // id 67 «ذخیره‌سازها»
            ]
        }
    }
}

/// وضعیت یک ماژول تب‌دار: تب انتخاب‌شده + کش محصولات هر تب (تب‌ها فقط بار اولِ انتخاب لود می‌شن)
struct TabbedModuleState: Equatable {
    var selectedIndex: Int = 0
    var productsByTab: [Int: [ProductListItemDto]] = [:]
    var loadingTabs: Set<Int> = []

    var selectedProducts: [ProductListItemDto] { productsByTab[selectedIndex] ?? [] }
    var isSelectedLoading: Bool { loadingTabs.contains(selectedIndex) }
}

/// فاز ۲۱: ماژول ۶ - کاروسل دسته‌بندی‌های ۴تایی. هر اسلاید ۴ محصول موجودِ یک دسته رو نشون می‌ده.
struct CategoryProductsSlide: Equatable {
    let categorySlug: String
    let categoryTitle: String
    let products: [ProductListItemDto]
}

// فاز ۲۱: فقط دسته‌بندی‌های اصلیِ اول بررسی می‌شن تا تعداد درخواست‌های موازی منفجر نشه
private let CATEGORY_SLIDE_MAX_CATEGORIES = 10
private let CATEGORY_SLIDE_PRODUCTS_PER_SLIDE = 4

// اگه سرور مقدار نفرسته، همون قانون درخواست‌شده: کمتر از ۴ = بدون ماژول، بیشتر از ۱۰ = دکمه‌ی «بیشتر»
let IN_CARTS_DEFAULT_MIN_COUNT = 4
let IN_CARTS_DEFAULT_CAROUSEL_LIMIT = 10

/// ۱.۶: مقدار announcement.position برای نمایش نوار اعلان بالای هدر (بقیه = زیر هدر، جای قبلی)
let ANNOUNCEMENT_POSITION_ABOVE_HEADER = "above_header"

struct HomeUiState: Equatable {
    var isLoading = true
    var isLoadingMore = false
    var errorMessage: String? = nil
    var categories: [CategoryDto] = []
    var products: [ProductListItemDto] = []
    var currentPage = 1
    var hasMorePages = true
    // فاز ۱۰: مرتب‌سازی/فیلتر فعلی صفحه
    var sortFilter = ProductSortFilter()
    // فیلترهای اختصاصیِ در دسترس برای همین دسته‌بندی/کوئری فعلی
    var availableDynamicFilters: [DynamicFilterDto] = []
    // فاز ۱۷: بنرهای اسلایدر صفحه‌ی اصلی
    var homeSlides: [HomeSlideDto] = []
    // ۱.۶: ارتفاع اسلایدر = «ارتفاع اسلایدر موبایل» قالب سایت؛ null = نسبت ابعاد پیش‌فرض اپ
    var homeSliderHeight: Int? = nil
    var amazingOfferProducts: [ProductListItemDto] = []
    var latestProducts: [ProductListItemDto] = []
    var mostViewedProducts: [ProductListItemDto] = []
    var solarSelectedTabIndex = 0
    var solarProducts: [ProductListItemDto] = []
    var isSolarLoading = false
    var homeBanners: [HomeBannerDto] = []
    // بنر دوتایی زیر کاروسل پیشنهاد شگفت‌انگیز
    var homeBanners2: [HomeBannerDto] = []
    // ماژول ۶ - کاروسل دسته‌بندی‌های ۴تایی، زیر بنرهای ۴تایی
    var categoryProductSlides: [CategoryProductsSlide] = []
    var surveillanceModule = TabbedModuleState()
    var installationModule = TabbedModuleState()
    // «نخری بردن!»
    var lowStockProducts: [ProductListItemDto] = []
    // «آخرین محصولاتی که مشاهده کردید» - ۱۵ بازدید اخیر (جدیدترین اول)
    var recentlyViewedProducts: [ProductListItemDto] = []
    // کشیدن به پایین برای بروزرسانی
    var isRefreshing = false
    // «همین لحظه در سبد خرید دیگران»
    var inCartsProducts: [ProductListItemDto] = []
    var inCartsMinCount = IN_CARTS_DEFAULT_MIN_COUNT
    var inCartsCarouselLimit = IN_CARTS_DEFAULT_CAROUSEL_LIMIT
    // رنگ‌های ماژول پیشنهاد شگفت‌انگیز از پنل (null = رنگ‌های پیش‌فرض اپ)
    var amazingOfferColors: AmazingOfferColorsDto? = nil
    var amazingOfferSource: AmazingOfferSourceDto? = nil
    var amazingOfferSiteTitle: String? = nil
    // استوری‌های سایت - خالی یعنی کلید سایت خاموشه یا استوری فعالی نیست
    var stories: [StoryDto] = []
}

extension Array where Element == ProductListItemDto {
    /// معادل distinctBy { it.id }
    func distinctById() -> [ProductListItemDto] {
        var seen = Set<Int>()
        return filter { seen.insert($0.id).inserted }
    }
}

/// معادل HomeViewModel اپ اندروید: هم برای صفحه‌ی اصلی (بدون فیلتر)، هم صفحه‌ی محصولات یک
/// دسته‌بندی (categorySlug)، صفحه‌ی «تخفیف‌دارها» (forceDiscount)، «جدیدترین/پربازدیدترین»
/// (forceSort) و نتایج جستجو (searchQuery).
@MainActor
final class HomeViewModel: ObservableObject {
    private let repository: CatalogRepository
    private let categorySlug: String?
    private let forceDiscount: Bool
    private let forceSort: ProductSortOption?
    private let searchQuery: String?
    private let isHomePage: Bool
    private let hasFreshCacheOnStart: Bool

    @Published private(set) var uiState: HomeUiState

    init(
        repository: CatalogRepository = CatalogRepository(),
        categorySlug: String? = nil,
        forceDiscount: Bool = false,
        forceSort: ProductSortOption? = nil,
        searchQuery: String? = nil,
        autoLoad: Bool = true
    ) {
        self.repository = repository
        self.categorySlug = categorySlug
        self.forceDiscount = forceDiscount
        self.forceSort = forceSort
        self.searchQuery = searchQuery
        isHomePage = categorySlug == nil && !forceDiscount && forceSort == nil && searchQuery == nil
        hasFreshCacheOnStart = isHomePage && Self.isHomeCacheFresh()
        // فاز ۱۹: اگه نسخه‌ی کش‌شده‌ی تازه از صفحه‌ی اصلی داریم، همون فوراً نشون داده می‌شه
        // (بدون اسپینر) و هم‌زمان در پس‌زمینه یه بار دیگه (بی‌صدا) تازه‌سازی می‌شه
        var initial = HomeUiState()
        if hasFreshCacheOnStart, var cached = Self.homeCache {
            cached.isLoading = false
            initial = cached
        }
        if forceDiscount {
            initial.sortFilter = ProductSortFilter(onlyDiscounted: true)
        } else if let forceSort {
            initial.sortFilter = ProductSortFilter(sort: forceSort, onlyAvailable: true)
        } else if searchQuery != nil {
            // مرتب‌سازی پیش‌فرض نتایج جستجو: ارزان‌ترین
            initial.sortFilter = ProductSortFilter(sort: .CHEAPEST)
        }
        uiState = initial
        if autoLoad { loadHome(silent: hasFreshCacheOnStart) }
    }

    /// فقط برای حالت عکس‌برداری CI
    func debugSetState(_ state: HomeUiState) { uiState = state }

    /// silent=true یعنی همین الان یه نسخه‌ی کش‌شده رو داریم نشون می‌دیم - پس اسپینر بارگذاری نمی‌زنیم
    func loadHome(silent: Bool = false) {
        let keepFilter = uiState.sortFilter
        if !silent {
            // بازدیدهای اخیر از حافظه‌ی گوشی میاد - با بارگذاری دوباره از بین نمی‌ره
            var s = HomeUiState(isLoading: true, sortFilter: keepFilter)
            s.recentlyViewedProducts = uiState.recentlyViewedProducts
            uiState = s
        }
        Task {
            if isHomePage {
                let fetched = await Self.fetchHomeModules(repository, keepFilter)
                // کش تب‌های ماژول‌های تب‌دار و تب انتخاب‌شده با تازه‌سازی بی‌صدا از بین نمی‌ره
                let current = uiState
                var fresh = fetched
                fresh.recentlyViewedProducts = current.recentlyViewedProducts
                fresh.surveillanceModule = mergeTabbedModule(current.surveillanceModule, fetched.surveillanceModule)
                fresh.installationModule = mergeTabbedModule(current.installationModule, fetched.installationModule)
                uiState = fresh
                Self.primeCache(fresh)
            } else {
                let result = await repository.getProducts(page: 1, category: categorySlug, search: searchQuery, sortFilter: keepFilter)
                let page = result.successValue
                var s = uiState
                s.isLoading = false
                s.errorMessage = page == nil ? "بارگذاری اطلاعات با خطا مواجه شد. اتصال اینترنت را بررسی کنید." : nil
                s.categories = []
                s.products = page?.items ?? []
                s.currentPage = 1
                s.hasMorePages = page.map { $0.pagination.currentPage < $0.pagination.lastPage } ?? false
                s.availableDynamicFilters = page?.dynamicFilters ?? []
                uiState = s
            }
        }
    }

    /// کشیدن به پایین برای بروزرسانی: مثل loadHome ولی بدون اسپینر تمام‌صفحه؛ محتوای فعلی تا
    /// رسیدن جواب سرور می‌مونه و اگه خطا بشه همون محتوای قبلی نگه داشته می‌شه.
    func refresh() async {
        if uiState.isRefreshing || uiState.isLoading || uiState.isLoadingMore { return }
        let keepFilter = uiState.sortFilter
        uiState.isRefreshing = true
        if isHomePage {
            let fetched = await Self.fetchHomeModules(repository, keepFilter)
            let current = uiState
            // اگه همه چیز خالی اومد یعنی احتمالاً اینترنت قطعه - محتوای قبلی رو نگه می‌داریم
            let looksFailed = fetched.categories.isEmpty && fetched.homeSlides.isEmpty &&
                fetched.latestProducts.isEmpty && fetched.amazingOfferProducts.isEmpty
            if looksFailed {
                uiState.isRefreshing = false
            } else {
                // تب انتخاب‌شده‌ی ماژول‌های تب‌دار حفظ می‌شه؛ کش بقیه‌ی تب‌ها دور ریخته می‌شه
                var fresh = fetched
                fresh.recentlyViewedProducts = current.recentlyViewedProducts
                fresh.surveillanceModule.selectedIndex = current.surveillanceModule.selectedIndex
                fresh.installationModule.selectedIndex = current.installationModule.selectedIndex
                fresh.isRefreshing = false
                uiState = fresh
                Self.primeCache(fresh)
                for module in HomeTabbedModule.allCases {
                    let selected = moduleState(module).selectedIndex
                    if selected != 0 { selectModuleTab(module, selected) }
                }
            }
        } else {
            let result = await repository.getProducts(page: 1, category: categorySlug, search: searchQuery, sortFilter: keepFilter)
            if let page = result.successValue {
                uiState.isRefreshing = false
                uiState.errorMessage = nil
                uiState.products = page.items
                uiState.currentPage = 1
                uiState.hasMorePages = page.pagination.currentPage < page.pagination.lastPage
                uiState.availableDynamicFilters = page.dynamicFilters
            } else {
                uiState.isRefreshing = false
            }
        }
    }

    /// فاز ۱۸: تعویض تب کاروسل انرژی خورشیدی - محصولات همون تب به‌صورت لایو بارگذاری می‌شه
    func selectSolarTab(_ index: Int) {
        if index == uiState.solarSelectedTabIndex || !SOLAR_ENERGY_TABS.indices.contains(index) { return }
        uiState.solarSelectedTabIndex = index
        uiState.isSolarLoading = true
        Task {
            let tab = SOLAR_ENERGY_TABS[index]
            let result = await repository.getProducts(page: 1, category: tab.categorySlug, sortFilter: ProductSortFilter(onlyAvailable: true))
            let items = Array((result.successValue?.items ?? []).prefix(HOME_MODULE_ITEM_LIMIT))
            // اگه تا وقتی جواب اومد، کاربر تب دیگه‌ای رو زده بود، این جواب قدیمی نادیده گرفته می‌شه
            if uiState.solarSelectedTabIndex == index {
                uiState.isSolarLoading = false
                uiState.solarProducts = items
            }
        }
    }

    private func mergeTabbedModule(_ old: TabbedModuleState, _ fresh: TabbedModuleState) -> TabbedModuleState {
        var m = old
        m.productsByTab.merge(fresh.productsByTab) { _, new in new }
        m.loadingTabs.subtract(fresh.productsByTab.keys)
        return m
    }

    private func moduleState(_ module: HomeTabbedModule) -> TabbedModuleState {
        switch module {
        case .SURVEILLANCE: return uiState.surveillanceModule
        case .INSTALLATION: return uiState.installationModule
        }
    }

    private func updateModuleState(_ module: HomeTabbedModule, _ transform: (inout TabbedModuleState) -> Void) {
        switch module {
        case .SURVEILLANCE: transform(&uiState.surveillanceModule)
        case .INSTALLATION: transform(&uiState.installationModule)
        }
    }

    /// انتخاب تب در ماژول‌های تب‌دار - محصولات هر تب فقط بار اول لود و بعد از کش نمایش داده می‌شه
    func selectModuleTab(_ module: HomeTabbedModule, _ index: Int) {
        if !module.tabs.indices.contains(index) { return }
        let state = moduleState(module)
        updateModuleState(module) { $0.selectedIndex = index }
        if state.productsByTab[index] != nil || state.loadingTabs.contains(index) { return }

        updateModuleState(module) { $0.loadingTabs.insert(index) }
        Task {
            let result = await repository.getProducts(page: 1, category: module.tabs[index].categorySlug, sortFilter: ProductSortFilter(onlyAvailable: true))
            let items = result.successValue.map { Array($0.items.prefix(HOME_MODULE_ITEM_LIMIT)) }
            updateModuleState(module) { current in
                current.loadingTabs.remove(index)
                // در صورت خطا کش نمی‌شه تا انتخاب دوباره‌ی تب، دوباره تلاش کنه
                if let items { current.productsByTab[index] = items }
            }
        }
    }

    private var recentlyViewedTask: Task<Void, Never>? = nil

    /// «آخرین محصولاتی که مشاهده کردید»: slugهای ذخیره‌شده روی گوشی (جدیدترین اول) - اطلاعات
    /// کارت (قیمت/موجودی به‌روز) از سرور گرفته می‌شه. هر بار برگشت به صفحه‌ی اصلی صدا زده می‌شه.
    func refreshRecentlyViewed(_ slugs: [String]) {
        if !isHomePage { return }
        var seen = Set<String>()
        let ordered = Array(slugs.filter { seen.insert($0).inserted }.prefix(HOME_MODULE_ITEM_LIMIT))
        if ordered.isEmpty {
            uiState.recentlyViewedProducts = []
            return
        }
        // تا رسیدن جواب سرور، همون کارت‌های قبلی با ترتیب جدید نشون داده می‌شن
        let known = Dictionary(uiState.recentlyViewedProducts.map { ($0.slug, $0) }, uniquingKeysWith: { a, _ in a })
        uiState.recentlyViewedProducts = ordered.compactMap { known[$0] }
        recentlyViewedTask?.cancel()
        recentlyViewedTask = Task {
            let result = await repository.getProductsBySlugs(ordered)
            if Task.isCancelled { return }
            if let list = result.successValue {
                let bySlug = Dictionary(list.map { ($0.slug, $0) }, uniquingKeysWith: { a, _ in a })
                uiState.recentlyViewedProducts = ordered.compactMap { bySlug[$0] }
            }
        }
    }

    /// لایک استوری - مثل سایت: فقط اگه قبلاً لایک نشده، و تعداد/وضعیت بعد از جواب سرور عوض می‌شه
    func likeStory(_ storyId: Int) {
        guard let story = uiState.stories.first(where: { $0.id == storyId }), story.isLiked != true else { return }
        Task {
            let result = await repository.likeStory(storyId)
            if let data = result.successValue {
                uiState.stories = uiState.stories.map {
                    guard $0.id == storyId else { return $0 }
                    var s = $0
                    s.like = data.like ?? s.like
                    s.isLiked = true
                    return s
                }
                if isHomePage { Self.primeCache(uiState) }
            }
        }
    }

    /// فاز ۱۰: اعمال مرتب‌سازی/فیلتر جدید - صفحه از اول بارگذاری می‌شود
    func applySortFilter(_ filter: ProductSortFilter) {
        uiState.sortFilter = filter
        loadHome()
    }

    func loadNextPageIfNeeded() {
        if isHomePage { return } // صفحه‌ی اصلی اسکرول بی‌نهایتِ فهرست تخت نداره
        if uiState.isLoadingMore || !uiState.hasMorePages || uiState.isLoading || uiState.isRefreshing { return }
        uiState.isLoadingMore = true
        Task {
            let nextPage = uiState.currentPage + 1
            let result = await repository.getProducts(page: nextPage, category: categorySlug, search: searchQuery, sortFilter: uiState.sortFilter)
            if let page = result.successValue {
                uiState.isLoadingMore = false
                uiState.products += page.items
                uiState.currentPage = nextPage
                uiState.hasMorePages = page.pagination.currentPage < page.pagination.lastPage
            } else {
                uiState.isLoadingMore = false
            }
        }
    }

    // MARK: - کش صفحه‌ی اصلی (companion اندروید)

    // فاز ۱۹: کش سبک صفحه‌ی اصلی در حافظه (نه دیسک) - برگشتن به تب خانه در همون اجرای اپ
    // فوراً (بدون اسپینر) محتوای قبلی رو نشون می‌ده و هم‌زمان در پس‌زمینه تازه‌سازی می‌شه.
    private static var homeCache: HomeUiState? = nil
    private static var homeCacheTimestamp: Int64 = 0
    private static let HOME_CACHE_TTL_MS: Int64 = 5 * 60 * 1000

    static func isHomeCacheFresh() -> Bool {
        homeCache != nil && nowMs() - homeCacheTimestamp < HOME_CACHE_TTL_MS
    }

    /// فاز ۲۰: نتیجه‌ی از پیش گرفته‌شده (توسط StartupViewModel در لودینگ اولیه‌ی اپ) رو توی همین کش
    /// می‌گذاریم تا وقتی صفحه‌ی اصلی واقعاً نمایش داده می‌شه، اسپینر جدا نشون داده نشه.
    static func primeCache(_ state: HomeUiState) {
        homeCache = state
        homeCacheTimestamp = nowMs()
    }

    /// فاز ۲۰: گرفتن هم‌زمان (موازی) ماژول‌های صفحه‌ی اصلی - هم HomeViewModel و هم StartupViewModel
    nonisolated static func fetchHomeModules(_ repository: CatalogRepository, _ keepFilter: ProductSortFilter) async -> HomeUiState {
        let available = ProductSortFilter(onlyAvailable: true)
        func items(_ r: ApiResult<ProductsPage>) -> [ProductListItemDto] {
            Array((r.successValue?.items ?? []).prefix(HOME_MODULE_ITEM_LIMIT))
        }

        async let categoriesR = repository.getCategories()
        async let sliderR = repository.getHomeSlider()
        async let bannersR = repository.getHomeBanners()
        async let banners2R = repository.getHomeBanners2()
        // پیشنهاد شگفت‌انگیز = دقیقاً ماژول ProductList1 قالب فعال سایت؛ اگه سرور قدیمی بود (یا خطا) رفتار قبلی: تخفیف‌دارها
        async let amazingSiteR = repository.getHomeAmazingOffer()
        async let latestR = repository.getProducts(page: 1, sortFilter: ProductSortFilter(sort: .LATEST, onlyAvailable: true))
        async let mostViewedR = repository.getProducts(page: 1, sortFilter: ProductSortFilter(sort: .MOST_VIEWED, onlyAvailable: true))
        async let solarR = repository.getProducts(page: 1, category: SOLAR_ENERGY_TABS[0].categorySlug, sortFilter: available)
        // ماژول‌های تب‌دار جدید: فقط تب اول همراه صفحه لود می‌شه، بقیه‌ی تب‌ها موقع انتخاب
        async let surveillanceR = repository.getProducts(page: 1, category: HomeTabbedModule.SURVEILLANCE.tabs[0].categorySlug, sortFilter: available)
        async let installationR = repository.getProducts(page: 1, category: HomeTabbedModule.INSTALLATION.tabs[0].categorySlug, sortFilter: available)
        async let inCartsR = repository.getInCartsNow()
        async let homeUiR = repository.getHomeUi()
        async let storiesR = repository.getStories()
        async let lowStockR = repository.getLowStockProducts(limit: HOME_MODULE_ITEM_LIMIT)

        let categories = await categoriesR.successValue ?? []

        // فاز ۲۱: ماژول ۶ - برای هر دسته‌بندی اصلی (حداکثر ۱۰ تای اول)، ۴ محصولِ موجودش موازی؛
        // دسته‌ای که کمتر از ۴ محصولِ موجود داشته باشه، اسلایدش نمایش داده نمی‌شه
        let slideCategories = Array(categories.prefix(CATEGORY_SLIDE_MAX_CATEGORIES))
        let slides: [CategoryProductsSlide] = await withTaskGroup(of: (Int, CategoryProductsSlide?).self) { group in
            for (i, category) in slideCategories.enumerated() {
                group.addTask {
                    let list = await repository.getProducts(page: 1, category: category.slug, sortFilter: available).successValue?.items ?? []
                    guard list.count >= CATEGORY_SLIDE_PRODUCTS_PER_SLIDE else { return (i, nil) }
                    return (i, CategoryProductsSlide(
                        categorySlug: category.slug,
                        categoryTitle: category.title,
                        products: Array(list.prefix(CATEGORY_SLIDE_PRODUCTS_PER_SLIDE))
                    ))
                }
            }
            var result = [(Int, CategoryProductsSlide?)]()
            for await r in group { result.append(r) }
            return result.sorted { $0.0 < $1.0 }.compactMap { $0.1 }
        }

        let amazingSite = await amazingSiteR.successValue
        let amazingProducts: [ProductListItemDto]
        if let amazingSite {
            amazingProducts = amazingSite.found == true ? (amazingSite.products ?? []).distinctById() : []
        } else {
            amazingProducts = items(await repository.getProducts(page: 1, sortFilter: ProductSortFilter(onlyDiscounted: true)))
        }

        let slider = await sliderR.successValue
        let inCarts = await inCartsR.successValue
        let surveillance = await surveillanceR.successValue.map { Array($0.items.prefix(HOME_MODULE_ITEM_LIMIT)) }
        let installation = await installationR.successValue.map { Array($0.items.prefix(HOME_MODULE_ITEM_LIMIT)) }

        var s = HomeUiState()
        s.isLoading = false
        s.errorMessage = nil
        s.categories = categories
        s.products = []
        s.currentPage = 1
        s.hasMorePages = false
        s.sortFilter = keepFilter
        s.homeSlides = slider?.slides ?? []
        s.homeSliderHeight = slider?.mobileHeight.flatMap { (1...2999).contains($0) ? $0 : nil }
        s.homeBanners = await bannersR.successValue?.banners ?? []
        s.homeBanners2 = await banners2R.successValue?.banners ?? []
        s.amazingOfferProducts = amazingProducts
        s.latestProducts = items(await latestR)
        s.mostViewedProducts = items(await mostViewedR)
        s.solarSelectedTabIndex = 0
        s.solarProducts = items(await solarR)
        s.categoryProductSlides = slides
        s.surveillanceModule = TabbedModuleState(productsByTab: surveillance.map { [0: $0] } ?? [:])
        s.installationModule = TabbedModuleState(productsByTab: installation.map { [0: $0] } ?? [:])
        s.lowStockProducts = await lowStockR.successValue ?? []
        s.inCartsProducts = (inCarts?.products ?? []).distinctById()
        s.inCartsMinCount = inCarts?.minCount.flatMap { $0 > 0 ? $0 : nil } ?? IN_CARTS_DEFAULT_MIN_COUNT
        s.inCartsCarouselLimit = inCarts?.carouselLimit.flatMap { $0 > 0 ? $0 : nil } ?? IN_CARTS_DEFAULT_CAROUSEL_LIMIT
        s.amazingOfferColors = await homeUiR.successValue?.amazingOfferColors
        s.amazingOfferSource = amazingSite?.found == true ? amazingSite?.source : nil
        s.amazingOfferSiteTitle = amazingSite?.found == true ? amazingSite?.title : nil
        s.stories = await storiesR.successValue ?? []
        return s
    }
}
