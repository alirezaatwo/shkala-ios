import SwiftUI

/**
 * معادل ui/forms/DynamicFormScreen.kt
 * فاز ۳۲: نمایش و ارسال نیتیو فرم‌های داینامیک اسکریپت (مثل «تماس با ما») - بدون
 * وب‌ویو. چون فیلدها کاملاً از پنل ادمین قابل تغییرن، این صفحه هیچ فیلدی رو
 * hardcode نمی‌کنه - هرچی از سرور بیاد رو بر اساس نوعش (type) رندر می‌کنه.
 *
 * کپچا: خودِ اسکریپت یه کپچای ساده‌ی ریاضی (جمع دو عدد) داره که کاملاً سمت کلاینت
 * تولید و چک می‌شه (captcha_args.first + captcha_args.two == captcha) - همینو این‌جا
 * هم پیاده کردیم.
 */
struct DynamicFormScreen: View {
    let slug: String
    let fallbackTitle: String
    let onBack: () -> Void

    @Environment(\.shkColors) private var colors
    @State private var loadedTitle: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: onBack) {
                    RemixIcon(RemixIcons.ArrowRightLine, contentDescription: "بازگشت", tint: colors.onBackground, size: 22)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surface))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer().frame(width: 10)
                Text(loadedTitle ?? fallbackTitle).shkFont(16, .bold).foregroundColor(colors.onBackground)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            ScrollView {
                DynamicFormBody(slug: slug, onTitleLoaded: { loadedTitle = $0 })
                    .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
    }
}

/**
 * فاز ۳۲/۳۳: بدنه‌ی فرم داینامیک (بدون پس‌زمینه/هدر خودش) - تا هم داخل
 * DynamicFormScreen مستقل استفاده بشه، هم داخل صفحه‌ی سفارشی «تماس با ما».
 */
struct DynamicFormBody: View {
    let slug: String
    var onTitleLoaded: (String) -> Void = { _ in }
    // فاز ۳۴ (کد ۴): توی صفحه‌ی «تماس با ما»، توضیحات HTML خودِ فرم نمایش داده نمی‌شه
    var showDescription: Bool = true

    @Environment(\.shkColors) private var colors
    private let repository = ContentRepository()

    @State private var form: FormDto? = nil
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var isSubmitting = false
    @State private var fieldValues: [String: String] = [:]
    @State private var checkboxValues: [String: Bool] = [:]
    @State private var captchaFirst = Int.random(in: 1..<10)
    @State private var captchaSecond = Int.random(in: 1..<10)
    @State private var captchaAnswer = ""

    private func submit() {
        guard let currentForm = form, !isSubmitting else { return }

        // اعتبارسنجی سمت اپ (پیش از ارسال) - همون فیلدهای الزامی که خودِ اسکریپت هم چک می‌کنه
        for field in currentForm.fields where field.status == "necessary" && field.type != "checkbox" {
            if (fieldValues[field.id] ?? "").isBlankShk {
                ShkToast.shared.show("لطفاً «\(field.title)» را پر کنید.")
                return
            }
        }
        guard let captchaInt = Int(captchaAnswer.trimmingCharacters(in: .whitespaces).englishDigits) else {
            ShkToast.shared.show("لطفاً جواب سوال امنیتی را وارد کنید.")
            return
        }

        let answerList = currentForm.fields.map { field in
            let value = field.type == "checkbox" ? (checkboxValues[field.id] == true ? "1" : "") : (fieldValues[field.id] ?? "")
            return FormAnswerFieldDto(id: field.id, title: field.title, type: field.type, status: field.status, value: value)
        }

        Task {
            isSubmitting = true
            let body = FormAnswerSubmitRequest(
                captchaArgs: CaptchaArgsDto(first: captchaFirst, two: captchaSecond),
                captcha: captchaInt,
                answer: answerList
            )
            switch await repository.submitFormAnswer(slug, body: body) {
            case .success(let message):
                ShkToast.shared.show(message, long: true)
                // پاک کردن فرم بعد از ارسال موفق + تولید یه کپچای جدید
                fieldValues = [:]
                checkboxValues = [:]
                captchaAnswer = ""
                captchaFirst = Int.random(in: 1..<10)
                captchaSecond = Int.random(in: 1..<10)
            case .error(let message):
                ShkToast.shared.show(message, long: true)
            }
            isSubmitting = false
        }
    }

    var body: some View {
        Group {
            if isLoading {
                MaterialSpinner(color: colors.primary, lineWidth: 4, size: 40)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if form == nil, let loadError {
                Text(loadError).shkFont(14).foregroundColor(colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if let currentForm = form {
                VStack(alignment: .leading, spacing: 0) {
                    if showDescription, let description = currentForm.description, !description.isBlankShk {
                        Text(description)
                            .shkFont(.bodyMedium)
                            .foregroundColor(colors.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 12)
                    }

                    ForEach(Array(currentForm.fields.enumerated()), id: \.offset) { _, field in
                        FormFieldInput(
                            field: field,
                            textValue: Binding(get: { fieldValues[field.id] ?? "" }, set: { fieldValues[field.id] = $0 }),
                            checkedValue: Binding(get: { checkboxValues[field.id] ?? false }, set: { checkboxValues[field.id] = $0 })
                        )
                        Spacer().frame(height: 12)
                    }

                    // کپچای ساده‌ی ریاضی - دقیقاً همون منطق خودِ اسکریپت
                    FormFieldLabel(text: "سوال امنیتی", necessary: true)
                    HStack(spacing: 8) {
                        Text("\(captchaFirst.toPersianDigits()) + \(captchaSecond.toPersianDigits()) = ؟")
                            .shkFont(14, .bold)
                            .foregroundColor(colors.primary)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.primary.opacity(0.1)))
                        SiteFormField(value: $captchaAnswer, placeholder: "حاصل جمع را وارد کنید", keyboard: .numberPad)
                    }

                    Spacer().frame(height: 18)
                    Button(action: submit) {
                        HStack(spacing: 0) {
                            if isSubmitting {
                                MaterialSpinner(color: .white, lineWidth: 2, size: 20)
                            } else {
                                RemixIcon(RemixIcons.SendPlaneFill, tint: .white, size: 18)
                                Spacer().frame(width: 8)
                                Text("ارسال پیام").shkFont(14, .bold).foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isSubmitting ? colors.onSurface.opacity(0.12) : colors.primary))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
            }
        }
        .task(id: slug) {
            guard form == nil else { return }
            isLoading = true
            switch await repository.getForm(slug) {
            case .success(let f):
                form = f
                loadError = nil
                onTitleLoaded(f.title)
            case .error(let message):
                loadError = message
            }
            isLoading = false
        }
    }
}

private extension String {
    /// ارقام فارسی/عربی → انگلیسی (برای خوندن جواب کپچا)
    var englishDigits: String {
        String(map { ch -> Character in
            guard let v = ch.unicodeScalars.first?.value else { return ch }
            if (0x06F0...0x06F9).contains(v) { return Character(UnicodeScalar(v - 0x06F0 + 0x30)!) }
            if (0x0660...0x0669).contains(v) { return Character(UnicodeScalar(v - 0x0660 + 0x30)!) }
            return ch
        })
    }
}

/** برچسب بالای هر فیلد - فیلدهای الزامی با ستاره‌ی قرمز */
private struct FormFieldLabel: View {
    let text: String
    let necessary: Bool
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            Text(text).shkFont(12, .medium).foregroundColor(colors.onSurface)
            if necessary { Text(" *").shkFont(12, .bold).foregroundColor(colors.primary) }
        }
        .padding(.bottom, 6)
    }
}

/**
 * فیلد ورودی جمع‌وجور به سبک سایت: پس‌زمینه‌ی ملایم، گوشه‌ی ۱۲، بدون حاشیه در حالت
 * عادی و حاشیه‌ی قرمز هنگام فوکوس.
 */
private struct SiteFormField: View {
    @Binding var value: String
    var placeholder: String = ""
    var singleLine: Bool = true
    var minHeight: CGFloat = 44
    var keyboard: UIKeyboardType = .default

    @Environment(\.shkColors) private var colors
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        ZStack(alignment: singleLine ? .leading : .topLeading) {
            if value.isEmpty && !placeholder.isEmpty {
                Text(placeholder).shkFont(13).foregroundColor(colors.onSurfaceVariant.opacity(0.7))
            }
            Group {
                if singleLine {
                    TextField("", text: $value)
                } else {
                    TextField("", text: $value, axis: .vertical)
                }
            }
            .font(ShkFont.yekan(13))
            .foregroundColor(colors.onSurface)
            .tint(colors.primary)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .focused($focused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: singleLine ? .leading : .topLeading)
        .background(shape.fill(colors.surfaceVariant))
        .overlay(shape.strokeBorder(focused ? colors.primary : Color.clear, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture { focused = true }
    }
}

private struct FormFieldInput: View {
    let field: FormFieldDto
    @Binding var textValue: String
    @Binding var checkedValue: Bool
    @Environment(\.shkColors) private var colors

    var body: some View {
        let necessary = field.status == "necessary"
        switch field.type {
        case "checkbox":
            HStack(spacing: 0) {
                MaterialCheckbox(checked: checkedValue)
                Text(field.title).shkFont(13).foregroundColor(colors.onSurface)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { checkedValue.toggle() }
        case "textarea":
            VStack(alignment: .leading, spacing: 0) {
                FormFieldLabel(text: field.title, necessary: necessary)
                SiteFormField(value: $textValue, placeholder: field.title, singleLine: false, minHeight: 110)
            }
        case "email":
            VStack(alignment: .leading, spacing: 0) {
                FormFieldLabel(text: field.title, necessary: necessary)
                SiteFormField(value: $textValue, placeholder: field.title, keyboard: .emailAddress)
            }
        default:
            VStack(alignment: .leading, spacing: 0) {
                FormFieldLabel(text: field.title, necessary: necessary)
                SiteFormField(value: $textValue, placeholder: field.title)
            }
        }
    }
}

/// معادل Checkbox متریال ۳: کادر ۱۸ با حاشیه‌ی ۲، در حالت انتخاب پُر با تیک؛ ناحیه‌ی لمس ۴۸
struct MaterialCheckbox: View {
    let checked: Bool
    @Environment(\.shkColors) private var colors

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(checked ? colors.primary : Color.clear)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .strokeBorder(checked ? colors.primary : colors.onSurfaceVariant, lineWidth: 2)
            if checked {
                Path { p in
                    p.move(to: CGPoint(x: 4, y: 9.5))
                    p.addLine(to: CGPoint(x: 7.5, y: 13))
                    p.addLine(to: CGPoint(x: 14, y: 5.5))
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .square))
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .frame(width: 18, height: 18)
        .frame(width: 48, height: 48)
        .animation(.easeInOut(duration: 0.15), value: checked)
    }
}
