import SwiftUI
import UIKit

// معادل ShkalaTheme اپ اندروید (ui/theme/Theme.kt):
//  - رنگ‌ها از ShkColorScheme (روشن/تاریک) با همان نقش‌های متریال
//  - «تاریک بودن اپ» بر اساس انتخاب کاربر در خود اپ است، نه تنظیم گوشی (پیش‌فرض: روشن)
//  - جهت کل اپ ثابت راست‌به‌چپ است، صرف‌نظر از زبان گوشی

private struct ShkColorSchemeKey: EnvironmentKey {
    static let defaultValue: ShkColorScheme = .light
}

private struct ShkIsDarkKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// معادل MaterialTheme.colorScheme
    var shkColors: ShkColorScheme {
        get { self[ShkColorSchemeKey.self] }
        set { self[ShkColorSchemeKey.self] = newValue }
    }

    /// معادل isAppInDarkTheme() اپ اندروید
    var shkIsDark: Bool {
        get { self[ShkIsDarkKey.self] }
        set { self[ShkIsDarkKey.self] = newValue }
    }
}

struct ShkalaTheme: ViewModifier {
    let darkTheme: Bool

    func body(content: Content) -> some View {
        content
            .environment(\.shkColors, darkTheme ? .dark : .light)
            .environment(\.shkIsDark, darkTheme)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "fa_IR"))
            // نوار وضعیت بالای صفحه: متن تیره در تم روشن و روشن در تم تاریک (مثل isAppearanceLightStatusBars)
            .preferredColorScheme(darkTheme ? .dark : .light)
    }
}

extension View {
    func shkalaTheme(darkTheme: Bool) -> some View {
        modifier(ShkalaTheme(darkTheme: darkTheme))
    }

    /// محتوای sheet در iOS پنجره‌ی جدا داره: تم و جهت راست‌به‌چپ اپ دوباره روش اعمال می‌شه
    /// و پس‌زمینه‌ی شیت هم‌رنگ پس‌زمینه‌ی صفحه (containerColor = background اندروید)
    func shkSheetEnvironment() -> some View {
        modifier(ShkSheetEnvironment())
    }
}

struct ShkSheetEnvironment: ViewModifier {
    @Environment(\.shkIsDark) private var isDark

    func body(content: Content) -> some View {
        content
            // توست اندروید روی همه‌چیز (حتی شیت) دیده می‌شه
            .overlay(ShkToastHost())
            .shkalaTheme(darkTheme: isDark)
            .background((isDark ? ShkColorScheme.dark : ShkColorScheme.light).background.ignoresSafeArea())
    }
}

/// پنجره‌ی اپ مثل اندروید (setDecorFitsSystemWindows=true) هیچ محتوایی را زیر نوار وضعیت
/// نمی‌برد: ناحیه‌ی نوار وضعیت به رنگ background و ناحیه‌ی پایین (نوار ناوبری) به رنگ
/// surface (روشن) / background (تاریک) - دقیقاً مثل window.statusBarColor/navigationBarColor اندروید.
struct SystemBarsBackground: ViewModifier {
    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    func body(content: Content) -> some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    colors.background.frame(height: geo.safeAreaInsets.top)
                    Spacer(minLength: 0)
                    (isDark ? colors.background : colors.surface).frame(height: geo.safeAreaInsets.bottom)
                }
                .ignoresSafeArea()
                content
            }
        }
    }
}

extension View {
    func systemBarsBackground() -> some View {
        modifier(SystemBarsBackground())
    }
}
