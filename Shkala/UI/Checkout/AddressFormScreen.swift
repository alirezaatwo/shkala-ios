import SwiftUI

// ===================================================================================
// معادل ui/checkout/AddressFormScreen.kt
// بازطراحی: فرم افزودن/ویرایش آدرس - فیلدهای SiteTextField با برچسب و آیکن، گروه‌بندی در
// کارت‌های «مشخصات گیرنده» و «نشانی»، کارت انتخاب لوکیشن و دکمه‌ی ذخیره‌ی ثابت پایین.
// ===================================================================================

struct AddressFormScreen: View {
    let addressId: Int?
    let onBack: () -> Void
    let onSaved: () -> Void
    let onPickLocation: () -> Void

    @Environment(\.shkColors) private var colors
    @ObservedObject private var locationFlow = LocationPickFlowState.shared
    private let repository = CheckoutRepository()

    @State private var existing: AddressDto? = nil
    @State private var isLoadingExisting: Bool
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var state = ""
    @State private var city = ""
    @State private var phone = ""
    @State private var postalCode = ""
    @State private var fullAddress = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    // فقط برای نمایش: بعد از اولین تلاش ذخیره، فیلدهای ناقص قرمز می‌شن
    @State private var triedSubmit = false

    init(addressId: Int?, onBack: @escaping () -> Void, onSaved: @escaping () -> Void, onPickLocation: @escaping () -> Void) {
        self.addressId = addressId
        self.onBack = onBack
        self.onSaved = onSaved
        self.onPickLocation = onPickLocation
        _isLoadingExisting = State(initialValue: addressId != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: existing == nil ? "افزودن آدرس" : "ویرایش آدرس", onBack: onBack)

            if isLoadingExisting {
                SiteLoading(message: "در حال دریافت اطلاعات آدرس...", icon: RemixIcons.MapPin2Line)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                form
                saveBar
            }
        }
        .background(colors.background)
        .task(id: addressId) { await loadExisting() }
    }

    private func loadExisting() async {
        guard let addressId else { return }
        if case .success(let list) = await repository.getAddresses(), let found = list.first(where: { $0.id == addressId }) {
            existing = found
            firstName = found.firstName
            lastName = found.lastName
            state = found.state
            city = found.city
            phone = found.phone
            postalCode = found.postalCode
            fullAddress = found.fullAddress
        }
        isLoadingExisting = false
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 12) {
                // --- مشخصات گیرنده ---
                FormSectionCard(icon: RemixIcons.User3Line, title: "مشخصات گیرنده", subtitle: "سفارش به نام این شخص تحویل داده می‌شود") {
                    HStack(alignment: .top, spacing: 10) {
                        SiteTextField(value: $firstName, label: "نام", necessary: true, submitLabel: .next,
                                      isError: triedSubmit && firstName.isBlankShk)
                        SiteTextField(value: $lastName, label: "نام خانوادگی", necessary: true, submitLabel: .next,
                                      isError: triedSubmit && lastName.isBlankShk)
                    }
                    Spacer().frame(height: 12)
                    SiteTextField(
                        value: $phone, label: "شماره موبایل گیرنده", placeholder: "۰۹۱۲۳۴۵۶۷۸۹", necessary: true,
                        leadingIcon: RemixIcons.SmartphoneLine, keyboard: .phone, submitLabel: .next,
                        isError: triedSubmit && phone.count != 11,
                        helperText: triedSubmit && phone.count != 11 ? "شماره موبایل باید ۱۱ رقم باشد" : "\(phone.count.toPersianDigits()) از ۱۱ رقم",
                        maxLength: 11, filter: { $0.filter(\.isWholeNumber) }
                    )
                }

                // --- نشانی ---
                FormSectionCard(icon: RemixIcons.MapPin2Line, title: "نشانی", subtitle: "آدرس دقیق را برای ارسال سریع‌تر وارد کنید") {
                    HStack(alignment: .top, spacing: 10) {
                        SiteTextField(value: $state, label: "استان", necessary: true, leadingIcon: RemixIcons.Map2Line,
                                      submitLabel: .next, isError: triedSubmit && state.isBlankShk)
                        SiteTextField(value: $city, label: "شهر", necessary: true, leadingIcon: RemixIcons.Building2Line,
                                      submitLabel: .next, isError: triedSubmit && city.isBlankShk)
                    }
                    Spacer().frame(height: 12)
                    SiteTextField(
                        value: $postalCode, label: "کد پستی (۱۰ رقم)", necessary: true, leadingIcon: RemixIcons.MailLine,
                        keyboard: .number, submitLabel: .next,
                        isError: triedSubmit && postalCode.count != 10,
                        helperText: triedSubmit && postalCode.count != 10 ? "کد پستی باید ۱۰ رقم و بدون خط تیره باشد" : "\(postalCode.count.toPersianDigits()) از ۱۰ رقم",
                        maxLength: 10, filter: { $0.filter(\.isWholeNumber) }
                    )
                    Spacer().frame(height: 12)
                    SiteTextField(value: $fullAddress, label: "آدرس کامل", placeholder: "خیابان، کوچه، پلاک، واحد", necessary: true,
                                  singleLine: false, minHeight: 96, isError: triedSubmit && fullAddress.isBlankShk)
                }

                // --- لوکیشن روی نقشه ---
                LocationPickCard(picked: locationFlow.pickedLat != nil, onClick: onPickLocation)

                if let errorMessage {
                    let errorColor = colors.error
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.ErrorWarningLine, tint: errorColor, size: 18)
                        Spacer().frame(width: 8)
                        Text(errorMessage).shkFont(12, lineHeight: 20).foregroundColor(errorColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(errorColor.opacity(0.1)))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.25), value: errorMessage)
        }
    }

    private var saveBar: some View {
        SitePrimaryButton(text: "ذخیره‌ی آدرس", onClick: save, icon: RemixIcons.Save3Line, loading: isSaving, fillWidth: true)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                TopRoundedShape(radius: 20)
                    .fill(colors.surface)
                    .shadow(color: .black.opacity(0.14), radius: 9, x: 0, y: -2)
                    .ignoresSafeArea(edges: .bottom)
            )
    }

    private func save() {
        triedSubmit = true
        if firstName.isBlankShk || lastName.isBlankShk || state.isBlankShk || city.isBlankShk ||
            phone.count != 11 || postalCode.count != 10 || fullAddress.isBlankShk {
            errorMessage = "لطفاً همه‌ی فیلدها را کامل و صحیح وارد کنید."
            return
        }
        errorMessage = nil
        isSaving = true
        let currentExisting = existing
        let lat = locationFlow.pickedLat
        let lng = locationFlow.pickedLng
        Task {
            let result: ApiResult<AddressDto>
            if let currentExisting {
                result = await repository.updateAddress(
                    id: currentExisting.id, firstName: firstName, lastName: lastName, state: state, city: city,
                    phone: phone, postalCode: postalCode, fullAddress: fullAddress, mapLat: lat, mapLng: lng
                )
            } else {
                result = await repository.createAddress(
                    firstName: firstName, lastName: lastName, state: state, city: city,
                    phone: phone, postalCode: postalCode, fullAddress: fullAddress, mapLat: lat, mapLng: lng
                )
            }
            isSaving = false
            switch result {
            case .success:
                locationFlow.clear()
                onSaved()
            case .error(let message):
                errorMessage = message
            }
        }
    }
}

/** کارت گروه فیلدها با سرتیتر (آیکن + عنوان + توضیح) */
private struct FormSectionCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard(contentPadding: .all(16)) {
            HStack(spacing: 0) {
                SiteIconBadge(icon: icon, size: 36, iconSize: 18, radius: 11)
                Spacer().frame(width: 10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).shkFont(14, .bold).foregroundColor(colors.onSurface)
                    if let subtitle, !subtitle.isBlankShk {
                        Text(subtitle).shkFont(11, lineHeight: 18).foregroundColor(colors.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer().frame(height: 14)
            content()
        }
    }
}

/** کارت انتخاب لوکیشن روی نقشه (اختیاری) */
private struct LocationPickCard: View {
    let picked: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let success = SiteStatusColors.Success
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 0) {
            SiteIconBadge(icon: picked ? RemixIcons.CheckboxCircleLine : RemixIcons.MapPinRangeLine, tint: picked ? success : primary)
            Spacer().frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(picked ? "لوکیشن روی نقشه انتخاب شد ✅" : "انتخاب لوکیشن از روی نقشه (اختیاری)")
                    .shkFont(13, .bold)
                    .foregroundColor(colors.onSurface)
                Text(picked ? "برای تغییر موقعیت، دوباره ضربه بزنید" : "با مشخص کردن موقعیت، تحویل سفارش دقیق‌تر انجام می‌شود")
                    .shkFont(11, lineHeight: 18)
                    .foregroundColor(colors.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
        }
        .padding(14)
        .background(shape.fill(colors.surface))
        .overlay(shape.stroke(picked ? success.opacity(0.6) : .clear, lineWidth: 1))
        .contentShape(shape)
        .onTapGesture(perform: onClick)
        .animation(.easeInOut(duration: 0.2), value: picked)
    }
}
