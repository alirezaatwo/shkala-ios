import SwiftUI

// معادل ui/wallet/ChargeWalletScreen.kt

private let MIN_CHARGE_AMOUNT: Int64 = 500_000
private let MAX_CHARGE_AMOUNT: Int64 = 50_000_000

struct ChargeWalletScreen: View {
    let onBack: () -> Void
    let onOpenGateway: () -> Void

    @Environment(\.shkColors) private var colors
    private let repository = WalletRepository()
    private let flow = WalletFlowState.shared

    @State private var suggestedAmounts: [Int64] = []
    @State private var gateways: [PaymentGatewayDto] = []
    @State private var isLoading = true
    @State private var selectedAmount: Int64? = nil
    @State private var customAmount = ""
    @State private var selectedGatewayId: String? = nil
    @State private var isSubmitting = false

    private var finalAmount: Int64? { selectedAmount ?? Int64(customAmount.filter { $0.isASCII && $0.isNumber }) }

    private var amountError: String? {
        guard let a = finalAmount else { return nil }
        if a < MIN_CHARGE_AMOUNT { return "حداقل مبلغ شارژ \(formatTomanFa(MIN_CHARGE_AMOUNT)) تومان است." }
        if a > MAX_CHARGE_AMOUNT { return "حداکثر مبلغ شارژ \(formatTomanFa(MAX_CHARGE_AMOUNT)) تومان است." }
        if a % 500_000 != 0 { return "مبلغ باید مضربی از ۵۰۰,۰۰۰ تومان باشد." }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "شارژ کیف پول", onBack: onBack)

            if isLoading {
                SiteLoading(message: "در حال آماده‌سازی...", icon: RemixIcons.Wallet3Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // فاز ۲۹ (اصلاحیه): دکمه‌ی «پرداخت و شارژ» به‌صورت یک نوار ثابتِ پایینِ صفحه (مثل CardToCardScreen)
                VStack(spacing: 0) {
                    ScrollView {
                        formContent
                            .padding(.horizontal, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    // نوار ثابت پایین صفحه
                    let amountOk = (finalAmount ?? 0) > 0 && amountError == nil
                    SitePrimaryButton(
                        text: amountOk ? "پرداخت و شارژ (\(formatTomanFa(finalAmount ?? 0)) تومان)" : "پرداخت و شارژ",
                        onClick: onPayClick,
                        icon: RemixIcons.SecurePaymentLine,
                        enabled: amountOk,
                        loading: isSubmitting,
                        height: 50,
                        fillWidth: true
                    )
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        Rectangle()
                            .fill(colors.surface)
                            .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: -2)
                            .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task { await load() }
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 4)
            SiteHeroCard(icon: RemixIcons.Wallet3Line, title: "افزایش موجودی کیف پول", subtitle: "مبلغ و درگاه پرداخت را انتخاب کنید")

            if !suggestedAmounts.isEmpty {
                Spacer().frame(height: 20)
                SiteSectionTitle("مبلغ پیشنهادی")
                Spacer().frame(height: 12)
                FlowRow(spacing: 8, lineSpacing: 8) {
                    ForEach(suggestedAmounts, id: \.self) { amount in
                        AmountChip(text: "\(formatTomanFa(amount)) تومان", selected: selectedAmount == amount) {
                            // فاز ۲۹ (اصلاحیه): مبلغ پیشنهادیِ انتخاب‌شده داخل باکس «مبلغ دلخواه» هم نوشته می‌شه
                            selectedAmount = amount
                            customAmount = String(amount)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer().frame(height: 20)
            SiteSectionTitle("یا مبلغ دلخواه (تومان)")
            Spacer().frame(height: 12)
            SiteCard {
                VStack(alignment: .leading, spacing: 0) {
                    SiteTextField(
                        value: Binding(get: { customAmount }, set: { v in
                            customAmount = String(v.filter { $0.isASCII && $0.isNumber })
                            selectedAmount = nil
                        }),
                        placeholder: "مثلاً 500000",
                        leadingIcon: RemixIcons.MoneyDollarCircleLine,
                        keyboard: .number,
                        isError: amountError != nil,
                        helperText: amountError ?? "بین \(formatTomanFa(MIN_CHARGE_AMOUNT)) تا \(formatTomanFa(MAX_CHARGE_AMOUNT)) تومان، و مضربی از \(formatTomanFa(500_000)) تومان"
                    ) {
                        Text("تومان").shkFont(12).foregroundColor(colors.onSurfaceVariant)
                    }
                    // نمایش مبلغ واردشده با جداکننده‌ی هزارگان
                    if let a = finalAmount, a > 0 {
                        Spacer().frame(height: 8)
                        HStack(spacing: 6) {
                            RemixIcon(RemixIcons.CoinsLine, tint: colors.primary, size: 15)
                            Text("مبلغ شارژ: \(formatTomanFa(a)) تومان")
                                .shkFont(12, .bold)
                                .foregroundColor(colors.onSurface)
                        }
                    }
                }
            }

            Spacer().frame(height: 20)
            SiteSectionTitle("درگاه پرداخت")
            Spacer().frame(height: 12)
            VStack(spacing: 10) {
                ForEach(gateways) { gateway in
                    // کارت مشترک درگاه: لوگو + نام + توضیح زیر هر درگاه
                    GatewayOptionCard(
                        id: gateway.id,
                        label: gateway.label,
                        selected: selectedGatewayId == gateway.id,
                        description: gatewayDescription(gateway.id, gateway.label, cardToCardNote: "کیف پول پس از تأیید پرداخت شارژ می‌شود"),
                        onClick: { selectedGatewayId = gateway.id }
                    )
                }
            }

            Spacer().frame(height: 20)
        }
    }

    private func load() async {
        switch await repository.getWalletInfo() {
        case .success(let data):
            suggestedAmounts = data.suggestedAmounts
            gateways = data.paymentGateways
            selectedGatewayId = gateways.first?.id
        case .error(let message):
            ShkToast.shared.show(message)
        }
        isLoading = false
    }

    private func onPayClick() {
        guard let amount = finalAmount, amount > 0, amountError == nil else {
            ShkToast.shared.show("مبلغ را درست وارد کنید.")
            return
        }
        guard selectedGatewayId != nil else {
            ShkToast.shared.show("یک درگاه پرداخت انتخاب کنید.")
            return
        }
        if isVpnActive() {
            showVpnWarningDialog(onDismiss: {}, onContinueAnyway: { performCharge() })
        } else {
            performCharge()
        }
    }

    private func performCharge() {
        guard let amount = finalAmount, let gatewayId = selectedGatewayId else { return }
        isSubmitting = true
        Task {
            switch await repository.chargeWallet(amount: amount, paymentGateway: gatewayId) {
            case .success(let data):
                flow.pendingCharge = data
                isSubmitting = false
                onOpenGateway()
            case .error(let message):
                isSubmitting = false
                ShkToast.shared.show(message)
            }
        }
    }
}

/** چیپ مبلغ پیشنهادی (انتخاب‌شده: قرمز پُر) */
private struct AmountChip: View {
    let text: String
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let fg: Color = selected ? .white : colors.onSurface
        Button(action: onClick) {
            HStack(spacing: 4) {
                if selected { RemixIcon(RemixIcons.CheckLine, tint: fg, size: 15) }
                Text(text).shkFont(13, selected ? .bold : .medium).foregroundColor(fg)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? colors.primary : colors.surface))
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(.plain)
    }
}
