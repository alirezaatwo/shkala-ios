import SwiftUI
import WebKit

/**
 * معادل ui/webview/WebPageScreen.kt
 * وقتی کاربر رو لینکی از سایت کلیک می‌کنه که هنوز صفحه‌ی اختصاصی
 * توش نساختیم (مثلاً یه مقاله‌ی وبلاگ)، به‌جای بازکردن مرورگر خارجی،
 * همین صفحه رو تو خود اپ نشون می‌دیم.
 */
struct WebPageScreen: View {
    let url: String
    let onBack: () -> Void

    @Environment(\.shkColors) private var colors
    @State private var progress = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // معادل IconButton متریال (۴۸ با آیکن ۲۴)
                Button(action: onBack) {
                    RemixIcon(RemixIcons.ArrowRightLine, contentDescription: "بازگشت", tint: colors.onBackground, size: 24)
                        .frame(width: 48, height: 48)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
            .padding(4)

            if (1...99).contains(progress) {
                // معادل LinearProgressIndicator متریال ۳ (ارتفاع ۴)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(colors.primary.opacity(0.24))
                        Capsule().fill(colors.primary).frame(width: geo.size.width * CGFloat(progress) / 100)
                    }
                }
                .frame(height: 4)
                .frame(maxWidth: .infinity)
            }

            SimpleWebView(url: url, onProgress: { progress = $0 })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
    }
}

/// وب‌ویوی ساده با گزارش درصد بارگذاری (معادل WebChromeClient.onProgressChanged)
private struct SimpleWebView: UIViewRepresentable {
    let url: String
    let onProgress: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onProgress: onProgress) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.observation = webView.observe(\.estimatedProgress, options: [.new]) { view, _ in
            let value = Int((view.estimatedProgress * 100).rounded())
            DispatchQueue.main.async { context.coordinator.onProgress(value) }
        }
        if let u = URL(string: url) ?? URL(string: url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") {
            webView.load(URLRequest(url: u))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onProgress = onProgress
    }

    final class Coordinator {
        var onProgress: (Int) -> Void
        var observation: NSKeyValueObservation?
        init(onProgress: @escaping (Int) -> Void) { self.onProgress = onProgress }
        deinit { observation?.invalidate() }
    }
}
