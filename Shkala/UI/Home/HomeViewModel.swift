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

/**
 * یک ماژول تب‌دار صفحه‌ی اصلی. از ۳.۳ این ماژول‌ها از قالب فعال سایت میان (ماژول‌های «تب دسته‌ها با
 * فیلتر» - GET api/v2/home/category-tabs): عنوان، ترتیب تب‌ها (همون ترتیب کشیدن در صفحه‌ساز) و محصولات
 * هر تب همه از سرور. فقط اگه درخواست خطا بده (سرور قدیمی بدون این مسیر یا قطعی اینترنت)، دو ماژول
 * ثابتِ قبلی (BUILTIN_TABBED_MODULES) با لود تنبلِ هر تب نمایش داده می‌شن.
 * fromServer=true یعنی محصولات همه‌ی تب‌ها از قبل در TabbedModuleState هستن و دوباره گرفته نمی‌شن.
 */
struct HomeTabbedModule: Equatable {
    let key: String
    let title: String
    let tabs: [SolarTab]
    let fromServer: Bool
}

/** عنوان جایگزین وقتی ماژول قالب سایت عنوانی نداره */
private let TABBED_MODULE_FALLBACK_TITLE = "محصولات منتخب"

/**
 * ماژول‌های ثابت قبلی (فقط جایگزینِ خطای درخواست). اسلاگ هر تب = نزدیک‌ترین دسته‌بندی واقعیِ
 * فروشگاه؛ فیلتر cat سرور زیردسته‌ها رو هم شامل می‌شه.
 */
let BUILTIN_TABBED_MODULES: [HomeTabbedModule] = [
    HomeTabbedModule(
        key: "builtin-surveillance",
        title: "سیستم نظارتی",
        tabs: [
            SolarTab(label: "دوربین HDCVI", categorySlug: "دوربین-hdcvi"),                 // id 13
            SolarTab(label: "دوربین IP", categorySlug: "دوربین-تحت-شبکه-ip"),              // id 15
            SolarTab(label: "دوربین هوشمند", categorySlug: "دوربین-هوشمند-wi-fi"),         // id 16
            SolarTab(label: "دستگاه XVR", categorySlug: "دستگاه-ضبط-تصویر-xvr"),           // id 32
            SolarTab(label: "دستگاه NVR", categorySlug: "دستگاه-ضبط-تصویر-nvr"),           // id 33
        ],
        fromServer: false
    ),
    HomeTabbedModule(
        key: "builtin-installation",
        title: "ملزومات نصب",
        tabs: [
            SolarTab(label: "کابل و لوله", categorySlug: "کابل-و-لوله"),                   // id 63
            SolarTab(label: "رک و باکس", categorySlug: "باکس-و-رک-دیواری"),               // id 64
            SolarTab(label: "اتصالات", categorySlug: "تجهیزات-و-اتصالات-نصب"),             // id 65
            SolarTab(label: "آداپتور و پاور", categorySlug: "آداپتور-پاور-سوئیچ-و-باتری"), // id 66
            SolarTab(label: "ذخیره ساز", categorySlug: "هارد-دیسک"),                       // id 67 «ذخیره‌سازها»
        ],
        fromServer: false
    ),
]

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
    // ماژول‌های تب‌دار (۳.۳: از قالب سایت؛ در خطای درخواست، ماژول‌های ثابت قبلی) + وضعیت هر کدوم با key
    var tabbedModules: [HomeTabbedModule] = []
    var tabbedModuleStates: [String: TabbedModuleState] = [:]
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
                fresh.tabbedModuleStates = mergeTabbedModules(current, fetched)
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
                fresh.tabbedModuleStates = keepSelectedTabs(current, fetched)
                fresh.isRefreshing = false
                uiState = fresh
                Self.primeCache(fresh)
                // ماژول‌های ثابت (جایگزین): تب انتخاب‌شده‌ی غیر از اول دوباره گرفته می‌شه
                for module in fresh.tabbedModules where !module.fromServer {
                    let selected = moduleState(module).selectedIndex
                    if selected != 0 { selectModuleTab(module.key, selected) }
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

    /**
     * تازه‌سازی بی‌صدا: برای هر ماژولی که هنوز هست (همون key)، تب انتخاب‌شده حفظ می‌شه. ماژول‌های
     * سرور محصولات تازه‌ی خودشون رو دارن؛ ماژول‌های ثابت کش تب‌های قبلی رو هم نگه می‌دارن.
     */
    private func mergeTabbedModules(_ current: HomeUiState, _ fetched: HomeUiState) -> [String: TabbedModuleState] {
        var result: [String: TabbedModuleState] = [:]
        for module in fetched.tabbedModules {
            let fresh = fetched.tabbedModuleStates[module.key] ?? TabbedModuleState()
            guard let old = current.tabbedModuleStates[module.key] else {
                result[module.key] = fresh
                continue
            }
            let selected = module.tabs.indices.contains(old.selectedIndex) ? old.selectedIndex : 0
            if module.fromServer {
                var m = fresh
                m.selectedIndex = selected
                result[module.key] = m
            } else {
                var m = old
                m.selectedIndex = selected
                m.productsByTab.merge(fresh.productsByTab) { _, new in new }
                m.loadingTabs.subtract(fresh.productsByTab.keys)
                result[module.key] = m
            }
        }
        return result
    }

    /** کشیدن به پایین: فقط تب انتخاب‌شده‌ی هر ماژولِ باقی‌مونده حفظ می‌شه (کش تب‌ها تازه گرفته می‌شه) */
    private func keepSelectedTabs(_ current: HomeUiState, _ fetched: HomeUiState) -> [String: TabbedModuleState] {
        var result: [String: TabbedModuleState] = [:]
        for module in fetched.tabbedModules {
            var fresh = fetched.tabbedModuleStates[module.key] ?? TabbedModuleState()
            let old = current.tabbedModuleStates[module.key]?.selectedIndex
            // ماژول ثابت: فقط تب اول همراه صفحه گرفته شده؛ تب انتخاب‌شده‌ی دیگه بعد از این دوباره لود می‌شه
            fresh.selectedIndex = old.flatMap { module.tabs.indices.contains($0) ? $0 : nil } ?? 0
            result[module.key] = fresh
        }
        return result
    }

    private func moduleState(_ module: HomeTabbedModule) -> TabbedModuleState {
        uiState.tabbedModuleStates[module.key] ?? TabbedModuleState()
    }

    private func updateModuleState(_ module: HomeTabbedModule, _ transform: (inout TabbedModuleState) -> Void) {
        var state = moduleState(module)
        transform(&state)
        uiState.tabbedModuleStates[module.key] = state
    }

    /**
     * انتخاب تب در ماژول‌های تب‌دار. ماژول‌های سرور محصولات همه‌ی تب‌ها رو از قبل دارن (فقط انتخاب عوض
     * می‌شه)؛ ماژول‌های ثابت هر تب رو فقط بار اول لود و بعد از کش نمایش می‌دن.
     */
    func selectModuleTab(_ moduleKey: String, _ index: Int) {
        guard let module = uiState.tabbedModules.first(where: { $0.key == moduleKey }) else { return }
        if !module.tabs.indices.contains(index) { return }
        let state = moduleState(module)
        updateModuleState(module) { $0.selectedIndex = index }
        if module.fromServer || state.productsByTab[index] != nil || state.loadingTabs.contains(index) { return }

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
        // ۳.۳: ماژول‌های تب‌دار = ماژول‌های «تب دسته‌ها با فیلتر» قالب سایت (عنوان، ترتیب تب‌ها و
        // محصولات از سرور). فهرست خالی = سایت چنین ماژولی نداره (چیزی نمایش داده نمی‌شه). فقط در خطای
        // درخواست، دو ماژول ثابت قبلی نمایش داده می‌شن و تب اولشون همراه صفحه لود می‌شه.
        async let tabbedModulesR = loadTabbedModules(repository, available)
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
        let tabbed = await tabbedModulesR

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
        s.tabbedModules = tabbed.map { $0.0 }
        s.tabbedModuleStates = Dictionary(tabbed.map { ($0.0.key, $0.1) }, uniquingKeysWith: { first, _ in first })
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

    /** ماژول‌های تب‌دار: از سرور، یا در خطای درخواست ماژول‌های ثابت با تب اولِ لودشده */
    nonisolated private static func loadTabbedModules(_ repository: CatalogRepository, _ available: ProductSortFilter) async -> [(HomeTabbedModule, TabbedModuleState)] {
        switch await repository.getHomeCategoryTabs() {
        case .success(let modules):
            return serverTabbedModules(modules)
        case .error:
            return await withTaskGroup(of: (Int, [ProductListItemDto]?).self) { group in
                for (i, module) in BUILTIN_TABBED_MODULES.enumerated() {
                    group.addTask {
                        let r = await repository.getProducts(page: 1, category: module.tabs[0].categorySlug, sortFilter: available)
                        return (i, r.successValue.map { Array($0.items.prefix(HOME_MODULE_ITEM_LIMIT)) })
                    }
                }
                var firstTabs = [Int: [ProductListItemDto]?]()
                for await (i, items) in group { firstTabs.updateValue(items, forKey: i) }
                return BUILTIN_TABBED_MODULES.enumerated().map { i, module in
                    let items = firstTabs[i] ?? nil
                    return (module, TabbedModuleState(productsByTab: items.map { [0: $0] } ?? [:]))
                }
            }
        }
    }

    /**
     * ماژول‌های سرور -> مدل اپ. تب بدون عنوان یا اسلاگ کنار گذاشته می‌شه و ماژول بدون تب نمایش داده
     * نمی‌شه. key = شناسه‌ی ماژول در قالب (یا جایگاهش) تا تب انتخاب‌شده با تازه‌سازی حفظ بشه.
     */
    nonisolated private static func serverTabbedModules(_ modules: [HomeCategoryTabsModuleDto]) -> [(HomeTabbedModule, TabbedModuleState)] {
        var seen = Set<String>()
        var result: [(HomeTabbedModule, TabbedModuleState)] = []
        for (position, dto) in modules.enumerated() {
            let tabs = (dto.tabs ?? []).filter { !($0.title?.isBlankShk ?? true) && !($0.slug?.isBlankShk ?? true) }
            if tabs.isEmpty { continue }
            let id = dto.id.flatMap { $0.isBlankShk ? nil : $0 } ?? String(position)
            let title = dto.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let module = HomeTabbedModule(
                key: "server-" + id,
                title: (title?.isEmpty ?? true) ? TABBED_MODULE_FALLBACK_TITLE : title!,
                tabs: tabs.map { SolarTab(label: $0.title!.trimmingCharacters(in: .whitespacesAndNewlines), categorySlug: $0.slug!.trimmingCharacters(in: .whitespacesAndNewlines)) },
                fromServer: true
            )
            var productsByTab: [Int: [ProductListItemDto]] = [:]
            for (index, tab) in tabs.enumerated() { productsByTab[index] = (tab.products ?? []).distinctById() }
            if seen.insert(module.key).inserted {
                result.append((module, TabbedModuleState(productsByTab: productsByTab)))
            }
        }
        return result
    }
}
