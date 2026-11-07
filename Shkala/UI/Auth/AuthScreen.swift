import SwiftUI

// ===================================================================================
// صفحه‌ی ورود - ترجمه‌ی خط‌به‌خط AuthScreen.kt اپ اندروید: هدر قرمز گرادیانی با لوگوی سایت،
// کارت سفیدِ روی هدر با تب‌های «ورود پیامکی / ورود با رمز عبور»، فیلدها و دکمه‌های کیت طراحی.
// منطق (ارسال کد، ورود با رمز، تایید کد، شمارش معکوس) دقیقاً مثل اندروید.
// تفاوت اجباری سیستم‌عامل: iOS به اپ‌ها اجازه‌ی خواندن پیامک نمی‌ده؛ به‌جای خوانش خودکار پیامک،
// خودِ iOS کد پیامک رو بالای کیبورد پیشنهاد می‌ده (یک لمس = پر شدن کد).
// ===================================================================================

struct AuthScreen: View {
    let onLoginSuccess: () -> Void
    @StateObject private var viewModel: AuthViewModel

    @Environment(\.shkColors) private var colors

    init(onLoginSuccess: @escaping () -> Void, viewModel: AuthViewModel? = nil) {
        self.onLoginSuccess = onLoginSuccess
        _viewModel = StateObject(wrappedValue: viewModel ?? AuthViewModel())
    }

    private var stepTarget: Int {
        if viewModel.uiState.step == .ENTER_CODE { return 2 }
        if viewModel.uiState.loginMode == .PASSWORD { return 1 }
        return 0
    }

    var body: some View {
        let state = viewModel.uiState
        let primary = colors.primary

        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // ---------- هدر قرمز با لوگو ----------
                VStack(spacing: 0) {
                    AuthLogo()
                    Spacer().frame(height: 18)
                    Text(headerTitle(state))
                        .shkFont(20, .bold, lineHeight: 30)
                        .foregroundColor(.white)
                    Spacer().frame(height: 6)
                    Text(headerSubtitle(state))
                        .shkFont(12, lineHeight: 20)
                        .foregroundColor(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 32)
                .padding(.bottom, 64)
                .frame(maxWidth: .infinity)
                // دایره‌های تزئینی کم‌رنگ (بالا-شروع و پایین-پایان، مثل اندروید)
                .background(alignment: .topLeading) {
                    GeometryReader { geo in
                        Circle()
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 150, height: 150)
                            .offset(x: -40, y: -50)
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 120, height: 120)
                            .offset(x: geo.size.width - 120 + 30, y: geo.size.height - 120 + 40)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [primary, primary.opacity(0.82)], startPoint: .top, endPoint: .bottom))
                .clipShape(BottomRoundedShape(radius: 32))

                // ---------- کارت فرم (روی هدر) ----------
                SiteCard(contentPadding: .all(18), radius: 22) {
                    if state.step == .ENTER_PHONE {
                        SiteSegmentedTabs(
                            tabs: [("ورود پیامکی", RemixIcons.MessageLine), ("رمز عبور", RemixIcons.LockPasswordLine)],
                            selectedIndex: state.loginMode == .PASSWORD ? 1 : 0,
                            onSelect: { index in viewModel.onLoginModeChange(index == 1 ? .PASSWORD : .SMS) }
                        )
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(colors.outline.opacity(0.5), lineWidth: 1))
                        Spacer().frame(height: 18)
                    }

                    // معادل AnimatedContent با fadeIn/fadeOut
                    ZStack {
                        switch stepTarget {
                        case 0:
                            PhoneInputStep(
                                phone: state.phone,
                                isLoading: state.isLoading,
                                errorMessage: state.errorMessage,
                                onPhoneChange: viewModel.onPhoneChange,
                                onSubmit: viewModel.sendCode
                            )
                            .transition(Self.fadeTransition)
                        case 1:
                            PasswordInputStep(
                                phone: state.phone,
                                password: state.password,
                                isLoading: state.isLoading,
                                errorMessage: state.errorMessage,
                                onPhoneChange: viewModel.onPhoneChange,
                                onPasswordChange: viewModel.onPasswordChange,
                                onSubmit: viewModel.loginWithPassword
                            )
                            .transition(Self.fadeTransition)
                        default:
                            CodeInputStep(
                                code: state.code,
                                isLoading: state.isLoading,
                                errorMessage: state.errorMessage,
                                remainingSeconds: state.remainingSeconds,
                                otpStatus: state.otpStatus,
                                shakeKey: state.otpShakeKey,
                                onCodeChange: viewModel.onCodeChange,
                                onSubmit: viewModel.verifyCode,
                                onResend: viewModel.sendCode,
                                onBack: viewModel.backToPhoneStep
                            )
                            .transition(Self.fadeTransition)
                        }
                    }
                    .animation(.easeInOut(duration: 0.22), value: stepTarget)
                }
                .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 2)
                .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 5)
                .padding(.horizontal, 18)
                .offset(y: -40)

                Spacer().frame(height: 8)
            }
        }
        .background(colors.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: state.loginSuccess) { success in
            if success { onLoginSuccess() }
        }
        // ویومدل ورود بعد از ورود موفق پاک می‌شه تا بعد از «خروج از حساب» صفحه‌ی ورود از نو نمایش داده بشه
        .onAppear { viewModel.resetAfterLogin() }
        .onDisappear { viewModel.resetAfterLogin() }
    }

    private static let fadeTransition = AnyTransition.asymmetric(
        insertion: .opacity.animation(.linear(duration: 0.22).delay(0.09)),
        removal: .opacity.animation(.linear(duration: 0.09))
    )

    private func headerTitle(_ state: AuthUiState) -> String {
        if state.step == .ENTER_CODE { return "تایید شماره موبایل" }
        if state.loginMode == .PASSWORD { return "ورود با رمز عبور" }
        return "ورود | ثبت‌نام"
    }

    private func headerSubtitle(_ state: AuthUiState) -> String {
        if state.step == .ENTER_CODE { return "کد ارسال‌شده به \(state.phone.toPersianDigits()) را وارد کنید" }
        if state.loginMode == .PASSWORD { return "شماره موبایل و رمز عبور خود را وارد کنید" }
        return "برای ورود یا ساخت حساب، شماره موبایل خود را وارد کنید"
    }
}

/// گوشه‌های پایینی گرد (RoundedCornerShape(bottomStart = r, bottomEnd = r))
struct BottomRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.height / 2, rect.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// لوگوی سایت (از تنظیمات اسکریپت) داخل کارت سفید؛ اگه لوگو در دسترس نبود، آیکن جایگزین
private struct AuthLogo: View {
    @Environment(\.shkColors) private var colors

    var body: some View {
        let logoUrl = [SiteInfoCache.logoUrl, SiteInfoCache.logoDarkUrl].compactMap { $0 }.first { !$0.isEmpty }
        ZStack {
            if let logoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Color.clear
                    }
                }
            } else {
                RemixIcon(RemixIcons.ShieldUserLine, tint: colors.primary, size: 38)
            }
        }
        .padding(12)
        .frame(width: 84, height: 84)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white))
        .shadow(color: .black.opacity(0.2), radius: 9, x: 0, y: 4)
    }
}

private struct ErrorLine: View {
    let errorMessage: String?
    @Environment(\.shkColors) private var colors

    var body: some View {
        if let errorMessage {
            VStack(spacing: 0) {
                Spacer().frame(height: 10)
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.ErrorWarningLine, tint: colors.error, size: 16)
                    Spacer().frame(width: 6)
                    Text(errorMessage)
                        .shkFont(12, lineHeight: 20)
                        .foregroundColor(colors.error)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.error.opacity(0.08)))
            }
        }
    }
}

/// ارقام فارسی/عربی کیبورد → لاتین و فقط رقم (مثل filter(Char::isDigit) اندروید)
private func digitsOnly(_ s: String) -> String {
    let persian: [Character] = Array("۰۱۲۳۴۵۶۷۸۹")
    let arabic: [Character] = Array("٠١٢٣٤٥٦٧٨٩")
    return String(s.compactMap { c -> Character? in
        if let i = persian.firstIndex(of: c) ?? arabic.firstIndex(of: c) { return Character(String(i)) }
        return c.isASCII && c.isNumber ? c : nil
    })
}

private struct PhoneField: View {
    let phone: String
    let isError: Bool
    let onPhoneChange: (String) -> Void
    let submitLabel: SubmitLabel
    let onDone: () -> Void

    var body: some View {
        SiteTextField(
            value: Binding(get: { phone }, set: { onPhoneChange($0) }),
            label: "شماره موبایل",
            placeholder: "09123456789",
            leadingIcon: RemixIcons.SmartphoneLine,
            minHeight: 50,
            keyboard: .phone,
            textContentType: .telephoneNumber,
            submitLabel: submitLabel,
            onSubmit: onDone,
            isError: isError,
            maxLength: 11,
            filter: digitsOnly
        )
    }
}

private struct PasswordInputStep: View {
    let phone: String
    let password: String
    let isLoading: Bool
    let errorMessage: String?
    let onPhoneChange: (String) -> Void
    let onPasswordChange: (String) -> Void
    let onSubmit: () -> Void

    @State private var passwordVisible = false
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhoneField(phone: phone, isError: errorMessage != nil, onPhoneChange: onPhoneChange, submitLabel: .next, onDone: {})
            Spacer().frame(height: 12)
            SiteTextField(
                value: Binding(get: { password }, set: { onPasswordChange($0) }),
                label: "رمز عبور",
                placeholder: "رمز عبور خود را وارد کنید",
                leadingIcon: RemixIcons.LockPasswordLine,
                minHeight: 50,
                keyboard: .password,
                textContentType: .password,
                submitLabel: .done,
                onSubmit: { if !isLoading { onSubmit() } },
                secure: !passwordVisible,
                isError: errorMessage != nil
            ) {
                Button(action: { passwordVisible.toggle() }) {
                    RemixIcon(
                        passwordVisible ? RemixIcons.EyeOffLine : RemixIcons.EyeLine,
                        contentDescription: passwordVisible ? "مخفی کردن رمز عبور" : "نمایش رمز عبور",
                        tint: colors.onSurfaceVariant,
                        size: 20
                    )
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
                }
                .buttonStyle(SitePressStyle())
                .frame(height: 28)
            }
            ErrorLine(errorMessage: errorMessage)
            Spacer().frame(height: 20)
            SitePrimaryButton(
                text: "ورود به حساب",
                onClick: onSubmit,
                icon: RemixIcons.LoginBoxLine,
                loading: isLoading,
                height: 50,
                fillWidth: true
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PhoneInputStep: View {
    let phone: String
    let isLoading: Bool
    let errorMessage: String?
    let onPhoneChange: (String) -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhoneField(
                phone: phone,
                isError: errorMessage != nil,
                onPhoneChange: onPhoneChange,
                submitLabel: .done,
                onDone: { if !isLoading { onSubmit() } }
            )
            ErrorLine(errorMessage: errorMessage)
            Spacer().frame(height: 20)
            SitePrimaryButton(
                text: "دریافت کد تایید",
                onClick: onSubmit,
                icon: RemixIcons.MailSendLine,
                loading: isLoading,
                height: 50,
                fillWidth: true
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private let OTP_LENGTH = 5

private struct CodeInputStep: View {
    let code: String
    let isLoading: Bool
    let errorMessage: String?
    let remainingSeconds: Int
    let otpStatus: OtpBoxStatus
    let shakeKey: Int
    let onCodeChange: (String) -> Void
    let onSubmit: () -> Void
    let onResend: () -> Void
    let onBack: () -> Void

    @State private var secondsLeft: Int = 0
    @State private var timerTask: Task<Void, Never>? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        let isSuccess = otpStatus == .success
        VStack(spacing: 0) {
            OtpBoxInput(
                code: code,
                length: OTP_LENGTH,
                onCodeChange: onCodeChange,
                isError: false,
                status: otpStatus,
                shakeKey: shakeKey
            )

            // پیام موفقیت (با ظاهر شدن نرم)
            if isSuccess {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.CheckboxCircleFill, tint: SiteStatusColors.Success, size: 18)
                    Spacer().frame(width: 6)
                    Text("ورود با موفقیت انجام شد")
                        .shkFont(13, .bold)
                        .foregroundColor(SiteStatusColors.Success)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(SiteStatusColors.Success.opacity(0.12)))
                .padding(.top, 14)
                .transition(
                    .opacity.combined(with: .scale(scale: 0.8))
                        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.3).delay(0.35))
                )
            }

            if !isSuccess { ErrorLine(errorMessage: errorMessage) }

            if isLoading && !isSuccess {
                Spacer().frame(height: 16)
                HStack(spacing: 0) {
                    MaterialSpinner(color: colors.primary, lineWidth: 2, size: 18)
                    Spacer().frame(width: 8)
                    Text("در حال بررسی کد...")
                        .shkFont(12)
                        .foregroundColor(colors.onSurfaceVariant)
                }
            }

            Spacer().frame(height: 18)

            // شمارش معکوس / ارسال مجدد
            if secondsLeft > 0 {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.TimerLine, tint: colors.onSurfaceVariant, size: 15)
                    Spacer().frame(width: 6)
                    Text("ارسال مجدد کد تا \(String(secondsLeft).toPersianDigits()) ثانیه دیگر")
                        .shkFont(12)
                        .foregroundColor(colors.onSurfaceVariant)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(colors.surfaceVariant))
            } else {
                Button(action: onResend) {
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.RefreshLine, tint: colors.primary, size: 15)
                        Spacer().frame(width: 6)
                        Text("ارسال مجدد کد")
                            .shkFont(12, .bold)
                            .foregroundColor(colors.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(colors.primary.opacity(0.08)))
                    .contentShape(Capsule())
                }
                .buttonStyle(SitePressStyle())
                .disabled(isLoading)
            }

            Spacer().frame(height: 12)

            Button(action: onBack) {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.EditLine, tint: colors.onSurfaceVariant, size: 15)
                    Spacer().frame(width: 6)
                    Text("ویرایش شماره موبایل")
                        .shkFont(12)
                        .foregroundColor(colors.onSurfaceVariant)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(SitePressStyle())
        }
        .frame(maxWidth: .infinity)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.3), value: isSuccess)
        .onAppear { startTimer(remainingSeconds) }
        .onChange(of: remainingSeconds) { startTimer($0) }
        .onDisappear { timerTask?.cancel() }
        // به‌محض تکمیل شدن ۵ رقم، خودکار تایید انجام می‌شه (نیازی به زدن دکمه نیست)
        .onChange(of: code) { newCode in
            if newCode.count == OTP_LENGTH && !isLoading { onSubmit() }
        }
    }

    private func startTimer(_ seconds: Int) {
        timerTask?.cancel()
        secondsLeft = seconds
        timerTask = Task { @MainActor in
            while secondsLeft > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                secondsLeft -= 1
            }
        }
    }
}
