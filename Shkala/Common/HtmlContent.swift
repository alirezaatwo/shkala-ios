import SwiftUI
import WebKit

// معادل توابع مشترک ui/common/HtmlText.kt اپ اندروید (ساخت سند HTML، لینک‌ها، عکس‌ها)

/// رنگ → «#RRGGBB» برای CSS (colorToCssHexPublic اندروید)
func colorToCssHex(_ color: Color) -> String {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
}

/// پسوند فایل‌هایی که کلیک روی لینکشون به‌جای باز شدن، دانلود می‌شن
private let HtmlDownloadableExtensions: Set<String> = ["pdf", "zip", "rar", "7z", "doc", "docx", "xls", "xlsx", "ppt", "pptx"]

/**
 * مدیریت کلیک روی لینک‌های داخل محتوای HTML (توضیحات، تب‌های محصول، مقالات).
 * - لینک‌های داخلیِ همون صفحه (#بخش) → خودِ وب‌ویو اسکرول می‌کنه (false)
 * - لینک صفحه‌ی محصولِ خود سایت → صفحه‌ی محصول داخل اپ
 * - بقیه (فایل‌ها، http/https/tel/mailto/...) → باز کردن با برنامه‌ی خارجی
 *   (تفاوت اجباری iOS: DownloadManager اندروید وجود نداره؛ فایل‌ها در Safari باز/دانلود می‌شن)
 * خروجی true یعنی لینک مدیریت شد و وب‌ویو نباید خودش به اون آدرس بره.
 */
@MainActor
func handleHtmlContentLink(_ rawUrl: String?) -> Bool {
    let url = (rawUrl ?? "").trimmingCharacters(in: .whitespaces)
    if url.isEmpty { return true }
    let lower = url.lowercased()
    if lower.hasPrefix("javascript:") || lower.hasPrefix("about:") { return true }
    // لینک صفحه‌ی محصولِ خود سایت → صفحه‌ی محصول داخل خود اپ
    if InAppLinkRouter.tryOpenProduct(url) { return true }
    // لینک داخلیِ همین سند (لنگر) - سند با BASE_URL لود شده
    let base = ApiConstants.BASE_URL
    if url.contains("#") {
        let before = String(url.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0])
        if before == base || before == String(base.dropLast()) { return false }
    }
    openHtmlLinkExternally(url)
    return true
}

/// باز کردن لینک با برنامه‌ی خارجی (مرورگر، شماره‌گیر، ایمیل و ...)
@MainActor
func openHtmlLinkExternally(_ url: String) {
    guard let u = URL(string: url) ?? URL(string: url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
        ShkToast.shared.show("برنامه‌ای برای باز کردن این لینک پیدا نشد")
        return
    }
    UIApplication.shared.open(u, options: [:]) { ok in
        if !ok { Task { @MainActor in ShkToast.shared.show("برنامه‌ای برای باز کردن این لینک پیدا نشد") } }
    }
}

/// هدایت لینک‌های محصولِ خود سایت به صفحه‌ی محصول داخل اپ
@MainActor
enum InAppLinkRouter {
    private static let siteHosts: Set<String> = ["shkala.com", "www.shkala.com", "shkcctv.com", "www.shkcctv.com"]

    static func tryOpenProduct(_ url: String) -> Bool {
        guard let comps = URLComponents(string: url), let host = comps.host?.lowercased(), siteHosts.contains(host) else { return false }
        let segments = comps.path.split(separator: "/").map(String.init)
        guard segments.count >= 2, segments[0] == "product" else { return false }
        AppNavigator.shared.navigate(.productDetail(slug: segments[1].removingPercentEncoding ?? segments[1]))
        return true
    }
}

/// لیست آدرس عکس‌های داخل محتوا به ترتیب (برای لایت‌باکس)
func extractImageUrls(_ html: String) -> [String] {
    // عکس کارت‌های محصولِ داخل متن جزو گالری لایت‌باکس نیستن
    let prepared = transformProductMentions(decodeDoubleEncodedHtml(html))
    guard let regex = try? NSRegularExpression(pattern: #"<img[^>]+src=["']([^"']+)["']"#, options: [.caseInsensitive]) else { return [] }
    let ns = prepared as NSString
    return regex.matches(in: prepared, range: NSRange(location: 0, length: ns.length)).map { resolveHtmlUrl(ns.substring(with: $0.range(at: 1))) }
}

/// کارت محصولِ داخل متن مقاله: عکسِ کارت به یک باکس تصویرِ پس‌زمینه تبدیل می‌شه
func transformProductMentions(_ html: String) -> String {
    if !html.contains("product-horizontal--content") { return html }
    guard let regex = try? NSRegularExpression(
        pattern: #"(<div class="product-horizontal--content[^"]*">\s*)<img\s+src="([^"]*)"\s+alt="([^"]*)"\s*/?>"#,
        options: [.caseInsensitive]
    ) else { return html }
    let ns = html as NSString
    var result = ""
    var last = 0
    for m in regex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
        result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
        let prefix = ns.substring(with: m.range(at: 1))
        let src = ns.substring(with: m.range(at: 2)).replacingOccurrences(of: "'", with: "%27")
        result += "\(prefix)<span class=\"ph-thumb\"><span class=\"ph-thumb-img\" style=\"background-image:url('\(src)')\"></span></span>"
        last = m.range.location + m.range.length
    }
    result += ns.substring(from: last)
    return result
}

/// اگه آدرس عکس نسبی باشه (بدون دامنه)، دامنه‌ی سایت رو جلوش اضافه می‌کنه
private func resolveHtmlUrl(_ url: String) -> String {
    if url.hasPrefix("http://") || url.hasPrefix("https://") || url.hasPrefix("data:") { return url }
    let base = ApiConstants.BASE_URL.hasSuffix("/") ? String(ApiConstants.BASE_URL.dropLast()) : ApiConstants.BASE_URL
    return url.hasPrefix("/") ? base + url : base + "/" + url
}

/**
 * فاز ۱۶: بعضی بخش‌ها (مثل تب‌های محتوایی محصول) متن HTML رو انکودشده (&lt;p&gt;) ذخیره می‌کنن؛
 * اگه این‌جوری بود یک بار دیکد می‌شه. محتوای HTML سالم دست‌نخورده برمی‌گرده.
 */
func decodeDoubleEncodedHtml(_ raw: String) -> String {
    if raw.isBlankShk { return raw }
    let hasRealTag = raw.range(of: #"<[a-zA-Z/][^>]*>"#, options: .regularExpression) != nil
    guard raw.contains("&lt;") && !hasRealTag else { return raw }
    guard let data = raw.data(using: .utf8),
          let attributed = try? NSAttributedString(data: data, options: [
              .documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue,
          ], documentAttributes: nil) else { return raw }
    return attributed.string
}

/// متن ساده‌ی HTML (معادل HtmlCompat.fromHtml(...).toString())
func htmlToPlainText(_ html: String) -> String {
    if html.isEmpty { return "" }
    var s = html
    s = s.replacingOccurrences(of: #"(?is)<(script|style)[^>]*>.*?</\1>"#, with: "", options: .regularExpression)
    s = s.replacingOccurrences(of: #"(?i)<br\s*/?>"#, with: "\n", options: .regularExpression)
    s = s.replacingOccurrences(of: #"(?i)</(p|div|li|h[1-6]|tr)>"#, with: "\n", options: .regularExpression)
    s = s.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
    let entities: [String: String] = ["&nbsp;": "\u{00A0}", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'", "&zwnj;": "\u{200C}", "&rlm;": "\u{200F}", "&lrm;": "\u{200E}"]
    for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
    // موجودیت‌های عددی (&#1234; و &#x4F;)
    if let regex = try? NSRegularExpression(pattern: #"&#(x?)([0-9a-fA-F]+);"#) {
        let ns = s as NSString
        var out = ""
        var last = 0
        for m in regex.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let hex = ns.substring(with: m.range(at: 1)) == "x"
            let num = UInt32(ns.substring(with: m.range(at: 2)), radix: hex ? 16 : 10)
            if let num, let scalar = Unicode.Scalar(num) { out += String(Character(scalar)) }
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        s = out
    }
    s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
    return s
}

func buildHtmlDocument(_ bodyHtmlRaw: String, textColor: String, linkColor: String) -> String {
    let bodyHtml = transformProductMentions(decodeDoubleEncodedHtml(bodyHtmlRaw))
    // فونت: همون فونت یکانِ ثبت‌شده در خود اپ (UIAppFonts) با نام خانواده‌اش (به‌جای file:///android_asset)
    return """
    <!DOCTYPE html>
    <html dir="rtl" lang="fa">
    <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
        <style>
            html, body { margin: 0; padding: 0; background: transparent; overflow-x: hidden; -webkit-text-size-adjust: 100%; }
            body { padding: 16px 15px !important; box-sizing: border-box; }
            body, p, div, span, li, td, th, h1, h2, h3, h4, h5, h6 {
                font-family: 'IRANYekanXFaNum', 'IRANYekanX', sans-serif !important;
                direction: rtl;
                text-align: justify;
                color: \(textColor);
                line-height: 1.9;
                font-size: 15px;
                word-break: break-word;
            }
            img, video, iframe, table { max-width: 100% !important; height: auto !important; }
            img {
                opacity: 0;
                transition: opacity 0.25s ease-in;
                background: rgba(128,128,128,0.08);
                min-height: 40px;
                border-radius: 14px;
                overflow: hidden;
            }
            video, iframe { border-radius: 14px; overflow: hidden; }
            figure { margin: 12px 0; max-width: 100% !important; }
            figcaption { font-size: 12px; text-align: center; opacity: 0.8; margin-top: 6px; }
            img.shkala-loaded { opacity: 1; }
            a { color: \(linkColor); }
            body [style*="background"]:not([style*="transparent"]) { color: #1F2937; }
            body [style*="background"]:not([style*="transparent"]) * {
                color: inherit; font-size: inherit; line-height: inherit; text-align: inherit;
            }
            a[style*="background"] { -webkit-tap-highlight-color: rgba(0,0,0,0.15); cursor: pointer; }

            .w-100.d-flex { display: block; width: 100%; margin: 14px 0; }
            .product-horizontal {
                position: relative; display: block; width: 100%; box-sizing: border-box;
                background: rgba(128,128,128,0.07); border: 1px solid rgba(128,128,128,0.18);
                border-radius: 18px; padding: 10px; padding-left: 46px; cursor: pointer;
                -webkit-tap-highlight-color: transparent; transition: transform 0.15s ease, background 0.15s ease;
            }
            .product-horizontal:active { transform: scale(0.98); background: rgba(128,128,128,0.13); }
            .product-horizontal .card-body { padding: 0; margin: 0; }
            .product-horizontal--content { display: flex !important; flex-direction: row; align-items: center; gap: 12px; }
            .product-horizontal .ph-thumb {
                flex: 0 0 86px; width: 86px; height: 86px; border-radius: 14px; background: #FFFFFF;
                border: 1px solid rgba(128,128,128,0.15); overflow: hidden; display: block;
            }
            .product-horizontal .ph-thumb-img {
                display: block; width: 100%; height: 100%; background-size: contain;
                background-repeat: no-repeat; background-position: center;
            }
            .product-horizontal--information { flex: 1 1 auto; min-width: 0; }
            .product-horizontal--information h2 {
                margin: 0 0 8px 0 !important; font-size: 13.5px !important; line-height: 1.8 !important;
                font-weight: bold !important; text-align: right !important; display: -webkit-box;
                -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;
            }
            .product-horizontal--information h2 a { color: \(textColor); text-decoration: none; }
            .product-horizontal--footer {
                display: flex; flex-direction: row; align-items: center; justify-content: space-between; gap: 8px; flex-wrap: wrap;
            }
            .product-horizontal .product-colors { display: flex; flex-direction: row; gap: 4px; list-style: none; margin: 0; padding: 0; }
            .product-horizontal .product-colors:empty { display: none; }
            .product-horizontal .product-colors li {
                width: 12px; height: 12px; border-radius: 50%; box-shadow: 0 0 0 1px rgba(128,128,128,0.35); margin: 0;
            }
            .product-horizontal .product-footer-meta { display: inline-flex; flex-direction: row; align-items: center; gap: 8px; margin-right: auto; }
            .product-horizontal .product-footer-meta span { font-size: 12px; line-height: 1.6; text-align: right; }
            .product-horizontal .product-rating-average { display: inline-flex; align-items: center; gap: 2px; font-weight: bold; }
            .product-horizontal .ri-star-fill { font-style: normal; }
            .product-horizontal .ri-star-fill::before { content: "\\2605"; color: #F5A623; font-size: 13px; }
            .product-horizontal .divider { opacity: 0.3; }
            .product-horizontal .product-price-now { font-size: 14.5px !important; font-weight: bold; color: \(textColor); }
            .product-horizontal .product-price-now.fs-8,
            .product-horizontal .product-price-now.fs-9 { font-size: 12px !important; color: \(linkColor); }
            .product-horizontal .unit { font-size: 11px !important; font-weight: normal; opacity: 0.8; }
            .product-horizontal .unit::after { content: " تومان"; }
            .product-horizontal::after {
                content: ""; position: absolute; left: 10px; top: 50%; width: 28px; height: 28px; margin-top: -14px;
                border-radius: 50%; background-color: \(linkColor);
                background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E%3Cpath fill='white' d='M10.83 12l4.95 4.95-1.41 1.41L8 12l6.37-6.36 1.41 1.41z'/%3E%3C/svg%3E");
                background-size: 18px 18px; background-repeat: no-repeat; background-position: center;
            }
        </style>
    </head>
    <body>
        \(bodyHtml)
        <script>
            (function() {
                var fa = ['۰','۱','۲','۳','۴','۵','۶','۷','۸','۹'];
                function toFa(text) { return text.replace(/[0-9]/g, function(d) { return fa[parseInt(d, 10)]; }); }
                function faDigits(el) {
                    for (var k = 0; k < el.childNodes.length; k++) {
                        var node = el.childNodes[k];
                        if (node.nodeType === 3) { node.nodeValue = toFa(node.nodeValue); }
                    }
                }
                var cards = document.querySelectorAll('.go-to-product');
                for (var i = 0; i < cards.length; i++) {
                    (function(card) {
                        card.addEventListener('click', function(e) {
                            e.preventDefault();
                            var route = card.getAttribute('route');
                            if (route) { window.location.href = route; }
                        });
                        var nums = card.querySelectorAll('.product-price-now, .product-rating-average');
                        for (var j = 0; j < nums.length; j++) { faDigits(nums[j]); }
                    })(cards[i]);
                }
            })();
        </script>
    </body>
    </html>
    """
}

/// اسکریپتی که بعد از بارگذاری سند، کلیک روی عکس‌ها رو به اپ گزارش می‌ده (AndroidBridge.onImageClick)
let HTML_IMAGE_BRIDGE_JS = """
(function() {
    var imgs = document.getElementsByTagName('img');
    for (var i = 0; i < imgs.length; i++) {
        imgs[i].setAttribute('data-idx', i);
        if (imgs[i].complete) { imgs[i].classList.add('shkala-loaded'); }
        imgs[i].addEventListener('load', function() { this.classList.add('shkala-loaded'); });
        imgs[i].addEventListener('click', function() {
            window.webkit.messageHandlers.imageClick.postMessage(parseInt(this.getAttribute('data-idx')));
        });
    }
})();
"""

/// وب‌ویوی تمام‌صفحه‌ی محتوای HTML (توضیحات محصول و تب‌های محتوایی)
struct HtmlContentWebView: UIViewRepresentable {
    let html: String
    let textColor: String
    let linkColor: String
    let onImageClick: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImageClick: onImageClick) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.userContentController.add(context.coordinator, name: "imageClick")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.loadHTMLString(buildHtmlDocument(html, textColor: textColor, linkColor: linkColor), baseURL: URL(string: ApiConstants.BASE_URL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onImageClick = onImageClick
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "imageClick")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var onImageClick: (Int) -> Void
        init(onImageClick: @escaping (Int) -> Void) { self.onImageClick = onImageClick }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if let index = message.body as? Int { onImageClick(index) }
            else if let n = message.body as? NSNumber { onImageClick(n.intValue) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(HTML_IMAGE_BRIDGE_JS, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // بارگذاری خود سند و ناوبری داخل iframe ها (مثل ویدیوی آپارات) دست‌نخورده بمونه
            let urlString = navigationAction.request.url?.absoluteString ?? ""
            if urlString == ApiConstants.BASE_URL || urlString == "about:blank" || navigationAction.targetFrame?.isMainFrame == false {
                decisionHandler(.allow)
                return
            }
            let target = urlString
            Task { @MainActor in
                decisionHandler(handleHtmlContentLink(target) ? .cancel : .allow)
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

/**
 * معادل ProductDescriptionScreen اندروید (حالت توضیحات محصول/تب‌های محتوایی): نوار بالای استاندارد +
 * وب‌ویوی تمام‌صفحه. کلیک روی عکس‌ها لایت‌باکس رو باز می‌کنه.
 * (حالت مقاله‌ی همین صفحه در مرحله‌ی مجله ساخته می‌شه)
 */
struct ProductDescriptionScreen: View {
    let title: String
    let html: String
    let onBack: () -> Void

    @State private var lightboxIndex: Int? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        let imageUrls = extractImageUrls(html)
        VStack(spacing: 0) {
            SitePageTopBar(title: title, onBack: onBack)
            HtmlContentWebView(
                html: html,
                textColor: colorToCssHex(colors.onSurfaceVariant),
                linkColor: colorToCssHex(colors.primary),
                onImageClick: { index in lightboxIndex = index }
            )
        }
        .background(colors.background.ignoresSafeArea())
        .fullScreenCover(isPresented: Binding(get: { lightboxIndex != nil && !imageUrls.isEmpty }, set: { if !$0 { lightboxIndex = nil } })) {
            ImageLightbox(imageUrls: imageUrls, initialPage: min(max(lightboxIndex ?? 0, 0), max(imageUrls.count - 1, 0)), onDismiss: { lightboxIndex = nil })
                .shkSheetEnvironment()
        }
    }
}
