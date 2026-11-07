import SwiftUI

/**
 * معادل ui/compare/CompareScreen.kt
 * صفحه‌ی مقایسه‌ی محصولات (فاز ۹ - بازطراحی کامل؛ بازطراحی دوم با قالب جدید).
 *
 * - افزودن محصول بعدی (فقط از همون دسته‌بندی) از طریق کادر خط‌چین «افزودن محصول» یا دکمه‌ی
 *   بالای صفحه انجام می‌شه که یک باتم‌شیت با باکس جستجوی لایو باز می‌کنه.
 * - بدنه‌ی صفحه یک جدول است: ستون سرتیتر مشخصات ثابت (چسبان) و ستون‌های محصولات با اسکرول افقی،
 *   مقادیر هر ردیف دقیقاً روبروی همون سرتیتر.
 */
struct CompareScreen: View {
    let onBack: () -> Void
    var onGoHome: (() -> Void)? = nil

    @Environment(\.shkColors) private var colors
    private let repository = ProductCompareRepository()

    @State private var isLoading = true
    @State private var items: [CompareProductDto] = []
    @State private var errorMessage: String? = nil

    // --- جست‌وجوی لایو برای افزودن محصول بعدی ---
    @State private var searchExpanded = false
    @State private var searchQuery = ""
    @State private var searchResults: [CompareSearchProductDto] = []
    @State private var isSearching = false
    @State private var addErrorMessage: String? = nil
    @State private var loadedOnce = false

    private var canAddMore: Bool { items.count < 4 }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(
                title: "مقایسه‌ی محصولات",
                onBack: onBack,
                subtitle: items.isEmpty ? nil : "\(items.count.toPersianDigits()) از ۴ محصول"
            ) {
                if canAddMore {
                    SiteIconButton(icon: RemixIcons.AddLine, contentDescription: "افزودن محصول به مقایسه", onClick: openSearch, tint: colors.primary)
                }
            }

            if !canAddMore {
                CompareNoticeRow(
                    text: "حداکثر ۴ محصول قابل مقایسه هستند. برای افزودن محصول جدید، ابتدا یکی را حذف کنید.",
                    color: SiteStatusColors.Warning
                )
            }

            if let addErrorMessage, !searchExpanded {
                CompareNoticeRow(text: addErrorMessage, color: colors.error)
            }

            if isLoading {
                SiteLoading(message: "در حال دریافت فهرست مقایسه", icon: RemixIcons.ScalesLine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack {
                    SiteEmptyState(icon: RemixIcons.ErrorWarningLine, title: "خطا", subtitle: errorMessage)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        // فاز ۳۰: وقتی همه‌ی محصولات از لیست مقایسه پاک بشن، به‌جای موندن تو یه صفحه‌ی
                        // خالی، یه دکمه‌ی «بازگشت به صفحه اصلی» نمایش داده می‌شه
                        SiteEmptyState(
                            icon: RemixIcons.ScalesLine,
                            title: "هنوز محصولی برای مقایسه اضافه نکرده‌اید.",
                            subtitle: nil,
                            actionLabel: "بازگشت به صفحه اصلی",
                            actionIcon: RemixIcons.HomeLine,
                            onAction: onGoHome ?? onBack
                        )
                        Spacer().frame(height: 12)
                        AddProductSlot(onClick: openSearch)
                            .frame(maxWidth: .infinity)
                            .frame(height: 96)
                    }
                    .padding(16)
                }
                // کشیدن به پایین: فهرست مقایسه بی‌صدا دوباره گرفته می‌شه؛ در خطا محتوای قبلی می‌مونه
                .sitePullRefresh { await refresh() }
            } else {
                ScrollView {
                    CompareTable(
                        products: items,
                        showAddSlot: canAddMore,
                        onAddClick: openSearch,
                        onRemove: { product in
                            Task {
                                switch await repository.removeFromCompare(product.compareId) {
                                case .success: await load()
                                case .error(let message): errorMessage = message
                                }
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .sitePullRefresh { await refresh() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task {
            guard !loadedOnce else { return }
            loadedOnce = true
            await load()
        }
        // باتم‌شیت انتخاب محصول بعدی با باکس جستجوی لایو
        .sheet(isPresented: Binding(get: { searchExpanded && canAddMore }, set: { if !$0 { closeSearch() } })) {
            searchSheet
                .shkSheetEnvironment()
                .presentationDetents([.large])
        }
    }

    private var searchSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            SiteSheetHeader(title: "افزودن محصول به مقایسه", onClose: closeSearch, icon: RemixIcons.ScalesLine)
            SiteSearchField(value: $searchQuery, placeholder: "نام محصول را جستجو کنید", loading: isSearching)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            Text("فقط محصولات هم‌دسته با محصولات فعلی قابل افزودن هستند.")
                .shkFont(11, .normal)
                .foregroundColor(colors.onSurfaceVariant)
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            if let addErrorMessage {
                CompareNoticeRow(text: addErrorMessage, color: colors.error)
            }

            Group {
                if isSearching && searchResults.isEmpty {
                    SiteLoading(size: 48)
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                } else if searchResults.isEmpty {
                    SiteEmptyState(icon: RemixIcons.SearchLine, title: "محصولی از همین دسته‌بندی پیدا نشد.", subtitle: nil)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            // اصلاحیه (پیشگیری از کرش «Key already used»): آیتم‌های تکراری یکتا می‌شن
                            ForEach(searchResults.uniqueById()) { result in
                                SearchResultRow(result: result, onClick: { addProduct(result) })
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                    .frame(maxHeight: 420)
                }
            }
            .frame(minHeight: 120)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        // جست‌وجوی زنده: با باز شدن شیت (بدون تایپ چیزی) بلافاصله فهرست کامل محصولات مجاز به
        // مقایسه نمایش داده می‌شه. تا وقتی کاربر کمتر از ۳ کاراکتر تایپ کرده، همچنان همون فهرست
        // کامل (بدون فیلتر) نمایش داده می‌شه؛ فقط از ۳ کاراکتر به بعد، جست‌وجو واقعاً بر اساس
        // متن تایپ‌شده فیلتر می‌کنه.
        .task(id: searchQuery) {
            isSearching = true
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            let effectiveQuery = searchQuery.count >= 3 ? searchQuery : nil
            switch await repository.searchCompareProducts(search: effectiveQuery) {
            case .success(let page): if !Task.isCancelled { searchResults = page.data }
            case .error: if !Task.isCancelled { searchResults = [] }
            }
            if !Task.isCancelled { isSearching = false }
        }
    }

    private func openSearch() { if canAddMore { searchExpanded = true } }

    private func closeSearch() {
        searchExpanded = false
        searchQuery = ""
    }

    private func load() async {
        isLoading = true
        switch await repository.getCompares() {
        case .success(let data):
            items = data.compares
            errorMessage = nil
        case .error(let message):
            errorMessage = message
        }
        isLoading = false
    }

    private func refresh() async {
        if case .success(let data) = await repository.getCompares() {
            items = data.compares
            errorMessage = nil
        }
    }

    private func addProduct(_ product: CompareSearchProductDto) {
        Task {
            addErrorMessage = nil
            switch await repository.addToCompare(product.slug) {
            case .success:
                searchQuery = ""
                searchExpanded = false
                await load()
            case .error(let message):
                addErrorMessage = message
            }
        }
    }
}

/// ردیف پیام کوتاه رنگی (هشدار / خطا)
private struct CompareNoticeRow: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(RemixIcons.InformationLine, tint: color, size: 16)
            Spacer().frame(width: 8)
            Text(text)
                .shkFont(11, .normal, lineHeight: 19)
                .foregroundColor(color)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.1)))
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

private struct SearchResultRow: View {
    let result: CompareSearchProductDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 0) {
                RemoteImage(result.images?.first?.link, contentDescription: result.title, contentScale: .crop)
                    .frame(width: 52, height: 52)
                    .background(colors.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(result.title)
                        .shkFont(12, .medium, lineHeight: 19)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let price = result.bestNormalPrice?.price {
                        Text("\(price.toPersianDigits()) تومان")
                            .shkFont(12, .bold)
                            .foregroundColor(colors.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                SiteIconBadge(icon: RemixIcons.AddLine, size: 32, iconSize: 18, radius: 10)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.surface))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// کادر خط‌چین «افزودن محصول»
private struct AddProductSlot: View {
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        Button(action: onClick) {
            VStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.AddLine, size: 38, iconSize: 20, radius: 12)
                Spacer().frame(height: 8)
                Text("افزودن محصول")
                    .shkFont(12, .bold)
                    .foregroundColor(primary)
                    .multilineTextAlignment(.center)
                Text("برای انتخاب محصول بعدی کلیک کنید")
                    .shkFont(10, .normal, lineHeight: 16)
                    .foregroundColor(colors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(shape.fill(primary.opacity(0.04)))
            .overlay(shape.strokeBorder(primary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [12 / 3, 10 / 3])))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
    }
}

private struct SpecRow {
    let label: String
    let isGroupHeader: Bool
    let values: [Int: String?]
}

/// اتحاد (union) همه‌ی گروه‌ها و کلیدهای مشخصات محصولات مقایسه‌شده، به ترتیب اولین بار دیده‌شدن
private func buildSpecRows(_ products: [CompareProductDto]) -> [SpecRow] {
    var rows: [SpecRow] = []
    var groupTitles: [String] = []
    for product in products {
        for group in product.specifications ?? [] where !groupTitles.contains(group.title) { groupTitles.append(group.title) }
    }
    for groupTitle in groupTitles {
        rows.append(SpecRow(label: groupTitle, isGroupHeader: true, values: [:]))
        var keyLabels: [String] = []
        for product in products {
            for key in (product.specifications ?? []).first(where: { $0.title == groupTitle })?.keys ?? [] where !keyLabels.contains(key.key) {
                keyLabels.append(key.key)
            }
        }
        for keyLabel in keyLabels {
            var values: [Int: String?] = [:]
            for product in products {
                let group = (product.specifications ?? []).first(where: { $0.title == groupTitle })
                values[product.id] = .some(group?.keys.first(where: { $0.key == keyLabel })?.value)
            }
            rows.append(SpecRow(label: keyLabel, isGroupHeader: false, values: values))
        }
    }
    return rows
}

/**
 * جدول مقایسه: ستون اول سرتیتر مشخصات (ثابت/چسبان)، و ستون‌های محصولات با اسکرول افقی
 * که مقادیرشون دقیقاً هم‌ردیف با سرتیترهاست. ردیف‌های گروه با نوار رنگی و بقیه‌ی ردیف‌ها
 * یک‌درمیان سایه‌دار نمایش داده می‌شن تا مقایسه‌ی نظیر‌به‌نظیر راحت‌تر باشه.
 */
private struct CompareTable: View {
    let products: [CompareProductDto]
    let showAddSlot: Bool
    let onAddClick: () -> Void
    let onRemove: (CompareProductDto) -> Void

    @Environment(\.shkColors) private var colors

    private let rowHeight: CGFloat = 48
    private let headerHeight: CGFloat = 214
    private let titleColWidth: CGFloat = 118
    private let productColWidth: CGFloat = 150

    var body: some View {
        let rows = buildSpecRows(products)
        let primary = colors.primary
        let surface = colors.surface
        let stripe = colors.surfaceVariant.opacity(0.45)
        let groupBg = primary.opacity(0.07)
        let rowBackground: (Int, SpecRow) -> Color = { index, row in
            if row.isGroupHeader { return groupBg }
            return index % 2 == 0 ? surface : stripe
        }

        HStack(alignment: .top, spacing: 0) {
            // ستون سرتیتر مشخصات (ثابت)
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    SiteIconBadge(icon: RemixIcons.ScalesLine, size: 40, iconSize: 20)
                    Spacer().frame(height: 8)
                    Text("مشخصات").shkFont(12, .bold).foregroundColor(colors.onSurface)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .frame(height: headerHeight)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    Text(row.label)
                        .shkFont(row.isGroupHeader ? 12 : 11, row.isGroupHeader ? .bold : .medium, lineHeight: 17)
                        .foregroundColor(row.isGroupHeader ? primary : colors.onSurfaceVariant)
                        .lineLimit(2)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: rowHeight)
                        .background(rowBackground(index, row))
                }
            }
            .frame(width: titleColWidth)

            // خط جداکننده‌ی ستون ثابت
            colors.onSurfaceVariant.opacity(0.15)
                .frame(width: 1, height: headerHeight + rowHeight * CGFloat(rows.count))

            // ستون‌های محصولات (اسکرول افقی)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(products, id: \.compareId) { product in
                        VStack(spacing: 0) {
                            ProductHeaderCell(product: product, onRemove: { onRemove(product) })
                                .frame(maxWidth: .infinity)
                                .frame(height: headerHeight)
                            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                                ZStack {
                                    rowBackground(index, row)
                                    if !row.isGroupHeader {
                                        let value: String? = row.values[product.id] ?? nil
                                        Text(value ?? "-")
                                            .shkFont(12, .normal, lineHeight: 18)
                                            .foregroundColor(value == nil ? colors.onSurfaceVariant : colors.onSurface)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 8)
                                    }
                                }
                                .frame(height: rowHeight)
                            }
                        }
                        .frame(width: productColWidth)
                    }
                    // ستون کادر خط‌چین افزودن محصول
                    if showAddSlot {
                        VStack(spacing: 0) {
                            AddProductSlot(onClick: onAddClick)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .frame(height: headerHeight)
                            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                                rowBackground(index, row).frame(height: rowHeight)
                            }
                        }
                        .frame(width: productColWidth)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// کارت سرتیتر هر محصول: تصویر گوشه‌گرد، دکمه‌ی حذف، عنوان، قیمت و وضعیت موجودی
private struct ProductHeaderCell: View {
    let product: CompareProductDto
    let onRemove: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                RemoteImage(product.images?.first?.link, contentDescription: product.title, contentScale: .crop)
                    .frame(width: 78, height: 78)
                    .background(colors.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer().frame(height: 6)
                Text(product.title)
                    .shkFont(11, .medium, lineHeight: 17)
                    .foregroundColor(colors.onSurface)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                SiteDashedDivider().padding(.vertical, 4)
                if let price = product.bestNormalPrice?.price {
                    Text("\(price.toPersianDigits()) تومان")
                        .shkFont(12, .bold)
                        .foregroundColor(colors.primary)
                        .lineLimit(1)
                }
                if !product.inStockStatus || !product.inventory {
                    Spacer().frame(height: 2)
                    SiteStatusChip(text: "ناموجود", color: colors.error)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.background))

            // دکمه‌ی حذف از مقایسه
            Button(action: onRemove) {
                RemixIcon(RemixIcons.CloseLine, contentDescription: "حذف از مقایسه", tint: colors.error, size: 16)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(colors.error.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .padding(8)
    }
}
