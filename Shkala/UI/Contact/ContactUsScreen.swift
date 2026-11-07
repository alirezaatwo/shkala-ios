import SwiftUI

/**
 * معادل ui/contact/ContactUsScreen.kt
 * صفحه‌ی «تماس با ما» (ترتیب بخش‌ها مثل اندروید):
 * تصویر هدر → درباره‌ی ما → چرا ما → آمار → برندهای همکار → خدمات پس از فروش →
 * کارشناسان فروش → با اطمینان خرید کنید → خرید حضوری → نقشه و مسیریابی →
 * راه‌های ارتباطی → شبکه‌های اجتماعی → فرم پیام.
 *
 * - همه‌ی بخش‌ها پدینگ چپ/راست یکسان دارن (PAGE_PADDING) و فاصله‌ی عنوان‌ها از بخش
 *   بالایی هم یکسانه (SECTION_SPACING).
 * - عنوان‌ها وسط‌چین با خط قرمز در دو طرف (SiteCenteredSectionTitle).
 * - همه‌ی آیکن‌ها از Remix Icon؛ آیکن شبکه‌ها لوگوی رسمی خودشون.
 */
private let STORE_LAT = 37.2867811
private let STORE_LNG = 49.5675744
private let STORE_MAP_URL = "https://nshn.ir/12_bWDFqeBdqCf"
private let APARAT_URL = "https://www.aparat.com/shkcctv"

private let PAGE_PADDING: CGFloat = 16
private let SECTION_SPACING: CGFloat = 28
private let CARD_RADIUS: CGFloat = 16

/// تصویر داخل باندل اپ (Resources/Images)
private func bundledImage(_ name: String) -> Image {
    Image(uiImage: UIImage(named: name) ?? UIImage())
}

struct ContactUsScreen: View {
    let onBack: () -> Void
    // فاز ۳۴ (اصلاحیه، کد ۴-و): با کلیک روی لوگوی هر برند در کاروسل، به صفحه‌ی همون برند می‌ره
    var onOpenBrand: (String) -> Void = { _ in }

    @Environment(\.shkColors) private var colors
    private let catalogRepository = CatalogRepository()
    private let contentRepository = ContentRepository()

    @State private var seals: [TrustSealDto] = []
    @State private var brands: [BrandListItemDto] = []
    @State private var social: SocialLinksResponse? = nil

    // دریافت داده‌های سرور صفحه؛ هم در ورود اول و هم با کشیدن صفحه به پایین صدا زده می‌شه
    // (در خطا، داده‌ی قبلی دست‌نخورده می‌مونه)
    private func loadData() async {
        if case .success(let data) = await catalogRepository.getTrustSeals() { seals = data }
        // شبکه‌های اجتماعی: دقیقاً همون‌هایی که سایدبار همبرگری نشون می‌ده (+ آپارات)
        if case .success(let data) = await catalogRepository.getSocialLinks() { social = data }
        // فاز ۳۴ (اصلاحیه، کد ۴-و): همه‌ی برندهای دارای لوگو (با حلقه‌ی بی‌نهایت)
        if case .success(let data) = await contentRepository.getBrandsList() {
            brands = data.filter { !($0.logo ?? "").isBlankShk }
        }
    }

    var body: some View {
        // کشیدن به پایین: بروزرسانی نشان‌های اعتماد، شبکه‌های اجتماعی و برندها
        // (فرم پیام دوباره بارگذاری نمی‌شه تا متن تایپ‌شده‌ی کاربر پاک نشه)
        ScrollView {
            VStack(spacing: 0) {
                ContactHeroImage(onBack: onBack)
                CompanyDescriptionSection()
                WhyUsSection()
                StatsSection()
                if !brands.isEmpty {
                    BrandsCarouselSection(brands: brands, onBrandClick: onOpenBrand)
                }
                AfterSalesSection()
                SalesRepsSection()
                BuyWithConfidenceSection(seals: seals, onSealClick: { seal in openLink(seal.verifyUrl) })
                InPersonPurchaseSection()
                MapAndRoutingSection()
                ContactDetailsSection()
                PageSection(title: "شبکه‌های اجتماعی") {
                    SocialChannelsRow(social: social, aparatUrl: APARAT_URL)
                }
                // فرم پیام (فرم داینامیک خودِ اسکریپت) داخل یک کادر
                PageSection(title: "پیام خود را برای ما ارسال کنید") {
                    PageCard {
                        // فاز ۳۴ (کد ۴): توضیحات HTML خودِ فرم در این صفحه نمایش داده نمی‌شه
                        DynamicFormBody(slug: "contact-us", showDescription: false)
                    }
                }
                Spacer().frame(height: 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .sitePullRefresh { await loadData() }
        .background(colors.background.ignoresSafeArea())
        .task { await loadData() }
    }
}


// ----------------------------------------------------------------------------------
// اجزای مشترک صفحه
// ----------------------------------------------------------------------------------

/** یک بخش صفحه: پدینگ چپ/راست یکسان + فاصله‌ی یکسان از بخش بالایی + عنوان دوطرفه */
private struct PageSection<Content: View>: View {
    let title: String?
    var topSpacing: CGFloat = SECTION_SPACING
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title { SiteCenteredSectionTitle(title: title).padding(.bottom, 14) }
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PAGE_PADDING)
        .padding(.top, topSpacing)
    }
}

/** کادر استاندارد صفحه (روشن: سفید / تاریک: #353542) */
private struct PageCard<Content: View>: View {
    var onClick: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.shkColors) private var colors

    var body: some View {
        let card = VStack(alignment: .leading, spacing: 0) { content() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CARD_RADIUS, style: .continuous).fill(colors.surface))
            .clipShape(RoundedRectangle(cornerRadius: CARD_RADIUS, style: .continuous))
        if let onClick {
            Button(action: onClick) { card.contentShape(Rectangle()) }.buttonStyle(.plain)
        } else {
            card
        }
    }
}

/** باکس آیکن قرمز کم‌رنگ */
private struct ContactIconBadge: View {
    let icon: String
    var size: CGFloat = 42
    var iconSize: CGFloat = 22
    var tint: Color? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        let t = tint ?? colors.primary
        RemixIcon(icon, tint: t, size: iconSize)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(t.opacity(0.1)))
    }
}

/** ردیف افقی: آیکن + عنوان بولد + توضیح (برای «چرا ما»، «خدمات پس از فروش» و «خرید حضوری») */
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    var trailingArrow: Bool = false
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            ContactIconBadge(icon: icon)
            Spacer().frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).shkFont(14, .bold).foregroundColor(colors.onSurface)
                Spacer().frame(height: 3)
                Text(description)
                    .shkFont(12, lineHeight: 20)
                    .foregroundColor(colors.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if trailingArrow {
                Spacer().frame(width: 6)
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
            }
        }
    }
}

private struct ContactDashedDivider: View {
    @Environment(\.shkIsDark) private var isDark
    var body: some View { DashedDivider(color: isDark ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider) }
}

// ----------------------------------------------------------------------------------
// بخش‌ها
// ----------------------------------------------------------------------------------

/** تصویر تمام‌عرض بالای صفحه + دکمه‌ی برگشت روی تصویر */
private struct ContactHeroImage: View {
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay(bundledImage("contact_hero.jpg").resizable().scaledToFill())
                .clipped()
                .accessibilityLabel("سیما حفاظ خزر")
            Button(action: onBack) {
                RemixIcon(RemixIcons.ArrowRightLine, contentDescription: "بازگشت", tint: .white, size: 22)
                    .frame(width: 38, height: 38)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.35)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CompanyDescriptionSection: View {
    @Environment(\.shkColors) private var colors
    var body: some View {
        PageSection(title: "درباره‌ی سیما حفاظ خزر", topSpacing: 24) {
            PageCard {
                JustifiedText(
                    text: "فروشگاه سیما حفاظ خزر با بیش از دو دهه تجربه‌ی حرفه‌ای در زمینه‌ی تامین، فروش، " +
                        "طراحی و راه‌اندازی سیستم‌های نظارت تصویری، حفاظت الکترونیکی و امنیت اماکن، یکی از " +
                        "فعالان شناخته‌شده‌ی این صنعت در استان گیلان است. دفتر و فروشگاه اصلی ما در شهر رشت " +
                        "قرار دارد و با تکیه بر تیمی متخصص در حوزه‌ی فناوری اطلاعات و مهندسی فروش، محصولات " +
                        "متنوعی از برندهای معتبر داخلی و بین‌المللی را با مشاوره‌ی تخصصی رایگان، ضمانت اصالت " +
                        "کالا و خدمات پس از فروش در اختیار مشتریان و همکاران خود در سراسر کشور قرار می‌دهیم.",
                    size: 13,
                    lineHeight: 24,
                    color: colors.onSurfaceVariant
                )
            }
        }
    }
}

/**
 * «چرا سیما حفاظ خزر؟» - باکس‌های تمام‌عرض افقی با آیکن مناسب و متن کامل.
 */
private struct WhyUsSection: View {
    var body: some View {
        let points: [(String, String, String)] = [
            (RemixIcons.StackLine, "تنوع بالای محصولات", "بیش از هزار کالای متنوع از معتبرترین برندهای حوزه‌ی امنیت و نظارت تصویری، یک‌جا در دسترس شما."),
            (RemixIcons.PriceTag3Line, "قیمت رقابتی", "قیمت‌گذاری مستقیم و رقابتی، بدون واسطه‌های اضافه."),
            (RemixIcons.ShieldCheckLine, "ضمانت اصالت و گارانتی", "همه‌ی محصولات اصلی و معتبرند و با گارانتی رسمی ارائه می‌شوند."),
            (RemixIcons.CustomerService2Line, "مشاوره‌ی تخصصی رایگان", "مشاوران مجرب ما در حوزه‌های نظارتی، امنیتی و خورشیدی، پیش از خرید رایگان راهنمایی‌تان می‌کنند."),
        ]
        PageSection(title: "چرا سیما حفاظ خزر؟") {
            VStack(spacing: 10) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                    PageCard { FeatureRow(icon: p.0, title: p.1, description: p.2) }
                }
            }
        }
    }
}

/** آمار و ارقام - دو ردیف دوستونه */
private struct StatsSection: View {
    @Environment(\.shkColors) private var colors
    var body: some View {
        let stats: [(String, String, String)] = [
            (RemixIcons.CheckboxCircleLine, "۱۳۰,۰۰۰+", "سفارش موفق"),
            (RemixIcons.Box3Line, "۱,۰۰۰+", "محصول متنوع"),
            (RemixIcons.AwardLine, "۶۰+", "برند معتبر"),
            (RemixIcons.TeamLine, "۹,۰۰۰+", "مشتری و همکار"),
        ]
        PageSection(title: nil, topSpacing: 12) {
            VStack(spacing: 10) {
                ForEach([0, 2], id: \.self) { start in
                    HStack(spacing: 10) {
                        ForEach(start..<(start + 2), id: \.self) { i in
                            let s = stats[i]
                            VStack(spacing: 0) {
                                RemixIcon(s.0, tint: colors.primary, size: 22)
                                Spacer().frame(height: 6)
                                Text(s.1).shkFont(20, .bold).foregroundColor(colors.primary)
                                Spacer().frame(height: 2)
                                Text(s.2).shkFont(12).foregroundColor(colors.onSurfaceVariant).multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: CARD_RADIUS, style: .continuous).fill(colors.surface))
                        }
                    }
                }
            }
        }
    }
}

/**
 * کاروسل برندها - همه‌ی برندها با حلقه‌ی بی‌نهایت؛ کلیک روی هر لوگو به صفحه‌ی همون برند می‌ره.
 */
private struct BrandsCarouselSection: View {
    let brands: [BrandListItemDto]
    let onBrandClick: (String) -> Void
    @State private var page: Int = -1

    var body: some View {
        let chunked: [[BrandListItemDto]] = stride(from: 0, to: brands.count, by: 4).map { Array(brands[$0..<min($0 + 4, brands.count)]) }
        if !chunked.isEmpty {
            let virtualPageCount = INFINITE_PAGE_COUNT
            let startPage = (virtualPageCount / 2) - (virtualPageCount / 2) % chunked.count
            PageSection(title: "برندهای همکار") {
                ShkPager(pageCount: virtualPageCount, currentPage: Binding(get: { page < 0 ? startPage : page }, set: { page = $0 })) { p in
                    let pageBrands = chunked[p % chunked.count]
                    HStack(spacing: 10) {
                        ForEach(pageBrands) { brand in
                            Button(action: { onBrandClick(brand.slug) }) {
                                Color.white
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(RemoteImage(brand.logo, contentDescription: brand.title, contentScale: .fit).padding(6))
                                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                        ForEach(0..<(4 - pageBrands.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }
}

private struct AfterSalesSection: View {
    var body: some View {
        PageSection(title: "خدمات پس از فروش") {
            PageCard {
                FeatureRow(
                    icon: RemixIcons.ToolsLine,
                    title: "همراه شما، حتی پس از خرید",
                    description: "از راهنمایی نصب و راه‌اندازی تا پیگیری گارانتی و خدمات فنی، از طریق شماره‌های تماس " +
                        "و شبکه‌های اجتماعی فروشگاه در دسترس هستیم."
                )
            }
        }
    }
}

private struct SalesRep {
    let name: String
    let role: String
    let phone: String
    let photo: String
    var baleUrl: String? = nil
    var rubikaUrl: String? = nil
    var whatsappUrl: String? = nil
    var telegramId: String? = nil
    var instagramId: String? = nil

    /** تعداد دکمه‌های پیام‌رسان این کارشناس */
    var channelCount: Int { [baleUrl, rubikaUrl, whatsappUrl, instagramId, telegramId].filter { $0 != nil }.count }
}

private struct SalesRepsSection: View {
    var body: some View {
        let reps: [SalesRep] = [
            SalesRep(
                name: "محمد مهدی عزتی",
                role: "مدیریت فروشگاه سیما حفاظ خزر - بیش از ۲۲ سال سابقه‌ی حرفه‌ای در تامین کالا، فروش، طراحی و راه‌اندازی سیستم‌های نظارتی و امنیت اماکن",
                phone: "09120398602",
                photo: "rep_mohammadmehdi.jpg",
                baleUrl: "https://web.bale.ai/chat?uid=1061321461",
                rubikaUrl: "https://web.rubika.ir/#c=u0Jnc403c78fc5dace7599ba8abb12b5",
                whatsappUrl: "http://wa.me/+989120398602",
                // تلگرام با لینک داخلی خودِ اپ تلگرام باز می‌شه (t.me از دسترس خارج شده)
                telegramId: "+989120398602"
            ),
            SalesRep(
                name: "مسیح بیابانی",
                role: "کارشناس فروش سیستم و تجهیزات امنیتی و حفاظتی، گیت‌های ضد سرقت فروشگاهی و پنل‌های دزدگیر - ارائه‌ی مشاوره‌ی تخصصی خرید تجهیزات",
                phone: "09115585589",
                photo: "rep_masih.jpg",
                baleUrl: "https://web.bale.ai/chat?uid=1733333305",
                whatsappUrl: "http://wa.me/+989115585589",
                telegramId: "+989115585589"
            ),
            SalesRep(
                name: "علیرضا کهن",
                role: "مدیر واحد IT و فروشگاه آنلاین سیما حفاظ خزر - بیش از ۱۴ سال سابقه‌ی فعال در فناوری اطلاعات، شبکه‌های رایانه‌ای و برنامه‌نویسی تحت وب",
                phone: "09354424162",
                photo: "rep_alireza.jpg",
                baleUrl: "https://web.bale.ai/@a_kohan",
                whatsappUrl: "http://wa.me/+989354424162",
                telegramId: "+989354424162",
                instagramId: "alirezafbk"
            ),
        ]
        let maxChannels = reps.map(\.channelCount).max() ?? 0
        PageSection(title: "کارشناسان فروش") {
            VStack(spacing: 12) {
                ForEach(Array(reps.enumerated()), id: \.offset) { _, rep in
                    SalesRepCard(rep: rep, maxChannels: maxChannels)
                }
            }
        }
    }
}

/** کارت هر کارشناس: عکس با حلقه‌ی قرمز، نام و سمت، خط‌چین، و دکمه‌های تماس */
private struct SalesRepCard: View {
    let rep: SalesRep
    let maxChannels: Int
    @Environment(\.shkColors) private var colors

    var body: some View {
        PageCard {
            HStack(spacing: 0) {
                bundledImage(rep.photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .padding(3)
                    .frame(width: 66, height: 66)
                    .overlay(Circle().strokeBorder(colors.primary, lineWidth: 2))
                    .accessibilityLabel(rep.name)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    Text(rep.name).shkFont(15, .bold).foregroundColor(colors.onSurface)
                    Spacer().frame(height: 4)
                    Text(rep.role)
                        .shkFont(12, lineHeight: 20)
                        .foregroundColor(colors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer().frame(height: 12)
            ContactDashedDivider()
            Spacer().frame(height: 12)
            HStack(spacing: 6) {
                // دکمه‌ی اصلی تماس تلفنی (قرص قرمز با شماره)
                Button(action: { openLink("tel:\(rep.phone)") }) {
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.PhoneFill, tint: .white, size: 16)
                        Spacer().frame(width: 5)
                        Text(rep.phone.toPersianDigits()).shkFont(12, .bold).foregroundColor(.white).lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.primary))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if let url = rep.baleUrl {
                    RepChannelButton(contentDescription: "بله", imageName: "ic_social_bale") { openLink(url) }
                }
                if let url = rep.rubikaUrl {
                    RepChannelButton(contentDescription: "روبیکا", imageName: "ic_social_rubika") { openLink(url) }
                }
                if let url = rep.whatsappUrl {
                    RepChannelButton(contentDescription: "واتساپ", remixIcon: RemixIcons.WhatsappFill, tint: WhatsappColor) { openLink(url) }
                }
                if let id = rep.instagramId {
                    RepChannelButton(contentDescription: "اینستاگرام", remixIcon: RemixIcons.InstagramFill, tint: InstagramColor) {
                        openLink(SocialLinkBuilder.instagramUrl(id))
                    }
                }
                if let id = rep.telegramId {
                    RepChannelButton(contentDescription: "تلگرام", remixIcon: RemixIcons.TelegramFill, tint: TelegramColor) {
                        SocialLinkBuilder.openTelegram(id)
                    }
                }
                // جای خالی به تعداد پیام‌رسان‌های کمتر، تا عرض دکمه‌ی تماس همه‌ی کارشناسان یکسان بمونه
                ForEach(0..<max(maxChannels - rep.channelCount, 0), id: \.self) { _ in
                    Color.clear.frame(width: 38, height: 38)
                }
            }
        }
    }
}

/** دکمه‌ی مربعیِ یک پیام‌رسان در کارت کارشناس (لوگوی رسمی) */
private struct RepChannelButton: View {
    let contentDescription: String
    var remixIcon: String? = nil
    var tint: Color? = nil
    var imageName: String? = nil
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            ZStack {
                if let remixIcon {
                    RemixIcon(remixIcon, contentDescription: contentDescription, tint: tint, size: 22)
                } else if let imageName {
                    bundledImage(imageName).resizable().scaledToFit().frame(width: 20, height: 20)
                        .accessibilityLabel(contentDescription)
                }
            }
            .frame(width: 38, height: 38)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/** با اطمینان خرید کنید + نمادها و مجوزها */
private struct BuyWithConfidenceSection: View {
    let seals: [TrustSealDto]
    let onSealClick: (TrustSealDto) -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        PageSection(title: "با اطمینان خرید کنید") {
            PageCard {
                FeatureRow(
                    icon: RemixIcons.VerifiedBadgeLine,
                    title: "نماد اعتماد و مجوزهای رسمی",
                    description: "فروشگاه سیما حفاظ خزر دارای نماد اعتماد الکترونیکی و مجوزهای رسمی فعالیت است."
                )
                if !seals.isEmpty {
                    Spacer().frame(height: 14)
                    HStack(spacing: 14) {
                        ForEach(Array(seals.enumerated()), id: \.offset) { _, seal in
                            Button(action: { onSealClick(seal) }) {
                                RemoteImage(seal.imageUrl, contentDescription: seal.label, contentScale: .fit)
                                    .frame(width: 58, height: 58)
                                    .frame(width: 76, height: 76)
                                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white))
                                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(colors.outlineVariant, lineWidth: 1))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct InPersonPurchaseSection: View {
    var body: some View {
        PageSection(title: "خرید حضوری") {
            PageCard(onClick: { openLink(STORE_MAP_URL) }) {
                FeatureRow(
                    icon: RemixIcons.Store2Line,
                    title: "از فروشگاه ما دیدن کنید",
                    description: "برای بازدید حضوری و مشاهده‌ی محصولات، روی این بخش بزنید تا مسیر روی نقشه باز شود.",
                    trailingArrow: true
                )
            }
        }
    }
}

private struct MapAndRoutingSection: View {
    @Environment(\.shkColors) private var colors

    var body: some View {
        PageSection(title: "موقعیت فروشگاه روی نقشه") {
            Button(action: { openLink(STORE_MAP_URL) }) {
                colors.surfaceVariant
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay(RemoteImage(neshanStaticMapUrl(STORE_LAT, STORE_LNG), contentDescription: "نقشه‌ی فروشگاه", contentScale: .crop))
                    .clipShape(RoundedRectangle(cornerRadius: CARD_RADIUS, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer().frame(height: 12)
            // دکمه‌های مسیریابی - همون لینک‌ها و رنگ‌های اختصاصی
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    RouteButton(label: "مسیریابی با نشان", color: Color(argb: 0xFFAF2E2E)) { openLink(STORE_MAP_URL) }
                    RouteButton(label: "مسیریابی با بلد", color: Color(argb: 0xFF303766)) { openLink("https://balad.ir/p/3lMyNmXLEvr2gr") }
                }
                HStack(spacing: 8) {
                    RouteButton(label: "مسیریابی با اسنپ", color: Color(argb: 0xFF388F38)) { openLink("https://tile.snappmaps.ir/#19.82/37.2867811/49.5675744") }
                    RouteButton(label: "مسیریابی با گوگل مپ", color: Color(argb: 0xFF1A4D19)) { openLink("https://maps.app.goo.gl/pjHHwoFCJibnUAce7") }
                }
            }
        }
    }
}

/** دکمه‌ی مسیریابی: کادر رنگی گوشه‌گرد، آیکن ناوبری داخل دایره‌ی سفیدِ نیمه‌شفاف + متن */
private struct RouteButton: View {
    let label: String
    let color: Color
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 0) {
                RemixIcon(RemixIcons.NavigationFill, tint: .white, size: 15)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.18)))
                Spacer().frame(width: 8)
                Text(label).shkFont(12, .bold).foregroundColor(.white).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/** راه‌های ارتباطی: هر مورد یک ردیف با آیکن، عنوان کوچک و مقدار؛ بین ردیف‌ها خط‌چین */
private struct ContactDetailsSection: View {
    var body: some View {
        PageSection(title: "راه‌های ارتباطی با ما") {
            PageCard {
                ContactRow(icon: RemixIcons.PhoneLine, caption: "تلفن فروشگاه", text: "01333234659".toPersianDigits()) {
                    openLink("tel:01333234659")
                }
                ContactDashedDivider()
                ContactRow(
                    icon: RemixIcons.MapPin2Line,
                    caption: "آدرس",
                    text: "گیلان، رشت، رشتیان، بلوار شمسی‌پور، ابتدای خیابان احمدیان، فروشگاه سیما حفاظ خزر",
                    onClick: nil
                )
                ContactDashedDivider()
                ContactRow(icon: RemixIcons.MailLine, caption: "ایمیل", text: "shkcctv@gmail.com") {
                    openLink("mailto:shkcctv@gmail.com")
                }
                ContactDashedDivider()
                ContactRow(icon: RemixIcons.GlobalLine, caption: "وب‌سایت", text: "shkala.com") {
                    openLink("https://shkala.com")
                }
            }
        }
    }
}

private struct ContactRow: View {
    let icon: String
    let caption: String
    let text: String
    let onClick: (() -> Void)?
    @Environment(\.shkColors) private var colors

    var body: some View {
        let row = HStack(spacing: 0) {
            ContactIconBadge(icon: icon, size: 38, iconSize: 19)
            Spacer().frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(caption).shkFont(11).foregroundColor(colors.onSurfaceVariant)
                Text(text)
                    .shkFont(13, .medium, lineHeight: 22)
                    .foregroundColor(colors.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if onClick != nil {
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        if let onClick {
            Button(action: onClick) { row.contentShape(Rectangle()) }.buttonStyle(.plain)
        } else {
            row
        }
    }
}
