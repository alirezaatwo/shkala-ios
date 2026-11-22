import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// ===================================================================================
// معادل ui/partner/PartnerRequestScreen.kt
// تفاوت iOS: انتخاب فایل اندروید (OpenDocument) در iOS دو راه دارد: «گالری عکس» (PhotosPicker)
// و «فایل‌ها» (fileImporter، برای PDF یا عکس ذخیره‌شده در Files).
// ===================================================================================

/** مراحل «همکار شوید» - همان ترتیب سایت */
private enum PartnerStep: CaseIterable {
    case ACCOUNT, DOCUMENTS, INSTAGRAM, BALE, SUBMIT

    var title: String {
        switch self {
        case .ACCOUNT: return "اطلاعات حساب"
        case .DOCUMENTS: return "بارگذاری مدارک"
        case .INSTAGRAM: return "دنبال کردن اینستاگرام"
        case .BALE: return "عضویت در کانال بله"
        case .SUBMIT: return "ارسال درخواست"
        }
    }

    var hint: String {
        switch self {
        case .ACCOUNT: return "نام و نام خانوادگی، شماره‌ی تماس و آدرس"
        case .DOCUMENTS: return "کارت ملی، جواز کسب، کارت ویزیت و عکس فروشگاه"
        case .INSTAGRAM: return "اسکرین‌شات دنبال کردن پیج ما"
        case .BALE: return "عضویت در کانال و بررسی در لحظه"
        case .SUBMIT: return "ارسال برای بررسی مدیر"
        }
    }
}

private let SuccessGreen = Color(argb: 0xFF2E7D32)

private func documentLabel(_ kind: String) -> String {
    switch kind {
    case "national_card": return "کارت ملی (فقط رو)"
    case "license": return "جواز (پروانه) کسب فروشگاه"
    case "business_card": return "کارت ویزیت فروشگاه"
    case "storefront": return "عکس تابلو (سردر) یا ویترین فروشگاه"
    case "instagram": return "اسکرین‌شات دنبال کردن پیج اینستاگرام"
    default: return kind
    }
}

/**
 * «همکار شوید»: مراحل جدا و ترتیبی (مثل پنل کاربر سایت). وقتی کاربر همکار باشد، صفحه‌ی «پورسانت همکاری» باز می‌شود.
 */
struct PartnerRequestScreen: View {
    let onBack: () -> Void
    let onOpenCommissions: () -> Void
    let onEditProfile: () -> Void
    let onAddresses: () -> Void

    @Environment(\.shkColors) private var colors
    private let repository = PartnerRepository()

    @State private var state: PartnerStateDto? = nil
    @State private var loading = true
    @State private var error: String? = nil
    @State private var openStep: PartnerStep? = nil
    @State private var uploadingKind: String? = nil
    @State private var pendingDoc: PartnerDocumentDto? = nil
    @State private var baleChecking = false
    @State private var submitting = false

    @State private var showSourceDialog = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var pickerItem: PhotosPickerItem? = nil

    private func stepDone(_ step: PartnerStep, _ s: PartnerStateDto) -> Bool {
        switch step {
        case .ACCOUNT: return s.steps?.account?.ok == true
        case .DOCUMENTS: return s.steps?.documents?.ok == true
        case .INSTAGRAM: return s.steps?.instagram?.ok == true
        case .BALE: return s.steps?.bale?.ok == true
        case .SUBMIT: return s.state == "submitted"
        }
    }

    private func apply(_ outcome: PartnerOutcome, toast: Bool = true) {
        if let fresh = outcome.state {
            state = fresh
            if fresh.state == "partner" || fresh.state == "suspended" { onOpenCommissions() }
        }
        if toast, let message = outcome.message, !message.isBlankShk { ShkToast.shared.show(message, long: true) }
    }

    private func load(showLoading: Bool) async {
        if showLoading { loading = true }
        switch await repository.status() {
        case .success(let data):
            error = nil
            apply(data, toast: false)
            if let s = data.state, openStep == nil {
                openStep = PartnerStep.allCases.first { !stepDone($0, s) } ?? .SUBMIT
            }
        case .error(let message):
            if state == nil { error = message } else { ShkToast.shared.show(message) }
        }
        loading = false
    }

    private func pick(_ doc: PartnerDocumentDto) {
        pendingDoc = doc
        showSourceDialog = true
    }

    private func upload(_ file: PartnerPickedFile) {
        guard let kind = pendingDoc?.kind else { return }
        pendingDoc = nil
        uploadingKind = kind
        Task {
            switch await repository.upload(kind: kind, file: file) {
            case .success(let data): apply(data)
            case .error(let message): ShkToast.shared.show(message, long: true)
            }
            uploadingKind = nil
        }
    }

    private func openUrl(_ url: String) {
        guard let u = URL(string: url) else { return }
        UIApplication.shared.open(u) { opened in
            if !opened { ShkToast.shared.show("برنامه‌ای برای باز کردن این لینک پیدا نشد.") }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "همکار شوید", onBack: onBack)
            Group {
                if loading && state == nil {
                    SiteLoading(message: "در حال دریافت...", icon: RemixIcons.TeamLine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let s = state {
                    if !s.ready {
                        Group {
                            if s.enabled == false {
                                SiteEmptyState(icon: RemixIcons.TeamLine, title: "ثبت درخواست همکاری فعلاً امکان‌پذیر نیست", subtitle: "لطفاً بعداً دوباره سر بزنید.")
                            } else {
                                SiteEmptyState(icon: RemixIcons.TimeLine, title: "این بخش به‌زودی فعال می‌شود", subtitle: "لطفاً کمی بعد دوباره سر بزنید.")
                            }
                        }
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView { content(s) }
                            .sitePullRefresh { await load(showLoading: false) }
                    }
                } else {
                    SiteEmptyState(
                        icon: RemixIcons.ErrorWarningLine,
                        title: "دریافت اطلاعات ممکن نشد",
                        subtitle: error,
                        actionLabel: "تلاش دوباره",
                        actionIcon: RemixIcons.RefreshLine,
                        onAction: { Task { await load(showLoading: true) } }
                    )
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task { await load(showLoading: true) }
        .confirmationDialog("انتخاب فایل", isPresented: $showSourceDialog, titleVisibility: .visible) {
            Button("گالری عکس") { showPhotoPicker = true }
            Button(pendingDoc?.accept.contains(".pdf") == true ? "فایل‌ها (عکس یا PDF)" : "فایل‌ها") { showFileImporter = true }
            Button("انصراف", role: .cancel) { pendingDoc = nil }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            pickerItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    upload(.image(data))
                } else {
                    pendingDoc = nil
                    ShkToast.shared.show("خواندن فایل ممکن نشد؛ فایل دیگری انتخاب کنید.")
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: pendingDoc?.accept.contains(".pdf") == true ? [.image, .pdf] : [.image]
        ) { result in
            guard case .success(let url) = result else { pendingDoc = nil; return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                pendingDoc = nil
                ShkToast.shared.show("خواندن فایل ممکن نشد؛ فایل دیگری انتخاب کنید.")
                return
            }
            let isPdf = (UTType(filenameExtension: url.pathExtension)?.conforms(to: .pdf) ?? false) || data.starts(with: Data("%PDF".utf8))
            upload(isPdf ? .pdf(data) : .image(data))
        }
    }

    @ViewBuilder
    private func content(_ s: PartnerStateDto) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("با همکاری، برای هر فروش با لینک معرفی خودتان پورسانت ویژه‌ی همکار می‌گیرید. مراحل زیر را به ترتیب کامل کنید و درخواست را برای بررسی بفرستید.")
                .shkFont(12, lineHeight: 21)
                .foregroundColor(colors.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(height: 12)

            // وضعیت درخواست
            if s.state == "submitted" {
                StatusBanner(
                    icon: RemixIcons.TimeLine,
                    color: Color(argb: 0xFF1565C0),
                    title: "درخواست شما\(s.submittedAt.map { " در \($0.toPersianDigits())" } ?? "") ارسال شده و در انتظار بررسی است.",
                    message: nil
                )
                Spacer().frame(height: 12)
            } else if s.state == "rejected" {
                let lines = [s.rejectReason, s.retryAt.map { "می‌توانید از \($0.toPersianDigits()) دوباره درخواست بدهید." }].compactMap { $0 }
                StatusBanner(
                    icon: RemixIcons.CloseCircleLine,
                    color: colors.primary,
                    title: "درخواست قبلی شما رد شد.",
                    message: lines.isEmpty ? nil : lines.joined(separator: "\n")
                )
                Spacer().frame(height: 12)
            }

            ForEach(Array(PartnerStep.allCases.enumerated()), id: \.offset) { index, step in
                StepCard(
                    number: index + 1,
                    step: step,
                    done: stepDone(step, s),
                    open: openStep == step,
                    onToggle: { withAnimation(.easeInOut(duration: 0.25)) { openStep = openStep == step ? nil : step } }
                ) {
                    stepContent(step, s)
                }
                Spacer().frame(height: 10)
            }
            Spacer().frame(height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func stepContent(_ step: PartnerStep, _ s: PartnerStateDto) -> some View {
        switch step {
        case .ACCOUNT:
            let a = s.steps?.account
            CheckLine(ok: a?.name == true, text: "نام و نام خانوادگی در حساب کاربری ثبت شده باشد")
            CheckLine(ok: a?.phone == true, text: "شماره‌ی تماس ثبت شده باشد")
            CheckLine(ok: a?.address == true, text: "حداقل یک آدرس ثبت شده باشد")
            if a?.ok != true {
                Spacer().frame(height: 10)
                HStack(spacing: 8) {
                    if a?.name != true {
                        SiteSecondaryButton(text: "ویرایش حساب کاربری", onClick: onEditProfile, icon: RemixIcons.UserSettingsLine, height: 40, fontSize: 12)
                    }
                    if a?.address != true {
                        SiteSecondaryButton(text: "افزودن آدرس", onClick: onAddresses, icon: RemixIcons.MapPin2Line, height: 40, fontSize: 12)
                    }
                }
            }
        case .DOCUMENTS, .INSTAGRAM:
            if step == .INSTAGRAM {
                Text("پیج اینستاگرام ما را دنبال کنید و از صفحه‌ی پیج (که دکمه‌ی «دنبال می‌کنید» دیده شود) اسکرین‌شات بگیرید و بارگذاری کنید.")
                    .shkFont(12, lineHeight: 20)
                    .foregroundColor(colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let url = s.steps?.instagram?.pageUrl {
                    Spacer().frame(height: 8)
                    SiteSecondaryButton(text: "باز کردن پیج اینستاگرام", onClick: { openUrl(url) }, icon: RemixIcons.InstagramLine, height: 40, fontSize: 12)
                }
                Spacer().frame(height: 10)
            }
            let key = step == .DOCUMENTS ? "documents" : "instagram"
            ForEach(s.documents.filter { $0.step == key }, id: \.kind) { doc in
                DocumentRow(
                    doc: doc,
                    editable: s.editable,
                    uploading: uploadingKind == doc.kind,
                    busy: uploadingKind != nil,
                    onPick: { pick(doc) },
                    onDelete: {
                        Task {
                            switch await repository.deleteFile(doc.kind) {
                            case .success(let data): apply(data)
                            case .error(let message): ShkToast.shared.show(message)
                            }
                        }
                    }
                )
            }
            Text("عکس، یا برای جواز و کارت ویزیت PDF؛ حداکثر \(String(s.maxKb / 1024).toPersianDigits()) مگابایت.")
                .shkFont(11)
                .foregroundColor(colors.onSurfaceVariant)
        case .BALE:
            baleContent(s)
        case .SUBMIT:
            if s.state == "submitted" {
                Text("درخواست شما ارسال شده و در انتظار بررسی است.").shkFont(12).foregroundColor(colors.onSurface)
            } else {
                Text(s.canSubmit ? "همه‌ی مراحل کامل است. درخواست را برای بررسی بفرستید." : "برای ارسال درخواست، همه‌ی مراحل و مدارک الزامی را کامل کنید.")
                    .shkFont(12, lineHeight: 20)
                    .foregroundColor(colors.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(height: 10)
                SitePrimaryButton(
                    text: "ارسال درخواست",
                    onClick: {
                        submitting = true
                        Task {
                            switch await repository.submit() {
                            case .success(let data): apply(data)
                            case .error(let message): ShkToast.shared.show(message, long: true)
                            }
                            submitting = false
                        }
                    },
                    icon: RemixIcons.SendPlaneLine,
                    enabled: s.canSubmit && s.editable,
                    loading: submitting,
                    containerColor: SuccessGreen,
                    fillWidth: true
                )
            }
        }
    }

    @ViewBuilder
    private func baleContent(_ s: PartnerStateDto) -> some View {
        if let b = s.steps?.bale, b.ready {
            if b.ok {
                CheckLine(ok: true, text: "عضویت شما در کانال بله تأیید شد.")
                Spacer().frame(height: 6)
            }
            NumberedLine(number: 1, text: "در کانال بله ما عضو شوید.")
            if let url = b.channelUrl {
                SiteSecondaryButton(text: "باز کردن کانال", onClick: { openUrl(url) }, icon: RemixIcons.ExternalLinkLine, height: 38, fontSize: 12)
                    .padding(.leading, 26)
                    .padding(.bottom, 8)
            }
            NumberedLine(number: 2, text: "برای اتصال حساب بله، ربات ما را باز کنید و «شروع» را بزنید؛ یا همین کد را برای ربات بفرستید:")
            if let code = b.code {
                HStack(spacing: 8) {
                    Text(code)
                        .tracking(3)
                        .shkFont(17, .bold)
                        .foregroundColor(colors.onSurface)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(colors.surfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    SiteSecondaryButton(text: "کپی کد", onClick: { copyToClipboard(label: "کد", value: code) }, icon: RemixIcons.FileCopyLine, height: 36, fontSize: 12)
                }
                .padding(.leading, 26)
                .padding(.top, 4)
                .padding(.bottom, 6)
                if let url = b.botUrl {
                    SiteSecondaryButton(text: "باز کردن ربات \(b.bot ?? "")".trimmingCharacters(in: .whitespaces), onClick: { openUrl(url) }, icon: RemixIcons.ExternalLinkLine, height: 38, fontSize: 12)
                        .padding(.leading, 26)
                        .padding(.bottom, 6)
                }
            }
            if b.linked {
                Text("حساب بله شما متصل شد.").shkFont(11).foregroundColor(SuccessGreen)
                    .padding(.leading, 26)
                    .padding(.bottom, 6)
            }
            NumberedLine(number: 3, text: "به این صفحه برگردید و «بررسی عضویت» را بزنید.")
            Spacer().frame(height: 10)
            if s.editable {
                SitePrimaryButton(
                    text: "بررسی عضویت",
                    onClick: {
                        baleChecking = true
                        Task {
                            switch await repository.checkBale() {
                            case .success(let data): apply(data)
                            case .error(let message): ShkToast.shared.show(message, long: true)
                            }
                            baleChecking = false
                        }
                    },
                    icon: RemixIcons.RefreshLine,
                    loading: baleChecking,
                    height: 44,
                    fillWidth: true
                )
            }
            if let checkedAt = b.checkedAt {
                Spacer().frame(height: 6)
                Text("آخرین بررسی: \(checkedAt.toPersianDigits())").shkFont(11).foregroundColor(colors.onSurfaceVariant)
            }
        } else {
            Text("بررسی عضویت بله فعلاً در دسترس نیست. لطفاً بعداً دوباره امتحان کنید.")
                .shkFont(12)
                .foregroundColor(colors.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatusBanner: View {
    let icon: String
    let color: Color
    let title: String
    let message: String?
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RemixIcon(icon, tint: color, size: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).shkFont(12, .bold).foregroundColor(color)
                if let message {
                    Text(message).shkFont(12, lineHeight: 20).foregroundColor(colors.onSurface)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct StepCard<Content: View>: View {
    let number: Int
    let step: PartnerStep
    let done: Bool
    let open: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: () -> Content
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        SiteCard(contentPadding: .all(0), borderColor: open ? primary.opacity(0.35) : nil) {
            Button(action: onToggle) {
                HStack(spacing: 0) {
                    ZStack {
                        Circle().fill(done ? SuccessGreen.opacity(0.12) : open ? primary : colors.surfaceVariant)
                        if done {
                            RemixIcon(RemixIcons.CheckLine, contentDescription: "انجام شد", tint: SuccessGreen, size: 18)
                        } else {
                            Text(number.toPersianDigits()).shkFont(14, .bold).foregroundColor(open ? .white : colors.onSurface)
                        }
                    }
                    .frame(width: 34, height: 34)
                    Spacer().frame(width: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).shkFont(14, .bold).foregroundColor(colors.onSurface)
                        Text(step.hint).shkFont(11).foregroundColor(colors.onSurfaceVariant).lineLimit(2).truncationMode(.tail)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    RemixIcon(open ? RemixIcons.ArrowUpSLine : RemixIcons.ArrowDownSLine, tint: colors.onSurfaceVariant, size: 22)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                VStack(alignment: .leading, spacing: 0) { content() }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct CheckLine: View {
    let ok: Bool
    let text: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 8) {
            RemixIcon(ok ? RemixIcons.CheckboxCircleFill : RemixIcons.CloseCircleFill, tint: ok ? SuccessGreen : colors.primary, size: 18)
            Text(text).shkFont(12).foregroundColor(colors.onSurface)
        }
        .padding(.vertical, 3)
    }
}

private struct NumberedLine: View {
    let number: Int
    let text: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number.toPersianDigits())
                .shkFont(10, .bold)
                .foregroundColor(colors.onSurface)
                .frame(width: 18, height: 18)
                .background(Circle().fill(colors.surfaceVariant))
            Text(text).shkFont(12, lineHeight: 20).foregroundColor(colors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }
}

private struct DocumentRow: View {
    let doc: PartnerDocumentDto
    let editable: Bool
    let uploading: Bool
    let busy: Bool
    let onPick: () -> Void
    let onDelete: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 0) {
            RemixIcon(doc.uploaded ? RemixIcons.CheckboxCircleFill : RemixIcons.UploadCloud2Line, tint: doc.uploaded ? SuccessGreen : colors.onSurfaceVariant, size: 20)
            Spacer().frame(width: 8)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text(documentLabel(doc.kind)).shkFont(12, .bold).foregroundColor(colors.onSurface)
                    Text(doc.required ? "(الزامی)" : "(اختیاری)").shkFont(10).foregroundColor(doc.required ? primary : colors.onSurfaceVariant)
                }
                if doc.uploaded, let name = doc.name, !name.isBlankShk {
                    Text(name).shkFont(10).foregroundColor(colors.onSurfaceVariant).lineLimit(1).truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if editable {
                Spacer().frame(width: 6)
                if uploading {
                    ProgressView().tint(primary).frame(width: 22, height: 22)
                } else {
                    SiteSecondaryButton(text: doc.uploaded ? "تغییر" : "بارگذاری", onClick: onPick, enabled: !busy, height: 34, fontSize: 11)
                    if doc.uploaded && !doc.required {
                        Spacer().frame(width: 4)
                        Button(action: onDelete) {
                            RemixIcon(RemixIcons.DeleteBinLine, contentDescription: "حذف", tint: colors.onSurfaceVariant, size: 17)
                                .frame(width: 34, height: 34)
                                .background(colors.surfaceVariant)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(SitePressStyle())
                        .disabled(busy)
                    }
                }
            }
        }
        .padding(10)
        .overlay(shape.stroke(doc.uploaded ? SuccessGreen.opacity(0.35) : colors.surfaceVariant, lineWidth: 1))
        .clipShape(shape)
        .padding(.bottom, 8)
    }
}
