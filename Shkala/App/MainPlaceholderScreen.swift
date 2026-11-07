import SwiftUI

/// جای موقت صفحه‌ی اصلی اپ (AppRoot اندروید) تا مرحله‌ی ۳.
/// فقط برای بررسی رنگ‌ها، فونت، آیکن‌ها و تم روشن/تاریک در عکس‌های مرحله‌ی ۱.
struct MainPlaceholderScreen: View {
    let isDarkTheme: Bool
    let onToggleTheme: () -> Void

    @Environment(\.shkColors) private var colors

    private let sampleIcons: [(String, String)] = [
        (RemixIcons.Home5Line, "خانه"),
        (RemixIcons.LayoutGridLine, "دسته‌بندی"),
        (RemixIcons.ShoppingCart2Line, "سبد خرید"),
        (RemixIcons.User3Line, "پروفایل"),
    ]

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("سیما حفاظ خزر")
                .shkFont(.headlineMedium)
                .foregroundColor(colors.onBackground)
            Text("اسکلت اپ iOS آماده است. صفحه‌ی اصلی در مراحل بعد عیناً مثل اپ اندروید ساخته می‌شود.")
                .shkFont(.bodyMedium)
                .foregroundColor(colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            HStack(spacing: 24) {
                ForEach(sampleIcons, id: \.0) { icon, label in
                    VStack(spacing: 6) {
                        RemixIcon(icon, contentDescription: label, tint: colors.primary)
                        Text(label)
                            .shkFont(.labelMedium)
                            .foregroundColor(colors.onSurface)
                    }
                }
            }
            .padding(16)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(colors.outlineVariant, lineWidth: 1))

            Button(action: onToggleTheme) {
                HStack(spacing: 8) {
                    RemixIcon(isDarkTheme ? RemixIcons.SunLine : RemixIcons.MoonLine, tint: colors.onPrimary, size: 18)
                    Text(isDarkTheme ? "تم روشن" : "تم تاریک")
                        .shkFont(14, .bold)
                        .foregroundColor(colors.onPrimary)
                }
                .padding(.horizontal, 20)
                .frame(height: 44)
                .background(colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
    }
}
