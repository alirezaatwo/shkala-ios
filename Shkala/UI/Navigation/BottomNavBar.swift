import SwiftUI

/// تب‌های اصلی اپ (Routes.HOME / CATEGORIES / ACCOUNT اندروید)
enum AppTab: Hashable { case HOME, CATEGORIES, ACCOUNT }

/**
 * نوار ناوبری پایین اپ.
 *
 * بازطراحی - مرحله ۲: ظاهر دقیقاً مثل نوار پایین موبایل سایت (کامپوننت BottomNavigation
 * و کلاس‌های .bottom-navigation در CSS سایت):
 *  - پس‌زمینه: روشن سفید / تاریک #262631، با خط‌چین ۱px در بالا
 *  - آیکن‌ها: Remix Icon خطی، ۲۲pt، رنگ غیرفعال #999 (تاریک #bbb)
 *  - آیتم فعال: آیکن قرمز + عنوان داخل قرص قرمز (گوشه‌ی ۸، متن سفید بولد) با سایه‌ی قرمز
 *  - بج تعداد: متن قرمز روی پس‌زمینه‌ی قرمزِ ۲۰٪، کنار عنوان
 */
struct BottomNavBar: View {
    /// تب فعلی؛ nil یعنی یه صفحه‌ی غیرتبی (مثل صفحه‌ی محصول) روی تب‌ها باز شده
    let currentTab: AppTab?
    let cartItemCount: Int
    let isLoggedIn: Bool
    let onTabClick: (AppTab) -> Void
    let onCartClick: () -> Void
    let onChatClick: () -> Void
    let isChatOpen: Bool
    let chatUnreadCount: Int

    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    var body: some View {
        // روشن: سفید (#fff سایت) / تاریک: #262631 (همون پس‌زمینه‌ی صفحه در حالت تاریک سایت)
        let barColor = isDark ? colors.background : colors.surface
        VStack(spacing: 0) {
            DashedDivider(color: isDark ? ShkColors.DarkNavDashedBorder : ShkColors.LightNavDashedBorder)
            HStack(alignment: .center, spacing: 0) {
                SiteNavItem(label: "خانه", icon: RemixIcons.Home6Line, selected: currentTab == .HOME, barColor: barColor) {
                    onTabClick(.HOME)
                }
                SiteNavItem(label: "دسته‌بندی", icon: RemixIcons.Apps2Line, selected: currentTab == .CATEGORIES, barColor: barColor) {
                    onTabClick(.CATEGORIES)
                }
                SiteNavItem(label: "سبد خرید", icon: RemixIcons.ShoppingBasketLine, selected: false, barColor: barColor, badgeCount: cartItemCount) {
                    onCartClick()
                }
                SiteNavItem(label: "مشاوره آنلاین", icon: RemixIcons.CustomerService2Line, selected: isChatOpen, barColor: barColor, badgeCount: chatUnreadCount) {
                    if !isChatOpen { onChatClick() }
                }
                SiteNavItem(
                    label: isLoggedIn ? "حساب من" : "ورود",
                    icon: RemixIcons.UserSmileLine,
                    selected: currentTab == .ACCOUNT,
                    barColor: barColor,
                    // کاربر واردشده: بج تیک قرمز روی آیکن «حساب من»
                    showCheckBadge: isLoggedIn
                ) {
                    onTabClick(.ACCOUNT)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .background(barColor.ignoresSafeArea(edges: .bottom))
    }
}

/// یک دکمه‌ی نوار پایین با ظاهر سایت (li در .bottom-navigation ul)
private struct SiteNavItem: View {
    let label: String
    let icon: String
    let selected: Bool
    let barColor: Color
    var badgeCount: Int = 0
    var showCheckBadge: Bool = false
    let onClick: () -> Void

    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    var body: some View {
        let primary = colors.primary
        let inactive = isDark ? ShkColors.DarkNavInactive : ShkColors.LightNavInactive
        Button(action: onClick) {
            VStack(spacing: 0) {
                RemixIcon(icon, tint: selected ? primary : inactive, size: 22)
                    .overlay(alignment: .topTrailing) {
                        if showCheckBadge {
                            // بج دایره‌ای قرمز با تیک سفید، گوشه‌ی بالا-چپِ آیکن (حاشیه‌ی هم‌رنگ نوار)
                            ZStack {
                                Circle().fill(barColor)
                                Circle().fill(primary).padding(1.5)
                                RemixIcon(RemixIcons.CheckLine, tint: .white, size: 9)
                            }
                            .frame(width: 13, height: 13)
                            .offset(x: -6, y: -3)
                        }
                    }
                Spacer().frame(height: 2)

                if selected {
                    // عنوان آیتم فعال: قرص قرمز با متن سفید بولد و سایه‌ی قرمز
                    // (box-shadow: 0 5px 5px rgba(primary, .4) در سایت)
                    HStack(spacing: 0) {
                        Text(label)
                            .shkFont(11, .bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if badgeCount > 0 {
                            Spacer().frame(width: 4)
                            NavCountBadge(count: badgeCount, textColor: .white, background: Color.white.opacity(0.25))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(primary)
                            .shadow(color: primary.opacity(0.5), radius: 4, x: 0, y: 2.5)
                    )
                } else {
                    HStack(spacing: 0) {
                        Text(label)
                            .shkFont(11)
                            .foregroundColor(inactive)
                            .lineLimit(1)
                        if badgeCount > 0 {
                            Spacer().frame(width: 4)
                            NavCountBadge(count: badgeCount, textColor: primary, background: primary.opacity(0.2))
                        }
                    }
                }
            }
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(SitePressStyle())
        .padding(.horizontal, 3)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// بج تعداد کنار عنوان - مثل .count-badge سایت (گوشه‌ی ۵، متن بولد ۱۱)
private struct NavCountBadge: View {
    let count: Int
    let textColor: Color
    let background: Color

    var body: some View {
        Text(count > 99 ? "+۹۹" : count.toPersianDigits())
            .shkFont(11, .bold, lineHeight: 15)
            .foregroundColor(textColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(background))
    }
}
