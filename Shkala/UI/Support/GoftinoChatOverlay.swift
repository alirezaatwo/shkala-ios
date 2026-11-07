import SwiftUI
import WebKit

/// معادل GoftinoViewModel اپ اندروید: یه نمونه‌ی واحد از وب‌ویوی گفتینو رو برای کل عمر اپ نگه
/// می‌داره - نه هر بار که کاربر صفحه‌ی چت رو باز/بسته می‌کنه از نو ساخته بشه. این باعث می‌شه:
/// ۱. اتصال به گفتینو (و در نتیجه «آنلاین بودن» کاربر) همیشه برقرار بمونه
/// ۲. تاریخچه و وضعیت گفتگو با رفتن به صفحه‌ی دیگه یا بستن چت، از بین نره
final class GoftinoViewModel: ObservableObject {
    static let shared = GoftinoViewModel()

    var webView: WKWebView? = nil
    @Published var isChatVisible = false
    @Published var unreadCount = 0
    @Published var isWebViewReady = false
}

/// معادل CurrentPageViewModel اپ اندروید: صفحه‌ی فعلی کاربر (محصول/دسته‌بندی) برای گفتینو.
/// صفحه‌ها در مرحله‌ی ۳ به بعد این رو پر می‌کنن.
final class CurrentPageViewModel: ObservableObject {
    static let shared = CurrentPageViewModel()
    @Published var currentPageUrl: String? = nil
    @Published var currentPageLabel: String? = nil
}

/// چت آنلاین گفتینو، به‌عنوان یه لایه‌ی همیشه-موجود بالای کل اپ (نه یه مقصد جدا تو ناوبری).
/// این‌طوری خود وب‌ویو **هیچ‌وقت ساخته/نابود نمی‌شه** - فقط نمایانی‌اش عوض می‌شه (نامرئی وقتی
/// بسته‌ست، تمام‌صفحه وقتی بازه).
struct GoftinoChatOverlay: View {
    @ObservedObject private var goftinoVm = GoftinoViewModel.shared
    @ObservedObject private var currentPage = CurrentPageViewModel.shared
    @Environment(\.shkColors) private var colors

    @State private var siteName: String? = nil
    @State private var siteNameFetched = false
    // لودینگ اجباری ۳ ثانیه‌ای - فقط دفعه‌ی اولی که چت باز می‌شه معنی داره
    @State private var showMandatoryLoading = false

    var body: some View {
        let visible = goftinoVm.isChatVisible
        ZStack {
            // فقط صبر می‌کنیم اسم سایت (برای برچسب پلتفرم) یه‌بار موقع اولین بالا اومدن اپ دریافت بشه
            if siteNameFetched {
                GoftinoWebView(siteName: siteName, visible: visible && !showMandatoryLoading)
                    .opacity(visible && !showMandatoryLoading ? 1 : 0)
            }

            if visible && showMandatoryLoading {
                ZStack {
                    colors.background
                    VStack(spacing: 0) {
                        MaterialSpinner(color: colors.primary, lineWidth: 4, size: 40)
                        Spacer().frame(height: 16)
                        Text("در حال بارگذاری گفتگوی آنلاین")
                            .shkFont(.bodyMedium)
                            .foregroundColor(colors.onSurfaceVariant)
                    }
                }
            }
        }
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
        .task {
            if siteNameFetched { return }
            if case .success(let info) = await CatalogRepository().getSiteInfo() {
                siteName = info.siteName
            }
            siteNameFetched = true
        }
        .onChange(of: visible) { isVisible in
            if isVisible && !goftinoVm.isWebViewReady {
                showMandatoryLoading = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showMandatoryLoading = false }
            }
        }
        // هر بار کاربر یه محصول/دسته‌بندی جدید رو مشاهده کرد، بدون reload صفحه‌ی گفتینو
        // (که گفتگو رو پاک می‌کرد)، همون لحظه با جاوااسکریپت به گفتینو خبر می‌دیم "الان کاربر این‌جاست"
        .onChange(of: currentPage.currentPageUrl) { _ in pushCurrentPage() }
        .onChange(of: currentPage.currentPageLabel) { _ in pushCurrentPage() }
        .onChange(of: goftinoVm.isWebViewReady) { _ in pushCurrentPage() }
    }

    private func pushCurrentPage() {
        guard let webView = goftinoVm.webView, goftinoVm.isWebViewReady,
              let url = currentPage.currentPageUrl else { return }
        let label = (currentPage.currentPageLabel ?? "").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: " ")
        let safeUrl = url.replacingOccurrences(of: "'", with: "\\'")
        webView.evaluateJavaScript("""
        if (window.Goftino) {
            Goftino.setUser({
                metadata: [{ key: 'صفحه‌ی فعلی', value: '\(label) — \(safeUrl)' }],
                forceUpdate: true
            });
        }
        """)
    }
}

private struct GoftinoWebView: UIViewRepresentable {
    let siteName: String?
    let visible: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let vm = GoftinoViewModel.shared
        if let existing = vm.webView { return existing }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        // معادل addJavascriptInterface(..., "AndroidBridge"): همان نام در صفحه تا HTML یکی بمونه
        let bridgeScript = """
        window.AndroidBridge = {
            onWidgetReady: function () { window.webkit.messageHandlers.shkBridge.postMessage('ready'); },
            onWidgetClosed: function () { window.webkit.messageHandlers.shkBridge.postMessage('closed'); },
            onNewMessage: function () { window.webkit.messageHandlers.shkBridge.postMessage('message'); }
        };
        """
        config.userContentController.addUserScript(WKUserScript(source: bridgeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController.add(context.coordinator, name: "shkBridge")
        config.applicationNameForUserAgent = "ShkalaIOSApp/1.0"

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        vm.webView = webView

        let platformLabel = "اپلیکیشن iOS" + ((siteName?.isEmpty == false) ? " \(siteName!)" : "")
        webView.loadHTMLString(buildGoftinoHtmlPersistent(platformLabel), baseURL: URL(string: ApiConstants.BASE_URL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if visible && !context.coordinator.wasVisible {
            GoftinoViewModel.shared.unreadCount = 0
            webView.evaluateJavaScript("if (window.Goftino) { Goftino.open(); }")
        }
        context.coordinator.wasVisible = visible
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var wasVisible = false

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let vm = GoftinoViewModel.shared
            DispatchQueue.main.async {
                switch message.body as? String {
                case "ready": vm.isWebViewReady = true
                case "closed": vm.isChatVisible = false
                case "message":
                    // فقط وقتی چت باز نیست، به‌عنوان پیام خوانده‌نشده حساب می‌شه
                    if !vm.isChatVisible { vm.unreadCount += 1 }
                default: break
                }
            }
        }
    }
}

private func buildGoftinoHtmlPersistent(_ platformLabel: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
        <style>
            html, body {
                margin: 0;
                padding: 0;
                height: 100%;
                width: 100%;
                background: #ffffff;
            }
        </style>
    </head>
    <body>
        <script type="text/javascript">
            window.addEventListener('goftino_ready', function () {
                Goftino.setWidget({ hasIcon: false });
                Goftino.setUser({
                    tags: 'ios-app',
                    metadata: [{ key: 'پلتفرم', value: '\(platformLabel)' }],
                    forceUpdate: true
                });
                if (window.AndroidBridge) { window.AndroidBridge.onWidgetReady(); }
            });

            window.addEventListener('goftino_closeWidget', function () {
                if (window.AndroidBridge) { window.AndroidBridge.onWidgetClosed(); }
            });

            // این رویداد همیشه فعاله (چه پنجره‌ی چت باز باشه چه بسته)
            // چون خود اسکریپت گفتینو همیشه در حال اجراست
            window.addEventListener('goftino_getMessage', function () {
                if (window.AndroidBridge) { window.AndroidBridge.onNewMessage(); }
            });

            !function(){var i="beuMDC",d=document,g=d.createElement("script"),s="https://www.goftino.com/widget/"+i,l=localStorage.getItem("goftino_"+i);g.type="text/javascript",g.async=!0,g.src=l?s+"?o="+l:s;d.getElementsByTagName("head")[0].appendChild(g);}();
        </script>
    </body>
    </html>
    """
}
