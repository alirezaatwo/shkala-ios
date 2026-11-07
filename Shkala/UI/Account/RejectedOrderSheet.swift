import SwiftUI

// ===================================================================================
// معادل ui/account/RejectedOrderSheet.kt
// ===================================================================================

/** دلیل رد سفارش (اگه سرور نفرستاده باشه، متن پیش‌فرض) */
func rejectedOrderReason(_ order: RejectedOrderDto) -> String {
    let reason = order.reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return reason.isEmpty ? "عدم پرداخت / هماهنگی در موعد مقرر" : reason
}

/** عنوان روش پرداخت سفارش ردشده */
func rejectedOrderMethodLabel(_ method: String?) -> String {
    switch method {
    case "card_to_card": return "کارت‌به‌کارت"
    case "coordinated": return "پرداخت با هماهنگی"
    case nil, "": return "-"
    default: return method ?? ""
    }
}

/**
 * باتم‌شیت جزئیات سفارش ردشده: شماره، روش پرداخت، تاریخ ثبت/رد، مبلغ، دلیل رد و اقلام.
 * (داده‌ها همون آیتم لیسته؛ درخواست جدیدی به سرور زده نمی‌شه)
 */
struct RejectedOrderSheet: View {
    let order: RejectedOrderDto
    let onDismiss: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let errorColor = colors.error
        let items = order.items ?? []
        VStack(spacing: 0) {
            SiteSheetHeader(title: "سفارش #\((order.uuid ?? "").toPersianDigits())", onClose: onDismiss, icon: RemixIcons.ShoppingBag3Line)
                .padding(.top, 12)
                .padding(.bottom, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SiteCard {
                        HStack(spacing: 0) {
                            Text("وضعیت سفارش")
                                .shkFont(12)
                                .foregroundColor(colors.onSurfaceVariant)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            SiteStatusChip(text: "رد شده", color: errorColor, icon: RemixIcons.ForbidLine)
                        }
                        Spacer().frame(height: 6)
                        let uuid = (order.uuid ?? "").toPersianDigits()
                        SiteKeyValueRow(label: "شماره سفارش", value: uuid.isEmpty ? "-" : uuid, icon: RemixIcons.Hashtag)
                        SiteKeyValueRow(label: "روش پرداخت", value: rejectedOrderMethodLabel(order.method), icon: RemixIcons.BankCardLine)
                        if let date = order.jalaliCreatedAt, !date.isBlankShk {
                            SiteKeyValueRow(label: "تاریخ ثبت", value: date.toPersianDigits(), icon: RemixIcons.Calendar2Line)
                        }
                        if let date = order.jalaliRejectedAt, !date.isBlankShk {
                            SiteKeyValueRow(label: "تاریخ رد", value: date.toPersianDigits(), icon: RemixIcons.CalendarCloseLine)
                        }
                        if let amount = order.amount {
                            Spacer().frame(height: 4)
                            SiteDashedDivider()
                            Spacer().frame(height: 4)
                            SiteKeyValueRow(label: "مبلغ سفارش", value: "\(formatTomanFa(amount)) تومان", emphasized: true)
                        }
                    }

                    Spacer().frame(height: 12)
                    // دلیل رد
                    SiteCard(color: errorColor.opacity(0.08)) {
                        HStack(alignment: .top, spacing: 0) {
                            RemixIcon(RemixIcons.InformationLine, tint: errorColor, size: 18)
                            Spacer().frame(width: 8)
                            VStack(alignment: .leading, spacing: 0) {
                                Text("دلیل رد").shkFont(12, .bold).foregroundColor(errorColor)
                                Spacer().frame(height: 2)
                                Text(rejectedOrderReason(order))
                                    .shkFont(13, lineHeight: 22)
                                    .foregroundColor(colors.onSurface)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !items.isEmpty {
                        Spacer().frame(height: 12)
                        SiteCard {
                            Text("اقلام سفارش (\(items.count.toPersianDigits()))")
                                .shkFont(13, .bold)
                                .foregroundColor(colors.onSurface)
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                Spacer().frame(height: 10)
                                if index > 0 {
                                    SiteDashedDivider()
                                    Spacer().frame(height: 10)
                                }
                                RejectedOrderItemRow(item: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
    }
}

private struct RejectedOrderItemRow: View {
    let item: RejectedOrderItemDto
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant)
                if let image = item.image, !image.isBlankShk {
                    RemoteImage(image, contentDescription: item.title, contentScale: .crop)
                } else {
                    RemixIcon(RemixIcons.ImageLine, tint: colors.onSurfaceVariant, size: 22)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Spacer().frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title.flatMap { $0.isBlankShk ? nil : $0 } ?? "محصول")
                    .shkFont(13, .medium, lineHeight: 21)
                    .foregroundColor(colors.onSurface)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Spacer().frame(height: 3)
                Text("تعداد: \((item.count ?? 1).toPersianDigits())")
                    .shkFont(11)
                    .foregroundColor(colors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
