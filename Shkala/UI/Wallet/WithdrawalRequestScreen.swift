import SwiftUI

// معادل ui/wallet/WithdrawalRequestScreen.kt

struct WithdrawalRequestScreen: View {
    let onBack: () -> Void
    let onSubmitted: () -> Void
    let onAddCard: () -> Void

    @Environment(\.shkColors) private var colors
    private let repository = WalletRepository()

    @State private var walletAmount: Int64 = 0
    @State private var withdrawalLimit: Int64 = 0
    @State private var cards: [BankCardDto] = []
    @State private var isLoading = true
    @State private var amountInput = ""
    @State private var selectedCardId: Int? = nil
    @State private var isSubmitting = false

    private func load() async {
        switch await repository.getWalletInfo() {
        case .success(let data):
            walletAmount = data.walletAmount
            withdrawalLimit = data.withdrawalLimit
            cards = data.bankCards
            if selectedCardId == nil { selectedCardId = cards.first?.id }
        case .error(let message):
            ShkToast.shared.show(message)
        }
        isLoading = false
    }

    private var enteredAmount: Int64? { Int64(amountInput) }

    private var amountValidationError: String? {
        if walletAmount <= 0 { return "موجودی کیف پول شما صفر است." }
        if amountInput.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
        guard let a = enteredAmount, a > 0 else { return "مبلغ را درست وارد کنید." }
        if a > walletAmount { return "مبلغ درخواستی بیشتر از موجودی کیف پول است." }
        if a < withdrawalLimit { return "مبلغ درخواستی کمتر از حداقل مبلغ قابل برداشت است." }
        return nil
    }

    private var canSubmit: Bool {
        (enteredAmount ?? 0) > 0 && amountValidationError == nil && !cards.isEmpty && selectedCardId != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "درخواست برداشت", onBack: onBack)

            if isLoading {
                SiteLoading(message: "در حال دریافت اطلاعات...", icon: RemixIcons.HandCoinLine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    content.padding(.horizontal, 16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        // تفاوت iOS: بعد از برگشت از «افزودن کارت» فهرست کارت‌ها تازه می‌شه
        // (در اندروید هم صفحه با برگشت دوباره ساخته و بارگذاری می‌شه)
        .onAppear { Task { await load() } }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 4)
            // خلاصه‌ی موجودی
            SiteCard {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: RemixIcons.Wallet3Line, size: 44, iconSize: 22)
                        Spacer().frame(width: 12)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("موجودی قابل برداشت").shkFont(12).foregroundColor(colors.onSurfaceVariant)
                            Text("\(formatTomanFa(walletAmount)) تومان").shkFont(17, .bold).foregroundColor(colors.onSurface)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer().frame(height: 8)
                    SiteDashedDivider()
                    SiteKeyValueRow(label: "حداقل مبلغ قابل برداشت", value: "\(formatTomanFa(withdrawalLimit)) تومان", icon: RemixIcons.InformationLine)
                }
            }

            Spacer().frame(height: 20)
            SiteSectionTitle("مبلغ درخواستی")
            Spacer().frame(height: 12)
            SiteCard {
                VStack(alignment: .leading, spacing: 0) {
                    SiteTextField(
                        value: $amountInput,
                        label: "مبلغ درخواستی (تومان)",
                        placeholder: "مبلغ را وارد کنید",
                        necessary: true,
                        leadingIcon: RemixIcons.MoneyDollarCircleLine,
                        keyboard: .number,
                        isError: amountValidationError != nil,
                        helperText: amountValidationError,
                        filter: { String($0.filter { $0.isASCII && $0.isNumber }) }
                    ) {
                        Text("تومان").shkFont(12).foregroundColor(colors.onSurfaceVariant)
                    }
                    // نمایش مبلغ با جداکننده‌ی هزارگان
                    if let a = enteredAmount, a > 0, amountValidationError == nil {
                        Spacer().frame(height: 8)
                        Text("\(formatTomanFa(a)) تومان").shkFont(12, .bold).foregroundColor(colors.primary)
                    }
                }
            }

            Spacer().frame(height: 20)
            SiteSectionTitle("کارت مقصد") {
                WalletAddCardPill(onClick: onAddCard)
            }
            Spacer().frame(height: 12)

            if cards.isEmpty {
                SiteCard(onClick: onAddCard) {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: RemixIcons.BankCardLine)
                        Spacer().frame(width: 12)
                        Text("برای ثبت درخواست برداشت، اول یک کارت بانکی اضافه کنید")
                            .shkFont(12, lineHeight: 20)
                            .foregroundColor(colors.onSurfaceVariant)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(cards) { card in
                        BankCardOption(card: card, selected: selectedCardId == card.id) { selectedCardId = card.id }
                    }
                }
            }

            Spacer().frame(height: 24)

            SitePrimaryButton(
                text: "ثبت درخواست برداشت",
                onClick: submit,
                icon: RemixIcons.HandCoinLine,
                enabled: canSubmit,
                loading: isSubmitting,
                fillWidth: true
            )
            Spacer().frame(height: 16)
        }
    }

    private func submit() {
        guard let amount = enteredAmount, let cardId = selectedCardId, canSubmit else { return }
        isSubmitting = true
        Task {
            switch await repository.addWithdrawal(amount: amount, bankCardId: cardId) {
            case .success(let msg):
                ShkToast.shared.show(msg)
                isSubmitting = false
                onSubmitted()
            case .error(let msg):
                isSubmitting = false
                ShkToast.shared.show(msg)
            }
        }
    }
}

/** کارت انتخاب کارت بانکی مقصد: آیکن بانک، نام بانک، شماره‌ی کارت و نام صاحب کارت */
private struct BankCardOption: View {
    let card: BankCardDto
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let digits = String(card.cardNumber.filter { $0.isASCII && $0.isNumber })
        let bank = bankNameFromCardNumber(digits)
        Button(action: onClick) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.BankCardLine, tint: selected ? primary : colors.onSurfaceVariant)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(formatCardNumberSpaced(digits.isEmpty ? card.cardNumber : digits))
                        .shkFont(14, .bold)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(1)
                    Text(bank != nil ? "\(card.name) • \(bank!)" : card.name)
                        .shkFont(11)
                        .foregroundColor(colors.onSurfaceVariant)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RemixIcon(selected ? RemixIcons.CheckboxCircleFill : RemixIcons.CheckboxBlankCircleLine,
                          tint: selected ? primary : colors.onSurfaceVariant, size: 22)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? primary : Color.clear, lineWidth: 1.5))
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(.plain)
    }
}
