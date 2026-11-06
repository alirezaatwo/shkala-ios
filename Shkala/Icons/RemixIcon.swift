import SwiftUI

/// نمایش یک آیکن Remix Icon - معادل RemixIcon() اپ اندروید (همان فایل فونت remixicon.ttf سایت).
///
/// مثال:
///   RemixIcon(RemixIcons.ShoppingCart2Line, contentDescription: "سبد خرید")
///   RemixIcon(RemixIcons.HeartFill, tint: colors.primary, size: 20)
struct RemixIcon: View {
    let icon: String
    var contentDescription: String? = nil
    /// رنگ آیکن - پیش‌فرض رنگ پیش‌زمینه‌ی جاری (مثل LocalContentColor)
    var tint: Color? = nil
    /// اندازه بر حسب dp اندروید (= pt) - پیش‌فرض ۲۴ مثل Icon()
    var size: CGFloat = 24

    init(_ icon: String, contentDescription: String? = nil, tint: Color? = nil, size: CGFloat = 24) {
        self.icon = icon
        self.contentDescription = contentDescription
        self.tint = tint
        self.size = size
    }

    var body: some View {
        // اندازه‌ی ثابت (مثل dp در اندروید) تا با بزرگ‌کردن متن سیستم، آیکن‌ها بزرگ نشوند
        let text = Text(verbatim: icon)
            .font(.custom("remixicon", fixedSize: size))
        Group {
            if let tint {
                text.foregroundColor(tint)
            } else {
                text
            }
        }
        .lineLimit(1)
        .fixedSize()
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(contentDescription ?? "")
        .accessibilityHidden(contentDescription == nil)
    }
}
