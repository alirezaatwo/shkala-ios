import SwiftUI

// ===================================================================================
// معادل ui/account/OrderDetailScreen.kt
// بازطراحی جزئیات سفارش: کارت خلاصه (شماره، تاریخ، وضعیت + مراحل سفارش)، کارت ارسال و پرداخت،
// دکمه‌های فاکتور/رسید، کارت گیرنده، اقلام هر مرسوله با تصویر، و خلاصه‌ی مالی. همه‌ی مودال‌ها SiteDialog.
// ===================================================================================

struct OrderDetailScreen: View {
    let orderId: Int
    let onBack: () -> Void
    let onProductClick: (String) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = AccountRepository()

    @State private var order: OrderDetailDto? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(
                title: "جزئیات سفارش",
                onBack: onBack,
                subtitle: order.map { "#\($0.uuid.toPersianDigits())" }
            )

            if isLoading {
                SiteLoading(message: "در حال دریافت جزئیات سفارش...", icon: RemixIcons.FileList3Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let order, errorMessage == nil {
                // کشیدن صفحه به پایین برای بروزرسانی جزئیات سفارش
                OrderDetailContent(order: order, orderId: orderId, onProductClick: onProductClick)
                    .refreshable { await pullRefresh() }
            } else {
                // حالت خطا دکمه‌ی تلاش مجدد نداره، پس با کشیدن صفحه دوباره بارگذاری می‌شه
                ScrollView {
                    SiteEmptyState(icon: RemixIcons.ErrorWarningLine, title: errorMessage ?? "سفارش یافت نشد.", subtitle: nil)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
                .refreshable { await pullRefresh() }
            }
        }
        .background(colors.background)
        .task(id: orderId) {
            switch await repository.getMyOrderDetail(orderId) {
            case .success(let data):
                order = data
                ViewedOrdersManager.shared.markOrderAsViewed(orderId)
            case .error(let message):
                errorMessage = message
            }
            isLoading = false
        }
    }

    // بروزرسانی با کشیدن صفحه: جزئیات فعلی حفظ می‌شه و خطا فقط با Toast نشون داده می‌شه
    private func refresh() async {
        switch await repository.getMyOrderDetail(orderId) {
        case .success(let data):
            order = data
            errorMessage = nil
        case .error(let message):
            if order == nil {
                errorMessage = message
            } else {
                ShkToast.shared.show(message)
            }
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

/** وضعیت مودال رسید کارت‌به‌کارت (مودال روی کل پنجره رسم می‌شه و باید با تغییر وضعیت به‌روز بشه) */
@MainActor
private final class ReceiptState: ObservableObject {
    @Published var image: UIImage? = nil
    @Published var isLoading = false
}

private struct OrderDetailContent: View {
    let order: OrderDetailDto
    let orderId: Int
    let onProductClick: (String) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = AccountRepository()
    private let catalogRepository = CatalogRepository()
    @StateObject private var receipt = ReceiptState()
    @State private var isLoadingInvoice = false

    // مرحله‌ی سفارش - «تکمیل‌شده» فقط از وضعیت delivered خودِ سرور (توضیح کنار orderStageOf)
    private var stage: OrderStage {
        orderStageOf(order.status, order.startProcess, order.sentAtTimestamp, order.updatedAtTimestamp)
    }

    // دلیل لغو: سایت روی ستون reason اقلام لغوشده ذخیره‌ش می‌کنه؛ اگه API فیلد cancel_reason رو
    // نفرستاد، از همون reason اقلام لغوشده خونده می‌شه. اگه هیچ دلیلی ثبت نشده، چیزی نمایش داده نمی‌شه.
    private var cancelReason: String? {
        guard order.status == "cancelled" else { return nil }
        if let r = plainCancelReason(order.cancelReason) { return r }
        var reasons: [String] = []
        for item in order.consignments.flatMap(\.items) where item.status == "cancelled" {
            if let r = plainCancelReason(item.reason), !reasons.contains(r) { reasons.append(r) }
        }
        let joined = reasons.joined(separator: "\n")
        return joined.isBlankShk ? nil : joined
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ---- کارت خلاصه‌ی سفارش + مراحل ----
                SiteCard {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: RemixIcons.ShoppingBag3Line, size: 44, iconSize: 22)
                        Spacer().frame(width: 12)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("شماره سفارش").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                            Text("#\(order.uuid.toPersianDigits())")
                                .shkFont(14, .bold)
                                .foregroundColor(colors.onSurface)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        let statusInfo = orderStatusInfo(order.status, stage, colors)
                        SiteStatusChip(text: statusInfo.label, color: statusInfo.color, icon: statusInfo.icon)
                    }
                    if let orderDate = order.jalaliCreatedAt.jalaliDateLabel(), !orderDate.isBlankShk {
                        Spacer().frame(height: 10)
                        SiteDashedDivider()
                        SiteKeyValueRow(label: "تاریخ ثبت سفارش", value: orderDate, icon: RemixIcons.Calendar2Line)
                            .padding(.top, 4)
                    }
                    Spacer().frame(height: 8)
                    OrderProgress(status: order.status, stage: stage)
                }

                // ---- دلیل لغو سفارش (کارت قرمز‌رنگ) ----
                if let cancelReason {
                    Spacer().frame(height: 10)
                    CancelReasonCard(reason: cancelReason)
                }

                // ---- ارسال و پرداخت ----
                let sendMethodLabel = order.sendMethod.selectedPostWayTitle()
                let tracking = order.postTrackingCode.flatMap { $0.isBlankShk ? nil : $0 }
                let methodLabel = sendMethodLabel.flatMap { $0.isBlankShk ? nil : $0 }
                let gatewayLabel = order.paymentGatewayLabel.flatMap { $0.isBlankShk ? nil : $0 }
                if tracking != nil || methodLabel != nil || gatewayLabel != nil {
                    Spacer().frame(height: 10)
                    SiteCard {
                        CardHeader(icon: RemixIcons.TruckLine, title: "ارسال و پرداخت")
                        Spacer().frame(height: 4)
                        if let tracking {
                            SiteKeyValueRow(label: "کد رهگیری پستی", value: tracking, icon: RemixIcons.BarcodeLine)
                        }
                        if let methodLabel {
                            SiteKeyValueRow(label: "روش ارسال", value: methodLabel, icon: RemixIcons.TruckLine)
                        }
                        if let gatewayLabel {
                            SiteKeyValueRow(label: "روش پرداخت", value: gatewayLabel, icon: RemixIcons.BankCardLine)
                        }
                    }
                }

                // ---- دکمه‌های فاکتور و رسید ----
                let canDownloadInvoice = ["sent_to_customer", "direct_sent_to_customer", "sent", "delivered"].contains(order.status)
                if canDownloadInvoice {
                    Spacer().frame(height: 12)
                    SitePrimaryButton(
                        text: "دانلود فاکتور سفارش",
                        onClick: downloadInvoice,
                        icon: RemixIcons.Download2Line,
                        loading: isLoadingInvoice,
                        fillWidth: true
                    )
                }

                if order.hasReceipt == true {
                    Spacer().frame(height: 10)
                    SiteSecondaryButton(text: "نمایش رسید کارت‌به‌کارت", onClick: showReceipt, icon: RemixIcons.BankCardLine, fillWidth: true)
                }

                RecipientInfoCard(order: order)

                // ---- اقلام سفارش ----
                Spacer().frame(height: 20)
                SiteSectionTitle("اقلام سفارش").padding(.bottom, 10)
                ForEach(order.consignments) { consignment in
                    ConsignmentCard(
                        consignment: consignment,
                        onProductClick: onProductClick,
                        // در سفارش لغوشده دلیل بالای صفحه اومده؛ این‌جا فقط برای لغو تکی اقلام
                        showItemCancelReason: order.status != "cancelled"
                    )
                    Spacer().frame(height: 10)
                }

                // ---- خلاصه‌ی مالی ----
                SiteCard {
                    CardHeader(icon: RemixIcons.BillLine, title: "خلاصه‌ی پرداخت")
                    Spacer().frame(height: 4)
                    // نکته‌ی مهم: order.totalBill.price از قبل تخفیف‌خورده و نهایی‌ست
                    // (نه قیمت اصلی)؛ برای همین «جمع کل» رو با برگردوندن تخفیف به
                    // این عدد می‌سازیم، و «مبلغ نهایی» دیگه دوباره تخفیف رو کم نمی‌کنه
                    let discountAmount = order.totalBill?.discount ?? 0
                    let originalTotal = (order.totalBill?.price ?? 0) + discountAmount
                    SiteKeyValueRow(label: "جمع کل (قیمت اصلی کالاها)", value: tomanText(originalTotal))
                    SiteKeyValueRow(label: "تخفیف", value: tomanText(-discountAmount), valueColor: colors.primary)
                    if (order.taxAmount ?? 0) > 0 {
                        SiteKeyValueRow(label: "مالیات بر ارزش افزوده", value: tomanText(order.taxAmount ?? 0))
                    }
                    SiteKeyValueRow(label: "هزینه‌ی ارسال", value: tomanText(order.totalBill?.sendPrice ?? 0))
                    Spacer().frame(height: 4)
                    SiteDashedDivider()
                    Spacer().frame(height: 4)
                    SiteKeyValueRow(
                        label: "مبلغ نهایی",
                        value: tomanText((order.totalBill?.price ?? 0) + (order.taxAmount ?? 0) + (order.totalBill?.sendPrice ?? 0)),
                        valueColor: colors.primary,
                        emphasized: true
                    )
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 16)
        }
    }

    private func downloadInvoice() {
        isLoadingInvoice = true
        Task {
            do {
                var logoUrl: String? = nil
                if case .success(let info) = await catalogRepository.getSiteInfo() { logoUrl = info.logoUrl }
                let file = try await InvoicePdfGenerator.generate(order: order, logoUrl: logoUrl)
                InvoicePdfGenerator.openOrSharePdf(file)
            } catch {
                ShkToast.shared.show("ساخت فاکتور با خطا مواجه شد.")
            }
            isLoadingInvoice = false
        }
    }

    private func showReceipt() {
        let state = receipt
        ShkDialogCenter.shared.show {
            ReceiptDialog(state: state, onClose: { ShkDialogCenter.shared.dismiss() })
        }
        if state.image == nil {
            state.isLoading = true
            Task {
                switch await repository.getMyOrderReceiptBytes(orderId) {
                case .success(let data):
                    state.image = UIImage(data: data)
                case .error(let message):
                    ShkToast.shared.show(message)
                    ShkDialogCenter.shared.dismiss()
                }
                state.isLoading = false
            }
        }
    }
}

private struct ReceiptDialog: View {
    @ObservedObject var state: ReceiptState
    let onClose: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteDialogContent(title: "رسید کارت‌به‌کارت", icon: RemixIcons.BankCardLine, dismissText: "بستن", onDismiss: onClose) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.surfaceVariant)
                if state.isLoading {
                    MaterialSpinner(color: colors.primary, lineWidth: 4, size: 40).padding(24)
                } else if let image = state.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel("رسید پرداخت")
                        .padding(6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 180, maxHeight: 460)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

/** مبلغ به تومان (قدر مطلق، مثل قبل) */
private func tomanText(_ amount: Int64) -> String { "\(formatTomanFa(abs(amount))) تومان" }

/** سرتیتر کوچک داخل کارت‌ها: آیکن در کادر رنگی + عنوان */
private struct CardHeader: View {
    let icon: String
    let title: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            SiteIconBadge(icon: icon, size: 32, iconSize: 17, radius: 10)
            Spacer().frame(width: 10)
            Text(title).shkFont(14, .bold).foregroundColor(colors.onSurface)
        }
    }
}

/** کارت قرمز‌رنگ «دلیل لغو سفارش» */
private struct CancelReasonCard: View {
    let reason: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        let errorColor = colors.error
        // رنگ زمینه = قرمز ۷٪ روی رنگ کارت (compositeOver اندروید)
        SiteCard(color: errorColor.opacity(0.07), borderColor: errorColor.opacity(0.25)) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.ErrorWarningLine, size: 32, iconSize: 17, tint: errorColor, radius: 10)
                Spacer().frame(width: 10)
                Text("دلیل لغو سفارش").shkFont(14, .bold).foregroundColor(errorColor)
            }
            Spacer().frame(height: 10)
            Text(reason)
                .shkFont(13, lineHeight: 23)
                .foregroundColor(colors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.surface))
    }
}

/**
 * مراحل سفارش مطابق مراحل واقعی سایت: در انتظار بررسی → پردازش → ارسال، به‌علاوه‌ی مرحله‌ی آخر «تکمیل»
 * که فقط از وضعیت delivered خودِ سایت خونده می‌شه (قانون ۳۰ روزه‌ی اسکریپت - توضیح کنار orderStageOf).
 * برای سفارش‌های لغو/مرجوع‌شده به‌جای مراحل یک پیام قرمز نمایش داده می‌شه.
 */
private struct OrderProgress: View {
    let status: String
    let stage: OrderStage
    @Environment(\.shkColors) private var colors

    private let steps: [(String, String)] = [
        ("بررسی", RemixIcons.TimeLine),
        ("پردازش", RemixIcons.Loader4Line),
        ("ارسال", RemixIcons.TruckLine),
        ("تکمیل", RemixIcons.CheckboxCircleLine),
    ]

    var body: some View {
        if status == "cancelled" || status == "returned" {
            let info = orderStatusInfo(status, colors)
            HStack(spacing: 0) {
                RemixIcon(info.icon, tint: info.color, size: 18)
                Spacer().frame(width: 8)
                Text("این سفارش \(info.label) است.").shkFont(12, .medium).foregroundColor(info.color)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(info.color.opacity(0.08)))
        } else {
            progressRow
        }
    }

    private var currentIndex: Int {
        switch stage {
        case .Review: return 0
        case .Sent: return 2
        case .Completed: return 3
        default: return (status == "awaiting" || status == "prefactor") ? 0 : 1
        }
    }

    private var progressRow: some View {
        let primary = colors.primary
        let doneColor = SiteStatusColors.Success
        let idleColor = colors.onSurfaceVariant
        let lastIndex = steps.count - 1
        return HStack(alignment: .top, spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                let title = steps[index].0
                let icon = steps[index].1
                let isDone = index < currentIndex || (index == currentIndex && index == lastIndex)
                let isActive = index == currentIndex && !isDone
                let color = isDone ? doneColor : (isActive ? primary : idleColor)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // خط اتصال سمت شروع (بین مرحله‌ی قبل و این مرحله)
                        Rectangle()
                            .fill(index == 0 ? Color.clear : (index <= currentIndex ? doneColor : idleColor.opacity(0.25)))
                            .frame(maxWidth: .infinity)
                            .frame(height: 2)
                        ZStack {
                            Circle().fill(isActive ? primary : color.opacity(isDone ? 0.15 : 0.1))
                            RemixIcon(isDone ? RemixIcons.CheckLine : icon, tint: isActive ? .white : color, size: 16)
                        }
                        .frame(width: 32, height: 32)
                        Rectangle()
                            .fill(index == lastIndex ? Color.clear : (index < currentIndex ? doneColor : idleColor.opacity(0.25)))
                            .frame(maxWidth: .infinity)
                            .frame(height: 2)
                    }
                    Spacer().frame(height: 6)
                    Text(title)
                        .shkFont(11, isActive ? .bold : .medium)
                        .foregroundColor(isActive ? primary : (isDone ? colors.onSurface : idleColor))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }
}

/** سرور بعضی‌وقتا مختصات رو به‌شکل رشته برمی‌گردونه، نه عدد - این تابع هر دو حالت رو پشتیبانی می‌کنه */
private func jsonDouble(_ v: JSONValue?) -> Double? {
    switch v {
    case .number(let n): return n
    case .string(let s): return Double(s)
    default: return nil
    }
}

private struct RecipientInfoCard: View {
    let order: OrderDetailDto
    @Environment(\.shkColors) private var colors

    var body: some View {
        let buyerAddress = order.address?["address"]?.objectValue ?? [:]
        let field: (String) -> String = { buyerAddress[$0]?.stringValue ?? "" }
        let name = "\(field("first_name")) \(field("last_name"))".trimmingCharacters(in: .whitespaces)
        let phone = field("phone")
        let state = field("state")
        let city = field("city")
        let postal = field("postal_code")
        let fullAddress = field("full_address")
        let mapData = buyerAddress["get_map"]?.objectValue
        let lat = jsonDouble(mapData?["lat"]) ?? jsonDouble(mapData?["latitude"])
        let lng = jsonDouble(mapData?["lng"]) ?? jsonDouble(mapData?["longitude"])

        if !(name.isBlankShk && fullAddress.isBlankShk) {
            VStack(spacing: 0) {
                Spacer().frame(height: 10)
                SiteCard {
                    CardHeader(icon: RemixIcons.MapPin2Line, title: "اطلاعات گیرنده")
                    Spacer().frame(height: 4)
                    if !name.isBlankShk { SiteKeyValueRow(label: "نام گیرنده", value: name, icon: RemixIcons.User3Line) }
                    if !phone.isBlankShk { SiteKeyValueRow(label: "شماره گیرنده", value: phone.toPersianDigits(), icon: RemixIcons.PhoneLine) }
                    if !state.isBlankShk || !city.isBlankShk { SiteKeyValueRow(label: "استان / شهر", value: "\(state)، \(city)", icon: RemixIcons.Map2Line) }
                    if !postal.isBlankShk { SiteKeyValueRow(label: "کدپستی", value: postal.toPersianDigits(), icon: RemixIcons.MailLine) }
                    if !fullAddress.isBlankShk {
                        // آدرس کامل معمولاً طولانیه - زیر عنوانش و در یک کادر ملایم نمایش داده می‌شه
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.MapPinLine, tint: colors.onSurfaceVariant, size: 16)
                            Spacer().frame(width: 6)
                            Text("آدرس کامل").shkFont(12).foregroundColor(colors.onSurfaceVariant)
                        }
                        .padding(.top, 6)
                        Spacer().frame(height: 6)
                        Text(fullAddress)
                            .shkFont(13, lineHeight: 22)
                            .foregroundColor(colors.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant))
                    }

                    if let lat, let lng {
                        Spacer().frame(height: 10)
                        SiteSecondaryButton(
                            text: "نمایش روی نقشه",
                            onClick: {
                                ShkDialogCenter.shared.show {
                                    MapDialog(lat: lat, lng: lng, onClose: { ShkDialogCenter.shared.dismiss() })
                                }
                            },
                            icon: RemixIcons.Map2Line,
                            height: 42,
                            fontSize: 13,
                            fillWidth: true
                        )
                    }
                }
            }
        }
    }
}

/** آدرس تصویر ثابت نقشه از پروکسی سرور (NeshanConstants.staticMapUrl اندروید) */
func neshanStaticMapUrl(_ lat: Double, _ lng: Double, width: Int = 600, height: Int = 400, zoom: Int = 15) -> String {
    "\(ApiConstants.BASE_URL)api/v2/app/static-map?lat=\(lat)&lng=\(lng)&width=\(width)&height=\(height)&zoom=\(zoom)"
}

private struct MapDialog: View {
    let lat: Double
    let lng: Double
    let onClose: () -> Void
    @Environment(\.shkColors) private var colors
    // loading | success | error
    @State private var loadState = "loading"
    @State private var image: UIImage? = nil

    var body: some View {
        SiteDialogContent(title: "موقعیت روی نقشه", icon: RemixIcons.MapPin2Line, dismissText: "بستن", onDismiss: onClose) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.surfaceVariant)
                if let image {
                    Color.clear.overlay {
                        Image(uiImage: image).resizable().scaledToFill().accessibilityLabel("موقعیت روی نقشه")
                    }
                    .clipped()
                }
                if loadState == "loading" {
                    MaterialSpinner(color: colors.primary, lineWidth: 4, size: 40)
                } else if loadState == "error" {
                    Text("بارگذاری نقشه با خطا مواجه شد").shkFont(12).foregroundColor(colors.error)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .task {
                loadState = "loading"
                if let img = await ShkImageLoader.shared.load(neshanStaticMapUrl(lat, lng)) {
                    image = img
                    loadState = "success"
                } else {
                    loadState = "error"
                }
            }
        }
    }
}

private struct ConsignmentCard: View {
    let consignment: OrderConsignmentDto
    let onProductClick: (String) -> Void
    var showItemCancelReason: Bool = true
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard {
            HStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.Store2Line, size: 30, iconSize: 16, radius: 9)
                Spacer().frame(width: 8)
                Text(consignment.store?.name ?? "فروشگاه اصلی")
                    .shkFont(13, .bold)
                    .foregroundColor(colors.onSurface)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(consignment.items.count.toPersianDigits()) کالا").shkFont(11).foregroundColor(colors.onSurfaceVariant)
            }
            Spacer().frame(height: 10)
            ForEach(Array(consignment.items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    SiteDashedDivider().padding(.vertical, 10)
                }
                OrderItemRow(item: item, onClick: { if let slug = item.product?.slug { onProductClick(slug) } })
                // کالای لغوشده (لغو تکی) - برچسب و دلیلی که سایت ثبت کرده
                if showItemCancelReason && item.status == "cancelled" {
                    let itemReason = plainCancelReason(item.reason)
                    HStack(alignment: .top, spacing: 0) {
                        RemixIcon(RemixIcons.CloseCircleLine, tint: colors.error, size: 15)
                        Spacer().frame(width: 6)
                        Text(itemReason.map { "این کالا لغو شده - دلیل لغو: \($0)" } ?? "این کالا لغو شده")
                            .shkFont(11, lineHeight: 19)
                            .foregroundColor(colors.error)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.error.opacity(0.07)))
                    .padding(.top, 8)
                }
            }
        }
    }
}

private struct OrderItemRow: View {
    let item: OrderConsignmentItemDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant)
                if item.product?.mainImageUrl == nil {
                    RemixIcon(RemixIcons.ImageLine, tint: colors.onSurfaceVariant, size: 22)
                }
                RemoteImage(item.product?.mainImageUrl, contentScale: .crop)
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Spacer().frame(width: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .shkFont(13, .medium, lineHeight: 21)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .foregroundColor(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(height: 6)
                HStack(alignment: .bottom, spacing: 0) {
                    Text("تعداد: \(item.count.toPersianDigits())")
                        .shkFont(11)
                        .foregroundColor(colors.onSurfaceVariant)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.surfaceVariant))
                    Spacer(minLength: 0)
                    let itemDiscount = (item.discount ?? 0) * Int64(item.count)
                    VStack(alignment: .trailing, spacing: 0) {
                        if itemDiscount > 0 {
                            Text("\(formatTomanFa(item.fullCountPrice + itemDiscount)) تومان")
                                .strikethrough()
                                .shkFont(11)
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                        Text("\(formatTomanFa(item.fullCountPrice)) تومان")
                            .shkFont(13, .bold)
                            .foregroundColor(colors.onSurface)
                    }
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture { if item.product != nil { onClick() } }
    }
}
