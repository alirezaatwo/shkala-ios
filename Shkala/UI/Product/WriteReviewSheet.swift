import SwiftUI
import PhotosUI

/// معادل validateImageUpload + validateReviewImage اندروید: فقط png/jpg، حداکثر ۵ مگ (عمومی) و ۲ مگ (دیدگاه)
func validateReviewImage(_ data: Data) -> String? {
    let sizeMb = Double(data.count) / (1024 * 1024)
    if sizeMb > 5.0 { return "حجم عکس نباید بیشتر از ۵ مگابایت باشد." }
    if !isPngData(data) && !isJpegData(data) { return "فقط فرمت JPG یا PNG مجاز است." }
    if sizeMb > 2.0 { return ReviewImageErrorMessage }
    return nil
}

/**
 * معادل ui/product/WriteReviewSheet.kt: شیت ثبت دیدگاه - امتیاز ستاره‌ای + متن + پیشنهاد خرید (بله/خیر).
 * فیلدهای «نقاط قوت/ضعف» به‌صورت متن آزاد (خط به خط). افزودن تصویر: مثل سایت فقط برای خریدار محصول.
 * (تفاوت اجباری iOS: عکس‌های HEIC گالری آیفون قبل از اعتبارسنجی به JPG تبدیل می‌شن)
 */
struct WriteReviewSheet: View {
    let isSubmitting: Bool
    let onDismiss: () -> Void
    // مثل سایت: بخش «افزودن تصویر کالای خریداری شده» فقط برای خریدار همین محصول نمایش داده می‌شه
    var canAttachImages: Bool = false
    /// (متن، امتیاز، پیشنهاد، نقاط قوت، نقاط ضعف، تصاویر)
    let onSubmit: (String, Int, Bool?, [String], [String], [Data]) -> Void

    @State private var content = ""
    @State private var rating = 5
    @State private var suggest: Bool? = nil
    @State private var strengthsText = ""
    @State private var weaknessText = ""
    @State private var selectedImages: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            SiteSheetHeader(title: "ثبت دیدگاه", onClose: onDismiss, icon: RemixIcons.ChatQuoteLine)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // ---- امتیاز ستاره‌ای ----
                    SiteCard {
                        SiteFieldLabel(text: "امتیاز شما")
                        HStack(spacing: 0) {
                            ForEach(1...5, id: \.self) { star in
                                Button { rating = star } label: {
                                    RemixIcon(star <= rating ? RemixIcons.StarFill : RemixIcons.StarLine,
                                              contentDescription: "امتیاز \(star)", tint: ProductRatingStarColor, size: 28)
                                        .frame(width: 40, height: 40)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(SitePressStyle())
                            }
                            Spacer()
                            Text("\(rating.toPersianDigits()) از ۵").shkFont(13, .bold).foregroundColor(colors.onSurface)
                        }
                    }

                    // ---- متن دیدگاه + نقاط قوت/ضعف ----
                    SiteCard {
                        SiteTextField(value: $content, label: "نظر شما", necessary: true, singleLine: false, minHeight: 100)
                        Spacer().frame(height: 12)
                        SiteTextField(value: $strengthsText, label: "نقاط قوت (اختیاری - هرکدام در یک خط)", leadingIcon: RemixIcons.AddLine, singleLine: false)
                        Spacer().frame(height: 12)
                        SiteTextField(value: $weaknessText, label: "نقاط ضعف (اختیاری - هرکدام در یک خط)", leadingIcon: RemixIcons.SubtractLine, singleLine: false)
                    }

                    // ---- تصاویر کالای خریداری شده (فقط خریدار؛ png/jpg زیر ۲ مگ مثل سایت) ----
                    if canAttachImages { imagesCard }

                    // ---- پیشنهاد خرید (هر گزینه با کلیک دوباره برداشته می‌شه) ----
                    VStack(spacing: 8) {
                        SuggestOption(text: "این محصول را پیشنهاد می‌کنم", icon: RemixIcons.ThumbUpLine, color: SiteStatusColors.Success, selected: suggest == true) {
                            suggest = suggest == true ? nil : true
                        }
                        SuggestOption(text: "این محصول را پیشنهاد نمی‌کنم", icon: RemixIcons.ThumbDownLine, color: colors.error, selected: suggest == false) {
                            suggest = suggest == false ? nil : false
                        }
                    }

                    SitePrimaryButton(
                        text: "ارسال دیدگاه",
                        onClick: {
                            let strengths = strengthsText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                            let weakness = weaknessText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                            // تصاویر فقط وقتی فرستاده می‌شن که بخش تصویر برای کاربر نمایش داده شده باشه
                            onSubmit(content, rating, suggest, strengths, weakness, canAttachImages ? selectedImages : [])
                        },
                        icon: RemixIcons.SendPlane2Line,
                        enabled: !content.isBlankShk,
                        loading: isSubmitting,
                        fillWidth: true
                    )
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 12)
        .onChange(of: pickerItems) { items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    guard var data = try? await item.loadTransferable(type: Data.self) else { continue }
                    if !isPngData(data) && !isJpegData(data), let image = UIImage(data: data), let jpg = image.jpegData(compressionQuality: 0.9) {
                        data = jpg
                    }
                    if let error = validateReviewImage(data) {
                        ShkToast.shared.show(error)
                    } else if !selectedImages.contains(data) {
                        selectedImages.append(data)
                    }
                }
                pickerItems = []
            }
        }
    }

    private var imagesCard: some View {
        SiteCard {
            HStack(spacing: 6) {
                RemixIcon(RemixIcons.Image2Line, tint: colors.primary, size: 18)
                Text("افزودن تصویر کالای خریداری شده").shkFont(13, .bold).foregroundColor(colors.onSurface)
            }
            Text("فرمت png یا jpg، حداکثر ۲ مگابایت برای هر تصویر")
                .shkFont(11).foregroundColor(colors.onSurfaceVariant)
                .padding(.top, 4).padding(.bottom, 10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // دکمه‌ی افزودن تصویر
                    PhotosPicker(selection: $pickerItems, matching: .images) {
                        VStack(spacing: 2) {
                            RemixIcon(RemixIcons.ImageAddLine, contentDescription: "افزودن تصویر", tint: colors.primary, size: 22)
                            Text("افزودن").shkFont(11).foregroundColor(colors.primary)
                        }
                        .frame(width: 72, height: 72)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.primary.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(colors.primary.opacity(0.35), lineWidth: 1))
                    }
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, data in
                        ZStack(alignment: .topLeading) {
                            if let image = UIImage(data: data) {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .background(colors.surfaceVariant)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            // دکمه‌ی حذف تصویر (گوشه‌ی TopStart)
                            Button { selectedImages.remove(at: index) } label: {
                                ZStack {
                                    Circle().fill(Color.black.opacity(0.55))
                                    RemixIcon(RemixIcons.CloseLine, contentDescription: "حذف تصویر", tint: .white, size: 14)
                                }
                                .frame(width: 22, height: 22)
                            }
                            .padding(4)
                        }
                        .frame(width: 72, height: 72)
                    }
                }
            }
            if selectedImages.isEmpty {
                Text("هنوز موردی اضافه نشده است").shkFont(11).foregroundColor(colors.onSurfaceVariant).padding(.top, 8)
            }
        }
    }
}

/** گزینه‌ی پیشنهاد/عدم پیشنهاد به‌شکل کارت قابل انتخاب */
private struct SuggestOption: View {
    let text: String
    let icon: String
    let color: Color
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Button(action: onClick) {
            HStack(spacing: 0) {
                RemixIcon(selected ? RemixIcons.CheckboxCircleFill : RemixIcons.CheckboxBlankCircleLine, tint: selected ? color : colors.outline, size: 20)
                Spacer().frame(width: 10)
                Text(text).shkFont(13, selected ? .bold : .medium).foregroundColor(colors.onSurface).frame(maxWidth: .infinity, alignment: .leading)
                RemixIcon(icon, tint: color, size: 18)
            }
            .padding(12)
            .background(shape.fill(selected ? color.opacity(0.08) : colors.surface))
            .overlay(shape.strokeBorder(selected ? color : .clear, lineWidth: 1))
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(SitePressStyle())
    }
}
