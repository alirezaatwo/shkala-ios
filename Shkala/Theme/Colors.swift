import SwiftUI

// ===================================================================================
// رنگ‌های اپ - عیناً همان مقادیر ui/theme/Color.kt اپ اندروید (که خودشان از تم فعال سایت
// گرفته شده‌اند). نام‌ها هم همان نام‌های اندروید هستند تا تطبیق دو اپ ساده باشد.
// ===================================================================================

extension Color {
    /// رنگ از کد هگز ARGB به سبک اندروید: Color(argb: 0xFFE60012)
    init(argb: UInt32) {
        let a = Double((argb >> 24) & 0xFF) / 255
        let r = Double((argb >> 16) & 0xFF) / 255
        let g = Double((argb >> 8) & 0xFF) / 255
        let b = Double(argb & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum ShkColors {
    // ----- رنگ برند (از تنظیمات قالب فعال سایت) -----
    static let SiteMainColor = Color(argb: 0xFFE60012)
    static let SiteSecondaryColor = Color(argb: 0xFFE60012)

    // ----- حالت روشن (body#light سایت) -----
    static let LightBackground = Color(argb: 0xFFF7F8FA)
    static let LightBox = Color(argb: 0xFFFFFFFF)
    static let LightFill = Color(argb: 0xFFF3F5F7)
    static let LightText = Color(argb: 0xFF1C1C25)
    static let LightTextSecondary = Color(argb: 0xFF6B778A)
    static let LightTextMuted = Color(argb: 0xFF8F9BAD)
    static let LightBorder = Color(argb: 0xFFDDE2E7)
    static let LightBorderSoft = Color(argb: 0xFFEFEFEF)

    // ----- حالت تاریک (#dark سایت) -----
    static let DarkBackground = Color(argb: 0xFF262631)
    static let DarkBox = Color(argb: 0xFF353542)
    static let DarkFill = Color(argb: 0xFF414150)
    static let DarkElevated = Color(argb: 0xFF4A4A5C)
    static let DarkDeepest = Color(argb: 0xFF1C1C25)
    static let DarkText = Color(argb: 0xFFFFFFFF)
    static let DarkTextSecondary = Color(argb: 0xFFBBBBBB)
    static let DarkBorder = Color(argb: 0xFF4A4A5C)
    static let DarkBorderSoft = Color(argb: 0xFF414150)

    // ----- رنگ‌های وضعیتی سایت -----
    static let SiteDanger = Color(argb: 0xFFFA4248)
    static let SiteSuccess = Color(argb: 0xFF1ABC9C)
    static let SiteSuccessDark = Color(argb: 0xFF16A085)
    static let SiteWarning = Color(argb: 0xFFF0BB40)
    static let SiteInfo = Color(argb: 0xFF3ECAF6)

    // ----- هدر و نوار پایین -----
    static let LightSearchField = Color(argb: 0xFFEBEEF3)
    static let DarkSearchField = Color(argb: 0xFF353542)
    static let LightSearchFieldText = Color(argb: 0xFF74777C)
    static let LightSearchChip = Color(argb: 0xFFFFFFFF)
    static let DarkSearchChip = Color(argb: 0xFF262631)
    static let LightHeaderDashedDivider = Color(argb: 0xFFD7DDE4)
    static let DarkHeaderDashedDivider = Color(argb: 0xFF353542)
    static let LightNavDashedBorder = Color(argb: 0xFFDFE3E9)
    static let DarkNavDashedBorder = Color(argb: 0xFF353542)
    static let LightNavInactive = Color(argb: 0xFF999999)
    static let DarkNavInactive = Color(argb: 0xFFBBBBBB)
    static let LightHeaderIcon = Color(argb: 0xFF1C1C25)

    // ----- پس‌زمینه‌ی ملایم رنگ برند -----
    static let LightPrimaryContainer = Color(argb: 0xFFFCE6E7)
    static let DarkPrimaryContainer = Color(argb: 0xFF552B39)
}

/// معادل ColorScheme متریال اپ اندروید (ui/theme/Theme.kt) - همان نقش‌ها و همان مقادیر.
struct ShkColorScheme {
    let primary: Color
    let onPrimary: Color
    let primaryContainer: Color
    let onPrimaryContainer: Color
    let secondary: Color
    let onSecondary: Color
    let tertiary: Color
    let onTertiary: Color
    let background: Color
    let onBackground: Color
    let surface: Color
    let onSurface: Color
    let surfaceVariant: Color
    let onSurfaceVariant: Color
    let surfaceContainerLowest: Color
    let surfaceContainerLow: Color
    let surfaceContainer: Color
    let surfaceContainerHigh: Color
    let surfaceContainerHighest: Color
    let inverseSurface: Color
    let inverseOnSurface: Color
    let outline: Color
    let outlineVariant: Color
    let error: Color
    let onError: Color
    let errorContainer: Color
    let onErrorContainer: Color
    let scrim: Color

    static let light = ShkColorScheme(
        primary: ShkColors.SiteMainColor,
        onPrimary: .white,
        primaryContainer: ShkColors.LightPrimaryContainer,
        onPrimaryContainer: ShkColors.SiteMainColor,
        secondary: ShkColors.SiteSecondaryColor,
        onSecondary: .white,
        tertiary: ShkColors.SiteSuccess,
        onTertiary: .white,
        background: ShkColors.LightBackground,
        onBackground: ShkColors.LightText,
        surface: ShkColors.LightBox,
        onSurface: ShkColors.LightText,
        surfaceVariant: ShkColors.LightFill,
        onSurfaceVariant: ShkColors.LightTextSecondary,
        surfaceContainerLowest: ShkColors.LightBox,
        surfaceContainerLow: ShkColors.LightBox,
        surfaceContainer: ShkColors.LightBox,
        surfaceContainerHigh: ShkColors.LightBox,
        surfaceContainerHighest: ShkColors.LightFill,
        inverseSurface: ShkColors.LightText,
        inverseOnSurface: .white,
        outline: ShkColors.LightBorder,
        outlineVariant: ShkColors.LightBorderSoft,
        error: ShkColors.SiteDanger,
        onError: .white,
        errorContainer: Color(argb: 0xFFFFE5E6),
        onErrorContainer: ShkColors.SiteDanger,
        scrim: .black
    )

    static let dark = ShkColorScheme(
        primary: ShkColors.SiteMainColor,
        onPrimary: .white,
        primaryContainer: ShkColors.DarkPrimaryContainer,
        onPrimaryContainer: .white,
        secondary: ShkColors.SiteSecondaryColor,
        onSecondary: .white,
        tertiary: ShkColors.SiteSuccess,
        onTertiary: .white,
        background: ShkColors.DarkBackground,
        onBackground: ShkColors.DarkText,
        surface: ShkColors.DarkBox,
        onSurface: ShkColors.DarkText,
        surfaceVariant: ShkColors.DarkFill,
        onSurfaceVariant: ShkColors.DarkTextSecondary,
        surfaceContainerLowest: ShkColors.DarkDeepest,
        surfaceContainerLow: ShkColors.DarkBackground,
        surfaceContainer: ShkColors.DarkBox,
        surfaceContainerHigh: ShkColors.DarkBackground,
        surfaceContainerHighest: ShkColors.DarkFill,
        inverseSurface: .white,
        inverseOnSurface: ShkColors.LightText,
        outline: ShkColors.DarkBorder,
        outlineVariant: ShkColors.DarkBorderSoft,
        error: ShkColors.SiteDanger,
        onError: .white,
        errorContainer: Color(argb: 0xFF5A2A30),
        onErrorContainer: .white,
        scrim: .black
    )
}
