import SwiftUI

/// اسپلش‌اسکرین با لوگوموشن - معادل AppSplashScreen.kt اپ اندروید.
/// بارگذاری واقعی اپ هم‌زمان از اول اجرا می‌شه و بعد از لوگو، یک نوار پیشرفت مینیمال
/// (بدون درصد) نزدیک پایین نمایش داده می‌شه. تا وقتی بارگذاری کامل نشده، اپ روی همین صفحه می‌مونه.
struct AppSplashScreen: View {
    var progress: Int = 0
    /// اگه مقدار داشته باشه (اینترنت قطعه / سرور در دسترس نیست) به‌جای نوار پیشرفت، این متن و دکمه‌ی تلاش مجدد
    var offlineMessage: String? = nil
    var onRetry: () -> Void = {}
    /// برای عکس‌برداری خودکار: فریم ثابت لوگوموشن
    var fixedTimeMs: Double? = nil

    @State private var animatedProgress: CGFloat = 0
    @State private var barAlpha: Double = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            SplashLogoMotion(fixedTimeMs: fixedTimeMs)
            if let offlineMessage {
                SplashOfflinePanel(message: offlineMessage, onRetry: onRetry)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 64)
            } else {
                // نوار باریک سفید روی زمینه‌ی قرمز اسپلش
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule().fill(Color.white)
                        .frame(width: 150 * min(max(animatedProgress / 100, 0), 1))
                }
                .frame(width: 150, height: 3)
                .opacity(barAlpha)
                .padding(.bottom, 72)
            }
        }
        .onAppear {
            animatedProgress = CGFloat(min(max(progress, 0), 100))
            if fixedTimeMs != nil {
                barAlpha = fixedTimeMs! >= SPLASH_PROGRESS_FADE_IN_START_MS + SPLASH_PROGRESS_FADE_IN_MS ? 1 : 0
                return
            }
            // نوار پیشرفت بعد از ظاهر شدن لوگو و لوگوتایپ آرام ظاهر می‌شه
            DispatchQueue.main.asyncAfter(deadline: .now() + SPLASH_PROGRESS_FADE_IN_START_MS / 1000) {
                withAnimation(.easeInOut(duration: SPLASH_PROGRESS_FADE_IN_MS / 1000)) { barAlpha = 1 }
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.easeInOut(duration: 0.4)) {
                animatedProgress = CGFloat(min(max(newValue, 0), 100))
            }
        }
    }
}

/// نمایش «عدم دسترسی به اینترنت» روی اسپلش (به‌جای نوار پیشرفت) با دکمه‌ی تلاش مجدد
private struct SplashOfflinePanel: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color.white.opacity(0.18))
                RemixIcon(RemixIcons.WifiOffLine, tint: .white, size: 26)
            }
            .frame(width: 52, height: 52)
            Spacer().frame(height: 12)
            Text("عدم دسترسی به اینترنت")
                .shkFont(15, .bold, lineHeight: 22)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Spacer().frame(height: 4)
            Text(message)
                .shkFont(12, lineHeight: 20)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            Spacer().frame(height: 16)
            // دکمه‌ی سفید روی زمینه‌ی قرمز اسپلش
            Button(action: onRetry) {
                HStack(spacing: 8) {
                    RemixIcon(RemixIcons.RefreshLine, tint: Color(argb: 0xFFE60012), size: 18)
                    Text("تلاش مجدد")
                        .shkFont(14, .bold)
                        .foregroundColor(Color(argb: 0xFFE60012))
                }
                .padding(.horizontal, 22)
                .frame(height: 44)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}
