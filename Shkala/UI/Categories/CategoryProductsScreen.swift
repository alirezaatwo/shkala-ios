import SwiftUI

// ===================================================================================
// معادل ui/categories/CategoryProductsScreen.kt + ui/common/SearchResultsScreen.kt
// ===================================================================================

/**
 * فاز ۱۹: این صفحه هم برای «محصولات یک دسته‌بندی» (categorySlug مشخص) و هم برای
 * «مشاهده‌ی همه‌ی محصولات تخفیف‌دار» (forceDiscount=true) استفاده می‌شه.
 * بازطراحی: نوار بالای استاندارد، کاروسل زیردسته‌ها هم‌سبک «دسته‌بندی‌های اصلی» صفحه‌ی
 * اصلی، نوار ابزار آرشیو (مرتب‌سازی/فیلتر/حالت نمایش) و دکمه‌ی شناور قرصی فیلترها.
 */
struct CategoryProductsScreen: View {
    let categorySlug: String?
    let categoryTitle: String
    let onBack: () -> Void
    let onProductClick: (String) -> Void
    let onSearchSubmit: (_ query: String, _ categorySlug: String?) -> Void
    var forceDiscount: Bool = false
    // فاز ۲۲: صفحه‌ی «بیشتر»ِ جدیدترین‌ها/پربازدیدترین‌های صفحه‌ی اصلی - فقط با یه مرتب‌سازیِ ثابت
    var forceSort: ProductSortOption? = nil
    // فاز ۳۱: کاروسل زیردسته‌بندی‌های همین دسته - با زدن روی هرکدوم، همین صفحه برای اون زیردسته باز می‌شه
    var onCategoryClick: (_ slug: String, _ title: String) -> Void = { _, _ in }
    // صفحه‌ی نتایج جستجو: همین صفحه با عبارت جستجو (و دسته‌ی انتخاب‌شده در نوار جستجو، اگه باشه)
    var searchQuery: String? = nil

    @StateObject private var viewModel: HomeViewModel
    @Environment(\.shkColors) private var colors

    @State private var allCategories: [CategoryDto] = []
    // فاز ۱۰: مرتب‌سازی و فیلتر
    @State private var showSortFilterSheet = false
    // فاز ۲۶: سایدبار فیلترهای «اختصاصیِ» همین دسته‌بندی
    @State private var showFilterSidebar = false
    // فاز ۲۸: تغییر حالت نمایش محصولات بین شبکه‌ای (پیش‌فرض) و خطی/لیستی
    @State private var isGridView = true
    // ردیف‌های نمایان (برای دکمه‌ی «بازگشت به بالا» = firstVisibleItemIndex > 4)
    @State private var visibleItems: Set<Int> = []

    init(
        categorySlug: String?,
        categoryTitle: String,
        onBack: @escaping () -> Void,
        onProductClick: @escaping (String) -> Void,
        onSearchSubmit: @escaping (_ query: String, _ categorySlug: String?) -> Void,
        forceDiscount: Bool = false,
        forceSort: ProductSortOption? = nil,
        onCategoryClick: @escaping (_ slug: String, _ title: String) -> Void = { _, _ in },
        searchQuery: String? = nil
    ) {
        self.categorySlug = categorySlug
        self.categoryTitle = categoryTitle
        self.onBack = onBack
        self.onProductClick = onProductClick
        self.onSearchSubmit = onSearchSubmit
        self.forceDiscount = forceDiscount
        self.forceSort = forceSort
        self.onCategoryClick = onCategoryClick
        self.searchQuery = searchQuery
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            categorySlug: categorySlug, forceDiscount: forceDiscount, forceSort: forceSort, searchQuery: searchQuery
        ))
    }

    private var state: HomeUiState { viewModel.uiState }

    // فاز ۳۱: زیردسته‌بندی‌های همین دسته - با گشتن بازگشتی تو درخت کامل دسته‌بندی‌ها
    private func findCategoryBySlug(_ nodes: [CategoryDto], _ slug: String) -> CategoryDto? {
        for node in nodes {
            if node.slug == slug { return node }
            if let childs = node.childs, !childs.isEmpty, let found = findCategoryBySlug(childs, slug) { return found }
        }
        return nil
    }

    private var subcategories: [CategoryDto] {
        // در نتایج جستجو کاروسل زیردسته‌ها نمایش داده نمی‌شه
        guard let categorySlug, searchQuery == nil else { return [] }
        return findCategoryBySlug(allCategories, categorySlug)?.childs ?? []
    }

    private var hasDynamicFilters: Bool { !state.availableDynamicFilters.isEmpty }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // بازطراحی: نوار بالای استاندارد صفحه‌ها
                SitePageTopBar(title: categoryTitle, onBack: onBack)

                LiveSearchBar(
                    categories: allCategories,
                    initialCategorySlug: categorySlug,
                    onOpenProduct: onProductClick,
                    onSubmitSearch: onSearchSubmit
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .zIndex(2)

                mainContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(colors.background.ignoresSafeArea())

            // فاز ۲۶ + بازطراحی: دکمه‌ی شناورِ قرصیِ قرمز «فیلترها» پایین صفحه - فقط وقتی این
            // دسته‌بندی حداقل یه فیلتر اختصاصی داره. نشانِ عددی = تعداد فیلترهای اختصاصیِ فعال
            VStack {
                Spacer()
                if hasDynamicFilters && !showFilterSidebar {
                    DynamicFiltersFab(activeCount: state.sortFilter.dynamicFilters.count) { withAnimation(.easeInOut(duration: 0.25)) { showFilterSidebar = true } }
                        .padding(.bottom, 20)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: hasDynamicFilters && !showFilterSidebar)

            if hasDynamicFilters && showFilterSidebar {
                // پرده‌ی نیمه‌شفاف پشت سایدبار - با زدنش سایدبار بسته می‌شه
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { showFilterSidebar = false } }
                    .transition(.opacity)
                    .zIndex(3)
                // فاز ۲۷: این سایدبار کنار لبه‌ی چپ داکه، پس از همون سمت وارد می‌شه
                HStack(spacing: 0) {
                    CategorySpecificFiltersSidebar(
                        availableFilters: state.availableDynamicFilters,
                        current: state.sortFilter,
                        onChange: { viewModel.applySortFilter($0) },
                        onClose: { withAnimation(.easeInOut(duration: 0.25)) { showFilterSidebar = false } }
                    )
                    Spacer(minLength: 0)
                }
                .environment(\.layoutDirection, .leftToRight)
                .transition(.move(edge: .leading))
                .zIndex(4)
            }
        }
        .sheet(isPresented: $showSortFilterSheet) {
            ProductSortFilterSheet(
                current: state.sortFilter,
                onDismiss: { showSortFilterSheet = false },
                onApply: { filter in
                    viewModel.applySortFilter(filter)
                    showSortFilterSheet = false
                }
            )
            .shkSheetEnvironment()
            .presentationDetents([.height(620), .large])
        }
        .task {
            if case .success(let data) = await CatalogRepository().getCategories() { allCategories = data }
        }
        .onAppear { reportCurrentPage() }
    }

    /// آدرس همین صفحه رو ثبت می‌کنیم تا به گفتینو گزارش بشه
    private func reportCurrentPage() {
        let base = ApiConstants.BASE_URL.hasSuffix("/") ? String(ApiConstants.BASE_URL.dropLast()) : ApiConstants.BASE_URL
        let url: String
        if let searchQuery {
            let q = searchQuery.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? searchQuery
            url = "\(base)/products?search=\(q)" + (categorySlug.map { "&cat=\($0)" } ?? "")
        } else if let categorySlug {
            url = "\(base)/products?cat=\(categorySlug)"
        } else if forceDiscount {
            url = "\(base)/products?discount=1"
        } else {
            url = "\(base)/products"
        }
        CurrentPageViewModel.shared.currentPageUrl = url
        CurrentPageViewModel.shared.currentPageLabel = categoryTitle
    }

    // سربرگ آرشیو (کاروسل زیردسته‌ها + نوار ابزار) - داخل خودِ لیست تا همراه محصولات اسکرول بشه
    private var archiveHeader: some View {
        let generalActiveCount = (state.sortFilter.onlyAvailable ? 1 : 0) + (state.sortFilter.onlyDiscounted ? 1 : 0)
        return VStack(spacing: 0) {
            if !subcategories.isEmpty {
                SubcategoryPagerSection(subcategories: subcategories, onCategoryClick: onCategoryClick)
                Spacer().frame(height: 16)
            }
            ArchiveToolbar(
                sortLabel: productSortLabel(state.sortFilter.sort),
                sortActive: state.sortFilter.sort != .DEFAULT,
                activeFilterCount: generalActiveCount,
                isGridView: isGridView,
                onGridViewChange: { isGridView = $0 },
                onOpenSortFilter: { showSortFilterSheet = true }
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyTitle: String {
        if searchQuery != nil { return "محصولی پیدا نشد" }
        if categorySlug != nil { return "محصولی تو این دسته‌بندی پیدا نشد" }
        if forceDiscount { return "محصول تخفیف‌داری پیدا نشد" }
        return "محصولی پیدا نشد"
    }

    @ViewBuilder
    private var mainContent: some View {
        if state.isLoading {
            VStack(spacing: 0) {
                archiveHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                SiteLoading(icon: RemixIcons.ShoppingBag3Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else if let errorMessage = state.errorMessage {
            ScrollView {
                VStack(spacing: 0) {
                    archiveHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    SiteEmptyState(
                        icon: RemixIcons.ErrorWarningLine,
                        title: errorMessage,
                        subtitle: nil,
                        actionLabel: "تلاش دوباره",
                        actionIcon: RemixIcons.RefreshLine,
                        onAction: { viewModel.loadHome() }
                    )
                    .padding(16)
                }
            }
            .sitePullRefresh { await viewModel.refresh() }
        } else if state.products.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    archiveHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    SiteEmptyState(icon: RemixIcons.ShoppingBag3Line, title: emptyTitle, subtitle: nil)
                        .padding(16)
                }
            }
            .sitePullRefresh { await viewModel.refresh() }
        } else {
            productsList
        }
    }

    // کشیدن به پایین: صفحه‌ی اول محصولات بی‌صدا دوباره گرفته می‌شه و جای فهرست فعلی رو می‌گیره
    private var productsList: some View {
        // فضای خالی پایین لیست تا دکمه‌ی شناور فیلترها روی آخرین محصول نیفته
        let bottomPadding: CGFloat = hasDynamicFilters ? 84 : 16
        let products = state.products.distinctById()
        let gridColumns = [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top)]
        return ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    if isGridView {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            Section {
                                // اصلاحیه: اگه لیست محصولات سرور یک محصول رو دوبار داشته باشه، اینجا یکتا می‌شه
                                ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                                    ProductCard(product: product, onClick: { onProductClick(product.slug) })
                                        .onAppear {
                                            visibleItems.insert(index + 1)
                                            // اسکرول بی‌نهایت: نزدیک انتهای فهرست، صفحه‌ی بعدی محصولات گرفته می‌شه
                                            if index + 1 >= products.count + 1 - 6 { viewModel.loadNextPageIfNeeded() }
                                        }
                                        .onDisappear { visibleItems.remove(index + 1) }
                                }
                            } header: {
                                archiveHeader
                                    .id("archive_header")
                                    .onAppear { visibleItems.insert(0) }
                                    .onDisappear { visibleItems.remove(0) }
                            } footer: {
                                if state.isLoadingMore { LoadMoreIndicator() }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, bottomPadding)
                    } else {
                        // فاز ۲۸: حالت خطی - هر محصول یک ردیف افقی (تصویر کوچیک + عنوان/قیمت/امتیاز)
                        LazyVStack(spacing: 10) {
                            archiveHeader
                                .id("archive_header")
                                .onAppear { visibleItems.insert(0) }
                                .onDisappear { visibleItems.remove(0) }
                            ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                                ProductListRow(product: product, onClick: { onProductClick(product.slug) })
                                    .onAppear {
                                        visibleItems.insert(index + 1)
                                        // اسکرول بی‌نهایت در حالت خطی
                                        if index + 1 >= products.count + 1 - 4 { viewModel.loadNextPageIfNeeded() }
                                    }
                                    .onDisappear { visibleItems.remove(index + 1) }
                            }
                            if state.isLoadingMore { LoadMoreIndicator() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, bottomPadding)
                    }
                }
                .sitePullRefresh { await viewModel.refresh() }
                .onChange(of: isGridView) { _ in visibleItems = [] }

                ScrollToTopButton(visible: (visibleItems.min() ?? 0) > 4) {
                    withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo("archive_header", anchor: .top) }
                }
            }
        }
    }
}

/** صفحه‌ی نتایج جستجو: همون صفحه‌ی محصولات با عبارت جستجو (معادل SearchResultsScreen.kt) */
struct SearchResultsScreen: View {
    let query: String
    let categorySlug: String?
    let onBack: () -> Void
    let onProductClick: (String) -> Void
    let onSearchSubmit: (_ query: String, _ categorySlug: String?) -> Void

    var body: some View {
        CategoryProductsScreen(
            categorySlug: categorySlug,
            categoryTitle: "نتایج برای «\(query)»",
            onBack: onBack,
            onProductClick: onProductClick,
            onSearchSubmit: onSearchSubmit,
            searchQuery: query
        )
    }
}

/** دکمه‌ی شناورِ قرصیِ قرمز فیلترهای اختصاصی، با نشان تعداد فیلترهای فعال */
private struct DynamicFiltersFab: View {
    let activeCount: Int
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        Button(action: onClick) {
            HStack(spacing: 0) {
                RemixIcon(RemixIcons.FilterLine, contentDescription: "فیلترهای اختصاصی محصولات", tint: .white, size: 19)
                Spacer().frame(width: 8)
                Text("فیلترها").shkFont(13, .bold).foregroundColor(.white)
                if activeCount > 0 {
                    Spacer().frame(width: 8)
                    ZStack {
                        Circle().fill(Color.white)
                        Text(activeCount.toPersianDigits()).shkFont(11, .bold, lineHeight: 14).foregroundColor(primary)
                    }
                    .frame(width: 24, height: 24)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, activeCount > 0 ? 8 : 18)
            .frame(height: 46)
            .background(Capsule().fill(primary).shadow(color: primary.opacity(0.5), radius: 8, x: 0, y: 5))
        }
        .buttonStyle(SitePressStyle())
    }
}

/**
 * نوار ابزار آرشیو محصولات: دکمه‌ی مرتب‌سازی (با نمایش مرتب‌سازی فعلی)، دکمه‌ی فیلتر (با نشان
 * تعداد فیلترهای فعال) - هر دو همون شیت «مرتب‌سازی و فیلتر» رو باز می‌کنن - و کلید دوحالته‌ی
 * نمایش شبکه‌ای/خطی.
 */
private struct ArchiveToolbar: View {
    let sortLabel: String
    let sortActive: Bool
    let activeFilterCount: Int
    let isGridView: Bool
    let onGridViewChange: (Bool) -> Void
    let onOpenSortFilter: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        SiteCard(contentPadding: .all(8), radius: 16) {
            HStack(spacing: 0) {
                // مرتب‌سازی
                Button(action: onOpenSortFilter) {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: RemixIcons.ArrowUpDownLine, size: 34, iconSize: 18, radius: 10)
                        Spacer().frame(width: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("مرتب‌سازی").shkFont(10, lineHeight: 14).foregroundColor(colors.onSurfaceVariant)
                            Text(sortLabel)
                                .shkFont(13, .bold, lineHeight: 18)
                                .foregroundColor(sortActive ? primary : colors.onSurface)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                // فیلتر عمومی
                Button(action: onOpenSortFilter) {
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.Filter3Line, contentDescription: "مرتب‌سازی و فیلتر", tint: activeFilterCount > 0 ? primary : colors.onSurface, size: 18)
                        Spacer().frame(width: 6)
                        Text("فیلتر").shkFont(12, .bold).foregroundColor(activeFilterCount > 0 ? primary : colors.onSurface)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(activeFilterCount > 0 ? primary.opacity(0.1) : colors.surfaceVariant))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .topTrailing) {
                    if activeFilterCount > 0 {
                        ZStack {
                            Circle().fill(primary)
                            Text(activeFilterCount.toPersianDigits()).shkFont(9, .bold, lineHeight: 12).foregroundColor(.white)
                        }
                        .frame(width: 16, height: 16)
                    }
                }

                Spacer().frame(width: 8)

                // فاز ۲۸ + بازطراحی: کلید دوحالته‌ی نمایش شبکه‌ای/خطی
                HStack(spacing: 0) {
                    ViewModeCell(icon: RemixIcons.LayoutGridLine, contentDescription: "نمایش شبکه‌ای", selected: isGridView) { onGridViewChange(true) }
                    ViewModeCell(icon: RemixIcons.ListCheck, contentDescription: "نمایش خطی", selected: !isGridView) { onGridViewChange(false) }
                }
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant))
            }
        }
    }
}

/** یک خانه‌ی کلید حالت نمایش (فعال: قرمز پُر با آیکن سفید) */
private struct ViewModeCell: View {
    let icon: String
    let contentDescription: String
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(selected ? colors.primary : Color.clear)
                RemixIcon(icon, contentDescription: contentDescription, tint: selected ? .white : colors.onSurfaceVariant, size: 17)
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

/**
 * فاز ۳۱ + بازطراحی: کاروسل زیردسته‌بندی‌های همین دسته - دقیقاً هم‌سبک «دسته‌بندی‌های اصلی»
 * صفحه‌ی اصلی: در هر اسلاید ۴ زیردسته، عنوان با خط قرمز و نقطه‌های اسلاید، جابه‌جایی خودکار
 * هر ۱۰ ثانیه.
 */
private struct SubcategoryPagerSection: View {
    let subcategories: [CategoryDto]
    let onCategoryClick: (_ slug: String, _ title: String) -> Void
    @State private var page = 0

    var body: some View {
        let pages = stride(from: 0, to: subcategories.count, by: 4).map { Array(subcategories[$0..<min($0 + 4, subcategories.count)]) }
        VStack(spacing: 0) {
            SiteSectionTitle("زیردسته‌بندی‌ها") { SitePagerDots(pageCount: pages.count, currentPage: page) }
                .padding(.bottom, 12)
            ShkPager(pageCount: pages.count, currentPage: $page, autoAdvanceSeconds: pages.count > 1 ? 10 : nil, autoAdvanceWraps: true) { p in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(pages[p]) { category in
                        CategoryPagerItem(category: category) { onCategoryClick(category.slug, category.title) }
                            .frame(maxWidth: .infinity)
                    }
                    // اگه آخرین اسلاید کمتر از ۴ زیردسته داشت، جای خالی حفظ بشه تا کارت‌ها هم‌اندازه بمونن
                    ForEach(0..<(4 - pages[p].count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
    }
}

/** معادل rating.toString() کاتلین (Double → «4.5» / null → «null») */
private func kotlinRatingText(_ rating: Double?) -> String {
    guard let rating else { return "null" }
    return rating == rating.rounded() ? String(format: "%.1f", rating) : String(rating)
}

/**
 * فاز ۲۸: کارتِ افقیِ حالت «نمایش خطی» - تصویر کوچیک + عنوان/امتیاز/قیمت کنار هم.
 */
private struct ProductListRow: View {
    let product: ProductListItemDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors
    @State private var quantity: Int
    @State private var isAdding = false

    init(product: ProductListItemDto, onClick: @escaping () -> Void) {
        self.product = product
        self.onClick = onClick
        _quantity = State(initialValue: product.minQuantity)
    }

    var body: some View {
        SiteCard(onClick: onClick, contentPadding: .all(10)) {
            HStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    colors.surfaceVariant
                    RemoteImage(product.mainImageUrl, contentDescription: product.title, contentScale: .crop)
                    // نشان درصد تخفیف (همون نشانِ کارت حالت گرید)
                    if product.hasDiscount, let percent = product.bestNormalPrice?.percent {
                        Text("٪\(String(percent).toPersianDigits())-")
                            .shkFont(10, .bold, lineHeight: 14)
                            .foregroundColor(colors.onPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(colors.primary))
                            .padding(4)
                    }
                }
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 0) {
                    Text(product.title)
                        .shkFont(12, .medium, lineHeight: 20)
                        .foregroundColor(colors.onSurface)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let info = product.commentsInfo, info.count != "0" {
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.StarFill, tint: colors.primary, size: 13)
                            Spacer().frame(width: 4)
                            Text("\(kotlinRatingText(info.rating).toPersianDigits()) (\(info.count.toPersianDigits()))")
                                .shkFont(11)
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                        .padding(.top, 4)
                    }
                    Spacer().frame(height: 6)
                    if !product.inventory {
                        Text("ناموجود").shkFont(12, .bold).foregroundColor(colors.error)
                    } else if let best = product.bestNormalPrice {
                        if product.hasDiscount {
                            Text("\((best.price ?? "null").toPersianDigits()) تومان")
                                .shkFont(11)
                                .foregroundColor(colors.onSurfaceVariant)
                                .strikethrough(true, color: colors.onSurfaceVariant)
                            Text("\((best.discountPrice ?? "null").toPersianDigits()) تومان")
                                .shkFont(14, .bold)
                                .foregroundColor(colors.primary)
                        } else {
                            Text("\(best.price?.toPersianDigits() ?? "-") تومان")
                                .shkFont(14, .bold)
                                .foregroundColor(colors.onSurface)
                        }
                    }
                }
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // فاز ۳۰: دکمه‌ی افزودن به سبد + تنظیم‌کننده‌ی تعداد - دقیقاً همون رفتارِ حالت گرید،
            // پایینِ کارت و سمتِ چپ
            if product.inventory, let inventoryId = product.bestInventory?.id {
                Spacer().frame(height: 8)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    HStack(spacing: 0) {
                        Button { if quantity < product.maxQuantity { quantity += 1 } } label: {
                            RemixIcon(RemixIcons.AddLine, contentDescription: "افزایش", tint: colors.onSurface, size: 16)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Text(quantity.toPersianDigits())
                            .shkFont(13, .semiBold)
                            .foregroundColor(colors.onSurface)
                            .padding(.horizontal, 4)
                        Button { if quantity > product.minQuantity { quantity -= 1 } } label: {
                            RemixIcon(RemixIcons.SubtractLine, contentDescription: "کاهش", tint: colors.onSurface, size: 16)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surfaceVariant))
                    Spacer().frame(width: 8)
                    Button {
                        if isAdding { return }
                        if product.hasVariants {
                            ProductCartActions.openQuickAdd?(product)
                            return
                        }
                        guard let add = ProductCartActions.addToCart else { return }
                        isAdding = true
                        add(inventoryId, quantity) { success, message in
                            isAdding = false
                            // message == null یعنی مودال ورود نمایش داده شده (کاربر مهمان) - toast لازم نیست
                            if let text = success ? "به سبد خرید اضافه شد" : message { ShkToast.shared.show(text) }
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.primary)
                            if isAdding {
                                MaterialSpinner(color: colors.onPrimary, lineWidth: 2, size: 14)
                            } else {
                                RemixIcon(RemixIcons.ShoppingCart2Line, contentDescription: "افزودن به سبد خرید", tint: colors.onPrimary, size: 16)
                            }
                        }
                        .frame(width: 32, height: 32)
                    }
                    .buttonStyle(SitePressStyle())
                }
            }
        }
    }
}

/**
 * فاز ۲۶: سایدبار فیلترهای «اختصاصیِ» همین دسته‌بندی (رنگ، سایز، جنس و... که تو پنل ادمین
 * اسکریپت تعریف می‌شن). هر تغییر بلافاصله (بدون دکمه‌ی «اعمال») روی لیست محصولات اعمال می‌شه.
 */
private struct CategorySpecificFiltersSidebar: View {
    let availableFilters: [DynamicFilterDto]
    let current: ProductSortFilter
    let onChange: (ProductSortFilter) -> Void
    let onClose: () -> Void
    @Environment(\.shkColors) private var colors
    @State private var selectedValues: [String: String]

    init(availableFilters: [DynamicFilterDto], current: ProductSortFilter, onChange: @escaping (ProductSortFilter) -> Void, onClose: @escaping () -> Void) {
        self.availableFilters = availableFilters
        self.current = current
        self.onChange = onChange
        self.onClose = onClose
        _selectedValues = State(initialValue: current.dynamicFilters)
    }

    private func applyLive() {
        var f = current
        f.dynamicFilters = selectedValues
        onChange(f)
    }

    private func toggleValue(_ filterTitle: String, _ value: String) {
        if selectedValues[filterTitle] == value {
            // زدن دوباره‌ی همون گزینه = پاک کردن انتخاب این فیلتر
            selectedValues.removeValue(forKey: filterTitle)
        } else {
            selectedValues[filterTitle] = value
        }
        applyLive()
    }

    var body: some View {
        VStack(spacing: 0) {
            SiteSheetHeader(title: "فیلتر محصولات", onClose: onClose, icon: RemixIcons.FilterLine)
                .padding(.top, 8)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(availableFilters) { filter in
                        let hasSelection = selectedValues[filter.title] != nil
                        SiteCard(contentPadding: .all(12)) {
                            SiteSectionTitle(filter.title) {
                                // گروهی که مقدار انتخاب‌شده داره، تیک قرمز کنار عنوانش می‌گیره
                                if hasSelection {
                                    RemixIcon(RemixIcons.CheckboxCircleFill, tint: colors.primary, size: 16)
                                }
                            }
                            .padding(.bottom, 6)
                            ForEach(filter.values, id: \.self) { value in
                                // فاز ۲۷: انتخابِ هر گروه در واقع تک‌گزینه‌ایه (دقیقاً مثل خود سایت)
                                let isSelected = selectedValues[filter.title] == value
                                Button { toggleValue(filter.title, value) } label: {
                                    HStack(spacing: 0) {
                                        SiteFilterCheckMark(checked: isSelected)
                                        Spacer().frame(width: 10)
                                        Text(value)
                                            .shkFont(13, isSelected ? .bold : .normal)
                                            .foregroundColor(isSelected ? colors.primary : colors.onSurface)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // دکمه‌های ثابت پایین سایدبار - فیلترها زنده اعمال می‌شن، پس «مشاهده محصولات» فقط سایدبار رو می‌بنده
            VStack(spacing: 8) {
                SitePrimaryButton(text: "مشاهده محصولات", onClick: onClose, icon: RemixIcons.CheckLine, height: 46, fillWidth: true)
                SiteSecondaryButton(
                    text: "پاک‌کردن همه",
                    onClick: {
                        selectedValues = [:]
                        applyLive()
                    },
                    icon: RemixIcons.DeleteBinLine,
                    enabled: !selectedValues.isEmpty,
                    height: 42,
                    fillWidth: true
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .frame(width: 290)
        .frame(maxHeight: .infinity)
        .background(colors.background.shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 0).ignoresSafeArea())
        // محتوای خود سایدبار راست‌به‌چپ (جای سایدبار در صفحه صریحاً سمت چپه)
        .environment(\.layoutDirection, .rightToLeft)
        .onChange(of: current.dynamicFilters) { selectedValues = $0 }
    }
}

/** لودینگ کوچک انتهای فهرست هنگام گرفتن صفحه‌ی بعدی (اسکرول بی‌نهایت) */
private struct LoadMoreIndicator: View {
    @Environment(\.shkColors) private var colors
    var body: some View {
        MaterialSpinner(color: colors.primary, lineWidth: 2.5, size: 28)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }
}
