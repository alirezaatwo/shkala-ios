import SwiftUI
import UIKit

// ===================================================================================
// «کیت طراحی» مشترک اپ - ترجمه‌ی SiteKit.kt اپ اندروید. همه‌ی صفحه‌ها از همین اجزا
// استفاده می‌کنن تا ظاهر کل اپ یکدست بمونه. قواعد کلی (مثل اندروید):
//  - پس‌زمینه‌ی صفحه: colors.background ؛ کادرها: colors.surface
//  - گوشه‌ی کادرها ۱۶، کادرهای کوچک ۱۲، پدینگ چپ/راست صفحه ۱۶
//  - آیکن‌ها فقط از Remix Icon
// ===================================================================================

/// رنگ‌های معنایی مشترک برای وضعیت‌ها (SiteStatusColors اندروید)
enum SiteStatusColors {
    static let Success = ShkColors.SiteSuccess
    static let Warning = Color(argb: 0xFFF2994A)
    static let Info = Color(argb: 0xFF2F80ED)
    static let Neutral = Color(argb: 0xFF8A94A6)
}

/// سایه‌ی متریال (elevation اندروید) - تقریب سایه‌ی shadow(elevation, ambientColor, spotColor)
extension View {
    func materialShadow(_ elevation: CGFloat, color: Color = .black, opacity: Double = 0.2) -> some View {
        shadow(color: color.opacity(opacity), radius: elevation * 0.75, x: 0, y: elevation * 0.4)
    }
}

// MARK: - خط‌چین

/// خط‌چین افقی (DashedDivider اندروید - معادل border: 1px dashed سایت)
struct DashedDivider: View {
    let color: Color
    var thickness: CGFloat = 1
    var dashLength: CGFloat = 4
    var gapLength: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.move(to: CGPoint(x: 0, y: thickness / 2))
                p.addLine(to: CGPoint(x: geo.size.width, y: thickness / 2))
            }
            .stroke(color, style: StrokeStyle(lineWidth: thickness, dash: [dashLength, gapLength]))
        }
        .frame(height: thickness)
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// خط‌چین جداکننده‌ی استاندارد (رنگ متناسب با تم)
struct SiteDashedDivider: View {
    @Environment(\.shkIsDark) private var isDark
    var body: some View {
        DashedDivider(color: isDark ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider)
    }
}

// MARK: - کادر

/// کادر استاندارد (روشن: سفید / تاریک: #353542) با گوشه‌ی ۱۶
struct SiteCard<Content: View>: View {
    var onClick: (() -> Void)? = nil
    var contentPadding: EdgeInsets = EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
    var radius: CGFloat = 16
    var color: Color? = nil
    var borderColor: Color? = nil
    @ViewBuilder let content: () -> Content

    @Environment(\.shkColors) private var colors

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let card = VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(contentPadding)
            .background(color ?? colors.surface)
            .clipShape(shape)
            .overlay { if let borderColor { shape.stroke(borderColor, lineWidth: 1) } }
        if let onClick {
            card.contentShape(shape).onTapGesture(perform: onClick)
        } else {
            card
        }
    }
}

extension EdgeInsets {
    static func all(_ v: CGFloat) -> EdgeInsets { EdgeInsets(top: v, leading: v, bottom: v, trailing: v) }
    static func hv(_ h: CGFloat, _ v: CGFloat) -> EdgeInsets { EdgeInsets(top: v, leading: h, bottom: v, trailing: h) }
}

// MARK: - آیکن

/// باکس آیکنِ رنگی کم‌رنگ (پیش‌فرض قرمز)
struct SiteIconBadge: View {
    let icon: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 20
    var tint: Color? = nil
    var radius: CGFloat = 12
    var filled: Bool = false

    @Environment(\.shkColors) private var colors

    var body: some View {
        let t = tint ?? colors.primary
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(filled ? t : t.opacity(0.1))
            RemixIcon(icon, tint: filled ? .white : t, size: iconSize)
        }
        .frame(width: size, height: size)
    }
}

/// دکمه‌ی آیکنیِ کادردار (مثل دکمه‌ی برگشت/منوی هدر)
struct SiteIconButton: View {
    let icon: String
    var contentDescription: String? = nil
    let onClick: () -> Void
    var size: CGFloat = 38
    var tint: Color? = nil
    var background: Color? = nil

    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(background ?? colors.surface)
                RemixIcon(icon, contentDescription: contentDescription, tint: tint ?? colors.onSurface, size: size * 0.55)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(SitePressStyle())
    }
}

// MARK: - دکمه‌ها

/// حالت فشرده‌شدن دکمه‌ها (معادل ripple ملایم اندروید)
struct SitePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// اسپینر دایره‌ای متریال (معادل CircularProgressIndicator نامعین اندروید)
struct MaterialSpinner: View {
    var color: Color
    var lineWidth: CGFloat = 2
    var size: CGFloat = 20

    @State private var rotate = false
    @State private var grow = false

    var body: some View {
        Circle()
            .trim(from: 0, to: grow ? 0.75 : 0.08)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .square))
            .rotationEffect(.degrees(rotate ? 360 : 0))
            .frame(width: size - lineWidth, height: size - lineWidth)
            .frame(width: size, height: size)
            .environment(\.layoutDirection, .leftToRight)
            .onAppear {
                withAnimation(.linear(duration: 1.333).repeatForever(autoreverses: false)) { rotate = true }
                withAnimation(.easeInOut(duration: 0.667).repeatForever(autoreverses: true)) { grow = true }
            }
    }
}

/// دکمه‌ی اصلی (قرمز پُر، ارتفاع ۴۸، گوشه‌ی ۱۲، سایه‌ی قرمز)
struct SitePrimaryButton: View {
    let text: String
    let onClick: () -> Void
    var icon: String? = nil
    var enabled: Bool = true
    var loading: Bool = false
    var height: CGFloat = 48
    var containerColor: Color? = nil
    var fontSize: CGFloat = 14
    /// تمام عرض (معادل Modifier.fillMaxWidth / weight)
    var fillWidth: Bool = false

    @Environment(\.shkColors) private var colors

    var body: some View {
        let container = containerColor ?? colors.primary
        let bg = enabled ? container : colors.surfaceVariant
        let fg = enabled ? Color.white : colors.onSurfaceVariant
        Button(action: { if enabled && !loading { onClick() } }) {
            HStack(spacing: 0) {
                if loading {
                    MaterialSpinner(color: fg, lineWidth: 2, size: 20)
                } else {
                    if let icon {
                        RemixIcon(icon, tint: fg, size: 19)
                        Spacer().frame(width: 8)
                    }
                    Text(text)
                        .shkFont(fontSize, .bold)
                        .foregroundColor(fg)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bg))
            .modifier(ConditionalShadow(enabled: enabled, color: container))
            .animation(.easeInOut(duration: 0.2), value: enabled)
        }
        .buttonStyle(SitePressStyle())
        .disabled(!enabled || loading)
    }
}

private struct ConditionalShadow: ViewModifier {
    let enabled: Bool
    let color: Color
    func body(content: Content) -> some View {
        if enabled {
            content.shadow(color: color.opacity(0.4), radius: 5, x: 0, y: 3)
        } else {
            content
        }
    }
}

/// دکمه‌ی ثانویه (زمینه‌ی کم‌رنگ از همون رنگ، متن رنگی)
struct SiteSecondaryButton: View {
    let text: String
    let onClick: () -> Void
    var icon: String? = nil
    var color: Color? = nil
    var enabled: Bool = true
    var loading: Bool = false
    var height: CGFloat = 48
    var fontSize: CGFloat = 14
    var fillWidth: Bool = false

    @Environment(\.shkColors) private var colors

    var body: some View {
        let c = color ?? colors.primary
        Button(action: { if enabled && !loading { onClick() } }) {
            HStack(spacing: 0) {
                if loading {
                    MaterialSpinner(color: c, lineWidth: 2, size: 20)
                } else {
                    if let icon {
                        RemixIcon(icon, tint: c, size: 19)
                        Spacer().frame(width: 8)
                    }
                    Text(text)
                        .shkFont(fontSize, .bold)
                        .foregroundColor(c.opacity(enabled ? 1 : 0.5))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: fillWidth ? .infinity : nil)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(c.opacity(enabled ? 0.1 : 0.05)))
        }
        .buttonStyle(SitePressStyle())
        .disabled(!enabled || loading)
    }
}

// MARK: - فیلدها

/// برچسب بالای فیلد - فیلدهای الزامی با ستاره‌ی قرمز
struct SiteFieldLabel: View {
    let text: String
    var necessary: Bool = false

    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            Text(text).shkFont(12, .medium).foregroundColor(colors.onSurface)
            if necessary { Text(" *").shkFont(12, .bold).foregroundColor(colors.primary) }
        }
        .padding(.bottom, 6)
    }
}

/// نوع صفحه‌کلید فیلد (معادل KeyboardType اندروید)
enum SiteKeyboard {
    case text, phone, number, password, email

    var uiKeyboard: UIKeyboardType {
        switch self {
        case .text, .password: return .default
        case .phone: return .phonePad
        case .number: return .numberPad
        case .email: return .emailAddress
        }
    }
}

/// فیلد ورودی استاندارد اپ: پس‌زمینه‌ی ملایم (surfaceVariant)، گوشه‌ی ۱۲، بدون حاشیه در حالت
/// عادی، حاشیه‌ی قرمز هنگام فوکوس یا خطا. برچسب بالای فیلد و متن راهنما/خطا زیرش.
struct SiteTextField<Trailing: View>: View {
    @Binding var value: String
    var label: String? = nil
    var placeholder: String = ""
    var necessary: Bool = false
    var leadingIcon: String? = nil
    var singleLine: Bool = true
    var minHeight: CGFloat = 46
    var keyboard: SiteKeyboard = .text
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .done
    var onSubmit: () -> Void = {}
    var secure: Bool = false
    var isError: Bool = false
    var helperText: String? = nil
    var enabled: Bool = true
    var textAlign: TextAlignment = .leading
    var fieldColor: Color? = nil
    var maxLength: Int? = nil
    /// فیلتر ورودی (مثلاً فقط رقم) - قبل از محدودیت طول اعمال می‌شه
    var filter: ((String) -> String)? = nil
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.shkColors) private var colors
    @FocusState private var focused: Bool

    var body: some View {
        let borderColor: Color = isError ? colors.error : (focused ? colors.primary : .clear)
        let fill = fieldColor ?? colors.surfaceVariant
        VStack(alignment: .leading, spacing: 0) {
            if let label { SiteFieldLabel(text: label, necessary: necessary) }
            HStack(alignment: singleLine ? .center : .top, spacing: 0) {
                if let leadingIcon {
                    RemixIcon(leadingIcon, tint: focused ? colors.primary : colors.onSurfaceVariant, size: 18)
                    Spacer().frame(width: 8)
                }
                ZStack(alignment: singleLine ? .leading : .topLeading) {
                    if value.isEmpty && !placeholder.isEmpty {
                        Text(placeholder)
                            .shkFont(13)
                            .foregroundColor(colors.onSurfaceVariant.opacity(0.7))
                            .multilineTextAlignment(textAlign)
                            .lineLimit(singleLine ? 1 : nil)
                            .frame(maxWidth: .infinity, alignment: frameAlignment)
                            .allowsHitTesting(false)
                    }
                    field
                }
                .frame(maxWidth: .infinity)
                if Trailing.self != EmptyView.self {
                    Spacer().frame(width: 6)
                    trailing()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(minHeight: minHeight)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(enabled ? fill : fill.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(borderColor, lineWidth: 1))
            .animation(.easeInOut(duration: 0.2), value: focused)
            .animation(.easeInOut(duration: 0.2), value: isError)
            .contentShape(Rectangle())
            .onTapGesture { focused = true }

            if let helperText, !helperText.isEmpty {
                Text(helperText)
                    .shkFont(11, lineHeight: 18)
                    .foregroundColor(isError ? colors.error : colors.onSurfaceVariant)
                    .padding(.top, 4)
                    .padding(.leading, 4)
            }
        }
    }

    private var frameAlignment: Alignment {
        switch textAlign {
        case .center: return .center
        case .trailing: return .trailing
        default: return .leading
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: { value },
            set: { new in
                var v = filter?(new) ?? new
                if let maxLength, v.count > maxLength {
                    // مثل اندروید: ورودیِ بلندتر از حد پذیرفته نمی‌شه
                    if value.count <= maxLength { v = value } else { v = String(v.prefix(maxLength)) }
                }
                value = v
            }
        )
    }

    @ViewBuilder
    private var field: some View {
        Group {
            if secure {
                SecureField("", text: binding)
            } else if singleLine {
                TextField("", text: binding)
            } else {
                if #available(iOS 16.0, *) {
                    TextField("", text: binding, axis: .vertical)
                } else {
                    TextField("", text: binding)
                }
            }
        }
        .font(ShkFont.yekan(13))
        .foregroundColor(colors.onSurface)
        .tint(colors.primary)
        .multilineTextAlignment(textAlign)
        .keyboardType(keyboard.uiKeyboard)
        .textContentType(textContentType)
        .autocorrectionDisabled(keyboard != .text)
        .textInputAutocapitalization(.never)
        .submitLabel(submitLabel)
        .onSubmit(onSubmit)
        .focused($focused)
        .disabled(!enabled)
    }
}

extension SiteTextField where Trailing == EmptyView {
    init(
        value: Binding<String>, label: String? = nil, placeholder: String = "", necessary: Bool = false,
        leadingIcon: String? = nil, singleLine: Bool = true, minHeight: CGFloat = 46,
        keyboard: SiteKeyboard = .text, textContentType: UITextContentType? = nil,
        submitLabel: SubmitLabel = .done, onSubmit: @escaping () -> Void = {}, secure: Bool = false,
        isError: Bool = false, helperText: String? = nil, enabled: Bool = true,
        textAlign: TextAlignment = .leading, fieldColor: Color? = nil, maxLength: Int? = nil,
        filter: ((String) -> String)? = nil
    ) {
        self.init(
            value: value, label: label, placeholder: placeholder, necessary: necessary, leadingIcon: leadingIcon,
            singleLine: singleLine, minHeight: minHeight, keyboard: keyboard, textContentType: textContentType,
            submitLabel: submitLabel, onSubmit: onSubmit, secure: secure, isError: isError, helperText: helperText,
            enabled: enabled, textAlign: textAlign, fieldColor: fieldColor, maxLength: maxLength, filter: filter,
            trailing: { EmptyView() }
        )
    }
}

// MARK: - تگ و ردیف‌ها

/// تگ وضعیت رنگی (مثل «پرداخت شده»، «در انتظار»)
struct SiteStatusChip: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            if let icon {
                RemixIcon(icon, tint: color, size: 13)
                Spacer().frame(width: 4)
            }
            Text(text).shkFont(11, .bold, lineHeight: 16).foregroundColor(color).lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.12)))
    }
}

/// ردیف «برچسب ..... مقدار» برای خلاصه‌ها (فاکتور، جزئیات سفارش و ...)
struct SiteKeyValueRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var valueColor: Color? = nil
    var emphasized: Bool = false

    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            if let icon {
                RemixIcon(icon, tint: colors.onSurfaceVariant, size: 16)
                Spacer().frame(width: 6)
            }
            Text(label)
                .shkFont(emphasized ? 13 : 12, emphasized ? .bold : .normal)
                .foregroundColor(emphasized ? colors.onSurface : colors.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .shkFont(emphasized ? 15 : 13, emphasized ? .bold : .medium)
                .foregroundColor(valueColor ?? colors.onSurface)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 6)
    }
}

/// ردیف منو با آیکن در کادر رنگی، عنوان، توضیح اختیاری و فلش (برای لیست‌ها و تنظیمات)
struct SiteMenuRow<Trailing: View>: View {
    let icon: String
    let title: String
    let onClick: (() -> Void)?
    var subtitle: String? = nil
    var tint: Color? = nil
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.shkColors) private var colors

    var body: some View {
        let row = HStack(spacing: 0) {
            SiteIconBadge(icon: icon, size: 36, iconSize: 19, tint: tint ?? colors.primary, radius: 11)
            Spacer().frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).shkFont(13, .medium).foregroundColor(colors.onSurface)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).shkFont(11, lineHeight: 18).foregroundColor(colors.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
            if onClick != nil {
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        if let onClick {
            Button(action: onClick) { row }.buttonStyle(SitePressStyle())
        } else {
            row
        }
    }
}

extension SiteMenuRow where Trailing == EmptyView {
    init(icon: String, title: String, onClick: (() -> Void)?, subtitle: String? = nil, tint: Color? = nil) {
        self.init(icon: icon, title: title, onClick: onClick, subtitle: subtitle, tint: tint, trailing: { EmptyView() })
    }
}

// MARK: - تب قرصی

/// کنترل تبِ قرصی: کادر سفید، تب فعال قرص قرمز با سایه‌ی قرمز
struct SiteSegmentedTabs: View {
    let tabs: [(String, String?)]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                let selected = index == selectedIndex
                let fg = selected ? Color.white : colors.onSurfaceVariant
                Button(action: { onSelect(index) }) {
                    HStack(spacing: 0) {
                        if let icon = tab.1 {
                            RemixIcon(icon, tint: fg, size: 18)
                            Spacer().frame(width: 6)
                        }
                        Text(tab.0).shkFont(13, selected ? .bold : .medium).foregroundColor(fg).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? colors.primary : Color.clear)
                            .shadow(color: selected ? colors.primary.opacity(0.5) : .clear, radius: 5, x: 0, y: 3)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.25), value: selected)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(colors.surface))
    }
}

// MARK: - لودینگ

/// لودینگ برندِ اپ: حلقه‌ی قرمزِ چرخان دور یک دایره‌ی تپنده، با متن اختیاری زیرش
struct SiteLoading: View {
    var message: String? = nil
    var subMessage: String? = nil
    var icon: String? = nil
    var size: CGFloat = 72

    @Environment(\.shkColors) private var colors
    @State private var rotating = false
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().stroke(colors.primary.opacity(0.12), lineWidth: 4).padding(2)
                Circle()
                    .trim(from: 0, to: 0.28)
                    .stroke(colors.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .padding(2)
                    .rotationEffect(.degrees(-90 + (rotating ? 360 : 0)))
                ZStack {
                    Circle().fill(colors.primary.opacity(0.1))
                    if let icon {
                        RemixIcon(icon, tint: colors.primary, size: size * 0.3)
                    } else {
                        Circle().fill(colors.primary).frame(width: size * 0.18, height: size * 0.18)
                    }
                }
                .frame(width: size * 0.62, height: size * 0.62)
                .scaleEffect(pulsing ? 1.05 : 0.85)
            }
            .frame(width: size, height: size)
            .environment(\.layoutDirection, .leftToRight)
            if let message, !message.isEmpty {
                Spacer().frame(height: 16)
                Text(message).shkFont(14, .bold).foregroundColor(colors.onBackground).multilineTextAlignment(.center)
            }
            if let subMessage, !subMessage.isEmpty {
                Spacer().frame(height: 6)
                Text(subMessage).shkFont(12, lineHeight: 20).foregroundColor(colors.onSurfaceVariant).multilineTextAlignment(.center)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { rotating = true }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulsing = true }
        }
    }
}

/// لودینگ تمام‌صفحه (وسط‌چین)
struct SiteFullScreenLoading: View {
    var message: String? = nil
    var subMessage: String? = nil
    var icon: String? = nil

    @Environment(\.shkColors) private var colors

    var body: some View {
        ZStack {
            colors.background
            SiteLoading(message: message, subMessage: subMessage, icon: icon).padding(24)
        }
    }
}

// MARK: - مودال

/// سرتیتر استاندارد باتم‌شیت‌ها: آیکن، عنوان و دکمه‌ی بستن کادردار
struct SiteSheetHeader: View {
    let title: String
    var onClose: (() -> Void)? = nil
    var icon: String? = nil

    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            if let icon {
                SiteIconBadge(icon: icon, size: 34, iconSize: 18, radius: 10)
                Spacer().frame(width: 10)
            }
            Text(title).shkFont(15, .bold).foregroundColor(colors.onSurface).frame(maxWidth: .infinity, alignment: .leading)
            if let onClose {
                Button(action: onClose) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surfaceVariant)
                        RemixIcon(RemixIcons.CloseLine, contentDescription: "بستن", tint: colors.onSurface, size: 18)
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(SitePressStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// مودال استاندارد اپ (SiteDialog اندروید): کادر گوشه‌گرد ۲۴، آیکن دایره‌ای بالای مودال، عنوان
/// بولد، متن/محتوا و دکمه‌ها (اصلی قرمز + ثانویه). روی صفحه با .siteDialog(isPresented:) نمایش داده می‌شه.
struct SiteDialogContent<Content: View>: View {
    let title: String
    var icon: String? = nil
    var iconTint: Color? = nil
    var message: String? = nil
    var confirmText: String? = nil
    var onConfirm: (() -> Void)? = nil
    var confirmColor: Color? = nil
    var confirmLoading: Bool = false
    var confirmEnabled: Bool = true
    var dismissText: String? = nil
    var onDismiss: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.shkColors) private var colors

    var body: some View {
        let tint = iconTint ?? colors.primary
        ScrollView {
            VStack(spacing: 0) {
                if let icon {
                    ZStack {
                        Circle().fill(tint.opacity(0.08)).frame(width: 64, height: 64)
                        Circle().fill(tint.opacity(0.14)).frame(width: 46, height: 46)
                        RemixIcon(icon, tint: tint, size: 24)
                    }
                    Spacer().frame(height: 12)
                }
                Text(title)
                    .shkFont(16, .bold)
                    .foregroundColor(colors.onSurface)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                if let message, !message.isEmpty {
                    Spacer().frame(height: 8)
                    Text(message)
                        .shkFont(13, lineHeight: 23)
                        .foregroundColor(colors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                if Content.self != EmptyView.self {
                    Spacer().frame(height: 14)
                    VStack(alignment: .leading, spacing: 0) { content() }.frame(maxWidth: .infinity)
                }
                if confirmText != nil || dismissText != nil {
                    Spacer().frame(height: 20)
                    HStack(spacing: 10) {
                        if let confirmText {
                            SitePrimaryButton(
                                text: confirmText, onClick: { onConfirm?() }, enabled: confirmEnabled,
                                loading: confirmLoading, height: 46, containerColor: confirmColor ?? colors.primary, fillWidth: true
                            )
                        }
                        if let dismissText {
                            SiteSecondaryButton(
                                text: dismissText, onClick: { onDismiss?() }, color: colors.onSurfaceVariant,
                                height: 46, fillWidth: true
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 420)
        .background(colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 24)
    }
}

extension SiteDialogContent where Content == EmptyView {
    init(
        title: String, icon: String? = nil, iconTint: Color? = nil, message: String? = nil,
        confirmText: String? = nil, onConfirm: (() -> Void)? = nil, confirmColor: Color? = nil,
        confirmLoading: Bool = false, confirmEnabled: Bool = true,
        dismissText: String? = nil, onDismiss: (() -> Void)? = nil
    ) {
        self.init(
            title: title, icon: icon, iconTint: iconTint, message: message, confirmText: confirmText,
            onConfirm: onConfirm, confirmColor: confirmColor, confirmLoading: confirmLoading,
            confirmEnabled: confirmEnabled, dismissText: dismissText, onDismiss: onDismiss,
            content: { EmptyView() }
        )
    }
}

/// لایه‌ی نمایش مودال روی صفحه (پس‌زمینه‌ی تیره‌ی نیمه‌شفاف مثل Dialog اندروید)
struct SiteDialogHost<Dialog: View>: ViewModifier {
    @Binding var isPresented: Bool
    var dismissOnClickOutside: Bool = true
    @ViewBuilder let dialog: () -> Dialog

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture { if dismissOnClickOutside { isPresented = false } }
                    .transition(.opacity)
                dialog()
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: isPresented)
    }
}

extension View {
    func siteDialog<D: View>(isPresented: Binding<Bool>, dismissOnClickOutside: Bool = true, @ViewBuilder dialog: @escaping () -> D) -> some View {
        modifier(SiteDialogHost(isPresented: isPresented, dismissOnClickOutside: dismissOnClickOutside, dialog: dialog))
    }
}

/**
 * مودال‌های صفحه‌ها (SiteDialog اندروید روی کل پنجره رسم می‌شه، حتی روی نوار پایین): صفحه‌ها مودالشون رو
 * به این مرکز می‌دن و AppRoot یک‌بار بالای همه‌چیز رسمش می‌کنه.
 */
@MainActor
final class ShkDialogCenter: ObservableObject {
    static let shared = ShkDialogCenter()
    @Published private(set) var dialog: AnyView? = nil
    /// معادل onDismissRequest اندروید: بسته شدن با لمس بیرون مودال
    private var onDismissRequest: (() -> Void)? = nil

    func show<V: View>(onDismissRequest: (() -> Void)? = nil, @ViewBuilder _ content: () -> V) {
        self.onDismissRequest = onDismissRequest
        dialog = AnyView(content())
    }

    func dismiss() {
        dialog = nil
        onDismissRequest = nil
    }

    /// بسته شدن با لمس بیرون: اول callback صفحه، بعد بستن
    func dismissFromOutside() {
        let callback = onDismissRequest
        dismiss()
        callback?()
    }
}
