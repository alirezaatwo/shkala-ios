import SwiftUI

// ===================================================================================
// معادل ui/checkout/CheckoutScreen.kt
// بازطراحی: صفحه‌ی تسویه‌حساب - کارت آدرس/نحوه‌ی دریافت، کارت بازشونده‌ی کد تخفیف (با
// انیمیشن موفقیت/لرزش خطا)، کارت کیف پول با سوییچ، فاکتور با خط‌چین و نوار پایینِ ثابت
// (مبلغ قابل پرداخت + دکمه).
// ادغام با صفحه‌ی انتخاب درگاه: روش پرداخت هم همین‌جا انتخاب می‌شه (جمع سبد زیر درگاه‌ها)؛
// با انتخاب کارت‌به‌کارت یا پرداخت با هماهنگی (طبق منطق کارت‌به‌کارت اسکریپت) کیف پول
// خاکستری و لغو می‌شه؛ کد تخفیف مثل سایت اعمال می‌شه.
// ===================================================================================

struct CheckoutScreen: View {
    let onBack: () -> Void
    let onGoToAddresses: () -> Void
    // ادغام تسویه‌حساب و انتخاب درگاه: ادامه‌ی مسیر مستقیم از همین صفحه
    let onOpenGateway: () -> Void
    let onOpenCardToCard: () -> Void
    let onCoordinatedPlaced: (String) -> Void

    @StateObject private var viewModel = CheckoutViewModel()
    @ObservedObject private var navigator = AppNavigator.shared
    @Environment(\.shkColors) private var colors
    @State private var showVpnWarning = false
    @State private var pendingBankGatewayId: String? = nil
    /// تعداد صفحه‌های پشته وقتی این صفحه باز شد - برای تشخیص «دوباره روی صفحه اومد» (ON_RESUME)
    @State private var ownDepth: Int? = nil

    var body: some View {
        let state = viewModel.uiState
        VStack(spacing: 0) {
            SitePageTopBar(title: "تسویه‌حساب", onBack: onBack)

            if state.isLoading {
                SiteLoading(message: "در حال آماده‌سازی تسویه‌حساب...", icon: RemixIcons.ShoppingBag3Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = state.errorMessage {
                SiteEmptyState(
                    icon: RemixIcons.WifiOffLine, title: error, subtitle: nil,
                    actionLabel: "تلاش دوباره", actionIcon: RemixIcons.RefreshLine,
                    onAction: { viewModel.load() }
                )
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content(state)
            }
        }
        .background(colors.background)
        // کد لینک کمپین: بعد از آماده شدن صفحه یک‌بار اعمال و بلافاصله از حافظه پاک می‌شه
        .onChange(of: state.isLoading || state.isMutating) { busy in applyCampaignIfReady(busy) }
        .onAppear {
            if ownDepth == nil { ownDepth = navigator.stack.count }
            applyCampaignIfReady(state.isLoading || state.isMutating)
        }
        // معادل ON_RESUME: هر بار که از صفحه‌ی آدرس‌ها برمی‌گردیم، اطلاعات از سرور تازه گرفته می‌شه
        .onChange(of: navigator.stack.count) { count in
            if count == ownDepth && viewModel.reloadOnResume {
                viewModel.reloadOnResume = false
                viewModel.load(silently: true)
            }
        }
        .onChange(of: state.discountMinAmount != nil) { show in if show { showMinAmountDialog() } }
        .onChange(of: showVpnWarning) { show in if show { showVpnDialog() } }
    }

    private func applyCampaignIfReady(_ busy: Bool) {
        if busy { return }
        guard let campaignCode = CampaignDiscountStore.peek() else { return }
        CampaignDiscountStore.clear()
        viewModel.applyCampaignCode(campaignCode)
    }

    // تماس با سرور برای اتصال به درگاه در خود صفحه‌ی وب‌ویو انجام می‌شه (مثل قبل)
    private func goToBankGateway(_ gatewayId: String) {
        let flow = PaymentFlowState.shared
        flow.pendingPayment = nil
        flow.pendingGatewayId = gatewayId
        onOpenGateway()
    }

    private func proceed() {
        let s = viewModel.uiState
        guard let gateway = s.selectedGateway else { return }
        let flow = PaymentFlowState.shared
        flow.useWallet = s.useWallet && !s.isOfflineMethod
        flow.payableAmount = s.payableAfterWallet
        switch gateway.id {
        case COORDINATED_GATEWAY_ID:
            viewModel.placeCoordinatedOrder(
                onPlaced: onCoordinatedPlaced,
                onError: { ShkToast.shared.show($0, long: true) }
            )
        case "card_to_card":
            flow.pendingCardToCardGateway = gateway
            onOpenCardToCard()
        default:
            if isVpnActive() {
                // درگاه‌های بانکی معمولاً با VPN روشن درست کار نمی‌کنن
                pendingBankGatewayId = gateway.id
                showVpnWarning = true
            } else {
                goToBankGateway(gateway.id)
            }
        }
    }

    @ViewBuilder
    private func content(_ state: CheckoutUiState) -> some View {
        let addressReady = state.hasSelectedAddress && state.allShippingMethodsSelected
        let offline = state.isOfflineMethod
        let selectedGateway = state.selectedGateway
        let canContinue = addressReady && selectedGateway != nil && !state.isApplyingDiscount && !state.isMutating

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // فقط یه باکس واحد «آدرس / نحوه‌ی دریافت» - انتخاب روش ارسال هم
                // داخل همون صفحه‌ی آدرس‌ها انجام می‌شه، نه اینجا
                SiteSectionTitle("آدرس / نحوه‌ی دریافت").padding(.top, 6).padding(.bottom, 10)
                AddressSummaryCard(
                    summaryText: state.deliverySummaryText,
                    isShop: state.selectedAddressType == "shop",
                    isComplete: addressReady,
                    hasAddress: state.hasSelectedAddress,
                    onClick: {
                        viewModel.reloadOnResume = true
                        onGoToAddresses()
                    }
                )

                SiteSectionTitle("کد تخفیف").padding(.top, 20).padding(.bottom, 10)
                DiscountLabelBanner(label: state.discountLabel, autoDiscount: state.autoDiscount, hasApplied: state.hasAppliedDiscount)
                DiscountCodeCard(
                    // تخفیف خودکار: کد از سرور میاد و کاربر چیزی تایپ نکرده
                    code: state.hasAppliedDiscount && state.discountCode.isBlankShk ? (state.autoDiscount?.code ?? "") : state.discountCode,
                    onCodeChange: { viewModel.updateDiscountCode($0) },
                    hasApplied: state.hasAppliedDiscount,
                    isBusy: state.isApplyingDiscount,
                    message: state.discountMessage,
                    isError: state.discountIsError,
                    couponDiscount: state.financial?.totalCouponDiscountPrice ?? 0,
                    onApply: { viewModel.applyDiscount() },
                    onRemove: { viewModel.removeDiscount() },
                    isAuto: state.autoDiscount != nil && state.hasAppliedDiscount
                )

                // فاز ۱۶: دقیقاً مثل خودِ سایت، همیشه نمایش داده می‌شه (فقط وقتی موجودی صفره، سوییچش غیرفعاله)
                SiteSectionTitle("کیف پول").padding(.top, 20).padding(.bottom, 10)
                WalletDeductionCard(
                    walletBalance: state.walletBalance,
                    useWallet: state.useWallet,
                    walletDeduction: state.walletDeductionAmount,
                    onToggle: { viewModel.toggleWallet($0) },
                    disabled: offline
                )

                SiteSectionTitle("روش پرداخت").padding(.top, 20).padding(.bottom, 10)
                if state.isLoadingGateways {
                    SiteCard {
                        SiteLoading(message: "در حال دریافت روش‌های پرداخت...", icon: RemixIcons.BankCardLine)
                            .frame(maxWidth: .infinity)
                    }
                } else if state.gateways.isEmpty {
                    SiteEmptyState(
                        icon: RemixIcons.BankCardLine,
                        title: state.gatewaysError ?? "در حال حاضر درگاه پرداختی فعال نیست",
                        subtitle: nil,
                        actionLabel: "تلاش دوباره", actionIcon: RemixIcons.RefreshLine,
                        onAction: { viewModel.loadGateways() }
                    )
                } else {
                    ForEach(distinctGateways(state.gateways)) { gateway in
                        let gatewayDisabled = state.isGatewayDisabled(gateway)
                        GatewayOptionCard(
                            id: gateway.id,
                            label: gateway.label,
                            enabled: !gatewayDisabled,
                            selected: gateway.id == state.selectedGatewayId && !gatewayDisabled,
                            showOverLimitNotice: gatewayDisabled,
                            description: gateway.description,
                            overLimitMessage: state.overLimitMessage(gateway),
                            onClick: { viewModel.selectGateway(gateway.id) }
                        )
                        .padding(.bottom, 12)
                    }
                }

                // هشدار: در کارت‌به‌کارت و پرداخت با هماهنگی، کیف پول اعمال نمی‌شه
                if offline {
                    OfflineMethodNotice().transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let financial = state.financial {
                    SiteSectionTitle("جمع سبد خرید").padding(.top, 8).padding(.bottom, 10)
                    FinancialSummaryCard(
                        totalPrice: financial.totalPrice ?? 0,
                        totalDiscount: financial.totalDiscount ?? 0,
                        couponDiscount: financial.totalCouponDiscountPrice ?? 0,
                        sendPrice: financial.sendPrice ?? 0,
                        totalFinalPrice: financial.totalFinalPrice ?? 0,
                        walletDeduction: state.walletDeductionAmount,
                        payableAfterWallet: state.payableAfterWallet
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 20)
            .animation(.easeInOut(duration: 0.25), value: offline)
        }
        .refreshable {
            // کشیدن صفحه به پایین: اطلاعات ارسال و درگاه‌ها بی‌صدا تازه می‌شن
            if PullRefreshRateLimiter.tryAcquire() {
                await viewModel.refresh(onError: { ShkToast.shared.show($0) })
            } else {
                ShkToast.shared.show(PULL_REFRESH_LIMIT_MESSAGE, long: true)
            }
        }

        // نوار پایینِ ثابت: مبلغ قابل پرداخت + دکمه‌ی ادامه
        CheckoutBottomBar(
            showAmount: state.financial != nil,
            payable: state.payableAfterWallet,
            usesWallet: state.walletDeductionAmount > 0,
            canContinue: canContinue,
            warning: !addressReady ? "برای ادامه، آدرس و روش ارسال را مشخص کنید."
                : (selectedGateway == nil && !state.isLoadingGateways ? "یک روش پرداخت را انتخاب کنید." : nil),
            buttonText: selectedGateway?.id == "card_to_card" ? "ادامه با کارت‌به‌کارت"
                : (selectedGateway?.id == COORDINATED_GATEWAY_ID ? "ثبت سفارش" : "پرداخت"),
            buttonIcon: selectedGateway?.id == COORDINATED_GATEWAY_ID ? RemixIcons.CheckboxCircleLine : RemixIcons.SecurePaymentLine,
            loading: state.isPlacingOrder,
            onContinue: proceed
        )
    }

    private func distinctGateways(_ list: [PaymentGatewayDto]) -> [PaymentGatewayDto] {
        var seen = Set<String>()
        return list.filter { seen.insert($0.id).inserted }
    }

    // مودال حداقل مبلغ سبد: وقتی کد به‌خاطر کمبود مبلغ رد شده
    private func showMinAmountDialog() {
        guard let info = viewModel.uiState.discountMinAmount else { return }
        let shortfall = info.shortfall ?? 0
        let minAmount = info.minAmount ?? 0
        var text = "برای استفاده از این کد، مبلغ سبد خرید باید حداقل \(formatTomanFa(minAmount)) تومان باشد."
        if shortfall > 0 { text += "\nبرای رسیدن به این مبلغ، \(formatTomanFa(shortfall)) تومان دیگر به سبد خود اضافه کنید." }
        if info.restricted == true { text += "\nمبلغ سبد فقط بر اساس کالاهای مشمول این تخفیف محاسبه می‌شود." }
        let title = (info.title?.isBlankShk == false ? info.title : nil) ?? "حداقل مبلغ سبد خرید"
        let vm = viewModel
        ShkDialogCenter.shared.show(onDismissRequest: { vm.dismissMinAmountDialog() }) {
            SiteDialogContent(
                title: title, icon: RemixIcons.InformationLine, iconTint: SiteStatusColors.Warning,
                message: text, confirmText: "متوجه شدم",
                onConfirm: { ShkDialogCenter.shared.dismiss(); vm.dismissMinAmountDialog() }
            )
        }
    }

    private func showVpnDialog() {
        ShkDialogCenter.shared.show(onDismissRequest: { showVpnWarning = false }) {
            SiteDialogContent(
                title: "VPN شما روشن است", icon: RemixIcons.GlobalLine, iconTint: SiteStatusColors.Warning,
                message: "برای اتصال به درگاه بانکی، لطفاً ابتدا VPN گوشی خود را خاموش کنید، سپس دوباره روی دکمه‌ی پرداخت بزنید.",
                confirmText: "متوجه شدم",
                onConfirm: {
                    ShkDialogCenter.shared.dismiss()
                    showVpnWarning = false
                },
                dismissText: "VPN خاموشه، ادامه بده",
                onDismiss: {
                    ShkDialogCenter.shared.dismiss()
                    showVpnWarning = false
                    if let id = pendingBankGatewayId { goToBankGateway(id) }
                }
            )
        }
    }
}

/** باکس هشدار روش‌های آفلاین (کارت‌به‌کارت / پرداخت با هماهنگی) */
private struct OfflineMethodNotice: View {
    @Environment(\.shkColors) private var colors
    var body: some View {
        let warning = SiteStatusColors.Warning
        HStack(spacing: 0) {
            RemixIcon(RemixIcons.ErrorWarningLine, tint: warning, size: 20)
            Spacer().frame(width: 8)
            Text("در روش پرداخت کارت‌به‌کارت و پرداخت با هماهنگی، کسر از کیف پول اعمال نمی‌گردد و مبلغ بر همین اساس محاسبه شده است.")
                .shkFont(12, lineHeight: 21)
                .foregroundColor(colors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(warning.opacity(0.12)))
        .padding(.bottom, 12)
    }
}

/** خط کوچک «در این روش پرداخت اعمال نمی‌شود» داخل کارت‌های غیرفعال */
private struct NotAppliedLine: View {
    let text: String
    @Environment(\.shkColors) private var colors
    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(RemixIcons.ForbidLine, tint: colors.onSurfaceVariant, size: 14)
            Spacer().frame(width: 5)
            Text(text).shkFont(11, lineHeight: 18).foregroundColor(colors.onSurfaceVariant)
        }
        .padding(.top, 10)
    }
}

/** کارت خلاصه‌ی آدرس/نحوه‌ی دریافت - با لمس، صفحه‌ی آدرس‌ها باز می‌شه */
private struct AddressSummaryCard: View {
    let summaryText: String
    let isShop: Bool
    let isComplete: Bool
    let hasAddress: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        SiteCard(onClick: onClick, borderColor: isComplete ? .clear : SiteStatusColors.Warning.opacity(0.55)) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: isShop ? RemixIcons.Store2Line : RemixIcons.MapPin2Line, size: 44, iconSize: 22)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(summaryText)
                        .shkFont(13, .medium, lineHeight: 22)
                        .foregroundColor(colors.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer().frame(height: 6)
                    if isComplete {
                        SiteStatusChip(text: "آماده‌ی ارسال", color: SiteStatusColors.Success, icon: RemixIcons.CheckboxCircleLine)
                    } else {
                        SiteStatusChip(
                            text: hasAddress ? "روش ارسال را انتخاب کنید" : "آدرس را انتخاب کنید",
                            color: SiteStatusColors.Warning,
                            icon: RemixIcons.ErrorWarningLine
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 8)
                HStack(spacing: 0) {
                    Text("تغییر").shkFont(11, .bold).foregroundColor(primary)
                    RemixIcon(RemixIcons.ArrowLeftSLine, tint: primary, size: 16)
                }
                .padding(.leading, 10).padding(.trailing, 4).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(primary.opacity(0.1)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isComplete)
    }
}

/** فاکتور: ردیف‌های «برچسب ..... مبلغ» با خط‌چین، مبالغ متغیر با انیمیشن عوض می‌شن */
private struct FinancialSummaryCard: View {
    let totalPrice: Int64
    let totalDiscount: Int64
    let couponDiscount: Int64
    let sendPrice: Int64
    let totalFinalPrice: Int64
    let walletDeduction: Int64
    let payableAfterWallet: Int64
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        SiteCard(contentPadding: .hv(14, 8)) {
            SiteKeyValueRow(label: "جمع کل", value: "\(formatTomanFa(totalPrice)) تومان", icon: RemixIcons.ShoppingBag3Line)
            if totalDiscount > 0 {
                SiteDashedDivider()
                SiteKeyValueRow(label: "تخفیف محصولات", value: "\(formatTomanFa(abs(totalDiscount))) تومان",
                                icon: RemixIcons.PriceTag3Line, valueColor: primary)
            }
            if couponDiscount > 0 {
                VStack(spacing: 0) {
                    SiteDashedDivider()
                    AmountRow(label: "کد تخفیف", amount: abs(couponDiscount), icon: RemixIcons.Coupon3Line, valueColor: primary)
                }
                .transition(.opacity)
            }
            SiteDashedDivider()
            SiteKeyValueRow(label: "هزینه‌ی ارسال", value: "\(formatTomanFa(sendPrice)) تومان", icon: RemixIcons.TruckLine)
            SiteDashedDivider()
            AmountRow(label: "مبلغ نهایی", amount: totalFinalPrice, emphasized: walletDeduction <= 0)
            if walletDeduction > 0 {
                VStack(spacing: 0) {
                    AmountRow(label: "کسر از کیف پول", amount: abs(walletDeduction), icon: RemixIcons.Wallet3Line, valueColor: primary)
                    SiteDashedDivider()
                    AmountRow(label: "قابل‌پرداخت از درگاه", amount: payableAfterWallet, emphasized: true, valueColor: primary)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: couponDiscount > 0)
        .animation(.easeInOut(duration: 0.25), value: walletDeduction > 0)
    }
}

/** ردیف مبلغ هم‌شکل SiteKeyValueRow، ولی با تغییر انیمیشنیِ عدد */
private struct AmountRow: View {
    let label: String
    let amount: Int64
    var icon: String? = nil
    var valueColor: Color? = nil
    var emphasized: Bool = false
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            if let icon {
                RemixIcon(icon, tint: colors.onSurfaceVariant, size: 16)
                Spacer().frame(width: 6)
            }
            Text(label)
                .shkFont(emphasized ? 13 : 12, emphasized ? .bold : .regular)
                .foregroundColor(emphasized ? colors.onSurface : colors.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
            AnimatedAmountText(amount: amount, fontSize: emphasized ? 15 : 13, weight: emphasized ? .bold : .medium,
                               color: valueColor ?? colors.onSurface)
        }
        .padding(.vertical, 6)
    }
}

/** مبلغ با انیمیشن بالا/پایین رفتن عدد هنگام تغییر (AnimatedContent اندروید) */
struct AnimatedAmountText: View {
    let amount: Int64
    let fontSize: CGFloat
    let weight: Font.Weight
    let color: Color
    @State private var shown: Int64? = nil
    @State private var goingUp = true

    var body: some View {
        let value = shown ?? amount
        ZStack {
            Text("\(formatTomanFa(value)) تومان")
                .shkFont(fontSize, weight)
                .foregroundColor(color)
                .lineLimit(1)
                .id(value)
                .transition(.asymmetric(
                    insertion: .move(edge: goingUp ? .bottom : .top).combined(with: .opacity),
                    removal: .move(edge: goingUp ? .top : .bottom).combined(with: .opacity)
                ))
        }
        .clipped()
        .onChange(of: amount) { newValue in
            goingUp = newValue > (shown ?? newValue)
            withAnimation(.easeInOut(duration: 0.3)) { shown = newValue }
        }
        .onAppear { shown = amount }
    }
}

/** فاز ۱۴: بخش درج کد تخفیف با اعمال/حذف و نمایش پیام نتیجه - بازطراحی: کارت بازشونده با انیمیشن */
private struct DiscountCodeCard: View {
    let code: String
    let onCodeChange: (String) -> Void
    let hasApplied: Bool
    let isBusy: Bool
    let message: String?
    let isError: Bool
    let couponDiscount: Int64
    let onApply: () -> Void
    let onRemove: () -> Void
    var isAuto: Bool = false
    // روش پرداخت آفلاین انتخاب شده: کارت خاکستری و غیرقابل استفاده
    var disabled: Bool = false

    @Environment(\.shkColors) private var colors
    @State private var expanded = false
    @State private var shake: CGFloat = 0

    var body: some View {
        let primary = colors.primary
        let errorColor = colors.error
        let success = SiteStatusColors.Success
        let showError = isError && message != nil
        let borderColor: Color = showError ? errorColor.opacity(0.6)
            : hasApplied ? success.opacity(0.6)
            : expanded ? primary.opacity(0.3) : .clear

        SiteCard(contentPadding: .all(0), borderColor: borderColor) {
            // سرتیتر قابل‌لمس برای باز/بسته کردن
            HStack(spacing: 0) {
                SiteIconBadge(icon: hasApplied ? RemixIcons.CheckboxCircleLine : RemixIcons.Coupon3Line, tint: hasApplied ? success : primary)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text("کد تخفیف").shkFont(13, .bold).foregroundColor(colors.onSurface)
                    Text(disabled ? "در روش پرداخت انتخابی، کد تخفیف اعمال نمی‌شود"
                         : hasApplied && isAuto ? "تخفیف به‌صورت خودکار روی سفارش شما اعمال شده است"
                         : hasApplied ? "کد تخفیف روی سفارش شما اعمال شده است"
                         : "کد تخفیف دارید؟ اینجا وارد کنید")
                        .shkFont(11, lineHeight: 18)
                        .foregroundColor(hasApplied && !disabled ? success : colors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RemixIcon(RemixIcons.ArrowDownSLine, tint: colors.onSurfaceVariant, size: 22)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture { if !disabled { withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() } } }

            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    SiteDashedDivider().padding(.bottom, 12)
                    HStack(spacing: 0) {
                        SiteTextField(
                            value: Binding(get: { code }, set: onCodeChange),
                            placeholder: "کد تخفیف را وارد کنید",
                            leadingIcon: RemixIcons.Coupon2Line,
                            submitLabel: .done,
                            onSubmit: { if !code.isBlankShk && !hasApplied && !disabled { onApply() } },
                            isError: showError,
                            enabled: !hasApplied && !disabled
                        )
                        .frame(maxWidth: .infinity)
                        Spacer().frame(width: 8)
                        if hasApplied {
                            SiteSecondaryButton(text: "حذف", onClick: { if !disabled { onRemove() } }, icon: RemixIcons.DeleteBin6Line,
                                                loading: isBusy, height: 46, fontSize: 13)
                        } else {
                            SitePrimaryButton(text: "اعمال", onClick: onApply, enabled: !code.isBlankShk && !disabled,
                                              loading: isBusy, height: 46, fontSize: 13)
                        }
                    }

                    // حالت موفق: تیک سبز + مبلغ صرفه‌جویی
                    if hasApplied && !isError {
                        HStack(spacing: 0) {
                            ZStack {
                                Circle().fill(success)
                                RemixIcon(RemixIcons.CheckLine, tint: .white, size: 18)
                            }
                            .frame(width: 30, height: 30)
                            Spacer().frame(width: 10)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(message ?? (isAuto ? "تخفیف خودکار اعمال شد." : "کد تخفیف اعمال شد."))
                                    .shkFont(12, .bold, lineHeight: 20)
                                    .foregroundColor(success)
                                if couponDiscount > 0 {
                                    HStack(spacing: 0) {
                                        Text("سود شما از این کد: ").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                                        AnimatedAmountText(amount: couponDiscount, fontSize: 12, weight: .bold, color: success)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(success.opacity(0.1)))
                        .padding(.top, 12)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }

                    // پیام خطا (یا پیام عادی) زیر فیلد
                    if let message, isError || !hasApplied {
                        HStack(spacing: 0) {
                            RemixIcon(isError ? RemixIcons.ErrorWarningLine : RemixIcons.InformationLine,
                                      tint: isError ? errorColor : primary, size: 15)
                            Spacer().frame(width: 5)
                            Text(message).shkFont(11, lineHeight: 18).foregroundColor(isError ? errorColor : primary)
                        }
                        .padding(.top, 8).padding(.leading, 4)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .opacity(disabled ? 0.5 : 1)
        .offset(x: shake)
        .animation(.easeInOut(duration: 0.25), value: hasApplied)
        .animation(.easeInOut(duration: 0.25), value: message)
        .animation(.easeInOut(duration: 0.2), value: borderColor)
        // اگه کد اعمال شده یا پیامی هست، کادر باز بمونه
        .onAppear { if hasApplied || message != nil { expanded = true } }
        .onChange(of: hasApplied) { if $0 { withAnimation { expanded = true } } }
        .onChange(of: message) { m in
            if m != nil { withAnimation { expanded = true } }
            // لرزش کوتاه کادر هنگام خطای کد تخفیف
            if isError && m != nil { runShake() }
        }
    }

    private func runShake() {
        Task { @MainActor in
            for _ in 0..<3 {
                withAnimation(.linear(duration: 0.045)) { shake = 10 }
                try? await Task.sleep(nanoseconds: 45_000_000)
                withAnimation(.linear(duration: 0.045)) { shake = -10 }
                try? await Task.sleep(nanoseconds: 45_000_000)
            }
            withAnimation(.linear(duration: 0.045)) { shake = 0 }
        }
    }
}

/**
 * برچسب وضعیت تخفیف بالای کارت کد تخفیف:
 * active = تخفیف (معمولاً خودکار) اعمال شده، pending = با رسیدن سبد به شرط تخفیف اعمال می‌شه.
 */
private struct DiscountLabelBanner: View {
    let label: DiscountLabelDto?
    let autoDiscount: AutoDiscountDto?
    let hasApplied: Bool
    @Environment(\.shkColors) private var colors

    var body: some View {
        let isPending = label?.type == "pending"
        let isActive = label?.type == "active" && hasApplied
        let showAutoBadge = autoDiscount != nil && hasApplied && !isPending
        if isPending || isActive || showAutoBadge {
            let tint = isPending ? colors.primary : SiteStatusColors.Success
            let title = nonBlank(label?.title) ?? nonBlank(autoDiscount?.title)
            let message = nonBlank(label?.message)
            HStack(spacing: 0) {
                RemixIcon(isPending ? RemixIcons.InformationLine : RemixIcons.CheckboxCircleLine, tint: tint, size: 20)
                Spacer().frame(width: 8)
                VStack(alignment: .leading, spacing: 0) {
                    if showAutoBadge && !isPending {
                        Text("اعمال خودکار").shkFont(10, .bold).foregroundColor(tint)
                    }
                    if let title {
                        Text(title).shkFont(12, .bold, lineHeight: 20).foregroundColor(tint)
                    }
                    if let message {
                        Text(message).shkFont(11, lineHeight: 18).foregroundColor(colors.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.1)))
            .padding(.bottom, 8)
        }
    }

    private func nonBlank(_ s: String?) -> String? { (s?.isBlankShk == false) ? s : nil }
}

/** فاز ۱۴: نمایش موجودی کیف پول + سوییچ فعال‌سازی کسر از کیف پول - بازطراحی: کارت سوییچ با انیمیشن */
private struct WalletDeductionCard: View {
    let walletBalance: Int64
    let useWallet: Bool
    let walletDeduction: Int64
    let onToggle: (Bool) -> Void
    var disabled: Bool = false
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let hasBalance = walletBalance > 0
        let active = useWallet && hasBalance && !disabled
        SiteCard(onClick: hasBalance && !disabled ? { onToggle(!useWallet) } : nil, borderColor: active ? primary.opacity(0.5) : .clear) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.Wallet3Line, tint: active ? primary : colors.onSurfaceVariant)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text("کسر از کیف پول").shkFont(13, .bold).foregroundColor(colors.onSurface)
                    Text("موجودی: \(formatTomanFa(walletBalance)) تومان")
                        .shkFont(11, lineHeight: 18)
                        .foregroundColor(colors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MaterialSwitch(checked: active, enabled: hasBalance && !disabled, onCheckedChange: onToggle)
            }

            if active {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.CheckboxCircleLine, tint: primary, size: 16)
                    Spacer().frame(width: 6)
                    Text("کسر از کیف پول").shkFont(12).foregroundColor(colors.onSurface).frame(maxWidth: .infinity, alignment: .leading)
                    AnimatedAmountText(amount: walletDeduction, fontSize: 13, weight: .bold, color: primary)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(primary.opacity(0.08)))
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if disabled {
                NotAppliedLine(text: "در روش پرداخت انتخابی، کسر از کیف پول اعمال نمی‌شود.")
            } else if !hasBalance {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.InformationLine, tint: colors.onSurfaceVariant, size: 14)
                    Spacer().frame(width: 5)
                    Text("موجودی کیف پول شما صفر است؛ این گزینه فعلاً غیرفعال است.")
                        .shkFont(11, lineHeight: 18)
                        .foregroundColor(colors.onSurfaceVariant)
                }
                .padding(.top, 10)
            }
        }
        .opacity(disabled ? 0.5 : 1)
        .animation(.easeInOut(duration: 0.25), value: active)
        .animation(.easeInOut(duration: 0.25), value: disabled)
    }
}

/// سوییچ به سبک Material 3 اندروید (Switch): ریل ۵۲×۳۲، دستگیره‌ی ۲۴ (روشن) / ۱۶ (خاموش)
struct MaterialSwitch: View {
    let checked: Bool
    var enabled: Bool = true
    let onCheckedChange: (Bool) -> Void
    var checkedTrackColor: Color? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = checkedTrackColor ?? colors.primary
        let track = checked ? primary : colors.surfaceVariant
        let border = checked ? primary : colors.onSurfaceVariant
        let thumb = checked ? Color.white : colors.onSurfaceVariant
        ZStack(alignment: checked ? .trailing : .leading) {
            Capsule().fill(track)
            Capsule().strokeBorder(border, lineWidth: 2)
            Circle().fill(thumb)
                .frame(width: checked ? 24 : 16, height: checked ? 24 : 16)
                .padding(.horizontal, checked ? 4 : 8)
        }
        .frame(width: 52, height: 32)
        .environment(\.layoutDirection, .rightToLeft)
        .opacity(enabled ? 1 : 0.38)
        .animation(.easeInOut(duration: 0.2), value: checked)
        .contentShape(Rectangle())
        .onTapGesture { if enabled { onCheckedChange(!checked) } }
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(checked ? "روشن" : "خاموش")
    }
}

/** نوار پایینِ ثابت تسویه‌حساب */
private struct CheckoutBottomBar: View {
    let showAmount: Bool
    let payable: Int64
    let usesWallet: Bool
    let canContinue: Bool
    let warning: String?
    let buttonText: String
    let buttonIcon: String
    let loading: Bool
    let onContinue: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let warning {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.ErrorWarningLine, tint: SiteStatusColors.Warning, size: 15)
                    Spacer().frame(width: 5)
                    Text(warning).shkFont(11).foregroundColor(SiteStatusColors.Warning)
                }
                .padding(.bottom, 10)
                .transition(.opacity)
            }
            HStack(spacing: 12) {
                if showAmount {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(usesWallet ? "قابل‌پرداخت از درگاه" : "مبلغ قابل پرداخت")
                            .shkFont(11)
                            .foregroundColor(colors.onSurfaceVariant)
                        AnimatedAmountText(amount: payable, fontSize: 16, weight: .bold, color: colors.onSurface)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                SitePrimaryButton(text: buttonText, onClick: onContinue, icon: buttonIcon,
                                  enabled: canContinue && !loading, loading: loading, fillWidth: true)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            TopRoundedShape(radius: 20)
                .fill(colors.surface)
                .shadow(color: .black.opacity(0.14), radius: 9, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.easeInOut(duration: 0.25), value: warning)
    }
}
