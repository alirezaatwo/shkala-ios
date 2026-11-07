import SwiftUI

// معادل ui/wallet/AddBankCardScreen.kt

struct AddBankCardScreen: View {
    let onBack: () -> Void
    let onSaved: () -> Void
    var editCard: BankCardDto? = nil

    @Environment(\.shkColors) private var colors
    private let repository = WalletRepository()

    @State private var name: String
    @State private var cardNumber: String
    // شبا فقط ۲۴ رقم بدون IR (مثل فرم سایت که IR- رو جدا نشون می‌ده)
    @State private var shebaNumber: String
    @State private var isSubmitting = false
    @State private var showErrors = false

    init(onBack: @escaping () -> Void, onSaved: @escaping () -> Void, editCard: BankCardDto? = nil) {
        self.onBack = onBack
        self.onSaved = onSaved
        self.editCard = editCard
        // حالت ویرایش: فیلدها با اطلاعات کارت پر می‌شن
        _name = State(initialValue: editCard?.name ?? "")
        _cardNumber = State(initialValue: editCard.map { String($0.cardNumber.filter { $0.isASCII && $0.isNumber }.prefix(16)) } ?? "")
        _shebaNumber = State(initialValue: editCard.map { String(shebaDigits($0.shebaNumber).prefix(24)) } ?? "")
    }

    private var isEdit: Bool { editCard != nil }
    private var nameError: String? { name.trimmingCharacters(in: .whitespaces).isEmpty ? "نام صاحب کارت را وارد کنید." : nil }
    private var cardError: String? { cardNumber.count != 16 ? "شماره کارت باید دقیقاً ۱۶ رقم باشد." : nil }
    private var shebaError: String? { shebaNumber.count != 24 ? "شماره شبا باید دقیقاً ۲۴ رقم باشد." : nil }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: isEdit ? "ویرایش کارت بانکی" : "افزودن کارت بانکی", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 4)
                    // پیش‌نمایش زنده‌ی کارت
                    WalletBankCardVisual(
                        cardNumber: cardNumber,
                        holderName: name,
                        masked: false,
                        width: nil,
                        shebaNumber: shebaNumber
                    )

                    Spacer().frame(height: 20)
                    SiteSectionTitle("مشخصات کارت")
                    Spacer().frame(height: 12)
                    SiteCard {
                        VStack(alignment: .leading, spacing: 0) {
                            SiteTextField(
                                value: $name,
                                label: "نام صاحب کارت",
                                necessary: true,
                                leadingIcon: RemixIcons.UserLine,
                                isError: showErrors && nameError != nil,
                                helperText: showErrors ? nameError : nil
                            )
                            Spacer().frame(height: 14)
                            // شماره کارت: ارقام تایپ‌شده دقیقاً جای صفرهای الگو (از چپ به راست) می‌شینن؛
                            // خط تیره‌ها فقط نمایشی‌ان و مقدار ذخیره/ارسال‌شده فقط رقمه
                            MaskedDigitsField(
                                value: $cardNumber,
                                label: "شماره کارت (۱۶ رقم)",
                                totalDigits: 16,
                                groupSize: 4,
                                separator: "-",
                                icon: RemixIcons.BankCardLine,
                                isError: showErrors && cardError != nil,
                                helperText: (showErrors && cardError != nil)
                                    ? "\(cardError!) (\(cardNumber.count.toPersianDigits()) از ۱۶)"
                                    : "\(cardNumber.count.toPersianDigits()) از ۱۶ رقم"
                            )
                            Spacer().frame(height: 14)
                            // شماره شبا: پیشوند ثابت IR (تایپ و ارسال نمی‌شه، مثل فرم سایت) + ۲۴ رقم
                            MaskedDigitsField(
                                value: $shebaNumber,
                                label: "شماره شبا (۲۴ رقم)",
                                totalDigits: 24,
                                groupSize: 4,
                                separator: " ",
                                icon: RemixIcons.BankLine,
                                isError: showErrors && shebaError != nil,
                                helperText: (showErrors && shebaError != nil)
                                    ? "\(shebaError!) (\(shebaNumber.count.toPersianDigits()) / ۲۴)"
                                    : "\(shebaNumber.count.toPersianDigits()) / ۲۴",
                                prefix: "IR"
                            )
                        }
                    }

                    Spacer().frame(height: 24)

                    SitePrimaryButton(
                        text: isEdit ? "ذخیره‌ی تغییرات" : "ذخیره‌ی کارت",
                        onClick: save,
                        icon: RemixIcons.CheckLine,
                        loading: isSubmitting,
                        fillWidth: true
                    )
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
    }

    private func save() {
        if nameError != nil || cardError != nil || shebaError != nil {
            showErrors = true
            ShkToast.shared.show(nameError ?? cardError ?? shebaError ?? "")
            return
        }
        isSubmitting = true
        Task {
            let result: ApiResult<AddBankCardResponse>
            if let editCard {
                result = await repository.updateBankCard(id: editCard.id, name: name, cardNumber: cardNumber, shebaNumber: shebaNumber)
            } else {
                result = await repository.addBankCard(name: name, cardNumber: cardNumber, shebaNumber: shebaNumber)
            }
            isSubmitting = false
            switch result {
            case .success: onSaved()
            case .error(let message): ShkToast.shared.show(message)
            }
        }
    }
}

/// ارقام فارسی/عربی رو به لاتین تبدیل و هر چیز غیرعددی رو حذف می‌کنه
private func normalizeCardDigits(_ input: String) -> String {
    var out = ""
    for ch in input {
        guard ch.unicodeScalars.count == 1, let v = ch.unicodeScalars.first?.value else { continue }
        if (0x30...0x39).contains(v) { out.append(ch) }
        else if (0x06F0...0x06F9).contains(v) { out.append(Character(UnicodeScalar(0x30 + v - 0x06F0)!)) }
        else if (0x0660...0x0669).contains(v) { out.append(Character(UnicodeScalar(0x30 + v - 0x0660)!)) }
    }
    return out
}

/**
 * فیلد ورودی عددیِ ماسک‌دار (شماره کارت / شبا) با ظاهر فیلدهای اپ.
 * - جهت فیلد همیشه چپ‌به‌راسته، پس ارقام دقیقاً به ترتیب جای صفرهای الگو می‌شینن.
 * - صفرهای باقی‌مونده‌ی الگو کم‌رنگ نمایش داده می‌شن و جداکننده‌ها فقط نمایشی‌ان؛
 *   مقدار واقعی فقط رقم‌های واردشده‌ست.
 * تفاوت iOS: SwiftUI معادل VisualTransformation نداره؛ یه TextField نامرئی ورودی رو می‌گیره و
 * متن ماسک‌شده روش کشیده می‌شه (مکان‌نما همیشه انتهای ارقام واردشده‌ست).
 */
private struct MaskedDigitsField: View {
    @Binding var value: String
    let label: String
    let totalDigits: Int
    let groupSize: Int
    let separator: Character
    let icon: String
    let isError: Bool
    let helperText: String?
    var prefix: String? = nil

    @Environment(\.shkColors) private var colors
    @FocusState private var focused: Bool
    @State private var caretVisible = true

    private var maskedText: Text {
        let maskColor = colors.onSurfaceVariant.opacity(0.45)
        let digits = Array(value.prefix(totalDigits))
        let typed = digits.count
        var result = Text("")
        for i in 0..<totalDigits {
            if i > 0 && i % groupSize == 0 {
                let sep = Text(String(separator))
                result = result + ((i <= typed && typed > 0) ? sep.foregroundColor(colors.onSurface) : sep.foregroundColor(maskColor))
            }
            if i == typed && focused {
                // مکان‌نمای چشمک‌زن (تفاوت iOS)
                result = result + Text("|").foregroundColor(caretVisible ? colors.primary : .clear)
            }
            if i < typed {
                result = result + Text(String(digits[i])).foregroundColor(colors.onSurface)
            } else {
                result = result + Text("0").foregroundColor(maskColor)
            }
        }
        if typed == totalDigits && focused {
            result = result + Text("|").foregroundColor(caretVisible ? colors.primary : .clear)
        }
        return result
    }

    var body: some View {
        let primary = colors.primary
        let borderColor: Color = isError ? colors.error : (focused ? primary : .clear)
        VStack(alignment: .leading, spacing: 0) {
            SiteFieldLabel(text: label, necessary: true)
            HStack(spacing: 0) {
                if let prefix {
                    Text(prefix).shkFont(15, .bold).foregroundColor(colors.onSurfaceVariant)
                    Spacer().frame(width: 6)
                }
                ZStack(alignment: .leading) {
                    TextField("", text: Binding(
                        get: { value },
                        set: { input in value = String(normalizeCardDigits(input).prefix(totalDigits)) }
                    ))
                    .keyboardType(.numberPad)
                    .focused($focused)
                    .foregroundColor(.clear)
                    .tint(.clear)
                    .opacity(0.02)
                    maskedText
                        .shkFont(15, .medium)
                        .tracking(0.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 8)
                RemixIcon(icon, tint: focused ? primary : colors.onSurfaceVariant, size: 18)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(borderColor, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            .environment(\.layoutDirection, .leftToRight)

            if let helperText, !helperText.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(helperText)
                    .shkFont(11, lineHeight: 18)
                    .foregroundColor(isError ? colors.error : colors.onSurfaceVariant)
                    .padding(.top, 4)
                    .padding(.leading, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: focused) {
            caretVisible = true
            while focused && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 530_000_000)
                caretVisible.toggle()
            }
        }
    }
}
