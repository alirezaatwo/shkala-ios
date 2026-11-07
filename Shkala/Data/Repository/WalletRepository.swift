import Foundation

// معادل data/WalletRepository.kt

struct WalletRepository {
    private let NETWORK_ERROR = "خطا در اتصال به اینترنت."

    func getWalletInfo() async -> ApiResult<WalletInfoResponse> {
        do {
            let r = try await ApiService.getWalletInfo()
            if r.isSuccessful, let body = r.body { return .success(body) }
            return .error("دریافت اطلاعات کیف پول با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func chargeWallet(amount: Int64, paymentGateway: String) async -> ApiResult<WalletChargeResponse> {
        do {
            let r = try await ApiService.chargeWallet(amount: amount, paymentGateway: paymentGateway)
            if r.isSuccessful, let body = r.body, body.action != nil { return .success(body) }
            return .error(r.body?.message ?? "اتصال به درگاه با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func addWithdrawal(amount: Int64, bankCardId: Int) async -> ApiResult<String> {
        do {
            let r = try await ApiService.addWithdrawal(amount: amount, bankCardId: bankCardId)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.message ?? "درخواست ثبت شد.") }
            return .error(r.body?.message ?? "ثبت درخواست برداشت با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func deleteWithdrawal(_ id: Int) async -> ApiResult<String> {
        do {
            let r = try await ApiService.deleteWithdrawal(id)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.message ?? "لغو شد.") }
            return .error(r.body?.message ?? "لغو درخواست با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func addBankCard(name: String, cardNumber: String, shebaNumber: String) async -> ApiResult<AddBankCardResponse> {
        do {
            let r = try await ApiService.addBankCard(name: name, cardNumber: cardNumber, shebaNumber: shebaNumber)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body) }
            return .error(r.body?.message ?? "ثبت کارت با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func updateBankCard(id: Int, name: String, cardNumber: String, shebaNumber: String) async -> ApiResult<AddBankCardResponse> {
        do {
            let r = try await ApiService.updateBankCard(id: id, name: name, cardNumber: cardNumber, shebaNumber: shebaNumber)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body) }
            // پیام خطای سرور (۴۲۲/۴۰۳) از بدنه‌ی خطا خونده می‌شه
            let errorMessage = r.errorBody.flatMap { try? JSONDecoder().decode(SimpleStatusResponse.self, from: $0) }?.message
            return .error(r.body?.message ?? errorMessage ?? "ویرایش کارت با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func deleteBankCard(_ id: Int) async -> ApiResult<String> {
        do {
            let r = try await ApiService.deleteBankCard(id)
            if r.isSuccessful, let body = r.body, body.status == "ok" { return .success(body.message ?? "حذف شد.") }
            return .error(r.body?.message ?? "حذف کارت با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }

    func getLastChargeTransaction() async -> ApiResult<LastChargeTransactionResponse> {
        do {
            let r = try await ApiService.getLastChargeTransaction()
            if r.isSuccessful, let body = r.body { return .success(body) }
            return .error("دریافت اطلاعات تراکنش با خطا مواجه شد.")
        } catch { return .error(NETWORK_ERROR) }
    }
}

/// معادل WalletFlowViewModel اندروید (ViewModel مشترک در سطح Activity)
final class WalletFlowState: ObservableObject {
    static let shared = WalletFlowState()
    @Published var pendingCharge: WalletChargeResponse? = nil
    @Published var lastChargeSuccessful = false
    // کارت بانکی‌ای که برای ویرایش باز شده (صفحه‌ی افزودن کارت در حالت ویرایش)
    @Published var editingCard: BankCardDto? = nil
}
