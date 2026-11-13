import SwiftUI
import UIKit

/**
 * معادل ui/appstatus/AppPopup.kt
 * وضعیت پاپ‌آپ‌ها در همین اجرای اپ: پاپ‌آپ‌های نمایش‌داده‌شده (تناوب always = یک‌بار در هر اجرای اپ)،
 * پاپ‌آپ‌های هر صفحه (کش کوتاه) و زمان بسته شدن آخرین پاپ‌آپ (فاصله تا پاپ‌آپ بعدی)
 */
private enum PopupSession {
    static var shownIds = Set<String>()
    static var cache: [String: (Int64, [AppPopupDto])] = [:]
    static var lastClosedAt: Int64 = 0
    /// پاپ‌آپ در حال نمایش (برای آمار کلیک کد تخفیف، خبرنامه و فرم)
    static var currentPid: Int64? = nil
    static let CACHE_MS: Int64 = 5 * 60 * 1000
    static let GAP_MS: Int64 = 60 * 1000
}

/// پاپ‌آپی که (اگه تصویر داره) تصویرش با موفقیت بارگذاری شده و آماده‌ی نمایشه
private struct ReadyPopup {
    let dto: AppPopupDto
    let id: String
    let imageUrl: String?
    let aspectRatio: CGFloat
}

private func todayKey() -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

/// نوع بلوک‌هایی که این نسخه‌ی اپ می‌شناسه (بقیه نادیده گرفته می‌شن)
private let KNOWN_BLOCKS: Set<String> = ["heading", "text", "image", "button", "coupon", "countdown", "newsletter", "form", "spacer", "divider"]

/// چیزی برای نمایش هست؟ (فقط تصویر: تصویر لازمه / تصویر + محتوا: هر دو / فقط محتوا: بلوک)
private func showable(_ popup: AppPopupDto) -> Bool {
    if (popup.id ?? "").isBlankShk || popup.device == "desktop" { return false }
    let hasImage = !(popup.imageUrl ?? "").isBlankShk
    let hasBlocks = (popup.blocks ?? []).contains { KNOWN_BLOCKS.contains($0.type ?? "") }
    switch popup.layout ?? "image" {
    case "content": return hasBlocks
    case "split": return hasImage && hasBlocks
    default: return hasImage
    }
}

/// آمار پاپ‌آپ در حال نمایش (بدون انتظار)
private func popupEvent(_ pid: Int64?, _ event: String) {
    guard let pid, pid > 0 else { return }
    Task { await ContentRepository().sendPopupEvent(pid, event: event) }
}

/// صفحه‌ی فعلی برای هدف‌گیری پاپ‌آپ (popupScreen اندروید در AppRoot.kt)؛ nil = این صفحه پاپ‌آپ نداره
func popupScreenFor(route: AppRoute?, tab: AppTab, cartOpen: Bool) -> (screen: String?, slug: String?) {
    if cartOpen { return ("cart", nil) }
    guard let route else { return (tab == .HOME ? "home" : "other", nil) }
    switch route {
    case .productDetail(let slug): return ("product", slug)
    case .categoryProducts(let slug, _): return ("category", slug)
    case .brand(let slug): return ("brand", slug)
    case .checkout, .addresses, .prefactorAddresses: return ("checkout", nil)
    case .articleList, .magazine: return ("blog", nil)
    case .paymentWebView, .cardToCard, .orderResult, .mapPicker, .addressForm,
         .walletChargeWebView, .walletChargeResult, .webpage, .cartPrefactor, .createTicket, .dynamicForm:
        return (nil, nil)
    default: return ("other", nil)
    }
}

/**
 * پاپ‌آپ‌های اپ - همان پاپ‌آپ‌ساز سایت، به‌صورت نیتیو:
 * - چیدمان: image = فقط تصویر / split = تصویر + محتوا / content = فقط محتوا (بلوک‌ها)
 * - بلوک‌ها: تیتر، متن، تصویر، دکمه، کد تخفیف، شمارش معکوس، خبرنامه، فرم دلخواه، فاصله، خط
 * - چند پاپ‌آپ با هدف‌گیری صفحه: پاپ‌آپ‌های هر صفحه ([screen] + [slug]) از api/v2/popups گرفته می‌شن؛ اولین
 *   پاپ‌آپ دیده‌نشده نمایش داده می‌شه، در هر صفحه حداکثر یکی و بعد از بستن یک پاپ‌آپ تا یک دقیقه پاپ‌آپ دیگه‌ای نه.
 *   سرور قدیمی: همون popup وضعیت اپ روی صفحه‌ی اصلی
 * - فقط وقتی [enabled] باشه (بعد از تموم شدن دیالوگ‌های شروع) و بعد از تأخیر تنظیم‌شده نمایش داده می‌شه
 * - تناوب: once = برای هر شناسه فقط یک‌بار / daily = روزی یک‌بار / always = یک‌بار در هر اجرای اپ
 * - اگه تصویر داره، اول تصویر بارگذاری می‌شه؛ اگه بارگذاری ناموفق بود، اصلاً نمایش داده نمی‌شه
 * - لینک‌ها (تصویر، دکمه) با [onOpenLink] باز می‌شن و پاپ‌آپ بسته می‌شه
 * - آمار: نمایش، کلیک (لینک / دکمه / کپی کد تخفیف)، بستن، ثبت فرم
 */
struct AppPopupHost: View {
    let enabled: Bool
    let screen: String?
    let slug: String?
    let onOpenLink: (String) -> Void

    @ObservedObject private var appStatus = AppStatusCache.shared
    @State private var visiblePopup: ReadyPopup? = nil
    @State private var clicked = false

    private struct Key: Equatable {
        let enabled: Bool
        let screen: String?
        let slug: String?
        let live: Bool?
        let legacyId: String?
        let hasStatus: Bool
    }

    var body: some View {
        let status = appStatus.status
        let key = Key(enabled: enabled, screen: screen, slug: slug, live: status?.popupsLive, legacyId: status?.popup?.id, hasStatus: status != nil)
        ZStack {
            if let current = visiblePopup {
                PopupOverlay(onDismiss: close) {
                    if (current.dto.layout ?? "image") == "image" {
                        AppImagePopupDialog(popup: current, onDismiss: close, onOpenLink: openLink)
                    } else {
                        AppBuilderPopupDialog(popup: current, onDismiss: close, onOpenLink: openLink)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: visiblePopup?.id)
        .task(id: key) { await pick(status: status) }
    }

    private func pick(status: AppStatusResponse?) async {
        guard enabled, let screen, let status else { return }
        if visiblePopup != nil { return }

        // پاپ‌آپ‌های این صفحه
        let candidates: [AppPopupDto]
        switch status.popupsLive {
        case nil: candidates = screen == "home" ? [status.popup].compactMap { $0 } : []
        case .some(false): candidates = []
        case .some(true):
            let cacheKey = "\(screen)|\(slug ?? "")"
            if let cached = PopupSession.cache[cacheKey], nowMs() - cached.0 < PopupSession.CACHE_MS {
                candidates = cached.1
            } else {
                guard let list = await ContentRepository().getPopups(screen, slug: slug) else { return }
                if Task.isCancelled { return }
                PopupSession.cache[cacheKey] = (nowMs(), list)
                candidates = list
            }
        }

        let day = todayKey()
        guard let popup = candidates.first(where: { p in
            guard let pid = p.id else { return false }
            if !showable(p) || PopupSession.shownIds.contains(pid) { return false }
            switch p.frequency {
            case "once": return !AppMetaPreferenceManager.wasPopupShownOnce(pid)
            case "daily": return !AppMetaPreferenceManager.wasPopupShownOnDay(pid, day: day)
            // always (و مقدار ناشناخته): فقط یک‌بار در هر اجرای اپ (PopupSession)
            default: return true
            }
        }), let popupId = popup.id else { return }
        let layout = popup.layout ?? "image"

        // تأخیر نمایش + فاصله از پاپ‌آپ قبلی (اگه در این فاصله از صفحه خارج بشه، task لغو می‌شه)
        let delayMs = Int64(min(max(popup.delay ?? 0, 0), 60)) * 1000
        let gapMs = max(PopupSession.lastClosedAt + PopupSession.GAP_MS - nowMs(), 0)
        let wait = max(delayMs, gapMs)
        if wait > 0 {
            try? await Task.sleep(nanoseconds: UInt64(wait) * 1_000_000)
            if Task.isCancelled { return }
        }

        // پیش‌بارگذاری تصویر (با همون بارگذار تصویر اپ، پس نمایش بعدی از کش میاد)
        var ratio: CGFloat = 1
        let shownImage: String? = layout == "content" ? nil : popup.imageUrl.flatMap { $0.isBlankShk ? nil : $0 }
        if let shownImage {
            guard let image = await ShkImageLoader.shared.load(shownImage) else { return }
            if Task.isCancelled { return }
            let w = image.size.width, h = image.size.height
            ratio = (w > 0 && h > 0) ? w / h : 1
        }

        PopupSession.shownIds.insert(popupId)
        switch popup.frequency {
        case "once": AppMetaPreferenceManager.markPopupShownOnce(popupId)
        case "daily": AppMetaPreferenceManager.markPopupShownOnDay(popupId, day: day)
        default: break
        }
        PopupSession.currentPid = popup.pid
        popupEvent(popup.pid, "view")
        clicked = false
        visiblePopup = ReadyPopup(dto: popup, id: popupId, imageUrl: shownImage, aspectRatio: ratio)
    }

    private func close() {
        guard let current = visiblePopup else { return }
        if !clicked { popupEvent(current.dto.pid, "close") }
        PopupSession.lastClosedAt = nowMs()
        visiblePopup = nil
    }

    private func openLink(_ link: String) {
        guard let current = visiblePopup else { return }
        clicked = true
        popupEvent(current.dto.pid, "click")
        PopupSession.lastClosedAt = nowMs()
        visiblePopup = nil
        onOpenLink(link)
    }
}

/// پس‌زمینه‌ی تیره‌ی Dialog اندروید (لمس بیرون = بستن) + کادر وسط صفحه
private struct PopupOverlay<Content: View>: View {
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            content()
        }
    }
}

// ------------------------------------------------------------------ «فقط تصویر»

private struct AppImagePopupDialog: View {
    let popup: ReadyPopup
    let onDismiss: () -> Void
    let onOpenLink: (String) -> Void

    var body: some View {
        let link = popup.dto.link.flatMap { $0.isBlankShk ? nil : $0 }
        let radius = CGFloat(min(max(popup.dto.style?.radius ?? 18, 0), 40))
        // حداکثر ۹۰٪ عرض (یا عرض تنظیم‌شده) و ۸۰٪ ارتفاع صفحه، با حفظ نسبت تصویر
        let screen = UIScreen.main.bounds.size
        let screenMax = screen.width * 0.9
        let maxWidth = popup.dto.width.map { min(CGFloat($0), screenMax) } ?? screenMax
        let maxHeight = screen.height * 0.8
        let ratio = min(max(popup.aspectRatio, 0.2), 5)
        let size: CGSize = {
            var width = maxWidth
            var height = width / ratio
            if height > maxHeight {
                height = maxHeight
                width = height * ratio
            }
            return CGSize(width: width, height: height)
        }()
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        RemoteImage(popup.imageUrl, contentDescription: "پاپ‌آپ تبلیغاتی", contentScale: .fit)
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onTapGesture { if let link { onOpenLink(link) } }
            .overlay(alignment: .topTrailing) { PopupCloseButton(onClick: onDismiss) }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}

private struct PopupCloseButton: View {
    let onClick: () -> Void
    var body: some View {
        Button(action: onClick) {
            RemixIcon(RemixIcons.CloseLine, contentDescription: "بستن", tint: .white, size: 20)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.black.opacity(0.45)))
        }
        .buttonStyle(.plain)
        .padding(8)
    }
}

// ------------------------------------------------------------------ پاپ‌آپ‌ساز (تصویر + محتوا / فقط محتوا)

/// رنگ‌های پاپ‌آپ (همان رنگ‌های پیش‌فرض سایت در حالت روز و شب، یا رنگ دلخواه پنل)
private struct PopupColors {
    let bg: Color
    let text: Color
    let muted: Color
    let line: Color
    let field: Color
    let accent: Color
    let accentText: Color
}

/// #rgb / #rrggbb → Color (نامعتبر = nil)
private func hexColor(_ value: String?) -> Color? {
    guard var hex = value?.trimmingCharacters(in: .whitespaces) else { return nil }
    if hex.hasPrefix("#") { hex.removeFirst() }
    let full: String
    switch hex.count {
    case 3: full = hex.map { "\($0)\($0)" }.joined()
    case 6: full = hex
    default: return nil
    }
    guard let rgb = UInt32(full, radix: 16) else { return nil }
    return Color(argb: 0xFF000000 | rgb)
}

private func popupColors(_ dto: AppPopupDto, dark: Bool, primary: Color) -> PopupColors {
    let style = dto.style
    let text = hexColor(style?.text) ?? (dark ? Color(argb: 0xFFF1F1F5) : Color(argb: 0xFF1C1C25))
    return PopupColors(
        bg: hexColor(style?.bg) ?? (dark ? Color(argb: 0xFF2B2B36) : .white),
        text: text,
        muted: text.opacity(0.65),
        line: dark ? Color.white.opacity(0.14) : Color(argb: 0x598C96AA),
        field: dark ? Color(argb: 0xFF363642) : Color(argb: 0xFFF5F6F8),
        accent: hexColor(style?.accent) ?? hexColor(dto.themeColor) ?? primary,
        accentText: hexColor(style?.accentText) ?? .white
    )
}

private func alignOf(_ align: String?) -> HorizontalAlignment {
    switch align {
    case "start": return .leading
    case "end": return .trailing
    default: return .center
    }
}

private func frameAlignOf(_ align: String?) -> Alignment {
    switch align {
    case "start": return .leading
    case "end": return .trailing
    default: return .center
    }
}

private func textAlignOf(_ align: String?) -> TextAlignment {
    switch align {
    case "start": return .leading
    case "end": return .trailing
    default: return .center
    }
}

private struct AppBuilderPopupDialog: View {
    let popup: ReadyPopup
    let onDismiss: () -> Void
    let onOpenLink: (String) -> Void

    @Environment(\.shkColors) private var shkColors
    @Environment(\.shkIsDark) private var isDark
    @State private var bodyHeight: CGFloat = 0

    var body: some View {
        let dto = popup.dto
        let colors = popupColors(dto, dark: isDark, primary: shkColors.primary)
        let style = dto.style
        let radius = CGFloat(min(max(style?.radius ?? 18, 0), 40))
        let pad = CGFloat(min(max(style?.padding ?? 28, 8), 64))
        let layout = dto.layout ?? "content"
        let screen = UIScreen.main.bounds.size
        // عرض: عرض تنظیم‌شده (پیکسل سایت = pt) ولی هیچ‌وقت بیشتر از ۹۲٪ صفحه
        let width = min(CGFloat(dto.width ?? (layout == "split" ? 820 : 560)), screen.width * 0.92)
        let maxHeight = screen.height * 0.85
        // مثل سایت: پاپ‌آپ باریک (تا ۵۶۰) = تصویر بالای محتوا (یا پنهان)، پهن‌تر = کنار هم
        let stacked = width <= 560
        let image = layout == "split" ? popup.imageUrl : nil
        let link = dto.link.flatMap { $0.isBlankShk ? nil : $0 }
        let imageOnStart = dto.imageSide != "end"
        let bodyPad = stacked ? pad * 0.75 : pad
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Group {
            if let image, !stacked {
                // تصویر کناری هم‌قد محتوا (مثل سایت)؛ قد محتوا بعد از اندازه‌گیری خوانده می‌شه
                let imageHeight = max(bodyHeight, 160)
                HStack(spacing: 0) {
                    if imageOnStart { sideImage(image, width: width * 0.46, height: imageHeight, link: link) }
                    ScrollView {
                        blocksColumn(dto: dto, colors: colors, pad: bodyPad)
                            .background(GeometryReader { g in Color.clear.preference(key: PopupBodyHeightKey.self, value: g.size.height) })
                    }
                    .frame(maxHeight: min(max(bodyHeight, 1), maxHeight))
                    if !imageOnStart { sideImage(image, width: width * 0.46, height: imageHeight, link: link) }
                }
                .onPreferenceChange(PopupBodyHeightKey.self) { bodyHeight = $0 }
                .frame(maxHeight: maxHeight)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        if let image, dto.imageMobile != "hide" {
                            let ratio = min(max(popup.aspectRatio, 0.4), 3)
                            let imageHeight = min(width / ratio, screen.height * 0.34)
                            RemoteImage(image, contentScale: .crop)
                                .frame(width: width, height: imageHeight)
                                .clipped()
                                .contentShape(Rectangle())
                                .onTapGesture { if let link { onOpenLink(link) } }
                        }
                        blocksColumn(dto: dto, colors: colors, pad: bodyPad)
                    }
                    .background(GeometryReader { g in Color.clear.preference(key: PopupBodyHeightKey.self, value: g.size.height) })
                }
                .onPreferenceChange(PopupBodyHeightKey.self) { bodyHeight = $0 }
                .frame(height: min(max(bodyHeight, 1), maxHeight))
            }
        }
        .frame(width: width)
        .background(colors.bg)
        .overlay(alignment: .topTrailing) { PopupCloseButton(onClick: onDismiss) }
        .clipShape(shape)
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }

    private func sideImage(_ url: String, width: CGFloat, height: CGFloat, link: String?) -> some View {
        RemoteImage(url, contentScale: .crop)
            .frame(width: width, height: height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture { if let link { onOpenLink(link) } }
    }

    private func blocksColumn(dto: AppPopupDto, colors: PopupColors, pad: CGFloat) -> some View {
        VStack(alignment: alignOf(dto.style?.align), spacing: 12) {
            PopupBlocks(dto: dto, colors: colors, onDismiss: onDismiss, onOpenLink: onOpenLink)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignOf(dto.style?.align))
        .padding(pad)
    }
}

private struct PopupBodyHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct PopupBlocks: View {
    let dto: AppPopupDto
    let colors: PopupColors
    let onDismiss: () -> Void
    let onOpenLink: (String) -> Void

    var body: some View {
        let align = textAlignOf(dto.style?.align)
        let frameAlign = frameAlignOf(dto.style?.align)
        ForEach(Array((dto.blocks ?? []).enumerated()), id: \.offset) { _, block in
            switch block.type {
            case "heading":
                if let text = block.text, !text.isBlankShk {
                    let size = CGFloat(min(max(block.size ?? 22, 14), 40))
                    Text(text)
                        .shkFont(size, .bold, lineHeight: size * 1.5)
                        .foregroundColor(colors.text)
                        .multilineTextAlignment(align)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: frameAlign)
                }
            case "text":
                if let text = block.text, !text.isBlankShk {
                    let size = CGFloat(min(max(block.size ?? 14, 11), 22))
                    Text(text)
                        .shkFont(size, .normal, lineHeight: size * 1.8)
                        .foregroundColor(colors.muted)
                        .multilineTextAlignment(align)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: frameAlign)
                }
            case "image":
                if let url = block.imageUrl, !url.isBlankShk {
                    let link = block.link.flatMap { $0.isBlankShk ? nil : $0 }
                    PopupBlockImage(
                        url: url,
                        maxHeight: CGFloat(min(max(block.maxHeight ?? 220, 60), 600)),
                        radius: CGFloat(dto.style?.radius ?? 18) * 0.6,
                        onTap: link.map { l in { onOpenLink(l) } }
                    )
                }
            case "button":
                if let text = block.text, !text.isBlankShk {
                    let link = block.link.flatMap { $0.isBlankShk ? nil : $0 }
                    PopupButton(
                        text: text,
                        colors: colors,
                        outline: block.variant == "outline",
                        full: block.full != false,
                        onClick: {
                            if let link { onOpenLink(link) } else if block.close == true { onDismiss() }
                        }
                    )
                }
            case "coupon":
                if let code = block.code, !code.isBlankShk { PopupCoupon(block: block, code: code, colors: colors) }
            case "countdown":
                PopupCountdown(block: block, colors: colors)
            case "newsletter":
                PopupNewsletter(block: block, colors: colors)
            case "form":
                if block.form?.slug != nil, !(block.form?.fields ?? []).isEmpty { PopupForm(block: block, colors: colors) }
            case "spacer":
                Spacer().frame(height: CGFloat(min(max(block.height ?? 16, 4), 120)))
            case "divider":
                colors.line.frame(height: 1).frame(maxWidth: .infinity)
            default:
                EmptyView()
            }
        }
    }
}

/// تصویر داخل محتوا: تمام‌عرض با حفظ نسبت (Fit) و حداکثر ارتفاع
private struct PopupBlockImage: View {
    let url: String
    let maxHeight: CGFloat
    let radius: CGFloat
    let onTap: (() -> Void)?
    @State private var ratio: CGFloat? = nil

    var body: some View {
        RemoteImage(url, contentScale: .fit)
            .aspectRatio(ratio ?? 1.6, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
            .task {
                if let img = await ShkImageLoader.shared.load(url), img.size.height > 0 { ratio = img.size.width / img.size.height }
            }
    }
}

private struct PopupButton: View {
    let text: String
    let colors: PopupColors
    let outline: Bool
    let full: Bool
    let onClick: () -> Void
    var enabled: Bool = true
    var loading: Bool = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: onClick) {
            ZStack {
                if loading {
                    MaterialSpinner(color: outline ? colors.accent : colors.accentText, lineWidth: 2, size: 18)
                } else {
                    Text(text).shkFont(14, .bold).foregroundColor(outline ? colors.accent : colors.accentText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(minWidth: full ? nil : 120, maxWidth: full ? .infinity : nil, minHeight: 44)
            .background(shape.fill(outline ? Color.clear : colors.accent.opacity(enabled ? 1 : 0.6)))
            .overlay(shape.strokeBorder(colors.accent, lineWidth: 2))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading)
    }
}

private struct PopupCoupon: View {
    let block: AppPopupBlockDto
    let code: String
    let colors: PopupColors
    @State private var copied = false

    var body: some View {
        let accent = colors.accent
        VStack(spacing: 0) {
            if let label = block.label, !label.isBlankShk {
                Text(label).shkFont(13, .normal).foregroundColor(colors.muted).padding(.bottom, 6)
            }
            HStack(spacing: 0) {
                // ارقام لاتین کد تخفیف لاتین بمونن
                Text(code)
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .kerning(2)
                    .foregroundColor(accent)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Button {
                    UIPasteboard.general.string = code
                    if !copied { popupEvent(PopupSession.currentPid, "click") }
                    copied = true
                } label: {
                    HStack(spacing: 0) {
                        RemixIcon(copied ? RemixIcons.CheckLine : RemixIcons.FileCopyLine, tint: colors.accentText, size: 15)
                        Spacer().frame(width: 4)
                        Text(copied ? "کپی شد" : "کپی").shkFont(12, .normal).foregroundColor(colors.accentText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(accent))
                }
                .buttonStyle(.plain)
            }
            .padding(6)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(accent, style: StrokeStyle(lineWidth: 2, dash: [10 / 3, 8 / 3])))
        }
        .frame(maxWidth: .infinity)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled { copied = false }
        }
    }
}

private struct PopupCountdown: View {
    let block: AppPopupBlockDto
    let colors: PopupColors
    @State private var now: Int64 = Int64(Date().timeIntervalSince1970)

    var body: some View {
        if let endsAt = block.endsTs {
            let left = max(endsAt - now, 0)
            if left > 0 {
                let days = left / 86400
                let hours = (left % 86400) / 3600
                let minutes = (left % 3600) / 60
                let seconds = left % 60
                VStack(spacing: 0) {
                    if let label = block.label, !label.isBlankShk {
                        Text(label).shkFont(13, .normal).foregroundColor(colors.muted).padding(.bottom, 6)
                    }
                    // مثل سایت: روز، ساعت، دقیقه، ثانیه از چپ به راست
                    HStack(spacing: 8) {
                        if days > 0 { CountdownCell(value: String(days).toPersianDigits(), label: "روز", colors: colors) }
                        CountdownCell(value: two(hours), label: "ساعت", colors: colors)
                        CountdownCell(value: two(minutes), label: "دقیقه", colors: colors)
                        CountdownCell(value: two(seconds), label: "ثانیه", colors: colors)
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }
                .frame(maxWidth: .infinity)
                .task(id: endsAt) {
                    while now < endsAt {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        if Task.isCancelled { return }
                        now = Int64(Date().timeIntervalSince1970)
                    }
                }
            }
        }
    }

    private func two(_ v: Int64) -> String {
        let s = String(v)
        return (s.count < 2 ? "0" + s : s).toPersianDigits()
    }
}

private struct CountdownCell: View {
    let value: String
    let label: String
    let colors: PopupColors
    var body: some View {
        VStack(spacing: 0) {
            Text(value).shkFont(20, .bold).foregroundColor(colors.accent)
            Text(label).shkFont(11, .normal).foregroundColor(colors.muted)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .frame(minWidth: 58)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.field))
    }
}

/// فیلد ورودی هم‌شکل سایت (پس‌زمینه‌ی ملایم، گوشه‌ی ۱۲، حاشیه‌ی رنگی هنگام فوکوس)
private struct PopupField: View {
    @Binding var value: String
    let placeholder: String
    let colors: PopupColors
    var singleLine: Bool = true
    var minHeight: CGFloat = 44
    var keyboard: UIKeyboardType = .default
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        ZStack(alignment: singleLine ? .leading : .topLeading) {
            if value.isEmpty && !placeholder.isEmpty {
                Text(placeholder).shkFont(14, .normal).foregroundColor(colors.muted)
            }
            Group {
                if singleLine {
                    TextField("", text: $value)
                } else {
                    TextField("", text: $value, axis: .vertical).lineLimit(3...)
                }
            }
            .font(ShkFont.yekan(14, .normal))
            .foregroundColor(colors.text)
            .tint(colors.accent)
            .keyboardType(keyboard)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .focused($focused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: singleLine ? .leading : .topLeading)
        .background(shape.fill(colors.field))
        .overlay(shape.strokeBorder(focused ? colors.accent : colors.line, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture { focused = true }
    }
}

private struct PopupDone: View {
    let message: String
    var body: some View {
        let green = Color(argb: 0xFF198754)
        HStack(spacing: 0) {
            RemixIcon(RemixIcons.CheckboxCircleLine, tint: green, size: 18)
            Spacer().frame(width: 6)
            Text(message).shkFont(14, .bold).foregroundColor(green).multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(green.opacity(0.12)))
    }
}

private struct PopupError: View {
    let message: String?
    var body: some View {
        if let message, !message.isBlankShk {
            Text(message)
                .shkFont(12, .normal)
                .foregroundColor(Color(argb: 0xFFDC3545))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
    }
}

private struct PopupNewsletter: View {
    let block: AppPopupBlockDto
    let colors: PopupColors
    @State private var value = ""
    @State private var sending = false
    @State private var done: String? = nil
    @State private var error: String? = nil

    var body: some View {
        let accept = block.accept ?? "both"
        let placeholder: String = {
            if let p = block.placeholder, !p.isBlankShk { return p }
            switch accept {
            case "email": return "ایمیل"
            case "phone": return "شماره موبایل"
            default: return "ایمیل یا شماره موبایل"
            }
        }()
        if let done {
            PopupDone(message: done)
        } else {
            VStack(spacing: 8) {
                PopupField(value: $value, placeholder: placeholder, colors: colors, keyboard: accept == "phone" ? .phonePad : .emailAddress)
                PopupButton(
                    text: block.button.flatMap { $0.isBlankShk ? nil : $0 } ?? "عضویت",
                    colors: colors,
                    outline: false,
                    full: true,
                    onClick: {
                        if value.isBlankShk {
                            error = "لطفاً \(placeholder) را وارد کنید."
                            return
                        }
                        Task {
                            sending = true
                            error = nil
                            switch await ContentRepository().subscribePopupNewsletter(value.trimmingCharacters(in: .whitespacesAndNewlines), pid: PopupSession.currentPid ?? 0) {
                            case .success(let message): done = message
                            case .error(let message): error = message
                            }
                            sending = false
                        }
                    },
                    loading: sending
                )
                PopupError(message: error)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct PopupForm: View {
    let block: AppPopupBlockDto
    let colors: PopupColors

    @State private var values: [String: String] = [:]
    @State private var checks: [String: Bool] = [:]
    @State private var captchaFirst = Int.random(in: 1...9)
    @State private var captchaSecond = Int.random(in: 1...9)
    @State private var captchaAnswer = ""
    @State private var captchaId: String? = nil
    @State private var captchaExpiresAt: Date = .distantPast
    @State private var sending = false
    @State private var done: String? = nil
    @State private var error: String? = nil

    var body: some View {
        let form = block.form
        let fields = form?.fields ?? []
        VStack(spacing: 10) {
            if block.showTitle == true, let title = form?.title, !title.isBlankShk {
                Text(title).shkFont(15, .bold).foregroundColor(colors.text).multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            if let done {
                PopupDone(message: done)
            } else {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                    if let id = field.id {
                        PopupFormField(
                            field: field,
                            colors: colors,
                            text: Binding(get: { values[id] ?? "" }, set: { values[id] = $0 }),
                            checked: Binding(get: { checks[id] == true }, set: { checks[id] = $0 })
                        )
                    }
                }
                // کپچای اپ: جمع دو عدد (همان کپچای فرم‌های اپ)
                HStack(spacing: 8) {
                    Text("\(captchaFirst.toPersianDigits()) + \(captchaSecond.toPersianDigits()) = ؟")
                        .shkFont(14, .bold)
                        .foregroundColor(colors.accent)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.accent.opacity(0.1)))
                    PopupField(value: $captchaAnswer, placeholder: "حاصل جمع", colors: colors, keyboard: .numberPad)
                }
                PopupButton(
                    text: block.button.flatMap { $0.isBlankShk ? nil : $0 } ?? "ارسال",
                    colors: colors,
                    outline: false,
                    full: true,
                    onClick: { submit(fields: fields) },
                    loading: sending
                )
                PopupError(message: error)
            }
        }
        .frame(maxWidth: .infinity)
        .task(id: block.form?.slug) { await loadCaptcha() }
    }

    // امنیتی (اپ ۳.۲): عددهای کپچا از سرور (هر captcha_id یک بار)؛ سرور قدیمی = مثل قبل عدد خود اپ
    private func loadCaptcha() async {
        if let captcha = await ContentRepository().getFormCaptcha() {
            captchaFirst = captcha.first ?? Int.random(in: 1...9)
            captchaSecond = captcha.two ?? Int.random(in: 1...9)
            captchaId = captcha.captchaId
            captchaExpiresAt = Date().addingTimeInterval(TimeInterval(max((captcha.expiresIn ?? 600) - 30, 30)))
        } else {
            captchaFirst = Int.random(in: 1...9)
            captchaSecond = Int.random(in: 1...9)
            captchaId = nil
            captchaExpiresAt = .distantPast
        }
    }

    private func submit(fields: [AppPopupFormFieldDto]) {
        guard let slug = block.form?.slug else { return }
        error = nil
        for field in fields {
            if field.status == "necessary" && field.type != "checkbox" && (values[field.id ?? ""] ?? "").isBlankShk {
                error = "لطفاً «\(field.title ?? "")» را پر کنید."
                return
            }
        }
        let latin = String(captchaAnswer.trimmingCharacters(in: .whitespaces).map { c -> Character in
            if let v = c.unicodeScalars.first?.value, v >= 0x06F0, v <= 0x06F9 { return Character(String(v - 0x06F0)) }
            return c
        })
        guard let answer = Int(latin) else {
            error = "لطفاً جواب سوال امنیتی را وارد کنید."
            return
        }
        if captchaId != nil && Date() > captchaExpiresAt {
            captchaAnswer = ""
            Task { await loadCaptcha() }
            error = "سوال امنیتی تازه شد؛ لطفاً دوباره جواب دهید."
            return
        }
        let list: [FormAnswerFieldDto] = fields.compactMap { field in
            guard let id = field.id else { return nil }
            return FormAnswerFieldDto(
                id: id,
                title: field.title ?? "",
                type: field.type ?? "text",
                status: field.status ?? "optional",
                value: field.type == "checkbox" ? (checks[id] == true ? "1" : "") : (values[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        Task {
            sending = true
            let body = FormAnswerSubmitRequest(captchaId: captchaId, captchaArgs: CaptchaArgsDto(first: captchaFirst, two: captchaSecond), captcha: answer, answer: list)
            let repository = ContentRepository()
            switch await repository.submitFormAnswer(slug, body: body) {
            case .success(let message):
                done = block.success.flatMap { $0.isBlankShk ? nil : $0 } ?? message
                if let pid = PopupSession.currentPid { await repository.sendPopupEvent(pid, event: "submit") }
            case .error(let message):
                error = message
                captchaAnswer = ""
                await loadCaptcha()
            }
            sending = false
        }
    }
}

private struct PopupFormField: View {
    let field: AppPopupFormFieldDto
    let colors: PopupColors
    @Binding var text: String
    @Binding var checked: Bool

    var body: some View {
        let title = field.title ?? ""
        let necessary = field.status == "necessary"
        let placeholder = necessary ? "\(title) *" : title
        switch field.type {
        case "checkbox":
            PopupCheckRow(text: title, selected: checked, round: false, colors: colors, onClick: { checked.toggle() })
                .frame(maxWidth: .infinity, alignment: .leading)
        case "radio":
            VStack(alignment: .leading, spacing: 0) {
                Text(placeholder).shkFont(13, .normal).foregroundColor(colors.text).padding(.bottom, 4)
                FlowRow(spacing: 14, lineSpacing: 0) {
                    ForEach(field.options ?? [], id: \.self) { option in
                        PopupCheckRow(text: option, selected: text == option, round: true, colors: colors, onClick: { text = option })
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "select":
            // تفاوت iOS: منوی کشویی با Menu خود سیستم (به‌جای DropdownMenu متریال)
            Menu {
                ForEach(field.options ?? [], id: \.self) { option in
                    Button(option) { text = option }
                }
            } label: {
                HStack(spacing: 0) {
                    Text(text.isBlankShk ? placeholder : text)
                        .shkFont(14, .normal)
                        .foregroundColor(text.isBlankShk ? colors.muted : colors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    RemixIcon(RemixIcons.ArrowDownSLine, tint: colors.muted, size: 18)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.field))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(colors.line, lineWidth: 1))
            }
        case "textarea":
            PopupField(value: $text, placeholder: placeholder, colors: colors, singleLine: false, minHeight: 96)
        case "email":
            PopupField(value: $text, placeholder: placeholder, colors: colors, keyboard: .emailAddress)
        default:
            PopupField(value: $text, placeholder: placeholder, colors: colors)
        }
    }
}

/// گزینه‌ی تیک‌زدنی / رادیویی کوچک به رنگ پاپ‌آپ
private struct PopupCheckRow: View {
    let text: String
    let selected: Bool
    let round: Bool
    let colors: PopupColors
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 0) {
                ZStack {
                    if round {
                        Circle().fill(selected ? colors.accent : Color.clear)
                        Circle().strokeBorder(selected ? colors.accent : colors.muted, lineWidth: 1.5)
                    } else {
                        RoundedRectangle(cornerRadius: 5, style: .continuous).fill(selected ? colors.accent : Color.clear)
                        RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(selected ? colors.accent : colors.muted, lineWidth: 1.5)
                    }
                    if selected { RemixIcon(RemixIcons.CheckLine, tint: colors.accentText, size: 13) }
                }
                .frame(width: 18, height: 18)
                Spacer().frame(width: 8)
                Text(text).shkFont(13, .normal).foregroundColor(colors.text)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
