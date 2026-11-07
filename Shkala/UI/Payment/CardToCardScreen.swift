import SwiftUI
import PhotosUI

// ===================================================================================
// معادل ui/payment/CardToCardScreen.kt
// بازطراحی: صفحه‌ی پرداخت کارت‌به‌کارت - فاکتور با خط‌چین، کارت بانکیِ گرادیانی (نام بانک،
// شماره‌کارت و زیر آن شماره‌شبا هر دو با دکمه‌ی کپی، دارنده‌ی حساب؛ اجزا در CardToCardComponents)،
// کادر خط‌چینِ بارگذاری رسید و دکمه‌ی ثابت پایین.
// ===================================================================================

struct CardToCardScreen: View {
    let onBack: () -> Void
    let onSubmitted: (String?) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = CheckoutRepository()
    private let gateway = PaymentFlowState.shared.pendingCardToCardGateway
    // دقیقاً مثل کارت‌به‌کارت سایت: کیف پول در پرداخت کارت‌به‌کارت اعمال نمی‌شه و کل مبلغ
    // سفارش باید واریز بشه (حتی اگه کاربر در صفحه‌ی تسویه‌حساب کسر از کیف پول رو روشن کرده باشه)
    private let useWallet = false
    private let walletToggledOnCheckout = PaymentFlowState.shared.useWallet
    private let walletUsed: Int64 = 0

    @State private var pickedImage: Data? = nil
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var isSubmitting = false
    // فاز ۱۵: جمع مالی سفارش، برای نمایش «مبلغ واقعی قابل‌واریز کارت‌به‌کارت» با جزئیات تخفیف/کیف پول
    @State private var totalFinalPrice: Int64 = 0
    @State private var couponDiscount: Int64 = 0
    @State private var walletBalance: Int64 = 0
    @State private var isLoadingSummary = true

    private var payableByCardToCard: Int64 { max(0, totalFinalPrice - walletUsed) }

    var body: some View {
        if let gateway {
            content(gateway)
        } else {
            SiteEmptyState(icon: RemixIcons.ErrorWarningLine, title: "اطلاعات درگاه یافت نشد.", subtitle: nil)
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(colors.background)
        }
    }

    private func content(_ gateway: PaymentGatewayDto) -> some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "پرداخت کارت‌به‌کارت", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isLoadingSummary {
                        SiteLoading(message: "در حال محاسبه‌ی مبلغ قابل‌واریز...", icon: RemixIcons.BillLine)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }

                    // فاز ۱۵: جزئیات مبلغ نهایی - تا کاربر دقیقاً بدونه چقدر باید کارت‌به‌کارت کنه
                    if !isLoadingSummary && totalFinalPrice > 0 {
                        SiteSectionTitle("جزئیات مبلغ").padding(.top, 6).padding(.bottom, 10)
                        SiteCard(contentPadding: .hv(14, 8)) {
                            SiteKeyValueRow(label: "جمع سفارش", value: "\(formatTomanFa(totalFinalPrice + couponDiscount)) تومان", icon: RemixIcons.ShoppingBag3Line)
                            if couponDiscount > 0 {
                                SiteDashedDivider()
                                SiteKeyValueRow(label: "تخفیف", value: "\(formatTomanFa(couponDiscount))- تومان",
                                                icon: RemixIcons.Coupon3Line, valueColor: colors.error)
                            }
                            if walletUsed > 0 {
                                SiteDashedDivider()
                                SiteKeyValueRow(label: "کسر از کیف پول", value: "\(formatTomanFa(walletUsed))- تومان",
                                                icon: RemixIcons.Wallet3Line, valueColor: colors.error)
                            }
                            if walletToggledOnCheckout {
                                SiteDashedDivider()
                                Text("در پرداخت کارت‌به‌کارت، موجودی کیف پول اعمال نمی‌شود و کل مبلغ سفارش باید واریز شود.")
                                    .shkFont(11, lineHeight: 19)
                                    .foregroundColor(colors.onSurfaceVariant)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            SiteDashedDivider()
                            SiteKeyValueRow(label: "مبلغ قابل‌واریز کارت‌به‌کارت", value: "\(formatTomanFa(payableByCardToCard)) تومان",
                                            valueColor: colors.primary, emphasized: true)
                        }
                    }

                    if payableByCardToCard > 0 {
                        SiteSectionTitle("اطلاعات حساب مقصد").padding(.top, 20).padding(.bottom, 10)
                        // راهنمای واریز
                        CardToCardGuideBox(text: "مبلغ درج‌شده بالا را به شماره‌کارت و یا شماره‌شبا زیر واریز کنید و سپس تصویر رسید را بارگذاری و ارسال نمایید")
                        Spacer().frame(height: 12)
                        // کارت بانکی: شماره‌کارت و شبا (زیر آن) هر دو با دکمه‌ی کپی
                        CardToCardBankDetails(bankDetails: gateway.bankDetails ?? [], onCopy: { detail in
                            copyToClipboard(label: detail.label, value: detail.value ?? "")
                        })

                        SiteSectionTitle("عکس رسید پرداخت").padding(.top, 20).padding(.bottom, 10)
                        CardToCardReceiptPicker(pickedImage: pickedImage, pickerItem: $pickerItem)
                    } else if !isLoadingSummary {
                        Spacer().frame(height: 12)
                        SiteCard {
                            HStack(spacing: 0) {
                                SiteIconBadge(icon: RemixIcons.Wallet3Line, tint: SiteStatusColors.Success)
                                Spacer().frame(width: 12)
                                Text("کل مبلغ این سفارش با کیف پول شما پوشش داده می‌شه و نیازی به واریز کارت‌به‌کارت نیست.")
                                    .shkFont(13, lineHeight: 22)
                                    .foregroundColor(colors.onSurface)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
            }

            SitePrimaryButton(text: "ثبت سفارش", onClick: submit, icon: RemixIcons.CheckDoubleLine,
                              enabled: !isLoadingSummary, loading: isSubmitting, fillWidth: true)
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    TopRoundedShape(radius: 20)
                        .fill(colors.surface)
                        .shadow(color: .black.opacity(0.14), radius: 9, x: 0, y: -2)
                        .ignoresSafeArea(edges: .bottom)
                )
        }
        .background(colors.background)
        .task { await loadSummary() }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = await loadPickedImageData(item) {
                    if let error = validateImageUpload(data) {
                        ShkToast.shared.show(error)
                    } else {
                        pickedImage = data
                    }
                }
                pickerItem = nil
            }
        }
    }

    private func loadSummary() async {
        guard isLoadingSummary else { return }
        if case .success(let shipping) = await repository.getShipping() {
            totalFinalPrice = shipping.financial?.totalFinalPrice ?? 0
            couponDiscount = shipping.financial?.totalCouponDiscountPrice ?? 0
            walletBalance = shipping.walletBalance ?? 0
        }
        // اگه جمع مالی نیاد، فقط بخش جزئیات نمایش داده نمی‌شه
        isLoadingSummary = false
    }

    private func submit() {
        let needsReceipt = payableByCardToCard > 0
        if needsReceipt && pickedImage == nil {
            ShkToast.shared.show("لطفاً عکس رسید را انتخاب کنید.")
            return
        }
        isSubmitting = true
        let receipt = needsReceipt ? pickedImage : nil
        Task {
            switch await repository.payCardToCard(receipt: receipt, useWallet: useWallet) {
            case .success(let uuid):
                isSubmitting = false
                onSubmitted(uuid)
            case .error(let message):
                isSubmitting = false
                ShkToast.shared.show(message, long: true)
            }
        }
    }
}
