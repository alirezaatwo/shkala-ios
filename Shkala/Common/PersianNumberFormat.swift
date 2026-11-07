import Foundation

// معادل PersianNumberFormat.kt اپ اندروید

private let persianDigits: [Character] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

extension String {
    /// تبدیل عددهای انگلیسی به فارسی - فقط برای نمایش (نه مقادیری که به سرور می‌رن)
    func toPersianDigits() -> String {
        var out = ""
        out.reserveCapacity(count)
        for ch in self {
            if let d = ch.wholeNumberValue, ch.isASCII {
                out.append(persianDigits[d])
            } else {
                out.append(ch)
            }
        }
        return out
    }
}

extension Int {
    func toPersianDigits() -> String { String(self).toPersianDigits() }
}

extension Int64 {
    func toPersianDigits() -> String { String(self).toPersianDigits() }
}

/// قیمت با جداکننده‌ی هزارگان و اعداد فارسی، مثلاً: ۱۲۰٬۰۰۰ (معادل "%,d" اندروید)
func formatTomanFa(_ amount: Int64) -> String {
    let negative = amount < 0
    var digits = String(abs(amount))
    var groups: [String] = []
    while digits.count > 3 {
        groups.insert(String(digits.suffix(3)), at: 0)
        digits.removeLast(3)
    }
    groups.insert(digits, at: 0)
    return ((negative ? "-" : "") + groups.joined(separator: ",")).toPersianDigits()
}
