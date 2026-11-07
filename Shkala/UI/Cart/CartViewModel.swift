import SwiftUI

/// معادل CartUiState اپ اندروید
struct CartUiState {
    var isLoading = false
    var hasLoadedOnce = false
    var errorMessage: String? = nil
    var items: [CartItemDto] = []
    var totalPrice: Int64 = 0
    var totalDiscount: Int64 = 0
    var totalFinalPrice: Int64 = 0
    // شناسه‌ی آیتم‌هایی که الان در حال به‌روزرسانی هستن (برای نمایش لودینگ فقط رو همون آیتم)
    var pendingItemIds: Set<Int> = []
    // کشیدن سبد به پایین برای بروزرسانی
    var isRefreshing = false

    var itemCount: Int { items.reduce(0) { $0 + $1.count } }
    var isEmpty: Bool { items.isEmpty }
}

/// معادل CartViewModel + rememberSharedCartViewModel اندروید: یک نمونه‌ی مشترک برای کل اپ
@MainActor
final class CartViewModel: ObservableObject {
    static let shared = CartViewModel()

    @Published private(set) var uiState = CartUiState()
    private let repository = CartRepository()

    func loadCart(silently: Bool = false) {
        if !silently {
            uiState.isLoading = true
            uiState.errorMessage = nil
        }
        Task { await fetchCart() }
    }

    /// کشیدن سبد به پایین: دقیقاً مثل loadCart(silently = true)، فقط وضعیت isRefreshing رو هم مدیریت می‌کنه
    func refresh() async {
        if uiState.isRefreshing { return }
        uiState.isRefreshing = true
        await fetchCart()
        uiState.isRefreshing = false
    }

    /// پاک کردن سبد بعد از خروج از حساب
    func clear() { uiState = CartUiState() }

    private func fetchCart() async {
        switch await repository.getCart() {
        case .success(let data):
            uiState.isLoading = false
            uiState.hasLoadedOnce = true
            uiState.items = data.items
            uiState.totalPrice = data.totalPrice
            uiState.totalDiscount = data.totalDiscount
            uiState.totalFinalPrice = data.totalFinalPrice
        case .error(let message):
            uiState.isLoading = false
            uiState.hasLoadedOnce = true
            uiState.errorMessage = message
        }
    }

    func addToCart(inventoryId: Int, count: Int = 1, onResult: @escaping (Bool, String?) -> Void = { _, _ in }) {
        Task {
            switch await repository.addToCart(inventoryId: inventoryId, count: count) {
            case .success:
                loadCart(silently: true)
                onResult(true, nil)
            case .error(let message):
                if message == CartRepository.LOGIN_REQUIRED {
                    // مهمان: مودال «لطفا به حساب کاربری خود وارد شوید» به‌جای toast (پیام nil = بدون toast)
                    LoginRequiredPrompt.shared.show()
                    onResult(false, nil)
                } else {
                    onResult(false, message)
                }
            }
        }
    }

    func increase(_ item: CartItemDto) {
        setPending(item.id, true)
        Task {
            switch await repository.increase(consignmentItemId: item.id, inventoryId: item.inventoryId) {
            case .success(let updated): replaceItem(updated)
            case .error(let message): uiState.errorMessage = message
            }
            setPending(item.id, false)
            recomputeTotalsLocally()
        }
    }

    func decrease(_ item: CartItemDto) {
        setPending(item.id, true)
        Task {
            switch await repository.decrease(consignmentItemId: item.id, inventoryId: item.inventoryId) {
            case .success(let updated): replaceItem(updated)
            case .error(let message): uiState.errorMessage = message
            }
            setPending(item.id, false)
            recomputeTotalsLocally()
        }
    }

    func remove(_ item: CartItemDto) {
        setPending(item.id, true)
        Task {
            if case .success = await repository.remove(consignmentItemId: item.id) {
                uiState.items.removeAll { $0.id == item.id }
            }
            setPending(item.id, false)
            recomputeTotalsLocally()
        }
    }

    func consumeError() { uiState.errorMessage = nil }

    private func replaceItem(_ updated: CartItemDto) {
        uiState.items = uiState.items.map { $0.id == updated.id ? updated : $0 }
    }

    private func setPending(_ itemId: Int, _ pending: Bool) {
        if pending { uiState.pendingItemIds.insert(itemId) } else { uiState.pendingItemIds.remove(itemId) }
    }

    private func recomputeTotalsLocally() {
        let items = uiState.items
        let final = items.reduce(Int64(0)) { $0 + $1.fullCountPrice }
        let discount = items.reduce(Int64(0)) { $0 + $1.discount * Int64($1.count) }
        uiState.totalFinalPrice = final
        uiState.totalDiscount = discount
        uiState.totalPrice = final + discount
    }
}

/**
 * مودال «لطفاً به حساب کاربری خود وارد شوید» (مثلاً وقتی مهمان محصولی رو به سبد خرید اضافه می‌کنه).
 * از هر جای اپ با show() باز می‌شه و فقط یک‌بار در AppRoot رسم می‌شه.
 */
@MainActor
final class LoginRequiredPrompt: ObservableObject {
    static let shared = LoginRequiredPrompt()
    @Published var isVisible = false
    func show() { isVisible = true }
    func dismiss() { isVisible = false }
}
