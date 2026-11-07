import SwiftUI

enum OrderResultKind: String, Hashable { case SUCCESS, PENDING_REVIEW, PENDING_COORDINATION, FAILED }

// ===================================================================================
// معادل ui/payment/OrderResultScreen.kt
// بازطراحی: صفحه‌ی نتیجه‌ی سفارش - آیکن بزرگ در دایره‌ی رنگی با انیمیشن ظاهرشدن (سبز موفق /
// نارنجی در انتظار بررسی / قرمز ناموفق)، کد پیگیری در کارت با دکمه‌ی کپی، و دکمه‌های پایین.
// onViewOrders اختیاریه: اگه از بیرون داده بشه، دکمه‌ی دوم «سفارش‌های من» نمایش داده می‌شه.
// ===================================================================================

struct OrderResultScreen: View {
    let kind: OrderResultKind
    let orderUuid: String?
    let onBackToHome: () -> Void
    var onViewOrders: (() -> Void)? = nil

    @Environment(\.shkColors) private var colors
    // فاز ۱۶: پیام واقعی خطا (اگه از سرور یا وب‌ویو موجود باشه) رو نشون می‌دیم، نه فقط یه متن ثابت
    @ObservedObject private var paymentFlow = PaymentFlowState.shared
    @State private var statusText: String? = nil
    @State private var circleScale: CGFloat = 0
    @State private var iconScale: CGFloat = 0
    @State private var contentAlpha: Double = 0
    private let repository = CheckoutRepository()

    private struct ResultVisual {
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
    }

    private var visual: ResultVisual {
        switch kind {
        case .SUCCESS:
            return ResultVisual(icon: RemixIcons.CheckLine, color: SiteStatusColors.Success,
                                title: "پرداخت با موفقیت انجام شد", subtitle: "سفارش شما ثبت شد")
        case .PENDING_REVIEW:
            return ResultVisual(icon: RemixIcons.Hourglass2Line, color: SiteStatusColors.Warning, title: "سفارش شما ثبت شد",
                                subtitle: "پس از تایید رسید پرداخت توسط فروشگاه، سفارش پردازش می‌شود")
        case .PENDING_COORDINATION:
            return ResultVisual(icon: RemixIcons.CustomerService2Line, color: SiteStatusColors.Warning, title: "سفارش شما ثبت شد",
                                subtitle: "کارشناس فروشگاه برای هماهنگی پرداخت با شما تماس می‌گیرد؛ سفارش پس از تایید پرداخت پردازش می‌شود")
        case .FAILED:
            return ResultVisual(icon: RemixIcons.CloseLine, color: colors.error, title: "پرداخت ناموفق بود",
                                subtitle: paymentFlow.lastErrorMessage ?? "مبلغ کسر شده (در صورت وجود) تا ۷۲ ساعت به حسابتان بازمی‌گردد")
        }
    }

    var body: some View {
        let visual = visual
        VStack(spacing: 0) {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        // دایره‌ی بزرگ وضعیت (هاله + دایره‌ی پُر + آیکن)
                        ZStack {
                            Circle().fill(visual.color.opacity(0.08)).frame(width: 140, height: 140)
                            Circle().fill(visual.color.opacity(0.14)).frame(width: 108, height: 108)
                            Circle().fill(visual.color).frame(width: 76, height: 76)
                            RemixIcon(visual.icon, tint: .white, size: 40).scaleEffect(iconScale)
                        }
                        .frame(width: 140, height: 140)
                        .scaleEffect(circleScale)

                        Spacer().frame(height: 24)
                        VStack(spacing: 0) {
                            Text(visual.title)
                                .shkFont(19, .bold)
                                .foregroundColor(colors.onBackground)
                                .multilineTextAlignment(.center)
                            Spacer().frame(height: 8)
                            Text(visual.subtitle)
                                .shkFont(13, lineHeight: 23)
                                .foregroundColor(colors.onSurfaceVariant)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)

                            if let orderUuid {
                                Spacer().frame(height: 24)
                                SiteCard(contentPadding: .hv(14, 8)) {
                                    HStack(spacing: 0) {
                                        SiteIconBadge(icon: RemixIcons.FileList3Line, size: 36, iconSize: 18, tint: visual.color, radius: 11)
                                        Spacer().frame(width: 10)
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text("کد پیگیری").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                                            Text(orderUuid).shkFont(13, .bold).foregroundColor(colors.onSurface)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer().frame(width: 8)
                                        Button { copyToClipboard(label: "کد پیگیری", value: orderUuid) } label: {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.primary.opacity(0.1))
                                                RemixIcon(RemixIcons.FileCopyLine, contentDescription: "کپی کد پیگیری", tint: colors.primary, size: 18)
                                            }
                                            .frame(width: 36, height: 36)
                                        }
                                        .buttonStyle(SitePressStyle())
                                    }
                                    .padding(.vertical, 6)
                                    SiteDashedDivider()
                                    SiteKeyValueRow(label: "وضعیت", value: statusLabel, icon: RemixIcons.InformationLine, valueColor: visual.color)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(contentAlpha)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
            }

            // دکمه‌های پایین
            VStack(spacing: 10) {
                SitePrimaryButton(text: "بازگشت به فروشگاه", onClick: onBackToHome, icon: RemixIcons.Store2Line, fillWidth: true)
                if let onViewOrders {
                    SiteSecondaryButton(text: "مشاهده‌ی سفارش‌های من", onClick: onViewOrders, icon: RemixIcons.FileList3Line, fillWidth: true)
                }
            }
            .padding(16)
            .opacity(contentAlpha)
        }
        .background(colors.background)
        .task(id: "\(kind)-\(orderUuid ?? "")") {
            // سفارش نهایی شده، پس سبد خرید فعلی دیگه معتبر نیست - عدد نشان‌شده رو تازه کن
            CartViewModel.shared.loadCart(silently: true)
            if kind == .SUCCESS, let orderUuid, case .success(let status) = await repository.getOrderStatus(orderUuid) {
                statusText = status
            }
        }
        .onAppear(perform: animateIn)
    }

    private var statusLabel: String {
        switch kind {
        case .SUCCESS: return "پرداخت موفق"
        case .PENDING_REVIEW: return "در انتظار تایید رسید"
        case .PENDING_COORDINATION: return "در انتظار هماهنگی پرداخت"
        case .FAILED: return "پرداخت ناموفق"
        }
    }

    // انیمیشن ظاهرشدن: دایره با فنر بزرگ می‌شه، بعد آیکن و متن‌ها
    private func animateIn() {
        guard circleScale == 0 else { return }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) { circleScale = 1 }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.35).delay(0.18)) { iconScale = 1 }
        withAnimation(.easeInOut(duration: 0.4).delay(0.3)) { contentAlpha = 1 }
    }
}
