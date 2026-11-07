import SwiftUI

// ===================================================================================
// معادل ui/account/RecentlyViewedScreen.kt
// ===================================================================================

/**
 * بازدیدهای اخیر (ذخیره‌شده روی خود گوشی) - نوار بالا با دکمه‌ی برگشت کادردار، شبکه‌ی دوستونه‌ی
 * کارت محصول با تصویر گوشه‌گرد و قیمت، و حالت خالیِ طراحی‌شده.
 */
struct RecentlyViewedScreen: View {
    let onBack: () -> Void
    let onOpenProduct: (String) -> Void
    @Environment(\.shkColors) private var colors
    @ObservedObject private var manager = RecentlyViewedManager.shared

    var body: some View {
        let products = manager.recentlyViewed
        VStack(spacing: 0) {
            SitePageTopBar(
                title: "بازدیدهای اخیر",
                onBack: onBack,
                subtitle: products.isEmpty ? nil : "\(products.count.toPersianDigits()) محصول"
            )
            if products.isEmpty {
                SiteEmptyState(
                    icon: RemixIcons.HistoryLine,
                    title: "هنوز محصولی مشاهده نکرده‌اید",
                    subtitle: "محصولاتی که مشاهده می‌کنید برای دسترسی سریع‌تر در این بخش نمایش داده می‌شوند."
                )
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)], spacing: 10) {
                        ForEach(products, id: \.slug) { product in
                            RecentlyViewedCard(product: product, onClick: { onOpenProduct(product.slug) })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
    }
}

private struct RecentlyViewedCard: View {
    let product: RecentlyViewedProduct
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard(onClick: onClick, contentPadding: .all(10)) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(colors.surfaceVariant)
                .overlay { RemoteImage(product.imageUrl, contentDescription: product.title, contentScale: .crop) }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Spacer().frame(height: 8)
            Text(product.title)
                .shkFont(12, .medium, lineHeight: 19)
                .foregroundColor(colors.onSurface)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: 38, alignment: .top)
            Spacer().frame(height: 6)
            if let price = product.bestPrice {
                Text("\(formatTomanFa(price)) تومان")
                    .shkFont(13, .bold)
                    .foregroundColor(colors.primary)
                    .lineLimit(1)
            } else {
                Spacer().frame(height: 18)
            }
        }
    }
}
