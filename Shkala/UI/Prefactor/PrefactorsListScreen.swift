import SwiftUI

// معادل ui/prefactor/PrefactorsListScreen.kt

private enum PrefactorFilter: Int, CaseIterable {
    case ALL, PAID, WAITING

    var label: String {
        switch self {
        case .ALL: return "همه"
        case .PAID: return "پرداخت‌شده"
        case .WAITING: return "در انتظار پرداخت"
        }
    }
    var icon: String? { nil }
}

private struct PrefactorsQuery: Equatable {
    let search: String
    let filter: PrefactorFilter
}

struct PrefactorsListScreen: View {
    let onBack: () -> Void
    let onOpenPrefactor: (String) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = PrefactorRepository()
    @ObservedObject private var viewedPrefactorsManager = ViewedPrefactorsManager.shared

    @State private var searchText = ""
    @State private var selectedFilter: PrefactorFilter = .ALL
    @State private var prefactors: [PrefactorDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private func fetch() async -> ApiResult<[PrefactorDto]> {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        return await repository.getPrefactors(
            search: q.isEmpty ? nil : q,
            paid: selectedFilter == .PAID ? true : nil,
            waitingPayment: selectedFilter == .WAITING ? true : nil
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "پیش‌فاکتورهای من", onBack: onBack)

            SiteSearchField(
                value: $searchText,
                placeholder: "جستجو بر اساس شناسه‌ی پیش‌فاکتور...",
                loading: isLoading && !searchText.isEmpty
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            SiteSegmentedTabs(
                tabs: PrefactorFilter.allCases.map { ($0.label, $0.icon) },
                selectedIndex: selectedFilter.rawValue,
                onSelect: { index in selectedFilter = PrefactorFilter(rawValue: index) ?? .ALL }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Group {
                if isLoading {
                    SiteLoading(message: "در حال دریافت پیش‌فاکتورها...", icon: RemixIcons.FileList3Line)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    SiteEmptyState(icon: RemixIcons.ErrorWarningLine, title: "خطا در دریافت پیش‌فاکتورها", subtitle: errorMessage)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if prefactors.isEmpty {
                    SiteEmptyState(icon: RemixIcons.FileList3Line, title: "پیش‌فاکتوری پیدا نشد", subtitle: nil)
                        .padding(16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // کشیدن صفحه به پایین: فهرست با همون جستجو/فیلتر فعلی بی‌صدا تازه می‌شه
                    // (در صورت خطا فهرست قبلی حفظ می‌شه)
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            // اصلاحیه (پیشگیری از کرش «Key already used»): آیتم تکراری یکتا می‌شه
                            ForEach(prefactors.uniqueById()) { prefactor in
                                PrefactorRow(
                                    prefactor: prefactor,
                                    isViewed: viewedPrefactorsManager.viewedPrefactorUuids.contains(prefactor.uuid),
                                    onClick: { onOpenPrefactor(prefactor.uuid) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 16)
                    }
                    .sitePullRefresh {
                        if case .success(let data) = await fetch() { prefactors = data }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        // جستجوی زنده - با یه تاخیر کوتاه بعد از هر تایپ، درخواست جدید می‌ره
        .task(id: PrefactorsQuery(search: searchText, filter: selectedFilter)) {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            isLoading = true
            errorMessage = nil
            switch await fetch() {
            case .success(let data): prefactors = data
            case .error(let message): errorMessage = message
            }
            isLoading = false
        }
    }
}

private struct PrefactorRow: View {
    let prefactor: PrefactorDto
    let isViewed: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let newColor = SiteStatusColors.Success
        SiteCard(onClick: onClick, borderColor: !isViewed ? newColor : nil) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        SiteIconBadge(icon: RemixIcons.FileList3Line, size: 44, iconSize: 22)
                        // نشانگر «مشاهده‌نشده»
                        if !isViewed {
                            Circle()
                                .fill(newColor)
                                .padding(2)
                                .background(Circle().fill(colors.surface))
                                .frame(width: 11, height: 11)
                        }
                    }
                    Spacer().frame(width: 12)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(prefactor.title.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
                             ?? "پیش‌فاکتور #\(String(prefactor.uuid.prefix(8)).toPersianDigits())")
                            .shkFont(13, .bold, lineHeight: 21)
                            .foregroundColor(colors.onSurface)
                            .lineLimit(2)
                            .truncationMode(.tail)
                        Text("شناسه: \(prefactor.uuid.toPersianDigits())")
                            .shkFont(11)
                            .foregroundColor(colors.onSurfaceVariant)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
                }
                Spacer().frame(height: 10)
                SiteDashedDivider()
                Spacer().frame(height: 8)
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.Calendar2Line, tint: colors.onSurfaceVariant, size: 13)
                    Spacer().frame(width: 4)
                    Text(prefactor.jalaliCreatedAt.jalaliDateLabel() ?? "")
                        .shkFont(11)
                        .foregroundColor(colors.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    PrefactorViewedBadge(isViewed: isViewed)
                    Spacer().frame(width: 6)
                    PrefactorStatusBadge(status: prefactor.status, isExpired: prefactor.isExpired)
                }
                if !prefactor.isExpired && prefactor.status == "waiting_payment" {
                    Spacer().frame(height: 6)
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.TimerLine, tint: colors.error, size: 13)
                        Spacer().frame(width: 4)
                        Text("انقضا: \(prefactor.jalaliExpiredAt.jalaliDateLabel() ?? "")")
                            .shkFont(11, .medium)
                            .foregroundColor(colors.error)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

private struct PrefactorViewedBadge: View {
    let isViewed: Bool
    var body: some View {
        SiteStatusChip(
            text: isViewed ? "مشاهده شده" : "مشاهده کنید",
            color: isViewed ? SiteStatusColors.Neutral : SiteStatusColors.Success,
            icon: isViewed ? RemixIcons.CheckDoubleLine : RemixIcons.EyeLine
        )
    }
}

private struct PrefactorStatusBadge: View {
    let status: String
    let isExpired: Bool
    var body: some View {
        let (label, color): (String, Color) = {
            if isExpired { return ("منقضی شده", SiteStatusColors.Neutral) }
            if status == "paid" { return ("پرداخت شده", SiteStatusColors.Success) }
            if status == "waiting_payment" { return ("در انتظار پرداخت", SiteStatusColors.Warning) }
            return (status, SiteStatusColors.Neutral)
        }()
        SiteStatusChip(text: label, color: color)
    }
}
