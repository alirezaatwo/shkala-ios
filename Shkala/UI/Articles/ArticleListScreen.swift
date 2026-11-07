import SwiftUI

/**
 * معادل ui/articles/ArticleListScreen.kt
 * فاز ۱۳: فهرست مقالات یک دسته‌بندی خاص - از تب «مقالات» باز می‌شود.
 * با کلیک روی یک مقاله، جزئیاتش گرفته می‌شود و از طریق onOpenArticle
 * (دقیقاً مثل توضیحات محصول) در همون صفحه‌ی مشترک نمایش داده می‌شود.
 *
 * بازطراحی: نوار بالای استاندارد (SitePageTopBar)، کارت‌های مقاله با تصویر گوشه‌گرد،
 * برچسب دسته‌بندی، عنوان و متای مقاله (تاریخ، زمان مطالعه، دیدگاه، بازدید، نویسنده)
 */
struct ArticleListScreen: View {
    // فاز ۳۱: nil یعنی «مجله» (همه‌ی مقالات، بدون فیلتر دسته‌بندی) - از منوی
    // همبرگری باز می‌شه؛ مقدار غیرِnil همون حالت قبلی (تب مقالات یک دسته‌بندی خاص)
    let categorySlug: String?
    let categoryTitle: String
    let onBack: () -> Void
    // فاز ۳۳ (کد ۱۲): پارامتر تصویر شاخص مقاله هم اضافه شد تا صفحه‌ی مقاله بتونه
    // تصویر رو تمام‌عرض در ابتدای محتوا نشون بده
    let onOpenArticle: (_ slug: String, _ title: String, _ html: String, _ imageUrl: String?) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = ContentRepository()

    @State private var articles: [ArticleListItemDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var isOpeningArticle = false
    // بازطراحی: کلید تلاش دوباره (فقط همون درخواست قبلی رو دوباره اجرا می‌کنه)
    @State private var reloadKey = 0
    // مقاله‌ای که در حال باز شدنه (برای نمایش لودینگ روی همون کارت)
    @State private var openingSlug: String? = nil
    @State private var loadedOnce = false

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: categoryTitle, onBack: onBack)

            if isLoading {
                SiteLoading(message: "در حال دریافت مقالات...", icon: RemixIcons.ArticleLine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, articles.isEmpty {
                SiteEmptyState(
                    icon: RemixIcons.ErrorWarningLine,
                    title: "مشکلی پیش آمد",
                    subtitle: errorMessage,
                    actionLabel: "تلاش دوباره",
                    actionIcon: RemixIcons.RefreshLine,
                    onAction: { reloadKey += 1 }
                )
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if articles.isEmpty {
                SiteEmptyState(
                    icon: RemixIcons.ArticleLine,
                    title: "مقاله‌ای پیدا نشد",
                    subtitle: "مقاله‌ای در این دسته‌بندی پیدا نشد."
                )
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // فاز ۳۳ (کد ۱۳): هر مقاله با تصویر تمام‌عرض نمایش داده می‌شه و عنوان/متا زیرش
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // خطای باز کردن مقاله (وقتی فهرست از قبل پره)
                        if let errorMessage {
                            HStack(spacing: 0) {
                                RemixIcon(RemixIcons.ErrorWarningLine, tint: colors.error, size: 18)
                                Spacer().frame(width: 8)
                                Text(errorMessage)
                                    .shkFont(12, .normal, lineHeight: 20)
                                    .foregroundColor(colors.error)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.error.opacity(0.1)))
                        }
                        // اصلاحیه (پیشگیری از کرش «Key already used»): آیتم‌های تکراری یکتا می‌شن
                        ForEach(articles.uniqueById()) { article in
                            ArticleListCard(
                                article: article,
                                isOpening: openingSlug == article.slug,
                                onClick: { openArticle(article) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                // کشیدن به پایین: فهرست مقالات بی‌صدا دوباره گرفته می‌شه؛ در خطا فهرست قبلی می‌مونه و پیام خطا بالای فهرست میاد
                .sitePullRefresh { await refresh() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task(id: reloadKey) {
            // برگشت از صفحه‌ی مقاله نباید فهرست رو دوباره بگیره (مثل remember اندروید)
            if loadedOnce && reloadKey == 0 { return }
            loadedOnce = true
            isLoading = true
            switch await repository.getArticles(category: categorySlug) {
            case .success(let data):
                articles = data.items
                errorMessage = nil
            case .error(let message):
                errorMessage = message
            }
            isLoading = false
        }
    }

    private func refresh() async {
        switch await repository.getArticles(category: categorySlug) {
        case .success(let data):
            articles = data.items
            errorMessage = nil
        case .error(let message):
            errorMessage = message
        }
    }

    private func openArticle(_ article: ArticleListItemDto) {
        if isOpeningArticle { return }
        Task {
            isOpeningArticle = true
            openingSlug = article.slug
            switch await repository.getArticleDetail(article.slug) {
            case .success(let data):
                onOpenArticle(article.slug, data.title, data.content ?? "", article.image?.url)
            case .error(let message):
                errorMessage = message
            }
            isOpeningArticle = false
            openingSlug = nil
        }
    }
}

/// کارت یک مقاله: تصویر گوشه‌گرد ۱۶:۹، برچسب دسته‌بندی، عنوان و ردیف متا
private struct ArticleListCard: View {
    let article: ArticleListItemDto
    let isOpening: Bool
    let onClick: () -> Void

    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard(onClick: onClick, contentPadding: .all(10)) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(colors.surfaceVariant)
                .overlay(RemoteImage(article.image?.url, contentDescription: article.title, contentScale: .crop))
                .overlay(alignment: .topLeading) {
                    // برچسب دسته‌بندی روی تصویر
                    if let categoryTitle = article.category?.title, !categoryTitle.isBlankShk {
                        Text(categoryTitle)
                            .shkFont(11, .bold)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.primary))
                            .padding(8)
                    }
                }
                .overlay {
                    // لودینگ باز شدن همین مقاله
                    if isOpening {
                        ZStack {
                            Color.black.opacity(0.35)
                            MaterialSpinner(color: .white, lineWidth: 3, size: 28)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer().frame(height: 10)
            Text(article.title)
                .shkFont(14, .bold, lineHeight: 24)
                .foregroundColor(colors.onSurface)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)

            let metaItems = articleListMetaItems(article)
            let authorName = article.author?.name
            if !metaItems.isEmpty || !(authorName ?? "").isBlankShk {
                Spacer().frame(height: 8)
                ArticleMetaFlow(items: metaItems, authorName: authorName)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
            }
        }
    }

    private func articleListMetaItems(_ article: ArticleListItemDto) -> [(String, String)] {
        var items: [(String, String)] = []
        if let date = articleListElement(article.jalaliCreatedAt, 3), !date.isBlankShk { items.append((RemixIcons.CalendarLine, date.toPersianDigits())) }
        if let readTime = article.readTime, !readTime.isBlankShk { items.append((RemixIcons.TimeLine, "زمان مطالعه: \(readTime.toPersianDigits())")) }
        if let count = article.commentsInfo?.count, !count.isBlankShk { items.append((RemixIcons.Chat3Line, "\(count.toPersianDigits()) دیدگاه")) }
        if let views = article.formattedViewCount, !views.isBlankShk { items.append((RemixIcons.EyeLine, "\(views.toPersianDigits()) بازدید")) }
        return items
    }
}

/**
 * ردیف متای مقاله (آیکن + متن) که در صورت کمبود جا به خط بعد می‌ره - مشترک بین
 * کارت فهرست مقالات و صفحه‌ی مقاله
 */
struct ArticleMetaFlow: View {
    let items: [(String, String)]
    var authorName: String? = nil

    var body: some View {
        FlowRow(spacing: 12, lineSpacing: 6) {
            if let authorName, !authorName.isBlankShk {
                ArticleMetaItem(icon: RemixIcons.UserLine, text: authorName, emphasized: true)
            }
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                ArticleMetaItem(icon: item.0, text: item.1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ArticleMetaItem: View {
    let icon: String
    let text: String
    var emphasized: Bool = false

    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(icon, tint: emphasized ? colors.primary : colors.onSurfaceVariant, size: 14)
            Spacer().frame(width: 4)
            Text(text)
                .shkFont(11, emphasized ? .bold : .normal, lineHeight: 18)
                .foregroundColor(emphasized ? colors.onSurface : colors.onSurfaceVariant)
                .lineLimit(1)
        }
    }
}

/// معادل getOrNull کاتلین برای آرایه‌ی تاریخ شمسی
func articleListElement(_ list: [String]?, _ index: Int) -> String? {
    guard let list, index >= 0, index < list.count else { return nil }
    return list[index]
}
