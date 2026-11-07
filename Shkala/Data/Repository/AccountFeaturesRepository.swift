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

// معادل باقی PrefactorRepository.kt (جزئیات، آدرس، روش ارسال، درگاه‌ها و پرداخت)
extension PrefactorRepository {
    func getPrefactorDetail(_ uuid: String) async -> ApiResult<PrefactorDetailResponse> {
        do {
            let r = try await ApiService.getPrefactorDetail(uuid)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body) }
            return .error(r.body?.message ?? "دریافت اطلاعات پیش‌فاکتور با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func selectAddress(_ uuid: String, addressId: Int) async -> ApiResult<String> {
        do {
            let r = try await ApiService.selectPrefactorAddress(uuid, addressId: addressId)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.message ?? "ثبت شد.") }
            return .error(r.body?.message ?? "ثبت آدرس با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    /** فاز ۳۱: انتخاب تحویل حضوری از یکی از شعبه‌ها برای همین پیش‌فاکتور */
    func selectShopAddress(_ uuid: String, receptionCenterId: String) async -> ApiResult<String> {
        do {
            let r = try await ApiService.selectPrefactorShopAddress(uuid, receptionCenterId: receptionCenterId)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.message ?? "ثبت شد.") }
            return .error(r.body?.message ?? "ثبت تحویل حضوری با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func selectShippingMethod(_ uuid: String, type: String, consignmentUuid: String, sendMethodUuid: String) async -> ApiResult<String> {
        do {
            let r = try await ApiService.selectPrefactorShippingMethod(uuid, type: type, consignmentUuid: consignmentUuid, sendMethodUuid: sendMethodUuid)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.message ?? "ثبت شد.") }
            return .error(r.body?.message ?? "ثبت روش ارسال با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func getGateways(_ uuid: String) async -> ApiResult<[PaymentGatewayDto]> {
        do {
            let r = try await ApiService.getPrefactorGateways(uuid)
            if r.isSuccessful, let body = r.body { return .success(body.gateways) }
            return .error("دریافت درگاه‌های پرداخت با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func pay(_ uuid: String, paymentGateway: String, description: String? = nil) async -> ApiResult<PrefactorPayResponse> {
        do {
            let r = try await ApiService.payPrefactor(uuid, paymentGateway: paymentGateway, description: description)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body) }
            return .error(r.body?.message ?? "پرداخت با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func payCardToCard(_ uuid: String, receipt: Data) async -> ApiResult<PrefactorPayResponse> {
        do {
            let part = MultipartPart(name: "receipt", data: receipt, fileName: "prefactor_receipt_\(Int64(Date().timeIntervalSince1970 * 1000)).jpg", mimeType: "image/*")
            let r = try await ApiService.payPrefactorCardToCard(uuid, parts: [part])
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body) }
            return .error(r.body?.message ?? "ثبت رسید با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
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

// معادل باقی TicketRepository.kt (سطوح اهمیت، ثبت، جزئیات، پاسخ و پیوست)
extension TicketRepository {
    func getPriorities() async -> ApiResult<[TicketPriorityDto]> {
        do {
            let r = try await ApiService.getTicketPriorities()
            if r.isSuccessful, let body = r.body { return .success(body.priorities) }
            return .error("دریافت سطوح اهمیت با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func createTicket(title: String, priority: String, content: String, attachment: Data?) async -> ApiResult<Int> {
        do {
            var parts: [MultipartPart] = [.text("title", title), .text("priority", priority), .text("content", content)]
            if let attachment {
                parts.append(MultipartPart(name: "attachment", data: attachment, fileName: "ticket_attachment_\(Int64(Date().timeIntervalSince1970 * 1000)).jpg", mimeType: "image/*"))
            }
            let r = try await ApiService.createTicket(parts: parts)
            if r.isSuccessful, let body = r.body, body.status == "ok", let id = body.ticketId { return .success(id) }
            return .error(r.body?.message ?? "ثبت تیکت با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func getTicketDetail(_ id: Int) async -> ApiResult<TicketDetailDto> {
        do {
            let r = try await ApiService.getTicketDetail(id)
            if r.isSuccessful, let ticket = r.body?.ticket { return .success(ticket) }
            return .error(r.body?.message ?? "دریافت جزئیات تیکت با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func answerTicket(_ id: Int, content: String) async -> ApiResult<String> {
        do {
            let r = try await ApiService.answerTicket(id, content: content)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.message ?? "ارسال شد.") }
            return .error(r.body?.message ?? "ارسال پاسخ با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func sendAttachment(_ id: Int, attachment: Data) async -> ApiResult<String> {
        do {
            let part = MultipartPart(name: "attachment", data: attachment, fileName: "ticket_reply_attachment_\(Int64(Date().timeIntervalSince1970 * 1000)).jpg", mimeType: "image/*")
            let r = try await ApiService.sendTicketAttachment(id, parts: [part])
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.message ?? "ارسال شد.") }
            return .error(r.body?.message ?? "ارسال پیوست با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }
}
