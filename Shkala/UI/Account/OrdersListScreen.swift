import SwiftUI

// ===================================================================================
// معادل ui/account/OrdersListScreen.kt
// بازطراحی «سفارش‌های من»: نوار بالا، باکس جستجوی هم‌شکل صفحه‌ی اصلی، فیلتر وضعیت به شکل
// چیپ‌های افقی، و کارت هر سفارش (شماره، تاریخ، فروشنده، تگ وضعیت رنگی با آیکن، نقطه‌ی «جدید»).
// نکته: API لیست سفارش‌ها (account/orders) تصویر اقلام و مبلغ سفارش رو برنمی‌گردونه، برای همین
// این دو مورد فقط در صفحه‌ی جزئیات نمایش داده می‌شن.
// سفارش‌های ردشده‌ی کارت‌به‌کارت/هماهنگی (rejected_orders صفحه‌ی ۱ همون API): اسکریپت خودِ سفارش رو
// هنگام رد حذف می‌کنه، پس این‌ها فقط یک نسخه‌ی ذخیره‌شده‌ان و بعد از سفارش‌های عادی، زیر سرتیتر
// «سفارش‌های رد شده» نمایش داده می‌شن (تاریخ‌شون فقط رشته‌ی شمسیه و قابل ادغام دقیق نیست).
// با لمس هرکدوم یک باتم‌شیت جزئیات باز می‌شه (صفحه‌ی جزئیات سفارش عادی برای این‌ها وجود نداره).
// ===================================================================================

/** دسته‌های فیلتر وضعیت (فقط سمت اپ، روی همون لیست دریافتی) */
private enum OrderFilter: CaseIterable {
    case All, Active, Sent, Completed, Cancelled, Rejected

    var title: String {
        switch self {
        case .All: return "همه"
        case .Active: return "جاری"
        case .Sent: return "ارسال شده"
        case .Completed: return "تکمیل‌شده"
        case .Cancelled: return "لغو و مرجوع"
        case .Rejected: return "رد شده"
        }
    }

    var icon: String {
        switch self {
        case .All: return RemixIcons.ListCheck2
        case .Active: return RemixIcons.Loader4Line
        case .Sent: return RemixIcons.TruckLine
        case .Completed: return RemixIcons.CheckboxCircleLine
        case .Cancelled: return RemixIcons.CloseCircleLine
        case .Rejected: return RemixIcons.ForbidLine
        }
    }
}

private func orderFilterOf(_ order: OrderSummaryDto) -> OrderFilter {
    switch orderStageOf(order.status, order.startProcess, order.sentAtTimestamp, order.updatedAtTimestamp) {
    case .Sent: return .Sent
    case .Completed: return .Completed
    case .Cancelled, .Returned: return .Cancelled
    default: return .Active
    }
}

/*
 * مراحل واقعی سفارش در سایت (Order.status + start_process):
 *   ۱) registered و start_process=false → «در انتظار بررسی»
 *   ۲) registered و start_process=true  → «در حال پردازش»
 *   ۳) sent (ثبت زمان در sent_at)       → «ارسال شده»
 * (به‌علاوه‌ی cancelled و returned). سایت وضعیت delivered هم داره که فقط در دو حالت ست می‌شه:
 * تحویل حضوری (ادمین مستقیم delivered می‌زنه) و به‌صورت خودکار بعد از گذشت «آزادسازی مبالغ سفارشات»
 * روز از sent_at (HandleCartMiddleware).
 *
 * «تکمیل‌شده» دقیقاً طبق خودِ اسکریپت: فقط وقتی که وضعیت سفارش در سرور delivered باشه.
 * (اسکریپت خودش سفارش‌های ارسال‌شده رو بعد از گذشت «آزادسازی مبالغ سفارشات» روز - الان ۳۰ روز -
 * از sent_at، به delivered تغییر می‌ده؛ اپ هیچ تصمیمی نمی‌گیره و فقط وضعیت سرور رو نمایش می‌ده.)
 */
enum OrderStage { case Review, Processing, Sent, Completed, Cancelled, Returned, Other }

private let sentStatuses: Set<String> = ["sent_to_customer", "direct_sent_to_customer", "sent"]

func orderStageOf(_ status: String, _ startProcess: Bool?, _ sentAtTimestamp: Int64?, _ updatedAtTimestamp: Int64?) -> OrderStage {
    switch status {
    // اگه سرور start_process رو نفرسته (نسخه‌ی قدیمی API)، مثل قبل «در حال پردازش»
    case "registered": return startProcess == false ? .Review : .Processing
    case "processing": return .Processing
    case _ where sentStatuses.contains(status): return .Sent
    // تکمیل‌شده فقط با وضعیت خودِ سرور (قانون ۳۰ روزه‌ی اسکریپت)
    case "delivered": return .Completed
    case "cancelled": return .Cancelled
    case "returned": return .Returned
    default: return .Other
    }
}

/** متن ساده‌ی دلیل لغو (سایت ممکنه HTML ذخیره کرده باشه)؛ null اگه خالی باشه */
func plainCancelReason(_ raw: String?) -> String? {
    guard let raw, !raw.isBlankShk else { return nil }
    let text = htmlToPlainText(raw).trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
}

struct OrdersListScreen: View {
    let onBack: () -> Void
    let onOrderClick: (Int) -> Void

    @Environment(\.shkColors) private var colors
    @ObservedObject private var navigator = AppNavigator.shared
    @ObservedObject private var viewedOrders = ViewedOrdersManager.shared
    private let repository = AccountRepository()

    @State private var orderGroups: [OrderGroupDto] = []
    @State private var rejectedOrders: [RejectedOrderDto] = []
    // سفارش ردشده‌ای که باتم‌شیت جزئیاتش بازه
    @State private var selectedRejected: RejectedOrderDto? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var searchText = ""
    @State private var selectedFilter: OrderFilter = .All
    @State private var ownDepth: Int? = nil

    private var filteredGroups: [OrderGroupDto] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if searchText.isBlankShk { return orderGroups }
        return orderGroups.compactMap { group in
            let matching = group.orders.filter { $0.uuid.contains(query) }
            if matching.isEmpty { return nil }
            var copy = group
            copy.orders = matching
            return copy
        }
    }

    // سفارش‌های نهایی بعد از جستجو + فیلتر وضعیت
    private var visibleOrders: [OrderSummaryDto] {
        filteredGroups.flatMap(\.orders).filter { selectedFilter == .All || orderFilterOf($0) == selectedFilter }
    }

    // سفارش‌های ردشده بعد از جستجو (بر اساس شماره‌ی سفارش)
    private var filteredRejected: [RejectedOrderDto] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? rejectedOrders : rejectedOrders.filter { ($0.uuid ?? "").contains(query) }
    }

    // ردشده‌ها فقط زیر «همه» و «رد شده» نمایش داده می‌شن
    private var visibleRejected: [RejectedOrderDto] {
        selectedFilter == .All || selectedFilter == .Rejected ? filteredRejected : []
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "سفارش‌های من", onBack: onBack)

            SiteSearchField(value: $searchText, placeholder: "جستجو بر اساس شماره سفارش...")
                .padding(.horizontal, 16)

            // فیلتر وضعیت - چیپ‌های افقی با تعداد هر دسته
            if !isLoading && errorMessage == nil && (!orderGroups.isEmpty || !rejectedOrders.isEmpty) {
                let allOrders = filteredGroups.flatMap(\.orders)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(OrderFilter.allCases, id: \.self) { filter in
                            let count: Int = {
                                switch filter {
                                case .All: return allOrders.count + filteredRejected.count
                                case .Rejected: return filteredRejected.count
                                default: return allOrders.filter { orderFilterOf($0) == filter }.count
                                }
                            }()
                            OrderFilterChip(
                                title: filter.title, icon: filter.icon, count: count,
                                selected: selectedFilter == filter, onClick: { selectedFilter = filter }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            } else {
                Spacer().frame(height: 12)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(colors.background)
        .task {
            if ownDepth == nil { ownDepth = navigator.stack.count }
            await load()
        }
        // معادل ترکیب دوباره‌ی صفحه بعد از برگشت از جزئیات سفارش (صفحه از اول ساخته و بارگذاری می‌شه)
        .onChange(of: navigator.stack.count) { count in
            if count == ownDepth {
                searchText = ""
                selectedFilter = .All
                Task { await load() }
            }
        }
        .sheet(item: $selectedRejected) { order in
            RejectedOrderSheet(order: order, onDismiss: { selectedRejected = nil })
                .shkSheetEnvironment()
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            SiteLoading(message: "در حال دریافت سفارش‌ها...", icon: RemixIcons.ShoppingBag3Line)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            SiteEmptyState(
                icon: RemixIcons.WifiOffLine,
                title: "دریافت سفارش‌ها ممکن نشد",
                subtitle: errorMessage,
                actionLabel: "تلاش دوباره",
                actionIcon: RemixIcons.RefreshLine,
                onAction: { Task { await load() } }
            )
            .padding(16)
        } else if orderGroups.isEmpty && rejectedOrders.isEmpty {
            // حالت «بدون سفارش» هم با کشیدن صفحه دوباره بارگذاری می‌شه
            ScrollView {
                SiteEmptyState(icon: RemixIcons.ShoppingBag3Line, title: "هنوز سفارشی ثبت نکرده‌اید", subtitle: nil)
                    .frame(maxWidth: .infinity)
                    .padding(16)
            }
            .refreshable { await pullRefresh() }
        } else if filteredGroups.isEmpty && filteredRejected.isEmpty {
            SiteEmptyState(icon: RemixIcons.Search2Line, title: "سفارشی با این شماره پیدا نشد", subtitle: nil)
                .padding(.horizontal, 16)
        } else if visibleOrders.isEmpty && visibleRejected.isEmpty {
            SiteEmptyState(icon: selectedFilter.icon, title: "سفارشی با وضعیت «\(selectedFilter.title)» ندارید", subtitle: nil)
                .padding(.horizontal, 16)
        } else {
            // کشیدن صفحه به پایین برای بروزرسانی سفارش‌ها
            ScrollView {
                LazyVStack(spacing: 10) {
                    // اصلاحیه (پیشگیری از کرش «Key already used»): اگه سرور به هر دلیلی یک آیتم رو دوبار (یا با شناسه‌ی تکراری) بفرسته، اینجا یکتا می‌شه
                    ForEach(distinct(visibleOrders, \.id), id: \.id) { order in
                        OrderRow(
                            orderUuid: order.uuid,
                            status: order.status,
                            stage: orderStageOf(order.status, order.startProcess, order.sentAtTimestamp, order.updatedAtTimestamp),
                            cancelReason: order.status == "cancelled" ? plainCancelReason(order.cancelReason) : nil,
                            sendBy: order.sendBy,
                            jalaliDate: order.jalaliCreatedAt.jalaliDateLabel(),
                            isViewed: viewedOrders.viewedOrderIds.contains(String(order.id)),
                            onClick: { onOrderClick(order.id) }
                        )
                    }
                    if !visibleRejected.isEmpty {
                        // سرتیتر جدا فقط وقتی سفارش عادی هم بالاش هست
                        if !visibleOrders.isEmpty {
                            RejectedSectionHeader(count: visibleRejected.count)
                        }
                        ForEach(Array(visibleRejected.enumerated()), id: \.offset) { _, order in
                            RejectedOrderRow(order: order, onClick: { selectedRejected = order })
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable { await pullRefresh() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        switch await repository.getMyOrdersPage(1) {
        case .success(let data):
            orderGroups = data.orderGroups
            rejectedOrders = data.rejectedOrders ?? []
        case .error(let message):
            errorMessage = message
        }
        isLoading = false
    }

    // بروزرسانی با کشیدن صفحه: بدون لودینگ تمام‌صفحه؛ اگه خطا بده فهرست فعلی حفظ می‌شه
    private func refresh() async {
        if case .success(let data) = await repository.getMyOrdersPage(1) {
            orderGroups = data.orderGroups
            rejectedOrders = data.rejectedOrders ?? []
            errorMessage = nil
        }
    }

    private func pullRefresh() async {
        if PullRefreshRateLimiter.tryAcquire() {
            await refresh()
        } else {
            ShkToast.shared.show(PULL_REFRESH_LIMIT_MESSAGE, long: true)
        }
    }
}

private struct RejectedSectionHeader: View {
    let count: Int
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(RemixIcons.ForbidLine, tint: colors.error, size: 16)
            Spacer().frame(width: 6)
            Text("سفارش‌های رد شده")
                .shkFont(13, .bold)
                .foregroundColor(colors.onBackground)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(count.toPersianDigits()) سفارش").shkFont(11).foregroundColor(colors.onSurfaceVariant)
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}

/** کارت سفارش ردشده (هم‌شکل کارت سفارش عادی) با تگ قرمز «رد شده»، مبلغ و دلیل رد */
private struct RejectedOrderRow: View {
    let order: RejectedOrderDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let errorColor = colors.error
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let createdAt = order.jalaliCreatedAt.flatMap { $0.isBlankShk ? nil : $0 }
        let rejectedAt = order.jalaliRejectedAt.flatMap { $0.isBlankShk ? nil : $0 }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.ShoppingBag3Line, size: 42, iconSize: 21, tint: errorColor)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text("سفارش #\((order.uuid ?? "").toPersianDigits())")
                        .shkFont(14, .bold)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer().frame(height: 4)
                    if let createdAt {
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.Calendar2Line, tint: colors.onSurfaceVariant, size: 14)
                            Spacer().frame(width: 4)
                            Text("ثبت: \(createdAt.toPersianDigits())").shkFont(11).foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                        }
                    }
                    if let rejectedAt {
                        Spacer().frame(height: 2)
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.CalendarCloseLine, tint: colors.onSurfaceVariant, size: 14)
                            Spacer().frame(width: 4)
                            Text("رد: \(rejectedAt.toPersianDigits())").shkFont(11).foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 22)
            }
            Spacer().frame(height: 12)
            SiteDashedDivider()
            Spacer().frame(height: 10)
            HStack(spacing: 0) {
                SiteStatusChip(text: "رد شده", color: errorColor, icon: RemixIcons.ForbidLine)
                Spacer(minLength: 0)
                if let amount = order.amount {
                    Text("\(formatTomanFa(amount)) تومان")
                        .shkFont(13, .bold)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(1)
                }
            }
            Spacer().frame(height: 8)
            HStack(spacing: 0) {
                RemixIcon(RemixIcons.InformationLine, tint: errorColor, size: 14)
                Spacer().frame(width: 5)
                Text("دلیل رد: \(rejectedOrderReason(order).replacingOccurrences(of: "\n", with: " "))")
                    .shkFont(11)
                    .foregroundColor(errorColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(colors.surface))
        .contentShape(shape)
        .onTapGesture(perform: onClick)
    }
}

private struct OrderFilterChip: View {
    let title: String
    let icon: String
    let count: Int
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let bg = selected ? colors.primary : colors.surface
        let fg = selected ? Color.white : colors.onSurfaceVariant
        HStack(spacing: 0) {
            RemixIcon(icon, tint: fg, size: 16)
            Spacer().frame(width: 5)
            Text(title).shkFont(12, selected ? .bold : .medium).foregroundColor(fg).lineLimit(1)
            Spacer().frame(width: 6)
            Text(count.toPersianDigits())
                .shkFont(10, .bold, lineHeight: 14)
                .foregroundColor(fg)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(selected ? Color.white.opacity(0.22) : colors.surfaceVariant))
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bg))
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onClick)
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

private struct OrderRow: View {
    let orderUuid: String
    let status: String
    let stage: OrderStage
    let cancelReason: String?
    let sendBy: String?
    let jalaliDate: String?
    let isViewed: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let newOrderColor = SiteStatusColors.Success
        let info = orderStatusInfo(status, stage, colors)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.ShoppingBag3Line, size: 42, iconSize: 21, tint: info.color)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("سفارش #\(String(orderUuid.prefix(8)).toPersianDigits())")
                            .shkFont(14, .bold)
                            .foregroundColor(colors.onSurface)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if !isViewed {
                            // نقطه‌ی سبز «جدید / دیده‌نشده»
                            Spacer().frame(width: 6)
                            Circle().fill(newOrderColor).frame(width: 8, height: 8)
                        }
                    }
                    Spacer().frame(height: 4)
                    HStack(spacing: 0) {
                        if let jalaliDate, !jalaliDate.isBlankShk {
                            RemixIcon(RemixIcons.Calendar2Line, tint: colors.onSurfaceVariant, size: 14)
                            Spacer().frame(width: 4)
                            Text(jalaliDate).shkFont(11).foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                        }
                        if let sendBy, !sendBy.isBlankShk {
                            Spacer().frame(width: 10)
                            RemixIcon(RemixIcons.Store2Line, tint: colors.onSurfaceVariant, size: 14)
                            Spacer().frame(width: 4)
                            Text(sendBy).shkFont(11).foregroundColor(colors.onSurfaceVariant).lineLimit(1).truncationMode(.tail)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 22)
            }
            Spacer().frame(height: 12)
            SiteDashedDivider()
            Spacer().frame(height: 10)
            HStack(spacing: 6) {
                SiteStatusChip(text: info.label, color: info.color, icon: info.icon)
                ViewedBadge(isViewed: isViewed)
            }
            // دلیل لغو (فقط سفارش‌های لغوشده و فقط اگه سایت دلیلی ثبت کرده باشه) - یک خط کوتاه
            if let cancelReason, !cancelReason.isBlankShk {
                Spacer().frame(height: 8)
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.InformationLine, tint: colors.error, size: 14)
                    Spacer().frame(width: 5)
                    Text("دلیل لغو: \(cancelReason.replacingOccurrences(of: "\n", with: " "))")
                        .shkFont(11)
                        .foregroundColor(colors.error)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(colors.surface))
        .overlay(shape.stroke(!isViewed ? newOrderColor.opacity(0.7) : .clear, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture(perform: onClick)
    }
}

private struct ViewedBadge: View {
    let isViewed: Bool
    var body: some View {
        SiteStatusChip(
            text: isViewed ? "مشاهده شده" : "مشاهده کنید",
            color: isViewed ? SiteStatusColors.Neutral : SiteStatusColors.Success,
            icon: isViewed ? RemixIcons.CheckDoubleLine : RemixIcons.EyeLine
        )
    }
}

/** تگ وضعیت سفارش (StatusBadge اندروید) */
struct StatusBadge: View {
    let status: String
    var startProcess: Bool? = nil
    var sentAtTimestamp: Int64? = nil
    var updatedAtTimestamp: Int64? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        let info = orderStatusInfo(status, orderStageOf(status, startProcess, sentAtTimestamp, updatedAtTimestamp), colors)
        SiteStatusChip(text: info.label, color: info.color, icon: info.icon)
    }
}

/** برچسب، رنگ و آیکن هر وضعیت سفارش (برای تگ وضعیت و کارت‌ها) */
struct OrderStatusInfo {
    let label: String
    let color: Color
    let icon: String
}

/** برچسب/رنگ/آیکن بر اساس مرحله (وضعیت delivered سرور با عنوان «تکمیل‌شده» نمایش داده می‌شه) */
func orderStatusInfo(_ status: String, _ stage: OrderStage, _ colors: ShkColorScheme) -> OrderStatusInfo {
    switch stage {
    case .Review: return OrderStatusInfo(label: "در انتظار بررسی", color: SiteStatusColors.Neutral, icon: RemixIcons.TimeLine)
    case .Processing: return OrderStatusInfo(label: "در حال پردازش", color: SiteStatusColors.Warning, icon: RemixIcons.Loader4Line)
    case .Sent: return OrderStatusInfo(label: "ارسال شده", color: SiteStatusColors.Info, icon: RemixIcons.TruckLine)
    case .Completed: return OrderStatusInfo(label: "تکمیل‌شده", color: SiteStatusColors.Success, icon: RemixIcons.CheckboxCircleLine)
    default: return orderStatusInfo(status, colors)
    }
}

/** برچسب خام هر وضعیت سرور */
func orderStatusInfo(_ status: String, _ colors: ShkColorScheme) -> OrderStatusInfo {
    switch status {
    case "awaiting": return OrderStatusInfo(label: "در انتظار پرداخت", color: colors.error, icon: RemixIcons.TimeLine)
    case "prefactor": return OrderStatusInfo(label: "پیش‌فاکتور", color: SiteStatusColors.Neutral, icon: RemixIcons.FileList3Line)
    case "registered", "processing": return OrderStatusInfo(label: "در حال پردازش", color: SiteStatusColors.Warning, icon: RemixIcons.Loader4Line)
    case "sent_to_customer", "direct_sent_to_customer", "sent": return OrderStatusInfo(label: "ارسال شده", color: SiteStatusColors.Info, icon: RemixIcons.TruckLine)
    case "delivered": return OrderStatusInfo(label: "تکمیل‌شده", color: SiteStatusColors.Success, icon: RemixIcons.CheckboxCircleLine)
    case "cancelled": return OrderStatusInfo(label: "لغو شده", color: colors.error, icon: RemixIcons.CloseCircleLine)
    case "returned": return OrderStatusInfo(label: "مرجوع شده", color: colors.error, icon: RemixIcons.ArrowGoBackLine)
    default: return OrderStatusInfo(label: status, color: SiteStatusColors.Neutral, icon: RemixIcons.InformationLine)
    }
}
