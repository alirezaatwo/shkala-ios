import SwiftUI

// ===================================================================================
// بازطراحی - مرحله ۳: اجزای مشترک ماژول‌های صفحه‌ی اصلی، دقیقاً با ظاهر قالب سایت
// (ترجمه‌ی HomeSectionComponents.kt اپ اندروید):
//  - SiteSectionTitle : عنوان ماژول (بولد ۱۴، با خط قرمزِ ۴×۱۶ و سایه‌ی قرمز کنارش)
//  - SitePagerDots    : نقطه‌های موقعیت اسلاید (۶dp، نقطه‌ی فعال قرص قرمز ۱۵dp)
//  - SiteMoreButton   : دکمه‌ی قرمز «بیشتر» با فلش چپ و سایه‌ی قرمز
//  - ShkPager         : معادل HorizontalPager (راست‌به‌چپ: صفحه‌ی بعدی از سمت چپ میاد)
// ===================================================================================

/// عنوان ماژول با خط قرمز در سمت راست. [trailing] (نقطه‌های اسلاید یا دکمه‌ی «بیشتر») در
/// سمت چپِ همین ردیف قرار می‌گیره.
struct SiteSectionTitle<Trailing: View>: View {
    let title: String
    // رنگ عنوان و خط کنارش (null = رنگ‌های عادی تم) - فعلاً فقط ماژول پیشنهاد شگفت‌انگیز از پنل می‌گیره
    var titleColor: Color? = nil
    var barColor: Color? = nil
    let trailing: Trailing?

    @Environment(\.shkColors) private var colors

    init(_ title: String, titleColor: Color? = nil, barColor: Color? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.titleColor = titleColor
        self.barColor = barColor
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 0) {
            SiteTitleBar(color: barColor)
            Spacer().frame(width: 6)
            Text(title)
                .shkFont(14, .bold)
                .foregroundColor(titleColor ?? colors.onBackground)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let trailing {
                Spacer().frame(width: 8)
                trailing
            }
        }
        .frame(maxWidth: .infinity)
    }
}

extension SiteSectionTitle where Trailing == EmptyView {
    init(_ title: String, titleColor: Color? = nil, barColor: Color? = nil) {
        self.title = title
        self.titleColor = titleColor
        self.barColor = barColor
        self.trailing = nil
    }
}

/// خط قرمزِ عمودیِ کنار عنوان‌ها (۴×۱۶ با سایه‌ی قرمز)
struct SiteTitleBar: View {
    var color: Color? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        let c = color ?? colors.primary
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(c)
            .frame(width: 4, height: 16)
            .materialShadow(3, color: c, opacity: 0.5)
    }
}

/// عنوان وسط‌چین با خط قرمز در دو طرف - برای صفحه‌هایی مثل «تماس با ما»
struct SiteCenteredSectionTitle: View {
    let title: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 8) {
            SiteTitleBar()
            Text(title).shkFont(15, .bold).foregroundColor(colors.onBackground)
            SiteTitleBar()
        }
        .frame(maxWidth: .infinity)
    }
}

/// نقطه‌های موقعیت اسلاید - مثل swiper-pagination سایت. اگه تعداد صفحه‌ها زیاد باشه، فقط
/// حداکثر ۵ نقطه‌ی اطرافِ صفحه‌ی فعلی نشون داده می‌شه (مثل dynamicBullets سایت).
struct SitePagerDots: View {
    let pageCount: Int
    let currentPage: Int
    @Environment(\.shkColors) private var colors

    var body: some View {
        if pageCount > 1 {
            let maxDots = 5
            let start = pageCount <= maxDots ? 0 : min(max(currentPage - maxDots / 2, 0), pageCount - maxDots)
            let end = min(pageCount, start + maxDots)
            // چون اپ راست‌به‌چپه، اولین نقطه سمت راست قرار می‌گیره - مثل سایت
            HStack(spacing: 4) {
                ForEach(start..<end, id: \.self) { index in
                    let isActive = index == currentPage
                    Capsule()
                        .fill(isActive ? colors.primary : colors.onBackground.opacity(0.2))
                        .frame(width: isActive ? 15 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 1), value: isActive)
                }
            }
        }
    }
}

/// دکمه‌ی قرمز «بیشتر» سایت (قرص قرمز، متن سفید، فلش چپ، سایه‌ی قرمز)
struct SiteMoreButton: View {
    let onClick: () -> Void
    var text: String = "بیشتر"
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 0) {
                Text(text).shkFont(11, .medium, lineHeight: 16).foregroundColor(.white).lineLimit(1)
                Spacer().frame(width: 2)
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: .white, size: 14)
            }
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.primary))
            .materialShadow(5, color: colors.primary, opacity: 0.4)
        }
        .buttonStyle(SitePressStyle())
    }
}

/// ردیف تب‌های قرصیِ ماژول‌های تب‌دار صفحه‌ی اصلی - افقی اسکرول می‌خوره تا تب‌های زیاد/بلند هم
/// جا بشن؛ تب انتخاب‌شده خودکار به دید آورده می‌شه.
struct SiteScrollableTabs: View {
    let labels: [String]
    let selectedIndex: Int
    let onSelect: (Int) -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(labels.indices, id: \.self) { index in
                        let isSelected = index == selectedIndex
                        Button { onSelect(index) } label: {
                            Text(labels[index])
                                .shkFont(11, isSelected ? .bold : .normal, lineHeight: 14)
                                .foregroundColor(isSelected ? colors.onPrimary : colors.onSurface)
                                .lineLimit(1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(isSelected ? colors.primary : colors.surface)
                                )
                                .animation(.easeInOut(duration: 0.2), value: isSelected)
                        }
                        .buttonStyle(SitePressStyle())
                        .id(index)
                    }
                }
            }
            .onChange(of: selectedIndex) { index in
                if labels.indices.contains(index) {
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(index, anchor: .leading) }
                }
            }
        }
    }
}

/// یک دکمه‌ی فلشِ داخل کنترلرِ تیره‌ی ماژول پیشنهاد شگفت‌انگیز
struct SiteSliderArrow: View {
    let icon: String
    let contentDescription: String
    let onClick: () -> Void
    var tint: Color = .white

    var body: some View {
        Button(action: onClick) {
            RemixIcon(icon, contentDescription: contentDescription, tint: tint, size: 16)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(SitePressStyle())
    }
}

// MARK: - پیجر افقی

/// معادل HorizontalPager اپ اندروید در چیدمان راست‌به‌چپ: صفحه‌ی بعدی از سمت چپ میاد و با
/// کشیدن انگشت به سمت راست، صفحه‌ی بعد نمایش داده می‌شه. فقط صفحه‌های کناری ساخته می‌شن،
/// پس [pageCount] می‌تونه خیلی بزرگ باشه (اسلایدرهای حلقه‌ی بی‌نهایت).
/// ارتفاع پیجر = ارتفاع بلندترین صفحه‌ی ساخته‌شده.
struct ShkPager<Page: View>: View {
    let pageCount: Int
    @Binding var currentPage: Int
    /// فاصله‌ی بین صفحه‌ها (pageSpacing)
    var pageSpacing: CGFloat = 0
    /// تغییر خودکار صفحه هر چند ثانیه (null = خاموش)
    var autoAdvanceSeconds: Double? = nil
    /// بعد از آخرین صفحه دوباره صفحه‌ی اول (فقط برای چرخش خودکار)
    var autoAdvanceWraps: Bool = false
    /// false = کشیدن انگشت صفحه رو عوض نمی‌کنه (مثلاً وقتی عکس لایت‌باکس زوم شده)
    var swipeEnabled: Bool = true
    @ViewBuilder let page: (Int) -> Page

    @State private var width: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var axisLocked: Bool? = nil

    var body: some View {
        let step = width + pageSpacing
        ZStack(alignment: .top) {
            ForEach(visiblePages, id: \.self) { index in
                page(index)
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(width: width > 0 ? width : nil)
                    // چیدمان راست‌به‌چپ: صفحه‌ی بعدی (index بزرگ‌تر) سمت چپ
                    .offset(x: -CGFloat(index - currentPage) * step + dragOffset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { width = geo.size.width }
                .onChange(of: geo.size.width) { width = $0 }
        })
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(dragGesture(step: step))
        .task(id: TaskKey(count: pageCount, seconds: autoAdvanceSeconds)) {
            guard let seconds = autoAdvanceSeconds, pageCount > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                if Task.isCancelled { return }
                if isDragging { continue }
                var next = currentPage + 1
                if next >= pageCount {
                    guard autoAdvanceWraps else { continue }
                    next = 0
                }
                withAnimation(.easeInOut(duration: 0.45)) { currentPage = next }
            }
        }
    }

    private struct TaskKey: Equatable { let count: Int; let seconds: Double? }

    private var visiblePages: [Int] {
        guard pageCount > 0 else { return [] }
        return (max(0, currentPage - 1)...min(pageCount - 1, currentPage + 1)).map { $0 }
    }

    private func dragGesture(step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard swipeEnabled else { return }
                if axisLocked == nil {
                    axisLocked = abs(value.translation.width) > abs(value.translation.height)
                }
                guard axisLocked == true else { return }
                isDragging = true
                var dx = value.translation.width
                // لبه‌ها: کشیدن بیشتر از اولین/آخرین صفحه با مقاومت
                if (currentPage == 0 && dx < 0) || (currentPage == pageCount - 1 && dx > 0) { dx /= 3 }
                dragOffset = dx
            }
            .onEnded { value in
                defer { axisLocked = nil; isDragging = false }
                guard axisLocked == true, step > 0 else { return }
                let predicted = value.predictedEndTranslation.width
                var target = currentPage
                // کشیدن به راست (dx مثبت) = صفحه‌ی بعد؛ به چپ = صفحه‌ی قبل
                if predicted > step / 2 || value.translation.width > step / 2 { target += 1 }
                else if predicted < -step / 2 || value.translation.width < -step / 2 { target -= 1 }
                target = min(max(target, 0), pageCount - 1)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.95)) {
                    currentPage = target
                    dragOffset = 0
                }
            }
    }
}
