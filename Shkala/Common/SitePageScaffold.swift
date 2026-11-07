import SwiftUI

// ===================================================================================
// بازطراحی: اجزای مشترک صفحه‌های محتوایی (قوانین، پرسش‌های متداول و ...):
//  - SitePageTopBar : نوار بالای صفحه با دکمه‌ی برگشتِ کادردار (هم‌سبک دکمه‌ی منوی هدر)
//  - SiteHeroCard   : کارت معرفی بالای صفحه با پس‌زمینه‌ی قرمزِ گرادیانی و آیکن
//  - SiteEmptyState : حالت خالی با آیکن بزرگ، عنوان، توضیح و دکمه‌ی اختیاری
// ===================================================================================

struct SitePageTopBar<Actions: View>: View {
    let title: String
    let onBack: () -> Void
    var subtitle: String? = nil
    let actions: Actions

    @Environment(\.shkColors) private var colors

    init(title: String, onBack: @escaping () -> Void, subtitle: String? = nil, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.onBack = onBack
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surface)
                    RemixIcon(RemixIcons.ArrowRightLine, contentDescription: "بازگشت", tint: colors.onBackground, size: 22)
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(SitePressStyle())
            Spacer().frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .shkFont(16, .bold)
                    .foregroundColor(colors.onBackground)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let subtitle, !subtitle.isBlankShk {
                    Text(subtitle)
                        .shkFont(11)
                        .foregroundColor(colors.onSurfaceVariant)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            actions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
}

extension SitePageTopBar where Actions == EmptyView {
    init(title: String, onBack: @escaping () -> Void, subtitle: String? = nil) {
        self.init(title: title, onBack: onBack, subtitle: subtitle) { EmptyView() }
    }
}

struct SiteHeroCard: View {
    let icon: String
    let title: String
    let subtitle: String?

    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(0.18))
                RemixIcon(icon, tint: .white, size: 26)
            }
            .frame(width: 50, height: 50)
            Spacer().frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).shkFont(16, .bold).foregroundColor(.white)
                if let subtitle, !subtitle.isBlankShk {
                    Spacer().frame(height: 3)
                    Text(subtitle).shkFont(12, lineHeight: 20).foregroundColor(Color.white.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            // Brush.linearGradient پیش‌فرض کامپوز: از بالا-چپ به پایین-راست (فیزیکی)
            LinearGradient(colors: [colors.primary, Color(argb: 0xFFB8000E)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .environment(\.layoutDirection, .leftToRight)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SiteEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String?
    var actionLabel: String? = nil
    var actionIcon: String? = nil
    var onAction: (() -> Void)? = nil

    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(primary.opacity(0.08)).frame(width: 84, height: 84)
                Circle().fill(primary.opacity(0.12)).frame(width: 60, height: 60)
                RemixIcon(icon, tint: primary, size: 30)
            }
            Spacer().frame(height: 16)
            Text(title)
                .shkFont(15, .bold)
                .foregroundColor(colors.onSurface)
                .multilineTextAlignment(.center)
            if let subtitle, !subtitle.isBlankShk {
                Spacer().frame(height: 6)
                Text(subtitle)
                    .shkFont(12, lineHeight: 21)
                    .foregroundColor(colors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
            if let actionLabel, let onAction {
                Spacer().frame(height: 18)
                Button(action: onAction) {
                    HStack(spacing: 0) {
                        if let actionIcon {
                            RemixIcon(actionIcon, tint: .white, size: 18)
                            Spacer().frame(width: 6)
                        }
                        Text(actionLabel).shkFont(13, .bold).foregroundColor(.white)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(primary))
                }
                .buttonStyle(SitePressStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(colors.surface))
    }
}
