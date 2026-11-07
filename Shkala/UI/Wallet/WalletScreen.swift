import SwiftUI

// معادل ui/wallet/WalletScreen.kt

struct WalletScreen: View {
    let onBack: () -> Void
    let onOpenCharge: () -> Void
    let onOpenWithdraw: () -> Void
    let onOpenAddCard: () -> Void
    var onOpenEditCard: ((BankCardDto) -> Void)? = nil

    @Environment(\.shkColors) private var colors
    private let repository = WalletRepository()

    @State private var walletInfo: WalletInfoResponse? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    // نمایش/مخفی‌کردن شماره‌ی کارت‌ها (پیش‌فرض: مخفی)
    @State private var cardsRevealed = false

    private func load() async {
        switch await repository.getWalletInfo() {
        case .success(let data):
            walletInfo = data
            errorMessage = nil
        case .error(let message):
            errorMessage = message
        }
        isLoading = false
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "کیف پول", onBack: onBack)

            if isLoading {
                SiteLoading(message: "در حال دریافت اطلاعات کیف پول...", icon: RemixIcons.Wallet3Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, walletInfo == nil {
                SiteEmptyState(icon: RemixIcons.ErrorWarningLine, title: "خطا در دریافت اطلاعات", subtitle: errorMessage)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let info = walletInfo {
                // کشیدن صفحه به پایین: موجودی، کارت‌ها و برداشت‌ها بی‌صدا از سرور تازه می‌شن
                ScrollView {
                    content(info)
                }
                .sitePullRefresh { await load() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ info: WalletInfoResponse) -> some View {
        let primary = colors.primary
        VStack(spacing: 0) {
            Spacer().frame(height: 4)
            // کارت موجودی (گرادیان قرمز) + دکمه‌های سریع
            WalletBalanceHero(
                balance: info.walletAmount,
                withdrawalLimit: info.withdrawalLimit,
                onCharge: onOpenCharge,
                onWithdraw: onOpenWithdraw,
                onAddCard: onOpenAddCard
            )

            // کارت‌های بانکی
            Spacer().frame(height: 20)
            SiteSectionTitle("کارت‌های بانکی") {
                HStack(spacing: 0) {
                    if !info.bankCards.isEmpty {
                        // دکمه‌ی چشم: نمایش/مخفی‌کردن شماره‌ها
                        SiteIconButton(
                            icon: cardsRevealed ? RemixIcons.EyeOffLine : RemixIcons.EyeLine,
                            contentDescription: cardsRevealed ? "مخفی کردن شماره‌ها" : "نمایش شماره‌ها",
                            onClick: { cardsRevealed.toggle() },
                            size: 30,
                            tint: colors.onSurfaceVariant
                        )
                        Spacer().frame(width: 6)
                    }
                    WalletAddCardPill(onClick: onOpenAddCard)
                }
            }
            Spacer().frame(height: 12)

            if info.bankCards.isEmpty {
                SiteCard(onClick: onOpenAddCard) {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: RemixIcons.BankCardLine)
                        Spacer().frame(width: 12)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("هنوز کارتی ثبت نکرده‌اید").shkFont(13, .medium).foregroundColor(colors.onSurface)
                            Text("برای درخواست برداشت، یک کارت بانکی اضافه کنید")
                                .shkFont(11, lineHeight: 18)
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // اصلاحیه (پیشگیری از کرش «Key already used»): اگه سرور به هر دلیلی یک آیتم رو دوبار بفرسته، اینجا یکتا می‌شه
                        ForEach(info.bankCards.uniqueById()) { card in
                            WalletBankCardVisual(
                                cardNumber: card.cardNumber,
                                holderName: card.name,
                                onDelete: { confirmDelete(card) },
                                masked: !cardsRevealed,
                                shebaNumber: card.shebaNumber,
                                onEdit: onOpenEditCard.map { open in { open(card) } },
                                onCopyCard: {
                                    copyToClipboard(label: "شماره کارت", value: card.cardNumber.filter { $0.isASCII && $0.isNumber })
                                },
                                onCopySheba: {
                                    copyToClipboard(label: "شماره شبا", value: "IR" + shebaDigits(card.shebaNumber))
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // تاریخچه‌ی برداشت‌ها
            Spacer().frame(height: 20)
            SiteSectionTitle("تاریخچه‌ی درخواست‌های برداشت")
            Spacer().frame(height: 12)

            if info.withdrawals.isEmpty {
                SiteCard {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: RemixIcons.HandCoinLine, tint: SiteStatusColors.Neutral)
                        Spacer().frame(width: 12)
                        Text("هنوز درخواست برداشتی ثبت نکرده‌اید")
                            .shkFont(13)
                            .foregroundColor(colors.onSurfaceVariant)
                        Spacer(minLength: 0)
                    }
                }
            } else {
                SiteCard(contentPadding: .hv(14, 4)) {
                    VStack(spacing: 0) {
                        ForEach(Array(info.withdrawals.enumerated()), id: \.offset) { index, withdrawal in
                            WithdrawalRow(withdrawal: withdrawal, onCancel: { cancelWithdrawal(withdrawal.id) })
                            if index != info.withdrawals.count - 1 { SiteDashedDivider() }
                        }
                    }
                }
                if (info.pagination?.lastPage ?? 1) > 1 {
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.InformationLine, tint: colors.onSurfaceVariant, size: 15)
                        Spacer().frame(width: 6)
                        Text("برای دیدن سوابق قدیمی‌تر، از پنل کاربری سایت استفاده کنید")
                            .shkFont(11, lineHeight: 18)
                            .foregroundColor(colors.onSurfaceVariant)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 4)
                }
            }

            Spacer().frame(height: 24)
        }
        .padding(.horizontal, 16)
        .tint(primary)
    }

    private func cancelWithdrawal(_ id: Int) {
        Task {
            switch await repository.deleteWithdrawal(id) {
            case .success(let msg):
                ShkToast.shared.show(msg)
                await load()
            case .error(let msg):
                ShkToast.shared.show(msg)
            }
        }
    }

    private func confirmDelete(_ card: BankCardDto) {
        ShkDialogCenter.shared.show {
            SiteDialogContent(
                title: "حذف کارت بانکی",
                icon: RemixIcons.DeleteBin6Line,
                iconTint: colors.error,
                message: "مطمئنید می‌خواید این کارت رو حذف کنید؟",
                confirmText: "حذف کن",
                onConfirm: {
                    ShkDialogCenter.shared.dismiss()
                    Task {
                        switch await repository.deleteBankCard(card.id) {
                        case .success(let msg):
                            ShkToast.shared.show(msg)
                            await load()
                        case .error(let msg):
                            ShkToast.shared.show(msg)
                        }
                    }
                },
                confirmColor: colors.error,
                dismissText: "انصراف",
                onDismiss: { ShkDialogCenter.shared.dismiss() }
            )
        }
    }
}

/// دکمه‌ی کوچک «افزودن کارت» کنار عنوان بخش (در صفحه‌ی برداشت هم استفاده می‌شه)
struct WalletAddCardPill: View {
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 4) {
                RemixIcon(RemixIcons.AddLine, tint: colors.primary, size: 15)
                Text("افزودن کارت").shkFont(12, .bold).foregroundColor(colors.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

/** کارت موجودی: گرادیان قرمز، مبلغ بزرگ، آیکن کیف پول و دکمه‌های سریع */
private struct WalletBalanceHero: View {
    let balance: Int64
    let withdrawalLimit: Int64
    let onCharge: () -> Void
    let onWithdraw: () -> Void
    let onAddCard: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                RemixIcon(RemixIcons.Wallet3Line, tint: .white, size: 24)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.18)))
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text("موجودی کیف پول").shkFont(13).foregroundColor(.white.opacity(0.9))
                    Text("حداقل مبلغ قابل برداشت: \(formatTomanFa(withdrawalLimit)) تومان")
                        .shkFont(11, lineHeight: 18)
                        .foregroundColor(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
            }
            Spacer().frame(height: 16)
            HStack(alignment: .bottom, spacing: 6) {
                Text(formatTomanFa(balance))
                    .shkFont(30, .bold, lineHeight: 38)
                    .foregroundColor(.white)
                Text("تومان")
                    .shkFont(14, .medium)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.bottom, 5)
            }
            Spacer().frame(height: 18)
            HStack(spacing: 8) {
                WalletQuickAction(icon: RemixIcons.AddCircleLine, label: "شارژ کیف پول", onClick: onCharge)
                WalletQuickAction(icon: RemixIcons.HandCoinLine, label: "درخواست برداشت", onClick: onWithdraw)
                WalletQuickAction(icon: RemixIcons.BankCardLine, label: "افزودن کارت", onClick: onAddCard)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(colors: [primary, Color(argb: 0xFFB8000E)], startPoint: .topLeading, endPoint: .bottomTrailing)
                // دایره‌های تزئینی پس‌زمینه
                GeometryReader { geo in
                    Circle().fill(Color.white.opacity(0.07))
                        .frame(width: 170, height: 170)
                        .offset(x: -50, y: -60)
                    Circle().fill(Color.white.opacity(0.06))
                        .frame(width: 120, height: 120)
                        .offset(x: geo.size.width - 120 + 40, y: geo.size.height - 120 + 40)
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        )
        .clipShape(shape)
        .shadow(color: primary.opacity(0.4), radius: 10, x: 0, y: 4)
    }
}

private struct WalletQuickAction: View {
    let icon: String
    let label: String
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 0) {
                RemixIcon(icon, tint: colors.primary, size: 19)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white))
                Spacer().frame(height: 6)
                Text(label)
                    .shkFont(11, .bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }
}

/**
 * نمای کوچکِ کارت بانکی (گرادیان تیره، شماره‌ی ماسک‌شده، نام بانک از روی پیش‌شماره و نام صاحب کارت).
 * در صفحه‌ی کیف پول، انتخاب کارت برداشت و پیش‌نمایش افزودن کارت استفاده می‌شه.
 */
struct WalletBankCardVisual: View {
    let cardNumber: String
    let holderName: String
    var onDelete: (() -> Void)? = nil
    var masked: Bool = true
    /// nil = تمام عرض
    var width: CGFloat? = 270
    var shebaNumber: String? = nil
    var onEdit: (() -> Void)? = nil
    var onCopyCard: (() -> Void)? = nil
    var onCopySheba: (() -> Void)? = nil

    @Environment(\.shkColors) private var colors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let digits = String(cardNumber.filter { $0.isASCII && $0.isNumber })
        let bankName = bankNameFromCardNumber(digits) ?? "کارت بانکی"
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                RemixIcon(RemixIcons.BankLine, tint: .white, size: 20)
                Spacer().frame(width: 8)
                Text(bankName)
                    .shkFont(13, .bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let onEdit {
                    CardActionButton(icon: RemixIcons.PencilLine, contentDescription: "ویرایش", onClick: onEdit)
                    Spacer().frame(width: 6)
                }
                if let onDelete {
                    CardActionButton(icon: RemixIcons.DeleteBin6Line, contentDescription: "حذف", onClick: onDelete, size: 30, radius: 10, iconSize: 16)
                }
            }
            Spacer(minLength: 0)
            // تراشه‌ی کارت
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [Color(argb: 0xFFE9C46A), Color(argb: 0xFFC89B3C)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 34, height: 24)
            Spacer().frame(height: 10)
            // شماره‌ی کارت همیشه چپ‌به‌راست
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(masked ? maskCardNumber(digits) : formatCardNumberSpaced(padDots(String(digits.prefix(16)), 16)))
                        .shkFont(onCopyCard != nil ? 15 : 16, .bold)
                        .tracking(onCopyCard != nil ? 0.5 : 1)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let onCopyCard {
                        Spacer().frame(width: 6)
                        CardActionButton(icon: RemixIcons.FileCopyLine, contentDescription: "کپی شماره کارت", onClick: onCopyCard, size: 26)
                    }
                }
                // شماره‌ی شبا (کوچک‌تر، زیر شماره‌ی کارت)
                if let shebaNumber {
                    Spacer().frame(height: 4)
                    HStack(spacing: 0) {
                        let sheba = shebaDigits(shebaNumber)
                        Text("IR" + (masked ? maskShebaDigits(sheba) : sheba).toPersianDigits())
                            .shkFont(11)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let onCopySheba {
                            Spacer().frame(width: 6)
                            CardActionButton(icon: RemixIcons.FileCopyLine, contentDescription: "کپی شماره شبا", onClick: onCopySheba, size: 26)
                        }
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            Spacer().frame(height: 6)
            Text(holderName.trimmingCharacters(in: .whitespaces).isEmpty ? "نام صاحب کارت" : holderName)
                .shkFont(12)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(16)
        .frame(width: width, height: shebaNumber != nil ? 184 : 158, alignment: .topLeading)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .background(
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(argb: 0xFF2B2E43), Color(argb: 0xFF4A4F6A)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(colors.primary.opacity(0.35))
                    .frame(width: 150, height: 150)
                    .offset(x: -40, y: -70)
            }
            .environment(\.layoutDirection, .leftToRight)
        )
        .clipShape(shape)
        .shadow(color: Color(argb: 0xFF1F2233).opacity(0.45), radius: 6, x: 0, y: 3)
    }

    private func padDots(_ s: String, _ n: Int) -> String {
        s.count >= n ? s : s + String(repeating: "•", count: n - s.count)
    }
}

/** دکمه‌ی کوچک نیمه‌شفاف روی کارت (ویرایش/کپی/حذف) */
private struct CardActionButton: View {
    let icon: String
    let contentDescription: String
    let onClick: () -> Void
    var size: CGFloat = 30
    var radius: CGFloat = 9
    var iconSize: CGFloat? = nil

    var body: some View {
        Button(action: onClick) {
            RemixIcon(icon, contentDescription: contentDescription, tint: .white, size: iconSize ?? size * 0.53)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
    }
}

/** ارقام شبا بدون پیشوند IR (کارت‌های قدیمی ممکنه با IR ذخیره شده باشن) */
func shebaDigits(_ sheba: String) -> String { String(sheba.filter { $0.isASCII && $0.isNumber }) }

/** شبای ماسک‌شده: ۴ رقم اول و ۴ رقم آخر پیدا */
func maskShebaDigits(_ digits: String) -> String {
    if digits.count <= 8 { return digits }
    let chars = Array(digits)
    return String(chars.enumerated().map { i, c in (i < 4 || i >= chars.count - 4) ? c : "*" })
}

/** شماره‌ی کارت چهاررقمی جدا با ارقام فارسی (داخل ایزوله‌ی چپ‌به‌راست تا ترتیب گروه‌ها در متن راست‌چین برعکس نشه) */
func formatCardNumberSpaced(_ cardNumber: String) -> String {
    let chars = Array(cardNumber)
    let groups = stride(from: 0, to: chars.count, by: 4).map { String(chars[$0..<min($0 + 4, chars.count)]) }
    return "\u{2066}" + groups.joined(separator: " ").toPersianDigits() + "\u{2069}"
}

/** شماره‌ی کارت ماسک‌شده: ۶ رقم اول و ۴ رقم آخر پیدا، بقیه ستاره */
func maskCardNumber(_ digits: String) -> String {
    if digits.count < 12 { return formatCardNumberSpaced(digits) }
    let chars = Array(digits)
    let masked = String(chars.enumerated().map { i, c in (i < 6 || i >= chars.count - 4) ? c : "*" })
    return formatCardNumberSpaced(masked)
}

/** تشخیص نام بانک از ۶ رقم اول شماره‌ی کارت (پیش‌شماره‌های رسمی بانک‌ها) */
func bankNameFromCardNumber(_ digits: String) -> String? {
    if digits.count < 6 { return nil }
    switch String(digits.prefix(6)) {
    case "603799": return "بانک ملی"
    case "589210": return "بانک سپه"
    case "627648", "207177": return "بانک توسعه صادرات"
    case "627961": return "بانک صنعت و معدن"
    case "603770", "639217": return "بانک کشاورزی"
    case "628023": return "بانک مسکن"
    case "627760": return "پست بانک"
    case "502908": return "بانک توسعه تعاون"
    case "627412": return "بانک اقتصاد نوین"
    case "622106", "639194", "627884": return "بانک پارسیان"
    case "502229", "639347": return "بانک پاسارگاد"
    case "627488", "502910": return "بانک کارآفرین"
    case "621986": return "بانک سامان"
    case "639346": return "بانک سینا"
    case "639607": return "بانک سرمایه"
    case "636214": return "بانک آینده"
    case "502806", "504706": return "بانک شهر"
    case "502938": return "بانک دی"
    case "603769": return "بانک صادرات"
    case "610433", "991975": return "بانک ملت"
    case "627353", "585983": return "بانک تجارت"
    case "589463": return "بانک رفاه"
    case "505785": return "بانک ایران زمین"
    case "606373": return "بانک قرض‌الحسنه مهر ایران"
    case "505416": return "بانک گردشگری"
    case "628157": return "موسسه اعتباری توسعه"
    case "505801": return "موسسه اعتباری کوثر"
    case "606256": return "موسسه اعتباری ملل"
    case "585947": return "بانک خاورمیانه"
    case "504172": return "بانک قرض‌الحسنه رسالت"
    case "636949": return "بانک حکمت ایرانیان"
    case "639370": return "بانک مهر اقتصاد"
    case "639599": return "بانک قوامین"
    case "627381": return "بانک انصار"
    case "507677": return "موسسه اعتباری نور"
    default: return nil
    }
}

private struct WithdrawalRow: View {
    let withdrawal: WithdrawalDto
    let onCancel: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let (label, color) = withdrawalStatusStyle(withdrawal.status)
        HStack(spacing: 0) {
            SiteIconBadge(icon: RemixIcons.ArrowUpLine, size: 38, iconSize: 19, tint: color, radius: 11)
            Spacer().frame(width: 10)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(withdrawal.formattedAmount.toPersianDigits()) تومان")
                    .shkFont(14, .bold)
                    .foregroundColor(colors.onSurface)
                Spacer().frame(height: 2)
                HStack(spacing: 4) {
                    RemixIcon(RemixIcons.Calendar2Line, tint: colors.onSurfaceVariant, size: 13)
                    Text(withdrawal.jalaliCreatedAt.jalaliDateLabel() ?? "")
                        .shkFont(11)
                        .foregroundColor(colors.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            SiteStatusChip(text: label, color: color)
            if withdrawal.status == "awaiting" {
                Spacer().frame(width: 6)
                SiteIconButton(
                    icon: RemixIcons.DeleteBin6Line,
                    contentDescription: "لغو درخواست",
                    onClick: onCancel,
                    size: 32,
                    tint: colors.error,
                    background: colors.error.opacity(0.1)
                )
            }
        }
        .padding(.vertical, 10)
    }

    private func withdrawalStatusStyle(_ status: String) -> (String, Color) {
        switch status {
        case "awaiting": return ("در انتظار بررسی", SiteStatusColors.Warning)
        case "deposited": return ("واریز شده", SiteStatusColors.Success)
        case "deleted": return ("لغو شده", colors.error)
        default: return (status, SiteStatusColors.Neutral)
        }
    }
}
