import Foundation

// معادل AccountFeaturesRepository.kt (CommentRepository / ProfileRepository / SessionRepository) +
// FavoriteRepository.kt + بخش فهرستیِ PrefactorRepository.kt و TicketRepository.kt اپ اندروید - همان پیام‌های خطا

private let NETWORK_ERROR = "خطا در اتصال به اینترنت."

struct CommentRepository {
    func getMyComments(search: String? = nil) async -> ApiResult<[UserCommentDto]> {
        do {
            let r = try await ApiService.getMyComments(search: search)
            if r.isSuccessful, let body = r.body { return .success(body.comments) }
            return .error("دریافت دیدگاه‌ها با خطا مواجه شد.")
        } catch {
            return .error(NETWORK_ERROR)
        }
    }
}

struct ProfileRepository {
    func getProfile() async -> ApiResult<ProfileEditResponse> {
        do {
            let r = try await ApiService.getProfile()
            if r.isSuccessful, let body = r.body { return .success(body) }
            return .error("دریافت اطلاعات حساب با خطا مواجه شد.")
        } catch {
            return .error(NETWORK_ERROR)
        }
    }

    /// avatar = (بایت‌های JPEG/PNG, نام فایل, نوع) - اختیاری
    func updateProfile(
        name: String,
        email: String?,
        username: String?,
        nationalNumber: String?,
        bio: String?,
        gender: String?,
        jalaliBirthday: String?,
        instagram: String?,
        telegram: String?,
        twitter: String?,
        facebook: String?,
        avatar: (data: Data, fileName: String, mimeType: String)?
    ) async -> ApiResult<String> {
        do {
            var parts: [MultipartPart] = [
                .text("name", name),
                .text("email", email ?? ""),
                .text("username", username ?? ""),
                .text("national_number", nationalNumber ?? ""),
                .text("bio", bio ?? ""),
                .text("gender", gender ?? ""),
                .text("birthday", jalaliBirthday ?? ""),
                .text("social[instagram]", instagram ?? ""),
                .text("social[telegram]", telegram ?? ""),
                .text("social[twitter]", twitter ?? ""),
                .text("social[facebook]", facebook ?? ""),
            ]
            if let avatar {
                parts.append(MultipartPart(name: "avatar", data: avatar.data, fileName: avatar.fileName, mimeType: avatar.mimeType))
            }
            let r = try await ApiService.updateProfile(parts: parts)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.message ?? "به‌روزرسانی شد.") }
            return .error(r.body?.message ?? "به‌روزرسانی با خطا مواجه شد.")
        } catch {
            return .error(NETWORK_ERROR)
        }
    }

    func changePassword(current: String?, new: String, newConfirmation: String) async -> ApiResult<String> {
        do {
            let r = try await ApiService.changePassword(current: current, new: new, newConfirmation: newConfirmation)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.message ?? "رمز عبور تغییر کرد.") }
            return .error(r.body?.message ?? "تغییر رمز عبور با خطا مواجه شد.")
        } catch {
            return .error(NETWORK_ERROR)
        }
    }
}

struct SessionRepository {
    func getSessions() async -> ApiResult<(sessions: [SessionDto], currentSessionId: Int?)> {
        do {
            let r = try await ApiService.getSessions()
            if r.isSuccessful, let body = r.body { return .success((body.sessions, body.currentSessionId)) }
            return .error("دریافت نشست‌ها با خطا مواجه شد.")
        } catch {
            return .error(NETWORK_ERROR)
        }
    }

    func terminate(_ id: Int) async -> ApiResult<Bool> {
        do {
            let r = try await ApiService.terminateSession(id)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.wasCurrent ?? false) }
            return .error(r.body?.message ?? "پایان نشست با خطا مواجه شد.")
        } catch {
            return .error(NETWORK_ERROR)
        }
    }
}

extension FavoriteRepository {
    func getFavorites(search: String? = nil) async -> ApiResult<[FavoriteDto]> {
        do {
            let r = try await ApiService.getFavorites(search: search)
            if r.isSuccessful, let body = r.body { return .success(body.favorites) }
            return .error("دریافت علاقه‌مندی‌ها با خطا مواجه شد.")
        } catch {
            return .error(NETWORK_ERROR)
        }
    }
}

struct PrefactorRepository {
    func getPrefactors(search: String? = nil, paid: Bool? = nil, waitingPayment: Bool? = nil) async -> ApiResult<[PrefactorDto]> {
        do {
            let r = try await ApiService.getPrefactors(search: search, paid: paid, waitingPayment: waitingPayment)
            if r.isSuccessful, let body = r.body { return .success(body.prefactors) }
            return .error("دریافت پیش‌فاکتورها با خطا مواجه شد.")
        } catch {
            return .error(NETWORK_ERROR)
        }
    }
}

struct TicketRepository {
    func getTickets(search: String? = nil, waitingAdmin: Bool? = nil, waitingUser: Bool? = nil, closed: Bool? = nil) async -> ApiResult<[TicketDto]> {
        do {
            let r = try await ApiService.getTickets(search: search, waitingAdmin: waitingAdmin, waitingUser: waitingUser, closed: closed)
            if r.isSuccessful, let body = r.body { return .success(body.tickets) }
            return .error("دریافت تیکت‌ها با خطا مواجه شد.")
        } catch {
            return .error(NETWORK_ERROR)
        }
    }
}
