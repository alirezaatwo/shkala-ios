import SwiftUI
import UserNotifications

/**
 * معادل ui/appstatus/StartupDialogs.kt
 * وضعیت مشترک «دیالوگ‌های شروع تموم شدن» - برای اینکه پاپ‌آپ تبلیغاتی فقط بعد از بسته شدن
 * هشدار VPN / رضایت گزارش خطا / مودال بروزرسانی نمایش داده بشه و هیچ‌وقت روی هم نیفتن.
 */
@MainActor
final class StartupDialogsState: ObservableObject {
    static let shared = StartupDialogsState()
    /// true = هیچ دیالوگ شروعی باز نیست و قرار هم نیست خودکار باز بشه
    @Published fileprivate(set) var isIdle = false
}

/**
 * دیالوگ‌های شروع اپ به‌ترتیب (هیچ‌وقت دو تا روی هم نمیان):
 *  ۱. هشدار VPN (در صورت روشن بودن)
 *  ۲. درخواست رضایت برای ارسال گزارش خطاها (فقط اگه کاربر هنوز انتخاب نکرده و در این نسخه پرسیده نشده)
 *  ۳. مودال بروزرسانی (اگه نسخه‌ی جدید هست؛ یک‌بار در هر اجرای اپ)
 *  ۴. درخواست اجازه‌ی نمایش اعلان (یک‌بار در هر نصب): اول یک توضیح کوتاه، بعد پنجره‌ی خود سیستم
 * داخل محتوای MaintenanceGate رندر می‌شه، پس روی صفحه‌ی «در حال بروزرسانی» نمایش داده نمی‌شه.
 * مودال بروزرسانی (AppUpdateDialog) فقط همین‌جا رندر می‌شه؛ سایدبار فقط بازش می‌کنه.
 */
struct StartupDialogsHost: View {
    let showVpnWarning: Bool
    let onVpnWarningDismiss: () -> Void

    @ObservedObject private var state = StartupDialogsState.shared
    @ObservedObject private var updateViewModel = AppUpdateViewModel.shared

    // null = هنوز از حافظه خونده نشده؛ true = باید پرسیده بشه؛ false = نیازی نیست / جواب داده شد
    @State private var consentPending: Bool? = nil
    // اجازه‌ی اعلان: null = هنوز خونده نشده، "ask" = باید پرسیده بشه، "requesting" = پنجره‌ی سیستم بازه، "done" = تموم شد
    @State private var notificationStep: String? = nil
    @State private var notificationAskReady = false

    private enum ActiveDialog { case vpn, consent, update, notification }

    var body: some View {
        let showConsent = !showVpnWarning && consentPending == true
        let readyForUpdate = !showVpnWarning && consentPending == false
        let hasUpdate = updateViewModel.availableUpdate != nil
        // بعد از بسته شدن مودال بروزرسانی (با کمی تأخیر تا اگه مودال همین الان قراره خودکار باز بشه، جلوش نپره)
        let updateSettled = readyForUpdate && !updateViewModel.isChecking && !updateViewModel.showDialog
        let showNotification = updateSettled && notificationAskReady && notificationStep == "ask"
        let active: ActiveDialog? =
            showVpnWarning ? .vpn
            : showConsent ? .consent
            : updateViewModel.showDialog ? .update
            : showNotification ? .notification
            : nil
        // «بیکار» یعنی: هشدار VPN و سؤال رضایت بسته شدن، استعلام نسخه تموم شده، مودال بروزرسانی باز نیست و
        // درخواست اجازه‌ی اعلان هم تموم شده
        let idleNow = updateSettled && notificationStep == "done"

        Color.clear
            .allowsHitTesting(false)
            .siteDialog(
                isPresented: Binding(
                    get: { active != nil },
                    set: { shown in
                        if shown { return }
                        // لمس بیرون مودال
                        switch active {
                        case .vpn: onVpnWarningDismiss()
                        case .update: updateViewModel.closeDialog()
                        default: break
                        }
                    }
                ),
                dismissOnClickOutside: active == .vpn || (active == .update && !updateViewModel.isForced)
            ) {
                switch active {
                case .vpn:
                    StartupVpnAdvisoryDialog(onDismiss: onVpnWarningDismiss)
                case .consent:
                    SiteDialogContent(
                        title: "کمک به بهبود اپ",
                        icon: RemixIcons.ShieldCheckLine,
                        message: "برای بهبود تجربه‌ی کاربری، اجازه می‌دهید گزارش خطاها و مشکلات فنی اپ (بدون اطلاعات شخصی) برای ما ارسال شود؟",
                        confirmText: "بله، ارسال شود",
                        onConfirm: { answerConsent(true) },
                        dismissText: "خیر",
                        onDismiss: { answerConsent(false) }
                    )
                case .update:
                    AppUpdateDialog(viewModel: updateViewModel)
                case .notification:
                    SiteDialogContent(
                        title: "اعلان‌های فروشگاه",
                        icon: RemixIcons.Notification3Line,
                        message: "برای اطلاع از تخفیف‌ها و محصولات ویژه، اجازه‌ی نمایش اعلان را بدهید.",
                        confirmText: "باشه",
                        onConfirm: requestNotificationPermission,
                        dismissText: "بعداً",
                        onDismiss: { notificationStep = "done" }
                    )
                case nil:
                    EmptyView()
                }
            }
            .task {
                if consentPending == nil {
                    let version = currentAppVersionName()
                    let ask = AppMetaPreferenceManager.getErrorReportConsent() == nil &&
                        AppMetaPreferenceManager.getConsentPromptedVersion() != version
                    if ask { AppMetaPreferenceManager.setConsentPromptedVersion(version) }
                    consentPending = ask
                }
                if notificationStep == nil {
                    let settings = await UNUserNotificationCenter.current().notificationSettings()
                    let ask = settings.authorizationStatus == .notDetermined &&
                        !AppMetaPreferenceManager.wasNotificationPermissionAsked()
                    // یک‌بار در هر نصب (حتی اگه کاربر بدون جواب ببنده)
                    if ask { AppMetaPreferenceManager.markNotificationPermissionAsked() }
                    notificationStep = ask ? "ask" : "done"
                }
            }
            // باز شدن خودکار مودال بروزرسانی بعد از بسته شدن دیالوگ‌های قبلی
            .task(id: "\(readyForUpdate)|\(hasUpdate)|\(updateViewModel.isForced)") {
                if readyForUpdate && hasUpdate { updateViewModel.autoOpenIfNeeded() }
            }
            .task(id: updateSettled) {
                if updateSettled {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    if !Task.isCancelled { notificationAskReady = true }
                } else {
                    notificationAskReady = false
                }
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

    private func answerConsent(_ consented: Bool) {
        consentPending = false
        ErrorReporter.setConsent(consented)
    }

    private func requestNotificationPermission() {
        notificationStep = "requesting"
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                notificationStep = "done"
                // اجازه داده شد: اعلان‌های جدید همین الان گرفته بشن
                if granted { PushSync.checkNow(force: true) }
            }
        }
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
