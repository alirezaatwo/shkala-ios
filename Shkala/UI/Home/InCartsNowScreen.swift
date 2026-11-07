import SwiftUI

/**
 * معادل ui/home/InCartsNowScreen.kt
 * صفحه‌ی «بیشتر»ِ ماژول «همین لحظه در سبد خرید دیگران»: همه‌ی محصولاتی که الان در سبد خرید
 * کاربرهای دیگه هستن (فهرست تازه از سرور گرفته می‌شه، نه کش صفحه‌ی اصلی).
 */
struct InCartsNowScreen: View {
    let onBack: () -> Void
    let onOpenProduct: (String) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = CatalogRepository()
    @State private var products: [ProductListItemDto]? = nil
    @State private var failed = false

    var body: some View {
        VStack(spacing: 0) {
            let list = products
            SitePageTopBar(
                title: IN_CARTS_NOW_TITLE,
                onBack: onBack,
                subtitle: (list?.isEmpty == false) ? "\(list!.count.toPersianDigits()) محصول" : nil
            )
            if list == nil && !failed {
                SiteLoading(size: 56)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if (list ?? []).isEmpty {
                VStack {
                    SiteEmptyState(
                        icon: RemixIcons.ShoppingCartLine,
                        title: failed ? "دریافت محصولات با خطا مواجه شد" : "فعلاً محصولی در سبد خرید دیگران نیست",
                        subtitle: failed ? "اتصال اینترنت را بررسی کنید." : nil
                    )
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        // اصلاحیه (پیشگیری از کرش «Key already used»): آیتم‌های تکراری یکتا می‌شن
                        ForEach((list ?? []).uniqueById()) { product in
                            ProductCard(product: product, onClick: { onOpenProduct(product.slug) })
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
        .task {
            guard products == nil else { return }
            switch await repository.getInCartsNow() {
            case .success(let data): products = (data.products ?? []).uniqueById()
            case .error: failed = true
            }
        }
    }
}
