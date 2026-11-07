import SwiftUI

/**
 * معادل ui/faq/FaqScreen.kt
 * صفحه‌ی پرسش‌های متداول - همون سوال/جواب‌های بخش FAQ اسکریپت (api/v2/faqs)، به‌صورت
 * آکاردئونی: کارت معرفی قرمز، هر پرسش داخل یک کادر با شماره و فلش چرخان، و حالت خالیِ
 * طراحی‌شده (با دکمه‌ی تماس با ما).
 */
struct FaqScreen: View {
    let onBack: () -> Void
    var onOpenContact: () -> Void = {}

    @Environment(\.shkColors) private var colors
    private let repository = ContentRepository()

    @State private var faqs: [FaqDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "پرسش‌های متداول", onBack: onBack)

            if isLoading {
                MaterialSpinner(color: colors.primary, lineWidth: 4, size: 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack {
                    SiteEmptyState(icon: RemixIcons.WifiOffLine, title: "دریافت پرسش‌ها ممکن نشد", subtitle: errorMessage)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        SiteHeroCard(
                            icon: RemixIcons.QuestionAnswerLine,
                            title: "پاسخ پرسش‌های شما",
                            subtitle: faqs.isEmpty ? nil : "\(faqs.count.toPersianDigits()) پرسش پرتکرار مشتریان؛ روی هر پرسش بزنید تا پاسخ آن باز شود."
                        )
                        .padding(.bottom, 4)
                        if faqs.isEmpty {
                            SiteEmptyState(
                                icon: RemixIcons.QuestionnaireLine,
                                title: "هنوز پرسشی ثبت نشده است",
                                subtitle: "اگر سؤالی دارید، کارشناسان ما از طریق صفحه‌ی تماس با ما پاسخگوی شما هستند.",
                                actionLabel: "تماس با ما",
                                actionIcon: RemixIcons.CustomerService2Line,
                                onAction: onOpenContact
                            )
                        } else {
                            ForEach(Array(faqs.uniqueById().enumerated()), id: \.element.id) { index, faq in
                                FaqRow(index: index, faq: faq)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                // کشیدن به پایین: دریافت دوباره‌ی پرسش‌ها بدون پاک کردن محتوای فعلی (در خطا، همون قبلی می‌مونه)
                .sitePullRefresh {
                    if case .success(let data) = await repository.getFaqs() {
                        faqs = data
                        errorMessage = nil
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task {
            guard isLoading else { return }
            switch await repository.getFaqs() {
            case .success(let data): faqs = data
            case .error(let message): errorMessage = message
            }
            isLoading = false
        }
    }
}

private struct FaqRow: View {
    let index: Int
    let faq: FaqDto
    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark
    @State private var expanded = false

    var body: some View {
        let primary = colors.primary
        let answer = htmlToPlainText(faq.answer).trimmingCharacters(in: .whitespacesAndNewlines)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text((index + 1).toPersianDigits())
                    .shkFont(13, .bold)
                    .foregroundColor(expanded ? .white : primary)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(expanded ? primary : primary.opacity(0.1)))
                Spacer().frame(width: 12)
                Text(faq.question)
                    .shkFont(13, .bold, lineHeight: 22)
                    .foregroundColor(colors.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 8)
                RemixIcon(RemixIcons.ArrowDownSLine, tint: expanded ? primary : colors.onSurfaceVariant, size: 22)
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 12)
                    DashedDivider(color: isDark ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider)
                    Spacer().frame(height: 12)
                    JustifiedText(text: answer, size: 13, lineHeight: 24, color: colors.onSurfaceVariant)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(shape.fill(colors.surface))
        .overlay(shape.strokeBorder(expanded ? primary.opacity(0.35) : Color.clear, lineWidth: 1))
        .clipShape(shape)
        .contentShape(shape)
        .onTapGesture { withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() } }
    }
}
