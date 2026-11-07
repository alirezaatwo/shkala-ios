import SwiftUI

/// فاز ۲۶: سایدبار اصلی اپ (از منوی همبرگری کنار لوگو) - پرده‌ی نیمه‌شفاف + پنل کشویی
/// از سمت راست (چون اپ راست‌به‌چپه، سایدبار اصلی طبق قرارداد رایج اپ‌های فارسی از راست باز می‌شه).
/// معادل دو AnimatedVisibility انتهای AppRoot.kt اندروید.
struct AppDrawerOverlay: View {
    @Binding var isPresented: Bool
    let onOpenContact: () -> Void
    let onOpenGuaranty: () -> Void
    let onOpenTerms: () -> Void
    let onOpenMagazine: () -> Void
    let onOpenFaq: () -> Void
    let onOpenTools: () -> Void

    @Environment(\.shkColors) private var colors

    var body: some View {
        // لایه‌ی فیزیکی چپ‌به‌راست تا «راست» واقعاً سمت راست صفحه باشه (حرکت ورود/خروج از لبه‌ی راست)
        ZStack(alignment: .trailing) {
            if isPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { isPresented = false }
                    // بهینه‌سازی روانی: زمان‌بندی نرم و هماهنگ با حرکت پنل منو
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.linear(duration: 0.26)),
                        removal: .opacity.animation(.linear(duration: 0.22))
                    ))
            }
            if isPresented {
                panel
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(width: 280)
                    .frame(maxHeight: .infinity)
                    .background(colors.background.ignoresSafeArea())
                    .compositingGroup()
                    .materialShadow(12)
                    // فاز ۲۷ (اصلاحیه): پنل از همون لبه‌ی راست وارد می‌شه و به همون سمت برمی‌گرده
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.3)),
                        removal: .move(edge: .trailing).animation(.timingCurve(0.4, 0, 1, 1, duration: 0.24))
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // فاز ۳۲: عنوان بالای سایدبار «دسترسی سریع»
                Text("دسترسی سریع")
                    .shkFont(16, .bold)
                    .foregroundColor(colors.onBackground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // بازطراحی: دکمه‌ی بستن هم‌سبکِ دکمه‌ی منوی هدر (کادر ۳۶ با گوشه‌ی ۱۲)
                Button(action: { isPresented = false }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surface)
                        RemixIcon(RemixIcons.CloseLine, contentDescription: "بستن", tint: colors.onBackground, size: 20)
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(SitePressStyle())
            }
            Spacer().frame(height: 16)
            AppDrawerContent(
                onOpenContact: { isPresented = false; onOpenContact() },
                onOpenGuaranty: { isPresented = false; onOpenGuaranty() },
                onOpenTerms: { isPresented = false; onOpenTerms() },
                onOpenMagazine: { isPresented = false; onOpenMagazine() },
                onOpenFaq: { isPresented = false; onOpenFaq() },
                onOpenTools: { isPresented = false; onOpenTools() }
            )
        }
        .padding(16)
    }
}

/**
 * فاز ۳۲: محتوای سایدبار اصلی اپ (منوی همبرگری).
 *
 * ترتیب از بالا به پایین: لینک‌های دسترسی سریع → «نمادها و مجوزها» (هرکدوم داخل یه باکسِ هم‌اندازه)
 * → «راه‌های ارتباطی» (آیکن‌های برندِ شبکه‌های اجتماعی) → کپی‌رایت + نسخه‌ی اپ (وسط‌چین، با ۲۰ فاصله از پایین).
 */
struct AppDrawerContent: View {
    let onOpenContact: () -> Void
    let onOpenGuaranty: () -> Void
    let onOpenTerms: () -> Void
    let onOpenMagazine: () -> Void
    let onOpenFaq: () -> Void
    // ۱.۹: «ابزارهای کاربردی» (ماشین‌حساب هارد و ...)
    var onOpenTools: () -> Void = {}

    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    @State private var seals: [TrustSealDto] = AppDrawerContent.cachedSeals
    @State private var social: SocialLinksResponse? = AppDrawerContent.cachedSocial

    // نگه‌داری در حافظه تا باز شدن دوباره‌ی منو بدون پرش باشه (در اندروید منو هر بار از نو بارگذاری می‌شه)
    private static var cachedSeals: [TrustSealDto] = []
    private static var cachedSocial: SocialLinksResponse? = nil

    private var dividerColor: Color { isDark ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider }

    var body: some View {
        // فاز ۳۴ (کد ۳-الف): دو بخش مستقل - لینک‌های دسترسی سریع بالا-چین، و بخش
        // نمادها/راه‌های ارتباطی/کپی‌رایت پایین-چین
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                // بازطراحی - منو: همه‌ی آیتم‌ها داخل یک کادر با خط‌چینِ جداکننده بین آیتم‌ها
                VStack(spacing: 0) {
                    let items: [(String, String, () -> Void)] = [
                        (RemixIcons.ToolsLine, TOOLS_TITLE, onOpenTools),
                        (RemixIcons.CustomerService2Line, "تماس با ما", onOpenContact),
                        (RemixIcons.ShieldCheckLine, "استعلام گارانتی", onOpenGuaranty),
                        (RemixIcons.ScalesLine, "قوانین و شرایط", onOpenTerms),
                        (RemixIcons.NewspaperLine, "مجله", onOpenMagazine),
                        (RemixIcons.QuestionAnswerLine, "پرسش‌های متداول", onOpenFaq),
                    ]
                    ForEach(items.indices, id: \.self) { index in
                        if index > 0 { DashedDivider(color: dividerColor) }
                        DrawerLinkRow(icon: items[index].0, label: items[index].1, onClick: items[index].2)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.surface))
            }

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                bottomSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await load() }
    }

    @ViewBuilder
    private var bottomSection: some View {
        VStack(spacing: 0) {
            if !seals.isEmpty {
                Spacer().frame(height: 20)
                // عنوان با خط قرمز - دقیقاً مثل عنوان «دسته‌بندی‌های اصلی» صفحه‌ی اصلی
                SiteSectionTitle("نمادها و مجوزها").padding(.bottom, 10)
                HStack(spacing: 14) {
                    ForEach(seals.indices, id: \.self) { i in
                        let seal = seals[i]
                        // فاز ۳۴ (کد ۳-ب): کادر سفیدِ ثابت ۷۶ با گوشه‌ی ۱۵
                        Button(action: {
                            // فاز ۳۴ (کد ۱): مستقیم با لینک trust-redirect در مرورگر خارجی
                            SocialLinkBuilder.tryOpen(seal.verifyUrl)
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white)
                                RemoteImage(seal.imageUrl, contentDescription: seal.label, contentScale: .fit)
                                    .frame(width: 58, height: 58)
                            }
                            .frame(width: 76, height: 76)
                        }
                        .buttonStyle(SitePressStyle())
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if let socialData = social, hasSocial(socialData) {
                Spacer().frame(height: 18)
                SiteSectionTitle("راه‌های ارتباطی").padding(.bottom, 10)
                // بازطراحی: آیکن رسمی هر شبکه با همون رنگ‌هایی که سایت استفاده می‌کنه
                SocialChannelsRow(social: socialData)
            }

            Spacer().frame(height: 18)
            DashedDivider(color: dividerColor)
            Spacer().frame(height: 12)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.CopyrightLine, tint: colors.onSurfaceVariant, size: 13)
                    Text(" \(Calendar(identifier: .gregorian).component(.year, from: Date())) - فروشگاه سیما حفاظ خزر")
                        .shkFont(11)
                        .foregroundColor(colors.onSurfaceVariant)
                }
                // تفاوت اجباری iOS: بروزرسانی داخل اپ (فایل APK) در iOS وجود نداره، پس فقط تگ نسخه نمایش داده می‌شه
                if let versionName = Self.versionName {
                    Spacer().frame(height: 8)
                    // نسخه‌ی اپ به‌صورت تگِ کادردار
                    Text("نسخه \(versionName)")
                        .shkFont(11, .medium, lineHeight: 16)
                        .foregroundColor(colors.onSurfaceVariant)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(colors.surface))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(colors.outline, lineWidth: 1))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
        }
    }

    private func hasSocial(_ s: SocialLinksResponse) -> Bool {
        !(s.instagram?.isBlankShk ?? true) || !(s.telegramPhone?.isBlankShk ?? true) ||
            !(s.whatsappPhone?.isBlankShk ?? true) || !(s.baleSupport?.isBlankShk ?? true)
    }

    private static var versionName: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    private func load() async {
        let repository = CatalogRepository()
        if case .success(let data) = await repository.getTrustSeals() {
            seals = data
            Self.cachedSeals = data
        }
        if case .success(let data) = await repository.getSocialLinks() {
            social = data
            Self.cachedSocial = data
        }
    }
}

private struct DrawerLinkRow: View {
    let icon: String
    let label: String
    let onClick: () -> Void

    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(colors.primary.opacity(0.1))
                    RemixIcon(icon, tint: colors.primary, size: 19)
                }
                .frame(width: 36, height: 36)
                Text(label)
                    .shkFont(13, .medium)
                    .foregroundColor(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 18)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(SitePressStyle())
    }
}
