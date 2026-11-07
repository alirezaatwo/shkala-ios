import SwiftUI

// معادل ui/common/JalaliDatePicker.kt
// تقویم شمسی: تبدیل دقیق شمسی↔میلادی (الگوریتم استاندارد) + دیالوگ انتخاب تاریخ هم‌سبک کیت

/** یک تاریخ شمسی (ماه ۱ تا ۱۲) */
struct JalaliDate: Equatable, Comparable, Hashable {
    let year: Int
    let month: Int
    let day: Int

    init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /** قالب ارسالی به سرور: yyyy/MM/dd با ارقام لاتین (مثل 1375/05/02) */
    func format() -> String { String(format: "%04d/%02d/%02d", year, month, day) }

    static func < (a: JalaliDate, b: JalaliDate) -> Bool {
        if a.year != b.year { return a.year < b.year }
        if a.month != b.month { return a.month < b.month }
        return a.day < b.day
    }
}

enum JalaliCalendar {
    static let monthNames = [
        "فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
        "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند",
    ]

    /** حرف اول روزهای هفته از شنبه */
    static let weekdayInitials = ["ش", "ی", "د", "س", "چ", "پ", "ج"]

    /** نام کامل روزهای هفته از شنبه */
    static let weekdayNames = ["شنبه", "یکشنبه", "دوشنبه", "سه‌شنبه", "چهارشنبه", "پنجشنبه", "جمعه"]

    /** میلادی ← شمسی */
    static func gregorianToJalali(_ gy: Int, _ gm: Int, _ gd: Int) -> JalaliDate {
        let gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        let gy2 = gm > 2 ? gy + 1 : gy
        var days = 355666 + 365 * gy + (gy2 + 3) / 4 - (gy2 + 99) / 100 + (gy2 + 399) / 400 + gd + gdm[gm - 1]
        var jy = -1595 + 33 * (days / 12053)
        days %= 12053
        jy += 4 * (days / 1461)
        days %= 1461
        if days > 365 {
            jy += (days - 1) / 365
            days = (days - 1) % 365
        }
        let jm: Int
        let jd: Int
        if days < 186 {
            jm = 1 + days / 31
            jd = 1 + days % 31
        } else {
            jm = 7 + (days - 186) / 30
            jd = 1 + (days - 186) % 30
        }
        return JalaliDate(jy, jm, jd)
    }

    /** شمسی ← میلادی؛ خروجی: [سال، ماه (۱ تا ۱۲)، روز] */
    static func jalaliToGregorian(_ jy: Int, _ jm: Int, _ jd: Int) -> [Int] {
        let jy1 = jy + 1595
        var days = -355668 + 365 * jy1 + (jy1 / 33) * 8 + ((jy1 % 33) + 3) / 4 + jd +
            (jm < 7 ? (jm - 1) * 31 : (jm - 7) * 30 + 186)
        var gy = 400 * (days / 146097)
        days %= 146097
        if days > 36524 {
            days -= 1
            gy += 100 * (days / 36524)
            days %= 36524
            if days >= 365 { days += 1 }
        }
        gy += 4 * (days / 1461)
        days %= 1461
        if days > 365 {
            gy += (days - 1) / 365
            days = (days - 1) % 365
        }
        var gd = days + 1
        let leap = (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0
        let monthDays = [0, 31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        var gm = 0
        while gm < 13 && gd > monthDays[gm] {
            gd -= monthDays[gm]
            gm += 1
        }
        return [gy, gm, gd]
    }

    /** کبیسه بودن سال شمسی (۳۰ اسفند وجود دارد؟) */
    static func isLeap(_ jy: Int) -> Bool {
        let g = jalaliToGregorian(jy, 12, 30)
        return gregorianToJalali(g[0], g[1], g[2]) == JalaliDate(jy, 12, 30)
    }

    /** طول ماه: ۶ ماه اول ۳۱، ۵ ماه بعد ۳۰، اسفند ۲۹ یا ۳۰ */
    static func monthLength(_ jy: Int, _ jm: Int) -> Int {
        if jm <= 6 { return 31 }
        if jm <= 11 { return 30 }
        return isLeap(jy) ? 30 : 29
    }

    private static var gregorian: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }

    /** شماره‌ی روز هفته (شنبه = ۰ ... جمعه = ۶) */
    static func weekdayIndex(_ date: JalaliDate) -> Int {
        let g = jalaliToGregorian(date.year, date.month, date.day)
        let cal = gregorian
        guard let d = cal.date(from: DateComponents(year: g[0], month: g[1], day: g[2])) else { return 0 }
        // یکشنبه=۱ ... شنبه=۷ ← شنبه=۰
        return cal.component(.weekday, from: d) % 7
    }

    static func today() -> JalaliDate {
        let c = gregorian.dateComponents([.year, .month, .day], from: Date())
        return gregorianToJalali(c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    /** خواندن رشته‌ای مثل 1375/05/02 (ارقام فارسی/عربی هم قبول) ؛ نامعتبر ← nil */
    static func parse(_ text: String?) -> JalaliDate? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var normalized = ""
        for ch in text.trimmingCharacters(in: .whitespacesAndNewlines) {
            if let v = ch.unicodeScalars.first?.value, ch.unicodeScalars.count == 1 {
                if (0x06F0...0x06F9).contains(v) { normalized.append(Character(UnicodeScalar(0x30 + v - 0x06F0)!)); continue }
                if (0x0660...0x0669).contains(v) { normalized.append(Character(UnicodeScalar(0x30 + v - 0x0660)!)); continue }
            }
            if ch == "-" || ch == "." { normalized.append("/") } else { normalized.append(ch) }
        }
        let parts = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        if y < 1 || !(1...12).contains(m) || d < 1 || d > monthLength(y, m) { return nil }
        return JalaliDate(y, m, d)
    }

    /** متن نمایشی: «شنبه ۴ مهر ۱۴۰۵» */
    static func displayText(_ date: JalaliDate) -> String {
        "\(weekdayNames[weekdayIndex(date)]) \(date.day.toPersianDigits()) \(monthNames[date.month - 1]) \(date.year.toPersianDigits())"
    }
}

private enum PickerMode { case days, months, years }

/**
 * دیالوگ انتخاب تاریخ شمسی (روی SiteDialog):
 * سرتیتر تاریخ انتخاب‌شده، انتخاب ماه/سال، جدول ۷ستونه‌ی روزها از شنبه،
 * امروز با حلقه و روز انتخاب‌شده با دایره‌ی قرمز.
 * تفاوت iOS: با ShkDialogCenter.shared.show نمایش داده می‌شه (معادل Dialog کامپوز).
 */
struct JalaliDatePickerDialog: View {
    let initialDate: JalaliDate?
    let onDismiss: () -> Void
    let onConfirm: (JalaliDate) -> Void
    var title: String = "انتخاب تاریخ"
    var defaultDate: JalaliDate = JalaliDate(1380, 1, 1)
    var minDate: JalaliDate? = nil
    var maxDate: JalaliDate? = nil
    var onClear: (() -> Void)? = nil

    @Environment(\.shkColors) private var colors
    private let today = JalaliCalendar.today()
    @State private var selected: JalaliDate?
    @State private var viewYear: Int
    @State private var viewMonth: Int
    @State private var mode: PickerMode = .days

    init(
        initialDate: JalaliDate?,
        onDismiss: @escaping () -> Void,
        onConfirm: @escaping (JalaliDate) -> Void,
        title: String = "انتخاب تاریخ",
        defaultDate: JalaliDate = JalaliDate(1380, 1, 1),
        minDate: JalaliDate? = nil,
        maxDate: JalaliDate? = nil,
        onClear: (() -> Void)? = nil
    ) {
        self.initialDate = initialDate
        self.onDismiss = onDismiss
        self.onConfirm = onConfirm
        self.title = title
        self.defaultDate = defaultDate
        self.minDate = minDate
        self.maxDate = maxDate
        self.onClear = onClear
        let today = JalaliCalendar.today()
        let minYear = minDate?.year ?? 1300
        let maxYear = maxDate?.year ?? (today.year + 10)
        let start = initialDate ?? defaultDate
        _selected = State(initialValue: initialDate)
        _viewYear = State(initialValue: min(max(start.year, minYear), maxYear))
        _viewMonth = State(initialValue: start.month)
    }

    private var minYear: Int { minDate?.year ?? 1300 }
    private var maxYear: Int { maxDate?.year ?? (today.year + 10) }

    private func isAllowed(_ d: JalaliDate) -> Bool {
        (minDate == nil || d >= minDate!) && (maxDate == nil || d <= maxDate!)
    }

    private func monthAllowed(_ y: Int, _ m: Int) -> Bool {
        let first = JalaliDate(y, m, 1)
        let last = JalaliDate(y, m, JalaliCalendar.monthLength(y, m))
        return (maxDate == nil || first <= maxDate!) && (minDate == nil || last >= minDate!)
    }

    var body: some View {
        let primary = colors.primary
        let canPrev = viewYear > minYear || (viewYear == minYear && viewMonth > 1)
        let canNext = viewYear < maxYear || (viewYear == maxYear && viewMonth < 12)

        SiteDialogContent(
            title: title,
            confirmText: "تأیید",
            onConfirm: { if let s = selected { onConfirm(s) } },
            confirmEnabled: selected != nil,
            dismissText: "انصراف",
            onDismiss: onDismiss
        ) {
            VStack(spacing: 0) {
                // ---- سرتیتر: تاریخ انتخاب‌شده ----
                HStack(spacing: 0) {
                    SiteIconBadge(icon: RemixIcons.CalendarCheckLine, size: 38, iconSize: 20, radius: 12, filled: true)
                    Spacer().frame(width: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("تاریخ انتخاب‌شده").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                        Text(selected.map { JalaliCalendar.displayText($0) } ?? "یک روز را انتخاب کنید")
                            .shkFont(15, .bold)
                            .foregroundColor(selected != nil ? primary : colors.onSurface)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(primary.opacity(0.08)))

                Spacer().frame(height: 12)

                // ---- ردیف ماه/سال با فلش‌های ماه قبل و بعد ----
                HStack(spacing: 6) {
                    JalaliNavArrow(icon: RemixIcons.ArrowRightSLine, description: "ماه قبل", enabled: canPrev && mode == .days) {
                        if viewMonth == 1 { viewMonth = 12; viewYear -= 1 } else { viewMonth -= 1 }
                    }
                    JalaliHeaderChip(text: JalaliCalendar.monthNames[viewMonth - 1], active: mode == .months) {
                        mode = mode == .months ? .days : .months
                    }
                    JalaliHeaderChip(text: viewYear.toPersianDigits(), active: mode == .years) {
                        mode = mode == .years ? .days : .years
                    }
                    JalaliNavArrow(icon: RemixIcons.ArrowLeftSLine, description: "ماه بعد", enabled: canNext && mode == .days) {
                        if viewMonth == 12 { viewMonth = 1; viewYear += 1 } else { viewMonth += 1 }
                    }
                }

                Spacer().frame(height: 12)

                Group {
                    switch mode {
                    case .days: daysGrid
                    case .months: monthsGrid
                    case .years: yearsGrid
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.2), value: mode)

                // ---- رفتن به امروز / حذف تاریخ ----
                Spacer().frame(height: 8)
                HStack(spacing: 0) {
                    if isAllowed(today) {
                        JalaliTextAction(text: "امروز", icon: RemixIcons.CalendarLine, color: primary) {
                            viewYear = today.year
                            viewMonth = today.month
                            mode = .days
                        }
                    }
                    Spacer(minLength: 0)
                    if let onClear, initialDate != nil {
                        JalaliTextAction(text: "حذف تاریخ", icon: RemixIcons.DeleteBinLine, color: colors.onSurfaceVariant, onClick: onClear)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var daysGrid: some View {
        let primary = colors.primary
        VStack(spacing: 0) {
            // سرستون روزهای هفته (از شنبه)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { index in
                    Text(JalaliCalendar.weekdayInitials[index])
                        .shkFont(12, .bold)
                        .foregroundColor(index == 6 ? primary : colors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            let length = JalaliCalendar.monthLength(viewYear, viewMonth)
            let offset = JalaliCalendar.weekdayIndex(JalaliDate(viewYear, viewMonth, 1))
            let rows = (offset + length + 6) / 7
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { c in
                        let dayNum = r * 7 + c - offset + 1
                        ZStack {
                            if (1...length).contains(dayNum) {
                                let date = JalaliDate(viewYear, viewMonth, dayNum)
                                JalaliDayCell(
                                    day: dayNum,
                                    isSelected: date == selected,
                                    isToday: date == today,
                                    isFriday: c == 6,
                                    enabled: isAllowed(date),
                                    onClick: { selected = date }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                    }
                }
            }
        }
        .id("days-\(viewYear)-\(viewMonth)")
    }

    private var monthsGrid: some View {
        // جدول ۳×۴ ماه‌ها
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { c in
                        let m = r * 3 + c + 1
                        JalaliGridChip(text: JalaliCalendar.monthNames[m - 1], selected: m == viewMonth, enabled: monthAllowed(viewYear, m)) {
                            viewMonth = m
                            mode = .days
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    private var yearsGrid: some View {
        // فهرست سال‌ها (جدیدترین بالا) با ارتفاع ثابت
        let years = Array(stride(from: maxYear, through: minYear, by: -1))
        return ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(years, id: \.self) { y in
                        JalaliGridChip(text: y.toPersianDigits(), selected: y == viewYear, enabled: true) {
                            viewYear = y
                            // اگر ماه فعلی در این سال مجاز نبود، به نزدیک‌ترین ماه مجاز برو
                            if !monthAllowed(y, viewMonth) {
                                viewMonth = (1...12).first { monthAllowed(y, $0) } ?? 1
                            }
                            mode = .months
                        }
                        .id(y)
                    }
                }
            }
            .frame(height: 248)
            .onAppear {
                let idx = max((years.firstIndex(of: viewYear) ?? 0) - 4, 0)
                if idx < years.count { proxy.scrollTo(years[idx], anchor: .top) }
            }
        }
    }
}

private struct JalaliNavArrow: View {
    let icon: String
    let description: String
    let enabled: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            RemixIcon(icon, contentDescription: description, tint: colors.onSurface, size: 20)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

private struct JalaliHeaderChip: View {
    let text: String
    let active: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        Button(action: onClick) {
            HStack(spacing: 4) {
                Text(text)
                    .shkFont(13, .bold)
                    .foregroundColor(active ? primary : colors.onSurface)
                    .lineLimit(1)
                RemixIcon(active ? RemixIcons.ArrowUpSLine : RemixIcons.ArrowDownSLine, tint: active ? primary : colors.onSurfaceVariant, size: 16)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(active ? primary.opacity(0.1) : colors.surfaceVariant))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(active ? primary : Color.clear, lineWidth: 1))
            .animation(.easeInOut(duration: 0.2), value: active)
        }
        .buttonStyle(.plain)
    }
}

private struct JalaliDayCell: View {
    let day: Int
    let isSelected: Bool
    let isToday: Bool
    let isFriday: Bool
    let enabled: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let textColor: Color = isSelected ? .white : ((isToday || isFriday) ? primary : colors.onSurface)
        Button(action: onClick) {
            Text(day.toPersianDigits())
                .shkFont(13, (isSelected || isToday) ? .bold : .medium)
                .foregroundColor(textColor)
                .frame(width: 36, height: 36)
                .background(Circle().fill(isSelected ? primary : Color.clear))
                .overlay(Circle().stroke((isToday && !isSelected) ? primary : Color.clear, lineWidth: (isToday && !isSelected) ? 1.5 : 0))
                .contentShape(Circle())
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }
}

private struct JalaliGridChip: View {
    let text: String
    let selected: Bool
    let enabled: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            Text(text)
                .shkFont(13, selected ? .bold : .medium)
                .foregroundColor(selected ? .white : colors.onSurface)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? colors.primary : colors.surfaceVariant))
                .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

private struct JalaliTextAction: View {
    let text: String
    let icon: String
    let color: Color
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 4) {
                RemixIcon(icon, tint: color, size: 16)
                Text(text).shkFont(12, .bold).foregroundColor(color)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
