import SwiftUI
import PhotosUI

// معادل ui/ticket/TicketDetailScreen.kt

/** آیتم‌های فهرست گفتگو: جداکننده‌ی تاریخ یا یک پیام */
private enum ChatEntry: Identifiable {
    case dateSeparator(label: String, key: String)
    case message(TicketAnswerDto)

    var id: String {
        switch self {
        case .dateSeparator(_, let key): return key
        case .message(let answer): return "msg_\(answer.id)"
        }
    }
}

/**
 * جزئیات تیکت به‌شکل گفتگو (چت) - بازطراحی با قالب جدید: پیام‌های کاربر در حباب قرمز کم‌رنگ
 * و پیام‌های پشتیبانی در حباب سفید با نشان پشتیبانی، در دو سمت مخالف، جداکننده‌ی تاریخ،
 * و نوار ارسال پایین صفحه (پیوست + فیلد پیام + دکمه‌ی ارسال). منطق ارسال/آپلود/بروزرسانی دست‌نخورده است.
 */
struct TicketDetailScreen: View {
    let ticketId: Int
    let onBack: () -> Void

    @Environment(\.shkColors) private var colors
    private let repository = TicketRepository()

    @State private var ticket: TicketDetailDto? = nil
    @State private var currentUserId: Int? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var replyText = ""
    @State private var isSending = false
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem? = nil

    private func loadNow() async {
        switch await repository.getTicketDetail(ticketId) {
        case .success(let data): ticket = data
        case .error(let message): errorMessage = message
        }
        isLoading = false
    }

    private var entries: [ChatEntry] {
        guard let t = ticket else { return [] }
        var list: [ChatEntry] = []
        var lastDate: String? = nil
        for answer in t.answers {
            let date = answer.jalaliCreatedAt.jalaliDateLabel()
            if let date, !date.trimmingCharacters(in: .whitespaces).isEmpty, date != lastDate {
                list.append(.dateSeparator(label: date, key: "date_\(answer.id)"))
                lastDate = date
            }
            list.append(.message(answer))
        }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: ticket?.title ?? "تیکت", onBack: onBack, subtitle: "تیکت شماره‌ی \(ticketId.toPersianDigits())")

            if isLoading {
                SiteLoading(message: "در حال دریافت گفتگو", icon: RemixIcons.CustomerService2Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, ticket == nil {
                VStack {
                    SiteEmptyState(icon: RemixIcons.WifiOffLine, title: "دریافت تیکت ممکن نشد", subtitle: errorMessage)
                    Spacer(minLength: 0)
                }
                .padding(16)
            } else if let t = ticket {
                let (statusLabel, statusColor, statusIcon) = ticketStatusStyle(t.status, colors)
                let (priorityLabel, priorityColor) = ticketPriorityStyle(t.priority, colors)

                // نوار اطلاعات تیکت: وضعیت، اولویت و تاریخ ایجاد
                HStack(spacing: 8) {
                    SiteStatusChip(text: statusLabel, color: statusColor, icon: statusIcon)
                    SiteStatusChip(text: "اولویت: \(priorityLabel)", color: priorityColor, icon: RemixIcons.Flag2Line)
                    Spacer(minLength: 0)
                    if let created = t.jalaliCreatedAt.jalaliDateLabel(), !created.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(created.toPersianDigits())
                            .shkFont(11)
                            .foregroundColor(colors.onSurfaceVariant)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.surface))
                .padding(.horizontal, 16)

                // فهرست پیام‌ها با جداکننده‌ی تاریخ
                let list = entries
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(list) { entry in
                                switch entry {
                                case .dateSeparator(let label, _):
                                    DateSeparatorChip(label: label)
                                case .message(let answer):
                                    AnswerBubble(answer: answer, isMine: currentUserId != nil && answer.userId == currentUserId)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    // کشیدن صفحه به پایین: گفتگو بی‌صدا از سرور تازه می‌شه
                    .sitePullRefresh { await loadNow() }
                    // با رسیدن پیام جدید، فهرست به آخرین پیام اسکرول می‌شه
                    .onChange(of: list.count) { _ in
                        if let last = list.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    .onAppear {
                        if let last = list.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if t.status == "closed" {
                    HStack(spacing: 8) {
                        RemixIcon(RemixIcons.LockLine, tint: colors.onSurfaceVariant, size: 18)
                        Text("این تیکت بسته شده است")
                            .shkFont(13, .medium)
                            .foregroundColor(colors.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.surface))
                    .padding(16)
                } else {
                    // نوار ارسال پیام
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            ComposerButton(icon: RemixIcons.AttachmentLine, contentDescription: "پیوست", enabled: !isSending, filled: false) {
                                showPicker = true
                            }
                            SiteTextField(value: $replyText, placeholder: "پیام خود را بنویسید...", singleLine: true)
                                .frame(maxWidth: .infinity)
                            ComposerButton(icon: RemixIcons.SendPlane2Fill, contentDescription: "ارسال", enabled: !isSending, filled: true, loading: isSending) {
                                sendReply()
                            }
                        }
                        HStack(spacing: 4) {
                            RemixIcon(RemixIcons.ImageLine, tint: colors.onSurfaceVariant, size: 13)
                            Text("حداکثر حجم پیوست: ۵ مگابایت - فرمت JPG یا PNG").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                        }
                        .padding(.top, 6)
                        .padding(.leading, 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .background(TopRoundedShape(radius: 20).fill(colors.surface).ignoresSafeArea(edges: .bottom))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                defer { pickerItem = nil }
                guard let data = await loadPickedImageData(item) else { return }
                if let error = validateImageUpload(data) {
                    ShkToast.shared.show(error)
                    return
                }
                isSending = true
                switch await repository.sendAttachment(ticketId, attachment: data) {
                case .success: await loadNow()
                case .error(let message): ShkToast.shared.show(message)
                }
                isSending = false
            }
        }
        .task(id: ticketId) {
            if let r = try? await ApiService.me(), r.isSuccessful { currentUserId = r.body?.user?.id }
            await loadNow()
        }
        // چک کردن لحظه‌ای پیام جدید - هر ۲ ثانیه، بدون نشون‌دادن لودینگ (silently)
        .task(id: ticketId) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if Task.isCancelled { return }
                if ticket?.status != "closed" {
                    if case .success(let data) = await repository.getTicketDetail(ticketId) { ticket = data }
                }
            }
        }
    }

    private func sendReply() {
        if replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        let text = replyText
        replyText = ""
        isSending = true
        Task {
            switch await repository.answerTicket(ticketId, content: text) {
            case .success: await loadNow()
            case .error(let message): ShkToast.shared.show(message)
            }
            isSending = false
        }
    }
}

/** دکمه‌های نوار ارسال (پیوست / ارسال) */
private struct ComposerButton: View {
    let icon: String
    let contentDescription: String
    let enabled: Bool
    let filled: Bool
    var loading: Bool = false
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    init(icon: String, contentDescription: String, enabled: Bool, filled: Bool, loading: Bool = false, onClick: @escaping () -> Void) {
        self.icon = icon
        self.contentDescription = contentDescription
        self.enabled = enabled
        self.filled = filled
        self.loading = loading
        self.onClick = onClick
    }

    var body: some View {
        let primary = colors.primary
        Button(action: onClick) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(filled ? primary : primary.opacity(0.1))
                if loading {
                    MaterialSpinner(color: filled ? .white : primary, lineWidth: 2, size: 20)
                } else {
                    // آیکن «ارسال» در اپ راست‌به‌چپ باید به سمت چپ باشه؛ برای همین افقی قرینه می‌شه
                    RemixIcon(icon, contentDescription: contentDescription, tint: filled ? .white : primary, size: 21)
                        .scaleEffect(x: icon == RemixIcons.SendPlane2Fill ? -1 : 1, y: 1)
                }
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/** جداکننده‌ی تاریخ بین پیام‌ها */
private struct DateSeparatorChip: View {
    let label: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        Text(label.toPersianDigits())
            .shkFont(11, .medium)
            .foregroundColor(colors.onSurfaceVariant)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surface))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}

private struct AnswerBubble: View {
    let answer: TicketAnswerDto
    let isMine: Bool
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        // ساعت پیام (از قالب «H:i - Y/m/d» سرور)
        let time: String? = {
            if let list = answer.jalaliCreatedAt, list.count > 2, case .string(let s) = list[2] {
                return s.components(separatedBy: " - ").first?.trimmingCharacters(in: .whitespaces)
            }
            return answer.jalaliCreatedAt.jalaliDateLabel()
        }()
        // پیام کاربر سمت پایان (چپ) و پیام پشتیبانی سمت شروع (راست) - مثل نسخه‌ی قبلی
        let bubbleShape = BubbleShape(isMine: isMine)

        HStack(alignment: .bottom, spacing: 0) {
            if isMine { Spacer(minLength: 0) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 0) {
                if !isMine {
                    HStack(spacing: 6) {
                        SiteIconBadge(icon: RemixIcons.CustomerService2Line, size: 22, iconSize: 13, radius: 11)
                        Text(answer.user?.name ?? "پشتیبانی")
                            .shkFont(11, .bold)
                            .foregroundColor(primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.bottom, 4)
                }
                VStack(alignment: .leading, spacing: 0) {
                    if answer.type == "file", let file = answer.file {
                        RemoteImage(file.link, contentDescription: file.alt, contentScale: .crop)
                            .frame(width: 180, height: 180)
                            .background(colors.surfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        if let name = file.name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                            Spacer().frame(height: 6)
                            HStack(spacing: 4) {
                                RemixIcon(RemixIcons.AttachmentLine, tint: colors.onSurfaceVariant, size: 13)
                                Text(name).shkFont(10).foregroundColor(colors.onSurfaceVariant).lineLimit(1).truncationMode(.tail)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: 180, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.surfaceVariant))
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    } else {
                        Text(answer.content ?? "")
                            .shkFont(13, lineHeight: 23)
                            .foregroundColor(colors.onSurface)
                    }
                    if let time, !time.trimmingCharacters(in: .whitespaces).isEmpty {
                        Spacer().frame(height: 4)
                        Text(time.toPersianDigits()).shkFont(10).foregroundColor(colors.onSurfaceVariant)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(bubbleShape.fill(isMine ? primary.opacity(0.1) : colors.surface))
            }
            .frame(maxWidth: 290, alignment: isMine ? .trailing : .leading)
            if !isMine { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity)
    }
}

/// شکل حباب پیام: گوشه‌ی پایین سمت فرستنده تیزتر (۴) - جهت‌ها مثل RoundedCornerShape با start/end در RTL
private struct BubbleShape: Shape {
    let isMine: Bool

    func path(in rect: CGRect) -> Path {
        // در اپ راست‌به‌چپ: start = راست، end = چپ
        // پیام من: bottomEnd = 4 ← پایین چپ؛ پیام پشتیبانی: bottomStart = 4 ← پایین راست
        let bl: CGFloat = isMine ? 4 : 16
        let br: CGFloat = isMine ? 16 : 4
        let r: CGFloat = 16
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br), radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl), radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}
