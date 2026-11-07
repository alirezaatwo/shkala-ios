import SwiftUI
import PhotosUI

// معادل ui/ticket/CreateTicketScreen.kt

/**
 * ثبت تیکت جدید - بازطراحی با قالب جدید: کارت معرفی قرمز، فرم داخل کادر با فیلدهای SiteTextField،
 * انتخاب سطح اهمیت به‌شکل کارت‌های قرصی رنگی، کادر خط‌چین پیوست تصویر و دکمه‌ی اصلی ثبت.
 * منطق اعتبارسنجی و ارسال دست‌نخورده است.
 */
struct CreateTicketScreen: View {
    let onBack: () -> Void
    let onCreated: (Int) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = TicketRepository()

    @State private var priorities: [TicketPriorityDto] = []
    @State private var title = ""
    @State private var selectedPriority: String? = nil
    @State private var content = ""
    @State private var attachment: Data? = nil
    @State private var isSubmitting = false
    // فقط برای نمایش متن «در حال دریافت» زیر برچسب سطح اهمیت
    @State private var prioritiesLoading = true
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "ثبت تیکت جدید", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SiteHeroCard(
                        icon: RemixIcons.CustomerService2Line,
                        title: "ارسال درخواست به پشتیبانی",
                        subtitle: "موضوع، سطح اهمیت و شرح درخواست خود را وارد کنید؛ پاسخ کارشناسان در همین بخش نمایش داده می‌شود."
                    )

                    Spacer().frame(height: 12)

                    SiteCard {
                        VStack(alignment: .leading, spacing: 0) {
                            SiteTextField(
                                value: $title,
                                label: "عنوان تیکت",
                                placeholder: "مثلاً: پیگیری سفارش",
                                necessary: true,
                                leadingIcon: RemixIcons.TicketLine
                            )

                            Spacer().frame(height: 16)
                            SiteFieldLabel(text: "سطح اهمیت", necessary: true)
                            if priorities.isEmpty {
                                if prioritiesLoading {
                                    Text("در حال دریافت سطوح اهمیت...").shkFont(12).foregroundColor(colors.onSurfaceVariant)
                                }
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(Array(stride(from: 0, to: priorities.count, by: 3)), id: \.self) { start in
                                        let rowItems = Array(priorities[start..<min(start + 3, priorities.count)])
                                        HStack(spacing: 8) {
                                            ForEach(rowItems) { priority in
                                                PriorityOption(priority: priority, selected: selectedPriority == priority.id) {
                                                    selectedPriority = priority.id
                                                }
                                            }
                                            // جای خالی ردیف آخر تا عرض گزینه‌ها یکسان بمونه
                                            ForEach(0..<(3 - rowItems.count), id: \.self) { _ in
                                                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                                            }
                                        }
                                    }
                                }
                            }

                            Spacer().frame(height: 16)
                            SiteTextField(
                                value: $content,
                                label: "متن پیام",
                                placeholder: "مشکل یا سؤال خودتون رو کامل توضیح بدید...",
                                necessary: true,
                                singleLine: false,
                                minHeight: 140
                            )
                        }
                    }

                    Spacer().frame(height: 12)

                    // کادر خط‌چین پیوست تصویر
                    AttachmentPickerBox(attachment: attachment, onPick: { showPicker = true })

                    Spacer().frame(height: 20)

                    SitePrimaryButton(text: "ثبت تیکت", onClick: submit, icon: RemixIcons.SendPlane2Fill, loading: isSubmitting, fillWidth: true)

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = await loadPickedImageData(item) {
                    if let error = validateImageUpload(data) { ShkToast.shared.show(error) } else { attachment = data }
                }
                pickerItem = nil
            }
        }
        .task {
            if case .success(let data) = await repository.getPriorities() {
                priorities = data
                selectedPriority = priorities.first(where: { $0.id == "normal" })?.id ?? priorities.first?.id
            }
            prioritiesLoading = false
        }
    }

    private func submit() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let priority = selectedPriority else {
            ShkToast.shared.show("همه‌ی فیلدها را کامل کنید.")
            return
        }
        isSubmitting = true
        Task {
            let result = await repository.createTicket(title: title, priority: priority, content: content, attachment: attachment)
            isSubmitting = false
            switch result {
            case .success(let id): onCreated(id)
            case .error(let message): ShkToast.shared.show(message)
            }
        }
    }
}

/** گزینه‌ی سطح اهمیت (کارت قرصی رنگی) */
private struct PriorityOption: View {
    let priority: TicketPriorityDto
    let selected: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let (_, color) = ticketPriorityStyle(priority.id, colors)
        Button(action: onClick) {
            HStack(spacing: 6) {
                RemixIcon(selected ? RemixIcons.CheckboxCircleLine : RemixIcons.Flag2Line, tint: selected ? color : colors.onSurfaceVariant, size: 16)
                Text(priority.label)
                    .shkFont(12, selected ? .bold : .medium)
                    .foregroundColor(selected ? color : colors.onSurface)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? color.opacity(0.12) : colors.surfaceVariant))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? color : Color.clear, lineWidth: 1))
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(.plain)
    }
}

private struct AttachmentPickerBox: View {
    let attachment: Data?
    let onPick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let dashColor = attachment != nil ? primary.opacity(0.6) : colors.onSurfaceVariant.opacity(0.4)
        Button(action: onPick) {
            HStack(spacing: 0) {
                if let attachment, let img = UIImage(data: attachment) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .background(colors.surfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    SiteIconBadge(icon: RemixIcons.ImageLine, size: 48, iconSize: 22)
                }
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment != nil ? "تصویر پیوست انتخاب شد" : "پیوست کردن تصویر (اختیاری)")
                        .shkFont(13, .bold)
                        .foregroundColor(attachment != nil ? primary : colors.onSurface)
                    Text("حداکثر حجم: ۵ مگابایت - فرمت JPG یا PNG").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RemixIcon(attachment != nil ? RemixIcons.CheckboxCircleLine : RemixIcons.AttachmentLine,
                          tint: attachment != nil ? primary : colors.onSurfaceVariant, size: 20)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(dashColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3.3])))
        }
        .buttonStyle(.plain)
    }
}
