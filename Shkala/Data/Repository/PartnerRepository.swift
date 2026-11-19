import Foundation
import UIKit

// ===================================================================================
// معادل data/PartnerRepository.kt اپ اندروید - همان پیام‌های خطا
// ===================================================================================

/// نتیجه‌ی هر عملیات «همکار شوید»: پیام سرور + وضعیت تازه (در خطای ۴۲۲ هم وضعیت می‌آید)
struct PartnerOutcome {
    let ok: Bool
    let message: String?
    let state: PartnerStateDto?
}

/// فایل انتخاب‌شده برای بارگذاری: عکس (بایت‌های خام) یا PDF
enum PartnerPickedFile {
    case image(Data)
    case pdf(Data)
}

struct PartnerRepository {
    private static let NETWORK_ERROR = "خطا در اتصال به اینترنت."
    private static let GENERIC_ERROR = "خطایی رخ داد. لطفاً دوباره تلاش کنید."
    private static let MAX_SIDE: CGFloat = 2000

    func status() async -> ApiResult<PartnerOutcome> {
        if let sample = ScreenshotPartnerSamples.state() { return .success(PartnerOutcome(ok: true, message: nil, state: sample)) }
        return await call { try await ApiService.partnerStatus() }
    }

    func deleteFile(_ kind: String) async -> ApiResult<PartnerOutcome> { await call { try await ApiService.partnerDeleteFile(kind) } }

    func checkBale() async -> ApiResult<PartnerOutcome> { await call { try await ApiService.partnerCheckBale() } }

    func submit() async -> ApiResult<PartnerOutcome> { await call { try await ApiService.partnerSubmit() } }

    /// بارگذاری مدرک: عکس‌ها قبل از ارسال کوچک و JPEG می‌شوند (ضلع بلند حداکثر ۲۰۰۰)، PDF همان‌طور ارسال می‌شود
    func upload(kind: String, file: PartnerPickedFile) async -> ApiResult<PartnerOutcome> {
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let part: MultipartPart
        switch file {
        case .pdf(let data):
            part = MultipartPart(name: "file", data: data, fileName: "partner_\(stamp).pdf", mimeType: "application/pdf")
        case .image(let data):
            guard let jpeg = Self.prepareImage(data) else { return .error("خواندن فایل ممکن نشد؛ فایل دیگری انتخاب کنید.") }
            part = MultipartPart(name: "file", data: jpeg, fileName: "partner_\(stamp).jpg", mimeType: "image/jpeg")
        }
        return await call { try await ApiService.partnerUpload(parts: [.text("kind", kind), part]) }
    }

    func commissions(page: Int, search: String?) async -> ApiResult<PartnerCommissionsResponse> {
        if let sample = ScreenshotPartnerSamples.commissions() { return .success(sample) }
        do {
            let r = try await ApiService.partnerCommissions(page: page, search: search)
            if r.isSuccessful, let body = r.body { return .success(body) }
            return .error(Self.errorOf(r.errorBody)?.message ?? "دریافت پورسانت‌ها با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    private func call(_ block: () async throws -> ApiResponse<PartnerResponse>) async -> ApiResult<PartnerOutcome> {
        do {
            let r = try await block()
            if r.isSuccessful, let body = r.body {
                return .success(PartnerOutcome(ok: body.status == "ok", message: body.message, state: body.partner))
            }
            let error = Self.errorOf(r.errorBody)
            if let partner = error?.partner {
                // ۴۲۲ با وضعیت: پیام خطا نمایش داده می‌شود و صفحه با وضعیت تازه به‌روز می‌ماند
                return .success(PartnerOutcome(ok: false, message: error?.message ?? Self.GENERIC_ERROR, state: partner))
            }
            return .error(error?.message ?? Self.GENERIC_ERROR)
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    private static func errorOf(_ raw: Data?) -> PartnerResponse? {
        guard let raw, !raw.isEmpty else { return nil }
        return try? ShkJSON.decoder.decode(PartnerResponse.self, from: raw)
    }

    /// تبدیل عکس به JPEG با کیفیت ۸۵ و ضلع بلند حداکثر ۲۰۰۰ (جهت عکس دوربین با UIImage اعمال می‌شود)
    private static func prepareImage(_ data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let longSide = max(image.size.width, image.size.height)
        let scale = longSide > MAX_SIDE ? MAX_SIDE / longSide : 1
        let target = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }
}
