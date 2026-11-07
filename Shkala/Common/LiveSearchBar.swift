import SwiftUI

struct CategoryOption: Equatable {
    let slug: String?
    let title: String
    var depth: Int = 0
}

/// درخت دسته‌بندی‌ها رو به یه لیست تخت (با گزینه‌ی «همه‌ی دسته‌بندی‌ها» اول) تبدیل می‌کنه
func flattenCategoriesForSearch(_ categories: [CategoryDto]) -> [CategoryOption] {
    var result = [CategoryOption(slug: nil, title: "همه دسته‌ها")]
    func visit(_ list: [CategoryDto], _ depth: Int) {
        for cat in list {
            result.append(CategoryOption(slug: cat.slug, title: cat.title, depth: depth))
            if let childs = cat.childs { visit(childs, depth + 1) }
        }
    }
    visit(categories, 0)
    return result
}

/// مسیر slug های والدینِ یک دسته (از ریشه) - یا null اگه پیدا نشد
private func findCategoryAncestors(_ categories: [CategoryDto], _ slug: String?) -> [String]? {
    guard let slug else { return nil }
    func search(_ list: [CategoryDto], _ path: [String]) -> [String]? {
        for cat in list {
            if cat.slug == slug { return path }
            if let childs = cat.childs, let found = search(childs, path + [cat.slug]) { return found }
        }
        return nil
    }
    return search(categories, [])
}

/// فیلد جستجوی لایو + سلکتور دسته‌بندی - هم تو صفحه‌ی اصلی (پیش‌فرض: همه‌ی دسته‌بندی‌ها) هم تو
/// صفحه‌ی هر دسته‌بندی (پیش‌فرض: همون دسته‌بندی) استفاده می‌شه. (LiveSearchBar.kt اندروید)
struct LiveSearchBar: View {
    let categories: [CategoryDto]
    let initialCategorySlug: String?
    let onOpenProduct: (String) -> Void
    let onSubmitSearch: (_ query: String, _ categorySlug: String?) -> Void
    // بازطراحی - مرحله ۲: متن راهنمای فیلد (صفحه‌ی اصلی: «جستجوی سراسری ...» مثل سایت)
    var placeholder: String = "جستجوی محصول..."

    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    @State private var selectedCategory: CategoryOption? = nil
    @State private var categoryMenuExpanded = false
    // دسته‌هایی که در لیست درختی باز هستن (کلید: slug)
    @State private var expandedCategorySlugs: Set<String> = []
    @State private var query = ""
    @State private var results: [ProductListItemDto] = []
    @State private var isSearching = false
    @State private var showResultsDropdown = false
    @FocusState private var focused: Bool

    private let repository = CatalogRepository()

    private var categoryOptions: [CategoryOption] { flattenCategoriesForSearch(categories) }

    private var currentCategory: CategoryOption {
        selectedCategory ?? categoryOptions.first(where: { $0.slug == initialCategorySlug }) ?? categoryOptions[0]
    }

    var body: some View {
        // بازطراحی - مرحله ۲: ظاهر فیلد جستجو دقیقاً مثل هدر موبایل سایت (header-two)
        let fieldColor = isDark ? ShkColors.DarkSearchField : ShkColors.LightSearchField
        let fieldTextColor = isDark ? Color.white : ShkColors.LightSearchFieldText
        let chipColor = isDark ? ShkColors.DarkSearchChip : ShkColors.LightSearchChip

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    if query.isEmpty {
                        Text(placeholder)
                            .shkFont(14, .medium, lineHeight: 22)
                            .foregroundColor(fieldTextColor.opacity(0.8))
                            .lineLimit(1)
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $query)
                        .font(ShkFont.yekan(14, .medium))
                        .foregroundColor(fieldTextColor)
                        .tint(colors.primary)
                        .submitLabel(.search)
                        .onSubmit(submitSearch)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)

                if isSearching {
                    MaterialSpinner(color: colors.primary, lineWidth: 2, size: 16)
                        .padding(.trailing, 8)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        results = []
                        showResultsDropdown = false
                    } label: {
                        RemixIcon(RemixIcons.CloseLine, contentDescription: "پاک کردن", tint: fieldTextColor, size: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SitePressStyle())
                    .padding(.trailing, 6)
                }

                // سلکتور دسته‌بندی - داخل فیلد، سمت چپ (با ظاهر دکمه‌ی «آرشیو محصولات» سایت)
                Button { categoryMenuExpanded = true } label: {
                    HStack(spacing: 4) {
                        Text(currentCategory.title)
                            .shkFont(13, .bold)
                            .foregroundColor(colors.onSurface)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 120, alignment: .leading)
                            .fixedSize(horizontal: true, vertical: false)
                        RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurface, size: 14)
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(chipColor))
                }
                .buttonStyle(SitePressStyle())
                .shkDropdown(isPresented: $categoryMenuExpanded, width: 300) { categoryMenu }
                .padding(.trailing, 4)
            }
            .frame(minHeight: 42)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(fieldColor))

            if showResultsDropdown && !results.isEmpty {
                resultsDropdown
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: SearchKey(query: query, category: currentCategory.slug)) { await runSearch() }
        .onChange(of: categoryMenuExpanded) { expanded in
            // هر بار که لیست باز می‌شه، مسیرِ دسته‌ی انتخاب‌شده‌ی فعلی باز باشه تا دیده بشه
            if expanded, let path = findCategoryAncestors(categories, currentCategory.slug) {
                expandedCategorySlugs.formUnion(path)
            }
        }
    }

    private struct SearchKey: Equatable { let query: String; let category: String? }

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 3 {
            results = []
            showResultsDropdown = false
            return
        }
        try? await Task.sleep(nanoseconds: 350_000_000)
        if Task.isCancelled { return }
        isSearching = true
        let result = await repository.getProducts(category: currentCategory.slug, search: trimmed, cheapest: true)
        if Task.isCancelled { isSearching = false; return }
        if let page = result.successValue {
            // فاز ۱۹: لایو سرچ اپ فقط بر اساس عنوان محصول باشه (فقط توی اپ فیلتر می‌شه)
            results = Array(page.items.filter { $0.title.range(of: trimmed, options: .caseInsensitive) != nil }.prefix(8))
            showResultsDropdown = true
        }
        isSearching = false
    }

    private func submitSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 3 {
            ShkToast.shared.show("حداقل ۳ کاراکتر وارد کنید.")
        } else {
            showResultsDropdown = false
            onSubmitSearch(trimmed, currentCategory.slug)
        }
    }

    // MARK: - لیست درختی دسته‌بندی‌ها

    /// بازطراحی - مرحله ۲ (اصلاحیه): لیست دسته‌بندی‌ها به‌صورت درختیِ جمع‌شونده - کنار هر دسته‌ای
    /// که زیرمجموعه داره یک مربع کوچیکِ گرد با «+» هست که زیرمجموعه‌هاش رو باز/بسته می‌کنه.
    private var categoryMenu: some View {
        ShkDropdownSurface {
            VStack(spacing: 0) {
                CategoryTreeRow(
                    title: categoryOptions[0].title, depth: 0, hasChildren: false, isExpanded: false,
                    isSelected: currentCategory.slug == nil,
                    onSelect: {
                        selectedCategory = categoryOptions[0]
                        categoryMenuExpanded = false
                    },
                    onToggle: {}
                )
                ForEach(categories) { category in
                    treeNode(category, depth: 0)
                }
            }
        }
    }

    private func treeNode(_ category: CategoryDto, depth: Int) -> AnyView {
        let children = category.childs ?? []
        let isExpanded = expandedCategorySlugs.contains(category.slug)
        return AnyView(VStack(spacing: 0) {
            CategoryTreeRow(
                title: category.title, depth: depth, hasChildren: !children.isEmpty, isExpanded: isExpanded,
                isSelected: category.slug == currentCategory.slug,
                onSelect: {
                    selectedCategory = CategoryOption(slug: category.slug, title: category.title, depth: depth)
                    categoryMenuExpanded = false
                },
                onToggle: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if isExpanded { expandedCategorySlugs.remove(category.slug) } else { expandedCategorySlugs.insert(category.slug) }
                    }
                }
            )
            if !children.isEmpty && isExpanded {
                VStack(spacing: 0) {
                    ForEach(children) { child in treeNode(child, depth: depth + 1) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }.clipped())
    }

    // MARK: - نتایج لایو

    private var resultsDropdown: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(results.distinctById()) { product in
                    LiveSearchResultRow(product: product) {
                        showResultsDropdown = false
                        query = ""
                        focused = false
                        onOpenProduct(product.slug)
                    }
                }
                Button {
                    showResultsDropdown = false
                    focused = false
                    onSubmitSearch(query.trimmingCharacters(in: .whitespacesAndNewlines), currentCategory.slug)
                } label: {
                    Text("مشاهده‌ی همه‌ی نتایج برای «\(query.trimmingCharacters(in: .whitespacesAndNewlines))»")
                        .shkFont(12, .medium, lineHeight: 18)
                        .foregroundColor(colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SitePressStyle())
            }
        }
        .frame(maxHeight: min(360, CGFloat(results.count) * 64 + 44))
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.surface))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .materialShadow(6)
        .padding(.top, 4)
    }
}

/// یک ردیف از لیست درختی: عنوان (با کلیک انتخاب می‌شه) + در صورت داشتن زیرمجموعه، مربع
/// کوچیکِ گرد با +/− در سمت چپ (با کلیک، زیرمجموعه‌ها باز/بسته می‌شن).
private struct CategoryTreeRow: View {
    let title: String
    let depth: Int
    let hasChildren: Bool
    let isExpanded: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .shkFont(depth > 0 ? 12 : 14, (isSelected || depth == 0) ? .bold : .normal, lineHeight: depth > 0 ? 18 : 22)
                .foregroundColor(isSelected ? colors.primary : colors.onSurface)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if hasChildren {
                Spacer().frame(width: 10)
                Button(action: onToggle) {
                    RemixIcon(
                        isExpanded ? RemixIcons.SubtractLine : RemixIcons.AddLine,
                        contentDescription: isExpanded ? "بستن زیرمجموعه‌ها" : "باز کردن زیرمجموعه‌ها",
                        tint: isExpanded ? .white : colors.onSurface,
                        size: 16
                    )
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(isExpanded ? colors.primary : colors.surfaceVariant))
                }
                .buttonStyle(SitePressStyle())
            }
        }
        .padding(.leading, CGFloat(14 + depth * 16))
        .padding(.trailing, 10)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

private struct LiveSearchResultRow: View {
    let product: ProductListItemDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let isOutOfStock = !product.inventory || (product.bestInventory?.count ?? 1) <= 0
        HStack(spacing: 10) {
            ZStack {
                colors.surfaceVariant
                RemoteImage(product.mainImageUrl, contentDescription: product.title, contentScale: .crop)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                Text(product.title)
                    .shkFont(.bodySmall)
                    .foregroundColor(isOutOfStock ? colors.onSurfaceVariant : colors.onSurface)
                    .lineLimit(1)
                if isOutOfStock {
                    Text("ناموجود").shkFont(.labelSmall).foregroundColor(colors.error)
                } else if let price = product.bestPrice {
                    Text("\(formatTomanFa(Int64(price))) تومان").shkFont(11, .medium, lineHeight: 14).foregroundColor(colors.onSurface)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onClick)
    }
}
