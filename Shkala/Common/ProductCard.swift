import SwiftUI

// فاز ۲۳ (ProductCard.kt اندروید): هر بخش از کارت (عنوان، ردیف امتیاز، بخش قیمت، ردیف افزودن
// به سبد) یک ارتفاعِ ثابتِ از پیش‌تعیین‌شده داره و همیشه همون فضا رو اشغال می‌کنه - پس همه‌ی
// کارت‌ها (با یک عرض یکسان) همیشه دقیقاً یک ارتفاع دارن.
private let CARD_PADDING: CGFloat = 10
private let TITLE_HEIGHT: CGFloat = 36
private let RATING_ROW_HEIGHT: CGFloat = 14
private let RATING_TO_PRICE_SPACER: CGFloat = 2
private let PRICE_BLOCK_HEIGHT: CGFloat = 44
private let ACTIONS_ROW_HEIGHT: CGFloat = 34
private let ACTION_BUTTON_SIZE: CGFloat = 30

/// عرض کارت‌های همه‌ی کاروسل‌های افقی صفحه‌ی اصلی
let PRODUCT_CARD_CAROUSEL_WIDTH: CGFloat = 160
let PRODUCT_CARD_CAROUSEL_HEIGHT: CGFloat = (CARD_PADDING * 2) +
    (PRODUCT_CARD_CAROUSEL_WIDTH - CARD_PADDING * 2) + // ارتفاع تصویر = عرضش (۱:۱)
    8 + TITLE_HEIGHT + RATING_ROW_HEIGHT + RATING_TO_PRICE_SPACER + PRICE_BLOCK_HEIGHT + 8 + ACTIONS_ROW_HEIGHT

/// پل افزودن به سبد خرید - سبد خرید و ورود اجباری در مرحله‌ی ۴ وصل می‌شن (CartViewModel اندروید)
@MainActor
enum ProductCartActions {
    /// (inventoryId, quantity, onResult(success, message)) - message == null یعنی مودال ورود نمایش داده شده
    static var addToCart: ((Int, Int, @escaping (Bool, String?) -> Void) -> Void)? = nil
    /// باز کردن شیت انتخاب گزینه‌های محصولِ دارای تنوع (ProductQuickAddSheet)
    static var openQuickAdd: ((ProductListItemDto) -> Void)? = nil
}

struct ProductCard: View {
    let product: ProductListItemDto
    let onClick: () -> Void
    // ماژول «نخری بردن!»: تعداد باقی‌مونده‌ی موجودی (بین تنظیم تعداد و دکمه‌ی خرید) - در بقیه‌ی جاها null
    var stockLeft: Int? = nil

    @Environment(\.shkColors) private var colors
    @State private var quantity: Int
    @State private var isAdding = false

    init(product: ProductListItemDto, onClick: @escaping () -> Void, stockLeft: Int? = nil) {
        self.product = product
        self.onClick = onClick
        self.stockLeft = stockLeft
        _quantity = State(initialValue: product.minQuantity)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                colors.surfaceVariant
                RemoteImage(product.mainImageUrl, contentDescription: product.title, contentScale: .crop)
                if product.hasDiscount, let percent = product.bestNormalPrice?.percent {
                    Text("٪\(String(percent).toPersianDigits())-")
                        .shkFont(12, .bold, lineHeight: 16)
                        .foregroundColor(colors.onPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.primary))
                        .padding(6)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer().frame(height: 8)

            // فاز ۲۳: ارتفاعِ ثابتِ عنوان، صرف‌نظر از یک‌خطی یا دوخطی بودنش
            Text(product.title)
                .shkFont(.bodySmall)
                .foregroundColor(colors.onSurface)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: TITLE_HEIGHT, alignment: .topLeading)
                .frame(height: TITLE_HEIGHT, alignment: .topLeading)

            // ردیف امتیاز همیشه همون فضای ثابت رو می‌گیره - چه محصول امتیاز داشته باشه چه نه
            HStack(spacing: 4) {
                if let info = product.commentsInfo, info.count != "0" {
                    RemixIcon(RemixIcons.StarFill, tint: colors.primary, size: 13)
                    Text("\(ratingText(info.rating).toPersianDigits()) (\(info.count.toPersianDigits()))")
                        .shkFont(12)
                        .foregroundColor(colors.onSurfaceVariant)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: RATING_ROW_HEIGHT)

            Spacer().frame(height: RATING_TO_PRICE_SPACER)

            // بخش قیمت/موجودی هم فضای ثابت داره و محتواش همیشه وسط‌چین می‌مونه
            ZStack {
                if !product.inventory {
                    Text("ناموجود")
                        .shkFont(.labelMedium)
                        .foregroundColor(colors.error)
                        .multilineTextAlignment(.center)
                } else if let price = product.bestNormalPrice {
                    if product.hasDiscount {
                        VStack(spacing: 0) {
                            Text("\((price.price ?? "").toPersianDigits()) تومان")
                                .shkFont(.bodySmall)
                                .strikethrough(true, color: colors.onSurfaceVariant)
                                .foregroundColor(colors.onSurfaceVariant)
                                .lineLimit(1)
                            Text("\((price.discountPrice ?? "").toPersianDigits()) تومان")
                                .shkFont(16, .bold, lineHeight: 24)
                                .foregroundColor(colors.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    } else {
                        Text("\(price.price?.toPersianDigits() ?? "-") تومان")
                            .shkFont(16, .bold, lineHeight: 24)
                            .foregroundColor(colors.onSurface)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: PRICE_BLOCK_HEIGHT)

            Spacer().frame(height: 8)

            // ردیف شمارشگر/افزودن به سبد هم فضای ثابت داره (برای ناموجودها خالی می‌مونه)
            ZStack {
                if product.inventory, let inventoryId = product.bestInventory?.id {
                    actionsRow(inventoryId: inventoryId)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: ACTIONS_ROW_HEIGHT)
        }
        .padding(CARD_PADDING)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.surface))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onClick)
    }

    @ViewBuilder
    private func actionsRow(inventoryId: Int) -> some View {
        HStack(spacing: 0) {
            // شمارشگر تعداد - محدود به حداقل/حداکثر خرید همون کالا
            HStack(spacing: 0) {
                Button { if quantity < product.maxQuantity { quantity += 1 } } label: {
                    RemixIcon(RemixIcons.AddLine, contentDescription: "افزایش", tint: colors.onSurface, size: 15)
                        .frame(width: ACTION_BUTTON_SIZE, height: ACTION_BUTTON_SIZE)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SitePressStyle())
                Text(quantity.toPersianDigits())
                    .shkFont(12, .semiBold, lineHeight: 18)
                    .foregroundColor(colors.onSurface)
                    .padding(.horizontal, 4)
                Button { if quantity > product.minQuantity { quantity -= 1 } } label: {
                    RemixIcon(RemixIcons.SubtractLine, contentDescription: "کاهش", tint: colors.onSurface, size: 15)
                        .frame(width: ACTION_BUTTON_SIZE, height: ACTION_BUTTON_SIZE)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SitePressStyle())
            }
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.surfaceVariant))

            // ماژول «نخری بردن!»: «۴ تا» در خط بالا و «مونده!» در خط پایین
            if let stockLeft, stockLeft > 0 {
                VStack(spacing: 0) {
                    // فقط یکی مونده: «این / آخریه!»
                    Text(stockLeft == 1 ? "این" : "\(stockLeft.toPersianDigits()) تا")
                        .shkFont(11, .bold, lineHeight: 13)
                        .foregroundColor(colors.primary)
                        .lineLimit(1)
                    Text(stockLeft == 1 ? "آخریه!" : "مونده!")
                        .shkFont(10, .medium, lineHeight: 12)
                        .foregroundColor(colors.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }

            Button {
                if isAdding { return }
                if product.hasVariants {
                    ProductCartActions.openQuickAdd?(product)
                    return
                }
                guard let add = ProductCartActions.addToCart else { return }
                isAdding = true
                add(inventoryId, quantity) { success, message in
                    isAdding = false
                    // message == null یعنی مودال ورود نمایش داده شده (کاربر مهمان) - toast لازم نیست
                    if let text = success ? "به سبد خرید اضافه شد" : message { ShkToast.shared.show(text) }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.primary)
                    if isAdding {
                        MaterialSpinner(color: colors.onPrimary, lineWidth: 2, size: 14)
                    } else {
                        RemixIcon(RemixIcons.ShoppingCart2Line, contentDescription: "افزودن به سبد خرید", tint: colors.onPrimary, size: 16)
                    }
                }
                .frame(width: ACTION_BUTTON_SIZE, height: ACTION_BUTTON_SIZE)
            }
            .buttonStyle(SitePressStyle())
        }
    }

    /// معادل rating.toString() کاتلین (Double → «4.5» / null → «null»)
    private func ratingText(_ rating: Double?) -> String {
        guard let rating else { return "null" }
        return rating == rating.rounded() ? String(format: "%.1f", rating) : String(rating)
    }
}
