import SwiftUI
import UIKit

/// وضعیت نمایشی خانه‌های کد: عادی، تایید شده (سبز)، اشتباه (قرمز)
enum OtpBoxStatus { case none, success, error }

/// فیلد ورود کد تایید به شکل چند خونه‌ی جدا - معادل OtpBoxInput اپ اندروید.
/// از یک فیلد متنی نامرئی زیرِ کار استفاده می‌کنه که مقدارش رو تو چند تا "خونه" نمایش می‌ده -
/// این‌جوری کیبورد، پیست، و پرکردن خودکار (پیشنهاد کد پیامک بالای کیبورد iOS) هم درست کار می‌کنن.
///
/// انیمیشن‌ها: کد درست → خانه‌ها یکی‌یکی (موجی) سبز می‌شن و کمی می‌پرن؛ کد اشتباه → کل ردیف
/// می‌لرزه (با لرزش کوتاه گوشی) و خانه‌ها قرمز می‌شن. هر بار که [shakeKey] زیاد بشه، لرزش تکرار می‌شه.
struct OtpBoxInput: View {
    let code: String
    let length: Int
    let onCodeChange: (String) -> Void
    let isError: Bool
    var status: OtpBoxStatus = .none
    var shakeKey: Int = 0

    @State private var shakeStart: Date? = nil
    @FocusState private var focused: Bool

    // همان keyframes اندروید (۴۸۰ میلی‌ثانیه، بین فریم‌ها خطی)
    private static let shakeFrames: [(ms: Double, x: CGFloat)] = [
        (0, 0), (50, -16), (110, 16), (170, -12), (230, 12), (290, -7), (350, 7), (410, -3), (480, 0),
    ]

    private static func shakeOffset(at ms: Double) -> CGFloat {
        guard ms > 0 else { return 0 }
        let frames = shakeFrames
        for i in 1..<frames.count where ms <= frames[i].ms {
            let a = frames[i - 1], b = frames[i]
            let t = (ms - a.ms) / (b.ms - a.ms)
            return a.x + (b.x - a.x) * CGFloat(t)
        }
        return 0
    }

    private var effectiveStatus: OtpBoxStatus {
        if status != .none { return status }
        return isError ? .error : .none
    }

    var body: some View {
        TimelineView(.animation(paused: shakeStart == nil)) { context in
            let ms = shakeStart.map { context.date.timeIntervalSince($0) * 1000 } ?? 0
            content
                .offset(x: ms < 480 ? Self.shakeOffset(at: ms) : 0)
        }
        // اعداد باید همیشه از چپ به راست خونده بشن، حتی تو اپ راست‌چین
        .environment(\.layoutDirection, .leftToRight)
        .onChange(of: shakeKey) { key in
            guard key > 0 else { return }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            let start = Date()
            shakeStart = start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if shakeStart == start { shakeStart = nil }
            }
        }
    }

    private var content: some View {
        ZStack {
            // فیلد نامرئی: کیبورد عددی + پیشنهاد خودکار کد پیامک (oneTimeCode)
            TextField("", text: Binding(
                get: { code },
                set: { new in
                    if status == .success { return }
                    let digitsOnly = String(new.map { Self.latinDigit($0) }
                        .filter { $0.isASCII && $0.isNumber }
                        .prefix(length))
                    onCodeChange(digitsOnly)
                }
            ))
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .foregroundColor(.clear)
            .tint(.clear)
            .focused($focused)
            .opacity(0.02)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 10) {
                ForEach(0..<length, id: \.self) { index in
                    let chars = Array(code)
                    DigitBox(
                        digit: index < chars.count ? String(chars[index]) : "",
                        index: index,
                        isActive: index == code.count,
                        status: effectiveStatus
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    /// ارقام فارسی کیبورد فارسی → لاتین (سرور کد لاتین می‌خواد)
    private static func latinDigit(_ c: Character) -> Character {
        let persian: [Character] = Array("۰۱۲۳۴۵۶۷۸۹")
        let arabic: [Character] = Array("٠١٢٣٤٥٦٧٨٩")
        if let i = persian.firstIndex(of: c) ?? arabic.firstIndex(of: c) { return Character(String(i)) }
        return c
    }
}

private struct DigitBox: View {
    let digit: String
    let index: Int
    let isActive: Bool
    let status: OtpBoxStatus

    @Environment(\.shkColors) private var colors

    var body: some View {
        let success = SiteStatusColors.Success
        let error = colors.error
        // در حالت موفق، هر خانه با کمی تأخیر نسبت به خانه‌ی قبلی سبز می‌شه (حالت موجی)
        let delay = status == .success ? Double(index) * 0.08 : 0
        let borderColor: Color = {
            switch status {
            case .success: return success
            case .error: return error
            case .none: return isActive ? colors.primary : colors.outline
            }
        }()
        let backgroundColor: Color = {
            switch status {
            case .success: return success.opacity(0.12)
            case .error: return error.opacity(0.08)
            case .none: return colors.surface
            }
        }()
        let textColor: Color = {
            switch status {
            case .success: return success
            case .error: return error
            case .none: return colors.onSurface
            }
        }()
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        ZStack {
            shape.fill(backgroundColor)
            shape.strokeBorder(borderColor, lineWidth: status == .none ? 1.5 : 2)
            Text(digit)
                .font(ShkFont.yekan(22, .bold))
                .foregroundColor(textColor)
        }
        .frame(height: 56)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.25).delay(delay), value: status)
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.25), value: isActive)
        // پرش کوچک هر خانه هنگام سبز شدن
        .modifier(PopScaleEffect(pop: status == .success ? 1 : 0))
        .animation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.32).delay(delay), value: status == .success)
    }
}

/// مقیاس = 1 + 0.14 × sin(pop × π) (مثل اندروید)
private struct PopScaleEffect: GeometryEffect {
    var pop: CGFloat

    var animatableData: CGFloat {
        get { pop }
        set { pop = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let scale = 1 + 0.14 * sin(pop * .pi)
        let t = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(t)
    }
}
