import SwiftUI

// ===================================================================================
// معادل ui/common/ProductSortFilterSheet.kt
// ===================================================================================

/** عنوان فارسی هر گزینه‌ی مرتب‌سازی */
func productSortLabel(_ option: ProductSortOption) -> String {
    switch option {
    case .DEFAULT: return "پیش‌فرض"
    case .LATEST: return "جدیدترین"
    case .MOST_VIEWED: return "پربازدیدترین"
    case .POPULAR: return "محبوب‌ترین"
    case .MOST_SALE: return "پرفروش‌ترین"
    case .CHEAPEST: return "ارزان‌ترین"
    case .EXPENSIVE: return "گران‌ترین"
    }
}

/** بازطراحی: آیکن Remix هر گزینه‌ی مرتب‌سازی */
func productSortIcon(_ option: ProductSortOption) -> String {
    switch option {
    case .DEFAULT: return RemixIcons.Apps2Line
    case .LATEST: return RemixIcons.TimeLine
    case .MOST_VIEWED: return RemixIcons.EyeLine
    case .POPULAR: return RemixIcons.HeartLine
    case .MOST_SALE: return RemixIcons.FireLine
    case .CHEAPEST: return RemixIcons.ArrowDownLine
    case .EXPENSIVE: return RemixIcons.ArrowUpLine
    }
}

/** بازطراحی: چک‌باکس گوشه‌گردِ اختصاصی (انتخاب‌شده: پُر قرمز با تیک سفید) */
struct SiteFilterCheckMark: View {
    let checked: Bool
    @Environment(\.shkColors) private var colors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        ZStack {
            shape.fill(checked ? colors.primary : Color.clear)
            shape.strokeBorder(checked ? colors.primary : colors.onSurfaceVariant.opacity(0.45), lineWidth: 1.5)
            if checked {
                RemixIcon(RemixIcons.CheckLine, tint: .white, size: 14)
            }
        }
        .frame(width: 20, height: 20)
        .animation(.easeInOut(duration: 0.2), value: checked)
    }
}

/** بازطراحی: کلید روشن/خاموشِ اختصاصی (روشن: قرمز) */
struct SiteFilterSwitch: View {
    let checked: Bool
    @Environment(\.shkColors) private var colors

    var body: some View {
        // در کامپوز (RTL) دکمه‌ی خاموش سمت راسته و با روشن‌شدن به چپ می‌ره؛ اینجا جهت‌ها صریح نوشته شدن
        ZStack(alignment: .trailing) {
            Capsule().fill(checked ? colors.primary : colors.onSurfaceVariant.opacity(0.25))
            Circle().fill(Color.white)
                .frame(width: 18, height: 18)
                .padding(3)
                .offset(x: checked ? -18 : 0)
        }
        .frame(width: 42, height: 24)
        .environment(\.layoutDirection, .leftToRight)
        .animation(.easeInOut(duration: 0.2), value: checked)
    }
}

/**
 * فاز ۱۰: پنل مرتب‌سازی و فیلتر - در صفحات دسته‌بندی و برند استفاده می‌شود.
 * دقیقاً همون گزینه‌های مرتب‌سازی/فیلتری که در سایت (ProductsArchiveService.php) هست.
 * بازطراحی: گزینه‌های مرتب‌سازی به‌صورت کارت‌های دوستونه، فیلترها با کلید اختصاصی و
 * دکمه‌های «اعمال»/«بازنشانی» ثابت پایین شیت.
 */
struct ProductSortFilterSheet: View {
    let current: ProductSortFilter
    let onDismiss: () -> Void
    let onApply: (ProductSortFilter) -> Void

    @Environment(\.shkColors) private var colors
    @State private var sort: ProductSortOption
    @State private var onlyAvailable: Bool
    @State private var onlyDiscounted: Bool

    init(current: ProductSortFilter, onDismiss: @escaping () -> Void, onApply: @escaping (ProductSortFilter) -> Void) {
        self.current = current
        self.onDismiss = onDismiss
        self.onApply = onApply
        _sort = State(initialValue: current.sort)
        _onlyAvailable = State(initialValue: current.onlyAvailable)
        _onlyDiscounted = State(initialValue: current.onlyDiscounted)
    }

    private let sortOptions: [ProductSortOption] = [.DEFAULT, .LATEST, .MOST_VIEWED, .POPULAR, .MOST_SALE, .CHEAPEST, .EXPENSIVE]

    var body: some View {
        VStack(spacing: 0) {
            // سرتیتر استاندارد باتم‌شیت‌ها
            SiteSheetHeader(title: "مرتب‌سازی و فیلتر", onClose: onDismiss, icon: RemixIcons.Filter3Line)
                .padding(.top, 12)
                .padding(.bottom, 4)

            // بخش قابل‌اسکرول (دکمه‌ها پایین ثابت می‌مونن)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SiteSectionTitle("مرتب‌سازی بر اساس")
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                    SiteCard(contentPadding: .all(10)) {
                        let rows = stride(from: 0, to: sortOptions.count, by: 2).map { Array(sortOptions[$0..<min($0 + 2, sortOptions.count)]) }
                        ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, rowOptions in
                            if rowIndex > 0 { Spacer().frame(height: 8) }
                            HStack(spacing: 8) {
                                ForEach(rowOptions, id: \.self) { option in
                                    SortOptionTile(
                                        label: productSortLabel(option),
                                        icon: productSortIcon(option),
                                        selected: sort == option,
                                        onClick: { sort = option }
                                    )
                                    .frame(maxWidth: .infinity)
                                }
                                // ردیف آخرِ تک‌گزینه‌ای: جای خالی حفظ بشه تا اندازه‌ها یکی بمونن
                                if rowOptions.count < 2 { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                            }
                        }
                    }

                    SiteSectionTitle("فیلتر")
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    SiteCard(contentPadding: .hv(14, 4)) {
                        FilterToggleRow(icon: RemixIcons.CheckboxCircleLine, title: "فقط کالاهای موجود", checked: onlyAvailable) {
                            onlyAvailable.toggle()
                        }
                        SiteDashedDivider()
                        FilterToggleRow(icon: RemixIcons.PercentLine, title: "فقط دارای تخفیف", checked: onlyDiscounted) {
                            onlyDiscounted.toggle()
                        }
                    }
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 16)
            }

            // دکمه‌های ثابت پایین شیت
            HStack(spacing: 10) {
                SitePrimaryButton(
                    text: "اعمال فیلتر",
                    onClick: {
                        // فیلترهای اختصاصیِ انتخاب‌شده از سایدبار هم حفظ می‌شن
                        var f = current
                        f.sort = sort
                        f.onlyAvailable = onlyAvailable
                        f.onlyDiscounted = onlyDiscounted
                        onApply(f)
                    },
                    icon: RemixIcons.CheckLine,
                    fillWidth: true
                )
                // بازنشانی فقط انتخاب‌های داخل همین شیت رو به حالت پیش‌فرض برمی‌گردونه (تا «اعمال» زده نشه اثری نداره)
                SiteSecondaryButton(
                    text: "بازنشانی",
                    onClick: {
                        sort = .DEFAULT
                        onlyAvailable = false
                        onlyDiscounted = false
                    },
                    icon: RemixIcons.RefreshLine,
                    color: colors.onSurfaceVariant,
                    fillWidth: true
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .background(colors.background)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
    }
}

/** یک گزینه‌ی مرتب‌سازی (کارت کوچک آیکن‌دار؛ انتخاب‌شده: زمینه‌ی قرمز کم‌رنگ با حاشیه‌ی قرمز) */
private struct SortOptionTile: View {
    let label: String
    let icon: String
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: onClick) {
            HStack(spacing: 0) {
                RemixIcon(icon, tint: selected ? primary : colors.onSurfaceVariant, size: 17)
                Spacer().frame(width: 8)
                Text(label)
                    .shkFont(12, selected ? .bold : .medium)
                    .foregroundColor(selected ? primary : colors.onSurface)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if selected {
                    RemixIcon(RemixIcons.CheckboxCircleFill, tint: primary, size: 16)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background(shape.fill(selected ? primary.opacity(0.1) : colors.surfaceVariant))
            .overlay(shape.strokeBorder(selected ? primary : Color.clear, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

/** ردیف فیلتر روشن/خاموش با آیکن و کلید اختصاصی */
private struct FilterToggleRow: View {
    let icon: String
    let title: String
    let checked: Bool
    let onToggle: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: icon, size: 34, iconSize: 18, radius: 10)
                Spacer().frame(width: 12)
                Text(title)
                    .shkFont(13, .medium)
                    .foregroundColor(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SiteFilterSwitch(checked: checked)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// ===================================================================================
// معادل ui/common/ScrollToTopButton.kt
// ===================================================================================

/** دکمه‌ی «بازگشت به بالا»: مربع گوشه‌گرد قرمز با سایه‌ی قرمز (هم‌سبک دکمه‌های اصلی اپ) */
struct ScrollToTopButton: View {
    let visible: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        ZStack {
            if visible {
                Button(action: onClick) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(colors.primary)
                            .shadow(color: colors.primary.opacity(0.5), radius: 6, x: 0, y: 4)
                        RemixIcon(RemixIcons.ArrowUpLine, contentDescription: "بازگشت به بالا", tint: .white, size: 22)
                    }
                    .frame(width: 46, height: 46)
                }
                .buttonStyle(SitePressStyle())
                .padding(16)
                .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: visible)
    }
}
