import SwiftUI

/**
 * معادل HtmlText اپ اندروید (ui/common/HtmlText.kt): نمایش محتوای HTML داخل یک لیست/ستون
 * اسکرول‌شونده، با ارتفاعی که دقیقاً از ارتفاع واقعی محتوا (گزارش جاوااسکریپت) گرفته می‌شه.
 * کلیک روی عکس‌ها لایت‌باکس رو باز می‌کنه.
 */
struct HtmlText: View {
    let html: String

    @Environment(\.shkColors) private var colors
    @State private var contentHeight: CGFloat = 0
    @State private var lightboxIndex: Int? = nil

    var body: some View {
        let imageUrls = extractImageUrls(html)
        SelfSizingHtmlWebView(
            html: html,
            textColor: colorToCssHex(colors.onSurfaceVariant),
            linkColor: colorToCssHex(colors.primary),
            onHeight: { h in if h > contentHeight { contentHeight = h } },
            onImageClick: { index in lightboxIndex = index }
        )
        .frame(maxWidth: .infinity)
        // scrollHeight از قبل بر حسب pt هست؛ فقط یه حاشیه‌ی امن ۱۶ اضافه می‌شه
        .frame(height: contentHeight > 0 ? contentHeight + 16 : 40)
        .fullScreenCover(isPresented: Binding(get: { lightboxIndex != nil && !imageUrls.isEmpty }, set: { if !$0 { lightboxIndex = nil } })) {
            ImageLightbox(
                imageUrls: imageUrls,
                initialPage: min(max(lightboxIndex ?? 0, 0), max(imageUrls.count - 1, 0)),
                onDismiss: { lightboxIndex = nil }
            )
            .shkSheetEnvironment()
        }
    }
}
