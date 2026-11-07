import SwiftUI

@main
struct ShkalaApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// معادل MainActivity اپ اندروید: اسپلش ← اینترو (فقط بار اول) ← صفحه‌ی اصلی اپ
struct RootView: View {
    private enum AppStage { case splash, intro, main }

    @StateObject private var themePreference = ThemePreferenceManager()
    @State private var startupViewModel = StartupViewModel()
    @State private var stage: AppStage = .splash
    /// هر بار «تلاش مجدد» = بارگذاری مجدد کامل اپ از اسپلش (مثل recreate() اندروید)
    @State private var launchId = UUID()

    private let screenshot = ScreenshotMode.current

    var body: some View {
        content
            .id(launchId)
            .shkalaTheme(darkTheme: screenshot?.dark ?? themePreference.isDarkTheme)
    }

    @ViewBuilder
    private var content: some View {
        if let screenshot {
            screenshotContent(screenshot)
        } else {
            switch stage {
            case .splash:
                SplashStage(viewModel: startupViewModel, onRetry: restart) {
                    stage = IntroPreferenceManager.hasSeenIntro() ? .main : .intro
                }
            case .intro:
                IntroScreen(onFinish: {
                    IntroPreferenceManager.markIntroAsSeen()
                    stage = .main
                })
                .systemBarsBackground()
            case .main:
                // معادل MaintenanceGate { AppRoot } + لایه‌ی همیشگی گفتینو
                ZStack {
                    MaintenanceGate {
                        AppRoot(
                            isDarkTheme: themePreference.isDarkTheme,
                            onToggleTheme: { themePreference.setDarkTheme(!themePreference.isDarkTheme) }
                        )
                    }
                    GoftinoChatOverlay()
                }
                .systemBarsBackground()
            }
        }
    }

    private func restart() {
        startupViewModel = StartupViewModel()
        stage = .splash
        launchId = UUID()
    }

    @ViewBuilder
    private func screenshotContent(_ mode: ScreenshotMode) -> some View {
        switch mode.screen {
        case .splash(let ms):
            AppSplashScreen(progress: 60, fixedTimeMs: ms).systemBarsBackground()
        case .splashOffline:
            AppSplashScreen(offlineMessage: StartupViewModel.MESSAGE_NO_INTERNET, fixedTimeMs: SPLASH_LOGO_MOTION_MS)
                .systemBarsBackground()
        case .intro(let page):
            IntroScreen(onFinish: {}, initialPage: page).systemBarsBackground()
        case .main:
            // صفحه‌ی اصلی با داده‌ی زنده‌ی سایت (شبیه‌ساز CI به shkala.com دسترسی داره)
            AppRoot(isDarkTheme: mode.dark).systemBarsBackground()
        case .drawer:
            AppRoot(isDarkTheme: mode.dark, initialDrawerOpen: true).systemBarsBackground()
        case .auth(let state):
            AuthScreen(onLoginSuccess: {}, viewModel: ScreenshotMode.authViewModel(state)).systemBarsBackground()
        case .maintenance(let countdown):
            MaintenanceScreen(
                title: nil,
                description: "برای ارائه‌ی تجربه‌ای بهتر، فروشگاه سیما حفاظ خزر در حال بروزرسانی است و به‌زودی با امکانات تازه برمی‌گردیم. از شکیبایی شما سپاسگزاریم.",
                contacts: AppContactsDto(
                    mobile1: "09120398602", mobile2: "09115585589", landline: "01333234659",
                    whatsappUrl: "http://wa.me/+989120398602", baleUrl: "https://web.bale.ai/chat?uid=1061321461"
                ),
                endsAtMillis: countdown ? nowMs() + ((2 * 3600 + 15 * 60 + 42) * 1000) : nil
            )
            .systemBarsBackground()
        }
    }
}

/// اسپلش + اجرای بارگذاری واقعی (معادل LaunchedEffect های MainActivity اندروید)
private struct SplashStage: View {
    @ObservedObject var viewModel: StartupViewModel
    @ObservedObject private var network = NetworkMonitor.shared
    let onRetry: () -> Void
    let onFinished: () -> Void

    var body: some View {
        AppSplashScreen(progress: viewModel.progress, offlineMessage: viewModel.offlineMessage, onRetry: onRetry)
            .systemBarsBackground()
            .task {
                let startup = await viewModel.startIfNeeded()
                // حداقل زمان نمایش اسپلش = طول لوگوموشن (بارگذاری هم‌زمان در جریانه)
                try? await Task.sleep(nanoseconds: UInt64(SPLASH_LOGO_MOTION_MS * 1_000_000))
                await startup.value
                if await !network.isInternetAvailable { await viewModel.markOffline() }
                // اینترنت قطع بود / قطع شد: روی اسپلش با پیام «عدم دسترسی» و دکمه‌ی تلاش مجدد می‌مونیم
                if await viewModel.offlineMessage != nil { return }
                // فرصت برای اینکه انیمیشن نوار به ۱۰۰٪ برسه و دیده بشه
                try? await Task.sleep(nanoseconds: 450_000_000)
                await MainActor.run { onFinished() }
            }
            // قطع شدن اینترنت در حین بارگذاری: ۲ ثانیه صبر و دوباره بررسی
            .onChange(of: network.isInternetAvailable) { available in
                if !available && viewModel.offlineMessage == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if !network.isInternetAvailable { viewModel.markOffline() }
                    }
                } else if available && viewModel.offlineMessage != nil {
                    // وصل شدن دوباره‌ی اینترنت: اپ خودکار از نو بارگذاری می‌شه
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if network.isInternetAvailable { onRetry() }
                    }
                }
            }
    }
}

/// حالت عکس‌برداری خودکار در CI: با آرگومان اجرای «-shkScreen <نام>» یک صفحه‌ی ثابت نمایش داده می‌شه.
/// نمونه‌ها: splash:1200 ، splash:3750 ، splash-offline ، intro:0 ، intro:5 ، main ، auth:code ، maintenance ،
/// maintenance-countdown ، drawer  (و «-shkDark» برای تم تاریک، «-shkScrollY 1200» برای اسکرول صفحه‌ی اصلی)
struct ScreenshotMode {
    enum Screen {
        case splash(Double)
        case splashOffline
        case intro(Int)
        case main
        case drawer
        case auth(String)
        case maintenance(Bool)
    }

    static var isActive: Bool { current != nil }

    /// وضعیت‌های نمایشی صفحه‌ی ورود: phone / phone-error / password / code / code-error / code-success
    @MainActor
    static func authViewModel(_ name: String) -> AuthViewModel {
        let vm = AuthViewModel()
        var s = AuthUiState()
        switch name {
        case "phone-error":
            s.phone = "0912"
            s.errorMessage = "شماره موبایل معتبر نیست. مثال: 09123456789"
        case "password":
            s.loginMode = .PASSWORD
            s.phone = "09123456789"
            s.password = "secret12"
        case "code":
            s.step = .ENTER_CODE
            s.phone = "09123456789"
            s.code = "48"
            s.remainingSeconds = 97
        case "code-error":
            s.step = .ENTER_CODE
            s.phone = "09123456789"
            s.code = "48213"
            s.remainingSeconds = 0
            s.otpStatus = .error
            s.errorMessage = "کد تایید اشتباه است."
        case "code-success":
            s.step = .ENTER_CODE
            s.phone = "09123456789"
            s.code = "48213"
            s.remainingSeconds = 45
            s.otpStatus = .success
        default:
            break
        }
        vm.debugSetState(s)
        return vm
    }

    let screen: Screen
    let dark: Bool
    /// «-shkScrollY <عدد>»: اسکرول صفحه‌ی اصلی به این موقعیت (pt) برای عکس از بخش‌های پایین
    var scrollY: CGFloat = 0

    static let current: ScreenshotMode? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-shkScreen"), i + 1 < args.count else { return nil }
        let value = args[i + 1]
        let dark = args.contains("-shkDark")
        let parts = value.split(separator: ":").map(String.init)
        let screen: Screen
        switch parts.first {
        case "splash": screen = .splash(Double(parts.count > 1 ? parts[1] : "") ?? SPLASH_LOGO_MOTION_MS)
        case "splash-offline": screen = .splashOffline
        case "intro": screen = .intro(Int(parts.count > 1 ? parts[1] : "") ?? 0)
        case "auth": screen = .auth(parts.count > 1 ? parts[1] : "phone")
        case "drawer": screen = .drawer
        case "maintenance": screen = .maintenance(false)
        case "maintenance-countdown": screen = .maintenance(true)
        default: screen = .main
        }
        var scrollY: CGFloat = 0
        if let j = args.firstIndex(of: "-shkScrollY"), j + 1 < args.count, let v = Double(args[j + 1]) { scrollY = CGFloat(v) }
        return ScreenshotMode(screen: screen, dark: dark, scrollY: scrollY)
    }()
}

/// فقط عکس‌برداری CI: پیدا کردن UIScrollView والد و اسکرول به موقعیت y (بعد از بارگذاری داده‌ها)
struct ScreenshotScrollOffset: UIViewRepresentable {
    let y: CGFloat

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        guard y > 0 else { return v }
        // چند بار تلاش، چون محتوای صفحه بعد از رسیدن داده‌های سرور بلند می‌شه
        for delay in [2.5, 4.0, 5.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak v] in
                var s = v?.superview
                while s != nil && !(s is UIScrollView) { s = s?.superview }
                guard let scroll = s as? UIScrollView else { return }
                let maxY = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                scroll.setContentOffset(CGPoint(x: 0, y: min(y, maxY) - scroll.adjustedContentInset.top), animated: false)
            }
        }
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
