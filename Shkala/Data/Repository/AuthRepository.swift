import Foundation

/// معادل AuthRepository اپ اندروید (data/AuthRepository.kt) - همان پیام‌های خطا
final class AuthRepository {
    private let tokenManager: TokenManager

    init(tokenManager: TokenManager = .shared) {
        self.tokenManager = tokenManager
    }

    func sendCode(_ phone: String) async -> ApiResult<Int> {
        do {
            let response = try await ApiService.sendCode(SendCodeRequest(phone: phone))
            if response.isSuccessful, let body = response.body {
                return .success(body.remainingSeconds ?? 0)
            }
            return .error(extractErrorMessage(response.errorBodyString))
        } catch {
            return .error("خطا در اتصال به اینترنت. لطفاً دوباره تلاش کنید.")
        }
    }

    /// [onVerified] درست قبل از ذخیره‌ی توکن صدا زده می‌شه - صفحه‌ی ورود ازش برای نمایش انیمیشن
    /// «کد درست بود» استفاده می‌کنه (بعد از ذخیره‌ی توکن، صفحه‌ی حساب فوراً جایگزین صفحه‌ی ورود می‌شه).
    func verifyCode(_ phone: String, _ code: String, onVerified: @escaping () async -> Void = {}) async -> ApiResult<UserDto> {
        let response: ApiResponse<VerifyCodeResponse>
        do {
            response = try await ApiService.verifyCode(VerifyCodeRequest(phone: phone, code: code))
        } catch {
            return .error("خطا در اتصال به اینترنت. لطفاً دوباره تلاش کنید.")
        }
        if response.isSuccessful, let token = response.body?.token, let user = response.body?.user {
            await onVerified()
            tokenManager.saveSession(token: token, userType: user.type)
            return .success(user)
        }
        return .error(extractErrorMessage(response.errorBodyString))
    }

    func loginWithPassword(_ phone: String, _ password: String) async -> ApiResult<UserDto> {
        do {
            let response = try await ApiService.loginWithPassword(PasswordLoginRequest(phone: phone, password: password))
            if response.isSuccessful, let token = response.body?.token, let user = response.body?.user {
                tokenManager.saveSession(token: token, userType: user.type)
                return .success(user)
            }
            return .error(extractErrorMessage(response.errorBodyString))
        } catch {
            return .error("خطا در اتصال به اینترنت. لطفاً دوباره تلاش کنید.")
        }
    }

    private func extractErrorMessage(_ rawBody: String?) -> String {
        guard let rawBody, !rawBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = rawBody.data(using: .utf8),
              let message = (try? ShkJSON.decoder.decode(ApiErrorResponse.self, from: data))?.message
        else { return "خطایی رخ داد. لطفاً دوباره تلاش کنید." }
        return message
    }
}
