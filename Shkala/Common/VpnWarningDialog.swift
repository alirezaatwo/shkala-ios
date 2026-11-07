import SwiftUI

// معادل ui/common/VpnWarningDialog.kt
// هشدار روشن بودن VPN قبل از رفتن به درگاه بانکی (تفاوت iOS: از طریق ShkDialogCenter نمایش داده می‌شه)
@MainActor
func showVpnWarningDialog(onDismiss: @escaping () -> Void, onContinueAnyway: @escaping () -> Void) {
    ShkDialogCenter.shared.show(onDismissRequest: onDismiss) {
        SiteDialogContent(
            title: "VPN شما روشن است",
            icon: RemixIcons.ShieldKeyholeLine,
            iconTint: SiteStatusColors.Warning,
            message: "برای اتصال به درگاه بانکی، لطفاً ابتدا VPN گوشی خود را خاموش کنید، سپس دوباره ضربه بزنید.",
            confirmText: "متوجه شدم",
            onConfirm: {
                ShkDialogCenter.shared.dismiss()
                onDismiss()
            },
            dismissText: "VPN خاموشه، ادامه بده",
            onDismiss: {
                ShkDialogCenter.shared.dismiss()
                onContinueAnyway()
            }
        )
    }
}
