import SwiftUI

// معادل ui/ticket/TicketsListScreen.kt

private enum TicketFilter: CaseIterable {
    case ALL, WAITING_ADMIN, WAITING_USER, CLOSED

    var label: String {
        switch self {
        case .ALL: return "همه"
        case .WAITING_ADMIN: return "در انتظار پشتیبانی"
        case .WAITING_USER: return "در انتظار پاسخ من"
        case .CLOSED: return "بسته‌شده"
        }
    }

    var icon: String {
        switch self {
        case .ALL: return RemixIcons.InboxLine
        case .WAITING_ADMIN: return RemixIcons.CustomerService2Line
        case .WAITING_USER: return RemixIcons.ChatHistoryLine
        case .CLOSED: return RemixIcons.LockLine
        }
    }
}

private struct TicketsQuery: Equatable {
    let search: String
    let filter: TicketFilter
}

/**
 * فهرست تیکت‌های پشتیبانی - بازطراحی با قالب جدید: نوار بالا با دکمه‌ی برگشت کادردار،
 * باکس جستجوی هم‌شکل صفحه‌ی اصلی، فیلترهای قرصی، کارت تیکت با شماره/تاریخ/اولویت/وضعیت
 * و دکمه‌ی شناور «تیکت جدید». منطق دریافت و بروزرسانی خودکار دست‌نخورده است.
 */
struct TicketsListScreen: View {
    let onBack: () -> Void
    let onOpenTicket: (Int) -> Void
    let onCreateTicket: () -> Void

    @Environment(\.shkColors) private var colors
    private let repository = TicketRepository()

    @State private var searchText = ""
    @State private var selectedFilter: TicketFilter = .ALL
    @State private var tickets: [TicketDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private func fetch() async -> ApiResult<[TicketDto]> {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        return await repository.getTickets(
            search: q.isEmpty ? nil : q,
            waitingAdmin: selectedFilter == .WAITING_ADMIN ? true : nil,
            waitingUser: selectedFilter == .WAITING_USER ? true : nil,
            closed: selectedFilter == .CLOSED ? true : nil
        )
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                SitePageTopBar(
                    title: "تیکت‌های پشتیبانی",
                    onBack: onBack,
                    subtitle: (!isLoading && errorMessage == nil && !tickets.isEmpty) ? "\(tickets.count.toPersianDigits()) تیکت" : nil
                )

                // باکس جستجو - هم‌شکل جستجوی صفحه‌ی اصلی
                SiteSearchField(value: $searchText, placeholder: "جستجو بر اساس عنوان تیکت...")
                    .padding(.horizontal, 16)

                // فیلترهای وضعیت
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TicketFilter.allCases, id: \.self) { filter in
                            TicketFilterPill(filter: filter, selected: selectedFilter == filter) { selectedFilter = filter }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Group {
                    if isLoading {
                        SiteLoading(message: "در حال دریافت تیکت‌ها", icon: RemixIcons.CustomerService2Line)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage {
                        VStack {
                            SiteEmptyState(icon: RemixIcons.WifiOffLine, title: "دریافت تیکت‌ها ممکن نشد", subtitle: errorMessage)
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                    } else if tickets.isEmpty {
                        VStack {
                            SiteEmptyState(
                                icon: RemixIcons.CustomerService2Line,
                                title: "تیکتی پیدا نشد",
                                subtitle: (!searchText.trimmingCharacters(in: .whitespaces).isEmpty || selectedFilter != .ALL)
                                    ? "با جستجو یا فیلتر دیگری امتحان کنید."
                                    : "برای طرح سؤال یا مشکل خود، یک تیکت جدید ثبت کنید.",
                                actionLabel: "ثبت تیکت جدید",
                                actionIcon: RemixIcons.AddLine,
                                onAction: onCreateTicket
                            )
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                    } else {
                        // کشیدن صفحه به پایین: فهرست با همون جستجو/فیلتر فعلی بی‌صدا تازه می‌شه
                        // (در صورت خطا فهرست قبلی حفظ می‌شه)
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(tickets.uniqueById()) { ticket in
                                    TicketRow(ticket: ticket, onClick: { onOpenTicket(ticket.id) })
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 2)
                            .padding(.bottom, 96)
                        }
                        .sitePullRefresh {
                            if case .success(let data) = await fetch() { tickets = data }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }

            // دکمه‌ی شناور ثبت تیکت جدید
            SitePrimaryButton(text: "تیکت جدید", onClick: onCreateTicket, icon: RemixIcons.AddLine)
                .fixedSize()
                .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task(id: TicketsQuery(search: searchText, filter: selectedFilter)) {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            isLoading = true
            errorMessage = nil
            switch await fetch() {
            case .success(let data): tickets = data
            case .error(let message): errorMessage = message
            }
            isLoading = false

            // بعد از لود اولیه، هر ۵ ثانیه بی‌صدا (بدون نمایش لودینگ) بررسی
            // می‌کنه وضعیت تیکت‌ها تغییری کرده یا نه (پاسخ جدید و ...)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                if Task.isCancelled { return }
                if case .success(let data) = await fetch() { tickets = data }
            }
        }
    }
}

private struct TicketFilterPill: View {
    let filter: TicketFilter
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let fg: Color = selected ? .white : colors.onSurfaceVariant
        Button(action: onClick) {
            HStack(spacing: 6) {
                RemixIcon(filter.icon, tint: fg, size: 16)
                Text(filter.label).shkFont(12, selected ? .bold : .medium).foregroundColor(fg).lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? colors.primary : colors.surface))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

/** رنگ، عنوان و آیکن وضعیت تیکت */
func ticketStatusStyle(_ status: String, _ colors: ShkColorScheme) -> (String, Color, String) {
    switch status {
    case "waiting_admin": return ("در انتظار پشتیبانی", SiteStatusColors.Info, RemixIcons.TimeLine)
    case "waiting_user": return ("در انتظار پاسخ شما", SiteStatusColors.Warning, RemixIcons.ChatHistoryLine)
    case "closed": return ("بسته‌شده", SiteStatusColors.Neutral, RemixIcons.LockLine)
    default: return (status, colors.onSurfaceVariant, RemixIcons.InformationLine)
    }
}

/** رنگ و عنوان اولویت تیکت */
func ticketPriorityStyle(_ priority: String, _ colors: ShkColorScheme) -> (String, Color) {
    switch priority {
    case "high": return ("زیاد", colors.primary)
    case "normal": return ("متوسط", SiteStatusColors.Warning)
    case "low": return ("کم", SiteStatusColors.Success)
    default: return (priority, colors.onSurfaceVariant)
    }
}

private struct TicketRow: View {
    let ticket: TicketDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let (statusLabel, statusColor, statusIcon) = ticketStatusStyle(ticket.status, colors)
        let (priorityLabel, priorityColor) = ticketPriorityStyle(ticket.priority, colors)
        // تیکت‌هایی که منتظر پاسخ کاربر هستن با حاشیه‌ی رنگی و نقطه‌ی چشمک‌زن برجسته می‌شن
        let needsReply = ticket.status == "waiting_user"
        let isClosed = ticket.status == "closed"

        SiteCard(onClick: onClick, borderColor: needsReply ? SiteStatusColors.Warning.opacity(0.45) : nil) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    SiteIconBadge(icon: RemixIcons.TicketLine, size: 42, tint: statusColor)
                    Spacer().frame(width: 12)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Text(ticket.title)
                                .shkFont(13, .bold, lineHeight: 22)
                                .foregroundColor(isClosed ? colors.onSurfaceVariant : colors.onSurface)
                                .lineLimit(2)
                                .truncationMode(.tail)
                            if needsReply { PulsingDot(color: SiteStatusColors.Warning) }
                        }
                        Spacer().frame(height: 4)
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.Hashtag, tint: colors.onSurfaceVariant, size: 13)
                            Text(ticket.id.toPersianDigits()).shkFont(11).foregroundColor(colors.onSurfaceVariant)
                            if let date = ticket.jalaliUpdatedAt.jalaliDateLabel(), !date.trimmingCharacters(in: .whitespaces).isEmpty {
                                Spacer().frame(width: 10)
                                RemixIcon(RemixIcons.CalendarLine, tint: colors.onSurfaceVariant, size: 13)
                                Spacer().frame(width: 4)
                                Text(date.toPersianDigits()).shkFont(11).foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(width: 6)
                    RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
                }
                Spacer().frame(height: 12)
                SiteDashedDivider()
                Spacer().frame(height: 10)
                HStack(spacing: 0) {
                    SiteStatusChip(text: "اولویت: \(priorityLabel)", color: priorityColor, icon: RemixIcons.Flag2Line)
                    Spacer(minLength: 0)
                    SiteStatusChip(text: statusLabel, color: statusColor, icon: statusIcon)
                }
            }
        }
    }
}

/** نقطه‌ی تپنده برای برجسته کردن تیکت نیازمند پاسخ */
private struct PulsingDot: View {
    let color: Color
    @State private var bright = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(bright ? 1 : 0.35)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bright = true }
            }
    }
}
