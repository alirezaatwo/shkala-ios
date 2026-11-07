import SwiftUI
import PhotosUI

// معادل ui/account/EditProfileScreen.kt
// بازطراحی ویرایش حساب: آواتار بالای صفحه (حلقه‌ی قرمز + نشان دوربین)، فیلدها در کارت‌های
// گروه‌بندی‌شده (اطلاعات شخصی، تماس، درباره‌ی من، شبکه‌های اجتماعی با آیکن برند هر شبکه، رمز عبور)
// و دکمه‌ی «ذخیره‌ی تغییرات» چسبیده به پایین صفحه. منطق دریافت/ذخیره/اعتبارسنجی بدون تغییر.

// رنگ برند شبکه‌هایی که در SocialLinks تعریف نشده‌ن
private let FacebookColor = Color(argb: 0xFF1877F2)

// تبدیل ارقام فارسی/عربی به لاتین (برای ورودی‌های عددی)
private func normalizeDigits(_ s: String) -> String {
    var out = ""
    for ch in s {
        if ch.unicodeScalars.count == 1, let v = ch.unicodeScalars.first?.value {
            if (0x06F0...0x06F9).contains(v) { out.append(Character(UnicodeScalar(0x30 + v - 0x06F0)!)); continue }
            if (0x0660...0x0669).contains(v) { out.append(Character(UnicodeScalar(0x30 + v - 0x0660)!)); continue }
        }
        out.append(ch)
    }
    return out
}

// کد ملی: خالی مجاز است، در غیر این صورت دقیقاً ۱۰ رقم
private func isNationalNumberInvalid(_ value: String) -> Bool { !value.isEmpty && value.count != 10 }

// ایمیل: خالی مجاز است (در سرور nullable)، در غیر این صورت باید فرمت درست داشته باشد
// (معادل android.util.Patterns.EMAIL_ADDRESS)
private func isEmailInvalid(_ value: String) -> Bool {
    if value.isEmpty { return false }
    let pattern = "^[a-zA-Z0-9+._%\\-]{1,256}@[a-zA-Z0-9][a-zA-Z0-9\\-]{0,64}(\\.[a-zA-Z0-9][a-zA-Z0-9\\-]{0,25})+$"
    return value.range(of: pattern, options: .regularExpression) == nil
}

struct EditProfileScreen: View {
    let onBack: () -> Void

    @Environment(\.shkColors) private var colors

    @State private var isLoading = true
    @State private var genderList: [GenderDto] = []
    @State private var avatarUrl: String? = nil
    @State private var newAvatarData: Data? = nil
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var nationalNumber = ""
    @State private var bio = ""
    @State private var selectedGender: String? = nil
    @State private var birthday = ""
    @State private var instagram = ""
    @State private var telegram = ""
    @State private var twitter = ""
    @State private var facebook = ""
    @State private var isSaving = false
    // بعد از اولین تلاش ذخیره، خطاها قرمز نمایش داده می‌شوند
    @State private var showErrors = false

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var newPasswordConfirm = ""
    @State private var isChangingPassword = false

    @State private var showAvatarPicker = false
    @State private var avatarPickerItem: PhotosPickerItem? = nil

    private let repository = ProfileRepository()

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "ویرایش حساب کاربری", onBack: onBack)

            if isLoading {
                SiteLoading(message: "در حال دریافت اطلاعات حساب...", icon: RemixIcons.UserSettingsLine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            // ---- آواتار ----
                            AvatarEditor(
                                newAvatarData: newAvatarData,
                                avatarUrl: avatarUrl,
                                name: name,
                                onPick: { showAvatarPicker = true }
                            )

                            // ---- اطلاعات شخصی ----
                            FormSection(icon: RemixIcons.User3Line, title: "اطلاعات شخصی") {
                                SiteTextField(value: $name, label: "نام و نام خانوادگی", leadingIcon: RemixIcons.User3Line)
                                FieldGap()
                                SiteTextField(value: $username, label: "نام کاربری", leadingIcon: RemixIcons.AtLine)
                                FieldGap()
                                // کد ملی: فقط رقم، حداکثر ۱۰ رقم + شمارنده
                                // (تفاوت iOS: نمایش ارقام فارسی با یک Binding نمایشی، مقدار واقعی لاتین می‌مونه)
                                let nationalInvalid = isNationalNumberInvalid(nationalNumber)
                                SiteTextField(
                                    value: Binding(
                                        get: { nationalNumber.toPersianDigits() },
                                        set: { input in nationalNumber = String(normalizeDigits(input).filter { ("0"..."9").contains($0) }.prefix(10)) }
                                    ),
                                    label: "کد ملی",
                                    placeholder: "۱۰ رقم بدون خط تیره",
                                    leadingIcon: RemixIcons.IdCardLine,
                                    keyboard: .number,
                                    isError: showErrors && nationalInvalid,
                                    helperText: nationalInvalid ? "کد ملی باید دقیقاً ۱۰ رقم باشد." : nil
                                ) {
                                    Text("\(nationalNumber.count.toPersianDigits()) / ۱۰")
                                        .shkFont(11)
                                        .foregroundColor(nationalNumber.count == 10 ? colors.primary : colors.onSurfaceVariant)
                                }
                                FieldGap()
                                // تاریخ تولد: فقط‌خواندنی؛ با لمس، تقویم شمسی باز می‌شود
                                SiteTextField(
                                    value: .constant(birthday.toPersianDigits()),
                                    label: "تاریخ تولد",
                                    placeholder: "انتخاب از تقویم",
                                    leadingIcon: RemixIcons.Cake2Line
                                ) {
                                    RemixIcon(RemixIcons.CalendarLine, contentDescription: "انتخاب تاریخ تولد", tint: colors.primary, size: 18)
                                }
                                .overlay(Color.clear.contentShape(Rectangle()).onTapGesture { showBirthdayPicker() })
                                if !genderList.isEmpty {
                                    FieldGap()
                                    SiteFieldLabel(text: "جنسیت")
                                    FlowRow(spacing: 8, lineSpacing: 8) {
                                        ForEach(genderList, id: \.id) { gender in
                                            GenderOption(
                                                label: gender.label,
                                                selected: selectedGender == gender.id,
                                                onClick: { selectedGender = gender.id }
                                            )
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            // ---- اطلاعات تماس ----
                            FormSection(icon: RemixIcons.MailLine, title: "اطلاعات تماس") {
                                SiteTextField(
                                    value: $email,
                                    label: "ایمیل",
                                    placeholder: "name@example.com",
                                    leadingIcon: RemixIcons.MailLine,
                                    keyboard: .email,
                                    textContentType: .emailAddress,
                                    isError: showErrors && isEmailInvalid(email),
                                    helperText: isEmailInvalid(email) ? "فرمت ایمیل صحیح نیست (مثل name@example.com)." : nil,
                                    textAlign: .leading,
                                    // فقط نویسه‌های لاتین قابل چاپ، بدون فاصله و حروف فارسی
                                    filter: { input in String(input.unicodeScalars.filter { (33...126).contains($0.value) }.map(Character.init)) }
                                )
                            }

                            // ---- درباره‌ی من ----
                            FormSection(icon: RemixIcons.FileTextLine, title: "درباره‌ی من") {
                                SiteTextField(
                                    value: $bio,
                                    placeholder: "چند خط درباره‌ی خودتان بنویسید...",
                                    singleLine: false,
                                    minHeight: 104
                                )
                            }

                            // ---- شبکه‌های اجتماعی (هر فیلد با آیکن برند خودش) ----
                            FormSection(icon: RemixIcons.ShareLine, title: "شبکه‌های اجتماعی") {
                                SocialField(label: "اینستاگرام", icon: RemixIcons.InstagramFill, brandColor: InstagramColor, value: $instagram)
                                FieldGap()
                                SocialField(label: "تلگرام", icon: RemixIcons.TelegramFill, brandColor: TelegramColor, value: $telegram)
                                FieldGap()
                                SocialField(label: "توییتر (X)", icon: RemixIcons.TwitterXFill, brandColor: colors.onSurface, value: $twitter)
                                FieldGap()
                                SocialField(label: "فیسبوک", icon: RemixIcons.FacebookCircleFill, brandColor: FacebookColor, value: $facebook)
                            }

                            // ---- تغییر رمز عبور (با دکمه‌ی جداگانه‌ی خودش) ----
                            FormSection(icon: RemixIcons.LockPasswordLine, title: "تغییر رمز عبور") {
                                Text("تغییر رمز عبور جدا از اطلاعات بالا و با دکمه‌ی همین بخش انجام می‌شود. رمز جدید باید حداقل ۸ کاراکتر باشد.")
                                    .shkFont(11, lineHeight: 19)
                                    .foregroundColor(colors.onSurfaceVariant)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, 10)
                                PasswordField(label: "رمز عبور فعلی (در صورت داشتن)", value: $currentPassword, icon: RemixIcons.LockLine)
                                FieldGap()
                                PasswordField(label: "رمز عبور جدید", value: $newPassword, icon: RemixIcons.KeyLine)
                                FieldGap()
                                PasswordField(label: "تکرار رمز عبور جدید", value: $newPasswordConfirm, icon: RemixIcons.KeyLine)
                                Spacer().frame(height: 14)
                                SiteSecondaryButton(
                                    text: "تغییر رمز عبور",
                                    onClick: changePassword,
                                    icon: RemixIcons.ShieldCheckLine,
                                    enabled: !isChangingPassword,
                                    loading: isChangingPassword,
                                    fillWidth: true
                                )
                            }

                            Spacer().frame(height: 20)
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollDismissesKeyboard(.interactively)

                    // ---- دکمه‌ی ذخیره‌ی چسبیده به پایین ----
                    SitePrimaryButton(
                        text: "ذخیره‌ی تغییرات",
                        onClick: saveProfile,
                        icon: RemixIcons.Save3Line,
                        loading: isSaving,
                        fillWidth: true
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        TopRoundedShape(radius: 20)
                            .fill(colors.surface)
                            .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .photosPicker(isPresented: $showAvatarPicker, selection: $avatarPickerItem, matching: .images)
        .onChange(of: avatarPickerItem) { item in
            guard let item else { return }
            Task {
                if let data = await loadPickedImageData(item) {
                    if let error = validateImageUpload(data) {
                        ShkToast.shared.show(error)
                    } else {
                        newAvatarData = data
                    }
                }
                avatarPickerItem = nil
            }
        }
        .task { await load() }
    }

    private func load() async {
        switch await repository.getProfile() {
        case .success(let d):
            genderList = d.genderList
            avatarUrl = d.user.avatarUrl
            name = d.user.name ?? ""
            username = d.user.username ?? ""
            email = d.user.email ?? ""
            nationalNumber = d.user.nationalNumber ?? ""
            bio = d.user.bio ?? ""
            selectedGender = d.user.gender
            birthday = d.user.jalaliBirthday ?? ""
            instagram = d.user.social?.instagram ?? ""
            telegram = d.user.social?.telegram ?? ""
            twitter = d.user.social?.twitter ?? ""
            facebook = d.user.social?.facebook ?? ""
        case .error(let message):
            ShkToast.shared.show(message)
        }
        isLoading = false
    }

    // ذخیره‌ی پروفایل - دقیقاً همون فراخوانی قبلی
    private func saveProfile() {
        // جلوگیری از ذخیره با کد ملی یا ایمیل نامعتبر
        if isNationalNumberInvalid(nationalNumber) || isEmailInvalid(email) {
            showErrors = true
            let message = isNationalNumberInvalid(nationalNumber) ? "کد ملی باید دقیقاً ۱۰ رقم باشد." : "لطفاً یک ایمیل معتبر وارد کنید."
            ShkToast.shared.show(message)
            return
        }
        isSaving = true
        Task {
            let avatar: (data: Data, fileName: String, mimeType: String)? = newAvatarData.map {
                ($0, "avatar_\(Int64(Date().timeIntervalSince1970 * 1000)).jpg", "image/*")
            }
            let result = await repository.updateProfile(
                name: name, email: email, username: username, nationalNumber: nationalNumber, bio: bio,
                gender: selectedGender, jalaliBirthday: birthday, instagram: instagram, telegram: telegram,
                twitter: twitter, facebook: facebook, avatar: avatar
            )
            isSaving = false
            switch result {
            case .success(let msg): ShkToast.shared.show(msg)
            case .error(let msg): ShkToast.shared.show(msg)
            }
        }
    }

    // تغییر رمز عبور - همون اعتبارسنجی و فراخوانی قبلی
    private func changePassword() {
        if newPassword.count < 8 {
            ShkToast.shared.show("رمز عبور جدید باید حداقل ۸ کاراکتر باشد.")
            return
        }
        if newPassword != newPasswordConfirm {
            ShkToast.shared.show("تکرار رمز عبور مطابقت ندارد.")
            return
        }
        isChangingPassword = true
        Task {
            let current = currentPassword.trimmingCharacters(in: .whitespaces).isEmpty ? nil : currentPassword
            let result = await repository.changePassword(current: current, new: newPassword, newConfirmation: newPasswordConfirm)
            isChangingPassword = false
            switch result {
            case .success(let msg):
                currentPassword = ""
                newPassword = ""
                newPasswordConfirm = ""
                ShkToast.shared.show(msg)
            case .error(let msg):
                ShkToast.shared.show(msg)
            }
        }
    }

    // ---- تقویم شمسی تاریخ تولد ----
    private func showBirthdayPicker() {
        hideKeyboardShk()
        let initial = JalaliCalendar.parse(birthday)
        ShkDialogCenter.shared.show {
            JalaliDatePickerDialog(
                initialDate: initial,
                onDismiss: { ShkDialogCenter.shared.dismiss() },
                onConfirm: { date in
                    // همان قالب قبلی ارسال به سرور: yyyy/MM/dd
                    birthday = date.format()
                    ShkDialogCenter.shared.dismiss()
                },
                title: "انتخاب تاریخ تولد",
                // سرور تاریخ‌های قبل از ۱۹۷۰ و آینده را نادیده می‌گیرد
                minDate: JalaliDate(1348, 10, 12),
                maxDate: JalaliCalendar.today(),
                onClear: {
                    birthday = ""
                    ShkDialogCenter.shared.dismiss()
                }
            )
        }
    }
}

/// بستن صفحه‌کلید پیش از باز شدن دیالوگ
private func hideKeyboardShk() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/** آواتار دایره‌ای با حلقه‌ی قرمز و نشان دوربین؛ زدن روی آن گالری را باز می‌کند */
private struct AvatarEditor: View {
    let newAvatarData: Data?
    let avatarUrl: String?
    let name: String
    let onPick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        VStack(spacing: 0) {
            // جعبه‌ی بیرونی بدون clip تا نشان دوربین کامل دیده شود
            ZStack(alignment: .bottomTrailing) {
                Button(action: onPick) {
                    ZStack {
                        Circle().fill(primary.opacity(0.1))
                        if let newAvatarData, let img = UIImage(data: newAvatarData) {
                            Image(uiImage: img).resizable().scaledToFill().clipShape(Circle())
                        } else if let avatarUrl {
                            RemoteImage(avatarUrl, contentScale: .crop).clipShape(Circle())
                        } else {
                            RemixIcon(RemixIcons.UserSmileLine, tint: primary, size: 44)
                        }
                    }
                    .clipShape(Circle())
                    .padding(5)
                    .overlay(Circle().strokeBorder(primary, lineWidth: 2.5))
                    .frame(width: 100, height: 100)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(width: 110, height: 110)
                // نشان دوربین روی گوشه‌ی آواتار
                Button(action: onPick) {
                    ZStack {
                        Circle().fill(colors.background)
                        Circle().fill(primary).padding(3)
                        RemixIcon(RemixIcons.CameraFill, contentDescription: "تغییر عکس پروفایل", tint: .white, size: 15)
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 110, height: 110)
            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                Spacer().frame(height: 10)
                Text(name).shkFont(15, .bold).foregroundColor(colors.onBackground)
            }
            Spacer().frame(height: 4)
            Text(newAvatarData != nil
                 ? "عکس جدید انتخاب شد؛ برای ثبت، «ذخیره‌ی تغییرات» را بزنید."
                 : "برای تغییر عکس پروفایل ضربه بزنید (حداکثر ۵ مگابایت - JPG یا PNG)")
                .shkFont(11, lineHeight: 18)
                .foregroundColor(newAvatarData != nil ? primary : colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
}

/** کارت یک بخش از فرم: سرتیتر با آیکن + محتوا */
private struct FormSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 12)
            SiteCard(contentPadding: .all(16)) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: icon, size: 32, iconSize: 17, radius: 10)
                        Spacer().frame(width: 10)
                        Text(title).shkFont(14, .bold).foregroundColor(colors.onSurface)
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 14)
                    content()
                }
            }
        }
    }
}

private struct FieldGap: View {
    var body: some View { Spacer().frame(height: 12) }
}

/** گزینه‌ی جنسیت به شکل قرص انتخابی (جایگزین رادیوباتن) */
private struct GenderOption: View {
    let label: String
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        Button(action: onClick) {
            HStack(spacing: 6) {
                RemixIcon(
                    selected ? RemixIcons.CheckboxCircleFill : RemixIcons.CheckboxBlankCircleLine,
                    tint: selected ? primary : colors.onSurfaceVariant,
                    size: 18
                )
                Text(label)
                    .shkFont(13, selected ? .bold : .medium)
                    .foregroundColor(selected ? primary : colors.onSurface)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? primary.opacity(0.1) : colors.surfaceVariant))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? primary : Color.clear, lineWidth: 1))
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(.plain)
    }
}

/** فیلد شبکه‌ی اجتماعی: کادر آیکن برند (با رنگ خود برند) کنار فیلد ورودی */
private struct SocialField: View {
    let label: String
    let icon: String
    let brandColor: Color
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SiteFieldLabel(text: label)
            HStack(spacing: 8) {
                RemixIcon(icon, contentDescription: label, tint: brandColor, size: 22)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(brandColor.opacity(0.12)))
                SiteTextField(value: $value)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/** فیلد رمز عبور با دکمه‌ی نمایش/مخفی‌کردن */
private struct PasswordField: View {
    let label: String
    @Binding var value: String
    let icon: String
    @State private var visible = false
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteTextField(
            value: $value,
            label: label,
            leadingIcon: icon,
            keyboard: .password,
            textContentType: .password,
            secure: !visible
        ) {
            Button { visible.toggle() } label: {
                RemixIcon(
                    visible ? RemixIcons.EyeOffLine : RemixIcons.EyeLine,
                    contentDescription: visible ? "مخفی کردن رمز" : "نمایش رمز",
                    tint: colors.onSurfaceVariant,
                    size: 18
                )
            }
            .buttonStyle(.plain)
        }
    }
}
