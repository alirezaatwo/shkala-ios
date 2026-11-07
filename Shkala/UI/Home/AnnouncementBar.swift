import SwiftUI

/// نوار اطلاعیه‌ی بالای صفحه‌ی اصلی: آیکن بلندگو، متن متحرک (از چپ به راست) و دکمه‌ی «مشاهده»
/// در سمت چپ نوار که صفحه‌ی جزئیات اطلاعیه رو باز می‌کنه.
struct HomeAnnouncementBar: View {
    let text: String
    let buttonText: String
    let onOpen: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(RemixIcons.MegaphoneLine, tint: colors.primary, size: 18)
            Spacer().frame(width: 8)
            LeftToRightMarqueeText(text: text, color: colors.onSurface)
                .frame(maxWidth: .infinity)
            Spacer().frame(width: 8)
            Button(action: onOpen) {
                Text(buttonText)
                    .shkFont(11, .bold, lineHeight: 16)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.primary))
            }
            .buttonStyle(SitePressStyle())
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.primary.opacity(0.1)))
    }
}

/// متن متحرکِ بی‌پایان که از چپ به راست حرکت می‌کنه (مستقل از جهت چیدمان RTL).
/// چند نسخه از متن با فاصله‌ی ثابت پشت‌سرهم کشیده می‌شن تا حلقه بدون پرش و بدون جای خالی باشه.
/// لبه‌های چپ و راست کمی محو می‌شن.
private struct LeftToRightMarqueeText: View {
    let text: String
    let color: Color

    private let gap: CGFloat = 56
    // سرعت حرکت: حدود ۳۵ نقطه در ثانیه
    private let velocity: CGFloat = 35
    private let fade: CGFloat = 14

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var start = Date()

    var body: some View {
        let label = Text(text).shkFont(12, .medium, lineHeight: 20).foregroundColor(color).lineLimit(1).fixedSize()
        // اندازه‌گیری یک‌باره‌ی متن (ارتفاع نوار = ارتفاع یک خط)
        label.hidden()
            .background(GeometryReader { g in
                Color.clear.onAppear { textWidth = g.size.width }.onChange(of: g.size.width) { textWidth = $0 }
            })
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                GeometryReader { geo in
                    // فاصله‌ی تکرار: اگه متن کوتاه‌تر از نوار باشه، به اندازه‌ی عرض نوار
                    let unit = max(textWidth + gap, geo.size.width)
                    let duration = max(Double(unit / velocity), 1.5)
                    TimelineView(.animation) { context in
                        let elapsed = context.date.timeIntervalSince(start)
                        let offset = unit > 0 ? CGFloat(elapsed.truncatingRemainder(dividingBy: duration) / duration) * unit : 0
                        ZStack(alignment: .topLeading) {
                            ForEach(copyPositions(offset: offset, unit: unit, width: geo.size.width), id: \.self) { x in
                                label.offset(x: x)
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                    }
                    .clipped()
                    .mask(
                        LinearGradient(
                            stops: geo.size.width > fade * 2 ? [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: fade / geo.size.width),
                                .init(color: .black, location: 1 - fade / geo.size.width),
                                .init(color: .clear, location: 1),
                            ] : [.init(color: .black, location: 0), .init(color: .black, location: 1)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                }
            )
            .environment(\.layoutDirection, .leftToRight)
            .onChange(of: text) { _ in start = Date() }
    }

    /// نسخه‌ها در موقعیت‌های offset - unit + k*unit (با افزایش offset همه به سمت راست می‌رن)
    private func copyPositions(offset: CGFloat, unit: CGFloat, width: CGFloat) -> [CGFloat] {
        guard unit > 0, textWidth > 0 else { return [] }
        var xs: [CGFloat] = []
        var x = offset - unit
        while x < width {
            if x + textWidth > 0 { xs.append(x) }
            x += unit
        }
        return xs
    }
}
