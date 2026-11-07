import SwiftUI
import UIKit

// ===================================================================================
// حالت «در حال بروزرسانی / غیرفعال» - ترجمه‌ی MaintenanceGate.kt اپ اندروید: وقتی سایت از طریق
// اسکریپت (تنظیم maintenance پنل ادمین) غیرفعال بشه، اپ به‌جای محتوای اصلی یک صفحه‌ی
// «در حال بروزرسانی» نشون می‌ده؛ اگه سرور زمان پایان (maintenance_ends_at) بفرسته، شمارش معکوس
// (با اصلاح اختلاف ساعت گوشی از روی server_time) نمایش داده می‌شه.
// وضعیت هنگام باز شدن اپ، هر بار که اپ به جلو میاد و هر ۱۵ ثانیه (در حالت بروزرسانی هر ۳۰ ثانیه و
// درست بعد از رسیدن شمارش معکوس به صفر) بررسی می‌شه؛ پس اپ خودش از حالت بروزرسانی خارج می‌شه.
// ===================================================================================

// مقادیر پیش‌فرض راه‌های ارتباطی (وقتی سرور هنوز جواب نداده یا نسخه‌ی قدیمی API باشه)
private let DEFAULT_CONTACTS = AppContactsDto(
    mobile1: "09120398602",
    mobile2: "09115585589",
    landline: "01333234659",
    whatsappUrl: "http://wa.me/+989120398602",
    baleUrl: "https://web.bale.ai/chat?uid=1061321461"
)
private let DEFAULT_DESCRIPTION = "برای ارائه‌ی تجربه‌ای بهتر، فروشگاه سیما حفاظ خزر در حال بروزرسانی است و به‌زودی با امکانات تازه برمی‌گردیم. از شکیبایی شما سپاسگزاریم."

/// رنگ واتساپ (WhatsappColor اپ اندروید - ui/common/SocialLinks.kt)
let WhatsappColor = Color(argb: 0xFF1ABC9C)

/// اطلاعات صفحه‌ی بروزرسانی
struct MaintenanceInfo {
    var maintenance: Bool
    var title: String? = nil
    var description: String? = nil
    var contacts: AppContactsDto? = nil
    /// زمان پایان بروزرسانی (میلی‌ثانیه، به ساعت سرور)؛ null = بدون شمارش معکوس
    var endsAtMillis: Int64? = nil
    /// اختلاف ساعت سرور با گوشی (سرور منهای گوشی، میلی‌ثانیه)
    var clockOffsetMillis: Int64 = 0

    /// زمان باقی‌مانده تا پایان بروزرسانی (میلی‌ثانیه، با اصلاح اختلاف ساعت)؛ null = بدون زمان پایان
    func remainingMillis() -> Int64? {
        endsAtMillis.map { $0 - (nowMs() + clockOffsetMillis) }
    }
}

/// تبدیل زمان ISO8601 (مثل 2026-10-02T11:00:00Z) به میلی‌ثانیه؛ قالب نامعتبر = null
private func parseIsoUtcMillis(_ value: String?) -> Int64? {
    guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: value).map { Int64($0.timeIntervalSince1970 * 1000) }
}

/// فاصله‌ی بررسی بعدی وضعیت: حالت عادی ۱۵ ثانیه؛ در حالت بروزرسانی هر ۳۰ ثانیه و اگه شمارش معکوس
/// زودتر تموم بشه، کمی بعد از صفر شدنش
private let NORMAL_STATUS_CHECK_MS: Int64 = 15_000

private func nextStatusCheckDelay(_ info: MaintenanceInfo) -> Int64 {
    if !info.maintenance { return NORMAL_STATUS_CHECK_MS }
    guard let remaining = info.remainingMillis() else { return 30_000 }
    if remaining < -5_000 { return 30_000 }
    return min(max(remaining + 1_500, 2_000), 30_000)
}

/// نتیجه‌ی بررسی وضعیت در لود اولیه (اسپلش) - منبع وضعیت اولیه‌ی MaintenanceGate
enum MaintenanceStatusCache {
    private(set) static var info = MaintenanceInfo(maintenance: false)
    static var maintenance: Bool { info.maintenance }

    static func prime(_ status: MaintenanceInfo?) {
        guard let status else { return }
        info = status
    }
}

/// وضعیت maintenance سایت از API؛ اگه اتصال برقرار نشه null برمی‌گرده
/// (قطعی اینترنت ≠ بروزرسانی سایت). پاسخ 503 یعنی سایت با artisan down کاملاً خاموشه.
func fetchMaintenanceStatus() async -> MaintenanceInfo? {
    // شناسه‌ی نصب + نسخه: سرور با همین پرسش‌های دوره‌ای، کاربران آنلاین اپ رو در پنل نشون می‌ده
    let installId = AppMetaPreferenceManager.getOrCreateInstallId()
    guard let response = try? await ApiService.getAppStatus(installId: installId, appVersion: currentAppVersionName()) else {
        return nil
    }
    if response.isSuccessful, let body = response.body {
        // پاسخ کامل (شامل popup و announcement) برای بقیه‌ی بخش‌های اپ
        AppStatusCache.shared.update(body)
        let serverNow = parseIsoUtcMillis(body.serverTime)
        return MaintenanceInfo(
            maintenance: body.maintenance,
            title: body.maintenanceTitle,
            description: body.maintenanceDescription,
            contacts: body.contacts,
            endsAtMillis: parseIsoUtcMillis(body.maintenanceEndsAt),
            clockOffsetMillis: serverNow.map { $0 - nowMs() } ?? 0
        )
    }
    if response.code == 503 { return MaintenanceInfo(maintenance: true) }
    return nil
}

struct MaintenanceGate<Content: View>: View {
    @ViewBuilder let content: () -> Content

    // وضعیت اولیه همونیه که موقع اسپلش (StartupViewModel) گرفته شده؛ پس از همون فریم اول
    // درسته و صفحه‌ی اپ قبل از صفحه‌ی بروزرسانی نمایش داده نمی‌شه
    @State private var info = MaintenanceStatusCache.info
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if info.maintenance {
                MaintenanceScreen(
                    title: info.title,
                    description: info.description.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? DEFAULT_DESCRIPTION,
                    contacts: info.contacts ?? DEFAULT_CONTACTS,
                    endsAtMillis: info.endsAtMillis,
                    clockOffsetMillis: info.clockOffsetMillis
                )
            } else {
                content()
            }
        }
        // معادل repeatOnLifecycle(STARTED): فقط وقتی اپ جلوئه
        .task(id: scenePhase == .active) {
            guard scenePhase == .active, !ScreenshotMode.isActive else { return }
            while !Task.isCancelled {
                let result = await fetchMaintenanceStatus()
                if Task.isCancelled { return }
                // اگه اتصال برقرار نشد، وضعیت قبلی حفظ می‌شه (قطعی اینترنت ≠ بروزرسانی سایت)
                if let result {
                    // اگه 503 بود و اطلاعات تماس نداشت، اطلاعات قبلی (در صورت وجود) حفظ می‌شه
                    if result.contacts == nil && result.description == nil {
                        info.maintenance = result.maintenance
                        info.title = result.title ?? info.title
                    } else {
                        info = result
                    }
                }
                try? await Task.sleep(nanoseconds: UInt64(nextStatusCheckDelay(info)) * 1_000_000)
            }
        }
    }
}

struct MaintenanceScreen: View {
    let title: String?
    let description: String
    let contacts: AppContactsDto
    var endsAtMillis: Int64? = nil
    var clockOffsetMillis: Int64 = 0

    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark
    @State private var startDate = Date()

    var body: some View {
        let primary = colors.primary
        ZStack {
            // تم تاریک: پس‌زمینه‌ی ساده (بدون گرادیان)؛ تم روشن: گرادیان ملایم قرمز
            Group {
                if isDark {
                    colors.background
                } else {
                    LinearGradient(colors: [primary.opacity(0.10), colors.background, colors.background], startPoint: .top, endPoint: .bottom)
                }
            }
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // آیکن انیمیشنی: چرخ‌دنده‌ی چرخان داخل دایره‌ی تپنده
                    TimelineView(.animation) { ctx in
                        let t = ctx.date.timeIntervalSince(startDate) * 1000
                        // چرخش ۶۰۰۰ میلی‌ثانیه‌ای خطی
                        let rotation = (t.truncatingRemainder(dividingBy: 6000)) / 6000 * 360
                        // تپش 0.9 ↔ 1.08 با tween(1100) رفت‌وبرگشتی (FastOutSlowIn)
                        let cycle = t.truncatingRemainder(dividingBy: 2200) / 1100
                        let phase = cycle <= 1 ? cycle : 2 - cycle
                        let pulse = 0.9 + 0.18 * CubicBezierEasing(0.4, 0, 0.2, 1).transform(phase)
                        ZStack {
                            Circle().fill(primary.opacity(0.08)).frame(width: 104, height: 104).scaleEffect(pulse)
                            Circle().fill(primary.opacity(0.14)).frame(width: 76, height: 76)
                            RemixIcon(RemixIcons.Settings3Line, tint: primary, size: 40)
                                .rotationEffect(.degrees(rotation))
                        }
                        .frame(width: 104, height: 104)
                    }
                    Spacer().frame(height: 16)
                    Text(title.flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 } ?? "در حال بروزرسانی هستیم")
                        .shkFont(20, .bold, lineHeight: 32)
                        .foregroundColor(colors.onBackground)
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 10)
                    Text(description)
                        .shkFont(13, lineHeight: 25)
                        .foregroundColor(colors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer().frame(height: 18)
                    if let endsAtMillis {
                        // شمارش معکوس تا پایان بروزرسانی
                        MaintenanceCountdown(endsAtMillis: endsAtMillis, clockOffsetMillis: clockOffsetMillis)
                    } else {
                        // سه نقطه‌ی متحرک
                        TimelineView(.animation) { ctx in
                            let t = ctx.date.timeIntervalSince(startDate) * 1000
                            let dotPhase = Int(t.truncatingRemainder(dividingBy: 1500) / 500)
                            HStack(spacing: 8) {
                                ForEach(0..<3, id: \.self) { index in
                                    let active = dotPhase == index
                                    Circle()
                                        .fill(active ? primary : primary.opacity(0.25))
                                        .frame(width: active ? 12 : 9, height: active ? 12 : 9)
                                }
                            }
                        }
                    }
                    Spacer().frame(height: 20)
                    // راه‌های ثبت سفارش در این مدت
                    contactBox
                    Spacer().frame(height: 12)
                    // دکمه‌ی مشاوره‌ی آنلاین (گفتینو) - وسط، زیر باکس تماس؛ هر ۵ ثانیه یک پالس
                    GoftinoPulseButton(onClick: { GoftinoViewModel.shared.isChatVisible = true })
                    Spacer().frame(height: 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }

    private var contactBox: some View {
        let whatsapp = contacts.whatsappUrl.flatMap { $0.isBlankShk ? nil : $0 }
        let bale = contacts.baleUrl.flatMap { $0.isBlankShk ? nil : $0 }
        // تماس تلفنی: شماره‌های موبایل (با بج ۱ و ۲) و تلفن ثابت - فقط شماره‌های تنظیم‌شده
        var phones: [(icon: String, number: String, badge: String?)] = []
        if let m = contacts.mobile1, !m.isBlankShk { phones.append((RemixIcons.SmartphoneLine, m, "۱")) }
        if let m = contacts.mobile2, !m.isBlankShk { phones.append((RemixIcons.SmartphoneLine, m, "۲")) }
        if let l = contacts.landline, !l.isBlankShk { phones.append((RemixIcons.PhoneLine, l, nil)) }

        return VStack(spacing: 0) {
            Text("در این مدت می‌توانید سفارش خود را از طریق راه‌های ارتباطی زیر ثبت کنید")
                .shkFont(13, .bold, lineHeight: 23)
                .foregroundColor(colors.onSurface)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if whatsapp != nil || bale != nil {
                Spacer().frame(height: 14)
                HStack(spacing: 10) {
                    if let whatsapp {
                        ContactChannelButton(label: "واتساپ", onClick: { openLink(whatsapp) }) {
                            RemixIcon(RemixIcons.WhatsappFill, tint: WhatsappColor, size: 22)
                        }
                    }
                    if let bale {
                        ContactChannelButton(label: "بله", onClick: { openLink(bale) }) {
                            Image(uiImage: UIImage(named: "ic_social_bale") ?? UIImage()).resizable().scaledToFit().frame(width: 20, height: 20)
                        }
                    }
                }
            }
            if !phones.isEmpty {
                Spacer().frame(height: 10)
                HStack(spacing: 10) {
                    ForEach(Array(phones.enumerated()), id: \.offset) { _, p in
                        CallButton(icon: p.icon, number: p.number, badge: p.badge)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(colors.surface))
    }
}

extension String {
    /// معادل isBlank() کاتلین
    var isBlankShk: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// شمارش معکوس تا پایان بروزرسانی: روز / ساعت / دقیقه / ثانیه با ارقام فارسی (ساعت سرور =
/// ساعت گوشی + [clockOffsetMillis]). با رسیدن به صفر «به‌زودی برمی‌گردیم…» نمایش داده می‌شه.
private struct MaintenanceCountdown: View {
    let endsAtMillis: Int64
    let clockOffsetMillis: Int64

    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        TimelineView(.periodic(from: Date(), by: 0.25)) { _ in
            let remaining = endsAtMillis - (nowMs() + clockOffsetMillis)
            SiteCard(contentPadding: .hv(12, 14), radius: 18) {
                if remaining > 0 {
                    let totalSeconds = remaining / 1_000
                    let parts: [(Int64, String)] = [
                        (totalSeconds / 86_400, "روز"),
                        ((totalSeconds % 86_400) / 3_600, "ساعت"),
                        ((totalSeconds % 3_600) / 60, "دقیقه"),
                        (totalSeconds % 60, "ثانیه"),
                    ]
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.TimerLine, tint: primary, size: 18)
                        Spacer().frame(width: 6)
                        Text("زمان باقی‌مانده تا بازگشت")
                            .shkFont(12, .medium)
                            .foregroundColor(colors.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer().frame(height: 10)
                    // در چیدمان راست‌به‌چپ، روز سمت راست و ثانیه سمت چپ قرار می‌گیره (مثل صفحه‌ی سایت)
                    HStack(spacing: 8) {
                        ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                            VStack(spacing: 0) {
                                Text(String(format: "%02lld", part.0).toPersianDigits())
                                    .shkFont(22, .bold, lineHeight: 28)
                                    .foregroundColor(primary)
                                    .lineLimit(1)
                                Text(part.1)
                                    .shkFont(11, lineHeight: 16)
                                    .foregroundColor(colors.onSurfaceVariant)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant))
                        }
                    }
                } else {
                    Text("به‌زودی برمی‌گردیم…")
                        .shkFont(14, .bold)
                        .foregroundColor(primary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct ContactChannelButton<Icon: View>: View {
    let label: String
    let onClick: () -> Void
    @ViewBuilder let icon: () -> Icon

    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 0) {
                icon()
                Spacer().frame(width: 8)
                Text(label)
                    .shkFont(13, .bold)
                    .foregroundColor(colors.onSurface)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(SitePressStyle())
    }
}

/// دکمه‌ی تماس: آیکن (با بج شماره در صورت وجود) + شماره؛ با لمس، شماره‌گیر گوشی باز می‌شه
private struct CallButton: View {
    let icon: String
    let number: String
    let badge: String?

    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        Button(action: { openLink("tel:\(number)") }) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    RemixIcon(icon, tint: primary, size: 22)
                    if let badge {
                        Text(badge)
                            .shkFont(9, .bold, lineHeight: 10)
                            .foregroundColor(.white)
                            .frame(width: 15, height: 15)
                            .background(Circle().fill(primary))
                            .offset(x: -7, y: -5)
                    }
                }
                Spacer().frame(height: 5)
                Text(number.toPersianDigits())
                    .shkFont(11, .medium, lineHeight: 14)
                    .foregroundColor(colors.onSurface)
                    .lineLimit(1)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(SitePressStyle())
    }
}

/// دکمه‌ی گفتینو با پالس دوره‌ای (هر ۵ ثانیه یک موج + تپش کوچک دکمه)
private struct GoftinoPulseButton: View {
    let onClick: () -> Void

    @Environment(\.shkColors) private var colors
    @State private var start = Date()

    var body: some View {
        let primary = colors.primary
        VStack(spacing: 0) {
            TimelineView(.animation) { ctx in
                // چرخه‌ی ۶ ثانیه‌ای: ۵ ثانیه مکث، ۱ ثانیه پالس خطی
                let t = ctx.date.timeIntervalSince(start).truncatingRemainder(dividingBy: 6)
                let p = t < 5 ? 0 : CGFloat(t - 5)
                // تپش دکمه: در نیمه‌ی اول بزرگ و در نیمه‌ی دوم به اندازه‌ی عادی برمی‌گرده
                let buttonScale = 1 + 0.10 * sin(p * .pi)
                ZStack {
                    if p > 0 {
                        // موج پالس که بزرگ و محو می‌شه
                        Circle()
                            .fill(primary)
                            .frame(width: 60, height: 60)
                            .scaleEffect(1 + 0.6 * p)
                            .opacity(Double((1 - p) * 0.45))
                    }
                    Button(action: onClick) {
                        RemixIcon(RemixIcons.CustomerService2Fill, contentDescription: "مشاوره‌ی آنلاین", tint: .white, size: 28)
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(primary))
                            .shadow(color: primary.opacity(0.5), radius: 6, x: 0, y: 3)
                            .contentShape(Circle())
                    }
                    .buttonStyle(SitePressStyle())
                    .scaleEffect(buttonScale)
                }
                .frame(width: 96, height: 96)
            }
            Text("مشاوره‌ی آنلاین")
                .shkFont(12, .bold)
                .foregroundColor(colors.onSurface)
        }
    }
}

/// باز کردن لینک (واتساپ، بله) یا شماره‌گیر گوشی (tel:)
func openLink(_ url: String) {
    guard let u = URL(string: url) else { return }
    UIApplication.shared.open(u)
}
