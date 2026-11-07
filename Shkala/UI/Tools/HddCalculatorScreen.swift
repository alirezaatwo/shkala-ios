import SwiftUI

// معادل ui/tools/HddCalculatorScreen.kt - ماشین‌حساب هارد دوربین (فرمول‌ها در HddCalculatorMath)

private let DEFAULT_TITLE = "ماشین‌حساب هارد دوربین"

struct HddCalculatorScreen: View {
    let onBack: () -> Void
    let onOpenProduct: (String) -> Void
    let onOpenLink: (String) -> Void

    @Environment(\.shkColors) private var colors
    private let repository = ToolsRepository()
    @State private var data: HddToolResponse? = nil
    @State private var error: String? = nil
    @State private var reloadKey = 0

    var body: some View {
        let current = data
        let config = current?.config
        VStack(spacing: 0) {
            SitePageTopBar(title: current?.tool?.title.flatMap { $0.isBlankShk ? nil : $0 } ?? DEFAULT_TITLE, onBack: onBack)
            if current == nil && error == nil {
                SiteLoading(size: 56)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if current == nil {
                VStack {
                    SiteEmptyState(
                        icon: RemixIcons.WifiOffLine,
                        title: error ?? "دریافت اطلاعات با خطا مواجه شد.",
                        subtitle: "اتصال اینترنت را بررسی کنید.",
                        actionLabel: "تلاش دوباره",
                        actionIcon: RemixIcons.RefreshLine,
                        onAction: { reloadKey += 1 }
                    )
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if current?.enabled != true || config == nil || (config?.resolutions ?? []).isEmpty {
                VStack {
                    SiteEmptyState(icon: RemixIcons.ToolsLine, title: "این ابزار در حال حاضر فعال نیست", subtitle: nil)
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let config {
                HddCalculatorContent(
                    config: config,
                    tool: current?.tool,
                    repository: repository,
                    onOpenProduct: onOpenProduct,
                    onOpenLink: onOpenLink
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        .task(id: reloadKey) {
            error = nil
            switch await repository.getHddCalculator() {
            case .success(let d): data = d
            case .error(let message): error = message
            }
        }
    }
}

private struct HddCalculatorContent: View {
    let config: HddConfigDto
    let tool: ToolItemDto?
    let repository: ToolsRepository
    let onOpenProduct: (String) -> Void
    let onOpenLink: (String) -> Void

    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    private let resolutions: [HddOptionDto]
    private let codecs: [HddOptionDto]
    private let modes: [HddOptionDto]
    private let fpsOptions: [Int]
    private let tiers: [Double]
    private let margin: Int
    private let camerasMax: Int
    private let groupsMax: Int
    private let disksMax: Int
    private let quickDays: [Int]
    private let productsEnabled: Bool
    // تب‌های فعال از پنل (need = هارد لازم، days = مدت ضبط)؛ سرور قدیمی = هر دو
    private let calcTabs: [(key: String, label: String?)]

    // ۰ = هارد لازم، ۱ = روزهای ضبط
    @State private var calcMode: Int
    @State private var groups: [HddCameraGroup]
    @State private var codec: String
    @State private var fps: Int
    @State private var hours: Int
    @State private var recMode: String
    @State private var days: Int
    @State private var diskTb: Double
    @State private var disks = 1
    @State private var products: HddProductsResponse? = nil
    @State private var productsLoading = false

    init(config: HddConfigDto, tool: ToolItemDto?, repository: ToolsRepository, onOpenProduct: @escaping (String) -> Void, onOpenLink: @escaping (String) -> Void) {
        self.config = config
        self.tool = tool
        self.repository = repository
        self.onOpenProduct = onOpenProduct
        self.onOpenLink = onOpenLink
        let defaults = config.defaults
        let limits = config.limits
        let resolutions = config.resolutions ?? []
        let codecs = config.codecs ?? []
        let modes = config.modes ?? []
        let fpsOptions = (config.fpsOptions ?? []).isEmpty ? [25] : (config.fpsOptions ?? [])
        let tiers = (config.tiersTb ?? []).filter { $0 > 0.0 }.sorted()
        let camerasMax = limits?.camerasMax ?? 256
        self.resolutions = resolutions
        self.codecs = codecs
        self.modes = modes
        self.fpsOptions = fpsOptions
        self.tiers = tiers
        self.margin = config.marginPercent ?? 0
        self.camerasMax = camerasMax
        self.groupsMax = limits?.groupsMax ?? 6
        self.disksMax = max(limits?.disksMax ?? 16, 1)
        let qd = (config.quickDays ?? []).filter { $0 > 0 }
        self.quickDays = qd.isEmpty ? [7, 14, 30, 60, 90] : qd
        self.productsEnabled = config.productsEnabled != false
        let panelTabs = (config.tabs ?? []).filter { $0.key == "need" || $0.key == "days" }.map { (key: $0.key ?? "", label: $0.label) }
        let calcTabs = panelTabs.isEmpty ? [(key: "need", label: Optional("هارد لازم")), (key: "days", label: Optional("مدت ضبط"))] : panelTabs
        self.calcTabs = calcTabs

        let first = calcTabs.first { $0.key == defaults?.tab } ?? calcTabs[0]
        _calcMode = State(initialValue: first.key == "days" ? 1 : 0)
        let defaultRes = defaults?.resolution.flatMap { key in resolutions.contains { $0.key == key } ? key : nil } ?? (resolutions.first?.key ?? "")
        _groups = State(initialValue: [HddCameraGroup(count: min(max(defaults?.cameras ?? 4, 1), camerasMax), resolution: defaultRes)])
        _codec = State(initialValue: defaults?.codec.flatMap { key in codecs.contains { $0.key == key } ? key : nil } ?? (codecs.first?.key ?? ""))
        _fps = State(initialValue: defaults?.fps.flatMap { fpsOptions.contains($0) ? $0 : nil } ?? fpsOptions.last!)
        _hours = State(initialValue: min(max(defaults?.hours ?? 24, 1), 24))
        _recMode = State(initialValue: defaults?.mode.flatMap { key in modes.contains { $0.key == key } ? key : nil } ?? (modes.first?.key ?? ""))
        _days = State(initialValue: min(max(defaults?.days ?? 30, 1), limits?.daysMax ?? 365))
        _diskTb = State(initialValue: tiers.contains(2.0) ? 2.0 : (tiers.first ?? 1.0))
    }

    private var dashedColor: Color { isDark ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider }

    var body: some View {
        let limits = config.limits
        let accent = toolColorOf(tool, colors)
        let daily = HddCalculatorMath.dailyGb(config: config, groups: groups, codec: codec, fps: fps, hours: hours, mode: recMode)
        let required = HddCalculatorMath.requiredTb(dailyGb: daily, days: days, marginPercent: margin)
        let recommendation = calcMode == 0 ? HddCalculatorMath.recommend(tiers: tiers, requiredTb: required) : HddRecommendation(count: disks, tierTb: diskTb)
        let productTier = recommendation?.tierTb
        let list = productsEnabled ? (products?.products ?? []).uniqueById() : []

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let summary = tool?.summary, !summary.isBlankShk {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: toolIconOf(tool), size: 40, iconSize: 21, tint: accent, radius: 12, filled: true)
                        Spacer().frame(width: 10)
                        Text(summary).shkFont(12, lineHeight: 21).foregroundColor(colors.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let intro = tool?.intro, !intro.isBlankShk {
                    ToolIntroBox(text: intro, accent: accent)
                }
                if calcTabs.count > 1 {
                    SiteSegmentedTabs(
                        tabs: calcTabs.map { tab in
                            let fallback = tab.key == "days" ? "مدت ضبط" : "هارد لازم"
                            let label = (tab.label ?? "").isBlankShk ? fallback : (tab.label ?? fallback)
                            return (label, tab.key == "days" ? RemixIcons.TimeLine : RemixIcons.HardDrive2Line)
                        },
                        selectedIndex: max(calcTabs.firstIndex { ($0.key == "days") == (calcMode == 1) } ?? 0, 0),
                        onSelect: { index in calcMode = calcTabs[index].key == "days" ? 1 : 0 }
                    )
                }

                // دوربین‌ها
                SiteCard {
                    HddCardTitle(icon: RemixIcons.CameraLine, title: "دوربین‌ها")
                    ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                        if index > 0 {
                            DashedDivider(color: dashedColor).padding(.vertical, 10)
                        }
                        HStack(spacing: 0) {
                            HddStepper(value: group.count, min: limits?.camerasMin ?? 1, max: camerasMax, suffix: "دوربین", onChange: { value in
                                if index < groups.count { groups[index] = HddCameraGroup(count: value, resolution: groups[index].resolution) }
                            })
                            Spacer(minLength: 0)
                            if groups.count > 1 {
                                Button(action: { if index < groups.count { groups.remove(at: index) } }) {
                                    RemixIcon(RemixIcons.DeleteBinLine, contentDescription: "حذف", tint: colors.onSurfaceVariant, size: 18)
                                        .frame(width: 38, height: 38)
                                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Spacer().frame(height: 10)
                        HddChipRow(
                            options: resolutions.map { ($0.key ?? "", $0.label ?? "") },
                            selected: group.resolution,
                            onSelect: { key in
                                if index < groups.count { groups[index] = HddCameraGroup(count: groups[index].count, resolution: key) }
                            }
                        )
                    }
                    if groups.count < groupsMax {
                        Spacer().frame(height: 12)
                        Button(action: { groups.append(HddCameraGroup(count: 1, resolution: groups.last?.resolution ?? "")) }) {
                            HStack(spacing: 0) {
                                RemixIcon(RemixIcons.AddLine, tint: colors.primary, size: 17)
                                Spacer().frame(width: 6)
                                Text("دوربین با رزولوشن دیگر").shkFont(12, .bold).foregroundColor(colors.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(colors.primary.opacity(0.45), lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // تنظیمات ضبط
                SiteCard {
                    HddCardTitle(icon: RemixIcons.RecordCircleLine, title: "تنظیمات ضبط")
                    HddFieldLabel(text: "کدک فشرده‌سازی")
                    SiteSegmentedTabs(
                        tabs: codecs.map { ($0.label ?? "", nil) },
                        selectedIndex: max(codecs.firstIndex { $0.key == codec } ?? 0, 0),
                        onSelect: { codec = codecs[$0].key ?? "" }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(dashedColor, lineWidth: 1))
                    Spacer().frame(height: 14)
                    HddFieldLabel(text: "فریم در ثانیه (fps)")
                    HddChipRow(
                        options: fpsOptions.map { (String($0), "\($0.toPersianDigits()) فریم") },
                        selected: String(fps),
                        onSelect: { fps = Int($0) ?? fps }
                    )
                    Spacer().frame(height: 14)
                    HddFieldLabel(text: "ساعت ضبط در شبانه‌روز")
                    HddStepper(value: hours, min: limits?.hoursMin ?? 1, max: limits?.hoursMax ?? 24, suffix: "ساعت", onChange: { hours = $0 })
                    // یک نوع ضبط (حالت حرکتی خاموش در پنل) = بدون انتخابگر
                    if modes.count > 1 {
                        Spacer().frame(height: 14)
                        HddFieldLabel(text: "نوع ضبط")
                        SiteSegmentedTabs(
                            tabs: modes.map { ($0.label ?? "", nil) },
                            selectedIndex: max(modes.firstIndex { $0.key == recMode } ?? 0, 0),
                            onSelect: { recMode = modes[$0].key ?? "" }
                        )
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(dashedColor, lineWidth: 1))
                    }
                }

                // روز نگهداری یا هارد فعلی
                SiteCard {
                    if calcMode == 0 {
                        HddCardTitle(icon: RemixIcons.CalendarLine, title: "مدت نگهداری فیلم")
                        HddStepper(value: days, min: limits?.daysMin ?? 1, max: limits?.daysMax ?? 365, suffix: "روز", onChange: { days = $0 })
                        Spacer().frame(height: 10)
                        HddChipRow(
                            options: quickDays.map { (String($0), "\($0.toPersianDigits()) روز") },
                            selected: String(days),
                            onSelect: { days = Int($0) ?? days }
                        )
                    } else {
                        HddCardTitle(icon: RemixIcons.HardDrive2Line, title: "هارد فعلی شما")
                        HddFieldLabel(text: "ظرفیت هر هارد")
                        HddChipRow(
                            options: tiers.map { (String($0), HddCalculatorMath.tierLabel($0)) },
                            selected: String(diskTb),
                            onSelect: { diskTb = Double($0) ?? diskTb }
                        )
                        Spacer().frame(height: 14)
                        HddFieldLabel(text: "تعداد هارد")
                        HddStepper(value: disks, min: 1, max: disksMax, suffix: "عدد", onChange: { disks = $0 })
                    }
                }

                // نتیجه
                HddResultCard(
                    calcMode: calcMode,
                    daily: daily,
                    required: required,
                    days: days,
                    recommendation: recommendation,
                    cameras: groups.reduce(0) { $0 + $1.count },
                    marginPercent: margin,
                    showMonthly: config.showMonthly != false,
                    showMargin: config.showMargin != false
                )

                // هاردهای پیشنهادی
                if !list.isEmpty {
                    let tierTb = products?.tierTb ?? productTier ?? 0.0
                    VStack(alignment: .leading, spacing: 0) {
                        let title = ((config.productsTitle ?? "").isBlankShk ? "هارد مناسب برای شما" : (config.productsTitle ?? "")) + " (\(HddCalculatorMath.tierLabel(tierTb)))"
                        if let moreUrl = config.moreUrl, !moreUrl.isBlankShk {
                            SiteSectionTitle(title) {
                                Text((config.moreLabel ?? "").isBlankShk ? "همه‌ی هاردها" : (config.moreLabel ?? ""))
                                    .shkFont(12, .bold)
                                    .foregroundColor(colors.primary)
                                    .onTapGesture { onOpenLink(absoluteSiteUrl(moreUrl)) }
                            }
                            .padding(.top, 6)
                        } else {
                            SiteSectionTitle(title).padding(.top, 6)
                        }
                        if products?.exact == false, let productTier {
                            Text("برای \(HddCalculatorMath.tierLabel(productTier)) محصولی موجود نیست؛ نزدیک‌ترین ظرفیت بزرگ‌تر نمایش داده شده است.")
                                .shkFont(11, lineHeight: 19)
                                .foregroundColor(colors.onSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 6)
                        }
                    }
                    ForEach(Array(stride(from: 0, to: list.count, by: 2)), id: \.self) { start in
                        let pair = Array(list[start..<min(start + 2, list.count)])
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(pair) { product in
                                ProductCard(product: product, onClick: { onOpenProduct(product.slug) })
                                    .frame(maxWidth: .infinity)
                            }
                            if pair.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                        }
                    }
                } else if productsLoading && productsEnabled {
                    SiteLoading(size: 40)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                // یادداشت زیر نتیجه از پنل (خالی = بدون یادداشت؛ سرور قدیمی = متن پیش‌فرض)
                let note = config.resultNote ?? "عددها تخمینی‌اند و به تنظیمات کیفیت دستگاه ضبط، شلوغی تصویر و دید در شب بستگی دارند. برای انتخاب دقیق‌تر با کارشناسان فروشگاه مشورت کنید."
                if !note.isBlankShk {
                    Text(note)
                        .shkFont(11, lineHeight: 19)
                        .foregroundColor(colors.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                if !(tool?.endTitle ?? "").isBlankShk || !(tool?.endText ?? "").isBlankShk {
                    ToolEndSection(title: tool?.endTitle, text: tool?.endText, accent: accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .task(id: productTier) {
            guard let productTier, productsEnabled else {
                products = nil
                return
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }
            productsLoading = true
            switch await repository.getHddProducts(tb: productTier) {
            case .success(let r): products = r
            case .error: products = nil
            }
            productsLoading = false
        }
    }
}

private struct HddResultCard: View {
    let calcMode: Int
    let daily: Double
    let required: Double
    let days: Int
    let recommendation: HddRecommendation?
    let cameras: Int
    let marginPercent: Int
    var showMonthly: Bool = true
    var showMargin: Bool = true
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        let (label, value, pick): (String, String, String?) = {
            if calcMode == 0 {
                let pick = recommendation.map { rec -> String in
                    let disk = HddCalculatorMath.tierLabel(rec.tierTb)
                    return rec.count > 1 ? "پیشنهاد ما: \(rec.count.toPersianDigits()) عدد هارد \(disk)" : "پیشنهاد ما: یک هارد \(disk)"
                }
                return ("ظرفیت لازم برای \(days.toPersianDigits()) روز", HddCalculatorMath.capacityLabel(required), pick)
            } else {
                let count = recommendation?.count ?? 1
                let tier = recommendation?.tierTb ?? 0.0
                let recordDays = HddCalculatorMath.recordDays(totalTb: tier * Double(count), dailyGb: daily, marginPercent: marginPercent)
                let label = "مدت ضبط با " + (count > 1 ? "\(count.toPersianDigits()) هارد " : "هارد ") + HddCalculatorMath.tierLabel(tier)
                return (label, "\(HddCalculatorMath.groupedNumber(recordDays)) روز", recordDays >= 60 ? "حدود \(HddCalculatorMath.groupedNumber(recordDays / 30)) ماه" : nil)
            }
        }()
        let marginRow = showMargin && marginPercent > 0

        SiteCard(borderColor: primary.opacity(0.25)) {
            HddCardTitle(icon: RemixIcons.CalculatorLine, title: "نتیجه‌ی محاسبه")
            VStack(spacing: 0) {
                Text(label).shkFont(12).foregroundColor(.white.opacity(0.9)).multilineTextAlignment(.center)
                Text(value).shkFont(26, .bold, lineHeight: 38).foregroundColor(.white).multilineTextAlignment(.center)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(LinearGradient(colors: [primary, Color(red: 0xB8 / 255, green: 0, blue: 0x0E / 255)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            if let pick {
                Spacer().frame(height: 10)
                HStack(spacing: 0) {
                    RemixIcon(calcMode == 0 ? RemixIcons.HardDrive2Line : RemixIcons.TimeLine, tint: primary, size: 19)
                    Spacer().frame(width: 8)
                    Text(pick).shkFont(13, .bold).foregroundColor(primary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(primary.opacity(0.08)))
            }
            Spacer().frame(height: 6)
            HddFactRow(label: "تعداد دوربین", value: "\(cameras.toPersianDigits()) عدد")
            HddFactRow(label: "حجم ضبط روزانه", value: HddCalculatorMath.capacityLabel(daily / 1000.0), last: !showMonthly && !marginRow)
            if showMonthly {
                HddFactRow(label: "حجم ضبط ماهانه (۳۰ روز)", value: HddCalculatorMath.capacityLabel(daily * 30 / 1000.0), last: !marginRow)
            }
            if marginRow {
                HddFactRow(label: "حاشیه‌ی اطمینان", value: "\(marginPercent.toPersianDigits())٪", last: true)
            }
        }
    }
}

private struct HddFactRow: View {
    let label: String
    let value: String
    var last: Bool = false
    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    var body: some View {
        HStack(spacing: 0) {
            Text(label).shkFont(12).foregroundColor(colors.onSurfaceVariant).frame(maxWidth: .infinity, alignment: .leading)
            Text(value).shkFont(13, .bold).foregroundColor(colors.onSurface)
        }
        .padding(.vertical, 8)
        if !last { DashedDivider(color: isDark ? ShkColors.DarkHeaderDashedDivider : ShkColors.LightHeaderDashedDivider) }
    }
}

private struct HddCardTitle: View {
    let icon: String
    let title: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            RemixIcon(icon, tint: colors.primary, size: 20)
            Spacer().frame(width: 8)
            Text(title).shkFont(14, .bold).foregroundColor(colors.onSurface)
        }
        .padding(.bottom, 12)
    }
}

private struct HddFieldLabel: View {
    let text: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        Text(text).shkFont(12, .medium).foregroundColor(colors.onSurfaceVariant).padding(.bottom, 8)
    }
}

/** ردیف قرص‌های قابل انتخاب با اسکرول افقی (رزولوشن، فریم، ظرفیت، روزها) */
private struct HddChipRow: View {
    let options: [(String, String)]
    let selected: String
    let onSelect: (String) -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    let isSelected = option.0 == selected
                    Button(action: { onSelect(option.0) }) {
                        Text(option.1)
                            .shkFont(12, isSelected ? .bold : .medium)
                            .foregroundColor(isSelected ? .white : colors.onSurface)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(isSelected ? primary : colors.surfaceVariant))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/** کنترل عدد با دکمه‌های + و − و امکان تایپ (ارقام فارسی هم پذیرفته می‌شن) */
private struct HddStepper: View {
    let value: Int
    let min: Int
    let max: Int
    let suffix: String
    let onChange: (Int) -> Void
    @Environment(\.shkColors) private var colors
    @State private var text: String

    init(value: Int, min: Int, max: Int, suffix: String, onChange: @escaping (Int) -> Void) {
        self.value = value
        self.min = min
        self.max = max
        self.suffix = suffix
        self.onChange = onChange
        _text = State(initialValue: value.toPersianDigits())
    }

    private func clamp(_ v: Int) -> Int { Swift.min(Swift.max(v, min), max) }

    var body: some View {
        let primary = colors.primary
        HStack(spacing: 0) {
            HddStepperButton(icon: RemixIcons.AddLine, description: "زیاد کردن", enabled: value < max) { onChange(clamp(value + 1)) }
            TextField("", text: Binding(
                get: { text },
                set: { input in
                    let digits = String(input.map { ch -> Character in
                        if let v = ch.unicodeScalars.first?.value, (0x06F0...0x06F9).contains(v) {
                            return Character(UnicodeScalar(v - 0x06F0 + 0x30)!)
                        }
                        return ch
                    }.filter { $0.isASCII && $0.isNumber })
                    text = digits.toPersianDigits()
                    if let parsed = Int(String(digits.prefix(4))), parsed >= min { onChange(Swift.min(parsed, max)) }
                }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(ShkFont.yekan(15, .bold))
            .foregroundColor(colors.onSurface)
            .tint(primary)
            .frame(width: 52)
            HddStepperButton(icon: RemixIcons.SubtractLine, description: "کم کردن", enabled: value > min) { onChange(clamp(value - 1)) }
            Text(suffix).shkFont(12).foregroundColor(colors.onSurfaceVariant).padding(.horizontal, 8)
        }
        .padding(4)
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(colors.surfaceVariant))
        .onChange(of: value) { text = $0.toPersianDigits() }
    }
}

private struct HddStepperButton: View {
    let icon: String
    let description: String
    let enabled: Bool
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        let primary = colors.primary
        Button(action: onClick) {
            RemixIcon(icon, contentDescription: description, tint: primary.opacity(enabled ? 1 : 0.4), size: 18)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(primary.opacity(enabled ? 0.12 : 0.05)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/** لینک نسبی پنل (/products?cat=...) ← آدرس کامل سایت برای مسیریاب لینک‌های اپ */
private func absoluteSiteUrl(_ url: String) -> String {
    if url.hasPrefix("/") {
        var base = ApiConstants.BASE_URL
        while base.hasSuffix("/") { base.removeLast() }
        return base + url
    }
    return url
}
