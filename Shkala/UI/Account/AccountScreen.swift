import SwiftUI

// ===================================================================================
// معادل ui/account/AccountScreen.kt
// ===================================================================================

/** مقصدهای منوی «حساب من» */
struct AccountActions {
    var onOrdersClick: () -> Void
    var onWalletClick: () -> Void
    var onTransactionsClick: () -> Void
    var onNotificationsClick: () -> Void
    var onPrefactorsClick: () -> Void
    var onTicketsClick: () -> Void
    var onFavoritesClick: () -> Void
    var onCommentsClick: () -> Void
    var onRecentlyViewedClick: () -> Void
    var onSessionsClick: () -> Void
    var onEditProfileClick: () -> Void
    var onAddressesClick: () -> Void
    // فاز ۲۶: منوی «مقایسه‌های من» - بین دیدگاه‌های من و بازدیدهای اخیر
    var onCompareClick: () -> Void = {}
}

struct AccountScreen: View {
    let actions: AccountActions
    @ObservedObject private var tokenManager = TokenManager.shared

    var body: some View {
        if tokenManager.token == nil {
            // نیازی نیست کاری بکنیم؛ با تغییر توکن، همین صفحه خودکار به پروفایل تغییر می‌کنه
            AuthScreen(onLoginSuccess: {})
        } else {
            ProfileScreen(actions: actions)
        }
    }
}

private struct ProfileScreen: View {
    let actions: AccountActions
    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark
    @ObservedObject private var viewedOrders = ViewedOrdersManager.shared
    @ObservedObject private var viewedPrefactors = ViewedPrefactorsManager.shared

    @State private var user: UserDto? = nil
    @State private var summary: AccountSummaryResponse? = nil
    @State private var unreadOrdersCount = 0
    @State private var totalPrefactorsCount = 0
    @State private var unreadPrefactorsCount = 0
    @State private var totalTicketsCount = 0
    @State private var unreadTicketsCount = 0
    @State private var isLoading = true
    @State private var avatarUrl: String? = nil
    @State private var favoritesCount = 0
    @State private var addressesCount = 0
    @State private var sessionsCount = 0

    private let accountRepository = AccountRepository()
    private let prefactorRepository = PrefactorRepository()
    private let ticketRepository = TicketRepository()
    private let favoriteRepository = FavoriteRepository()
    private let checkoutRepository = CheckoutRepository()
    private let sessionRepository = SessionRepository()
    private let profileRepository = ProfileRepository()

    // دریافت همه‌ی اطلاعات صفحه؛ هم برای بارگذاری اول و هم برای «کشیدن برای بروزرسانی» (بدون لودینگ تمام‌صفحه)
    private func loadAll() async {
        let viewedOrderIds = viewedOrders.viewedOrderIds
        let viewedPrefactorUuids = viewedPrefactors.viewedPrefactorUuids
        async let meResponse = try? ApiService.me()
        async let summaryResult = accountRepository.getAccountSummary()
        async let ordersResult = accountRepository.getMyOrdersPage(1)
        async let prefactorsResult = prefactorRepository.getPrefactors()
        async let ticketsResult = ticketRepository.getTickets()
        async let favoritesResult = favoriteRepository.getFavorites()
        async let addressesResult = checkoutRepository.getAddresses()
        async let sessionsResult = sessionRepository.getSessions()
        async let profileResult = profileRepository.getProfile()

        if let r = await meResponse, r.isSuccessful { user = r.body?.user }
        switch await summaryResult {
        case .success(let s): summary = s
        case .error(let message): ShkToast.shared.show("خطا در دریافت آمار: \(message)", long: true)
        }
        if case .success(let data) = await ordersResult {
            let allOrderIds = data.orderGroups.flatMap { group in group.orders.map { $0.id } }
            unreadOrdersCount = allOrderIds.filter { !viewedOrderIds.contains(String($0)) }.count
        }
        if case .success(let list) = await prefactorsResult {
            totalPrefactorsCount = list.count
            unreadPrefactorsCount = list.filter { !viewedPrefactorUuids.contains($0.uuid) }.count
        }
        if case .success(let list) = await ticketsResult {
            totalTicketsCount = list.count
            // تیکت‌هایی که وضعیتشون "در انتظار پاسخ کاربر"ه یعنی پشتیبانی جواب داده و کاربر هنوز ندیده/پاسخ نداده
            unreadTicketsCount = list.filter { $0.status == "waiting_user" }.count
        }
        if case .success(let list) = await favoritesResult { favoritesCount = list.count }
        if case .success(let list) = await addressesResult { addressesCount = list.count }
        if case .success(let r) = await sessionsResult { sessionsCount = r.sessions.count }
        if case .success(let r) = await profileResult { avatarUrl = r.user.avatarUrl }
    }

    var body: some View {
        Group {
            if isLoading {
                MaterialSpinner(color: colors.primary, lineWidth: 4, size: 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // بازطراحی: کارت پروفایل → آمار → منوها در سه کادرِ گروه‌بندی‌شده → دکمه‌ی خروج
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 16)
                        ProfileHeaderCard(
                            name: user?.name.flatMap { $0.isBlankShk ? nil : $0 } ?? "کاربر سیما حفاظ خزر",
                            phone: user?.phone ?? "",
                            avatarUrl: avatarUrl,
                            summary: summary,
                            onEditProfileClick: actions.onEditProfileClick,
                            onLevelClick: showLevelDialog
                        )

                        if let summary {
                            Spacer().frame(height: 12)
                            AccountStatsGrid(
                                summary: summary,
                                onOrdersClick: actions.onOrdersClick,
                                onWalletClick: actions.onWalletClick,
                                onTicketsClick: actions.onTicketsClick,
                                onCommentsClick: actions.onCommentsClick
                            )
                        }

                        MenuGroup(title: "سفارش‌ها و امور مالی") {
                            AccountMenuRow(icon: RemixIcons.ShoppingBag3Line, title: "سفارش‌های من", onClick: actions.onOrdersClick, totalCount: summary?.totalOrders, unreadCount: unreadOrdersCount)
                            MenuDivider()
                            AccountMenuRow(icon: RemixIcons.Wallet3Line, title: "کیف پول", onClick: actions.onWalletClick)
                            MenuDivider()
                            AccountMenuRow(icon: RemixIcons.ExchangeDollarLine, title: "تراکنش‌های من", onClick: actions.onTransactionsClick)
                            MenuDivider()
                            AccountMenuRow(icon: RemixIcons.FileList3Line, title: "پیش‌فاکتورها", onClick: actions.onPrefactorsClick, totalCount: totalPrefactorsCount, unreadCount: unreadPrefactorsCount)
                        }

                        MenuGroup(title: "پشتیبانی و فعالیت‌ها") {
                            AccountMenuRow(icon: RemixIcons.CustomerService2Line, title: "تیکت‌های پشتیبانی", onClick: actions.onTicketsClick, totalCount: totalTicketsCount, unreadCount: unreadTicketsCount)
                            MenuDivider()
                            AccountMenuRow(icon: RemixIcons.Heart3Line, title: "علاقه‌مندی‌های من", onClick: actions.onFavoritesClick, totalCount: favoritesCount)
                            MenuDivider()
                            AccountMenuRow(icon: RemixIcons.ChatQuoteLine, title: "دیدگاه‌های من", onClick: actions.onCommentsClick)
                            MenuDivider()
                            AccountMenuRow(icon: RemixIcons.ArrowLeftRightLine, title: "مقایسه‌های من", onClick: actions.onCompareClick)
                            MenuDivider()
                            AccountMenuRow(icon: RemixIcons.HistoryLine, title: "بازدیدهای اخیر", onClick: actions.onRecentlyViewedClick)
                        }

                        MenuGroup(title: "حساب کاربری") {
                            AccountMenuRow(icon: RemixIcons.SmartphoneLine, title: "نشست‌های فعال", onClick: actions.onSessionsClick, totalCount: sessionsCount)
                            MenuDivider()
                            AccountMenuRow(icon: RemixIcons.UserSettingsLine, title: "ویرایش حساب کاربری", onClick: actions.onEditProfileClick)
                            MenuDivider()
                            AccountMenuRow(icon: RemixIcons.MapPin2Line, title: "آدرس‌های من", onClick: actions.onAddressesClick, totalCount: addressesCount)
                            MenuDivider()
                            AccountMenuRow(icon: RemixIcons.Notification3Line, title: "اعلان‌ها", onClick: actions.onNotificationsClick, unreadCount: summary?.unreadNotificationsCount)
                        }

                        Spacer().frame(height: 16)
                        // خروج از حساب - کادر قرمزِ کم‌رنگ
                        Button { TokenManager.shared.clearSession() } label: {
                            HStack(spacing: 0) {
                                RemixIcon(RemixIcons.LogoutBoxRLine, tint: colors.error, size: 20)
                                Spacer().frame(width: 8)
                                Text("خروج از حساب کاربری").shkFont(14, .bold).foregroundColor(colors.error)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.error.opacity(0.08)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 16)
                }
                // کشیدن صفحه به پایین برای بروزرسانی اطلاعات حساب
                .sitePullRefresh { await loadAll() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background.ignoresSafeArea())
        .task {
            await loadAll()
            isLoading = false
        }
        // بج تیکت‌ها رو لحظه‌ای نگه می‌داره - هر ۵ ثانیه بی‌صدا چک می‌کنه (فقط وقتی همین صفحه دیده می‌شه)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                let nav = AppNavigator.shared
                guard nav.tab == .ACCOUNT && nav.stack.isEmpty else { continue }
                if case .success(let list) = await ticketRepository.getTickets() {
                    totalTicketsCount = list.count
                    unreadTicketsCount = list.filter { $0.status == "waiting_user" }.count
                }
            }
        }
    }

    private func showLevelDialog() {
        guard let summary else { return }
        ShkDialogCenter.shared.show {
            LevelInfoDialog(summary: summary, onDismiss: { ShkDialogCenter.shared.dismiss() })
        }
    }
}

/** کارت بالای پروفایل: آواتار با حلقه‌ی قرمز و دکمه‌ی ویرایش، نام و شماره، سطح و امتیاز باشگاه */
private struct ProfileHeaderCard: View {
    let name: String
    let phone: String
    let avatarUrl: String?
    let summary: AccountSummaryResponse?
    let onEditProfileClick: () -> Void
    var onLevelClick: () -> Void = {}
    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    var body: some View {
        let primary = colors.primary
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button(action: onEditProfileClick) {
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            Circle().fill(primary.opacity(0.1))
                            if let avatarUrl {
                                RemoteImage(avatarUrl, contentScale: .crop).clipShape(Circle())
                            } else {
                                RemixIcon(RemixIcons.UserSmileLine, tint: primary, size: 30)
                            }
                        }
                        .clipShape(Circle())
                        .padding(3)
                        .overlay(Circle().strokeBorder(primary, lineWidth: 2))
                        .frame(width: 62, height: 62)
                        // دکمه‌ی کوچک ویرایش روی گوشه‌ی آواتار
                        ZStack {
                            Circle().fill(colors.surface)
                            Circle().fill(primary).padding(2)
                            RemixIcon(RemixIcons.PencilLine, contentDescription: "ویرایش", tint: .white, size: 11)
                        }
                        .frame(width: 22, height: 22)
                    }
                    .frame(width: 62, height: 62)
                }
                .buttonStyle(.plain)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .shkFont(15, .bold)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if !phone.isBlankShk {
                        Spacer().frame(height: 2)
                        Text(phone.toPersianDigits()).shkFont(12).foregroundColor(colors.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let summary {
                    // تگ سطح کاربر (رنگ سطح: برنزی / نقره‌ای / طلایی) - با زدن روش، مودال راهنمای ارتقای سطح باز می‌شه
                    let levelTint = levelColor(summary.level)
                    Button(action: onLevelClick) {
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.VipCrown2Line, tint: levelTint, size: 15)
                            Spacer().frame(width: 4)
                            Text("سطح \(levelLabel(summary.level))").shkFont(11, .bold).foregroundColor(colors.onSurface)
                            RemixIcon(RemixIcons.ArrowLeftSLine, contentDescription: "راهنمای سطح‌ها", tint: colors.onSurfaceVariant, size: 15)
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, 4)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(levelTint.opacity(0.15)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if let summary {
                Spacer().frame(height: 12)
                DashedDivider(color: isDark ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider)
                Spacer().frame(height: 12)
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.CoinsLine, tint: primary, size: 18)
                    Spacer().frame(width: 6)
                    Text("امتیاز باشگاه مشتریان")
                        .shkFont(12)
                        .foregroundColor(colors.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(summary.clubScore.toPersianDigits()).shkFont(15, .bold).foregroundColor(primary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(colors.surface))
    }
}

/** یک گروه از منوهای حساب: عنوان با خط قرمز + کادر شامل ردیف‌ها */
private struct MenuGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 20)
            SiteSectionTitle(title).padding(.bottom, 10)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.surface))
        }
    }
}

private struct MenuDivider: View {
    @Environment(\.shkIsDark) private var isDark
    var body: some View {
        DashedDivider(color: isDark ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider)
    }
}

private struct AccountStatsGrid: View {
    let summary: AccountSummaryResponse
    let onOrdersClick: () -> Void
    let onWalletClick: () -> Void
    let onTicketsClick: () -> Void
    let onCommentsClick: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            // ردیف ۱: تعداد سفارش‌ها + سفارش‌های در انتظار پردازش (هر دو به سفارش‌ها می‌رن)
            HStack(spacing: 10) {
                StatBox(icon: RemixIcons.ShoppingBag3Line, label: "تعداد سفارش‌ها", value: summary.totalOrders.toPersianDigits(), onClick: onOrdersClick)
                StatBox(icon: RemixIcons.HourglassLine, label: "در انتظار پردازش", value: summary.pendingOrders.toPersianDigits(), onClick: onOrdersClick)
            }
            // ردیف ۲: مجموع خرید + موجودی کیف پول (کیف پول به کیف پول می‌ره)
            HStack(spacing: 10) {
                StatBox(icon: RemixIcons.BillLine, label: "مجموع خرید", value: "\(formatTomanFa(summary.totalSpent)) تومان", valueFontSize: 13)
                StatBox(icon: RemixIcons.Wallet3Line, label: "موجودی کیف پول", value: "\(formatTomanFa(summary.walletAmount)) تومان", valueFontSize: 13, onClick: onWalletClick)
            }
            // ردیف ۳: تیکت، دیدگاه، پرسش - سه‌ستونه
            HStack(spacing: 10) {
                StatBox(icon: RemixIcons.Ticket2Line, label: "تیکت‌ها", value: summary.ticketsCount.toPersianDigits(), onClick: onTicketsClick)
                StatBox(icon: RemixIcons.ChatQuoteLine, label: "دیدگاه‌ها", value: summary.commentsCount.toPersianDigits(), onClick: onCommentsClick)
                StatBox(icon: RemixIcons.QuestionAnswerLine, label: "پرسش‌ها", value: summary.questionsCount.toPersianDigits())
            }
        }
    }
}

private struct StatBox: View {
    let icon: String
    let label: String
    let value: String
    var valueFontSize: CGFloat = 16
    var onClick: (() -> Void)? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let box = VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous).fill(primary.opacity(0.1))
                    RemixIcon(icon, tint: primary, size: 16)
                }
                .frame(width: 28, height: 28)
                Spacer().frame(width: 6)
                Text(label)
                    .shkFont(11)
                    .foregroundColor(colors.onSurfaceVariant)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer().frame(height: 8)
            Text(value)
                .shkFont(valueFontSize, .bold)
                .foregroundColor(colors.onSurface)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.surface))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        if let onClick {
            Button(action: onClick) { box }.buttonStyle(.plain)
        } else {
            box
        }
    }
}

private func levelLabel(_ level: String) -> String {
    switch level {
    case "gold": return "طلایی"
    case "silver": return "نقره‌ای"
    default: return "برنزی"
    }
}

private func levelColor(_ level: String) -> Color {
    switch level {
    case "gold": return Color(argb: 0xFFD4AF37)
    case "silver": return Color(argb: 0xFFB0B0B8)
    default: return Color(argb: 0xFFCD7F32)
    }
}

private struct AccountMenuRow: View {
    let icon: String
    let title: String
    let onClick: () -> Void
    var totalCount: Int? = nil
    var unreadCount: Int? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        Button(action: onClick) {
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(primary.opacity(0.1))
                    RemixIcon(icon, tint: primary, size: 19)
                }
                .frame(width: 36, height: 36)
                Spacer().frame(width: 12)
                Text(title)
                    .shkFont(13, .medium)
                    .foregroundColor(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // تعداد کل: تگ خنثی / تعداد خوانده‌نشده: تگ سبز
                if let totalCount {
                    CountTag(count: totalCount, background: colors.surfaceVariant, textColor: colors.onSurfaceVariant)
                    Spacer().frame(width: 6)
                }
                if let unreadCount, unreadCount > 0 {
                    CountTag(count: unreadCount, background: Color(argb: 0xFF2E7D32), textColor: .white)
                    Spacer().frame(width: 6)
                }
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CountTag: View {
    let count: Int
    let background: Color
    let textColor: Color

    var body: some View {
        Text(count.toPersianDigits())
            .shkFont(11, .bold, lineHeight: 14)
            .foregroundColor(textColor)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 22)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(background))
    }
}

// ===================================================================================
// مودال «سطح کاربری»: منطق دقیقاً مطابق سایت (User::getGetLevelAttribute در بک‌اند):
//  سطح فقط بر اساس «امتیاز باشگاه مشتریان» حساب می‌شه:
//   امتیاز >= gold_level  → طلایی ؛  امتیاز >= silver_level → نقره‌ای ؛ وگرنه برنزی
// آستانه‌ها تنظیمات پنل ادمین هستن و API (account/summary) اون‌ها رو برمی‌گردونه؛ دو عدد زیر فقط
// پشتیبانِ حالتیه که سرور هنوز به‌روز نشده باشه.
// ===================================================================================
private let SILVER_LEVEL_SCORE = 5_000
private let GOLD_LEVEL_SCORE = 10_000

private struct LevelInfoDialog: View {
    let summary: AccountSummaryResponse
    let onDismiss: () -> Void
    @Environment(\.shkColors) private var colors
    @State private var started = false

    var body: some View {
        let level = summary.level
        // آستانه‌ها از API (تنظیمات ادمین)؛ اگه نسخه‌ی قدیمی API بود، مقادیر فعلی دیتابیس
        let silverScore = summary.silverLevel.map { Int($0) } ?? SILVER_LEVEL_SCORE
        let goldScore = summary.goldLevel.map { Int($0) } ?? GOLD_LEVEL_SCORE
        let score = max(summary.clubScore, 0)
        let currentTint = levelColor(level)
        // سطح بعدی و آستانه‌ی شروع/پایان بازه‌ی فعلی برای نوار پیشرفت
        let nextLevel: String? = level == "gold" ? nil : (level == "silver" ? "gold" : "silver")
        let rangeStart = level == "gold" ? goldScore : (level == "silver" ? silverScore : 0)
        let rangeEnd = nextLevel == "silver" ? silverScore : goldScore
        let targetProgress: CGFloat = nextLevel == nil ? 1 :
            min(max(CGFloat(score - rangeStart) / CGFloat(rangeEnd - rangeStart), 0), 1)
        let remaining = max(rangeEnd - score, 0)
        let nextKey = nextLevel ?? level

        SiteDialogContent(
            title: "سطح کاربری شما: \(levelLabel(level))",
            icon: RemixIcons.VipCrown2Line,
            iconTint: currentTint,
            message: "سطح حساب شما بر اساس «امتیاز باشگاه مشتریان» تعیین می‌شود و با افزایش امتیاز، خودکار ارتقا پیدا می‌کند.",
            confirmText: "متوجه شدم",
            onConfirm: onDismiss
        ) {
            // کادر امتیاز فعلی + نوار پیشرفت تا سطح بعد
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.CoinsLine, tint: colors.primary, size: 18)
                    Spacer().frame(width: 6)
                    Text("امتیاز فعلی شما").shkFont(12).foregroundColor(colors.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatTomanFa(Int64(score))).shkFont(15, .bold).foregroundColor(colors.primary)
                }
                Spacer().frame(height: 10)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(colors.surface)
                        Capsule().fill(nextLevel == nil ? currentTint : levelColor(nextKey))
                            .frame(width: g.size.width * (started ? targetProgress : 0))
                    }
                }
                .frame(height: 8)
                Spacer().frame(height: 8)
                Text(
                    nextLevel == nil ? "شما در بالاترین سطح باشگاه مشتریان هستید." :
                        (remaining > 0 ? "\(formatTomanFa(Int64(remaining))) امتیاز دیگر تا سطح \(levelLabel(nextKey))" :
                            "برای ارتقا به سطح \(levelLabel(nextKey)) امتیاز بیشتری نیاز دارید.")
                )
                .shkFont(12, .medium, lineHeight: 20)
                .foregroundColor(colors.onSurface)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.surfaceVariant))

            Spacer().frame(height: 12)
            // جدول سطح‌ها (برنزی → نقره‌ای → طلایی)
            LevelStepRow(levelKey: "bronze", requirement: "از ابتدای عضویت", currentLevel: level)
            SiteDashedDivider()
            LevelStepRow(levelKey: "silver", requirement: "از \(formatTomanFa(Int64(silverScore))) امتیاز", currentLevel: level)
            SiteDashedDivider()
            LevelStepRow(levelKey: "gold", requirement: "از \(formatTomanFa(Int64(goldScore))) امتیاز", currentLevel: level)

            Spacer().frame(height: 12)
            // نکته‌های کوتاه - مطابق منطق ثبت امتیاز در سایت
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.LightbulbFlashLine, tint: colors.primary, size: 16)
                    Spacer().frame(width: 6)
                    Text("چطور امتیاز بگیرم؟").shkFont(12, .bold).foregroundColor(colors.onSurface)
                }
                Spacer().frame(height: 6)
                LevelTip(text: "با هر خرید، به نسبت مبلغ نهایی سفارش امتیاز باشگاه دریافت می‌کنید.")
                LevelTip(text: "امتیاز خودکار فقط برای سفارش‌هایی است که آنلاین پرداخت می‌شوند (نه کارت‌به‌کارت).")
                LevelTip(text: "با لغو یا مرجوع‌شدن سفارش، امتیاز همان سفارش از حساب شما کسر می‌شود.")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.primary.opacity(0.06)))
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.7)) { started = true } }
    }
}

private struct LevelStepRow: View {
    let levelKey: String
    let requirement: String
    let currentLevel: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        let rank = ["bronze": 0, "silver": 1, "gold": 2]
        let isCurrent = levelKey == currentLevel || (levelKey == "bronze" && rank[currentLevel] == nil)
        let reached = (rank[levelKey] ?? 0) <= (rank[currentLevel] ?? 0)
        let tint = levelColor(levelKey)
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.15))
                RemixIcon(RemixIcons.VipCrown2Line, tint: tint, size: 18)
            }
            .frame(width: 34, height: 34)
            Spacer().frame(width: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text("سطح \(levelLabel(levelKey))").shkFont(13, .bold).foregroundColor(colors.onSurface)
                Text(requirement).shkFont(11).foregroundColor(colors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isCurrent {
                SiteStatusChip(text: "سطح فعلی", color: colors.primary)
            } else if reached {
                RemixIcon(RemixIcons.CheckboxCircleFill, contentDescription: "کسب شده", tint: SiteStatusColors.Success, size: 20)
            } else {
                RemixIcon(RemixIcons.LockLine, contentDescription: "کسب نشده", tint: colors.onSurfaceVariant, size: 18)
            }
        }
        .padding(.vertical, 8)
    }
}

private struct LevelTip: View {
    let text: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Circle().fill(colors.primary).frame(width: 5, height: 5).padding(.top, 8)
            Spacer().frame(width: 8)
            Text(text)
                .shkFont(12, lineHeight: 20)
                .foregroundColor(colors.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}
