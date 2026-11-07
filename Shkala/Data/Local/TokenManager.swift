import Foundation
import Security

/// معادل TokenManager اپ اندروید (data/local/TokenManager.kt): توکن ورود و نوع کاربر.
///
/// تفاوت اجباری سیستم‌عامل: در iOS جای امن نگه‌داری توکن «کی‌چین» است. کی‌چین برخلاف
/// DataStore اندروید با حذف اپ پاک نمی‌شه؛ برای اینکه رفتار دقیقاً مثل اندروید بمونه
/// (حذف و نصب دوباره = خروج از حساب)، در اولین اجرای هر نصب کی‌چین پاک می‌شه.
final class TokenManager: ObservableObject {
    static let shared = TokenManager()

    private enum Keys {
        static let TOKEN = "auth_token"
        static let USER_TYPE = "user_type" // user / owner / ...
        static let INSTALL_MARKER = "shkala_prefs.keychain_install_marker"
    }

    private let service = "com.shkala.app.session"
    private let lock = NSLock()

    /// معادل tokenFlow / userTypeFlow
    @Published private(set) var token: String?
    @Published private(set) var userType: String?

    private init() {
        if !UserDefaults.standard.bool(forKey: Keys.INSTALL_MARKER) {
            // نصب تازه: باقی‌مانده‌ی نصب قبلی در کی‌چین پاک می‌شه
            Self.keychainDelete(service: service, account: Keys.TOKEN)
            Self.keychainDelete(service: service, account: Keys.USER_TYPE)
            UserDefaults.standard.set(true, forKey: Keys.INSTALL_MARKER)
        }
        storedToken = Self.keychainRead(service: service, account: Keys.TOKEN)
        token = storedToken
        userType = Self.keychainRead(service: service, account: Keys.USER_TYPE)
    }

    /// مقدار فعلی توکن (هم‌زمان؛ برای هدر Authorization همه‌ی درخواست‌ها)
    func getTokenOnce() -> String? {
        lock.lock(); defer { lock.unlock() }
        return storedToken
    }

    private var storedToken: String?

    func saveSession(token: String, userType: String) {
        lock.lock()
        Self.keychainWrite(service: service, account: Keys.TOKEN, value: token)
        Self.keychainWrite(service: service, account: Keys.USER_TYPE, value: userType)
        storedToken = token
        lock.unlock()
        publish(token: token, userType: userType)
    }

    func clearSession() {
        lock.lock()
        Self.keychainDelete(service: service, account: Keys.TOKEN)
        Self.keychainDelete(service: service, account: Keys.USER_TYPE)
        storedToken = nil
        lock.unlock()
        publish(token: nil, userType: nil)
    }

    private func publish(token: String?, userType: String?) {
        let apply = { [weak self] in
            self?.token = token
            self?.userType = userType
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    // MARK: - کی‌چین

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private static func keychainRead(service: String, account: String) -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainWrite(service: String, account: String, value: String) {
        let data = Data(value.utf8)
        let query = baseQuery(service: service, account: account)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    private static func keychainDelete(service: String, account: String) {
        SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
    }
}
