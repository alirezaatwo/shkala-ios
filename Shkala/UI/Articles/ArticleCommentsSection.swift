import SwiftUI

/**
 * معادل ui/articles/ArticleCommentsSection.kt
 * فاز ۱۶: بخش دیدگاه‌های مقاله - زیر محتوای مقاله نمایش داده می‌شه. فقط وقتی
 * صفحه برای یک مقاله باز شده (articleSlug ست شده باشه) دیده می‌شه.
 *
 * منطق دقیقاً مطابق اسکریپت (CommentsController@add / ArticleComment::safe):
 * - فهرست فقط دیدگاه‌های منتشرشده (publish) رو نشون می‌ده، پاسخ‌ها هم زیرش تو در تو.
 * - ثبت دیدگاه نیاز به ورود داره؛ برای کاربر عادی وضعیت «در انتظار تایید» می‌مونه.
 *
 * بازطراحی: کارت فرم ثبت دیدگاه (SiteTextField + SitePrimaryButton) و کارت‌های دیدگاه
 * با آواتارِ حرف اول نام، نام، تاریخ، متن و پاسخ‌های تو در تو.
 */
struct ArticleCommentsSection: View {
    let articleSlug: String
    // کشیدن صفحه‌ی مقاله به پایین: با هر افزایش این عدد، دیدگاه‌ها بی‌صدا دوباره گرفته می‌شن
    var refreshSignal: Int = 0

    @Environment(\.shkColors) private var colors
    private let repository = ContentRepository()

    @State private var comments: [ArticleCommentDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    @State private var newComment = ""
    @State private var isSubmitting = false
    @State private var submitMessage: String? = nil
    // بازطراحی: فقط برای رنگ پیام (موفق/خطا) - در منطق ارسال تأثیری نداره
    @State private var submitIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SiteSectionTitle("دیدگاه‌ها") {
                if !comments.isEmpty {
                    Text("\(comments.count.toPersianDigits()) دیدگاه")
                        .shkFont(11, .bold)
                        .foregroundColor(colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.primary.opacity(0.1)))
                }
            }

            Spacer().frame(height: 12)

            // ---- فرم ثبت دیدگاه ----
            SiteCard {
                HStack(spacing: 0) {
                    SiteIconBadge(icon: RemixIcons.ChatSmile2Line, size: 38, iconSize: 19)
                    Spacer().frame(width: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("دیدگاه خود را بنویسید")
                            .shkFont(14, .bold)
                            .foregroundColor(colors.onSurface)
                        Text("نظر شما پس از تایید نمایش داده می‌شود.")
                            .shkFont(11, .normal, lineHeight: 18)
                            .foregroundColor(colors.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer().frame(height: 12)
                SiteTextField(
                    value: $newComment,
                    placeholder: "دیدگاه خود را درباره‌ی این مقاله بنویسید...",
                    singleLine: false,
                    minHeight: 110
                )
                if let submitMessage {
                    let color = submitIsError ? colors.error : SiteStatusColors.Success
                    HStack(spacing: 0) {
                        RemixIcon(submitIsError ? RemixIcons.ErrorWarningLine : RemixIcons.CheckboxCircleLine, tint: color, size: 18)
                        Spacer().frame(width: 8)
                        Text(submitMessage)
                            .shkFont(12, .normal, lineHeight: 20)
                            .foregroundColor(color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.1)))
                    .padding(.top, 10)
                    .transition(.opacity)
                }
                Spacer().frame(height: 12)
                SitePrimaryButton(
                    text: "ثبت دیدگاه",
                    onClick: submitComment,
                    icon: RemixIcons.SendPlane2Line,
                    enabled: !newComment.isBlankShk && !isSubmitting,
                    loading: isSubmitting,
                    fillWidth: true
                )
            }
            .animation(.easeInOut(duration: 0.25), value: submitMessage)

            Spacer().frame(height: 16)

            // ---- فهرست دیدگاه‌ها ----
            if isLoading {
                SiteLoading(message: "در حال دریافت دیدگاه‌ها...", size: 52)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if let errorMessage, comments.isEmpty {
                CommentsInfoBox(icon: RemixIcons.ErrorWarningLine, text: errorMessage, tint: colors.error)
            } else if comments.isEmpty {
                CommentsInfoBox(
                    icon: RemixIcons.Chat3Line,
                    text: "هنوز دیدگاهی برای این مقاله ثبت نشده است. اولین نفری باشید که نظر می‌دهد!",
                    tint: colors.primary
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(comments) { comment in
                        SiteCard(contentPadding: .all(14)) {
                            ArticleCommentItem(comment: comment)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 28)
        .task(id: articleSlug) { await load() }
        // بروزرسانی بی‌صدا (بدون اسپینر و بدون پاک شدن فهرست فعلی؛ در خطا، همون فهرست قبلی می‌مونه)
        .onChange(of: refreshSignal) { signal in
            guard signal > 0 else { return }
            Task {
                if case .success(let data) = await repository.getArticleComments(articleSlug) {
                    comments = data
                    errorMessage = nil
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        switch await repository.getArticleComments(articleSlug) {
        case .success(let data):
            comments = data
            errorMessage = nil
        case .error(let message):
            errorMessage = message
        }
        isLoading = false
    }

    private func submitComment() {
        if newComment.isBlankShk || isSubmitting { return }
        Task {
            isSubmitting = true
            submitMessage = nil
            switch await repository.addArticleComment(articleSlug, content: newComment.trimmingCharacters(in: .whitespacesAndNewlines)) {
            case .success(let message):
                submitMessage = message
                submitIsError = false
                newComment = ""
                Task { await load() }
            case .error(let message):
                submitMessage = message
                submitIsError = true
            }
            isSubmitting = false
        }
    }
}

/// کادر پیام ساده (خالی بودن یا خطای دریافت دیدگاه‌ها)
private struct CommentsInfoBox: View {
    let icon: String
    let text: String
    let tint: Color
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard {
            HStack(spacing: 0) {
                SiteIconBadge(icon: icon, size: 38, iconSize: 19, tint: tint)
                Spacer().frame(width: 10)
                Text(text)
                    .shkFont(12, .normal, lineHeight: 21)
                    .foregroundColor(colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// آواتار دایره‌ای با حرف اول نام
private struct CommentAvatar: View {
    let name: String
    let size: CGFloat
    let isReply: Bool
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let initial = trimmed.first.map { String($0) } ?? "؟"
        Text(initial)
            .shkFont(isReply ? 13 : 15, .bold)
            .foregroundColor(isReply ? SiteStatusColors.Info : primary)
            .frame(width: size, height: size)
            .background(Circle().fill(isReply ? SiteStatusColors.Info.opacity(0.12) : primary.opacity(0.12)))
    }
}

private struct ArticleCommentItem: View {
    let comment: ArticleCommentDto
    var isReply: Bool = false
    @Environment(\.shkColors) private var colors

    var body: some View {
        let name = comment.user?.name ?? "کاربر"
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                CommentAvatar(name: name, size: isReply ? 32 : 38, isReply: isReply)
                Spacer().frame(width: 10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .shkFont(13, .bold)
                        .foregroundColor(colors.onSurface)
                        .lineLimit(1)
                    if let date = articleListElement(comment.jalaliCreatedAt, 3) {
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.TimeLine, tint: colors.onSurfaceVariant, size: 12)
                            Spacer().frame(width: 3)
                            Text(date.toPersianDigits())
                                .shkFont(11, .normal)
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isReply {
                    RemixIcon(RemixIcons.ReplyLine, contentDescription: "پاسخ", tint: SiteStatusColors.Info, size: 16)
                }
            }
            Text(comment.content ?? "")
                .shkFont(13, .normal, lineHeight: 23)
                .foregroundColor(colors.onSurface)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            if !comment.answers.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(comment.answers.enumerated()), id: \.offset) { _, wrapper in
                        if let reply = wrapper.safe {
                            // پاسخ‌ها داخل کادر ملایم با نوار رنگی کنار
                            HStack(spacing: 0) {
                                SiteStatusColors.Info.frame(width: 3)
                                ArticleCommentItem(comment: reply, isReply: true)
                                    .padding(12)
                                    .frame(maxWidth: .infinity)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .background(colors.surfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
