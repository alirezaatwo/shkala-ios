import SwiftUI

/// معادل ui/cart/CartSheetContent.kt اپ اندروید - شیت تمام‌صفحه‌ی سبد خرید
struct CartSheetContent: View {
    let onClose: () -> Void
    let onContinueShopping: () -> Void
    let onCheckout: () -> Void
    var onPrefactor: () -> Void = {}

    @ObservedObject private var viewModel = CartViewModel.shared
    @Environment(\.shkColors) private var colors

    var body: some View {
        let state = viewModel.uiState
        // فاز ۱۴: سبد خرید تمام‌صفحه - لیست از بالا شروع می‌شه و خلاصه/دکمه‌ی
        // «ادامه‌ی خرید» همیشه در پایین کارت (پایین صفحه) می‌مونه
        VStack(spacing: 0) {
            // هدر: عنوان + دکمه‌ی بستن
            HStack(spacing: 0) {
                Text("سبد خرید")
                    .shkFont(18, .bold, lineHeight: 26)
                    .foregroundColor(colors.onBackground)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    RemixIcon(RemixIcons.CloseLine, contentDescription: "بستن", tint: colors.onSurfaceVariant, size: 22)
                        .frame(width: 48, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SitePressStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            if state.isLoading && !state.hasLoadedOnce {
                MaterialSpinner(color: colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(40)
                Spacer(minLength: 0)
            } else if state.isEmpty {
                EmptyCartState(onContinueShopping: { onClose(); onContinueShopping() })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let grouped = groupedByStore(state.items)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        // بازطراحی - مرحله ۳: هر محصول داخل کادر خودش (به‌جای خط جداکننده)
                        ForEach(grouped, id: \.0) { storeName, itemsInStore in
                            StoreHeader(storeName: storeName)
                            ForEach(itemsInStore) { item in
                                CartItemRow(
                                    item: item,
                                    isPending: state.pendingItemIds.contains(item.id),
                                    onIncrease: { viewModel.increase(item) },
                                    onDecrease: { viewModel.decrease(item) },
                                    onRemove: { viewModel.remove(item) }
                                )
                            }
                        }
                    }
                }
                .refreshable { await viewModel.refresh() }

                CartSummaryBar(
                    itemCount: state.itemCount,
                    totalDiscount: state.totalDiscount,
                    totalFinalPrice: state.totalFinalPrice,
                    onCheckout: { onClose(); onCheckout() },
                    onPrefactor: { onClose(); onPrefactor() }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        // سبد از لحظه‌ی باز شدن اپ بارگذاری شده؛ اینجا فقط بی‌صدا تازه می‌شه (بدون لودینگ تمام‌صفحه)
        .onAppear { viewModel.loadCart(silently: viewModel.uiState.hasLoadedOnce) }
    }

    /// گروه‌بندی بر اساس فروشگاه با حفظ ترتیب (groupBy کاتلین) + یکتا کردن شناسه‌ها (distinctBy)
    private func groupedByStore(_ items: [CartItemDto]) -> [(String, [CartItemDto])] {
        var order: [String] = []
        var map: [String: [CartItemDto]] = [:]
        for item in items {
            let key = item.store?.name ?? "فروشگاه اصلی"
            if map[key] == nil { order.append(key); map[key] = [] }
            if !(map[key]!.contains { $0.id == item.id }) { map[key]!.append(item) }
        }
        return order.map { ($0, map[$0]!) }
    }
}

private struct EmptyCartState: View {
    let onContinueShopping: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(colors.surface)
                RemixIcon(RemixIcons.ShoppingCartLine, tint: colors.primary, size: 36)
            }
            .frame(width: 80, height: 80)
            Spacer().frame(height: 16)
            Text("سبد خرید شما خالیه")
                .shkFont(16, .bold, lineHeight: 24)
                .foregroundColor(colors.onBackground)
            Spacer().frame(height: 16)
            Button(action: onContinueShopping) {
                Text("شروع خرید")
                    .shkFont(14, .bold, lineHeight: 20)
                    .foregroundColor(colors.onPrimary)
                    .padding(.horizontal, 24)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.primary))
            }
            .buttonStyle(SitePressStyle())
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

private struct StoreHeader: View {
    let storeName: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(RemixIcons.Store2Line, tint: colors.onSurfaceVariant, size: 16)
            Spacer().frame(width: 6)
            Text(storeName)
                .shkFont(12, .medium)
                .foregroundColor(colors.onSurfaceVariant)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

/**
 * بازطراحی - مرحله ۳: هر محصول سبد خرید داخل کادر خودش (روشن: سفید / تاریک: #353542، گوشه‌ی
 * ۱۴) با تصویر در قاب ملایم، عنوان و قیمت خوانا، و در پایین ردیفِ دکمه‌ی حذف (سطل زباله) و
 * تنظیم‌کننده‌ی تعداد با آیکن‌های Remix.
 */
private struct CartItemRow: View {
    let item: CartItemDto
    let isPending: Bool
    let onIncrease: () -> Void
    let onDecrease: () -> Void
    let onRemove: () -> Void

    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant)
                    RemoteImage(item.product?.image, contentScale: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(6)
                }
                .frame(width: 76, height: 76)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.product?.title ?? "محصول")
                        .shkFont(13, .medium, lineHeight: 21)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                    if let variantText = cartVariantText(item) {
                        Text(variantText)
                            .shkFont(11)
                            .foregroundColor(colors.onSurfaceVariant)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer().frame(height: 10)

            // ردیف پایین: قیمت (راست) + حذف و تنظیم‌کننده‌ی تعداد (چپ)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    if item.hasDiscount {
                        Text(formatTomanFa(item.unitOriginalPrice))
                            .shkFont(11)
                            .strikethrough()
                            .foregroundColor(colors.onSurfaceVariant)
                    }
                    Text("\(formatTomanFa(item.price)) تومان")
                        .shkFont(14, .bold)
                        .foregroundColor(item.hasDiscount ? colors.primary : colors.onSurface)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // حذف (سطل زباله)
                Button(action: onRemove) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.error.opacity(0.1))
                        RemixIcon(RemixIcons.DeleteBin6Line, contentDescription: "حذف", tint: colors.error, size: 18)
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(SitePressStyle())
                .disabled(isPending)
                Spacer().frame(width: 8)

                // تنظیم‌کننده‌ی تعداد
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surfaceVariant)
                    if isPending {
                        MaterialSpinner(color: colors.primary, lineWidth: 2, size: 16)
                            .frame(width: 96, height: 34)
                    } else {
                        HStack(spacing: 0) {
                            QuantityStepButton(icon: RemixIcons.AddLine, contentDescription: "افزودن") {
                                if item.count >= item.maxAvailableCount {
                                    ShkToast.shared.show("بیشتر از این موجودی نداریم")
                                } else {
                                    onIncrease()
                                }
                            }
                            Text(item.count.toPersianDigits())
                                .shkFont(14, .bold)
                                .foregroundColor(colors.onSurface)
                                .multilineTextAlignment(.center)
                                .frame(width: 28)
                            QuantityStepButton(icon: RemixIcons.SubtractLine, contentDescription: "کاهش", onClick: onDecrease)
                        }
                        .frame(height: 34)
                    }
                }
                .fixedSize()
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.surface))
        .overlay {
            if !isDark {
                RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(colors.outlineVariant, lineWidth: 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }
}

private struct QuantityStepButton: View {
    let icon: String
    let contentDescription: String
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            RemixIcon(icon, contentDescription: contentDescription, tint: colors.primary, size: 18)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(SitePressStyle())
    }
}

/**
 * بازطراحی - مرحله ۳: خلاصه‌ی پایین سبد. سمت راست: «مبلغ قابل پرداخت» و زیرش مبلغ، و
 * «سود شما از این خرید» و زیرش مبلغ سود. سمت چپ: دکمه‌ی ادامه‌ی خرید.
 */
private struct CartSummaryBar: View {
    let itemCount: Int
    let totalDiscount: Int64
    let totalFinalPrice: Int64
    let onCheckout: () -> Void
    let onPrefactor: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            // پیش‌فاکتور سبد خرید: دکمه‌ی حاشیه‌دار به عرض کامل، بالای مبلغ و دکمه‌ی ادامه‌ی خرید (هم‌سان سایت)
            Button(action: onPrefactor) {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.FileDownloadLine, tint: colors.primary, size: 18)
                    Spacer().frame(width: 6)
                    Text("دانلود پیش‌فاکتور")
                        .shkFont(14, .bold, lineHeight: 20)
                        .foregroundColor(colors.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(colors.primary, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(SitePressStyle())
            .padding(.horizontal, 16)
            .padding(.top, 12)

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("مبلغ قابل پرداخت").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                        Text("\(formatTomanFa(totalFinalPrice)) تومان").shkFont(16, .bold).foregroundColor(colors.onSurface)
                    }
                    if totalDiscount > 0 {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("سود شما از این خرید").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                            Text("\(formatTomanFa(totalDiscount)) تومان").shkFont(13, .bold).foregroundColor(colors.primary)
                        }
                    }
                }
                Spacer(minLength: 8)
                Button(action: onCheckout) {
                    Text("ادامه‌ی خرید (\(itemCount.toPersianDigits()))")
                        .shkFont(14, .bold, lineHeight: 20)
                        .foregroundColor(colors.onPrimary)
                        .padding(.horizontal, 24)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.primary))
                }
                .buttonStyle(SitePressStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .background(colors.surface.ignoresSafeArea(edges: .bottom).materialShadow(8))
    }
}

private func cartVariantText(_ item: CartItemDto) -> String? {
    let text = (item.props ?? [])
        .filter { !($0.name?.isBlankShk ?? true) && !($0.displayValue?.isBlankShk ?? true) }
        .map { "\($0.name!): \($0.displayValue!)" }
        .joined(separator: " | ")
    return text.isBlankShk ? nil : text
}
