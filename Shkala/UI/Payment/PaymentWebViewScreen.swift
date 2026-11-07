import SwiftUI
import WebKit

/**
 * معادل ui/payment/PaymentWebViewScreen.kt
 *
 * این صفحه هم مسئول وصل شدن به درگاه (تماس با سرور) هست، هم نمایش فرم
 * بانک - عمداً هر دو کار تو همین یه صفحه انجام می‌شه تا کاربر از همون لحظه‌ی
 * زدن دکمه‌ی درگاه، فقط یه لودینگ یکپارچه ببینه.
 *
 * بعد از اینکه اطلاعات فرم بانک آماده شد، فرم رو خودکار submit می‌کنه و
 * کاربر رو تو صفحه‌ی واقعی بانک نگه می‌داره. وقتی بانک نهایتاً کاربر رو
 * به سایت خودمون برگردوند (موفق یا ناموفق)، همون لحظه رو تشخیص می‌ده و
 * به اپ خبر می‌ده.
 *
 * قبل از رفتن به بانک، اول یه لینک ورود یک‌بارمصرف (bridge_url) رو بار
 * می‌کنه تا WebView هم مثل خود سایت، وارد نشست مرورگر بشه.
 *
 * صفحه‌های گذرای بانک و مسیر برگشت به سایت پشت لودینگ خودمون پنهان می‌شن.
 * (تفاوت iOS: وب‌ویو زیر نوار وضعیت نمی‌ره، پس فاصله‌ی ۴۸ پیکسلی بالای اندروید لازم نیست)
 */
struct PaymentWebViewScreen: View {
    let onResult: (Bool, String?) -> Void

    @StateObject private var model = PaymentWebModel()
    @Environment(\.shkColors) private var colors

    var body: some View {
        ZStack {
            colors.background.ignoresSafeArea()

            if let pending = model.pendingPayment, pending.action != nil {
                PaymentWebView(model: model)
                    .background(Color.white)
            }

            if model.isLoading {
                // بازطراحی: لودینگ برندِ اپ (حلقه‌ی قرمز) برای «اتصال به درگاه» و «بررسی نتیجه‌ی پرداخت»
                ZStack {
                    colors.background.ignoresSafeArea()
                    VStack(spacing: 0) {
                        SiteLoading(
                            message: model.loadingMessage,
                            subMessage: "حداکثر تا \(model.secondsRemaining.toPersianDigits()) ثانیه‌ی دیگر",
                            icon: model.formRevealed ? RemixIcons.ShieldCheckLine : RemixIcons.SecurePaymentLine,
                            size: 88
                        )
                        Spacer().frame(height: 24)
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.InformationLine, tint: colors.primary, size: 16)
                            Spacer().frame(width: 6)
                            Text("لطفاً تا پایان این مرحله از برنامه خارج نشوید")
                                .shkFont(11)
                                .foregroundColor(colors.onSurfaceVariant)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surface))
                    }
                    .padding(.horizontal, 32)
                }
            }
        }
        .onAppear { model.start(onResult: onResult) }
    }
}

/// وضعیت و منطق وب‌ویوی پرداخت (معادل state های remember و LaunchedEffect های اندروید)
@MainActor
final class PaymentWebModel: ObservableObject {
    @Published var isLoading = true
    @Published var loadingMessage = "در حال اتصال به درگاه بانکی..."
    @Published var formRevealed = false
    @Published var secondsRemaining = 10
    @Published private(set) var pendingPayment: PayResponse? = nil

    private var hasReachedBank = false
    fileprivate var hasFinished = false
    fileprivate var bridgeConsumed = true
    private var pageLoadGeneration = 0
    private var lastSeenUrl: String? = nil
    private var started = false
    private var onResult: (Bool, String?) -> Void = { _, _ in }
    private var countdownTask: Task<Void, Never>? = nil
    private var watchTask: Task<Void, Never>? = nil
    private let ourHost = URL(string: ApiConstants.BASE_URL)?.host
    weak var webView: WKWebView? = nil

    fileprivate let flow = PaymentFlowState.shared
    private let repository = CheckoutRepository()

    func start(onResult: @escaping (Bool, String?) -> Void) {
        guard !started else { return }
        started = true
        self.onResult = onResult
        pendingPayment = flow.pendingPayment
        bridgeConsumed = flow.pendingPayment?.bridgeUrl == nil
        startCountdown()

        // اگه هنوز اطلاعات فرم بانک آماده نیست (یعنی هنوز به سرور خودمون وصل
        // نشدیم)، همین الان این کار رو انجام بده - کاربر همچنان همون یه لودینگ رو می‌بینه
        guard flow.pendingPayment == nil else { return }
        flow.lastErrorMessage = nil
        guard let gatewayId = flow.pendingGatewayId else {
            onResult(false, nil)
            return
        }
        Task {
            switch await repository.pay(paymentGateway: gatewayId, useWallet: flow.useWallet) {
            case .success(let data):
                if data.paidByWallet {
                    // فاز ۱۴: کل مبلغ با کیف پول پرداخت شد - نیازی به وب‌ویوی بانک نیست
                    onResult(true, data.orderUuid)
                } else {
                    flow.pendingPayment = data
                    bridgeConsumed = data.bridgeUrl == nil
                    pendingPayment = data
                }
            case .error(let message):
                // فاز ۱۶: پیام واقعی خطا رو نگه می‌داریم تا صفحه‌ی نتیجه نشونش بده
                flow.lastErrorMessage = message
                onResult(false, nil)
            }
        }
    }

    // شمارنده‌ی معکوس فقط جهت اطلاع کاربره که حداکثر چقدر باید صبر کنه
    private func setLoading(_ loading: Bool) {
        let wasLoading = isLoading
        isLoading = loading
        if loading && !wasLoading { startCountdown() }
        if !loading { countdownTask?.cancel() }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        secondsRemaining = 10
        countdownTask = Task { [weak self] in
            while let self, self.secondsRemaining > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                self.secondsRemaining -= 1
            }
        }
    }

    /// شروع بار کردن وب‌ویو: اول لینک ورود یک‌بارمصرف، وگرنه مستقیم فرم بانک
    func loadInitial(_ webView: WKWebView) {
        self.webView = webView
        guard let pending = pendingPayment else { return }
        if let bridge = pending.bridgeUrl, let url = URL(string: bridge) {
            webView.load(URLRequest(url: url))
        } else {
            submitBankForm()
        }
    }

    private func submitBankForm() {
        guard let pending = pendingPayment, let action = pending.action else { return }
        let method = pending.method ?? "POST"
        var html = "<html><body onload=\"document.forms[0].submit()\">"
        html += "<form action=\"\(action)\" method=\"\(method)\">"
        for (key, value) in pending.inputs ?? [:] {
            html += "<input type=\"hidden\" name=\"\(escapeHtml(key))\" value=\"\(escapeHtml(value))\"/>"
        }
        html += "</form></body></html>"
        webView?.loadHTMLString(html, baseURL: URL(string: action))
    }

    // فقط برای ورود (رفتن به بانک) یه تایمر ثابت داریم - وقتی این تموم شد
    // و لودینگ مخفی شد، یعنی فرم اصلی بانک الان واقعاً نمایش داده شده
    private func scheduleEntryHide() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !hasFinished && !formRevealed {
                setLoading(false)
                formRevealed = true
                startWatching()
            }
        }
    }

    // لایه‌ی نهایی اطمینان: مستقل از هر قلابی، هر نیم‌ثانیه مستقیم آدرس فعلی وب‌ویو رو چک
    // می‌کنیم؛ اگه عوض شده باشه و از قبل فرم اصلی نمایش داده شده، یعنی داریم برمی‌گردیم.
    // سقف ۹۰ ثانیه: به‌جای گیر کردن در لودینگ، نتیجه ناموفق اعلام می‌شه.
    private func startWatching() {
        lastSeenUrl = webView?.url?.absoluteString
        watchTask = Task { [weak self] in
            var waitedMs = 0
            while let self, !self.hasFinished, waitedMs < 90_000 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                waitedMs += 500
                let currentUrl = self.webView?.url?.absoluteString
                if let currentUrl, currentUrl != self.lastSeenUrl {
                    self.lastSeenUrl = currentUrl
                    if let (success, uuid) = checkTerminalUrl(currentUrl) {
                        self.finishWithResult(success, uuid)
                        return
                    }
                    self.loadingMessage = "در حال بررسی نتیجه‌ی پرداخت..."
                    self.pageLoadGeneration += 1
                    self.setLoading(true)
                }
            }
            guard let self, !self.hasFinished else { return }
            self.flow.lastErrorMessage = "بررسی نتیجه‌ی پرداخت بیش از حد طول کشید. لطفاً از بخش سفارش‌های من، وضعیت سفارش را بررسی کنید."
            self.finishWithResult(false, nil)
        }
    }

    // فاز ۱۶: وقتی بانک با آدرس نتیجه‌ی ناموفق برمی‌گردونه، پیام روشن و عمومی
    fileprivate func finishWithResult(_ success: Bool, _ uuid: String?) {
        if hasFinished { return }
        hasFinished = true
        watchTask?.cancel()
        countdownTask?.cancel()
        if !success && flow.lastErrorMessage == nil {
            flow.lastErrorMessage = "بانک، پرداخت را تایید نکرد یا از سوی شما لغو شد."
        }
        onResult(success, uuid)
    }

    fileprivate func onNavigationChanged(_ url: String?) {
        guard let url, !hasFinished else { return }
        if let (success, uuid) = checkTerminalUrl(url) {
            finishWithResult(success, uuid)
            return
        }
        if formRevealed {
            loadingMessage = "در حال بررسی نتیجه‌ی پرداخت..."
            pageLoadGeneration += 1
            setLoading(true)
        }
    }

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
        // بعد از ورود اولیه به بانک، هر صفحه‌ای که کامل لود بشه باید لودینگ موقتی رو ببنده
        // (با تاخیر کوتاه تا ومضه‌ی صفحه‌ی نیمه‌آماده دیده نشه)
        if formRevealed && !hasFinished {
            let myGeneration = pageLoadGeneration
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if !hasFinished && pageLoadGeneration == myGeneration { setLoading(false) }
            }
        }
    }
}

private struct PaymentWebView: UIViewRepresentable {
    let model: PaymentWebModel

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = true
        webView.backgroundColor = .white
        // معادل doUpdateVisitedHistory: تغییر آدرس بدون بار شدن صفحه (pushState) هم دیده می‌شه
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
        let model: PaymentWebModel
        var observation: NSKeyValueObservation? = nil
        init(model: PaymentWebModel) { self.model = model }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            let url = webView.url?.absoluteString
            Task { @MainActor in self.model.onUrlChanged(url) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let url = webView.url?.absoluteString
            Task { @MainActor in self.model.pageFinished(url) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString, let (success, uuid) = checkTerminalUrl(url) {
                Task { @MainActor in self.model.terminalReached(success, uuid) }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // خطای سرور در لینک ورود یک‌بارمصرف (مثلاً ۴۰۴/۴۱۹): بدون نشست، برگشت از بانک به صفحه‌ی ورود
        // می‌رفت و کاربر در لودینگ گیر می‌کرد - الان صریحاً تشخیص داده می‌شه
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            let status = (navigationResponse.response as? HTTPURLResponse)?.statusCode ?? 200
            if status >= 400, navigationResponse.isForMainFrame {
                let failedUrl = navigationResponse.response.url?.absoluteString
                Task { @MainActor in self.model.httpError(status, failedUrl) }
            }
            decisionHandler(.allow)
        }
    }
}

extension PaymentWebModel {
    /// معادل onPageStarted / doUpdateVisitedHistory اندروید
    func onUrlChanged(_ url: String?) { onNavigationChanged(url) }

    /// معادل onPageFinished اندروید
    func pageFinished(_ url: String?) { onPageFinished(url) }

    /// معادل shouldOverrideUrlLoading اندروید
    func terminalReached(_ success: Bool, _ uuid: String?) {
        if !hasFinished { finishWithResult(success, uuid) }
    }

    /// معادل onReceivedHttpError اندروید (فقط برای لینک ورود یک‌بارمصرف)
    func httpError(_ status: Int, _ failedUrl: String?) {
        if hasFinished || bridgeConsumed { return }
        guard let bridge = pendingPayment?.bridgeUrl, failedUrl == bridge else { return }
        bridgeConsumed = true
        flow.lastErrorMessage = "اتصال به نشست پرداخت با خطا مواجه شد (کد \(status)). لطفاً بعداً دوباره تلاش کنید."
        finishWithResult(false, nil)
    }
}

/** اگه آدرس فعلی همون صفحه‌ی نتیجه‌ی نهایی سایت باشه، (موفق/ناموفق) رو برمی‌گردونه، وگرنه nil */
private func checkTerminalUrl(_ url: String) -> (Bool, String?)? {
    guard let components = URLComponents(string: url) else { return nil }
    let path = components.path
    if path.contains("/cart/order/status") || url.contains("/cart/order/status") {
        return (true, components.queryItems?.first(where: { $0.name == "order" })?.value)
    }
    if path.contains("/cart/transaction/error") || url.contains("/cart/transaction/error") {
        return (false, nil)
    }
    return nil
}

private func escapeHtml(_ text: String) -> String {
    text.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}
