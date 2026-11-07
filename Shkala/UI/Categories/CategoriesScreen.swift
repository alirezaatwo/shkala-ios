import SwiftUI

// ===================================================================================
// معادل ui/categories/CategoriesScreen.kt + PendingCategoriesTabViewModel.kt + ArticleCategoriesScreen.kt
// ===================================================================================

/**
 * فاز ۳۲: چون مقصد «دسته‌بندی‌ها» یه مقصدِ ثابتِ تب پایینیه (بدون آرگومان)، برای اینکه منوی
 * «مجله» بتونه از راه دور بگه «وقتی این صفحه باز شد، تبِ مقالات (شماره ۲) رو انتخاب کن»،
 * یه نگه‌دارنده‌ی اشتراکی سطح اپ داریم.
 */
@MainActor
final class PendingCategoriesTabViewModel {
    static let shared = PendingCategoriesTabViewModel()
    var requestedTab: Int? = nil

    // فاز ۳۴ (کد ۵): وقتی کاربر از داخل خودِ صفحه‌ی دسته‌بندی‌ها روی برند یا مقاله‌ای
    // کلیک می‌کنه (نه از منوی پایین)، قبل از ناوبری تبِ فعلی این‌جا ذخیره می‌شه تا با
    // برگشت، همون تب دوباره انتخاب بشه - نه همیشه تب اول (محصولات).
    var lastVisitedTab: Int? = nil
}

/**
 * بخش «دسته‌بندی‌ها» در منوی پایین با سه تب (محصولات، برندها، مقالات).
 * بازطراحی با قالب جدید: عنوان با خط قرمز، تب‌ها به‌صورت کنترل قرصیِ آیکن‌دار، درخت
 * دسته‌بندی‌ها داخل کارت‌ها (سطح سوم به‌صورت کاشی‌های تصویری)، برندها و مقالات در کارت‌های
 * هماهنگ با بقیه‌ی اپ.
 */
struct CategoriesScreen: View {
    let onCategoryClick: (_ slug: String, _ title: String) -> Void
    // فاز ۳۴ (کد ۵): تبِ فعلی قبل از رفتن به برند/مقاله به بیرون گزارش می‌شه تا با برگشت همون تب انتخاب بشه
    let onOpenBrand: (_ slug: String, _ currentTab: Int) -> Void
    let onOpenArticleCategory: (_ slug: String, _ title: String, _ currentTab: Int) -> Void

    @Environment(\.shkColors) private var colors
    @State private var selectedTab: Int

    // فاز ۳۲: وقتی از «مجله» باز می‌شه، مستقیم روی تب «مقالات»
    init(
        onCategoryClick: @escaping (_ slug: String, _ title: String) -> Void,
        onOpenBrand: @escaping (_ slug: String, _ currentTab: Int) -> Void,
        onOpenArticleCategory: @escaping (_ slug: String, _ title: String, _ currentTab: Int) -> Void,
        initialTab: Int = 0
    ) {
        self.onCategoryClick = onCategoryClick
        self.onOpenBrand = onOpenBrand
        self.onOpenArticleCategory = onOpenArticleCategory
        _selectedTab = State(initialValue: initialTab)
    }

    private let tabs: [(String, String?)] = [
        ("محصولات", RemixIcons.Apps2Line),
        ("برندها", RemixIcons.AwardLine),
        ("مقالات", RemixIcons.NewspaperLine),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SiteTitleBar()
                Spacer().frame(width: 8)
                Text("دسته‌بندی‌ها")
                    .shkFont(18, .bold)
                    .foregroundColor(colors.onBackground)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            SiteSegmentedTabs(tabs: tabs, selectedIndex: selectedTab, onSelect: { selectedTab = $0 })
                .padding(.horizontal, 16)
            Spacer().frame(height: 12)

            // مثل when اندروید: با عوض شدن تب، محتوای تب قبلی کنار گذاشته می‌شه و تب جدید از نو بارگذاری می‌شه
            Group {
                switch selectedTab {
                case 0: CategoryTreeTabContent(onCategoryClick: onCategoryClick)
                case 1: BrandsTabContent(onOpenBrand: { slug in onOpenBrand(slug, selectedTab) })
                default: ArticleCategoriesTabContent(onOpenArticleCategory: { slug, title in onOpenArticleCategory(slug, title, selectedTab) })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
    }
}

/**
 * فاز ۳۳: صفحه‌ی مستقل «مجله» - از منوی همبرگری باز می‌شه؛ محتواش دقیقاً همون
 * ArticleCategoriesTabContent تبِ سومِ CategoriesScreen است، فقط قاب و هدرش مستقله.
 */
struct ArticleCategoriesScreen: View {
    let onBack: () -> Void
    let onOpenArticleCategory: (_ slug: String, _ title: String) -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            // بازطراحی: نوار بالای هماهنگ با بقیه‌ی صفحه‌ها
            SitePageTopBar(title: "مجله", onBack: onBack)
            ArticleCategoriesTabContent(onOpenArticleCategory: onOpenArticleCategory)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
    }
}

private struct CategoriesLoadingBox: View {
    @Environment(\.shkColors) private var colors
    var body: some View {
        MaterialSpinner(color: colors.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CategoriesEmptyBox: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var body: some View {
        SiteEmptyState(icon: icon, title: title, subtitle: subtitle)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// ----------------------------------------------------------------------------------
// تب ۱: درخت دسته‌بندی محصولات
// ----------------------------------------------------------------------------------

/**
 * سطح یک داخل یک کارت، با کلیک باز/بسته می‌شه و سطح دو رو داخل همون کارت نشون می‌ده (که
 * خودش هم باز/بسته‌شدنیه). سطح سه به‌شکل کاشی‌های تصویری سه‌ستونه نمایش داده می‌شه.
 */
private struct CategoryTreeTabContent: View {
    let onCategoryClick: (_ slug: String, _ title: String) -> Void
    @Environment(\.shkColors) private var colors

    @State private var categories: [CategoryDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    private let repository = CatalogRepository()

    var body: some View {
        Group {
            if isLoading {
                CategoriesLoadingBox()
            } else if let errorMessage {
                CategoriesEmptyBox(icon: RemixIcons.WifiOffLine, title: "خطا در دریافت دسته‌بندی‌ها", subtitle: errorMessage)
            } else if categories.isEmpty {
                CategoriesEmptyBox(icon: RemixIcons.Apps2Line, title: "هنوز دسته‌بندی‌ای تعریف نشده")
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        // اصلاحیه (پیشگیری از کرش کلید تکراری): اگه سرور یک آیتم رو دوبار بفرسته، اینجا یکتا می‌شه
                        ForEach(categories.uniqueById(), id: \.id) { category in
                            VStack(spacing: 0) {
                                CategoryAccordionItem(category: category, depth: 0, onLeafClick: onCategoryClick)
                            }
                            .frame(maxWidth: .infinity)
                            .background(colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                // کشیدن به پایین: دریافت دوباره‌ی دسته‌بندی‌ها بدون پاک‌کردن محتوای فعلی
                .sitePullRefresh {
                    if case .success(let data) = await repository.getCategories() { categories = data }
                }
            }
        }
        .task {
            switch await repository.getCategories() {
            case .success(let data): categories = data
            case .error(let message): errorMessage = message
            }
            isLoading = false
        }
    }
}

private struct CategoryAccordionItem: View {
    let category: CategoryDto
    let depth: Int
    let onLeafClick: (_ slug: String, _ title: String) -> Void

    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark
    @State private var expanded = false

    var body: some View {
        let children = category.childs ?? []
        let hasChildren = !children.isEmpty
        let primary = colors.primary
        let isTop = depth == 0

        VStack(spacing: 0) {
            Button {
                if hasChildren {
                    withAnimation(.easeInOut(duration: 0.3)) { expanded.toggle() }
                } else {
                    onLeafClick(category.slug, category.title)
                }
            } label: {
                HStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: isTop ? 14 : 11, style: .continuous).fill(colors.surfaceVariant)
                        RemoteImage(category.image, contentDescription: category.title, contentScale: .fit)
                            .padding(4)
                    }
                    .frame(width: isTop ? 48 : 38, height: isTop ? 48 : 38)
                    .clipShape(RoundedRectangle(cornerRadius: isTop ? 14 : 11, style: .continuous))
                    Spacer().frame(width: 12)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(category.title)
                            .shkFont(isTop ? 14 : 13, isTop ? .bold : .medium)
                            .foregroundColor(colors.onSurface)
                        if hasChildren && isTop {
                            Text("\(children.count.toPersianDigits()) زیرمجموعه")
                                .shkFont(11)
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(expanded ? primary.opacity(0.12) : Color.clear)
                        RemixIcon(
                            hasChildren ? RemixIcons.ArrowDownSLine : RemixIcons.ArrowLeftSLine,
                            tint: expanded ? primary : colors.onSurfaceVariant,
                            size: 20
                        )
                        .rotationEffect(.degrees(hasChildren && expanded ? 180 : 0))
                    }
                    .frame(width: 28, height: 28)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, isTop ? 12 : 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if hasChildren && expanded {
                VStack(spacing: 0) {
                    // «مشاهده‌ی همه‌ی محصولات» به‌صورت قرص قرمزِ کم‌رنگ
                    Button { onLeafClick(category.slug, category.title) } label: {
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.StackLine, tint: primary, size: 16)
                            Spacer().frame(width: 6)
                            Text("مشاهده‌ی همه‌ی محصولات «\(category.title)»")
                                .shkFont(12, .medium)
                                .foregroundColor(primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            RemixIcon(RemixIcons.ArrowLeftSLine, tint: primary, size: 18)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(primary.opacity(0.08)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer().frame(height: 8)

                    if children.first?.level == "three" {
                        CategoryLeafGrid(children: children, onLeafClick: onLeafClick)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(children.enumerated()), id: \.offset) { index, child in
                                if index > 0 {
                                    DashedDivider(color: isDark ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider)
                                        .padding(.horizontal, 12)
                                }
                                CategoryAccordionItem(category: child, depth: depth + 1, onLeafClick: onLeafClick)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(colors.outlineVariant, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

/** عمیق‌ترین سطح: کاشی‌های تصویری سه‌ستونه */
private struct CategoryLeafGrid: View {
    let children: [CategoryDto]
    let onLeafClick: (_ slug: String, _ title: String) -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let rows = stride(from: 0, to: children.count, by: 3).map { Array(children[$0..<min($0 + 3, children.count)]) }
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, rowItems in
                HStack(alignment: .top, spacing: 8) {
                    ForEach(rowItems, id: \.id) { leaf in
                        Button { onLeafClick(leaf.slug, leaf.title) } label: {
                            VStack(spacing: 0) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surface)
                                    RemoteImage(leaf.image, contentDescription: leaf.title, contentScale: .fit)
                                        .padding(4)
                                }
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                Spacer().frame(height: 6)
                                // minLines = 2 / maxLines = 2
                                Text(leaf.title + "\n ")
                                    .shkFont(11, .medium, lineHeight: 17)
                                    .foregroundColor(colors.onSurface)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                                    .hidden()
                                    .overlay(alignment: .top) {
                                        Text(leaf.title)
                                            .shkFont(11, .medium, lineHeight: 17)
                                            .foregroundColor(colors.onSurface)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .truncationMode(.tail)
                                    }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(0..<(3 - rowItems.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// ----------------------------------------------------------------------------------
// تب ۲: برندها
// ----------------------------------------------------------------------------------

private struct BrandsTabContent: View {
    let onOpenBrand: (_ slug: String) -> Void
    @Environment(\.shkColors) private var colors

    @State private var brands: [BrandListItemDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    private let repository = ContentRepository()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3)

    var body: some View {
        Group {
            if isLoading {
                CategoriesLoadingBox()
            } else if let errorMessage {
                CategoriesEmptyBox(icon: RemixIcons.WifiOffLine, title: "خطا در دریافت برندها", subtitle: errorMessage)
            } else if brands.isEmpty {
                CategoriesEmptyBox(icon: RemixIcons.AwardLine, title: "برندی پیدا نشد")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(brands.uniqueById(), id: \.id) { brand in
                            Button { onOpenBrand(brand.slug) } label: {
                                VStack(spacing: 0) {
                                    // فاز ۱۶: پس‌زمینه‌ی لوگو سفید و مربعی با گوشه‌ی گرد
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white)
                                        RemoteImage(brand.logo, contentDescription: brand.title, contentScale: .fit)
                                            .padding(8)
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(colors.outlineVariant, lineWidth: 1))
                                    Spacer().frame(height: 8)
                                    Text(brand.title)
                                        .shkFont(12, .medium)
                                        .foregroundColor(colors.onSurface)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.surface))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                // کشیدن به پایین: دریافت دوباره‌ی برندها بدون پاک‌کردن محتوای فعلی
                .sitePullRefresh {
                    if case .success(let data) = await repository.getBrandsList() { brands = data }
                }
            }
        }
        .task {
            switch await repository.getBrandsList() {
            case .success(let data): brands = data
            case .error(let message): errorMessage = message
            }
            isLoading = false
        }
    }
}

// ----------------------------------------------------------------------------------
// تب ۳: مقالات (در صفحه‌ی مستقل «مجله» هم استفاده می‌شه)
// ----------------------------------------------------------------------------------

/** دسته‌بندی‌های مقاله، هر کدوم با تصویر آخرین مقاله‌شون. */
struct ArticleCategoriesTabContent: View {
    let onOpenArticleCategory: (_ slug: String, _ title: String) -> Void
    @Environment(\.shkColors) private var colors

    @State private var categories: [ArticleCategoryDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    private let repository = ContentRepository()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 2)

    var body: some View {
        Group {
            if isLoading {
                CategoriesLoadingBox()
            } else if let errorMessage {
                CategoriesEmptyBox(icon: RemixIcons.WifiOffLine, title: "خطا در دریافت دسته‌بندی مقالات", subtitle: errorMessage)
            } else if categories.isEmpty {
                CategoriesEmptyBox(icon: RemixIcons.NewspaperLine, title: "هنوز مقاله‌ای منتشر نشده است")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(categories.uniqueById(), id: \.id) { category in
                            Button { onOpenArticleCategory(category.slug, category.title) } label: {
                                ArticleCategoryCard(category: category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                // کشیدن به پایین: دریافت دوباره‌ی دسته‌بندی مقالات بدون پاک‌کردن محتوای فعلی
                .sitePullRefresh {
                    if case .success(let data) = await repository.getArticleCategories() { categories = data }
                }
            }
        }
        .task {
            switch await repository.getArticleCategories() {
            case .success(let data): categories = data
            case .error(let message): errorMessage = message
            }
            isLoading = false
        }
    }
}

private struct ArticleCategoryCard: View {
    let category: ArticleCategoryDto
    @Environment(\.shkColors) private var colors

    var body: some View {
        Color.clear
            .aspectRatio(1.1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(colors.surfaceVariant)
            .overlay {
                RemoteImage(category.lastArticleImage?.url, contentDescription: category.title, contentScale: .crop)
            }
            .overlay {
                LinearGradient(colors: [.clear, Color.black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            }
            // تعداد مقاله‌ها - تگ شیشه‌ای بالای کارت
            .overlay(alignment: .topLeading) {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.FileTextLine, tint: .white, size: 12)
                    Spacer().frame(width: 3)
                    Text("\(category.articlesCount.toPersianDigits()) مقاله")
                        .shkFont(10, lineHeight: 14)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.35)))
                .padding(8)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 0) {
                    Text(category.title)
                        .shkFont(13, .bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.primary)
                        RemixIcon(RemixIcons.ArrowLeftSLine, tint: .white, size: 16)
                    }
                    .frame(width: 24, height: 24)
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
    }
}

extension Array where Element: Identifiable {
    /// معادل distinctBy { it.id } کاتلین (اولین مورد هر شناسه می‌مونه)
    func uniqueById() -> [Element] {
        var seen = Set<Element.ID>()
        return filter { seen.insert($0.id).inserted }
    }
}
