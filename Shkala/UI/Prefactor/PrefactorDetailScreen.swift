import SwiftUI
import PhotosUI

// معادل ui/prefactor/PrefactorDetailScreen.kt

/// معادل نمایش ${map["key"] ?: ""} اندروید برای مقدارهای خام JSON
private func jsonText(_ v: JSONValue?) -> String {
    switch v {
    case .string(let s): return s
    case .number(let d): return d == d.rounded() && abs(d) < 1e15 ? String(Int64(d)) : String(d)
    case .bool(let b): return b ? "true" : "false"
    default: return ""
    }
}

struct PrefactorDetailScreen: View {
    let uuid: String
    let onBack: () -> Void
    let onOpenGatewayWebView: () -> Void
    let onPaidByWallet: (String) -> Void
    let onOpenProduct: (String) -> Void
    // فاز ۳۱: قبلاً انتخاب آدرس فقط یه دیالوگ ساده بود (بدون گزینه‌ی تحویل حضوری و
    // بدون امکان افزودن آدرس جدید). الان یه صفحه‌ی کامل و مشترک با تسویه‌حساب عادی داره.
    let onOpenAddressPicker: (String) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = PrefactorRepository()

    @State private var detail: PrefactorDetailResponse? = nil
    @State private var gateways: [PaymentGatewayDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var selectedGatewayId: String? = nil
    @State private var isPaying = false
    @State private var receiptImage: Data? = nil
    @State private var pickerItem: PhotosPickerItem? = nil

    private func load() async {
        switch await repository.getPrefactorDetail(uuid) {
        case .success(let data):
            detail = data
            ViewedPrefactorsManager.shared.markPrefactorAsViewed(uuid)
        case .error(let message):
            errorMessage = message
        }
        if case .success(let list) = await repository.getGateways(uuid) {
            gateways = list
            if selectedGatewayId == nil { selectedGatewayId = gateways.first?.id }
        }
        isLoading = false
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "پرداخت پیش‌فاکتور", onBack: onBack)

            if isLoading {
                SiteLoading(message: "در حال دریافت پیش‌فاکتور...", icon: RemixIcons.FileList3Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, detail == nil {
                SiteEmptyState(icon: RemixIcons.ErrorWarningLine, title: "خطا در دریافت پیش‌فاکتور", subtitle: errorMessage)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let d = detail {
                content(d)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task { await load() }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = await loadPickedImageData(item) {
                    if let error = validateImageUpload(data) {
                        ShkToast.shared.show(error)
                    } else {
                        receiptImage = data
                    }
                }
                pickerItem = nil
            }
        }
    }

    // فاز ۲۹ (اصلاحیه): تابعِ پرداخت بیرونِ ستونِ قابل‌اسکرول است تا دکمه‌ی «پرداخت»
    // یک نوار ثابتِ پایینِ صفحه (مثل CardToCardScreen) باشد.
    private func performPayment() {
        isPaying = true
        Task {
            guard let gatewayId = selectedGatewayId else {
                ShkToast.shared.show("یک درگاه پرداخت انتخاب کنید.")
                isPaying = false
                return
            }
            if gatewayId == "card_to_card" {
                guard let receipt = receiptImage else {
                    ShkToast.shared.show("عکس رسید را انتخاب کنید.")
                    isPaying = false
                    return
                }
                switch await repository.payCardToCard(uuid, receipt: receipt) {
                case .success(let r):
                    isPaying = false
                    ShkToast.shared.show(r.message ?? "", long: true)
                    if let orderUuid = r.orderUuid { onPaidByWallet(orderUuid) }
                case .error(let message):
                    isPaying = false
                    ShkToast.shared.show(message)
                }
                return
            }

            switch await repository.pay(uuid, paymentGateway: gatewayId) {
            case .success(let r):
                isPaying = false
                if r.paidByWallet {
                    if let orderUuid = r.orderUuid { onPaidByWallet(orderUuid) }
                } else if r.action != nil {
                    PaymentFlowState.shared.pendingPayment = r
                    onOpenGatewayWebView()
                }
            case .error(let message):
                isPaying = false
                ShkToast.shared.show(message)
            }
        }
    }

    @ViewBuilder
    private func content(_ d: PrefactorDetailResponse) -> some View {
        // کشیدن صفحه به پایین: پیش‌فاکتور و درگاه‌ها بی‌صدا از سرور تازه می‌شن
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 4)
                // اقلام
                SiteSectionTitle("اقلام")
                Spacer().frame(height: 12)
                let allItems = (d.consignments ?? []).flatMap { $0.value.items ?? [] }
                SiteCard(contentPadding: .hv(12, 4)) {
                    ForEach(Array(allItems.enumerated()), id: \.offset) { index, item in
                        PrefactorItemRow(item: item, onClick: {
                            if let slug = item.product?.slug { onOpenProduct(slug) }
                        })
                        if index != allItems.count - 1 { SiteDashedDivider() }
                    }
                }

                // آدرس
                Spacer().frame(height: 20)
                SiteSectionTitle("آدرس تحویل") {
                    Button(action: { onOpenAddressPicker(uuid) }) {
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.EditLine, tint: colors.primary, size: 14)
                            Spacer().frame(width: 4)
                            Text("تغییر آدرس").shkFont(12, .bold).foregroundColor(colors.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.primary.opacity(0.1)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer().frame(height: 12)
                // فاز ۳۱: آدرس انتخابی می‌تونه یه آدرس کاربر (type=user) یا یه شعبه‌ی
                // تحویل حضوری (type=shop) باشه - هر دو حالت رو نشون می‌دیم
                if let selectedAddress = d.selectedAddress, let addressMap = selectedAddress.address, selectedAddress.type == "shop" {
                    SelectedAddressCard(
                        icon: RemixIcons.Store2Line,
                        title: "تحویل حضوری از شعبه",
                        text: "\(jsonText(addressMap["state"])), \(jsonText(addressMap["city"])) - \(jsonText(addressMap["full_address"]))",
                        onClick: { onOpenAddressPicker(uuid) }
                    )
                } else if let addressMap = d.selectedAddress?.address {
                    SelectedAddressCard(
                        icon: RemixIcons.MapPin2Line,
                        title: "\(jsonText(addressMap["first_name"])) \(jsonText(addressMap["last_name"]))",
                        text: jsonText(addressMap["full_address"]),
                        onClick: { onOpenAddressPicker(uuid) }
                    )
                } else {
                    SiteSecondaryButton(text: "انتخاب آدرس", onClick: { onOpenAddressPicker(uuid) }, icon: RemixIcons.MapPin2Line, fillWidth: true)
                }

                // روش‌های ارسال
                ForEach(d.consignments ?? []) { entry in
                    let key = entry.key
                    let consignment = entry.value
                    if let postWays = consignment.postWays, !postWays.isEmpty {
                        Spacer().frame(height: 20)
                        SiteSectionTitle(key == "main" ? "روش ارسال" : "روش ارسال (فروشنده‌ی جدا)")
                        Spacer().frame(height: 12)
                        VStack(spacing: 10) {
                            ForEach(Array(postWays.enumerated()), id: \.offset) { _, way in
                                let currentUuid = consignment.sendMethod?["item"]?.objectValue?["uuid"]?.stringValue
                                let isSelected = currentUuid == way.uuid
                                PrefactorOptionCard(
                                    icon: RemixIcons.TruckLine,
                                    title: way.title ?? "",
                                    subtitle: "\(formatTomanFa(Int64(way.price?.replacingOccurrences(of: ",", with: "") ?? "") ?? 0)) تومان",
                                    selected: isSelected,
                                    onClick: {
                                        Task {
                                            let type = key == "main" ? "main" : "direct"
                                            switch await repository.selectShippingMethod(uuid, type: type, consignmentUuid: consignment.uuid ?? key, sendMethodUuid: way.uuid) {
                                            case .success: await load()
                                            case .error(let message): ShkToast.shared.show(message)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                }

                // جمع مالی
                let financial = d.financial
                Spacer().frame(height: 20)
                SiteSectionTitle("جمع مالی")
                Spacer().frame(height: 12)
                SiteCard(contentPadding: .hv(14, 8)) {
                    PrefactorFinancialLine(label: "جمع کل", amount: financial?.totalPrice ?? 0, icon: RemixIcons.ShoppingBag3Line)
                    if (financial?.totalDiscount ?? 0) > 0 {
                        PrefactorFinancialLine(label: "تخفیف", amount: -(financial?.totalDiscount ?? 0), icon: RemixIcons.PercentLine, valueColor: SiteStatusColors.Success)
                    }
                    if (financial?.totalCouponDiscountPrice ?? 0) > 0 {
                        PrefactorFinancialLine(label: "کد تخفیف", amount: -(financial?.totalCouponDiscountPrice ?? 0), icon: RemixIcons.Coupon2Line, valueColor: SiteStatusColors.Success)
                    }
                    PrefactorFinancialLine(label: "هزینه‌ی ارسال", amount: financial?.sendPrice ?? 0, icon: RemixIcons.TruckLine)
                    SiteDashedDivider().padding(.vertical, 4)
                    PrefactorFinancialLine(label: "مبلغ نهایی", amount: financial?.totalFinalPrice ?? 0, isBold: true)
                }

                // درگاه پرداخت
                Spacer().frame(height: 20)
                SiteSectionTitle("درگاه پرداخت")
                Spacer().frame(height: 12)
                VStack(spacing: 10) {
                    // مثل صفحه‌ی پرداخت سفارش: لوگو/آیکن درگاه + توضیح زیر هر گزینه
                    ForEach(gateways.uniqueById()) { gateway in
                        GatewayOptionCard(
                            id: gateway.id,
                            label: gateway.label,
                            selected: selectedGatewayId == gateway.id,
                            description: gatewayDescription(gateway.id, gateway.label, cardToCardNote: "پیش‌فاکتور پس از تأیید پرداخت ثبت می‌شود"),
                            onClick: { selectedGatewayId = gateway.id }
                        )
                    }
                }

                if selectedGatewayId == "card_to_card" {
                    let bankDetails = gateways.first { $0.id == "card_to_card" }?.bankDetails ?? []
                    // همان طراحی صفحه‌ی کارت‌به‌کارت سفارش (اجزای مشترک CardToCardComponents)
                    VStack(alignment: .leading, spacing: 0) {
                        SiteSectionTitle("جزئیات مبلغ").padding(.top, 20).padding(.bottom, 10)
                        SiteCard(contentPadding: .hv(14, 8)) {
                            SiteKeyValueRow(
                                label: "مبلغ قابل‌واریز کارت‌به‌کارت",
                                value: "\(formatTomanFa(d.financial?.totalFinalPrice ?? 0)) تومان",
                                icon: RemixIcons.BillLine,
                                valueColor: colors.primary,
                                emphasized: true
                            )
                        }

                        SiteSectionTitle("اطلاعات حساب مقصد").padding(.top, 20).padding(.bottom, 10)
                        CardToCardGuideBox(text: "مبلغ را به شماره‌کارت و یا شماره‌شبا زیر واریز کنید و سپس تصویر رسید را بارگذاری و ارسال نمایید")
                        Spacer().frame(height: 12)
                        CardToCardBankDetails(bankDetails: bankDetails, onCopy: { detailField in
                            copyToClipboard(label: detailField.label, value: detailField.value ?? "")
                        })

                        SiteSectionTitle("عکس رسید پرداخت").padding(.top, 20).padding(.bottom, 10)
                        CardToCardReceiptPicker(pickedImage: receiptImage, pickerItem: $pickerItem)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.25), value: selectedGatewayId)
        }
        .sitePullRefresh { await load() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        // نوار ثابت پایین: مبلغ نهایی + دکمه‌ی پرداخت
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("مبلغ قابل پرداخت").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                Text("\(formatTomanFa(d.financial?.totalFinalPrice ?? 0)) تومان")
                    .shkFont(15, .bold)
                    .foregroundColor(colors.onSurface)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SitePrimaryButton(
                text: "پرداخت",
                onClick: {
                    if selectedGatewayId != "card_to_card" && isVpnActive() {
                        showVpnWarningDialog(onDismiss: {}, onContinueAnyway: { performPayment() })
                    } else {
                        performPayment()
                    }
                },
                icon: RemixIcons.SecurePaymentLine,
                loading: isPaying,
                height: 50,
                fillWidth: true
            )
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            TopRoundedShape(radius: 20)
                .fill(colors.surface)
                .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

/** کارت آدرس انتخاب‌شده */
private struct SelectedAddressCard: View {
    let icon: String
    let title: String
    let text: String
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard(onClick: onClick, borderColor: colors.primary.opacity(0.35)) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: icon)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).shkFont(13, .bold).foregroundColor(colors.onSurface)
                    Spacer().frame(height: 2)
                    Text(text).shkFont(12, lineHeight: 20).foregroundColor(colors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
            }
        }
    }
}

/** کارت گزینه‌ی قابل انتخاب (روش ارسال / درگاه پرداخت) */
private struct PrefactorOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        Button(action: onClick) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: icon, tint: selected ? primary : colors.onSurfaceVariant)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).shkFont(13, .bold).foregroundColor(colors.onSurface)
                    if let subtitle, !subtitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(subtitle).shkFont(11, lineHeight: 18).foregroundColor(colors.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RemixIcon(selected ? RemixIcons.CheckboxCircleFill : RemixIcons.CheckboxBlankCircleLine,
                          tint: selected ? primary : colors.onSurfaceVariant, size: 22)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(shape.fill(colors.surface))
            .overlay(shape.strokeBorder(selected ? primary : Color.clear, lineWidth: 1.5))
            .clipShape(shape)
            .contentShape(shape)
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(.plain)
    }
}

private struct PrefactorItemRow: View {
    let item: PrefactorItemDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let variantText: String? = {
            let parts = (item.props ?? [])
                .filter { !($0.name ?? "").trimmingCharacters(in: .whitespaces).isEmpty && !($0.displayValue ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
                .map { "\($0.name ?? ""): \($0.displayValue ?? "")" }
            let joined = parts.joined(separator: " | ")
            return item.props == nil || joined.trimmingCharacters(in: .whitespaces).isEmpty ? nil : joined
        }()
        let discountTotal = (item.discount ?? 0) * Int64(item.count)
        let finalTotal = item.fullCountPrice ?? (item.price * Int64(item.count))

        Button(action: onClick) {
            HStack(alignment: .top, spacing: 0) {
                RemoteImage(item.product?.mainImageUrl, contentDescription: item.product?.title, contentScale: .crop)
                    .frame(width: 68, height: 68)
                    .background(colors.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.product?.title ?? "محصول")
                        .shkFont(13, .bold, lineHeight: 21)
                        .foregroundColor(colors.onSurface)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    if let variantText {
                        Spacer().frame(height: 2)
                        Text(variantText).shkFont(11, lineHeight: 18).foregroundColor(colors.onSurfaceVariant)
                    }
                    Spacer().frame(height: 6)
                    HStack(alignment: .bottom, spacing: 0) {
                        SiteStatusChip(text: "تعداد: \(item.count.toPersianDigits())", color: SiteStatusColors.Neutral)
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 0) {
                            if discountTotal > 0 {
                                Text("\(formatTomanFa(finalTotal + discountTotal)) تومان")
                                    .shkFont(11)
                                    .strikethrough()
                                    .foregroundColor(colors.onSurfaceVariant)
                            }
                            Text("\(formatTomanFa(finalTotal)) تومان")
                                .shkFont(13, .bold)
                                .foregroundColor(colors.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PrefactorFinancialLine: View {
    let label: String
    let amount: Int64
    var isBold: Bool = false
    var icon: String? = nil
    var valueColor: Color? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteKeyValueRow(
            label: label,
            value: "\(formatTomanFa(amount)) تومان",
            icon: icon,
            valueColor: valueColor ?? (isBold ? colors.primary : colors.onSurface),
            emphasized: isBold
        )
    }
}
