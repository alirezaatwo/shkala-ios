import SwiftUI

// ===================================================================================
// معادل ui/brand/BrandScreen.kt
// ===================================================================================

/**
 * صفحه‌ی مستقل برند (فاز ۷، با اصلاحات بعدی) - همه‌چیز (سربرگ برند + شبکه‌ی محصولات)
 * یک لیست واحد است تا کل صفحه با هم اسکرول شود، نه فقط بخش محصولات.
 * محصولات هر ۲تا یک ردیف چیده می‌شوند.
 *
 * بازطراحی: نوار بالای استاندارد، بنر گوشه‌گرد، کارت سربرگ برند (لوگو در کادر سفید،
 * عنوان، تعداد محصولات، توضیحات جمع‌شونده) و نوار «مرتب‌سازی و فیلتر» بالای محصولات.
 */
struct BrandScreen: View {
    let brandSlug: String
    let onBack: () -> Void
    let onProductClick: (String) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = CatalogRepository()

    @State private var brand: BrandDto? = nil
    @State private var products: [ProductListItemDto] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String? = nil
    @State private var currentPage = 1
    @State private var hasMore = false
    @State private var descriptionExpanded = false
    @State private var sortFilter = ProductSortFilter()
    @State private var showSortFilterSheet = false
    // کشیدن به پایین برای بروزرسانی (بدون پاک‌کردن محتوای فعلی)
    @State private var isRefreshing = false
    @State private var loadGeneration = 0

    private func loadFirstPage() {
        loadGeneration += 1
        let generation = loadGeneration
        Task {
            isLoading = true
            errorMessage = nil

            if case .success(let b) = await repository.getBrand(brandSlug) { brand = b }

            let result = await repository.getProducts(page: 1, brand: brandSlug, sortFilter: sortFilter)
            guard generation == loadGeneration else { return }
            switch result {
            case .success(let page):
                products = page.items
                currentPage = page.pagination.currentPage
                hasMore = page.pagination.currentPage < page.pagination.lastPage
            case .error(let message):
                errorMessage = message
            }
            isLoading = false
        }
    }

    // کشیدن به پایین: اطلاعات برند و صفحه‌ی اول محصولات بی‌صدا دوباره گرفته می‌شه؛ در خطا محتوای قبلی می‌مونه
    private func refresh() async {
        if isRefreshing || isLoadingMore { return }
        isRefreshing = true
        if case .success(let b) = await repository.getBrand(brandSlug) { brand = b }
        if case .success(let page) = await repository.getProducts(page: 1, brand: brandSlug, sortFilter: sortFilter) {
            products = page.items
            currentPage = page.pagination.currentPage
            hasMore = page.pagination.currentPage < page.pagination.lastPage
            errorMessage = nil
        }
        isRefreshing = false
    }

    private func loadMore() {
        if isLoadingMore || !hasMore || isRefreshing { return }
        isLoadingMore = true
        Task {
            if case .success(let page) = await repository.getProducts(page: currentPage + 1, brand: brandSlug, sortFilter: sortFilter) {
                products += page.items
                currentPage = page.pagination.currentPage
                hasMore = page.pagination.currentPage < page.pagination.lastPage
            }
            isLoadingMore = false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                SitePageTopBar(title: brand?.title ?? "برند", onBack: onBack)
                SiteLoading(message: "در حال دریافت محصولات برند...", icon: RemixIcons.PriceTag3Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, brand == nil {
                SitePageTopBar(title: "برند", onBack: onBack)
                SiteEmptyState(
                    icon: RemixIcons.ErrorWarningLine,
                    title: "مشکلی پیش آمد",
                    subtitle: errorMessage,
                    actionLabel: "تلاش دوباره",
                    actionIcon: RemixIcons.RefreshLine,
                    onAction: { loadFirstPage() }
                )
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .sheet(isPresented: $showSortFilterSheet) {
            ProductSortFilterSheet(
                current: sortFilter,
                onDismiss: { showSortFilterSheet = false },
                onApply: { filter in
                    sortFilter = filter
                    showSortFilterSheet = false
                    loadFirstPage()
                }
            )
            .shkSheetEnvironment()
            .presentationDetents([.height(620), .large])
        }
        .onAppear { if products.isEmpty && isLoading && loadGeneration == 0 { loadFirstPage() } }
    }

    private var content: some View {
        let productRows = stride(from: 0, to: products.count, by: 2).map { Array(products[$0..<min($0 + 2, products.count)]) }
        return ScrollView {
            LazyVStack(spacing: 0) {
                VStack(spacing: 0) {
                    SitePageTopBar(title: brand?.title ?? "برند", onBack: onBack) {
                        SiteIconButton(
                            icon: RemixIcons.EqualizerLine,
                            contentDescription: "مرتب‌سازی و فیلتر",
                            onClick: { showSortFilterSheet = true },
                            tint: colors.onBackground
                        )
                    }

                    // بنر برند
                    if let banner = brand?.banner {
                        Color.clear
                            .aspectRatio(3, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .background(colors.surfaceVariant)
                            .overlay { RemoteImage(banner, contentDescription: brand?.title, contentScale: .crop) }
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding(.horizontal, 16)
                        Spacer().frame(height: 12)
                    }

                    // کارت سربرگ برند
                    BrandHeaderCard(
                        brand: brand,
                        descriptionText: htmlToPlainText(brand?.content ?? ""),
                        descriptionExpanded: descriptionExpanded,
                        onToggleDescription: { withAnimation(.easeInOut(duration: 0.25)) { descriptionExpanded.toggle() } }
                    )
                    .padding(.horizontal, 16)

                    // عنوان بخش محصولات + نوار مرتب‌سازی/فیلتر
                    Spacer().frame(height: 20)
                    SiteSectionTitle("محصولات \(brand?.title ?? "")".trimmingCharacters(in: .whitespaces)) {
                        SortFilterChip(sortFilter: sortFilter, onClick: { showSortFilterSheet = true })
                    }
                    .padding(.horizontal, 16)
                    Spacer().frame(height: 8)

                    if products.isEmpty {
                        SiteEmptyState(icon: RemixIcons.ShoppingBag3Line, title: "محصولی پیدا نشد", subtitle: "محصولی برای این برند پیدا نشد.")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }

                ForEach(Array(productRows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(row) { product in
                            ProductCard(product: product, onClick: { onProductClick(product.slug) })
                                .frame(maxWidth: .infinity)
                        }
                        if row.count == 1 { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .onAppear {
                        if !productRows.isEmpty && index >= productRows.count - 2 { loadMore() }
                    }
                }

                if isLoadingMore {
                    SiteLoading(size: 44)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
            }
            .padding(.bottom, 24)
        }
        .sitePullRefresh { await refresh() }
    }
}

/** متن ساده‌ی یک HTML (معادل HtmlCompat.fromHtml(...).toString().trim()) */
private func htmlToPlainText(_ html: String) -> String {
    if html.isBlankShk { return "" }
    guard let data = html.data(using: .utf8),
          let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
          ) else {
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
}

/** کارت سربرگ برند: لوگو در کادر سفید گوشه‌گرد، عنوان، عنوان لاتین، تعداد محصولات و توضیحات */
private struct BrandHeaderCard: View {
    let brand: BrandDto?
    let descriptionText: String
    let descriptionExpanded: Bool
    let onToggleDescription: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard {
            HStack(spacing: 0) {
                if let logo = brand?.logo {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white)
                        RemoteImage(logo, contentDescription: brand?.title, contentScale: .fit)
                            .padding(8)
                    }
                    .frame(width: 68, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(colors.outline.opacity(0.15), lineWidth: 1))
                    Spacer().frame(width: 14)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(brand?.title ?? "")
                        .shkFont(16, .bold)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    if let titleEn = brand?.titleEn, !titleEn.isBlankShk {
                        Text(titleEn)
                            .shkFont(12)
                            .foregroundColor(colors.onSurfaceVariant)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer().frame(height: 6)
                    SiteStatusChip(
                        text: "\((brand?.productsCount ?? 0).toPersianDigits()) محصول",
                        color: colors.primary,
                        icon: RemixIcons.ShoppingBag3Line
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !descriptionText.isBlankShk {
                Spacer().frame(height: 12)
                SiteDashedDivider()
                Spacer().frame(height: 10)
                Text(descriptionText)
                    .shkFont(13, lineHeight: 23)
                    .foregroundColor(colors.onSurfaceVariant)
                    .lineLimit(descriptionExpanded ? nil : 4)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                // فقط اگه متن واقعاً طولانیه دکمه‌ی بیشتر/کمتر رو نشون بده
                if descriptionText.count > 150 {
                    Button(action: onToggleDescription) {
                        HStack(spacing: 0) {
                            Text(descriptionExpanded ? "کمتر" : "بیشتر")
                                .shkFont(12, .bold)
                                .foregroundColor(colors.primary)
                            Spacer().frame(width: 2)
                            RemixIcon(descriptionExpanded ? RemixIcons.ArrowUpSLine : RemixIcons.ArrowDownSLine, tint: colors.primary, size: 18)
                        }
                        .padding(4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
            }
        }
    }
}

/** دکمه‌ی کوچک «مرتب‌سازی» کنار عنوان محصولات - نوع مرتب‌سازی فعلی و نشانگر فیلتر فعال */
private struct SortFilterChip: View {
    let sortFilter: ProductSortFilter
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let hasActiveFilter = sortFilter.onlyAvailable || sortFilter.onlyDiscounted || !sortFilter.dynamicFilters.isEmpty
        Button(action: onClick) {
            HStack(spacing: 0) {
                RemixIcon(RemixIcons.SortDesc, tint: primary, size: 16)
                Spacer().frame(width: 5)
                Text(brandSortLabel(sortFilter.sort))
                    .shkFont(11, .bold)
                    .foregroundColor(colors.onSurface)
                    .lineLimit(1)
                if hasActiveFilter {
                    Spacer().frame(width: 6)
                    Circle().fill(primary).frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surface))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/** عنوان فارسی نوع مرتب‌سازی (هم‌نام گزینه‌های برگه‌ی مرتب‌سازی و فیلتر) */
private func brandSortLabel(_ sort: ProductSortOption) -> String {
    switch sort {
    case .DEFAULT: return "مرتب‌سازی"
    case .LATEST: return "جدیدترین"
    case .MOST_VIEWED: return "پربازدیدترین"
    case .POPULAR: return "محبوب‌ترین"
    case .MOST_SALE: return "پرفروش‌ترین"
    case .CHEAPEST: return "ارزان‌ترین"
    case .EXPENSIVE: return "گران‌ترین"
    }
}
