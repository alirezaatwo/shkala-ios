import Foundation

enum AuthStep { case ENTER_PHONE, ENTER_CODE }
enum LoginMode { case SMS, PASSWORD }

/// معادل AuthUiState اپ اندروید
struct AuthUiState {
    var step: AuthStep = .ENTER_PHONE
    var loginMode: LoginMode = .SMS
    var phone: String = ""
    var code: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var remainingSeconds: Int = 0
    var loginSuccess: Bool = false
    var userType: String? = nil
    // وضعیت نمایشی خانه‌های کد (سبز/قرمز) و شمارنده‌ی لرزش برای کد اشتباه
    var otpStatus: OtpBoxStatus = .none
    var otpShakeKey: Int = 0
}

/// معادل AuthViewModel اپ اندروید (ui/auth/AuthViewModel.kt) - همان منطق و همان پیام‌ها
@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var uiState = AuthUiState()

    private let repository: AuthRepository

    init(repository: AuthRepository = AuthRepository()) {
        self.repository = repository
    }

    func onLoginModeChange(_ mode: LoginMode) {
        uiState.loginMode = mode
        uiState.errorMessage = nil
    }

    func onPhoneChange(_ value: String) {
        uiState.phone = value
        uiState.errorMessage = nil
    }

    func onCodeChange(_ value: String) {
        if uiState.otpStatus == .success { return }
        uiState.code = value
        uiState.errorMessage = nil
        uiState.otpStatus = .none
    }

    func onPasswordChange(_ value: String) {
        uiState.password = value
        uiState.errorMessage = nil
    }

    func loginWithPassword() {
        let phone = uiState.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isValidIranianPhone(phone) {
            uiState.errorMessage = "شماره موبایل معتبر نیست. مثال: 09123456789"
            return
        }
        if uiState.password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            uiState.errorMessage = "رمز عبور را وارد کنید."
            return
        }
        uiState.isLoading = true
        uiState.errorMessage = nil
        let password = uiState.password
        Task {
            switch await repository.loginWithPassword(phone, password) {
            case .success(let user):
                uiState.isLoading = false
                uiState.loginSuccess = true
                uiState.userType = user.type
            case .error(let message):
                uiState.isLoading = false
                uiState.errorMessage = message
            }
        }
    }

    func sendCode() {
        let phone = uiState.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isValidIranianPhone(phone) {
            uiState.errorMessage = "شماره موبایل معتبر نیست. مثال: 09123456789"
            return
        }
        uiState.isLoading = true
        uiState.errorMessage = nil
        Task {
            switch await repository.sendCode(phone) {
            case .success(let seconds):
                uiState.isLoading = false
                uiState.step = .ENTER_CODE
                uiState.remainingSeconds = seconds
                uiState.otpStatus = .none
            case .error(let message):
                uiState.isLoading = false
                uiState.errorMessage = message
            }
        }
    }

    func verifyCode() {
        if uiState.otpStatus == .success { return }
        let code = uiState.code.trimmingCharacters(in: .whitespacesAndNewlines)
        if code.count != 5 {
            uiState.errorMessage = "کد تایید را کامل وارد کنید."
            return
        }
        uiState.isLoading = true
        uiState.errorMessage = nil
        let phone = uiState.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let result = await repository.verifyCode(phone, code, onVerified: { @MainActor [weak self] in
                // کد درست بود: اول انیمیشن سبز شدن خانه‌ها و پیام موفقیت، بعد ورود
                self?.uiState.isLoading = false
                self?.uiState.errorMessage = nil
                self?.uiState.otpStatus = .success
                try? await Task.sleep(nanoseconds: 1_400_000_000)
            })
            switch result {
            case .success(let user):
                uiState.isLoading = false
                uiState.loginSuccess = true
                uiState.userType = user.type
            case .error(let message):
                // کد اشتباه: لرزش و قرمز شدن خانه‌ها، بعد پاک شدن کد برای ورود دوباره
                uiState.isLoading = false
                uiState.errorMessage = message
                uiState.otpStatus = .error
                uiState.otpShakeKey += 1
                try? await Task.sleep(nanoseconds: 1_300_000_000)
                if uiState.otpStatus == .error && uiState.code == code {
                    uiState.code = ""
                    uiState.otpStatus = .none
                }
            }
        }
    }

    /// بعد از ورود موفق، صفحه‌ی ورود باید دفعه‌ی بعد (مثلاً بعد از خروج از حساب) از نو و خالی
    /// نمایش داده بشه - نه با همون مرحله‌ی کدِ تأییدشده و خانه‌های سبز
    func resetAfterLogin() {
        if !uiState.loginSuccess { return }
        uiState = AuthUiState(loginMode: uiState.loginMode)
    }

    func backToPhoneStep() {
        uiState.step = .ENTER_PHONE
        uiState.code = ""
        uiState.errorMessage = nil
        uiState.otpStatus = .none
    }

    private func isValidIranianPhone(_ phone: String) -> Bool {
        phone.range(of: "^09[0-9]{9}$", options: .regularExpression) != nil
    }

    /// فقط برای حالت اسکرین‌شات (ScreenshotMode): ساخت مستقیم یک وضعیت نمایشی
    func debugSetState(_ state: AuthUiState) { uiState = state }
}
