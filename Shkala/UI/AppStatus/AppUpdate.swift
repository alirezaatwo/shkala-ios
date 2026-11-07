import SwiftUI
import UIKit

// ===================================================================================
// معادل ui/appstatus/AppUpdate.kt - بروزرسانی داخل اپ:
//  - آخرین نسخه از API (api/v2/app/latest-version با platform=ios) خونده می‌شه (نسخه، امکانات جدید و راه‌های
//    دریافت: سیب‌اپ، سیب من، سیبچه).
//  - اگه نسخه‌ی سرور از نسخه‌ی نصب‌شده بالاتر بود: مودال بروزرسانی یک‌بار در هر اجرای اپ خودکار باز می‌شه
//    (StartupDialogsHost) و در پایین سایدبار هم «بروز رسانی موجود است» با بج قرمز نمایش داده می‌شه؛ با لمسش
//    همین مودال باز می‌شه.
// تفاوت‌های اجباری iOS:
//  - دانلود مستقیم فایل نصب (APK) در iOS وجود نداره؛ راه‌های دریافت فقط صفحه‌ی اپ در فروشگاه‌های iOS است
//    (همه‌ی راه‌های فعال؛ منبع نصب در iOS قابل تشخیص نیست).
//  - نشان‌های تصویری فروشگاه‌ها (بازار/مایکت) در حالت اجباری: برای فروشگاه‌های iOS نشانی در سایت نیست، پس
//    همان دکمه‌های قرمز/کادردار حالت عادی نمایش داده می‌شن.
//  - «خروج از اپ»: iOS بستن برنامه توسط خودش رو مجاز نمی‌دونه؛ اپ به صفحه‌ی اصلی گوشی می‌ره (پس‌زمینه).
// ===================================================================================

/// مقایسه‌ی عددیِ دو نسخه مثل 1.2.10 و 1.2.9 (بخش‌های غیرعددی نادیده گرفته می‌شن)
func compareAppVersions(_ a: String, _ b: String) -> Int {
    func parts(_ v: String) -> [Int] {
        var s = v.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        return s.split(whereSeparator: { $0 == "." || $0 == "-" || $0 == "_" })
            .map { Int(String($0.filter { $0.isASCII && $0.isNumber })) ?? 0 }
    }
    let pa = parts(a), pb = parts(b)
    for i in 0..<max(pa.count, pb.count) {
        let x = i < pa.count ? pa[i] : 0
        let y = i < pb.count ? pb[i] : 0
        if x != y { return x < y ? -1 : 1 }
    }
    return 0
}

/// راه‌های دریافت نسخه‌ی جدید iOS
enum UpdateChannel { case Sibapp, Sibeman, Sibche }

struct UpdateOption: Hashable {
    let channel: UpdateChannel
    let url: String
}

/// دکمه‌هایی که باید نمایش داده بشن: فقط راه‌های enabled با url
func updateOptionsFor(_ update: AppLatestVersionResponse) -> [UpdateOption] {
    var all: [UpdateOption] = []
    if let url = update.stores?.sibapp?.usableUrl { all.append(UpdateOption(channel: .Sibapp, url: url)) }
    if let url = update.stores?.sibeman?.usableUrl { all.append(UpdateOption(channel: .Sibeman, url: url)) }
    if let url = update.stores?.sibche?.usableUrl { all.append(UpdateOption(channel: .Sibche, url: url)) }
    return all
}

/// نمونه‌ی مشترک در کل اپ (یک بار بررسی در هر اجرای اپ) - معادل rememberSharedAppUpdateViewModel
@MainActor
final class AppUpdateViewModel: ObservableObject {
    static let shared = AppUpdateViewModel()

    /// اطلاعات نسخه‌ی جدیدتر (اگه وجود داشته باشه)
    @Published private(set) var availableUpdate: AppLatestVersionResponse? = nil
    @Published var showDialog = false
    @Published private(set) var errorMessage: String? = nil
    /// بروزرسانی اجباری: مودال بسته نمی‌شه و کار با اپ تا نصب نسخه‌ی جدید ممکن نیست
    @Published private(set) var isForced = false
    /// در حال استعلام نسخه از سرور (برای وقتی کاربر روی برچسب نسخه می‌زنه)
    @Published private(set) var isChecking = false

    private var checked = false
    private var autoShown = false

    func checkForUpdate(force: Bool = false) {
        if checked && !force { return }
        checked = true
        if ScreenshotMode.isActive { return }
        Task {
            isChecking = true
            let latest = (try? await ApiService.getAppLatestVersion()).flatMap { $0.isSuccessful ? $0.body : nil }
            let current = currentAppVersionName()
            if let latest, latest.available, let remote = latest.versionName, !remote.isBlankShk,
               !updateOptionsFor(latest).isEmpty, compareAppVersions(remote, current) > 0 {
                availableUpdate = latest
            } else {
                availableUpdate = nil
            }
            isForced = availableUpdate.map { update in
                let minVersion = update.minVersion.flatMap { $0.isBlankShk ? nil : $0 } ?? (update.versionName ?? "")
                return update.forceUpdate == true && compareAppVersions(current, minVersion) < 0
            } ?? false
            isChecking = false
        }
    }

    /// فقط عکس‌برداری CI: داده‌ی نمونه (سه فروشگاه iOS)
    func showScreenshotPreview(forced: Bool) {
        var update = AppLatestVersionResponse()
        update.available = true
        update.versionName = "3.1"
        update.releaseNotes = ["نمایش اعلان‌های فروشگاه روی آیفون", "پنجره‌ی بروزرسانی با لینک فروشگاه‌های iOS", "رفع چند اشکال جزئی"]
        var stores = AppStoresDto()
        stores.sibapp = AppStoreLinkDto(enabled: true, url: "https://sibapp.com/")
        stores.sibeman = AppStoreLinkDto(enabled: true, url: "https://sibeman.com/")
        stores.sibche = AppStoreLinkDto(enabled: true, url: "https://sibche.com/")
        update.stores = stores
        availableUpdate = update
        isForced = forced
        checked = true
        showDialog = true
    }

    /// لمس برچسب نسخه وقتی بروزرسانی‌ای شناسایی نشده: مودال باز می‌شه و یک بار دیگه از سرور استعلام می‌گیریم
    func openVersionInfo() {
        showDialog = true
        checkForUpdate(force: true)
    }

    /// باز شدن خودکار مودال: فقط یک‌بار در هر اجرای اپ و فقط وقتی نسخه‌ی جدید هست
    func autoOpenIfNeeded() {
        if availableUpdate == nil { return }
        // بروزرسانی اجباری: همیشه باز (نه فقط یک‌بار در هر اجرا)
        if isForced {
            showDialog = true
            return
        }
        if autoShown { return }
        autoShown = true
        showDialog = true
    }

    func closeDialog() {
        if isForced { return }
        showDialog = false
    }

    /// صفحه‌ی اپ در فروشگاه (اپ فروشگاه اگه نصب باشه لینک رو می‌گیره، وگرنه Safari)
    func openStore(_ url: String) {
        errorMessage = nil
        guard let target = URL(string: url) else {
            errorMessage = "باز کردن فروشگاه ممکن نشد."
            return
        }
        UIApplication.shared.open(target) { [weak self] opened in
            Task { @MainActor in
                if opened { self?.closeDialog() } else { self?.errorMessage = "باز کردن فروشگاه ممکن نشد." }
            }
        }
    }
}

/**
 * مودال بروزرسانی: نسخه‌ی فعلی و جدید، امکانات جدید و دکمه‌های دریافت (سیب‌اپ / سیب من / سیبچه).
 * اگه نسخه‌ی جدیدی نباشه، پیام «اپ شما به‌روز است». فقط یک‌جا (StartupDialogsHost) رندر می‌شه؛ سایدبار فقط
 * showDialog / openVersionInfo رو صدا می‌زنه.
 */
struct AppUpdateDialog: View {
    @ObservedObject var viewModel: AppUpdateViewModel
    @Environment(\.shkColors) private var colors

    var body: some View {
        let currentVersion = currentAppVersionName()
        if let update = viewModel.availableUpdate {
            updateContent(update, currentVersion: currentVersion)
        } else {
            // نسخه‌ی جدیدی نیست: اطلاع به کاربر که از آخرین نسخه استفاده می‌کنه
            SiteDialogContent(
                title: viewModel.isChecking ? "در حال بررسی نسخه‌ی جدید..." : "اپ شما به‌روز است",
                icon: viewModel.isChecking ? RemixIcons.DownloadCloud2Line : RemixIcons.CheckboxCircleLine,
                iconTint: viewModel.isChecking ? colors.primary : SiteStatusColors.Success,
                message: viewModel.isChecking
                    ? "لطفاً چند لحظه صبر کنید."
                    : "شما در حال حاضر از آخرین نسخه‌ی موجود (نسخه \(currentVersion.toPersianDigits())) استفاده می‌کنید.",
                confirmText: "متوجه شدم",
                onConfirm: { viewModel.closeDialog() }
            )
        }
    }

    private func label(_ channel: UpdateChannel) -> String {
        switch channel {
        case .Sibapp: return "دریافت از سیب‌اپ"
        case .Sibeman: return "دریافت از سیب من"
        case .Sibche: return "دریافت از سیبچه"
        }
    }

    @ViewBuilder
    private func updateContent(_ update: AppLatestVersionResponse, currentVersion: String) -> some View {
        let forced = viewModel.isForced
        let options = updateOptionsFor(update)
        SiteDialogContent(
            title: forced ? "بروزرسانی اجباری" : "نسخه‌ی جدید اپ آماده است",
            icon: forced ? RemixIcons.ErrorWarningLine : RemixIcons.DownloadCloud2Line,
            message: forced
                ? "این نسخه از اپ دیگر پشتیبانی نمی‌شود. برای ادامه‌ی استفاده، لطفاً نسخه‌ی جدید را از یکی از راه‌های زیر نصب کنید."
                : nil
        ) {
            // نسخه‌ی فعلی و نسخه‌ی جدید در دو خط
            VStack(spacing: 8) {
                VersionRow(label: "نسخه‌ی فعلی", version: currentVersion, highlight: false)
                VersionRow(label: "نسخه‌ی جدید", version: update.versionName ?? "", highlight: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(colors.surfaceVariant))

            // امکانات جدید: از release_notes (هر خط یک مورد)؛ اگه نبود، متن notes
            let notesLines = (update.releaseNotes ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let notesText = update.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !notesLines.isEmpty || !notesText.isEmpty {
                Spacer().frame(height: 14)
                Text("امکانات جدید")
                    .shkFont(13, .bold)
                    .foregroundColor(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(height: 6)
                if !notesLines.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(Array(notesLines.enumerated()), id: \.offset) { _, line in ReleaseNoteBullet(text: line) }
                    }
                } else {
                    Text(notesText)
                        .shkFont(12, lineHeight: 21)
                        .foregroundColor(colors.onSurfaceVariant)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let message = viewModel.errorMessage {
                Spacer().frame(height: 10)
                Text(message)
                    .shkFont(12, lineHeight: 20)
                    .foregroundColor(colors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // دکمه‌ها (هر کدوم تمام‌عرض، زیر هم)
            Spacer().frame(height: 18)
            VStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    if index == 0 {
                        SitePrimaryButton(text: label(option.channel), onClick: { viewModel.openStore(option.url) },
                                          icon: RemixIcons.Store2Line, height: 46, fillWidth: true)
                    } else {
                        SiteSecondaryButton(text: label(option.channel), onClick: { viewModel.openStore(option.url) },
                                            icon: RemixIcons.Store2Line, height: 46, fillWidth: true)
                    }
                }
                if forced {
                    // بروزرسانی اجباری: به‌جای «بعداً» فقط خروج از اپ (iOS: رفتن به صفحه‌ی اصلی گوشی)
                    SiteSecondaryButton(
                        text: "خروج از اپ",
                        onClick: { UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil) },
                        icon: RemixIcons.LogoutBoxRLine,
                        color: colors.onSurfaceVariant,
                        height: 46,
                        fillWidth: true
                    )
                } else {
                    SiteSecondaryButton(text: "بعداً", onClick: { viewModel.closeDialog() }, color: colors.onSurfaceVariant,
                                        height: 46, fillWidth: true)
                }
            }
        }
    }
}

private struct ReleaseNoteBullet: View {
    let text: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Circle().fill(colors.primary).frame(width: 6, height: 6).padding(.top, 8)
            Spacer().frame(width: 8)
            Text(text)
                .shkFont(12, lineHeight: 21)
                .foregroundColor(colors.onSurfaceVariant)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct VersionRow: View {
    let label: String
    let version: String
    let highlight: Bool
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(highlight ? RemixIcons.ArrowUpCircleLine : RemixIcons.SmartphoneLine,
                      tint: highlight ? colors.primary : colors.onSurfaceVariant, size: 18)
            Spacer().frame(width: 8)
            Text(label).shkFont(13).foregroundColor(colors.onSurfaceVariant).frame(maxWidth: .infinity, alignment: .leading)
            Text(version.toPersianDigits())
                .shkFont(14, .bold)
                .foregroundColor(highlight ? colors.primary : colors.onSurface)
        }
    }
}
