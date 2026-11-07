import SwiftUI

// معادل ui/product/ReviewsSection.kt + ReviewsWiring.kt + QnaSection.kt اپ اندروید

/** رنگ ستاره‌های امتیاز */
let ProductRatingStarColor = Color(argb: 0xFFFFB400)

/** نمایش امتیاز اعشاری به شکل خوانا (۴ یا ۴.۵) با ارقام فارسی */
func formatProductRating(_ rating: Double) -> String {
    let text = rating.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(rating)) : String(format: "%.1f", locale: Locale(identifier: "en_US"), rating)
    return text.toPersianDigits()
}

/** تعداد سؤال‌ها (عدد یا رشته از سرور) به‌صورت متن با ارقام فارسی؛ اگه مقداری نبود nil */
func formatQuestionsCount(_ count: JSONValue?) -> String? {
    switch count {
    case .none, .some(.null): return nil
    case .some(.number(let n)): return Int64(n).toPersianDigits()
    case .some(.string(let s)): return s.isBlankShk ? nil : s.toPersianDigits()
    case .some(.bool(let b)): return String(b)
    default: return nil
    }
}

/** ردیف ۵ ستاره (پُر/نیمه/خالی) بر اساس امتیاز */
struct ProductRatingStars: View {
    let rating: Double
    var starSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { i in
                let icon: String = rating >= Double(i) ? RemixIcons.StarFill : (rating >= Double(i) - 0.5 ? RemixIcons.StarHalfFill : RemixIcons.StarLine)
                RemixIcon(icon, tint: ProductRatingStarColor, size: starSize)
            }
        }
    }
}

/** یک گزینه‌ی مرتب‌سازی (کلید پارامتر API سایت + عنوان + آیکن) */
struct ReviewSortOption {
    let key: String
    let title: String
    let icon: String
}

/** گزینه‌های مرتب‌سازی دیدگاه‌ها - دقیقاً مثل صفحه‌ی محصول سایت (clatest / useful / buyers) */
let ProductCommentSortOptions = [
    ReviewSortOption(key: "clatest", title: "جدیدترین دیدگاه‌ها", icon: RemixIcons.TimeLine),
    ReviewSortOption(key: "useful", title: "مفیدترین دیدگاه‌ها", icon: RemixIcons.ThumbUpLine),
    ReviewSortOption(key: "buyers", title: "دیدگاه خریداران", icon: RemixIcons.ShoppingBag3Line),
]

/** گزینه‌های مرتب‌سازی پرسش‌ها - دقیقاً مثل سایت (qlatest / noanswer / answer) */
let ProductQuestionSortOptions = [
    ReviewSortOption(key: "qlatest", title: "جدیدترین", icon: RemixIcons.TimeLine),
    ReviewSortOption(key: "noanswer", title: "بدون پاسخ", icon: RemixIcons.ChatOffLine),
    ReviewSortOption(key: "answer", title: "دارای پاسخ", icon: RemixIcons.ChatCheckLine),
]

/** مقدار پیش‌فرض (در سایت وقتی هیچ فیلتری نیست «جدیدترین» فعال است) */
let DefaultCommentSort = "clatest"
let DefaultQuestionSort = "qlatest"

/** پیام خطای سایت برای تصویر دیدگاه (messages.error_buyer_image) */
let ReviewImageErrorMessage = "تصویر انتخابی باید فرمت png یا jpg بوده و زیر ۲ مگ باشد"

/** ردیف چیپ‌های قرصی مرتب‌سازی (افقی و قابل اسکرول) */
struct ReviewSortChipsRow: View {
    let title: String
    let options: [ReviewSortOption]
    let selectedKey: String
    let onSelect: (String) -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(RemixIcons.ListSettingsLine, tint: colors.onSurfaceVariant, size: 16)
            Spacer().frame(width: 4)
            Text(title).shkFont(11).foregroundColor(colors.onSurfaceVariant)
            Spacer().frame(width: 8)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.key) { option in
                        ReviewSortChip(option: option, selected: option.key == selectedKey) {
                            if option.key != selectedKey { onSelect(option.key) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ReviewSortChip: View {
    let option: ReviewSortOption
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let fg = selected ? primary : colors.onSurfaceVariant
        Button(action: onClick) {
            HStack(spacing: 4) {
                RemixIcon(option.icon, tint: fg, size: 14)
                Text(option.title).shkFont(12, selected ? .bold : .medium).foregroundColor(fg).lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(selected ? primary.opacity(0.10) : colors.surface))
            .overlay(Capsule().strokeBorder(selected ? primary.opacity(0.6) : .clear, lineWidth: 1))
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(SitePressStyle())
    }
}

/**
 * بخش دیدگاه‌های محصول: خلاصه‌ی امتیاز (تعداد/میانگین/درصد پیشنهاد خرید) + لیست دیدگاه‌ها
 * + دکمه‌ی «مشاهده‌ی بیشتر» برای صفحه‌بندی + دکمه‌ی «ثبت دیدگاه».
 */
struct ReviewsSection: View {
    let commentsInfo: CommentsInfoDto?
    let comments: [ProductCommentDto]
    let hasMore: Bool
    let onLoadMore: () -> Void
    let onVote: (Int, Bool) -> Void
    let onWriteReviewClick: () -> Void
    var ratingBreakdown: [RatingBreakdownDto]? = nil
    var sortKey: String = DefaultCommentSort
    var onSortChange: ((String) -> Void)? = nil
    var isLoading: Bool = false
    /// کلیک روی تصویر دیدگاه (لایت‌باکس)
    var onImageClick: ([String], Int) -> Void = { _, _ in }

    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SiteSectionTitle("دیدگاه‌های خریداران")

            // ---- کارت خلاصه‌ی امتیاز ----
            SiteCard {
                let rating = commentsInfo?.rating ?? 0
                if let info = commentsInfo, rating > 0 || info.suggestionPercent != nil {
                    HStack(spacing: 0) {
                        if rating > 0 {
                            VStack(spacing: 0) {
                                HStack(alignment: .bottom, spacing: 0) {
                                    Text(formatProductRating(rating)).shkFont(30, .bold, lineHeight: 36).foregroundColor(colors.onSurface)
                                    Text(" از ۵").shkFont(11).foregroundColor(colors.onSurfaceVariant).padding(.bottom, 6)
                                }
                                ProductRatingStars(rating: rating, starSize: 15)
                                Text("از \(info.count.toPersianDigits()) دیدگاه").shkFont(11).foregroundColor(colors.onSurfaceVariant).padding(.top, 4)
                            }
                            Spacer().frame(width: 16)
                            Rectangle().fill(colors.outline.opacity(0.2)).frame(width: 1, height: 64)
                            Spacer().frame(width: 16)
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            if let suggestion = info.suggestionPercent {
                                // فاز ۳۴ (کد ۶): درصد پیشنهاد خرید - با نوار درصد
                                HStack(spacing: 6) {
                                    RemixIcon(RemixIcons.ThumbUpLine, tint: SiteStatusColors.Success, size: 16)
                                    Text("\(Int(suggestion).toPersianDigits())% پیشنهاد خرید می‌کنند").shkFont(12, .medium).foregroundColor(colors.onSurface)
                                }
                                Spacer().frame(height: 8)
                                ReviewPercentBar(fraction: suggestion / 100, color: SiteStatusColors.Success)
                            }
                            if rating > 0, let ratingPercent = info.ratingPercent {
                                Spacer().frame(height: 10)
                                HStack(spacing: 6) {
                                    RemixIcon(RemixIcons.StarLine, tint: ProductRatingStarColor, size: 16)
                                    Text("امتیاز \(Int(ratingPercent).toPersianDigits())%").shkFont(12, .medium).foregroundColor(colors.onSurface)
                                }
                                Spacer().frame(height: 8)
                                ReviewPercentBar(fraction: ratingPercent / 100, color: ProductRatingStarColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer().frame(height: 14)
                }
                // ---- نمودار تفکیک امتیازها ----
                let breakdownTotal = (ratingBreakdown ?? []).reduce(0) { $0 + $1.count }
                if let breakdown = ratingBreakdown, breakdownTotal > 0 {
                    RatingBreakdownChart(breakdown: breakdown, total: breakdownTotal)
                    Spacer().frame(height: 14)
                }
                SiteSecondaryButton(text: "ثبت دیدگاه", onClick: onWriteReviewClick, icon: RemixIcons.ChatQuoteLine, height: 44, fontSize: 13, fillWidth: true)
            }

            // ---- چیپ‌های مرتب‌سازی ----
            if let onSortChange, !comments.isEmpty || sortKey != DefaultCommentSort {
                ReviewSortChipsRow(title: "مرتب‌سازی:", options: ProductCommentSortOptions, selectedKey: sortKey, onSelect: onSortChange)
            }

            if isLoading {
                SiteLoading(size: 40).frame(maxWidth: .infinity).padding(.vertical, 6).transition(.opacity)
            }

            if comments.isEmpty {
                SiteCard {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: RemixIcons.ChatSmile2Line, size: 38, iconSize: 19, tint: SiteStatusColors.Neutral)
                        Spacer().frame(width: 10)
                        Text(sortKey != DefaultCommentSort ? "دیدگاهی با این فیلتر یافت نشد." : "هنوز دیدگاهی برای این محصول ثبت نشده است.")
                            .shkFont(12, lineHeight: 21).foregroundColor(colors.onSurfaceVariant)
                    }
                }
            } else {
                ForEach(comments) { comment in
                    CommentItem(comment: comment, onVote: onVote, onImageClick: onImageClick)
                }
                if hasMore {
                    SiteSecondaryButton(text: "مشاهده‌ی دیدگاه‌های بیشتر", onClick: onLoadMore, icon: RemixIcons.ArrowDownSLine,
                                        color: colors.onSurfaceVariant, height: 44, fontSize: 13, fillWidth: true)
                }
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

/** نمودار تفکیک امتیازها: برای هر ستاره (۵ تا ۱) یک نوار افقی با تعداد و درصد */
private struct RatingBreakdownChart: View {
    let breakdown: [RatingBreakdownDto]
    let total: Int
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(spacing: 7) {
            ForEach([5, 4, 3, 2, 1], id: \.self) { star in
                let row = breakdown.first { $0.star == star }
                let count = row?.count ?? 0
                let percent = row?.percent ?? (Double(count) * 100 / Double(total))
                HStack(spacing: 0) {
                    Text(star.toPersianDigits()).shkFont(12, .bold).foregroundColor(colors.onSurface).frame(width: 12, alignment: .leading)
                    RemixIcon(RemixIcons.StarFill, tint: ProductRatingStarColor, size: 13)
                    Spacer().frame(width: 8)
                    ReviewPercentBar(fraction: percent / 100, color: ProductRatingStarColor)
                    Spacer().frame(width: 8)
                    Text("\(count.toPersianDigits()) (\(formatProductRating(percent))%)")
                        .shkFont(11).foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                        .frame(width: 72, alignment: .leading)
                }
            }
        }
    }
}

/** نوار درصد افقی ساده */
private struct ReviewPercentBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15))
                Capsule().fill(color).frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 6)
        .frame(maxWidth: .infinity)
    }
}

private struct CommentItem: View {
    let comment: ProductCommentDto
    let onVote: (Int, Bool) -> Void
    let onImageClick: ([String], Int) -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard {
            // سرتیتر دیدگاه: آواتار، نام، برچسب خریدار و تاریخ
            HStack(spacing: 0) {
                SiteIconBadge(icon: RemixIcons.UserLine, size: 36, iconSize: 18, radius: 18)
                Spacer().frame(width: 10)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Text(comment.userName ?? "کاربر").shkFont(13, .bold).foregroundColor(colors.onSurface).lineLimit(1)
                        if comment.isBuyer {
                            SiteStatusChip(text: "خریدار", color: SiteStatusColors.Success, icon: RemixIcons.ShoppingBag3Line)
                        }
                    }
                    if let date = comment.jalaliCreatedAt?.first, !date.isBlankShk {
                        Text(date.toPersianDigits()).shkFont(11).foregroundColor(colors.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(comment.content ?? "")
                .shkFont(13, lineHeight: 24)
                .foregroundColor(colors.onSurface)
                .padding(.top, 10)
            if !(comment.strengths ?? []).isEmpty || !(comment.weakness ?? []).isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array((comment.strengths ?? []).enumerated()), id: \.offset) { _, item in
                        CommentPointRow(icon: RemixIcons.AddLine, text: item, color: SiteStatusColors.Success, description: "نقاط قوت")
                    }
                    ForEach(Array((comment.weakness ?? []).enumerated()), id: \.offset) { _, item in
                        CommentPointRow(icon: RemixIcons.SubtractLine, text: item, color: colors.error, description: "نقاط ضعف")
                    }
                }
                .padding(.top, 8)
            }
            // ---- تصاویر ارسالی خریدار (بندانگشتی گرد، با کلیک بزرگ می‌شن) ----
            let imageUrls = (comment.images ?? []).compactMap { img -> String? in
                guard let url = img.url, !url.isBlankShk else { return nil }
                return url
            }
            if !imageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, url in
                            RemoteImage(url, contentDescription: "تصویر دیدگاه", contentScale: .crop)
                                .frame(width: 64, height: 64)
                                .background(colors.surfaceVariant)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .onTapGesture { onImageClick(imageUrls, index) }
                        }
                    }
                }
                .padding(.top, 10)
            }
            if let answerContent = comment.answer?.content, !answerContent.isBlankShk {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.Store2Line, tint: colors.primary, size: 15)
                        Spacer().frame(width: 6)
                        Text("پاسخ فروشگاه").shkFont(12, .bold).foregroundColor(colors.primary)
                        if let answerName = comment.answer?.userName, !answerName.isBlankShk {
                            Text(" - \(answerName)").shkFont(11).foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                        }
                    }
                    Text(answerContent).shkFont(12, lineHeight: 21).foregroundColor(colors.onSurface).padding(.top, 4)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.primary.opacity(0.06)))
                .padding(.top, 10)
            }
            SiteDashedDivider().padding(.top, 12).padding(.bottom, 10)
            // رأی مفید بود / مفید نبود
            HStack(spacing: 8) {
                CommentVoteButton(icon: RemixIcons.ThumbUpLine, label: "مفید بود", count: comment.voteUp, color: SiteStatusColors.Success) { onVote(comment.id, true) }
                CommentVoteButton(icon: RemixIcons.ThumbDownLine, label: "مفید نبود", count: comment.voteDown, color: colors.error) { onVote(comment.id, false) }
            }
        }
    }
}

/** ردیف نقطه‌ی قوت/ضعف با آیکن رنگی */
private struct CommentPointRow: View {
    let icon: String
    let text: String
    let color: Color
    let description: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.opacity(0.12))
                RemixIcon(icon, contentDescription: description, tint: color, size: 13)
            }
            .frame(width: 18, height: 18)
            .padding(.top, 2)
            Text(text).shkFont(12, lineHeight: 21).foregroundColor(colors.onSurface)
        }
    }
}

/** دکمه‌ی رأی (قرص کم‌رنگ با آیکن، متن و تعداد) */
private struct CommentVoteButton: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 0) {
                RemixIcon(icon, contentDescription: label, tint: color, size: 15)
                Spacer().frame(width: 4)
                Text(label).shkFont(11, .medium).foregroundColor(color)
                Spacer().frame(width: 6)
                Text(count.toPersianDigits()).shkFont(12, .bold).foregroundColor(color)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color.opacity(0.08)))
        }
        .buttonStyle(SitePressStyle())
    }
}

// MARK: - پرسش و پاسخ

/**
 * بخش پرسش و پاسخ محصول: لیست سؤالات + پاسخ‌ها، فرم پرسیدن سؤال جدید، و «مشاهده‌ی بیشتر».
 */
struct QnaSection: View {
    let questionsInfo: QuestionsInfoDto?
    let questions: [ProductQuestionDto]
    let hasMore: Bool
    let isSubmittingQuestion: Bool
    let onLoadMore: () -> Void
    let onSubmitQuestion: (String) -> Void
    var sortKey: String = DefaultQuestionSort
    var onSortChange: ((String) -> Void)? = nil
    var isLoading: Bool = false

    @State private var newQuestion = ""
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SiteSectionTitle("پرسش و پاسخ" + (formatQuestionsCount(questionsInfo?.count).map { " (\($0))" } ?? ""))

            // ---- فرم پرسیدن سؤال ----
            SiteCard {
                HStack(spacing: 0) {
                    SiteIconBadge(icon: RemixIcons.QuestionAnswerLine, size: 34, iconSize: 18, radius: 10)
                    Spacer().frame(width: 10)
                    Text("سؤال خود را درباره‌ی این محصول بپرسید").shkFont(13, .bold).foregroundColor(colors.onSurface)
                }
                .padding(.bottom, 10)
                SiteTextField(value: $newQuestion, placeholder: "متن سؤال...", singleLine: false, minHeight: 84)
                Spacer().frame(height: 10)
                SitePrimaryButton(
                    text: "ارسال سؤال",
                    onClick: {
                        onSubmitQuestion(newQuestion)
                        newQuestion = ""
                    },
                    icon: RemixIcons.SendPlane2Line,
                    enabled: !newQuestion.isBlankShk,
                    loading: isSubmittingQuestion,
                    height: 44,
                    fontSize: 13,
                    fillWidth: true
                )
            }

            if let onSortChange, !questions.isEmpty || sortKey != DefaultQuestionSort {
                ReviewSortChipsRow(title: "مرتب‌سازی:", options: ProductQuestionSortOptions, selectedKey: sortKey, onSelect: onSortChange)
            }

            if isLoading {
                SiteLoading(size: 40).frame(maxWidth: .infinity).padding(.vertical, 6).transition(.opacity)
            }

            if questions.isEmpty {
                SiteCard {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: RemixIcons.QuestionLine, size: 38, iconSize: 19, tint: SiteStatusColors.Neutral)
                        Spacer().frame(width: 10)
                        Text(sortKey != DefaultQuestionSort ? "سؤالی با این فیلتر یافت نشد." : "هنوز سؤالی برای این محصول ثبت نشده است.")
                            .shkFont(12, lineHeight: 21).foregroundColor(colors.onSurfaceVariant)
                    }
                }
            } else {
                ForEach(questions) { question in QuestionItem(question: question) }
                if hasMore {
                    SiteSecondaryButton(text: "مشاهده‌ی سؤالات بیشتر", onClick: onLoadMore, icon: RemixIcons.ArrowDownSLine,
                                        color: colors.onSurfaceVariant, height: 44, fontSize: 13, fillWidth: true)
                }
            }
        }
        .padding(.horizontal, 16)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

private struct QuestionItem: View {
    let question: ProductQuestionDto
    @Environment(\.shkColors) private var colors

    var body: some View {
        // مثل سایت فقط پاسخ‌های منتشرشده نمایش داده می‌شن (status == publish)
        let publishedAnswers = question.answers.filter { $0.status == nil || $0.status == "publish" }
        SiteCard {
            HStack(alignment: .top, spacing: 0) {
                SiteIconBadge(icon: RemixIcons.QuestionLine, size: 30, iconSize: 16, radius: 9)
                Spacer().frame(width: 10)
                Text(question.question ?? "")
                    .shkFont(13, .bold, lineHeight: 23)
                    .foregroundColor(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 3)
            }
            if publishedAnswers.isEmpty {
                SiteDashedDivider().padding(.vertical, 10)
                HStack(spacing: 6) {
                    RemixIcon(RemixIcons.TimeLine, tint: colors.onSurfaceVariant, size: 15)
                    Text("هنوز پاسخی برای این سؤال ثبت نشده است.").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(publishedAnswers) { answer in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                RemixIcon(RemixIcons.ChatQuoteLine, tint: colors.primary, size: 15)
                                Spacer().frame(width: 6)
                                Text(answer.userName ?? "پاسخ").shkFont(12, .bold).foregroundColor(colors.primary)
                                if answer.userIsSeller {
                                    Spacer().frame(width: 6)
                                    SiteStatusChip(text: "فروشنده", color: SiteStatusColors.Info, icon: RemixIcons.Store2Line)
                                }
                            }
                            Text(answer.answer ?? "").shkFont(12, lineHeight: 21).foregroundColor(colors.onSurface).padding(.top, 4)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant.opacity(0.6)))
                    }
                }
                .padding(.top, 10)
            }
        }
    }
}
