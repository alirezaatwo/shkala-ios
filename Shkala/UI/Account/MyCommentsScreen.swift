import SwiftUI

// ===================================================================================
// معادل ui/account/MyCommentsScreen.kt
// ===================================================================================

/**
 * دیدگاه‌های من - نوار بالا با دکمه‌ی برگشت کادردار، باکس جستجو، کارت هر دیدگاه (محصول، متن،
 * نقاط قوت/ضعف، پاسخ فروشگاه، تاریخ و رأی‌ها) و حالت خالیِ طراحی‌شده.
 */
struct MyCommentsScreen: View {
    let onBack: () -> Void
    let onOpenProduct: (String) -> Void
    @Environment(\.shkColors) private var colors
    private let repository = CommentRepository()

    @State private var searchText = ""
    @State private var comments: [UserCommentDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private var query: String? {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? nil : q
    }

    // بروزرسانی با کشیدن صفحه: بدون لودینگ تمام‌صفحه؛ اگه خطا بده محتوای فعلی حفظ می‌شه
    private func refresh() async {
        switch await repository.getMyComments(search: query) {
        case .success(let data):
            comments = data
            errorMessage = nil
        case .error(let message):
            if errorMessage != nil { errorMessage = message }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(
                title: "دیدگاه‌های من",
                onBack: onBack,
                subtitle: (!isLoading && errorMessage == nil && !comments.isEmpty) ? "\(comments.count.toPersianDigits()) دیدگاه" : nil
            )
            SiteSearchField(value: $searchText, placeholder: "جستجو در متن دیدگاه‌ها...")
                .padding(.horizontal, 16)
            Spacer().frame(height: 4)

            Group {
                if isLoading {
                    SiteLoading(message: "در حال دریافت دیدگاه‌ها", icon: RemixIcons.ChatQuoteLine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ScrollView {
                        SiteEmptyState(icon: RemixIcons.WifiOffLine, title: "دریافت دیدگاه‌ها ممکن نشد", subtitle: errorMessage)
                            .padding(16)
                    }
                    .sitePullRefresh { await refresh() }
                } else if comments.isEmpty {
                    ScrollView {
                        SiteEmptyState(
                            icon: RemixIcons.ChatQuoteLine,
                            title: "دیدگاهی پیدا نشد",
                            subtitle: searchText.isBlankShk
                                ? "دیدگاه‌هایی که برای محصولات ثبت می‌کنید در این بخش نمایش داده می‌شوند."
                                : "با عبارت دیگری جستجو کنید."
                        )
                        .padding(16)
                    }
                    .sitePullRefresh { await refresh() }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(comments.uniqueById()) { comment in
                                CommentCard(comment: comment, onClick: { if let slug = comment.product?.slug { onOpenProduct(slug) } })
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .sitePullRefresh { await refresh() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            isLoading = true
            switch await repository.getMyComments(search: query) {
            case .success(let data):
                comments = data
                errorMessage = nil
            case .error(let message):
                errorMessage = message
            }
            isLoading = false
        }
    }
}

private struct CommentCard: View {
    let comment: UserCommentDto
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        SiteCard(onClick: onClick) {
            // سرتیتر: محصول و تاریخ
            HStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.ShoppingBag3Line, size: 38, iconSize: 19)
                Spacer().frame(width: 10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(comment.product?.title ?? "محصول")
                        .shkFont(13, .bold, lineHeight: 21)
                        .foregroundColor(colors.onSurface)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .truncationMode(.tail)
                    if let date = comment.jalaliCreatedAt.jalaliDateLabel(), !date.isBlankShk {
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.CalendarLine, tint: colors.onSurfaceVariant, size: 12)
                            Spacer().frame(width: 4)
                            Text(date.toPersianDigits()).shkFont(11).foregroundColor(colors.onSurfaceVariant)
                        }
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if comment.product?.slug != nil {
                    Spacer().frame(width: 6)
                    RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
                }
            }

            Spacer().frame(height: 12)
            SiteDashedDivider()
            Spacer().frame(height: 12)

            // متن دیدگاه
            Text(comment.content ?? "")
                .shkFont(13, lineHeight: 23)
                .foregroundColor(colors.onSurface)
                .fixedSize(horizontal: false, vertical: true)

            // نقاط قوت و ضعف
            if let strengths = comment.strengths, !strengths.isEmpty {
                Spacer().frame(height: 10)
                PointsBlock(title: "نقاط قوت", items: strengths, icon: RemixIcons.AddLine, color: SiteStatusColors.Success)
            }
            if let weakness = comment.weakness, !weakness.isEmpty {
                Spacer().frame(height: 8)
                PointsBlock(title: "نقاط ضعف", items: weakness, icon: RemixIcons.SubtractLine, color: colors.error)
            }

            // پاسخ فروشگاه
            if let answer = comment.answer, !answer.isBlankShk {
                Spacer().frame(height: 12)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: RemixIcons.Store2Line, size: 26, iconSize: 14, radius: 8)
                        Spacer().frame(width: 8)
                        Text("پاسخ فروشگاه").shkFont(12, .bold).foregroundColor(primary)
                    }
                    Spacer().frame(height: 6)
                    Text(answer)
                        .shkFont(12, lineHeight: 21)
                        .foregroundColor(colors.onSurface)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(primary.opacity(0.06)))
            }

            // رأی‌های مفید/غیرمفید
            Spacer().frame(height: 12)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                VoteChip(icon: RemixIcons.ThumbUpLine, count: comment.voteUp, color: SiteStatusColors.Success)
                VoteChip(icon: RemixIcons.ThumbDownLine, count: comment.voteDown, color: colors.onSurfaceVariant)
            }
        }
    }
}

private struct PointsBlock: View {
    let title: String
    let items: [String]
    let icon: String
    let color: Color
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).shkFont(12, .bold).foregroundColor(color)
            Spacer().frame(height: 4)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 0) {
                    RemixIcon(icon, tint: color, size: 14)
                    Spacer().frame(width: 6)
                    Text(item).shkFont(12, lineHeight: 20).foregroundColor(colors.onSurface)
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VoteChip: View {
    let icon: String
    let count: Int
    let color: Color
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(icon, tint: color, size: 14)
            Spacer().frame(width: 4)
            Text(count.toPersianDigits()).shkFont(11, .medium).foregroundColor(colors.onSurface)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surfaceVariant))
    }
}
