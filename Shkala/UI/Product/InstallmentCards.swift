import SwiftUI

// معادل ui/product/InstallmentCards.kt اپ اندروید (A14)

/** یک کارت قسطیِ آماده‌ی نمایش (مبلغ هر قسط بدون گرد کردن) */
struct InstallmentCardItem: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String?
    let installments: Int
    /// مبلغ هر قسط به «صدم تومان» (بخش صحیح × ۱۰۰ + دو رقم اعشارِ بریده‌شده)
    let perInstallmentCents: Int64
    let iconUrl: String?
}

/**
 * A14: کارت‌های «هر قسط با {درگاه}: X تومان».
 * مبلغ = قیمت نهاییِ واحدِ موجودیِ انتخاب‌شده × تعداد ÷ تعداد اقساط؛ گرد نمی‌شه (به خواست مدیر
 * فروشگاه دقیقاً حاصل تقسیم نمایش داده می‌شه). اگه کل مبلغ از سقف درگاه بیشتر باشه، کارت
 * همون درگاه پنهان می‌شه (مثل سایت). با عوض شدن تعداد یا گزینه‌ها همون لحظه دوباره حساب می‌شه.
 */
func buildInstallmentCards(gateways: [InstallmentGatewayDto]?, unitFinalPrice: Int64?, quantity: Int) -> [InstallmentCardItem] {
    guard let gateways, !gateways.isEmpty, let unitFinalPrice, unitFinalPrice > 0, quantity > 0 else { return [] }
    let total = unitFinalPrice * Int64(quantity)
    return gateways.compactMap { g in
        guard let id = g.id, !id.isBlankShk else { return nil }
        // برچسب کامل از سرور («هر قسط با اسنپ‌پی:»)؛ اگه نبود از نام کوتاه ساخته می‌شه
        let title: String
        if let t = g.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            title = t
        } else if let n = g.name?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            title = "هر قسط با \(n):"
        } else {
            return nil
        }
        guard let count = g.installments, count > 0 else { return nil }
        if let max = g.maxAmount, max > 0, total > max { return nil }
        let description = g.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        return InstallmentCardItem(
            id: id,
            title: title,
            description: (description?.isEmpty ?? true) ? nil : description,
            installments: count,
            perInstallmentCents: installmentAmountCents(total: total, installments: count),
            iconUrl: absoluteInstallmentIconUrl(g.icon)
        )
    }
}

/**
 * حاصل تقسیم بدون گرد کردن. تقسیم بر ۲ و ۴ همیشه دقیق (حداکثر دو رقم اعشار) است؛ برای تقسیم‌های
 * بی‌پایان (مثلاً ÷۳) دو رقم اعشار نگه داشته می‌شه و بقیه بریده می‌شه (نه گرد).
 */
func installmentAmountCents(total: Int64, installments: Int) -> Int64 {
    (total * 100) / Int64(installments)
}

/** نمایش فارسیِ مبلغ: هزارگان مثل بقیه‌ی قیمت‌های اپ و جداکننده‌ی اعشار «٫» (صفرهای انتهایی حذف) */
func formatInstallmentFa(_ cents: Int64) -> String {
    let integerFa = formatTomanFa(cents / 100)
    let frac = cents % 100
    if frac == 0 { return integerFa }
    var fraction = String(format: "%02d", Int(frac))
    while fraction.hasSuffix("0") { fraction.removeLast() }
    return integerFa + "٫" + fraction.toPersianDigits()
}

private func absoluteInstallmentIconUrl(_ icon: String?) -> String? {
    guard let value = icon?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
    if value.hasPrefix("http://") || value.hasPrefix("https://") { return value }
    var base = ApiConstants.BASE_URL
    while base.hasSuffix("/") { base.removeLast() }
    var path = value
    while path.hasPrefix("/") { path.removeFirst() }
    return base + "/" + path
}

struct ProductInstallmentCards: View {
    let cards: [InstallmentCardItem]

    var body: some View {
        if !cards.isEmpty {
            VStack(spacing: 6) {
                ForEach(cards) { card in InstallmentCard(card: card) }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct InstallmentCard: View {
    let card: InstallmentCardItem
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // اندازه‌ی آیکن ثابته (۲۸×۲۸) تا با لود شدن عکس، کارت جابه‌جا نشه؛ لوگوها زمینه‌ی سفید دارن
            ZStack {
                if let url = card.iconUrl {
                    RemoteImage(url, contentDescription: card.title, contentScale: .fit)
                        .frame(width: 22, height: 22)
                }
            }
            .frame(width: 28, height: 28)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(colors.outline.opacity(0.2), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Spacer().frame(width: 8)
            VStack(alignment: .leading, spacing: 0) {
                // دقیقاً مثل سایت: برچسب + مبلغ + «تومان»
                Text("\(card.title) \(formatInstallmentFa(card.perInstallmentCents)) تومان")
                    .shkFont(12, .medium, lineHeight: 18)
                    .foregroundColor(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let description = card.description {
                    Text(description.toPersianDigits())
                        .shkFont(10, lineHeight: 16)
                        .foregroundColor(colors.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surfaceVariant.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(colors.outline.opacity(0.15), lineWidth: 1))
    }
}
