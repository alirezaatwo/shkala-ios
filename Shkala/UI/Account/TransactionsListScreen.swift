import SwiftUI

// ===================================================================================
// معادل ui/account/TransactionsListScreen.kt
// ===================================================================================

private enum TransactionFilter: CaseIterable {
    case ALL, SUCCESS, FAILED, DEPOSIT, WITHDRAWAL

    var label: String {
        switch self {
        case .ALL: return "همه"
        case .SUCCESS: return "موفق"
        case .FAILED: return "ناموفق"
        case .DEPOSIT: return "واریز"
        case .WITHDRAWAL: return "برداشت"
        }
    }

    var icon: String {
        switch self {
        case .ALL: return RemixIcons.ListCheck
        case .SUCCESS: return RemixIcons.CheckboxCircleLine
        case .FAILED: return RemixIcons.CloseCircleLine
        case .DEPOSIT: return RemixIcons.ArrowDownLine
        case .WITHDRAWAL: return RemixIcons.ArrowUpLine
        }
    }
}

private struct TransactionsQuery: Equatable {
    let search: String
    let filter: TransactionFilter
}

struct TransactionsListScreen: View {
    let onBack: () -> Void
    @Environment(\.shkColors) private var colors
    private let repository = AccountRepository()

    @State private var searchText = ""
    @State private var selectedFilter: TransactionFilter = .ALL
    @State private var transactions: [TransactionDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private func fetchTransactions() async -> ApiResult<TransactionsResponse> {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        return await repository.getTransactions(
            search: q.isEmpty ? nil : q,
            accepted: selectedFilter == .SUCCESS ? true : nil,
            rejected: selectedFilter == .FAILED ? true : nil,
            deposit: selectedFilter == .DEPOSIT ? true : nil,
            withdrawal: selectedFilter == .WITHDRAWAL ? true : nil
        )
    }

    // بروزرسانی با کشیدن صفحه: بدون لودینگ تمام‌صفحه؛ اگه خطا بده فهرست فعلی حفظ می‌شه
    private func refresh() async {
        if case .success(let data) = await fetchTransactions() {
            transactions = data.transactions
            errorMessage = nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "تراکنش‌های من", onBack: onBack)

            SiteSearchField(value: $searchText, placeholder: "جستجو بر اساس شناسه‌ی تراکنش...", loading: isLoading && !searchText.isEmpty)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TransactionFilter.allCases, id: \.self) { filter in
                        TransactionFilterPill(label: filter.label, icon: filter.icon, selected: selectedFilter == filter) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Group {
                if isLoading {
                    SiteLoading(message: "در حال دریافت تراکنش‌ها...", icon: RemixIcons.ExchangeDollarLine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    SiteEmptyState(icon: RemixIcons.ErrorWarningLine, title: "خطا در دریافت تراکنش‌ها", subtitle: errorMessage)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if transactions.isEmpty {
                    SiteEmptyState(icon: RemixIcons.ExchangeDollarLine, title: "تراکنشی پیدا نشد", subtitle: nil)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // کشیدن صفحه به پایین برای بروزرسانی تراکنش‌ها
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(transactions.uniqueById()) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 16)
                    }
                    .sitePullRefresh { await refresh() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        // جستجوی زنده - با یه تاخیر کوتاه بعد از هر تایپ، درخواست جدید می‌ره
        .task(id: TransactionsQuery(search: searchText, filter: selectedFilter)) {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            isLoading = true
            errorMessage = nil
            switch await fetchTransactions() {
            case .success(let data): transactions = data.transactions
            case .error(let message): errorMessage = message
            }
            isLoading = false
        }
    }
}

/** چیپ فیلتر (فعال: قرمز پُر) */
private struct TransactionFilterPill: View {
    let label: String
    let icon: String
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let fg = selected ? Color.white : colors.onSurfaceVariant
        Button(action: onClick) {
            HStack(spacing: 0) {
                RemixIcon(icon, tint: fg, size: 16)
                Spacer().frame(width: 5)
                Text(label).shkFont(12, selected ? .bold : .medium).foregroundColor(fg)
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

private struct TransactionRow: View {
    let transaction: TransactionDto
    @Environment(\.shkColors) private var colors

    var body: some View {
        let isDeposit = transaction.amount >= 0
        let flowColor = isDeposit ? SiteStatusColors.Success : colors.error
        SiteCard {
            HStack(spacing: 0) {
                // آیکن ورود/خروج وجه
                SiteIconBadge(icon: isDeposit ? RemixIcons.ArrowDownLine : RemixIcons.ArrowUpLine, size: 42, iconSize: 21, tint: flowColor)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(transactionTypeLabel(transaction.type, transaction.description))
                        .shkFont(13, .bold, lineHeight: 21)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    Spacer().frame(height: 3)
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.Calendar2Line, tint: colors.onSurfaceVariant, size: 13)
                        Spacer().frame(width: 4)
                        Text(transaction.jalaliCreatedAt.jalaliDateLabel() ?? "")
                            .shkFont(11)
                            .foregroundColor(colors.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 8)
                Text("\(isDeposit ? "+" : "")\(transaction.formattedAmount.toPersianDigits()) تومان")
                    .shkFont(14, .bold)
                    .foregroundColor(flowColor)
            }
            Spacer().frame(height: 10)
            SiteDashedDivider()
            Spacer().frame(height: 8)
            HStack(spacing: 0) {
                RemixIcon(RemixIcons.Hashtag, tint: colors.onSurfaceVariant, size: 13)
                Spacer().frame(width: 4)
                Text("شناسه: \(transaction.transactionId.toPersianDigits())")
                    .shkFont(11)
                    .foregroundColor(colors.onSurfaceVariant)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TransactionStatusBadge(status: transaction.status)
            }
        }
    }
}

private struct TransactionStatusBadge: View {
    let status: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        let (label, color): (String, Color) = {
            switch status {
            case "accepted": return ("موفق", SiteStatusColors.Success)
            case "rejected": return ("ناموفق", colors.error)
            case "waiting_payment": return ("در انتظار پرداخت", SiteStatusColors.Neutral)
            case "waiting_admin": return ("در انتظار بررسی", SiteStatusColors.Warning)
            default: return (status, SiteStatusColors.Neutral)
            }
        }()
        SiteStatusChip(text: label, color: color)
    }
}

/** اگه توضیح فارسی داشته باشه همونو نشون می‌ده، وگرنه بر اساس نوع تراکنش یه برچسب مناسب می‌سازه */
private func transactionTypeLabel(_ type: String, _ description: String?) -> String {
    if let description, !description.isBlankShk { return description }
    switch type {
    case "user_charge": return "شارژ کیف پول"
    case "bank_withdrawal": return "برداشت از کیف پول"
    case "order_decrease": return "کسر بابت سفارش"
    default: return type
    }
}
