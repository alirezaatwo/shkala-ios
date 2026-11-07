import SwiftUI
import PhotosUI

// ===================================================================================
// معادل ui/payment/CardToCardComponents.kt: اجزای مشترک پرداخت کارت‌به‌کارت (سفارش و پیش‌فاکتور):
// راهنمای واریز، کارت بانکی گرادیانی (شماره‌کارت و شبا با کپی) و کادر خط‌چین بارگذاری رسید.
// ===================================================================================

/** کلیدهایی که داخل کارت بانکی نمایش داده می‌شن */
private let bankCardKeys: Set<String> = ["bank_name", "account_holder", "card_number", "sheba_number"]

/// معادل copyToClipboard اندروید (ClipboardUtils.kt): کپی + پیام «... کپی شد»
@MainActor
func copyToClipboard(label: String, value: String) {
    UIPasteboard.general.string = value
    ShkToast.shared.show("\(label) کپی شد")
}

/// معادل validateImageUpload اندروید: حداکثر ۵ مگ، فقط JPG/PNG
func validateImageUpload(_ data: Data) -> String? {
    let sizeMb = Double(data.count) / (1024 * 1024)
    if sizeMb > 5.0 { return "حجم عکس نباید بیشتر از ۵ مگابایت باشد." }
    if !isPngData(data) && !isJpegData(data) { return "فقط فرمت JPG یا PNG مجاز است." }
    return nil
}

/// خوندن عکس انتخاب‌شده از گالری (تفاوت iOS: عکس‌های HEIC آیفون قبل از اعتبارسنجی به JPG تبدیل می‌شن)
func loadPickedImageData(_ item: PhotosPickerItem) async -> Data? {
    guard var data = try? await item.loadTransferable(type: Data.self) else { return nil }
    if !isPngData(data) && !isJpegData(data), let image = UIImage(data: data), let jpg = image.jpegData(compressionQuality: 0.9) {
        data = jpg
    }
    return data
}

/** باکس آبی راهنمای واریز */
struct CardToCardGuideBox: View {
    let text: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RemixIcon(RemixIcons.InformationLine, tint: SiteStatusColors.Info, size: 18)
            Spacer().frame(width: 8)
            Text(text)
                .shkFont(12, .medium, lineHeight: 21)
                .foregroundColor(colors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SiteStatusColors.Info.opacity(0.1)))
    }
}

/**
 * اطلاعات حساب مقصد: کارت بانکی (نام بانک، شماره‌کارت، شبا زیر آن و دارنده‌ی حساب) و
 * در صورت وجود، بقیه‌ی فیلدها در یک کارت جدا. مقادیر خالی نمایش داده نمی‌شن.
 */
struct CardToCardBankDetails: View {
    let bankDetails: [BankDetailDto]
    let onCopy: (BankDetailDto) -> Void

    var body: some View {
        let details = bankDetails.filter { !($0.value?.isBlankShk ?? true) }
        let bankName = details.first { $0.key == "bank_name" }
        let holder = details.first { $0.key == "account_holder" }
        let cardNumber = details.first { $0.key == "card_number" }
        let sheba = details.first { $0.key == "sheba_number" }
        let otherDetails = details.filter { !bankCardKeys.contains($0.key) }

        VStack(spacing: 0) {
            if bankName != nil || holder != nil || cardNumber != nil || sheba != nil {
                BankCardVisual(bankName: bankName, holder: holder, cardNumber: cardNumber, sheba: sheba, onCopy: onCopy)
            }
            if !otherDetails.isEmpty {
                Spacer().frame(height: 12)
                SiteCard(contentPadding: .hv(14, 6)) {
                    ForEach(Array(otherDetails.enumerated()), id: \.offset) { index, detail in
                        BankDetailRow(detail: detail, onCopy: { onCopy(detail) })
                        if index != otherDetails.count - 1 { SiteDashedDivider() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/** کارت بانکیِ گرادیانی: نام بانک، شماره‌کارت و شبا (با کپی) و دارنده‌ی حساب */
private struct BankCardVisual: View {
    let bankName: BankDetailDto?
    let holder: BankDetailDto?
    let cardNumber: BankDetailDto?
    let sheba: BankDetailDto?
    let onCopy: (BankDetailDto) -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.18))
                    RemixIcon(RemixIcons.BankLine, tint: .white, size: 20)
                }
                .frame(width: 36, height: 36)
                Spacer().frame(width: 10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(bankName?.label ?? "کارت مقصد").shkFont(10).foregroundColor(.white.opacity(0.75))
                    Text(bankName?.value ?? "کارت‌به‌کارت").shkFont(14, .bold).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // تراشه‌ی کارت (تزئینی)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [Color(argb: 0xFFF6D365), Color(argb: 0xFFD4A437)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 28)
            }

            Spacer().frame(height: 22)

            if let cardNumber {
                Text(cardNumber.label).shkFont(10).foregroundColor(.white.opacity(0.75))
                Spacer().frame(height: 4)
                CardValueRow(value: formatCardNumberForDisplay(cardNumber.value ?? ""), copyLabel: cardNumber.label,
                             fontSize: 19, letterSpacing: 1, compactCopy: false, onCopy: { onCopy(cardNumber) })
            }

            // شماره‌شبا درست زیر شماره‌کارت با فونت کوچک‌تر
            if let sheba {
                Spacer().frame(height: cardNumber != nil ? 10 : 0)
                Text(sheba.label).shkFont(10).foregroundColor(.white.opacity(0.75))
                Spacer().frame(height: 2)
                CardValueRow(value: sheba.value ?? "", copyLabel: sheba.label,
                             fontSize: 13, letterSpacing: 0.5, compactCopy: true, onCopy: { onCopy(sheba) })
            }

            if cardNumber != nil || sheba != nil { Spacer().frame(height: 18) }

            if let holder {
                Text(holder.label).shkFont(10).foregroundColor(.white.opacity(0.75))
                Text(holder.value ?? "").shkFont(13, .bold).foregroundColor(.white)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            GeometryReader { geo in
                ZStack {
                    LinearGradient(colors: [primary, Color(argb: 0xFF9E0010), Color(argb: 0xFF5E0009)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    // دایره‌های تزئینی پس‌زمینه‌ی کارت (مختصات فیزیکی، بدون آینه شدن)
                    Circle().fill(Color.white.opacity(0.08)).frame(width: 170, height: 170)
                        .position(x: geo.size.width - 20, y: 10)
                    Circle().fill(Color.white.opacity(0.07)).frame(width: 130, height: 130)
                        .position(x: 30, y: geo.size.height)
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        )
        .clipShape(shape)
        .shadow(color: primary.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}

/** ردیف مقدار چپ‌به‌راست روی کارت بانکی + دکمه‌ی کپی */
private struct CardValueRow: View {
    let value: String
    let copyLabel: String
    let fontSize: CGFloat
    let letterSpacing: CGFloat
    let compactCopy: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // شماره‌ها همیشه چپ‌به‌راست نمایش داده می‌شن
            Text(value)
                .shkFont(fontSize, .bold)
                .tracking(letterSpacing)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
            Spacer().frame(width: 8)
            Button(action: onCopy) {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.FileCopyLine, contentDescription: "کپی \(copyLabel)", tint: .white, size: compactCopy ? 13 : 15)
                    Spacer().frame(width: 4)
                    Text("کپی").shkFont(compactCopy ? 10 : 11, .bold).foregroundColor(.white)
                }
                .padding(.horizontal, compactCopy ? 8 : 10)
                .padding(.vertical, compactCopy ? 4 : 6)
                .background(RoundedRectangle(cornerRadius: compactCopy ? 8 : 10, style: .continuous).fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(SitePressStyle())
        }
    }
}

/** ردیف سایر اطلاعات حساب با دکمه‌ی کپی */
private struct BankDetailRow: View {
    let detail: BankDetailDto
    let onCopy: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        HStack(spacing: 0) {
            SiteIconBadge(icon: RemixIcons.BankCardLine, size: 34, iconSize: 17, radius: 10)
            Spacer().frame(width: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(detail.label).shkFont(11).foregroundColor(colors.onSurfaceVariant)
                Text(detail.value ?? "")
                    .shkFont(13, .bold)
                    .foregroundColor(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .frame(maxWidth: .infinity)
            Spacer().frame(width: 8)
            Button(action: onCopy) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(primary.opacity(0.1))
                    RemixIcon(RemixIcons.FileCopyLine, contentDescription: "کپی \(detail.label)", tint: primary, size: 17)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(SitePressStyle())
        }
        .padding(.vertical, 10)
    }
}

/** کادر خط‌چین انتخاب عکس رسید (با پیش‌نمایش بعد از انتخاب) */
struct CardToCardReceiptPicker: View {
    let pickedImage: Data?
    @Binding var pickerItem: PhotosPickerItem?
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack {
                shape.fill(colors.surface)
                if let pickedImage, let image = UIImage(data: pickedImage) {
                    Color.clear
                        .overlay(Image(uiImage: image).resizable().scaledToFill())
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .padding(4)
                    VStack {
                        Spacer()
                        HStack(spacing: 0) {
                            HStack(spacing: 0) {
                                RemixIcon(RemixIcons.CheckboxCircleLine, tint: .white, size: 13)
                                Spacer().frame(width: 4)
                                Text("رسید انتخاب شد").shkFont(11, .bold, lineHeight: 16).foregroundColor(.white).lineLimit(1)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(SiteStatusColors.Success))
                            Spacer()
                            HStack(spacing: 0) {
                                RemixIcon(RemixIcons.ImageEditLine, tint: .white, size: 14)
                                Spacer().frame(width: 4)
                                Text("تغییر تصویر").shkFont(11, .bold).foregroundColor(.white)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.55)))
                        }
                        .padding(12)
                    }
                } else {
                    VStack(spacing: 0) {
                        ZStack {
                            Circle().fill(primary.opacity(0.08))
                            if let logo = UIImage(named: "ic_gateway_card_to_card") {
                                Image(uiImage: logo).resizable().scaledToFit().frame(width: 40, height: 40)
                            }
                        }
                        .frame(width: 64, height: 64)
                        Spacer().frame(height: 10)
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.UploadCloud2Line, tint: primary, size: 18)
                            Spacer().frame(width: 6)
                            Text("برای انتخاب عکس رسید ضربه بزنید").shkFont(13, .bold).foregroundColor(colors.onSurface)
                        }
                        Spacer().frame(height: 4)
                        Text("حداکثر حجم: ۵ مگابایت - فرمت JPG یا PNG").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                    }
                    .padding(16)
                }
                // خط‌چین ۱۲/۹ پیکسل اندروید (~۴/۳ نقطه)
                shape.stroke(pickedImage != nil ? SiteStatusColors.Success : primary.opacity(0.55),
                             style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            .aspectRatio(1.6, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .contentShape(shape)
            .animation(.easeInOut(duration: 0.25), value: pickedImage != nil)
        }
        .buttonStyle(.plain)
    }
}

/** فقط برای نمایش: شماره‌کارت ۱۶ رقمی به گروه‌های ۴تایی (مقدار کپی‌شده همون مقدار اصلیه) */
func formatCardNumberForDisplay(_ value: String) -> String {
    let compact = value.filter { !$0.isWhitespace && $0 != "-" }
    guard compact.count == 16, compact.allSatisfy(\.isWholeNumber) else { return value }
    var groups: [String] = []
    var current = ""
    for ch in compact {
        current.append(ch)
        if current.count == 4 { groups.append(current); current = "" }
    }
    return groups.joined(separator: "  ")
}
