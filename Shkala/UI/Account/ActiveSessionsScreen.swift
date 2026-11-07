import SwiftUI

// ===================================================================================
// معادل ui/account/ActiveSessionsScreen.kt
// ===================================================================================

struct ActiveSessionsScreen: View {
    let onBack: () -> Void
    let onLoggedOut: () -> Void
    @Environment(\.shkColors) private var colors
    private let repository = SessionRepository()

    @State private var sessions: [SessionDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private func load() async {
        switch await repository.getSessions() {
        case .success(let data):
            sessions = data.sessions
            errorMessage = nil
        case .error(let message):
            errorMessage = message
        }
        isLoading = false
    }

    // بروزرسانی با کشیدن صفحه: محتوای فعلی حفظ می‌شه و خطا فقط با توست نشون داده می‌شه
    private func refresh() async {
        switch await repository.getSessions() {
        case .success(let data):
            sessions = data.sessions
            errorMessage = nil
        case .error(let message):
            ShkToast.shared.show(message)
        }
    }

    private func askTerminate(_ target: SessionDto) {
        ShkDialogCenter.shared.show {
            TerminateSessionDialog(
                target: target,
                onConfirm: {
                    ShkDialogCenter.shared.dismiss()
                    Task {
                        switch await repository.terminate(target.id) {
                        case .success(let wasCurrent):
                            if wasCurrent {
                                onLoggedOut()
                            } else {
                                ShkToast.shared.show("نشست پایان یافت.")
                                await load()
                            }
                        case .error(let message):
                            ShkToast.shared.show(message)
                        }
                    }
                },
                onDismiss: { ShkDialogCenter.shared.dismiss() }
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "نشست‌های فعال", onBack: onBack)
            Group {
                if isLoading {
                    SiteLoading(message: "در حال دریافت نشست‌ها...", icon: RemixIcons.SmartphoneLine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    // حالت خطا دکمه‌ی تلاش مجدد نداره، پس با کشیدن صفحه دوباره بارگذاری می‌شه
                    ScrollView {
                        SiteEmptyState(icon: RemixIcons.WifiOffLine, title: "دریافت نشست‌ها ممکن نشد", subtitle: errorMessage)
                            .padding(16)
                    }
                    .sitePullRefresh { await load() }
                } else {
                    // کشیدن صفحه به پایین برای بروزرسانی فهرست نشست‌ها
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            SiteHeroCard(
                                icon: RemixIcons.ShieldUserLine,
                                title: "\(sessions.count.toPersianDigits()) دستگاه فعال",
                                subtitle: "دستگاه‌هایی که با این حساب وارد شدن. با پایان‌دادن به یه نشست، همون دستگاه از حساب خارج می‌شه."
                            )
                            .padding(.bottom, 4)
                            ForEach(sessions.uniqueById()) { session in
                                SessionRow(session: session, onTerminate: { askTerminate(session) })
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                    .sitePullRefresh { await refresh() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task { await load() }
    }
}

private struct TerminateSessionDialog: View {
    let target: SessionDto
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteDialogContent(
            title: "پایان نشست",
            icon: RemixIcons.LogoutBoxRLine,
            iconTint: colors.error,
            message: target.isCurrent
                ? "این نشست، همین دستگاهه. با پایان‌دادنش، از حساب خارج می‌شید."
                : "مطمئنید می‌خواید این دستگاه رو از حساب خارج کنید؟",
            confirmText: "پایان نشست",
            onConfirm: onConfirm,
            confirmColor: colors.error,
            dismissText: "انصراف",
            onDismiss: onDismiss
        ) {
            // خلاصه‌ی دستگاهی که قراره خارج بشه
            HStack(spacing: 0) {
                SiteIconBadge(icon: sessionDeviceIcon(target.name), size: 36, iconSize: 19, radius: 11)
                Spacer().frame(width: 10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(target.name ?? "دستگاه ناشناس")
                        .shkFont(13, .bold)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("آخرین فعالیت: \(target.lastUsedAt?.toPersianDigits() ?? "نامشخص")")
                        .shkFont(11)
                        .foregroundColor(colors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.surfaceVariant))
        }
    }
}

/** آیکن دستگاه بر اساس نام نشست (نامی که اپ/مرورگر هنگام ورود فرستاده) */
private func sessionDeviceIcon(_ name: String?) -> String {
    let n = (name ?? "").lowercased()
    if n.contains("ipad") || n.contains("tablet") || n.contains("tab ") { return RemixIcons.TabletLine }
    if n.contains("iphone") || n.contains("ios") { return RemixIcons.AppleLine }
    if ["windows", "mac", "linux", "desktop", "web", "chrome", "firefox", "safari"].contains(where: { n.contains($0) }) { return RemixIcons.ComputerLine }
    if n.contains("android") { return RemixIcons.AndroidLine }
    return RemixIcons.SmartphoneLine
}

private struct SessionRow: View {
    let session: SessionDto
    let onTerminate: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let successColor = SiteStatusColors.Success
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                SiteIconBadge(
                    icon: sessionDeviceIcon(session.name),
                    size: 44,
                    iconSize: 22,
                    tint: session.isCurrent ? successColor : colors.primary
                )
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.name ?? "دستگاه ناشناس")
                        .shkFont(14, .bold)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if session.isCurrent {
                        Spacer().frame(height: 4)
                        SiteStatusChip(text: "همین دستگاه", color: successColor, icon: RemixIcons.CheckboxCircleLine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer().frame(height: 12)
            SiteDashedDivider()
            Spacer().frame(height: 10)
            SessionInfoLine(icon: RemixIcons.TimeLine, text: "آخرین فعالیت: \(session.lastUsedAt?.toPersianDigits() ?? "نامشخص")")
            if let createdAt = session.createdAt, !createdAt.isBlankShk {
                Spacer().frame(height: 4)
                SessionInfoLine(icon: RemixIcons.LoginBoxLine, text: "زمان ورود: \(createdAt.toPersianDigits())")
            }
            Spacer().frame(height: 12)
            SiteSecondaryButton(
                text: "پایان نشست",
                onClick: onTerminate,
                icon: RemixIcons.LogoutBoxRLine,
                color: colors.error,
                height: 40,
                fontSize: 13,
                fillWidth: true
            )
        }
        .padding(14)
        .background(shape.fill(colors.surface))
        .overlay(shape.strokeBorder(session.isCurrent ? successColor.opacity(0.6) : Color.clear, lineWidth: 1))
    }
}

private struct SessionInfoLine: View {
    let icon: String
    let text: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(icon, tint: colors.onSurfaceVariant, size: 15)
            Spacer().frame(width: 6)
            Text(text).shkFont(12).foregroundColor(colors.onSurfaceVariant)
        }
    }
}
