import SwiftUI

// ===================================================================================
// معادل ui/partner/PartnerCommissionsScreen.kt
// ===================================================================================

private let PartnerLevels = ["bronze", "silver", "gold"]

private func partnerLevelLabel(_ level: String) -> String {
    switch level {
    case "gold": return "طلایی"
    case "silver": return "نقره‌ای"
    default: return "برنزی"
    }
}

private func partnerLevelColor(_ level: String) -> Color {
    switch level {
    case "gold": return Color(argb: 0xFFD4AF37)
    case "silver": return Color(argb: 0xFFB0B0B8)
    default: return Color(argb: 0xFFCD7F32)
    }
}

/// درصد پورسانت با رقم فارسی (۲.۵ => ۲٫۵٪)
private func percentText(_ rate: PartnerRateDto?) -> String {
    guard let c = rate?.commission else { return "-" }
    var text: String
    if c.truncatingRemainder(dividingBy: 1) == 0 {
        text = String(Int64(c))
    } else {
        text = String(c)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
    }
    return text.replacingOccurrences(of: ".", with: "٫").toPersianDigits() + "٪"
}

/**
 * «پورسانت همکاری»: محصولات دارای پورسانت با درصد هر سطح (سطح کاربر پررنگ) و کپی/اشتراک لینک معرفی هر محصول.
 */
struct PartnerCommissionsScreen: View {
    let onBack: () -> Void
    let onOpenProduct: (String) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = PartnerRepository()

    @State private var products: [PartnerProductDto] = []
    @State private var status: String? = nil
    @State private var level = "bronze"
    @State private var page = 1
    @State private var lastPage = 1
    @State private var loading = true
    @State private var loadingMore = false
    @State private var error: String? = nil
    @State private var search = ""
    @State private var appliedSearch = ""

    private func load(_ nextPage: Int, showLoading: Bool) async {
        if nextPage == 1 && showLoading { loading = true }
        if nextPage > 1 { loadingMore = true }
        let q = appliedSearch.isBlankShk ? nil : appliedSearch
        switch await repository.commissions(page: nextPage, search: q) {
        case .success(let data):
            error = nil
            status = data.partnerStatus
            level = data.level ?? "bronze"
            if nextPage == 1 { products = [] }
            let known = Set(products.map(\.id))
            products.append(contentsOf: data.products.filter { !known.contains($0.id) })
            page = data.pagination?.currentPage ?? nextPage
            lastPage = data.pagination?.lastPage ?? nextPage
        case .error(let message):
            if products.isEmpty { error = message } else { ShkToast.shared.show(message) }
        }
        loading = false
        loadingMore = false
    }

    private func loadMoreIfNeeded(_ product: PartnerProductDto) {
        guard !loading, !loadingMore, page < lastPage, !products.isEmpty else { return }
        // سه مورد مانده به آخر فهرست، صفحه‌ی بعد گرفته می‌شود (همان اندروید)
        guard let index = products.firstIndex(where: { $0.id == product.id }), index >= products.count - 3 else { return }
        Task { await load(page + 1, showLoading: false) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "پورسانت همکاری", onBack: onBack)
            Group {
                if loading && products.isEmpty {
                    SiteLoading(message: "در حال دریافت...", icon: RemixIcons.HandCoinLine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if error != nil && products.isEmpty {
                    SiteEmptyState(
                        icon: RemixIcons.ErrorWarningLine,
                        title: "دریافت اطلاعات ممکن نشد",
                        subtitle: error,
                        actionLabel: "تلاش دوباره",
                        actionIcon: RemixIcons.RefreshLine,
                        onAction: { Task { await load(1, showLoading: true) } }
                    )
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            intro
                            if products.isEmpty && !loading {
                                SiteEmptyState(
                                    icon: RemixIcons.HandCoinLine,
                                    title: "موردی یافت نشد",
                                    subtitle: appliedSearch.isBlankShk ? "فعلاً محصولی با پورسانت همکاری ثبت نشده است." : "عبارت دیگری را جستجو کنید."
                                )
                                .padding(.top, 24)
                            }
                            ForEach(products) { product in
                                CommissionCard(
                                    product: product,
                                    level: level,
                                    onOpen: { onOpenProduct(product.slug) },
                                    onCopy: { copyToClipboard(label: "لینک معرفی", value: product.link) },
                                    onShare: { presentShareSheet(text: "\(product.title)\n\(product.link)") }
                                )
                                .onAppear { loadMoreIfNeeded(product) }
                            }
                            if loadingMore {
                                ProgressView().tint(colors.primary).frame(width: 24, height: 24)
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                    .sitePullRefresh { await load(1, showLoading: false) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task(id: appliedSearch) { await load(1, showLoading: true) }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 0) {
            if status == "suspended" {
                let amber = Color(argb: 0xFFC27A00)
                HStack(alignment: .top, spacing: 8) {
                    RemixIcon(RemixIcons.ErrorWarningLine, tint: amber, size: 18)
                    Text("همکاری شما فعلاً معلق است؛ تا فعال شدن دوباره، پورسانت عادی محاسبه می‌شود.")
                        .shkFont(12, lineHeight: 20)
                        .foregroundColor(colors.onSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(amber.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Spacer().frame(height: 10)
            }
            Text("پورسانت هر محصول برای سطح‌های باشگاه مشتریان؛ ستون سطح شما پررنگ است. لینک معرفی هر محصول را کپی کنید و به اشتراک بگذارید.")
                .shkFont(12, lineHeight: 21)
                .foregroundColor(colors.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(height: 6)
            HStack(spacing: 0) {
                Text("سطح شما: ").shkFont(12).foregroundColor(colors.onSurfaceVariant)
                Text(partnerLevelLabel(level)).shkFont(12, .bold).foregroundColor(colors.onSurface)
                Spacer().frame(width: 6)
                Circle().fill(partnerLevelColor(level)).frame(width: 10, height: 10)
            }
            Spacer().frame(height: 12)
            SiteSearchField(
                value: $search,
                placeholder: "عنوان محصول ...",
                onSearch: { appliedSearch = search.trimmingCharacters(in: .whitespaces) },
                loading: loading
            )
        }
    }
}

private struct CommissionCard: View {
    let product: PartnerProductDto
    let level: String
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onShare: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        SiteCard {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    Color.clear
                        .frame(width: 52, height: 52)
                        .background(colors.surfaceVariant)
                        .overlay { if let image = product.image { RemoteImage(image, contentDescription: product.title, contentScale: .crop) } }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(product.title)
                        .shkFont(13, .bold, lineHeight: 21)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer().frame(height: 12)
            // سه سطح کنار هم؛ سطح کاربر با کادر رنگی
            HStack(alignment: .top, spacing: 8) {
                ForEach(PartnerLevels, id: \.self) { l in
                    let rate = product.rates[l]
                    let mine = l == level
                    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                    VStack(spacing: 0) {
                        HStack(spacing: 4) {
                            Circle().fill(partnerLevelColor(l)).frame(width: 8, height: 8)
                            Text(partnerLevelLabel(l)).shkFont(11).foregroundColor(colors.onSurfaceVariant)
                        }
                        Spacer().frame(height: 4)
                        Text(percentText(rate))
                            .shkFont(15, mine ? .bold : .medium)
                            .foregroundColor(mine ? primary : colors.onSurface)
                        if rate?.partner == true {
                            Spacer().frame(height: 3)
                            Text("همکار")
                                .shkFont(9, .bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        if let max = rate?.max, max > 0 {
                            Spacer().frame(height: 3)
                            Text("حداکثر \(formatTomanFa(max)) تومان هر عدد")
                                .shkFont(9, lineHeight: 14)
                                .foregroundColor(colors.onSurfaceVariant)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity)
                    .background(mine ? primary.opacity(0.08) : colors.surfaceVariant.opacity(0.6))
                    .overlay(shape.stroke(mine ? primary.opacity(0.4) : Color.clear, lineWidth: 1))
                    .clipShape(shape)
                }
            }
            Spacer().frame(height: 12)
            HStack(spacing: 8) {
                SiteSecondaryButton(text: "کپی لینک", onClick: onCopy, icon: RemixIcons.FileCopyLine, height: 40, fontSize: 12, fillWidth: true)
                SiteSecondaryButton(text: "اشتراک‌گذاری", onClick: onShare, icon: RemixIcons.ShareLine, height: 40, fontSize: 12, fillWidth: true)
            }
        }
    }
}
