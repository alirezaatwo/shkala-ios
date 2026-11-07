import SwiftUI

/**
 * معادل ui/appstatus/AnnouncementScreen.kt
 * صفحه‌ی جزئیات اطلاعیه (از دکمه‌ی «مشاهده» نوار اطلاعیه‌ی صفحه‌ی اصلی):
 * عنوان در نوار بالا، توضیحات HTML با همون نمایشگر HTML اپ، و دکمه‌ی «بازگشت به صفحه اصلی».
 * اگه در این فاصله اطلاعیه غیرفعال شده باشه، پیام «اطلاعیه‌ای موجود نیست» نمایش داده می‌شه.
 */
struct AnnouncementScreen: View {
    let onBack: () -> Void
    let onGoHome: () -> Void

    @Environment(\.shkColors) private var colors
    @ObservedObject private var appStatus = AppStatusCache.shared

    var body: some View {
        let announcement = appStatus.announcement
        let title = announcement?.title.flatMap { $0.isBlankShk ? nil : $0 } ?? "اطلاعیه"
        let html = announcement?.descriptionHtml.flatMap { $0.isBlankShk ? nil : $0 }
        let text = announcement?.text.flatMap { $0.isBlankShk ? nil : $0 }
        VStack(spacing: 0) {
            SitePageTopBar(title: title, onBack: onBack)
            ScrollView {
                VStack(spacing: 0) {
                    if announcement == nil {
                        SiteEmptyState(
                            icon: RemixIcons.MegaphoneLine,
                            title: "اطلاعیه‌ای موجود نیست",
                            subtitle: "این اطلاعیه دیگر فعال نیست."
                        )
                    } else if let html {
                        SiteCard { HtmlText(html: html) }
                    } else if let text {
                        // بدون توضیحات: همون متن نوار نمایش داده می‌شه
                        SiteCard {
                            Text(text)
                                .shkFont(14, .medium, lineHeight: 26)
                                .foregroundColor(colors.onSurface)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: .infinity)
            SitePrimaryButton(text: "بازگشت به صفحه اصلی", onClick: onGoHome, icon: RemixIcons.Home5Line, fillWidth: true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            Spacer().frame(height: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
    }
}
