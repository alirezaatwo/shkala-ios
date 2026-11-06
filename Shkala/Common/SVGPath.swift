import SwiftUI

/// تبدیل رشته‌ی path فایل SVG (ویژگی d) به Path سوئیفت - معادل PathParser اندروید.
/// همه‌ی فرمان‌ها پشتیبانی می‌شوند: M L H V C S Q T A Z (بزرگ و کوچک).
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var scanner = Scanner(d)
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var lastControl: CGPoint? = nil      // برای S/s
        var lastQuadControl: CGPoint? = nil  // برای T/t
        var command: Character = "M"

        while true {
            scanner.skipSeparators()
            guard let ch = scanner.peek() else { break }
            if ch.isLetter {
                command = ch
                scanner.advance()
                if command == "Z" || command == "z" {
                    path.closeSubpath()
                    current = start
                    lastControl = nil
                    lastQuadControl = nil
                    continue
                }
            }
            let rel = command.isLowercase
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                rel ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }
            switch command {
            case "M", "m":
                guard let x = scanner.number(), let y = scanner.number() else { return path }
                current = pt(x, y)
                start = current
                path.move(to: current)
                // جفت‌های بعدی بعد از M به‌صورت L تفسیر می‌شوند
                command = rel ? "l" : "L"
                lastControl = nil; lastQuadControl = nil
            case "L", "l":
                guard let x = scanner.number(), let y = scanner.number() else { return path }
                current = pt(x, y)
                path.addLine(to: current)
                lastControl = nil; lastQuadControl = nil
            case "H", "h":
                guard let x = scanner.number() else { return path }
                current = CGPoint(x: rel ? current.x + x : x, y: current.y)
                path.addLine(to: current)
                lastControl = nil; lastQuadControl = nil
            case "V", "v":
                guard let y = scanner.number() else { return path }
                current = CGPoint(x: current.x, y: rel ? current.y + y : y)
                path.addLine(to: current)
                lastControl = nil; lastQuadControl = nil
            case "C", "c":
                guard let x1 = scanner.number(), let y1 = scanner.number(),
                      let x2 = scanner.number(), let y2 = scanner.number(),
                      let x = scanner.number(), let y = scanner.number() else { return path }
                let c1 = pt(x1, y1), c2 = pt(x2, y2), end = pt(x, y)
                path.addCurve(to: end, control1: c1, control2: c2)
                lastControl = c2; lastQuadControl = nil
                current = end
            case "S", "s":
                guard let x2 = scanner.number(), let y2 = scanner.number(),
                      let x = scanner.number(), let y = scanner.number() else { return path }
                let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let c2 = pt(x2, y2), end = pt(x, y)
                path.addCurve(to: end, control1: c1, control2: c2)
                lastControl = c2; lastQuadControl = nil
                current = end
            case "Q", "q":
                guard let x1 = scanner.number(), let y1 = scanner.number(),
                      let x = scanner.number(), let y = scanner.number() else { return path }
                let c = pt(x1, y1), end = pt(x, y)
                path.addQuadCurve(to: end, control: c)
                lastQuadControl = c; lastControl = nil
                current = end
            case "T", "t":
                guard let x = scanner.number(), let y = scanner.number() else { return path }
                let c = lastQuadControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let end = pt(x, y)
                path.addQuadCurve(to: end, control: c)
                lastQuadControl = c; lastControl = nil
                current = end
            case "A", "a":
                guard let rx = scanner.number(), let ry = scanner.number(), let rot = scanner.number(),
                      let large = scanner.flag(), let sweep = scanner.flag(),
                      let x = scanner.number(), let y = scanner.number() else { return path }
                let end = pt(x, y)
                addArc(&path, from: current, to: end, rx: rx, ry: ry, angle: rot, largeArc: large, sweep: sweep)
                current = end
                lastControl = nil; lastQuadControl = nil
            default:
                // فرمان ناشناخته: بقیه‌ی رشته نادیده گرفته می‌شود
                return path
            }
        }
        return path
    }

    /// کمان بیضوی SVG (پارامترهای نقطه‌ی پایانی) با تبدیل به منحنی‌های بزیه
    private static func addArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint,
                               rx rxIn: CGFloat, ry ryIn: CGFloat, angle: CGFloat,
                               largeArc: Bool, sweep: Bool) {
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 || p0 == p1 {
            path.addLine(to: p1)
            return
        }
        let phi = angle * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 {
            let s = sqrt(lambda)
            rx *= s; ry *= s
        }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = sqrt(max(0, num / den))
        if largeArc == sweep { coef = -coef }
        let cxp = coef * (rx * y1p / ry)
        let cyp = coef * (-ry * x1p / rx)
        let cx = cosPhi * cxp - sinPhi * cyp + (p0.x + p1.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (p0.y + p1.y) / 2

        func angleBetween(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var a = acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let theta1 = angleBetween(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var dTheta = angleBetween((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let delta = dTheta / CGFloat(segments)
        let t = 4 / 3 * tan(delta / 4)
        var theta = theta1
        func point(_ a: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cos(a) * cosPhi - ry * sin(a) * sinPhi,
                    y: cy + rx * cos(a) * sinPhi + ry * sin(a) * cosPhi)
        }
        func derivative(_ a: CGFloat) -> CGPoint {
            CGPoint(x: -rx * sin(a) * cosPhi - ry * cos(a) * sinPhi,
                    y: -rx * sin(a) * sinPhi + ry * cos(a) * cosPhi)
        }
        for i in 0..<segments {
            let a1 = theta, a2 = theta + delta
            let s = point(a1), e = (i == segments - 1) ? p1 : point(a2)
            let d1 = derivative(a1), d2 = derivative(a2)
            path.addCurve(to: e,
                          control1: CGPoint(x: s.x + t * d1.x, y: s.y + t * d1.y),
                          control2: CGPoint(x: e.x - t * d2.x, y: e.y - t * d2.y))
            theta = a2
        }
    }

    private struct Scanner {
        let chars: [Character]
        var i = 0

        init(_ s: String) { chars = Array(s) }

        func peek() -> Character? { i < chars.count ? chars[i] : nil }
        mutating func advance() { i += 1 }

        mutating func skipSeparators() {
            while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" || chars[i] == "\r" {
                i += 1
            }
        }

        /// عدد با قالب فشرده‌ی SVG: «-.96» ، «1.19-.96» ، «.5.5» ، «1e-3»
        mutating func number() -> CGFloat? {
            skipSeparators()
            var s = ""
            if i < chars.count, chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
            var seenDot = false, seenDigit = false
            while i < chars.count {
                let c = chars[i]
                if c.isNumber { s.append(c); seenDigit = true; i += 1 }
                else if c == "." && !seenDot { s.append(c); seenDot = true; i += 1 }
                else { break }
            }
            if i < chars.count, chars[i] == "e" || chars[i] == "E" {
                s.append("e"); i += 1
                if i < chars.count, chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
                while i < chars.count, chars[i].isNumber { s.append(chars[i]); i += 1 }
            }
            guard seenDigit, let v = Double(s) else { return nil }
            return CGFloat(v)
        }

        /// پرچم کمان (۰ یا ۱) - ممکن است بدون جداکننده به عدد بعدی چسبیده باشد
        mutating func flag() -> Bool? {
            skipSeparators()
            guard i < chars.count else { return nil }
            let c = chars[i]
            if c == "0" { i += 1; return false }
            if c == "1" { i += 1; return true }
            return nil
        }
    }
}

/// منحنی حرکت cubic-bezier - معادل CubicBezierEasing اندروید
struct CubicBezierEasing {
    let a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat

    init(_ a: CGFloat, _ b: CGFloat, _ c: CGFloat, _ d: CGFloat) {
        self.a = a; self.b = b; self.c = c; self.d = d
    }

    private func bezier(_ t: CGFloat, _ p1: CGFloat, _ p2: CGFloat) -> CGFloat {
        let u = 1 - t
        return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t
    }

    func transform(_ fraction: CGFloat) -> CGFloat {
        if fraction <= 0 { return 0 }
        if fraction >= 1 { return 1 }
        // جستجوی دودویی روی x برای پیدا کردن t
        var lo: CGFloat = 0, hi: CGFloat = 1, t: CGFloat = fraction
        for _ in 0..<30 {
            t = (lo + hi) / 2
            let x = bezier(t, a, c)
            if abs(x - fraction) < 0.00001 { break }
            if x < fraction { lo = t } else { hi = t }
        }
        return bezier(t, b, d)
    }

    static let linear = CubicBezierEasing(0, 0, 1, 1)
}
