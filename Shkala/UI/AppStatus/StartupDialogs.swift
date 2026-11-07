import SwiftUI

/**
 * معادل ui/appstatus/StartupDialogs.kt
 * وضعیت مشترک «دیالوگ‌های شروع تموم شدن» - برای اینکه پاپ‌آپ تبلیغاتی فقط بعد از بسته شدن
 * هشدار VPN / رضایت گزارش خطا نمایش داده بشه و هیچ‌وقت روی هم نیفتن.
 */
@MainActor
final class StartupDialogsState: ObservableObject {
    static let shared = StartupDialogsState()
    /// true = هیچ دیالوگ شروعی باز نیست و قرار هم نیست خودکار باز بشه
    @Published fileprivate(set) var isIdle = false
}

/// نسخه‌ی نصب‌شده‌ی اپ (versionName اندروید = CFBundleShortVersionString)
func currentAppVersionName() -> String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
}

/**
 * دیالوگ‌های شروع اپ به‌ترتیب (هیچ‌وقت دو تا روی هم نمیان):
 *  ۱. هشدار VPN (در صورت روشن بودن)
 * داخل محتوای MaintenanceGate رندر می‌شه، پس روی صفحه‌ی «در حال بروزرسانی» نمایش داده نمی‌شه.
 */
struct StartupDialogsHost: View {
    let showVpnWarning: Bool
    let onVpnWarningDismiss: () -> Void

    @ObservedObject private var state = StartupDialogsState.shared

    var body: some View {
        // «بیکار» یعنی: هشدار VPN بسته شده
        // (مراحل رضایت گزارش خطا، مودال بروزرسانی و اجازه‌ی اعلان در بخش بعدی همین مرحله اضافه می‌شن)
        let idleNow = !showVpnWarning
        Color.clear
            .allowsHitTesting(false)
            .siteDialog(isPresented: Binding(get: { showVpnWarning }, set: { if !$0 { onVpnWarningDismiss() } })) {
                StartupVpnAdvisoryDialog(onDismiss: onVpnWarningDismiss)
            }
            // کمی تأخیر تا اگه دیالوگ دیگه‌ای همین الان قراره باز بشه، پاپ‌آپ جلوتر ازش نپره
            .task(id: idleNow) {
                if idleNow {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    if !Task.isCancelled { state.isIdle = true }
                } else {
                    state.isIdle = false
                }
            }
            .onDisappear { state.isIdle = false }
    }
}

/// معادل StartupScreens.kt: هشدار اطلاع‌رسانی (نه اجباری) موقع بالا اومدن اپ، اگه VPN روشن باشه
struct StartupVpnAdvisoryDialog: View {
    let onDismiss: () -> Void
    var body: some View {
        SiteDialogContent(
            title: "VPN شما روشن است",
            icon: RemixIcons.GlobalLine,
            iconTint: SiteStatusColors.Warning,
            message: "برای تجربه‌ی سریع‌تر و جلوگیری از بروز خطا هنگام خرید و اتصال به درگاه پرداخت، توصیه می‌شود VPN گوشی خود را خاموش کنید.",
            confirmText: "متوجه شدم",
            onConfirm: onDismiss
        )
    }
}
