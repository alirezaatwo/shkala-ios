import SwiftUI

/**
 * معادل ui/product/ProductQuickAddSheet.kt: وقتی رو + یه محصول چندگزینه‌ای (رنگ/گارانتی/سایز) تو
 * صفحه‌ی اصلی یا آرشیو دسته‌بندی می‌زنید، این پاپ‌آپ باز می‌شه تا اول نوعش رو انتخاب کنید،
 * بعد به سبد اضافه بشه.
 */
struct ProductQuickAddSheet: View {
    let productSlug: String
    let productTitle: String
    let onDismiss: () -> Void

    @State private var inventories: [ProductInventoryDto]? = nil
    @State private var isAdding = false
    @Environment(\.shkColors) private var colors

    private let repository = CatalogRepository()

    var body: some View {
        VStack(spacing: 0) {
            // بازطراحی: سرتیتر استاندارد شیت‌ها (عنوان محصول) + محتوا داخل کارت
            SiteSheetHeader(title: productTitle, onClose: onDismiss, icon: RemixIcons.ShoppingCart2Line)
            VStack(spacing: 0) {
                if let inventories {
                    if inventories.isEmpty {
                        SiteCard {
                            HStack(spacing: 0) {
                                SiteIconBadge(icon: RemixIcons.ErrorWarningLine, size: 38, iconSize: 19, tint: colors.error)
                                Spacer().frame(width: 10)
                                Text("این محصول در حال حاضر موجود نیست").shkFont(13).foregroundColor(colors.onSurfaceVariant)
                            }
                        }
                    } else {
                        SiteCard(contentPadding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
                            ProductVariantSelectorContent(
                                inventories: inventories,
                                isAdding: isAdding,
                                onAddToCart: { inventoryId, qty in
                                    isAdding = true
                                    CartViewModel.shared.addToCart(inventoryId: inventoryId, count: qty) { success, message in
                                        isAdding = false
                                        // message == nil یعنی مودال ورود نمایش داده شده (کاربر مهمان) - toast لازم نیست؛
                                        // شیت بسته می‌شه تا مودال ورود (که روی صفحه‌ی اصلی رسم می‌شه) دیده بشه
                                        if let text = success ? "به سبد خرید اضافه شد" : message { ShkToast.shared.show(text) }
                                        if success || message == nil { onDismiss() }
                                    }
                                }
                            )
                        }
                    }
                } else {
                    SiteLoading(size: 56).frame(maxWidth: .infinity).padding(24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .task(id: productSlug) {
            switch await repository.getProductInventories(productSlug) {
            case .success(let data): inventories = data
            case .error: inventories = []
            }
        }
    }
}
