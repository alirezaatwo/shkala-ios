import Foundation

// معادل ui/tools/HddCalculatorMath.kt

/** یک گروه دوربین هم‌رزولوشن */
struct HddCameraGroup: Equatable {
    let count: Int
    let resolution: String
}

/** هارد پیشنهادی: count عدد هارد tierTb ترابایتی */
struct HddRecommendation: Equatable {
    let count: Int
    let tierTb: Double
}

/**
 * محاسبه‌ی ماشین‌حساب هارد - دقیقاً همون فرمول سایت (custom.js) و Modules/Tools/HddCalculator.php
 * همه‌ی عددها (بیت‌ریت، ضریب‌ها، ظرفیت‌ها) از پیکربندی سرور میاد:
 *   بیت‌ریت هر دوربین (kbps) = بیت‌ریت رزولوشن × ضریب کدک × (fps ÷ base_fps)
 *   مصرف روزانه (GB) = Σ تعداد × kbps × ۱۰۰۰ ÷ ۸ × ۳۶۰۰ × ساعت × ضریب نوع ضبط ÷ ۱۰^۹
 *   ظرفیت لازم (TB) = مصرف روزانه × روز ÷ ۱۰۰۰ × (۱ + حاشیه٪)
 *   روزهای ضبط = ظرفیت کل (TB) × ۱۰۰۰ ÷ (۱ + حاشیه٪) ÷ مصرف روزانه
 */
enum HddCalculatorMath {

    static func dailyGb(config: HddConfigDto, groups: [HddCameraGroup], codec: String, fps: Int, hours: Int, mode: String) -> Double {
        let codecFactor = (config.codecs ?? []).first { $0.key == codec }?.factor ?? 1.0
        let modeFactor = (config.modes ?? []).first { $0.key == mode }?.factor ?? 1.0
        let baseFps = max(config.baseFps ?? 25, 1)
        var total = 0.0
        for group in groups {
            guard let kbps = (config.resolutions ?? []).first(where: { $0.key == group.resolution })?.kbps else { continue }
            let cameraKbps = Double(kbps) * codecFactor * (Double(fps) / Double(baseFps))
            total += Double(group.count) * cameraKbps * 1000.0 / 8.0 * 3600.0 * Double(hours) * modeFactor / 1e9
        }
        return total
    }

    static func requiredTb(dailyGb: Double, days: Int, marginPercent: Int) -> Double {
        dailyGb * Double(days) / 1000.0 * (1 + Double(marginPercent) / 100.0)
    }

    static func recordDays(totalTb: Double, dailyGb: Double, marginPercent: Int) -> Int64 {
        if dailyGb <= 0.0 { return 0 }
        return Int64((totalTb * 1000.0 / (1 + Double(marginPercent) / 100.0) / dailyGb).rounded(.down))
    }

    /** کوچک‌ترین ظرفیت کافی؛ بیشتر از بزرگ‌ترین ظرفیت = چند هارد */
    static func recommend(tiers: [Double], requiredTb: Double) -> HddRecommendation? {
        if tiers.isEmpty || requiredTb <= 0.0 { return nil }
        let sorted = tiers.sorted()
        let maxTier = sorted.last!
        let count = requiredTb <= maxTier ? 1 : Int((requiredTb / maxTier).rounded(.up))
        let perDisk = requiredTb / Double(count)
        let tier = sorted.first { $0 + 1e-9 >= perDisk } ?? maxTier
        return HddRecommendation(count: count, tierTb: tier)
    }

    /** ۰٫۵ → «۵۰۰ گیگابایت»، ۴ → «۴ ترابایت» */
    static func tierLabel(_ tb: Double) -> String {
        tb < 1.0 ? "\(Int((tb * 1000).rounded()).toPersianDigits()) گیگابایت" : "\(trim(tb, 1)) ترابایت"
    }

    /** مقدار محاسبه‌شده: زیر ۱ ترابایت به گیگابایت */
    static func capacityLabel(_ tb: Double) -> String {
        if tb < 1.0 {
            let gb = tb * 1000
            return "\(trim(gb, gb < 100 ? 1 : 0)) گیگابایت"
        }
        return "\(trim(tb, tb < 10 ? 1 : 0)) ترابایت"
    }

    static func groupedNumber(_ value: Int64) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return (f.string(from: NSNumber(value: value)) ?? String(value)).replacingOccurrences(of: ",", with: "٬").toPersianDigits()
    }

    /** عدد با حداکثر digits رقم اعشار، بدون صفرهای اضافه و با ارقام فارسی */
    private static func trim(_ value: Double, _ digits: Int) -> String {
        if digits <= 0 { return groupedNumber(Int64(value.rounded())) }
        var text = String(format: "%.\(digits)f", locale: Locale(identifier: "en_US"), value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let whole = groupedNumber(Int64(parts[0]) ?? 0)
        return parts.count > 1 ? "\(whole)٫\(parts[1].toPersianDigits())" : whole
    }
}
