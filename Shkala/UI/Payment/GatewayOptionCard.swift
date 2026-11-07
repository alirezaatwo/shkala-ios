import SwiftUI

// ===================================================================================
// معادل ui/payment/GatewayOptionCard.kt - بازطراحی: اجزای مشترک انتخاب درگاه پرداخت
// (لوگوی زرین‌پال/کارت‌به‌کارت + توضیح هر روش)
// ===================================================================================

/** لوگوی محلیِ درگاه بر اساس شناسه/نام آن (اگه لوگویی نداشته باشیم nil) */
func gatewayLogoRes(_ id: String?, _ label: String) -> String? {
    if id == "zarinpal" || label.contains("زرین") { return "ic_gateway_zarinpal" }
    if id == "card_to_card" || label.contains("کارت به کارت") || label.contains("کارت‌به‌کارت") { return "ic_gateway_card_to_card" }
    return nil
}

/**
 * توضیح کوتاه هر روش پرداخت برای انتخاب آگاهانه‌تر. cardToCardNote جمله‌ی پایانیِ
 * کارت‌به‌کارت رو متناسب با کاربرد (سفارش / پیش‌فاکتور) مشخص می‌کنه.
 */
func gatewayDescription(_ id: String?, _ label: String, cardToCardNote: String = "سفارش پس از تأیید پرداخت پردازش می‌شود") -> String {
    switch gatewayLogoRes(id, label) {
    case "ic_gateway_zarinpal": return "پرداخت آنلاین و امن با تمامی کارت‌های عضو شتاب از طریق درگاه زرین‌پال"
    case "ic_gateway_card_to_card": return "واریز مبلغ به کارت فروشگاه و ثبت اطلاعات واریز؛ \(cardToCardNote)"
    default: return "پرداخت آنلاین از طریق درگاه بانکی"
    }
}

/**
 * کارت انتخاب درگاه (مشترک بین پرداخت سفارش، پرداخت پیش‌فاکتور و شارژ کیف پول): قاب سفید
 * لوگو، نام و توضیح درگاه، نشانگر رادیویی انیمیشنی و حاشیه‌ی قرمز در حالت انتخاب.
 * description اگه nil باشه، از gatewayDescription استفاده می‌شه.
 */
struct GatewayOptionCard: View {
    let id: String?
    let label: String
    var enabled: Bool = true
    var selected: Bool = false
    var showOverLimitNotice: Bool = false
    var description: String? = nil
    // متن هشدار سقف مبلغ (از سرور)؛ nil = متن پیش‌فرض قبلی
    var overLimitMessage: String? = nil
    let onClick: () -> Void

    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let logo = gatewayLogoRes(id, label)
        SiteCard(onClick: enabled ? onClick : nil, borderColor: selected ? primary : .clear) {
            HStack(spacing: 0) {
                // قاب لوگو (پس‌زمینه‌ی سفید تا لوگو در تم تاریک هم خوانا باشه)
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(colors.outlineVariant.opacity(0.6), lineWidth: 1)
                    if id == COORDINATED_GATEWAY_ID {
                        RemixIcon(RemixIcons.CustomerService2Fill, contentDescription: label, tint: primary, size: 28)
                    } else if let logo, let image = UIImage(named: logo) {
                        Image(uiImage: image).resizable().scaledToFit().frame(width: 38, height: 38)
                            .accessibilityLabel(label)
                    } else {
                        RemixIcon(RemixIcons.BankLine, tint: primary, size: 26)
                    }
                }
                .frame(width: 54, height: 54)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(label).shkFont(14, .bold).foregroundColor(colors.onSurface)
                    Spacer().frame(height: 3)
                    Text(description ?? gatewayDescription(id, label))
                        .shkFont(11, lineHeight: 19)
                        .foregroundColor(colors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 10)
                GatewaySelectIndicator(selected: selected)
            }
            .opacity(enabled ? 1 : 0.45)

            if showOverLimitNotice {
                HStack(alignment: .top, spacing: 0) {
                    RemixIcon(RemixIcons.InformationLine, tint: SiteStatusColors.Warning, size: 18)
                    Spacer().frame(width: 8)
                    Text(overLimitMessage ?? "برای پرداخت سفارشات با مبالغ بالای ۴۰۰ میلیون تومان خواهشمندیم از سایر شیوه‌های پرداخت استفاده نمایید.")
                        .shkFont(12, lineHeight: 21)
                        .foregroundColor(colors.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SiteStatusColors.Warning.opacity(0.12)))
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selected)
        .animation(.easeInOut(duration: 0.25), value: showOverLimitNotice)
    }
}

/** نشانگر رادیویی: حلقه‌ی خالی ← دایره‌ی قرمز با تیک (با انیمیشن) */
struct GatewaySelectIndicator: View {
    let selected: Bool
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        ZStack {
            Circle().fill(selected ? primary : .clear)
            Circle().strokeBorder(selected ? primary : colors.onSurfaceVariant.opacity(0.4), lineWidth: 1.5)
            RemixIcon(RemixIcons.CheckLine, tint: .white, size: 16)
                .scaleEffect(selected ? 1 : 0.001)
        }
        .frame(width: 24, height: 24)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selected)
    }
}
