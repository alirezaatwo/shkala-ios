import SwiftUI
import UIKit

// فونت یکان (IRANYekanX با اعداد فارسی) - همان دو فایل اپ اندروید (Regular و Bold).
// مثل اندروید وزن‌های Medium به Regular و SemiBold به Bold نگاشت می‌شوند.
// اندازه‌ها بر حسب sp اندروید هستند و در iOS همان عدد به pt استفاده می‌شود (1sp ≈ 1pt).

enum ShkWeight {
    case normal, medium, semiBold, bold

    var postScriptName: String {
        switch self {
        case .normal, .medium: return "IRANYekanXFaNum-Regular"
        case .semiBold, .bold: return "IRANYekanXFaNum-Bold"
        }
    }
}

enum ShkFont {
    /// فونت یکان با اندازه‌ی sp اندروید (با بزرگ‌نمایی متن سیستم بزرگ می‌شود؛ مثل sp)
    static func yekan(_ size: CGFloat, _ weight: ShkWeight = .normal) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    static func uiYekan(_ size: CGFloat, _ weight: ShkWeight = .normal) -> UIFont {
        UIFont(name: weight.postScriptName, size: size) ?? .systemFont(ofSize: size)
    }
}

/// سبک‌های متنی معادل ShkalaTypography اپ اندروید (ui/theme/Type.kt)
struct ShkTextStyle {
    let size: CGFloat
    let weight: ShkWeight
    let lineHeight: CGFloat

    static let displayLarge = ShkTextStyle(size: 32, weight: .bold, lineHeight: 40)
    static let displayMedium = ShkTextStyle(size: 28, weight: .bold, lineHeight: 36)
    static let displaySmall = ShkTextStyle(size: 24, weight: .bold, lineHeight: 32)
    static let headlineLarge = ShkTextStyle(size: 24, weight: .bold, lineHeight: 32)
    static let headlineMedium = ShkTextStyle(size: 20, weight: .semiBold, lineHeight: 28)
    static let headlineSmall = ShkTextStyle(size: 18, weight: .semiBold, lineHeight: 26)
    static let titleLarge = ShkTextStyle(size: 18, weight: .semiBold, lineHeight: 26)
    static let titleMedium = ShkTextStyle(size: 16, weight: .medium, lineHeight: 24)
    static let titleSmall = ShkTextStyle(size: 14, weight: .medium, lineHeight: 20)
    static let bodyLarge = ShkTextStyle(size: 16, weight: .normal, lineHeight: 24)
    static let bodyMedium = ShkTextStyle(size: 14, weight: .normal, lineHeight: 22)
    static let bodySmall = ShkTextStyle(size: 12, weight: .normal, lineHeight: 18)
    static let labelLarge = ShkTextStyle(size: 14, weight: .medium, lineHeight: 20)
    static let labelMedium = ShkTextStyle(size: 12, weight: .medium, lineHeight: 16)
    static let labelSmall = ShkTextStyle(size: 11, weight: .medium, lineHeight: 14)
}

extension View {
    /// متن با فونت یکان، اندازه و ارتفاع خط اندروید (lineHeight بر حسب sp).
    /// اگر lineHeight داده نشود، ارتفاع خط پیش‌فرض خود فونت استفاده می‌شود (مثل اندروید).
    func shkFont(_ size: CGFloat, _ weight: ShkWeight = .normal, lineHeight: CGFloat? = nil) -> some View {
        let natural = ShkFont.uiYekan(size, weight).lineHeight
        let spacing = lineHeight.map { max(0, $0 - natural) } ?? 0
        return self
            .font(ShkFont.yekan(size, weight))
            .lineSpacing(spacing)
    }

    func shkFont(_ style: ShkTextStyle) -> some View {
        shkFont(style.size, style.weight, lineHeight: style.lineHeight)
    }
}
