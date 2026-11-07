import Foundation

/** معادل data/ToolsRepository.kt - ابزارهای کاربردی: فهرست ابزارها، پیکربندی ماشین‌حساب هارد و هاردهای پیشنهادی */
struct ToolsRepository {

    func getTools() async -> ApiResult<ToolsResponse> { await call { try await ApiService.getTools() } }

    func getHddCalculator() async -> ApiResult<HddToolResponse> { await call { try await ApiService.getHddCalculator() } }

    func getHddProducts(tb: Double) async -> ApiResult<HddProductsResponse> { await call { try await ApiService.getHddProducts(tb: tb) } }

    private func call<T: Decodable>(_ block: () async throws -> ApiResponse<T>) async -> ApiResult<T> {
        do {
            let response = try await block()
            if response.isSuccessful, let body = response.body { return .success(body) }
            return .error("دریافت اطلاعات با خطا مواجه شد.")
        } catch is URLError {
            return .error("خطا در اتصال به اینترنت.")
        } catch {
            return .error("دریافت اطلاعات با خطا مواجه شد.")
        }
    }
}
