import SwiftUI

// ===================================================================================
// معادل ui/tools/ToolTexts.kt
// تنظیمات عمومی هر ابزار از پنل: آیکن، رنگ آیکن، متن معرفی و بخش انتهایی.
// قالب متن‌ها همون قالب سایته: خط خالی = پاراگراف، **پررنگ**، خط «- » = فهرست
// ===================================================================================

/** آیکن ابزار: کاراکتر فونت Remix که سرور فرستاده، وگرنه آیکن پیش‌فرض اپ */
func toolIconOf(_ tool: ToolItemDto?) -> String {
    if let glyph = tool?.iconGlyph, !glyph.trimmingCharacters(in: .whitespaces).isEmpty, glyph.utf16.count <= 2 { return glyph }
    return toolIcon(tool?.key)
}

/** رنگ آیکن ابزار از پنل («#rrggbb»)؛ خالی/نامعتبر = رنگ اصلی */
func toolColorOf(_ tool: ToolItemDto?, _ colors: ShkColorScheme) -> Color {
    parseToolColor(tool?.iconColor) ?? colors.primary
}

private func parseToolColor(_ value: String?) -> Color? {
    guard var raw = value?.trimmingCharacters(in: .whitespaces) else { return nil }
    if raw.hasPrefix("#") { raw.removeFirst() }
    let hex: String
    switch raw.count {
    case 3: hex = raw.map { "\($0)\($0)" }.joined()
    case 6: hex = raw
    default: return nil
    }
    guard let rgb = UInt32(hex, radix: 16) else { return nil }
    return Color(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
}

/** متن معرفی بالای ابزار: کادر کم‌رنگ با خط رنگی سمت راست (مثل سایت) */
struct ToolIntroBox: View {
    let text: String?
    let accent: Color

    var body: some View {
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // در RTL اولین فرزند HStack سمت راسته: نوار رنگی سمت راست کادر
            HStack(spacing: 0) {
                Rectangle().fill(accent).frame(width: 3)
                VStack(alignment: .leading, spacing: 0) {
                    ToolRichText(text: text, accent: accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(accent.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

/** بخش انتهایی صفحه‌ی ابزار (عنوان + متن) */
struct ToolEndSection: View {
    let title: String?
    let text: String?
    let accent: Color
    @Environment(\.shkColors) private var colors

    var body: some View {
        let hasTitle = !(title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasText = !(text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasTitle || hasText {
            SiteCard {
                if hasTitle {
                    Text(title ?? "").shkFont(14, .bold).foregroundColor(colors.onSurface)
                    if hasText { Spacer().frame(height: 8) }
                }
                if hasText { ToolRichText(text: text ?? "", accent: accent) }
            }
        }
    }
}

/** نمایش متن ساده‌ی پنل: پاراگراف‌ها، خط‌های فهرست و **پررنگ** */
struct ToolRichText: View {
    let text: String
    let accent: Color
    @Environment(\.shkColors) private var colors

    private struct Piece { let isItem: Bool; let value: String }

    private var blocks: [[Piece]] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let regex = try? NSRegularExpression(pattern: "\n\\s*\n")
        let ns = normalized as NSString
        var raw: [String] = []
        var last = 0
        regex?.enumerateMatches(in: normalized, range: NSRange(location: 0, length: ns.length)) { m, _, _ in
            guard let m else { return }
            raw.append(ns.substring(with: NSRange(location: last, length: m.range.location - last)))
            last = m.range.location + m.range.length
        }
        raw.append(ns.substring(from: last))
        let trimmedBlocks = raw.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\n")) }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return trimmedBlocks.map { block in
            var paragraph: [String] = []
            var pieces: [Piece] = []
            for line in block.components(separatedBy: "\n") {
                let trimmed = String(line.drop(while: { $0.isWhitespace }))
                if trimmed.hasPrefix("- ") {
                    if !paragraph.isEmpty {
                        pieces.append(Piece(isItem: false, value: paragraph.joined(separator: "\n")))
                        paragraph = []
                    }
                    pieces.append(Piece(isItem: true, value: String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                } else {
                    paragraph.append(line)
                }
            }
            if !paragraph.isEmpty { pieces.append(Piece(isItem: false, value: paragraph.joined(separator: "\n"))) }
            return pieces
        }
    }

    var body: some View {
        let color = colors.onSurfaceVariant
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, pieces in
                if index > 0 { Spacer().frame(height: 8) }
                ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                    if piece.isItem {
                        HStack(alignment: .top, spacing: 0) {
                            Circle().fill(accent).frame(width: 5, height: 5).padding(.top, 9)
                            Spacer().frame(width: 8)
                            toolBoldText(piece.value).shkFont(12.5, lineHeight: 22).foregroundColor(color)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.top, 2)
                    } else {
                        toolBoldText(piece.value).shkFont(12.5, lineHeight: 22).foregroundColor(color)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

/** «**متن**» → پررنگ */
func toolBoldText(_ source: String) -> Text {
    let parts = source.components(separatedBy: "**")
    var result = Text(verbatim: "")
    for (index, part) in parts.enumerated() {
        // تکه‌های فرد بین دو ** هستن؛ ** بی‌جفت آخر متن رو ساده نشون می‌دیم
        if index % 2 == 1 && index < parts.count - 1 {
            result = result + Text(part).font(ShkFont.yekan(12.5, .bold))
        } else {
            if index % 2 == 1 { result = result + Text(verbatim: "**") }
            result = result + Text(part)
        }
    }
    return result
}
