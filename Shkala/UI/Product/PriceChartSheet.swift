import SwiftUI

/**
 * معادل ui/product/PriceChartSheet.kt: شیت نمودار قیمت (فاز ۶) - تاریخچه‌ی قیمت همین موجودی/فروشنده‌ی
 * انتخاب‌شده به‌صورت یک نمودار خطی ساده. اگر داده‌ای ثبت نشده باشد، پیام مناسب نشان داده می‌شود.
 * بازطراحی: نمودار داخل کارت با سایه‌ی رنگیِ زیر خط، و کارت‌های کمترین/بیشترین قیمت.
 * (اندازه‌های پیکسلیِ Canvas اندروید - خط ۵px، نقطه‌ها ۶/۸px - به نسبت چگالی ۳ به pt تبدیل شدن)
 */
struct PriceChartSheet: View {
    let chart: PriceChangesChartDto?
    let onDismiss: () -> Void

    @State private var selectedIndex: Int? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        let prices = chart?.price ?? []
        let dates = chart?.date ?? []
        ScrollView {
            VStack(spacing: 0) {
                SiteSheetHeader(title: "نمودار قیمت", onClose: onDismiss, icon: RemixIcons.LineChartLine)
                Spacer().frame(height: 8)
                VStack(spacing: 0) {
                    if prices.count < 2 {
                        SiteCard {
                            HStack(spacing: 0) {
                                SiteIconBadge(icon: RemixIcons.LineChartLine, size: 38, iconSize: 19, tint: SiteStatusColors.Neutral)
                                Spacer().frame(width: 10)
                                Text("هنوز تاریخچه‌ی قیمتی برای این فروشنده ثبت نشده است.")
                                    .shkFont(13, lineHeight: 22)
                                    .foregroundColor(colors.onSurfaceVariant)
                            }
                        }
                    } else {
                        let minPrice = prices.min() ?? 0
                        let maxPrice = prices.max() ?? 0
                        let range = max(1, maxPrice - minPrice)
                        SiteCard(contentPadding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                            chartView(prices: prices, dates: dates, minPrice: minPrice, range: range)
                                .frame(height: 200)
                            Spacer().frame(height: 10)
                            // محور زمان عمداً چپ‌به‌راست است (قدیمی‌ترین قیمت سمت چپ)، مثل نمودار سایت
                            HStack {
                                Text((dates.first ?? "").toPersianDigits()).shkFont(11).foregroundColor(colors.onSurfaceVariant)
                                Spacer()
                                Text((dates.last ?? "").toPersianDigits()).shkFont(11).foregroundColor(colors.onSurfaceVariant)
                            }
                            .environment(\.layoutDirection, .leftToRight)
                        }
                        Spacer().frame(height: 10)
                        HStack(spacing: 10) {
                            PriceExtremeCard(title: "کمترین قیمت", value: "\(String(minPrice).toPersianDigits()) تومان", icon: RemixIcons.ArrowDownSLine, color: colors.primary)
                            PriceExtremeCard(title: "بیشترین قیمت", value: "\(String(maxPrice).toPersianDigits()) تومان", icon: RemixIcons.ArrowUpSLine, color: colors.error)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func chartView(prices: [Int64], dates: [String], minPrice: Int64, range: Int64) -> some View {
        let lineColor = colors.primary
        let gridColor = colors.outline.opacity(0.2)
        let ringColor = colors.surface
        return GeometryReader { geo in
            let size = geo.size
            let points = priceChartPoints(prices, minPrice, range, size.width, size.height)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    // خطوط راهنمای افقی
                    for i in 0...4 {
                        let y = size.height * CGFloat(i) / 4
                        var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(p, with: .color(gridColor), lineWidth: 0.5)
                    }
                    // سایه‌ی رنگیِ زیر خط نمودار
                    var fill = Path()
                    fill.move(to: CGPoint(x: points[0].x, y: size.height))
                    points.forEach { fill.addLine(to: $0) }
                    fill.addLine(to: CGPoint(x: points[points.count - 1].x, y: size.height))
                    fill.closeSubpath()
                    ctx.fill(fill, with: .linearGradient(
                        Gradient(colors: [lineColor.opacity(0.18), .clear]),
                        startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
                    ))
                    // خط عمودی راهنما زیر نقطه‌ی انتخاب‌شده
                    if let index = selectedIndex, index < points.count {
                        var guide = Path()
                        guide.move(to: CGPoint(x: points[index].x, y: 0))
                        guide.addLine(to: CGPoint(x: points[index].x, y: size.height))
                        ctx.stroke(guide, with: .color(lineColor.opacity(0.35)), style: StrokeStyle(lineWidth: 0.7, dash: [2.7, 2.7]))
                    }
                    var line = Path()
                    line.move(to: points[0])
                    points.dropFirst().forEach { line.addLine(to: $0) }
                    ctx.stroke(line, with: .color(lineColor), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                    for (i, pt) in points.enumerated() {
                        let sel = i == selectedIndex
                        let r1: CGFloat = sel ? 4 : 2.7, r2: CGFloat = sel ? 3 : 2
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r1, y: pt.y - r1, width: r1 * 2, height: r1 * 2)), with: .color(ringColor))
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r2, y: pt.y - r2, width: r2 * 2, height: r2 * 2)), with: .color(lineColor))
                    }
                }
                .contentShape(Rectangle())
                // لمس هر نقطه (نزدیک‌ترین نقطه) قیمت و تاریخ همان نقطه را در تولتیپ نشان می‌دهد؛
                // لمس دوباره‌ی همان نقطه تولتیپ را می‌بندد
                .gesture(SpatialTapGesture().onEnded { tap in
                    let stepX = size.width / CGFloat(prices.count - 1)
                    let index = min(max(0, Int((tap.location.x / stepX).rounded())), prices.count - 1)
                    selectedIndex = selectedIndex == index ? nil : index
                })

                // تولتیپ نقطه‌ی انتخاب‌شده: بالای نقطه (اگر جا نبود زیر آن)، داخل عرض نمودار
                if let index = selectedIndex, index < points.count {
                    PriceChartTooltip(price: prices[index], date: index < dates.count ? dates[index] : nil, point: points[index], chartWidth: size.width)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

/// تولتیپ یک نقطه‌ی نمودار: قیمت با جداکننده‌ی هزارگان + تاریخ شمسی همان قیمت
private struct PriceChartTooltip: View {
    let price: Int64
    let date: String?
    let point: CGPoint
    let chartWidth: CGFloat
    @State private var tipSize: CGSize = .zero
    @Environment(\.shkColors) private var colors

    var body: some View {
        let gap: CGFloat = 10
        let x = min(max(0, point.x - tipSize.width / 2), max(0, chartWidth - tipSize.width))
        let above = point.y - gap - tipSize.height
        let y = above >= 0 ? above : point.y + gap
        VStack(spacing: 0) {
            Text("\(formatTomanFa(price)) تومان")
                .shkFont(12, .bold)
                .foregroundColor(colors.inverseOnSurface)
                .environment(\.layoutDirection, .rightToLeft)
            if let date, !date.isBlankShk {
                Text(date.toPersianDigits()).shkFont(10).foregroundColor(colors.inverseOnSurface.opacity(0.8))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.inverseSurface).materialShadow(4))
        .fixedSize()
        .background(GeometryReader { g in Color.clear.onAppear { tipSize = g.size }.onChange(of: g.size) { tipSize = $0 } })
        .offset(x: x, y: y)
        .opacity(tipSize == .zero ? 0 : 1)
    }
}

/// کارت کوچک «کمترین/بیشترین قیمت»
private struct PriceExtremeCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard(contentPadding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: icon, size: 30, iconSize: 18, tint: color, radius: 9)
                Spacer().frame(width: 8)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).shkFont(11).foregroundColor(colors.onSurfaceVariant)
                    Text(value).shkFont(13, .bold).foregroundColor(color)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// مختصات نقطه‌های نمودار (چپ‌به‌راست، قدیمی‌ترین قیمت سمت چپ) - مشترک بین رسم و تولتیپ
private func priceChartPoints(_ prices: [Int64], _ minPrice: Int64, _ range: Int64, _ width: CGFloat, _ height: CGFloat) -> [CGPoint] {
    if prices.count < 2 { return [] }
    let stepX = width / CGFloat(prices.count - 1)
    return prices.enumerated().map { i, p in
        let normalized = CGFloat(p - minPrice) / CGFloat(range)
        return CGPoint(x: CGFloat(i) * stepX, y: height - normalized * height)
    }
}
