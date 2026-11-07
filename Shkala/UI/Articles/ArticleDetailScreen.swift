import SwiftUI
import WebKit

/**
 * معادل حالت «مقاله»ی ui/product/ProductDescriptionScreen.kt (وقتی articleSlug ست شده).
 * تفاوت اجباری iOS: اندروید برای مقاله و توضیحات محصول از یک صفحه با ViewModel مشترک استفاده می‌کنه؛
 * این‌جا مسیر جداگانه‌ی articleDetail همون داده‌ها (اسلاگ، عنوان، HTML، تصویر) رو مستقیم می‌گیره.
 *
 * فاز ۳۳ (کد ۱۲): برای مقاله عنوان کنار دکمه‌ی برگشت نمایش داده نمی‌شه - به‌جاش تصویر شاخص
 * مقاله به‌صورت بزرگ و تمام‌عرض در ابتدای مقاله نشون داده می‌شه.
 */
struct ArticleDetailScreen: View {
    let articleSlug: String
    let initialTitle: String
    let initialHtml: String
    let articleImageUrl: String?
    let onBack: () -> Void

    @Environment(\.shkColors) private var colors
    private let repository = ContentRepository()

    @State private var html: String
    @State private var lightboxImages: [String] = []
    @State private var lightboxIndex: Int? = nil
    // بازطراحی: متای مقاله (نویسنده، تاریخ، زمان مطالعه، دیدگاه‌ها، بازدید) - جزئیات مقاله یک بار دیگه گرفته می‌شه
    @State private var articleMeta: ArticleDetailDto? = nil
    @State private var commentsRefreshSignal = 0
    // WebView متن رو فقط موقع ساخت بارگذاری می‌کنه؛ با این نسخه بعد از بروزرسانیِ متن دوباره ساخته می‌شه
    @State private var htmlVersion = 0

    init(articleSlug: String, title: String, html: String, imageUrl: String?, onBack: @escaping () -> Void) {
        self.articleSlug = articleSlug
        self.initialTitle = title
        self.initialHtml = html
        self.articleImageUrl = imageUrl
        self.onBack = onBack
        _html = State(initialValue: html)
    }

    var body: some View {
        let textColor = colorToCssHex(colors.onSurfaceVariant)
        let linkColor = colorToCssHex(colors.primary)
        // زمان مطالعه: اگه سایت مقدار داده همون، وگرنه از تعداد کلمات متن (~۲۰۰ کلمه در دقیقه)
        let computedReadMinutes = estimateReadMinutes(html)
        ScrollView {
            VStack(spacing: 0) {
                ArticleHero(imageUrl: articleImageUrl, title: initialTitle, onBack: onBack)

                let meta = articleMeta
                let readTimeText: String? = {
                    if let r = meta?.readTime, !r.isBlankShk { return r }
                    return computedReadMinutes.map { "\($0) دقیقه" }
                }()
                let metaItems: [(String, String)] = {
                    var items: [(String, String)] = []
                    if let d = articleListElement(meta?.jalaliCreatedAt, 0), !d.isBlankShk { items.append((RemixIcons.CalendarLine, d.toPersianDigits())) }
                    if let readTimeText { items.append((RemixIcons.TimeLine, "زمان مطالعه: \(readTimeText.toPersianDigits())")) }
                    if let c = meta?.commentsInfo?.count, !c.isBlankShk { items.append((RemixIcons.Chat3Line, "\(c.toPersianDigits()) دیدگاه")) }
                    if let v = meta?.formattedViewCount, !v.isBlankShk { items.append((RemixIcons.EyeLine, "\(v.toPersianDigits()) بازدید")) }
                    return items
                }()
                ArticleTitleBlock(
                    title: initialTitle.isEmpty ? (meta?.title ?? "") : initialTitle,
                    categoryTitle: meta?.category?.title,
                    authorName: meta?.author?.name,
                    metaItems: metaItems
                )

                ArticleWebViewContent(
                    html: html,
                    textColor: textColor,
                    linkColor: linkColor,
                    onImagesExtracted: { lightboxImages = $0 },
                    onImageClick: { lightboxIndex = $0 }
                )
                .id(htmlVersion)

                ArticleCommentsSection(articleSlug: articleSlug, refreshSignal: commentsRefreshSignal)
            }
        }
        // کشیدن صفحه‌ی مقاله به پایین: دریافت دوباره‌ی جزئیات مقاله (متا + متن) بدون پاک کردن محتوای فعلی،
        // و فرستادن سیگنال به بخش دیدگاه‌ها تا فهرست دیدگاه‌ها رو هم بی‌صدا تازه کنه (در خطا، محتوای قبلی می‌مونه)
        .sitePullRefresh {
            commentsRefreshSignal += 1
            if case .success(let data) = await repository.getArticleDetail(articleSlug) {
                articleMeta = data
                if let fresh = data.content, !fresh.isBlankShk, fresh != html {
                    html = fresh
                    htmlVersion += 1
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background.ignoresSafeArea())
        .task {
            guard articleMeta == nil else { return }
            if case .success(let data) = await repository.getArticleDetail(articleSlug) { articleMeta = data }
        }
        .fullScreenCover(isPresented: Binding(get: { lightboxIndex != nil && !lightboxImages.isEmpty }, set: { if !$0 { lightboxIndex = nil } })) {
            ImageLightbox(
                imageUrls: lightboxImages,
                initialPage: min(max(lightboxIndex ?? 0, 0), max(lightboxImages.count - 1, 0)),
                onDismiss: { lightboxIndex = nil }
            )
            .shkSheetEnvironment()
        }
    }
}

/**
 * بازطراحی: تصویر شاخص تمام‌عرض (لبه‌به‌لبه) مقاله با دکمه‌ی برگشتِ کادردار روی تصویر
 * (پس‌زمینه‌ی تیره‌ی نیمه‌شفاف تا روی هر رنگ تصویری دیده بشه - مثل صفحه‌ی تماس با ما).
 * اگه تصویری نباشه، فقط دکمه‌ی برگشت کادردار نمایش داده می‌شه.
 */
private struct ArticleHero: View {
    let imageUrl: String?
    let title: String?
    let onBack: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        if let imageUrl, !imageUrl.isBlankShk {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(colors.surfaceVariant)
                .overlay(RemoteImage(imageUrl, contentDescription: title, contentScale: .crop))
                .clipped()
                .overlay(alignment: .topLeading) {
                    Button(action: onBack) {
                        RemixIcon(RemixIcons.ArrowRightLine, contentDescription: "بازگشت", tint: .white, size: 22)
                            .frame(width: 38, height: 38)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                }
        } else {
            HStack {
                SiteIconButton(icon: RemixIcons.ArrowRightLine, contentDescription: "بازگشت", onClick: onBack, tint: colors.onBackground)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

/// بازطراحی: عنوان مقاله زیر تصویر شاخص + برچسب دسته‌بندی + ردیف متا (نویسنده، تاریخ، ...)
private struct ArticleTitleBlock: View {
    let title: String
    let categoryTitle: String?
    let authorName: String?
    let metaItems: [(String, String)]
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let categoryTitle, !categoryTitle.isBlankShk {
                SiteStatusChip(text: categoryTitle, color: colors.primary, icon: RemixIcons.FolderLine)
                Spacer().frame(height: 10)
            }
            Text(title)
                .shkFont(19, .bold, lineHeight: 32)
                .foregroundColor(colors.onBackground)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !metaItems.isEmpty || !(authorName ?? "").isBlankShk {
                Spacer().frame(height: 12)
                ArticleMetaFlow(items: metaItems, authorName: authorName)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surface))
            }
            Spacer().frame(height: 14)
            SiteDashedDivider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

/// تخمین زمان مطالعه از تعداد کلمات متن (بدون تگ‌ها) با سرعت ~۲۰۰ کلمه در دقیقه
private func estimateReadMinutes(_ html: String) -> Int? {
    if html.isBlankShk { return nil }
    var plain = html.replacingOccurrences(of: #"(?is)<(script|style)[^>]*>.*?</\1>"#, with: " ", options: .regularExpression)
    plain = plain.replacingOccurrences(of: #"<[^>]*>"#, with: " ", options: .regularExpression)
    plain = plain.replacingOccurrences(of: #"&[a-zA-Z#0-9]+;"#, with: " ", options: .regularExpression)
    let words = plain.split(whereSeparator: { $0.isWhitespace }).count
    if words == 0 { return nil }
    return max(1, (words + 199) / 200)
}

/// اسکریپت گزارش ارتفاع + کلیک عکس‌ها (همون اسکریپت onPageFinished اندروید)
let ARTICLE_HEIGHT_BRIDGE_JS = """
(function() {
    function reportNow() {
        window.webkit.messageHandlers.reportHeight.postMessage(document.documentElement.scrollHeight);
    }
    reportNow();
    setTimeout(reportNow, 300);
    setTimeout(reportNow, 800);
    setTimeout(reportNow, 1500);
    setTimeout(reportNow, 2500);
    setTimeout(reportNow, 4000);
    setTimeout(reportNow, 6000);
    window.addEventListener('load', reportNow);
    if (window.ResizeObserver) {
        new ResizeObserver(reportNow).observe(document.body);
    }
    if (window.MutationObserver) {
        new MutationObserver(reportNow).observe(document.body, { childList: true, subtree: true, attributes: true });
    }
    var imgs = document.getElementsByTagName('img');
    for (var i = 0; i < imgs.length; i++) {
        imgs[i].setAttribute('data-idx', i);
        if (imgs[i].complete) { imgs[i].classList.add('shkala-loaded'); }
        imgs[i].addEventListener('load', function() {
            this.classList.add('shkala-loaded');
            reportNow();
        });
        imgs[i].addEventListener('click', function() {
            window.webkit.messageHandlers.imageClick.postMessage(parseInt(this.getAttribute('data-idx')));
        });
    }
})();
"""

/**
 * فاز ۱۶: نسخه‌ی «آیتم داخل لیست» وب‌ویوی محتوا - برای صفحه‌ی مقاله لازمه چون دیگه تمام صفحه
 * در اختیار وب‌ویو نیست (زیرش بخش دیدگاه‌ها میاد)، پس با گزارش ارتفاع واقعی محتوا از جاوااسکریپت
 * فقط به‌اندازه‌ی محتوای واقعی مقاله ارتفاع می‌گیره. scrollHeight بر حسب CSS px هست که با
 * viewport=device-width دقیقاً معادل pt خود iOS‌ـه؛ فقط یه حاشیه‌ی امن ۲۴ اضافه می‌شه.
 */
private struct ArticleWebViewContent: View {
    let html: String
    let textColor: String
    let linkColor: String
    let onImagesExtracted: ([String]) -> Void
    let onImageClick: (Int) -> Void

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        let imageUrls = extractImageUrls(html)
        SelfSizingHtmlWebView(
            html: html,
            textColor: textColor,
            linkColor: linkColor,
            onHeight: { h in if h > contentHeight { contentHeight = h } },
            onImageClick: { index in
                onImagesExtracted(imageUrls)
                onImageClick(index)
            }
        )
        .frame(maxWidth: .infinity)
        .frame(height: contentHeight > 0 ? contentHeight + 24 : 200)
    }
}

struct SelfSizingHtmlWebView: UIViewRepresentable {
    let html: String
    let textColor: String
    let linkColor: String
    let onHeight: (CGFloat) -> Void
    let onImageClick: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onHeight: onHeight, onImageClick: onImageClick) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.userContentController.add(context.coordinator, name: "imageClick")
        config.userContentController.add(context.coordinator, name: "reportHeight")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.loadHTMLString(buildHtmlDocument(html, textColor: textColor, linkColor: linkColor), baseURL: URL(string: ApiConstants.BASE_URL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onHeight = onHeight
        context.coordinator.onImageClick = onImageClick
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "imageClick")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "reportHeight")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var onHeight: (CGFloat) -> Void
        var onImageClick: (Int) -> Void
        init(onHeight: @escaping (CGFloat) -> Void, onImageClick: @escaping (Int) -> Void) {
            self.onHeight = onHeight
            self.onImageClick = onImageClick
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let value = (message.body as? NSNumber)?.doubleValue
            switch message.name {
            case "reportHeight":
                if let value { onHeight(CGFloat(value)) }
            case "imageClick":
                if let value { onImageClick(Int(value)) }
            default: break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(ARTICLE_HEIGHT_BRIDGE_JS, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // بارگذاری خود سند و ناوبری داخل iframe ها (مثل ویدیوی آپارات) دست‌نخورده بمونه
            let urlString = navigationAction.request.url?.absoluteString ?? ""
            if urlString == ApiConstants.BASE_URL || urlString == "about:blank" || navigationAction.targetFrame?.isMainFrame == false {
                decisionHandler(.allow)
                return
            }
            Task { @MainActor in
                decisionHandler(handleHtmlContentLink(urlString) ? .cancel : .allow)
            }
        }

        // لینک‌های target=_blank پنجره‌ی جدید باز نمی‌کنن و همون مسیر لینک‌ها رو طی می‌کنن
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            let target = navigationAction.request.url?.absoluteString
            Task { @MainActor in _ = handleHtmlContentLink(target) }
            return nil
        }
    }
}
