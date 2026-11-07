import SwiftUI

// معادل ui/wallet/WalletChargeResultScreen.kt

struct WalletChargeResultScreen: View {
    let isSuccess: Bool
    let onBackToWallet: () -> Void

    @Environment(\.shkColors) private var colors
    private let repository = WalletRepository()

    @State private var referenceId: String? = nil
    @State private var isLoadingReference: Bool
    // انیمیشن ورود آیکن (فنری) و حلقه‌ی تپنده‌ی دورش
    @State private var iconScale: CGFloat = 0.3
    @State private var contentAlpha: Double = 0
    @State private var ringExpanded = false

    init(isSuccess: Bool, onBackToWallet: @escaping () -> Void) {
        self.isSuccess = isSuccess
        self.onBackToWallet = onBackToWallet
        _isLoadingReference = State(initialValue: isSuccess)
    }

    var body: some View {
        let statusColor = isSuccess ? SiteStatusColors.Success : colors.error
        ZStack {
            colors.background.ignoresSafeArea()
            SiteCard(contentPadding: .hv(20, 28), radius: 24) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.08))
                            .frame(width: 112, height: 112)
                            .scaleEffect(ringExpanded ? 1.12 : 0.9)
                        ZStack {
                            Circle().fill(statusColor.opacity(0.16))
                            RemixIcon(isSuccess ? RemixIcons.CheckboxCircleFill : RemixIcons.CloseCircleFill, tint: statusColor, size: 50)
                        }
                        .frame(width: 84, height: 84)
                        .scaleEffect(iconScale)
                    }
                    .frame(width: 120, height: 120)

                    Spacer().frame(height: 18)
                    Text(isSuccess ? "شارژ کیف پول با موفقیت انجام شد" : "شارژ کیف پول ناموفق بود")
                        .shkFont(17, .bold)
                        .foregroundColor(statusColor)
                        .multilineTextAlignment(.center)

                    if isSuccess {
                        Spacer().frame(height: 14)
                        if isLoadingReference {
                            SiteLoading(size: 40)
                        } else if let referenceId, !referenceId.trimmingCharacters(in: .whitespaces).isEmpty {
                            SiteDashedDivider()
                            SiteKeyValueRow(label: "شماره رهگیری", value: referenceId.toPersianDigits(), icon: RemixIcons.Hashtag)
                                .padding(.vertical, 4)
                            SiteDashedDivider()
                        }
                    }

                    Spacer().frame(height: 24)
                    SitePrimaryButton(text: "بازگشت به کیف پول", onClick: onBackToWallet, icon: RemixIcons.Wallet3Line, fillWidth: true)
                }
                .frame(maxWidth: .infinity)
            }
            .opacity(contentAlpha)
            .padding(16)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { contentAlpha = 1 }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) { iconScale = 1 }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { ringExpanded = true }
        }
        .task {
            guard isSuccess else { return }
            if case .success(let data) = await repository.getLastChargeTransaction() { referenceId = data.referenceId }
            isLoadingReference = false
        }
    }
}
