import SwiftUI
import Combine

/// معادل ProductDetailUiState اپ اندروید
struct ProductDetailUiState {
    var isLoading = true
    var errorMessage: String? = nil
    var product: ProductDetailDto? = nil
    // کشیدن به پایین برای بروزرسانی: محصول فعلی نمایش داده می‌مونه و فقط نشانگر بالای صفحه می‌چرخه
    var isRefreshing = false
    // با هر بروزرسانی موفق یکی زیاد می‌شه تا صفحه اطلاعات جانبی (فروشنده‌ها، موجودی‌ها، دیدگاه‌ها) رو هم دوباره بگیره
    var refreshCount = 0
}

/// معادل ui/product/ProductDetailViewModel.kt
@MainActor
final class ProductDetailViewModel: ObservableObject {
    @Published private(set) var uiState = ProductDetailUiState()
    private let repository = CatalogRepository()
    let slug: String

    init(slug: String) {
        self.slug = slug
        load()
    }

    func load() {
        uiState = ProductDetailUiState(isLoading: true)
        Task {
            switch await repository.getProductDetail(slug) {
            case .success(let product):
                uiState.isLoading = false
                uiState.product = product
            case .error(let message):
                uiState.isLoading = false
                uiState.errorMessage = message
            }
        }
    }

    /** کشیدن به پایین: بارگذاری دوباره‌ی بی‌صدا؛ در خطا همون محصول قبلی می‌مونه */
    func refresh() async {
        if uiState.isRefreshing || uiState.isLoading { return }
        uiState.isRefreshing = true
        switch await repository.getProductDetail(slug) {
        case .success(let product):
            uiState.isRefreshing = false
            uiState.errorMessage = nil
            uiState.product = product
            uiState.refreshCount += 1
        case .error:
            uiState.isRefreshing = false
        }
    }
}

/// نگه‌دارنده‌ی ProductVariantState: با عوض شدن لیست موجودی‌ها (مثلاً تغییر فروشگاه)، انتخاب‌ها از نو
/// شروع می‌شن (remember(inventories) اندروید) و تغییرات وضعیت انتخاب به صفحه منتقل می‌شه
@MainActor
final class ProductVariantStateHolder: ObservableObject {
    @Published private(set) var state = ProductVariantState(inventories: [])
    private var inventories: [ProductInventoryDto]? = nil
    private var cancellable: AnyCancellable? = nil

    func update(_ newInventories: [ProductInventoryDto]) {
        if inventories == newInventories { return }
        inventories = newInventories
        state = ProductVariantState(inventories: newInventories)
        cancellable = state.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
    }
}
