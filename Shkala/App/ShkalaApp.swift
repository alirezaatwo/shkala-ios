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
                MainPlaceholderScreen(
                    isDarkTheme: themePreference.isDarkTheme,
                    onToggleTheme: { themePreference.setDarkTheme(!themePreference.isDarkTheme) }
                )
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
            MainPlaceholderScreen(isDarkTheme: mode.dark, onToggleTheme: {}).systemBarsBackground()
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
/// نمونه‌ها: splash:1200 ، splash:3750 ، splash-offline ، intro:0 ، intro:5 ، main  (و «-shkDark» برای تم تاریک)
struct ScreenshotMode {
    enum Screen {
        case splash(Double)
        case splashOffline
        case intro(Int)
        case main
    }

    let screen: Screen
    let dark: Bool

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
        default: screen = .main
        }
        return ScreenshotMode(screen: screen, dark: dark)
    }()
}
