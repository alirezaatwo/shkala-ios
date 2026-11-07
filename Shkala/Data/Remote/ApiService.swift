import Foundation

/// معادل ApiService اپ اندروید (data/remote/ApiService.kt) - همان مسیرها.
/// هر مرحله فقط اندپوینت‌هایی که لازم داره اضافه می‌کنه.
enum ApiService {
    private static var api: ApiClient { .shared }

    // ---- ورود ----

    static func sendCode(_ body: SendCodeRequest) async throws -> ApiResponse<SendCodeResponse> {
        try await api.call(.post, "api/v2/auth/send-code", body: body, as: SendCodeResponse.self)
    }

    static func verifyCode(_ body: VerifyCodeRequest) async throws -> ApiResponse<VerifyCodeResponse> {
        try await api.call(.post, "api/v2/auth/verify-code", body: body, as: VerifyCodeResponse.self)
    }

    static func loginWithPassword(_ body: PasswordLoginRequest) async throws -> ApiResponse<VerifyCodeResponse> {
        try await api.call(.post, "api/v2/auth/login-password", body: body, as: VerifyCodeResponse.self)
    }

    static func me() async throws -> ApiResponse<MeResponse> {
        try await api.call(.get, "api/v2/auth/me", as: MeResponse.self)
    }

    // ---- اطلاعات سایت ----

    static func getSiteInfo() async throws -> ApiResponse<SiteInfoResponse> {
        try await api.call(.get, "api/v2/site-info", as: SiteInfoResponse.self)
    }

    // ---- وضعیت اپ ----

    /// شناسه‌ی نصب و نسخه‌ی اپ برای آمار لایو «کاربران آنلاین» در پنل (null = هدر ارسال نمی‌شه)
    static func getAppStatus(installId: String?, appVersion: String?) async throws -> ApiResponse<AppStatusResponse> {
        try await api.call(
            .get, "api/v2/app/status",
            headers: ["X-Shk-Install": installId, "X-Shk-Version": appVersion],
            as: AppStatusResponse.self
        )
    }
}

/// معادل currentAppVersionName اپ اندروید: نسخه‌ی نمایشی اپ (CFBundleShortVersionString)
func currentAppVersionName() -> String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
}
