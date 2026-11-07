import SwiftUI
import WebKit

/**
 * معادل ui/wallet/WalletChargeWebViewScreen.kt
 *
 * دقیقاً همون تکنیک صفحه‌ی پرداخت سفارش (لودینگ یکپارچه، پل ورود
 * یک‌بارمصرف، تشخیص برگشت) - فقط برای شارژ کیف پول، که آدرس برگشت
 * موفقیتش با سفارش فرق می‌کنه.
 * (تفاوت iOS: وب‌ویو زیر نوار وضعیت نمی‌ره، پس فاصله‌ی ۴۸ پیکسلی بالای اندروید لازم نیست)
 */
struct WalletChargeWebViewScreen: View {
    let onResult: (Bool) -> Void

    @StateObject private var model = WalletChargeWebModel()
    @Environment(\.shkColors) private var colors

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            if model.pending?.action != nil {
                WalletChargeWebView(model: model)
                    .background(Color.white)
            }

            if model.isLoading {
                ZStack {
                    colors.background.ignoresSafeArea()
                    // لودینگ برند اپ
                    SiteLoading(
                        message: model.loadingMessage,
                        subMessage: "حداکثر تا \(model.secondsRemaining.toPersianDigits()) ثانیه‌ی دیگر",
                        icon: RemixIcons.SecurePaymentLine
                    )
                    .padding(24)
                }
            }
        }
        .onAppear { model.start(onResult: onResult) }
    }
}

@MainActor
final class WalletChargeWebModel: ObservableObject {
    @Published var isLoading = true {
        didSet { if isLoading && !oldValue { startCountdown() } }
    }
    @Published var loadingMessage = "در حال اتصال به درگاه بانکی..."
    @Published var secondsRemaining = 10
    @Published private(set) var pending: WalletChargeResponse? = nil

    private var hasReachedBank = false
    private var formRevealed = false
    fileprivate var hasFinished = false
    fileprivate var bridgeConsumed = true
    private var lastSeenUrl: String? = nil
    private var started = false
    private var onResult: (Bool) -> Void = { _ in }
    private var countdownTask: Task<Void, Never>? = nil
    private let ourHost = URL(string: ApiConstants.BASE_URL)?.host
    weak var webView: WKWebView? = nil

    func start(onResult: @escaping (Bool) -> Void) {
        guard !started else { return }
        started = true
        self.onResult = onResult
        pending = WalletFlowState.shared.pendingCharge
        bridgeConsumed = pending?.bridgeUrl == nil
        startCountdown()
        if pending?.action == nil { finish(false) }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        secondsRemaining = 10
        countdownTask = Task { [weak self] in
            while let self, self.isLoading, self.secondsRemaining > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                self.secondsRemaining -= 1
            }
        }
    }

    fileprivate func finish(_ success: Bool) {
        if hasFinished { return }
        hasFinished = true
        countdownTask?.cancel()
        onResult(success)
    }

    func loadInitial(_ webView: WKWebView) {
        self.webView = webView
        guard let pending else { return }
        if let bridge = pending.bridgeUrl, let url = URL(string: bridge) {
            webView.load(URLRequest(url: url))
        } else {
            submitBankForm()
        }
    }

    private func submitBankForm() {
        guard let pending, let action = pending.action else { return }
        let method = pending.method ?? "POST"
        var html = "<html><body onload=\"document.forms[0].submit()\">"
        html += "<form action=\"\(action)\" method=\"\(method)\">"
        for (key, value) in pending.inputs ?? [:] {
            html += "<input type=\"hidden\" name=\"\(escapeHtmlW(key))\" value=\"\(escapeHtmlW(value))\"/>"
        }
        html += "</form></body></html>"
        webView?.loadHTMLString(html, baseURL: URL(string: action))
    }

    private func scheduleEntryHide() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !hasFinished && !formRevealed {
                isLoading = false
                formRevealed = true
                startWatching()
            }
        }
    }

    // مثل صفحه‌ی پرداخت سفارش: سقف زمانی ۹۰ ثانیه تا اگه برگشت از بانک به آدرس نتیجه‌ی
    // قابل‌تشخیص نمی‌رسید، کاربر برای همیشه تو لودینگ گیر نکنه.
    private func startWatching() {
        lastSeenUrl = webView?.url?.absoluteString
        Task { [weak self] in
            var waitedMs = 0
            while let self, !self.hasFinished, waitedMs < 90_000 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                waitedMs += 500
                let currentUrl = self.webView?.url?.absoluteString
                if let currentUrl, currentUrl != self.lastSeenUrl {
                    self.lastSeenUrl = currentUrl
                    if let success = checkWalletTerminalUrl(currentUrl) {
                        self.finish(success)
                        return
                    }
                    self.loadingMessage = "در حال بررسی نتیجه‌ی پرداخت..."
                    self.isLoading = true
                }
            }
            guard let self, !self.hasFinished else { return }
            self.finish(false)
        }
    }

    /// معادل onPageStarted / doUpdateVisitedHistory اندروید
    fileprivate func onUrlChanged(_ url: String?) {
        guard let url, !hasFinished else { return }
        if let success = checkWalletTerminalUrl(url) {
            finish(success)
            return
        }
        if formRevealed {
            loadingMessage = "در حال بررسی نتیجه‌ی پرداخت..."
            isLoading = true
        }
    }

    /// معادل onPageFinished اندروید
    fileprivate func onPageFinished(_ url: String?) {
        if !bridgeConsumed {
            bridgeConsumed = true
            submitBankForm()
            return
        }
        if !hasReachedBank, let url, let host = URL(string: url)?.host {
            let isOurSite = ourHost != nil && host.contains(ourHost!)
            if !isOurSite {
                hasReachedBank = true
                scheduleEntryHide()
            }
        }
    }

    /// معادل shouldOverrideUrlLoading اندروید
    fileprivate func terminalReached(_ success: Bool) {
        if !hasFinished { finish(success) }
    }

    /// معادل onReceivedHttpError اندروید (فقط برای لینک ورود یک‌بارمصرف)
    fileprivate func httpError(_ failedUrl: String?) {
        if hasFinished || bridgeConsumed { return }
        guard let bridge = pending?.bridgeUrl, failedUrl == bridge else { return }
        bridgeConsumed = true
        finish(false)
    }
}

private struct WalletChargeWebView: UIViewRepresentable {
    let model: WalletChargeWebModel

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = true
        webView.backgroundColor = .white
        // معادل doUpdateVisitedHistory: تغییر آدرس بدون بار شدن صفحه هم دیده می‌شه
        let coordinator = context.coordinator
        coordinator.observation = webView.observe(\.url, options: [.new]) { view, _ in
            let url = view.url?.absoluteString
            Task { @MainActor in coordinator.model.onUrlChanged(url) }
        }
        model.loadInitial(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let model: WalletChargeWebModel
        var observation: NSKeyValueObservation? = nil
        init(model: WalletChargeWebModel) { self.model = model }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            let url = webView.url?.absoluteString
            Task { @MainActor in self.model.onUrlChanged(url) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let url = webView.url?.absoluteString
            Task { @MainActor in self.model.onPageFinished(url) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString, let success = checkWalletTerminalUrl(url) {
                Task { @MainActor in self.model.terminalReached(success) }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            let status = (navigationResponse.response as? HTTPURLResponse)?.statusCode ?? 200
            if status >= 400, navigationResponse.isForMainFrame {
                let failedUrl = navigationResponse.response.url?.absoluteString
                Task { @MainActor in self.model.httpError(failedUrl) }
            }
            decisionHandler(.allow)
        }
    }
}

/** برای شارژ کیف پول، صفحه‌ی موفقیت /user/wallet?status=success و خطا همون /cart/transaction/error هست */
private func checkWalletTerminalUrl(_ url: String) -> Bool? {
    guard let components = URLComponents(string: url) else { return nil }
    let path = components.path
    let status = components.queryItems?.first(where: { $0.name == "status" })?.value
    if (path.contains("/user/wallet") || url.contains("/user/wallet")) && status == "success" { return true }
    if path.contains("/cart/transaction/error") || url.contains("/cart/transaction/error") { return false }
    return nil
}

private func escapeHtmlW(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}
