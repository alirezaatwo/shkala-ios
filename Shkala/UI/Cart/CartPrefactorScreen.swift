import SwiftUI
import WebKit

/**
 * معادل ui/cart/CartPrefactorScreen.kt: پیش‌فاکتور سبد خرید - همان صفحه‌ی پیش‌فاکتور سایت (با هشدار قرمز
 * اعتبار ۲۴ ساعته) در وب‌ویو، با دکمه‌ی «چاپ / ذخیره‌ی PDF» که پنجره‌ی چاپ خود سیستم را باز می‌کند.
 * آدرس صفحه امضاشده و موقت است و از API سبد خرید گرفته می‌شود.
 * (تفاوت iOS: پنجره‌ی چاپ آی‌او‌اس گزینه‌ی «ذخیره به‌صورت PDF» ندارد؛ راهنمای زیر دکمه متناسب با iOS است)
 */
struct CartPrefactorScreen: View {
    let onBack: () -> Void

    @Environment(\.shkColors) private var colors
    private let repository = CartRepository()
    @State private var url: String? = nil
    @State private var errorMessage: String? = nil
    @State private var isPageLoading = true
    @State private var reloadKey = 0
    @StateObject private var webHolder = WebViewHolder()

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "پیش‌فاکتور", onBack: onBack)

            ZStack {
                if let error = errorMessage {
                    SiteEmptyState(icon: RemixIcons.FileListLine, title: "پیش‌فاکتور در دسترس نیست", subtitle: error,
                                   actionLabel: "تلاش دوباره", onAction: { reloadKey += 1 })
                } else if let pageUrl = url {
                    PrefactorWebView(url: pageUrl, holder: webHolder, onPageFinished: { isPageLoading = false })
                    if isPageLoading {
                        SiteLoading(message: "در حال آماده‌سازی پیش‌فاکتور...")
                    }
                } else {
                    SiteLoading(message: "در حال آماده‌سازی پیش‌فاکتور...")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if url != nil && errorMessage == nil {
                VStack(spacing: 0) {
                    Button(action: printPrefactor) {
                        HStack(spacing: 0) {
                            RemixIcon(RemixIcons.PrinterLine, tint: .white, size: 18)
                            Spacer().frame(width: 6)
                            Text("چاپ / ذخیره‌ی PDF").shkFont(14, .bold).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.primary))
                    }
                    .buttonStyle(SitePressStyle())
                    Text("از پنجره‌ی چاپ گوشی، چاپگر یا «اشتراک‌گذاری ← ذخیره در Files» را انتخاب کنید")
                        .shkFont(11)
                        .foregroundColor(colors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(colors.surface.materialShadow(8).ignoresSafeArea(edges: .bottom))
            }
        }
        .background(colors.background)
        .task(id: reloadKey) {
            errorMessage = nil
            url = nil
            isPageLoading = true
            switch await repository.getPrefactorLink() {
            case .success(let link):
                url = link
            case .error(let message):
                errorMessage = message == CartRepository.LOGIN_REQUIRED ? "برای دریافت پیش‌فاکتور وارد حساب کاربری خود شوید." : message
            }
        }
    }

    /** پنجره‌ی چاپ سیستم (چاپگر یا ذخیره) برای صفحه‌ی پیش‌فاکتور، اندازه‌ی A4 */
    private func printPrefactor() {
        guard let webView = webHolder.webView, !isPageLoading else {
            ShkToast.shared.show("پیش‌فاکتور هنوز کامل بارگذاری نشده است.")
            return
        }
        let info = UIPrintInfo(dictionary: nil)
        info.jobName = "پیش‌فاکتور"
        info.outputType = .general
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printFormatter = webView.viewPrintFormatter()
        controller.present(animated: true) { _, _, error in
            if error != nil { Task { @MainActor in ShkToast.shared.show("باز کردن پنجره‌ی چاپ ممکن نشد.") } }
        }
    }
}

/// نگه‌دارنده‌ی وب‌ویو برای دسترسی دکمه‌ی چاپ
@MainActor
final class WebViewHolder: ObservableObject {
    weak var webView: WKWebView? = nil
}

private struct PrefactorWebView: UIViewRepresentable {
    let url: String
    let holder: WebViewHolder
    let onPageFinished: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = true
        webView.backgroundColor = .white
        // صفحه به عرض نسخه‌ی چاپی ساخته شده؛ وب‌ویو آن را در عرض گوشی جا می‌دهد و بزرگ‌نمایی با دو انگشت فعال است
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 5
        holder.webView = webView
        if let u = URL(string: url) { webView.load(URLRequest(url: u)) }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onPageFinished = onPageFinished
    }

    func makeCoordinator() -> Coordinator { Coordinator(onPageFinished: onPageFinished) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onPageFinished: () -> Void
        init(onPageFinished: @escaping () -> Void) { self.onPageFinished = onPageFinished }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let callback = onPageFinished
            Task { @MainActor in callback() }
        }
    }
}
