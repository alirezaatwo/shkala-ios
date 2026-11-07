import Foundation

// ===================================================================================
// معادل RetrofitClient + AuthInterceptor اپ اندروید (data/remote/RetrofitClient.kt):
//  - هر درخواستی که به سرور می‌ره، اگه توکن ذخیره‌شده‌ای وجود داشته باشه، خودکار هدر
//    Authorization: Bearer <token> رو بهش اضافه می‌کنه
//  - Accept: application/json در همه‌ی درخواست‌ها
//  - شناسه‌ی نصب اپ (X-Shk-Install) در همه‌ی درخواست‌ها، اگه خودِ درخواست این هدر رو نداشته باشه
//  - همان تایم‌اوت‌ها: اتصال ۳۰ ثانیه، خواندن/نوشتن ۶۰ ثانیه
//  - رمزگشایی JSON مثل Gson اپ اندروید تحمل‌پذیره: آرایه‌ی خالیِ PHP ([]) به‌جای شیء = null
// ===================================================================================

enum ApiConstants {
    /// آدرس سایت (با اسلش انتهایی) - همان BASE_URL اپ اندروید
    static let BASE_URL = "https://shkala.com/"
}

/// معادل retrofit2.Response: کد HTTP، بدنه‌ی رمزگشایی‌شده (فقط در پاسخ موفق ۲xx) و بدنه‌ی خطا
struct ApiResponse<T> {
    let code: Int
    let body: T?
    let errorBody: Data?

    var isSuccessful: Bool { (200..<300).contains(code) }

    /// متن بدنه‌ی خطا (معادل errorBody()?.string())
    var errorBodyString: String? { errorBody.flatMap { String(data: $0, encoding: .utf8) } }
}

enum HttpMethod: String {
    case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
}

/// درخواست‌ها با JSON بدنه (مثل GsonConverterFactory)
final class ApiClient {
    static let shared = ApiClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        // معادل connectTimeout(30) / readTimeout(60) / writeTimeout(60) اوکی‌اچ‌تی‌تی‌پی
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    /// ساخت درخواست با هدرهای AuthInterceptor
    func makeRequest(
        _ method: HttpMethod,
        _ path: String,
        query: [String: String?] = [:],
        jsonBody: Data? = nil,
        headers: [String: String?] = [:]
    ) -> URLRequest {
        var components = URLComponents(string: ApiConstants.BASE_URL + path)!
        let items = query.compactMap { key, value in value.map { URLQueryItem(name: key, value: $0) } }
        if !items.isEmpty { components.queryItems = (components.queryItems ?? []) + items.sorted { $0.name < $1.name } }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method.rawValue
        request.timeoutInterval = 60

        // هدرهای خودِ درخواست (مثل getAppStatus) - null = ارسال نمی‌شه (مثل @Header با مقدار null)
        for (key, value) in headers {
            if let value { request.setValue(value, forHTTPHeaderField: key) }
        }
        if let token = TokenManager.shared.getTokenOnce(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // شناسه‌ی نصب اپ در همه‌ی درخواست‌ها (مثلاً برای نسبت دادن سفارش به اعلانی که کاربر روش زده)
        if let installId = AppMetaPreferenceManager.cachedInstallId, !installId.isEmpty,
           request.value(forHTTPHeaderField: "X-Shk-Install") == nil {
            request.setValue(installId, forHTTPHeaderField: "X-Shk-Install")
        }
        // فقط اضافه (سرور فعلی نادیده‌اش می‌گیره): سرور بتونه درخواست اپ iOS رو از اندروید تشخیص بده
        request.setValue("ios", forHTTPHeaderField: "X-Shk-Platform")
        if let jsonBody {
            request.httpBody = jsonBody
            request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    /// اجرای درخواست؛ خطای شبکه یا JSON نامعتبرِ پاسخ موفق = throw (مثل Retrofit)
    func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> ApiResponse<T> {
        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if (200..<300).contains(code) {
            let body = try ShkJSON.decoder.decode(T.self, from: data)
            return ApiResponse(code: code, body: body, errorBody: nil)
        }
        return ApiResponse(code: code, body: nil, errorBody: data)
    }

    func call<T: Decodable>(
        _ method: HttpMethod,
        _ path: String,
        query: [String: String?] = [:],
        body: (any Encodable)? = nil,
        headers: [String: String?] = [:],
        as type: T.Type
    ) async throws -> ApiResponse<T> {
        let data = try body.map { try ShkJSON.encoder.encode(AnyEncodable($0)) }
        let request = makeRequest(method, path, query: query, jsonBody: data, headers: headers)
        return try await send(request, as: type)
    }
}

/// بسته‌بندی Encodable برای ارسال بدنه‌ی دلخواه
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ value: any Encodable) { encodeFunc = value.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}

enum ShkJSON {
    static let decoder = JSONDecoder()
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()
}

// MARK: - تحمل‌پذیری مثل Gson

/// همه‌ی DTOهای اپ این پروتکل رو دارن (معادل پکیج dto اندروید): اگه سرور به‌جای شیء، آرایه
/// فرستاد (معمولاً [] خالیِ PHP)، اون فیلد null در نظر گرفته می‌شه تا کل پاسخ رد نشه
/// (EmptyPhpArrayAsNullFactory اپ اندروید).
protocol ShkDTO: Decodable {}

extension KeyedDecodingContainer {
    func decodeIfPresent<T: ShkDTO>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard contains(key) else { return nil }
        if (try? decodeNil(forKey: key)) == true { return nil }
        if (try? nestedUnkeyedContainer(forKey: key)) != nil { return nil }
        // مثل Gson برای SocialDto: مقدار غیرشیء (مثلاً false) = null
        guard (try? nestedContainer(keyedBy: AnyCodingKey.self, forKey: key)) != nil else { return nil }
        return try decode(T.self, forKey: key)
    }
}

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; intValue = nil }
    init?(intValue: Int) { stringValue = String(intValue); self.intValue = intValue }
}

/// مقدار عددی/رشته‌ای منعطف: Gson رشته‌ی عددی ("12") رو در فیلد عددی و عدد رو در فیلد رشته‌ای
/// می‌پذیره؛ این کمکی‌ها همون رفتار رو برای فیلدهایی که لازمه شبیه‌سازی می‌کنن.
extension KeyedDecodingContainer {
    func lenientString(_ key: Key) -> String? {
        if let v = try? decodeIfPresent(String.self, forKey: key) { return v }
        if let v = try? decodeIfPresent(Int64.self, forKey: key) { return String(v) }
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return String(v) }
        if let v = try? decodeIfPresent(Bool.self, forKey: key) { return v ? "true" : "false" }
        return nil
    }

    func lenientInt(_ key: Key) -> Int? {
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return v }
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return Int(v) }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Int(s.trimmingCharacters(in: .whitespaces)) ?? Double(s).map { Int($0) } }
        return nil
    }

    func lenientInt64(_ key: Key) -> Int64? {
        if let v = try? decodeIfPresent(Int64.self, forKey: key) { return v }
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return Int64(v) }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Int64(s.trimmingCharacters(in: .whitespaces)) ?? Double(s).map { Int64($0) } }
        return nil
    }

    func lenientBool(_ key: Key) -> Bool? {
        if let v = try? decodeIfPresent(Bool.self, forKey: key) { return v }
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return v != 0 }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return s == "true" || s == "1" }
        return nil
    }
}

/// معادل sealed class ApiResult اپ اندروید
enum ApiResult<T> {
    case success(T)
    case error(String)
}
