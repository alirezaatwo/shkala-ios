import SwiftUI

// ===================================================================================
// معادل ui/account/NotificationsListScreen.kt
// ===================================================================================

struct NotificationsListScreen: View {
    let onBack: () -> Void
    @Environment(\.shkColors) private var colors
    private let repository = AccountRepository()

    @State private var notifications: [NotificationDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    // بروزرسانی با کشیدن صفحه: بدون لودینگ تمام‌صفحه؛ اگه خطا بده محتوای فعلی حفظ می‌شه
    private func refresh() async {
        switch await repository.getNotifications() {
        case .success(let data):
            notifications = data.notifications
            errorMessage = nil
        case .error(let message):
            if errorMessage != nil { errorMessage = message }
        }
    }

    private func onNotificationClick(_ notification: NotificationDto) {
        if notification.isRead { return }
        notifications = notifications.map { n in
            var copy = n
            if n.id == notification.id { copy.isRead = true }
            return copy
        }
        Task { _ = await repository.markNotificationAsRead(notification.id) }
    }

    var body: some View {
        let unreadCount = notifications.filter { !$0.isRead }.count
        VStack(spacing: 0) {
            SitePageTopBar(
                title: "اعلان‌ها",
                onBack: onBack,
                subtitle: unreadCount > 0 ? "\(unreadCount.toPersianDigits()) اعلان خوانده‌نشده" : nil
            )
            Group {
                if isLoading {
                    SiteLoading(message: "در حال دریافت اعلان‌ها...", icon: RemixIcons.Notification3Line)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    // حالت خطا/خالی هم با کشیدن صفحه دوباره بارگذاری می‌شه
                    ScrollView {
                        SiteEmptyState(icon: RemixIcons.WifiOffLine, title: "دریافت اعلان‌ها ممکن نشد", subtitle: errorMessage)
                            .padding(16)
                    }
                    .sitePullRefresh { await refresh() }
                } else if notifications.isEmpty {
                    ScrollView {
                        SiteEmptyState(icon: RemixIcons.Notification3Line, title: "اعلانی ندارید", subtitle: nil)
                            .padding(16)
                    }
                    .sitePullRefresh { await refresh() }
                } else {
                    // کشیدن صفحه به پایین برای بروزرسانی اعلان‌ها
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(notifications.uniqueById()) { notification in
                                NotificationRow(notification: notification, onClick: { onNotificationClick(notification) })
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                    .sitePullRefresh { await refresh() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task {
            switch await repository.getNotifications() {
            case .success(let data): notifications = data.notifications
            case .error(let message): errorMessage = message
            }
            isLoading = false
        }
    }
}

private struct NotificationRow: View {
    let notification: NotificationDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let newColor = SiteStatusColors.Success
        let isUnread = !notification.isRead
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: onClick) {
            HStack(alignment: .top, spacing: 0) {
                SiteIconBadge(
                    icon: isUnread ? RemixIcons.Notification3Fill : RemixIcons.Notification3Line,
                    size: 40,
                    iconSize: 20,
                    tint: isUnread ? colors.primary : colors.onSurfaceVariant
                )
                .overlay(alignment: .topTrailing) {
                    if isUnread {
                        // نقطه‌ی سبز «خوانده‌نشده» روی گوشه‌ی آیکن
                        ZStack {
                            Circle().fill(colors.surface)
                            Circle().fill(newColor).padding(2)
                        }
                        .frame(width: 11, height: 11)
                    }
                }
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(htmlToPlainText(notification.message ?? ""))
                        .shkFont(13, isUnread ? .bold : .normal, lineHeight: 22)
                        .foregroundColor(colors.onSurface)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(height: 8)
                    HStack(spacing: 0) {
                        if let date = notification.date, !date.isBlankShk {
                            RemixIcon(RemixIcons.TimeLine, tint: colors.onSurfaceVariant, size: 14)
                            Spacer().frame(width: 4)
                            Text(date.toPersianDigits())
                                .shkFont(11)
                                .foregroundColor(colors.onSurfaceVariant)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer(minLength: 0)
                        }
                        SiteStatusChip(
                            text: notification.isRead ? "مشاهده شده" : "مشاهده کنید",
                            color: notification.isRead ? SiteStatusColors.Neutral : SiteStatusColors.Success,
                            icon: notification.isRead ? RemixIcons.CheckDoubleLine : RemixIcons.EyeLine
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(shape.fill(colors.surface))
            .overlay(shape.strokeBorder(isUnread ? newColor.opacity(0.7) : Color.clear, lineWidth: 1))
            .contentShape(shape)
            .animation(.easeInOut(duration: 0.3), value: isUnread)
        }
        .buttonStyle(.plain)
    }
}
