import SwiftUI

// معادل ui/product/ProductVariantSelector.kt اپ اندروید

/**
 * وضعیت انتخاب ویژگی‌های یه محصول (رنگ، گارانتی، سایز و ...) - از رو لیست موجودی‌های واقعی
 * محصول، ویژگی‌های موجود رو استخراج می‌کنه، انتخاب‌ها رو نگه می‌داره و موجودی دقیقاً منطبق با
 * انتخاب فعلی رو پیدا می‌کنه.
 */
@MainActor
final class ProductVariantState: ObservableObject {
    let inventories: [ProductInventoryDto]
    // اسم تمام ویژگی‌ها (مثلاً "رنگ"، "گارانتی") به ترتیب اولین باری که دیده می‌شن
    let propNames: [String]
    // برای هر ویژگی، تمام مقادیر متمایزی که تو کل موجودی‌ها دیده می‌شه
    let optionsByProp: [String: [CartPropDto]]

    @Published private(set) var selections: [String: String]

    init(inventories: [ProductInventoryDto]) {
        self.inventories = inventories
        var names: [String] = []
        for inv in inventories {
            for p in inv.props { if let n = p.name, !names.contains(n) { names.append(n) } }
        }
        propNames = names
        var options: [String: [CartPropDto]] = [:]
        for name in names {
            var seen = Set<String?>()
            var list: [CartPropDto] = []
            for p in inventories.flatMap({ $0.props }) where p.name == name {
                if seen.insert(p.displayValue).inserted { list.append(p) }
            }
            options[name] = list
        }
        optionsByProp = options
        // اگه فقط یه ارزش ممکنه، خودکار انتخابش کن
        var initial: [String: String] = [:]
        for name in names {
            if let list = options[name], list.count == 1, let v = list[0].displayValue { initial[name] = v }
        }
        selections = initial
    }

    /** همه‌ی ویژگی‌ها انتخاب شدن؟ */
    var isComplete: Bool { selections.count == propNames.count }

    /** موجودیِ دقیقاً منطبق با انتخاب فعلی (یا nil) */
    var matchedInventory: ProductInventoryDto? {
        let current = selections
        if current.count != propNames.count { return nil }
        return inventories.first { inv in
            propNames.allSatisfy { name in inv.props.first { $0.name == name }?.displayValue == current[name] }
        }
    }

    func select(_ propName: String, _ value: String) {
        selections[propName] = value
    }
}

/// چیدمان FlowRow کامپوز (ردیف‌هایی که وقتی جا نشن به خط بعد می‌رن)
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += s.width + spacing
            widest = max(widest, x - spacing)
            lineHeight = max(lineHeight, s.height)
        }
        return CGSize(width: proposal.width ?? widest, height: subviews.isEmpty ? 0 : y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // در RTL، SwiftUI خودش مختصات x رو آینه می‌کنه؛ پس از لبه‌ی شروع (minX) چیده می‌شه
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}

/**
 * فقط انتخابگرهای ویژگی (قرص‌های رنگ/گارانتی/...) + پیام «این ترکیب موجود نیست» - بدون قیمت و
 * دکمه‌ی خرید. در صفحه‌ی محصول بالای کادر قیمت نمایش داده می‌شه.
 */
struct ProductVariantPickers: View {
    @ObservedObject var state: ProductVariantState
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(state.propNames.enumerated()), id: \.offset) { index, propName in
                if index > 0 { Spacer().frame(height: 16) }
                // بازطراحی: عنوان ویژگی + مقدار انتخاب‌شده (کم‌رنگ) کنارش
                HStack(spacing: 0) {
                    Text(propName).shkFont(13, .bold).foregroundColor(colors.onSurface)
                    if let selectedValue = state.selections[propName], !selectedValue.isBlankShk {
                        // نویسه‌ی RLM اول متن: جهت پاراگراف راست‌به‌چپ می‌مونه تا «:» مثل اندروید کنار عنوان بیاد
                        Text("\u{200F}: \(selectedValue)").shkFont(12).foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                    }
                }
                Spacer().frame(height: 10)
                FlowRow(spacing: 8, lineSpacing: 8) {
                    ForEach(Array((state.optionsByProp[propName] ?? []).enumerated()), id: \.offset) { _, option in
                        let isSelected = state.selections[propName] == option.displayValue
                        if option.isColorType {
                            ColorSwatchChip(prop: option, isSelected: isSelected, onClick: { state.select(propName, option.displayValue ?? "") })
                        } else {
                            TextChip(label: option.displayValue ?? "-", isSelected: isSelected, onClick: { state.select(propName, option.displayValue ?? "") })
                        }
                    }
                }
            }

            if state.isComplete && state.matchedInventory == nil {
                SiteStatusChip(text: "این ترکیب موجود نیست", color: colors.error, icon: RemixIcons.ErrorWarningLine)
                    .padding(.top, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/**
 * انتخابگرهای یه محصول (رنگ، گارانتی، سایز و ...) + قیمت موجودیِ منطبق + تعداد + دکمه‌ی افزودن
 * به سبد - نسخه‌ی کامل و مستقل (برای شیت افزودن سریع از روی کارت محصول).
 */
struct ProductVariantSelectorContent: View {
    let inventories: [ProductInventoryDto]
    let isAdding: Bool
    let onAddToCart: (Int, Int) -> Void
    // فاز PA: اطلاع‌رسانی موجودیِ منطبق با انتخاب فعلی
    var onMatchedInventoryChange: (Int?) -> Void = { _ in }

    @StateObject private var state: ProductVariantState
    @State private var quantity = 1
    @Environment(\.shkColors) private var colors

    init(inventories: [ProductInventoryDto], isAdding: Bool, onAddToCart: @escaping (Int, Int) -> Void,
         onMatchedInventoryChange: @escaping (Int?) -> Void = { _ in }) {
        self.inventories = inventories
        self.isAdding = isAdding
        self.onAddToCart = onAddToCart
        self.onMatchedInventoryChange = onMatchedInventoryChange
        _state = StateObject(wrappedValue: ProductVariantState(inventories: inventories))
    }

    var body: some View {
        let matched = state.matchedInventory
        VStack(alignment: .leading, spacing: 0) {
            ProductVariantPickers(state: state)
            Spacer().frame(height: 16)

            // بازطراحی: قیمت موجودیِ منطبق + تنظیم تعداد داخل یک کادر ملایم
            if let inv = matched {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        if inv.isDiscountValid {
                            Text("\(formatTomanFa(inv.price)) تومان")
                                .shkFont(11).strikethrough().foregroundColor(colors.onSurfaceVariant)
                        }
                        HStack(spacing: 4) {
                            Text(formatTomanFa(inv.finalPrice)).shkFont(16, .bold).foregroundColor(colors.onSurface)
                            Text("تومان").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // انتخاب تعداد
                    ProductQuantityStepper(
                        quantity: quantity,
                        onIncrease: { if quantity < inv.maxQuantity { quantity += 1 } },
                        onDecrease: { if quantity > inv.minQuantity { quantity -= 1 } },
                        increaseDescription: "زیاد کردن",
                        decreaseDescription: "کم کردن"
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.primary.opacity(0.05)))
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            SitePrimaryButton(
                text: "افزودن به سبد خرید",
                onClick: { if let m = state.matchedInventory { onAddToCart(m.id, quantity) } },
                icon: RemixIcons.ShoppingCart2Line,
                enabled: matched != nil,
                loading: isAdding,
                fillWidth: true
            )
        }
        .animation(.easeInOut(duration: 0.25), value: matched?.id)
        .onAppear { onMatchedInventoryChange(state.matchedInventory?.id) }
        .onChange(of: matched?.id) { onMatchedInventoryChange($0) }
    }
}

/**
 * بازطراحی: تنظیم‌کننده‌ی تعداد - هم‌شکل تنظیم‌کننده‌ی سبد خرید (کادر خاکستری گوشه‌گرد ۱۰ با
 * دکمه‌های + و − قرمز). در صفحه‌ی محصول، نوار چسبان و انتخابگر نوع استفاده می‌شه.
 */
struct ProductQuantityStepper: View {
    let quantity: Int
    let onIncrease: () -> Void
    let onDecrease: () -> Void
    var height: CGFloat = 38
    var increaseEnabled: Bool = true
    var decreaseEnabled: Bool = true
    var increaseDescription: String = "افزایش تعداد"
    var decreaseDescription: String = "کاهش تعداد"
    // فاز PA: وقتی true باشه، تنظیم‌کننده کل عرض والد رو پر می‌کنه (عدد وسط کش میاد)
    var fillWidth: Bool = false

    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            stepButton(RemixIcons.AddLine, increaseDescription, increaseEnabled, onIncrease)
            Text(quantity.toPersianDigits())
                .shkFont(14, .bold)
                .foregroundColor(colors.onSurface)
                .multilineTextAlignment(.center)
                .frame(width: fillWidth ? nil : 30)
                .frame(maxWidth: fillWidth ? .infinity : nil)
            stepButton(RemixIcons.SubtractLine, decreaseDescription, decreaseEnabled, onDecrease)
        }
        .frame(height: height)
        .frame(maxWidth: fillWidth ? .infinity : nil)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surfaceVariant))
    }

    private func stepButton(_ icon: String, _ description: String, _ enabled: Bool, _ onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            RemixIcon(icon, contentDescription: description, tint: colors.primary.opacity(enabled ? 1 : 0.35), size: 18)
                .frame(width: height, height: height)
                .contentShape(Rectangle())
        }
        .buttonStyle(SitePressStyle())
        .disabled(!enabled)
    }
}

/** بازطراحی: گزینه‌ی متنی به‌شکل قرص - گزینه‌ی انتخاب‌شده با حاشیه‌ی قرمز و تیک */
private struct TextChip: View {
    let label: String
    let isSelected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: onClick) {
            HStack(spacing: 0) {
                if isSelected {
                    RemixIcon(RemixIcons.CheckLine, tint: primary, size: 15)
                    Spacer().frame(width: 4)
                }
                Text(label)
                    .shkFont(13, isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? primary : colors.onSurface)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(shape.fill(isSelected ? primary.opacity(0.06) : colors.surface))
            .overlay(shape.strokeBorder(isSelected ? primary : colors.outline.opacity(0.35), lineWidth: isSelected ? 1.5 : 1))
            .contentShape(shape)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(SitePressStyle())
    }
}

/** بازطراحی: گزینه‌ی رنگ به‌شکل قرص با دایره‌ی رنگ و نام رنگ */
private struct ColorSwatchChip: View {
    let prop: CartPropDto
    let isSelected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let rgb = hexRGB(prop.colorHex)
        let color = rgb.map { Color(.sRGB, red: $0.r, green: $0.g, blue: $0.b, opacity: 1) } ?? colors.surfaceVariant
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        // تیک روی دایره‌ی رنگ - با رنگ متضاد تا روی رنگ‌های روشن/تیره دیده بشه
        let luminance = rgb.map { $0.r * 0.299 + $0.g * 0.587 + $0.b * 0.114 } ?? 0
        let checkTint: Color = luminance > 0.6 ? .black : .white
        Button(action: onClick) {
            HStack(spacing: 0) {
                ZStack {
                    Circle().fill(color)
                    Circle().strokeBorder(colors.outline.opacity(0.3), lineWidth: 1)
                    if isSelected { RemixIcon(RemixIcons.CheckLine, tint: checkTint, size: 14) }
                }
                .frame(width: 22, height: 22)
                Spacer().frame(width: 8)
                Text(prop.displayValue ?? "-")
                    .shkFont(12, isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? primary : colors.onSurface)
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .padding(.vertical, 7)
            .background(shape.fill(isSelected ? primary.opacity(0.06) : colors.surface))
            .overlay(shape.strokeBorder(isSelected ? primary : colors.outline.opacity(0.35), lineWidth: isSelected ? 1.5 : 1))
            .contentShape(shape)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(SitePressStyle())
    }
}

/// معادل android.graphics.Color.parseColor برای «#RRGGBB» و «#AARRGGBB» (مؤلفه‌ها بین ۰ و ۱)
func hexRGB(_ value: String?) -> (r: Double, g: Double, b: Double)? {
    guard var raw = value?.trimmingCharacters(in: .whitespaces), raw.hasPrefix("#") else { return nil }
    raw.removeFirst()
    if raw.count == 8 { raw.removeFirst(2) }
    guard raw.count == 6, let v = UInt32(raw, radix: 16) else { return nil }
    return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
}
