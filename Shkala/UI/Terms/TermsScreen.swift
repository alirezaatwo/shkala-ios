import SwiftUI

/**
 * معادل ui/terms/TermsScreen.kt - صفحه‌ی نیتیو «قوانین و شرایط».
 *
 * محتوا همون صفحه‌ی terms خودِ اسکریپته (api/v2/pages/terms) که از پنل ادمین ویرایش می‌شه؛
 * HTML اون به بلوک‌های خوانا تبدیل می‌شه:
 *  - هر پاراگراف → یک «بند» شماره‌دار داخل کادر
 *  - تیترهای h1..h6 → عنوان با خط قرمز
 *  - پاراگراف‌هایی که برچسبِ بولد دارن (مثل «تلفن تماس:» و «آدرس شرکت:») → کارت اطلاعات تماس
 *    با آیکن، که شماره‌ها در اون قابل لمس (تماس) هستن
 * پس اگه ادمین متن رو عوض کنه، این صفحه هم خودکار به‌روز می‌شه.
 */
struct TermsScreen: View {
    let onBack: () -> Void

    @Environment(\.shkColors) private var colors
    private let repository = ContentRepository()

    @State private var page: PageDto? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        let blocks = parseTermsHtml(page?.content ?? "")
        let clauseCount = blocks.filter { if case .clause = $0 { return true }; return false }.count
        let title = page?.title ?? "قوانین و شرایط"

        VStack(spacing: 0) {
            SitePageTopBar(title: title, onBack: onBack)
            if isLoading {
                MaterialSpinner(color: colors.primary, lineWidth: 4, size: 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if errorMessage != nil || blocks.isEmpty {
                VStack {
                    SiteEmptyState(
                        icon: errorMessage != nil ? RemixIcons.WifiOffLine : RemixIcons.FileTextLine,
                        title: errorMessage != nil ? "دریافت قوانین ممکن نشد" : "متنی برای نمایش وجود ندارد",
                        subtitle: errorMessage
                    )
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        SiteHeroCard(
                            icon: RemixIcons.ScalesLine,
                            title: title,
                            subtitle: "\(clauseCount.toPersianDigits()) بند — مطالعه‌ی آن پیش از ثبت سفارش توصیه می‌شود."
                        )
                        .padding(.bottom, 4)
                        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                            switch block {
                            case .heading(let text): SiteSectionTitle(text).padding(.top, 8)
                            case .clause(let number, let text): TermsClauseCard(number: number, text: text)
                            case .info(let caption, let rows): TermsInfoCard(caption: caption, rows: rows)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                // کشیدن به پایین: دریافت دوباره‌ی متن قوانین بدون پاک کردن محتوای فعلی (در خطا، همون قبلی می‌مونه)
                .sitePullRefresh {
                    if case .success(let p) = await repository.getPage("terms") {
                        page = p
                        errorMessage = nil
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task {
            guard isLoading else { return }
            switch await repository.getPage("terms") {
            case .success(let p): page = p
            case .error(let message): errorMessage = message
            }
            isLoading = false
        }
    }
}

// ----------------------------------------------------------------------------------
// نمایش
// ----------------------------------------------------------------------------------

private struct TermsClauseCard: View {
    let number: Int
    let text: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        HStack(alignment: .top, spacing: 0) {
            Text(number.toPersianDigits())
                .shkFont(12, .bold)
                .foregroundColor(primary)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(primary.opacity(0.1)))
            Spacer().frame(width: 12)
            JustifiedText(text: text, size: 13, lineHeight: 25, color: colors.onSurface)
                .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.surface))
    }
}

private struct TermsInfoCard: View {
    let caption: String?
    let rows: [TermsInfoRow]
    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    var body: some View {
        let primary = colors.primary
        let dashed = isDark ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                RemixIcon(RemixIcons.CustomerService2Line, tint: primary, size: 20)
                Spacer().frame(width: 8)
                Text(caption ?? "اطلاعات تماس")
                    .shkFont(13, .bold, lineHeight: 22)
                    .foregroundColor(colors.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                Spacer().frame(height: 10)
                if index > 0 {
                    DashedDivider(color: dashed)
                    Spacer().frame(height: 10)
                }
                let isPhone = row.telLink != nil
                let icon: String = {
                    if isPhone || row.label.contains("تلفن") || row.label.contains("تماس") { return RemixIcons.PhoneLine }
                    if row.label.contains("آدرس") { return RemixIcons.MapPin2Line }
                    if row.label.contains("ایمیل") { return RemixIcons.MailLine }
                    return RemixIcons.InformationLine
                }()
                HStack(spacing: 0) {
                    RemixIcon(icon, tint: primary, size: 18)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(colors.surface))
                    Spacer().frame(width: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.label).shkFont(11).foregroundColor(colors.onSurfaceVariant)
                        if !row.value.isBlankShk {
                            Text(row.value)
                                .shkFont(13, .medium, lineHeight: 22)
                                .foregroundColor(isPhone ? primary : colors.onSurface)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let note = row.note, !note.isBlankShk {
                            Text(note).shkFont(11, lineHeight: 19).foregroundColor(colors.onSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture { if let tel = row.telLink { openLink(tel) } }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(primary.opacity(0.06)))
    }
}

// ----------------------------------------------------------------------------------
// تبدیل HTML به بلوک‌ها
// ----------------------------------------------------------------------------------

enum TermsBlock {
    case heading(String)
    case clause(number: Int, text: String)
    case info(caption: String?, rows: [TermsInfoRow])
}

struct TermsInfoRow {
    let label: String
    var value: String
    let note: String?
    let telLink: String?
}

private let termsBlockRegex = try! NSRegularExpression(pattern: "<(p|h[1-6]|li|div)(?:\\s[^>]*)?>(.*?)</\\1>", options: [.dotMatchesLineSeparators, .caseInsensitive])
private let termsStrongLabelRegex = try! NSRegularExpression(pattern: "<strong[^>]*>(.*?)</strong>", options: [.dotMatchesLineSeparators, .caseInsensitive])
private let termsTelRegex = try! NSRegularExpression(pattern: "href=\"(tel:[^\"]+)\"", options: [.caseInsensitive])
private let termsAnchorTextRegex = try! NSRegularExpression(pattern: "<a[^>]*>(.*?)</a>", options: [.dotMatchesLineSeparators, .caseInsensitive])

private func termsHtmlToText(_ html: String) -> String {
    htmlToPlainText(html)
        .replacingOccurrences(of: "\u{00A0}", with: " ")
        .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func firstGroup(_ regex: NSRegularExpression, _ text: String) -> String? {
    let ns = text as NSString
    guard let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else { return nil }
    return ns.substring(with: m.range(at: 1))
}

func parseTermsHtml(_ html: String) -> [TermsBlock] {
    if html.isBlankShk { return [] }
    let ns = html as NSString
    let matches = termsBlockRegex.matches(in: html, range: NSRange(location: 0, length: ns.length))
    let rawBlocks: [(String, String)] = matches.isEmpty
        ? html.components(separatedBy: "\n").flatMap { $0.replacingOccurrences(of: "<br\\s*/?>", with: "\u{1}", options: [.regularExpression, .caseInsensitive]).components(separatedBy: "\u{1}") }.map { ("p", $0) }
        : matches.map { (ns.substring(with: $0.range(at: 1)).lowercased(), ns.substring(with: $0.range(at: 2))) }

    var result: [TermsBlock] = []
    var clauseNumber = 0
    for (tag, inner) in rawBlocks {
        let text = termsHtmlToText(inner)
        if text.isBlankShk { continue }

        if tag.hasPrefix("h") {
            result.append(.heading(text))
            continue
        }

        // پاراگرافی که برچسب‌های بولدِ «...:» داره → ردیف‌های اطلاعات تماس
        let innerNs = inner as NSString
        let labels = termsStrongLabelRegex.matches(in: inner, range: NSRange(location: 0, length: innerNs.length))
            .filter { termsHtmlToText(innerNs.substring(with: $0.range(at: 1))).hasSuffix(":") }
        if !labels.isEmpty {
            let rows: [TermsInfoRow] = labels.enumerated().map { i, m in
                let start = m.range.location + m.range.length
                let end = i + 1 < labels.count ? labels[i + 1].range.location : innerNs.length
                let valueHtml = innerNs.substring(with: NSRange(location: start, length: end - start))
                let tel = firstGroup(termsTelRegex, valueHtml)
                let anchorText = firstGroup(termsAnchorTextRegex, valueHtml).map { termsHtmlToText($0) }
                let fullValue = termsHtmlToText(valueHtml)
                let value: String
                let note: String?
                if tel != nil, let anchorText {
                    value = anchorText
                    let rest = (fullValue.hasPrefix(anchorText) ? String(fullValue.dropFirst(anchorText.count)) : fullValue).trimmingCharacters(in: .whitespacesAndNewlines)
                    note = rest.isBlankShk ? nil : rest
                } else {
                    value = fullValue
                    note = nil
                }
                var label = termsHtmlToText(innerNs.substring(with: m.range(at: 1)))
                if label.hasSuffix(":") { label.removeLast() }
                return TermsInfoRow(label: label.trimmingCharacters(in: .whitespacesAndNewlines), value: value, note: note, telLink: tel)
            }
            // متن کوتاهِ درست قبل از این بخش (مثل «در صورت وجود هرگونه سوال ...») عنوان کارت می‌شه
            var caption: String? = nil
            if case .clause(_, let previousText) = result.last, previousText.count <= 140 {
                result.removeLast()
                clauseNumber -= 1
                caption = previousText
            }
            result.append(.info(caption: caption, rows: rows))
            continue
        }

        // خط کوتاهی که درست بعد از یک برچسبِ بدون مقدار اومده (مثل ادامه‌ی «آدرس شرکت:») → مقدار همون ردیف
        if case .info(let caption, var rows) = result.last, let lastRow = rows.last, lastRow.value.isBlankShk, text.count <= 200 {
            rows[rows.count - 1].value = text
            result[result.count - 1] = .info(caption: caption, rows: rows)
            continue
        }

        clauseNumber += 1
        result.append(.clause(number: clauseNumber, text: text))
    }
    return result
}
