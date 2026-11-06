import SwiftUI

// لوگوموشن اسپلش - ترجمه‌ی خط‌به‌خط SplashLogoMotion.kt اپ اندروید (همان زمان‌بندی، همان
// منحنی‌های حرکت، همان مختصات). اول خط دور سپر کشیده می‌شه، بعد سفیدی از پایین سپر رو پر
// می‌کنه (با برق و موج دایره‌ای)، سپر بالا می‌ره، «سیما حفاظ خزر» از راست به چپ ظاهر می‌شه
// و در آخر شعار کلمه به کلمه. فریم آخر دقیقاً همون تصویر اسپلش قبلیه.

/// رنگ زمینه‌ی اسپلش (همان قرمز تصویر اسپلش قبلی)
let SplashRed = Color(argb: 0xFFC70415)

/// طول کل لوگوموشن (میلی‌ثانیه)
let SPLASH_LOGO_MOTION_MS: Double = 3750

/// زمان ظاهر شدن نوار پیشرفت پایین اسپلش (بعد از لوگو و لوگوتایپ)
let SPLASH_PROGRESS_FADE_IN_START_MS: Double = 3300
let SPLASH_PROGRESS_FADE_IN_MS: Double = 500

// ---- چیدمان (فضای طراحی 1080x1920 با برش Crop) ----
private let DESIGN_W: CGFloat = 1080
private let DESIGN_H: CGFloat = 1920
private let SHIELD_CENTER = CGPoint(x: 548.5, y: 846)

// تبدیل مختصات SVG اصلی لوگو (400x300) به فضای طراحی
private let SHIELD_SCALE: CGFloat = 2.07
private let SHIELD_OFFSET = CGPoint(x: -80.30, y: 460.57)
private let TEXT_SCALE: CGFloat = 2.316
private let TEXT_OFFSET = CGPoint(x: 196.27, y: 636.45)

// کلمه‌ها و نقطه‌های شعار از راست به چپ (بازه‌ی x در فضای طراحی)
private let TAGLINE_PIECES: [(CGFloat, CGFloat)] = [
    (711, 812), (692, 703), (582, 686), (565, 576), (477, 558), (460, 471), (284, 453),
]

// منحنی‌های حرکت
private let EaseOutExpo = CubicBezierEasing(0.22, 1, 0.36, 1)
private let EaseDraw = CubicBezierEasing(0.6, 0, 0.3, 1)
private let EaseFill = CubicBezierEasing(0.5, 0, 0.2, 1)
private let EaseMove = CubicBezierEasing(0.65, 0, 0.25, 1)
private let EaseWipe = CubicBezierEasing(0.45, 0, 0.2, 1)
private let EaseOut = CubicBezierEasing(0, 0, 0.58, 1)

/// پیشرفت ۰ تا ۱ یک مرحله از انیمیشن در زمان t (میلی‌ثانیه)
private func phase(_ t: CGFloat, _ startMs: CGFloat, _ durationMs: CGFloat, _ easing: CubicBezierEasing = .linear) -> CGFloat {
    let f = min(max((t - startMs) / durationMs, 0), 1)
    return easing.transform(f)
}

private func lerp(_ a: CGFloat, _ b: CGFloat, _ f: CGFloat) -> CGFloat { a + (b - a) * f }

private struct SplashLogoShapes {
    let shieldBottom: Path
    let shieldTop: Path
    let wordmark: [Path]
    let tagline: [Path]

    static let shared: SplashLogoShapes = {
        SplashLogoShapes(
            shieldBottom: SVGPath.parse(SplashLogoPaths.SHIELD_BOTTOM),
            shieldTop: SVGPath.parse(SplashLogoPaths.SHIELD_TOP),
            wordmark: SplashLogoPaths.WORDMARK.map { SVGPath.parse($0) },
            tagline: SplashLogoPaths.TAGLINE.map { SVGPath.parse($0) }
        )
    }()
}

struct SplashLogoMotion: View {
    /// برای عکس‌برداری خودکار: نمایش یک فریم ثابت (میلی‌ثانیه) به‌جای انیمیشن
    var fixedTimeMs: Double? = nil

    @State private var startDate = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let fixedTimeMs {
            canvas(t: CGFloat(fixedTimeMs))
        } else if reduceMotion {
            // انیمیشن‌های گوشی خاموش: مستقیم فریم آخر
            canvas(t: CGFloat(SPLASH_LOGO_MOTION_MS))
        } else {
            TimelineView(.animation) { context in
                let elapsed = context.date.timeIntervalSince(startDate) * 1000
                canvas(t: CGFloat(min(elapsed, SPLASH_LOGO_MOTION_MS)))
            }
        }
    }

    private func canvas(t: CGFloat) -> some View {
        Canvas { ctx, size in
            drawSplashLogo(&ctx, size: size, t: t)
        }
        .environment(\.layoutDirection, .leftToRight)
        .clipped()
    }
}

private func drawSplashLogo(_ ctx: inout GraphicsContext, size: CGSize, t: CGFloat) {
    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(SplashRed))
    // مثل ContentScale.Crop: فضای طراحی 1080x1920 کل صفحه رو پر می‌کنه و وسط‌چین می‌شه
    let s = max(size.width / DESIGN_W, size.height / DESIGN_H)
    let dx = (size.width - DESIGN_W * s) / 2
    let dy = (size.height - DESIGN_H * s) / 2
    var c = ctx
    c.translateBy(x: dx, y: dy)
    c.scaleBy(x: s, y: s)
    drawBackgroundGlow(c, alpha: phase(t, 300, 1600, EaseOut))
    drawShieldGroup(c, t: t)
    drawWordmark(c, t: t)
    drawTagline(c, t: t)
}

private func scaled(_ ctx: GraphicsContext, _ sx: CGFloat, _ sy: CGFloat, pivot: CGPoint) -> GraphicsContext {
    var c = ctx
    c.translateBy(x: pivot.x, y: pivot.y)
    c.scaleBy(x: sx, y: sy)
    c.translateBy(x: -pivot.x, y: -pivot.y)
    return c
}

/// نور ملایم وسط زمینه (گرادیان بیضوی) که آرام ظاهر می‌شه
private func drawBackgroundGlow(_ ctx: GraphicsContext, alpha: CGFloat) {
    if alpha <= 0 { return }
    let center = CGPoint(x: DESIGN_W * 0.5, y: DESIGN_H * 0.45)
    var c = scaled(ctx, 1, DESIGN_H / DESIGN_W, pivot: center)
    c.opacity = Double(alpha)
    let gradient = Gradient(stops: [
        .init(color: Color(argb: 0xFFDC0D22), location: 0),
        .init(color: SplashRed, location: 0.6),
        .init(color: Color(argb: 0xFFA10212), location: 1),
    ])
    c.fill(
        Path(CGRect(x: -DESIGN_W, y: -DESIGN_H, width: DESIGN_W * 3, height: DESIGN_H * 3)),
        with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: DESIGN_W * 0.62)
    )
}

private func drawShieldGroup(_ ctx: GraphicsContext, t: CGFloat) {
    let shapes = SplashLogoShapes.shared
    // سپر اول وسطِ کل ترکیب و کمی بزرگ‌تره، بعد نرم به جای نهاییش بالا می‌ره
    let move = phase(t, 1600, 1000, EaseMove)
    let groupScale = lerp(1.2, 1, move)
    let groupY = lerp(100, 0, move)
    var g = ctx
    g.translateBy(x: 0, y: groupY)
    g = scaled(g, groupScale, groupScale, pivot: SHIELD_CENTER)

    // برق سفید پشت سپر در لحظه‌ی پر شدن
    let flashF = phase(t, 1300, 700)
    let flashAlpha = flashF < 0.2 ? flashF / 0.2 * 0.5 : lerp(0.5, 0, (flashF - 0.2) / 0.8)
    if flashF > 0 && flashF < 1 && flashAlpha > 0 {
        var f = g
        f.opacity = Double(flashAlpha)
        let r: CGFloat = 170
        f.fill(
            Path(ellipseIn: CGRect(x: SHIELD_CENTER.x - r, y: SHIELD_CENTER.y - r, width: r * 2, height: r * 2)),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.9), Color.white.opacity(0)]),
                center: SHIELD_CENTER, startRadius: 0, endRadius: r
            )
        )
    }
    drawRing(g, f: phase(t, 1350, 1100, EaseOutExpo), width: 3)
    drawRing(g, f: phase(t, 1500, 1100, EaseOutExpo), width: 1.5)

    // ضربه‌ی کوچک بعد از پر شدن
    let lockF = phase(t, 1200, 500)
    let lockScale = lockF < 0.4
        ? lerp(1, 1.05, EaseOut.transform(lockF / 0.4))
        : lerp(1.05, 1, EaseOut.transform((lockF - 0.4) / 0.6))
    var s = scaled(g, lockScale, lockScale, pivot: SHIELD_CENTER)
    s.translateBy(x: SHIELD_OFFSET.x, y: SHIELD_OFFSET.y)
    s.scaleBy(x: SHIELD_SCALE, y: SHIELD_SCALE)

    // ۱) کشیده شدن خط دور (اول تکه‌ی پایین، کمی بعد تاج)
    drawOutline(s, path: shapes.shieldBottom, f: phase(t, 100, 1050, EaseDraw))
    drawOutline(s, path: shapes.shieldTop, f: phase(t, 320, 1050, EaseDraw))
    // ۲) پر شدن از پایین به بالا (مختصات SVG اصلی: پایین سپر ≈ 231، بالا ≈ 141)
    let fill = phase(t, 1000, 600, EaseFill)
    if fill > 0 {
        let fillTop = lerp(232, 114, fill)
        var clip = s
        clip.clip(to: Path(CGRect(x: 260, y: fillTop, width: 90, height: 240 - fillTop)))
        clip.fill(shapes.shieldBottom, with: .color(.white))
        clip.fill(shapes.shieldTop, with: .color(.white))
    }
}

/// موج دایره‌ای که از پشت سپر باز می‌شه و محو می‌شه
private func drawRing(_ ctx: GraphicsContext, f: CGFloat, width: CGFloat) {
    if f <= 0 || f >= 1 { return }
    var c = ctx
    c.opacity = Double(lerp(0.6, 0, f))
    let r = 112 * lerp(0.75, 2.3, f)
    c.stroke(
        Path(ellipseIn: CGRect(x: SHIELD_CENTER.x - r, y: SHIELD_CENTER.y - r, width: r * 2, height: r * 2)),
        with: .color(.white),
        lineWidth: width
    )
}

/// کشیدن بخشی از خط دور مسیر (۰ تا ۱)
private func drawOutline(_ ctx: GraphicsContext, path: Path, f: CGFloat) {
    if f <= 0 { return }
    ctx.stroke(
        path.trimmedPath(from: 0, to: min(f, 1)),
        with: .color(.white),
        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
    )
}

/// لوگوتایپ: نمایش از راست به چپ با لبه‌ی نرم + کمی بالا اومدن
private func drawWordmark(_ ctx: GraphicsContext, t: CGFloat) {
    let wipe = phase(t, 1900, 1050, EaseWipe)
    if wipe <= 0 { return }
    let rise = lerp(16, 0, phase(t, 1900, 1050, EaseOutExpo))
    let edge = lerp(812, 172, wipe) // سمت چپِ لبه‌ی نرم؛ از edge+90 به راست کاملاً دیده می‌شه
    let bounds = CGRect(x: 250, y: 960, width: 590, height: 160)
    var c = ctx
    c.clip(to: Path(bounds))
    c.drawLayer { layer in
        var text = layer
        text.translateBy(x: TEXT_OFFSET.x, y: TEXT_OFFSET.y + rise)
        text.scaleBy(x: TEXT_SCALE, y: TEXT_SCALE)
        SplashLogoShapes.shared.wordmark.forEach { text.fill($0, with: .color(.white)) }
        var mask = layer
        mask.blendMode = .destinationIn
        mask.fill(
            Path(bounds),
            with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0), Color.white]),
                startPoint: CGPoint(x: edge, y: 0),
                endPoint: CGPoint(x: edge + 90, y: 0)
            )
        )
    }
}

/// شعار: کلمه‌ها و نقطه‌ها پشت سر هم از راست به چپ با محو و بالا اومدن
private func drawTagline(_ ctx: GraphicsContext, t: CGFloat) {
    for (i, piece) in TAGLINE_PIECES.enumerated() {
        let f = phase(t, 2650 + CGFloat(i) * 85, 550, EaseOutExpo)
        if f <= 0 { continue }
        let (left, right) = piece
        var c = ctx
        c.opacity = Double(f)
        c.clip(to: Path(CGRect(x: left, y: 1088, width: right - left, height: 1144 - 1088)))
        c.drawLayer { layer in
            var l = layer
            l.translateBy(x: TEXT_OFFSET.x, y: TEXT_OFFSET.y + lerp(14, 0, f))
            l.scaleBy(x: TEXT_SCALE, y: TEXT_SCALE)
            SplashLogoShapes.shared.tagline.forEach { l.fill($0, with: .color(.white)) }
        }
    }
}
