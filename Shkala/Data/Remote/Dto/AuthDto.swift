import Foundation

// معادل dto/AuthDto.kt اپ اندروید

// ---- درخواست‌ها (Request) ----

struct SendCodeRequest: Encodable {
    let phone: String
}

struct VerifyCodeRequest: Encodable {
    let phone: String
    let code: String
}

struct PasswordLoginRequest: Encodable {
    let phone: String
    let password: String
}

// ---- پاسخ‌ها (Response) ----

struct SendCodeResponse: ShkDTO {
    let status: String? // "sent" یا "pending"
    let message: String?
    let phone: String?
    let remainingSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case status, message, phone
        case remainingSeconds = "remaining_seconds"
    }
}

struct VerifyCodeResponse: ShkDTO {
    let status: String?
    let token: String?
    let needsProfileCompletion: Bool?
    let user: UserDto?

    enum CodingKeys: String, CodingKey {
        case status, token, user
        case needsProfileCompletion = "needs_profile_completion"
    }
}

struct MeResponse: ShkDTO {
    let status: String?
    let user: UserDto?
}

struct UserDto: ShkDTO {
    let id: Int
    let username: String?
    let name: String?
    let phone: String
    let type: String // "user" / "owner" / ... تعیین می‌کنه کدوم پنل نشون داده بشه
    let withPassword: Bool

    enum CodingKeys: String, CodingKey {
        case id, username, name, phone, type
        case withPassword = "with_password"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        username = c.lenientString(.username)
        name = c.lenientString(.name)
        phone = c.lenientString(.phone) ?? ""
        type = c.lenientString(.type) ?? ""
        withPassword = c.lenientBool(.withPassword) ?? false
    }
}

/// پاسخ خطای عمومی که سرور برمی‌گردونه، برای نمایش پیام دقیق به کاربر
struct ApiErrorResponse: ShkDTO {
    let status: String?
    let message: String?
}
