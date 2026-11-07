import SwiftUI

// معادل ui/product/SellerSelectorSection.kt + TieredPricingTable.kt + RelatedProductsCarousel.kt +
// FullSpecsScreen.kt اپ اندروید

/**
 * کارت اطلاعات کامل فروشگاهی که کاربر همین الان از آن خرید می‌کند (فاز ۸).
 * این کارت همیشه نمایش داده می‌شه - چون کاربر باید همیشه بدونه از کدوم فروشگاه می‌خره.
 * بازطراحی: کادر استاندارد با لوگو/آیکن فروشگاه، و ردیف‌های «تعهد ارسال» و «مرجوعی».
 * کلیک روی کارت، مودال فروشنده رو باز می‌کنه.
 */
struct SellerInfoCard: View {
    let seller: ProductSellerDto?
    // فاز PA: آیکن/نام فروشگاه اصلی برای موجودی‌های بدون فروشنده
    var mainShopLogoUrl: String? = nil
    var mainShopName: String? = nil

    @Environment(\.shkColors) private var colors

    var body: some View {
        let store = seller?.store
        // فاز PA (۳-ح): لوگوی فروشگاه (و برای فروشگاه اصلی، آیکن سایت) - در نبودِ لوگو همون آیکن
        let logoUrl = store != nil ? store?.logo?.url : mainShopLogoUrl
        let shopName = store?.name ?? (mainShopName?.isBlankShk == false ? mainShopName! : "سیما حفاظ خزر")

        SiteCard(onClick: {
            // فاز ۳۳ (کد ۸): با کلیک روی این باکس، یه مودال با اطلاعات کامل فروشنده باز می‌شه
            ShkDialogCenter.shared.show {
                SellerInfoModal(seller: seller, logoUrl: logoUrl, shopName: shopName)
            }
        }) {
            HStack(spacing: 0) {
                StoreLogoBox(logoUrl: logoUrl, name: shopName, size: 46)
                Spacer().frame(width: 12)
                VStack(alignment: .leading, spacing: 0) {
                    // فاز ۳۴ (کد ۸): دو خطی - خط اول کوچک و کم‌رنگ، نام فروشگاه بولد در خط دوم
                    Text("ثبت سفارش و ارسال از فروشگاه").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                    Text(shopName).shkFont(14, .bold, lineHeight: 22).foregroundColor(colors.onSurface)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
            }
            if let bio = store?.bio, !bio.isBlankShk {
                Text(bio)
                    .shkFont(12, lineHeight: 20)
                    .foregroundColor(colors.onSurfaceVariant)
                    .lineLimit(2)
                    .padding(.top, 8)
            }
            let commitment = store?.meta?.commitmentToSend
            let returned = store?.meta?.returnedPercent
            if commitment != nil || returned != nil {
                SiteDashedDivider().padding(.vertical, 10)
                HStack(spacing: 16) {
                    if let commitment {
                        SellerMetaItem(icon: RemixIcons.TruckLine, text: "تعهد ارسال: \(commitment.toPersianDigits())٪", tint: colors.primary)
                    }
                    if let returned {
                        SellerMetaItem(icon: RemixIcons.RefreshLine, text: "مرجوعی: \(returned.toPersianDigits())٪", tint: colors.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

/** یک آیتم کوچکِ آیکن + متن برای ردیف مشخصات فروشنده */
private struct SellerMetaItem: View {
    let icon: String
    let text: String
    let tint: Color
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint.opacity(0.1))
                RemixIcon(icon, tint: tint, size: 14)
            }
            .frame(width: 24, height: 24)
            Spacer().frame(width: 6)
            Text(text).shkFont(12, .medium).foregroundColor(colors.onSurface)
        }
    }
}

/** باکس لوگوی فروشگاه (یا آیکن فروشگاه اگر لوگو نداشت) */
struct StoreLogoBox: View {
    let logoUrl: String?
    let name: String?
    let size: CGFloat
    var circle: Bool = false
    @Environment(\.shkColors) private var colors

    var body: some View {
        let hasLogo = !(logoUrl?.isBlankShk ?? true)
        let shape = RoundedRectangle(cornerRadius: circle ? size / 2 : size / 3.5, style: .continuous)
        ZStack {
            // لوگوها معمولاً زمینه‌ی روشن دارن، پس پشت لوگو سفیده (حتی در تم تاریک)
            shape.fill(hasLogo ? Color.white : colors.primary.opacity(0.1))
            if hasLogo {
                RemoteImage(logoUrl, contentDescription: name, contentScale: .fit)
                    .padding(size / 9)
            } else {
                RemixIcon(RemixIcons.Store2Line, tint: colors.primary, size: size * 0.46)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .overlay(shape.strokeBorder(hasLogo ? colors.outline.opacity(0.2) : .clear, lineWidth: 1))
    }
}

/**
 * فاز ۳۳ (کد ۸): مودال اطلاعات کامل فروشنده (نام، بیو، لوگو، تعهد ارسال، درصد مرجوعی، عملکرد).
 * بازطراحی: مودال استاندارد اپ؛ ردیف‌ها به‌شکل «برچسب ..... مقدار» با آیکن و خط‌چین.
 */
private struct SellerInfoModal: View {
    let seller: ProductSellerDto?
    let logoUrl: String?
    let shopName: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        let store = seller?.store
        SiteDialogContent(
            title: "اطلاعات فروشنده",
            confirmText: "بستن",
            onConfirm: { ShkDialogCenter.shared.dismiss() }
        ) {
            VStack(spacing: 0) {
                StoreLogoBox(logoUrl: logoUrl, name: shopName, size: 72, circle: true)
                Spacer().frame(height: 10)
                Text(shopName).shkFont(15, .bold).foregroundColor(colors.onSurface).multilineTextAlignment(.center)
                if let bio = store?.bio, !bio.isBlankShk {
                    Spacer().frame(height: 6)
                    Text(bio)
                        .shkFont(12, lineHeight: 21)
                        .foregroundColor(colors.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            Spacer().frame(height: 14)
            VStack(alignment: .leading, spacing: 0) {
                // فاز ۳۴ (کد ۸-الف): store == nil یعنی فروشگاه پیش‌فرض/اصلی سیما حفاظ خزر
                // فاز PA (۳-و): برچسب و مقدار کنار هم با دونقطه («نوع فروشگاه: فروشگاه اصلی»)
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.Store2Line, tint: colors.primary, size: 16)
                    Spacer().frame(width: 6)
                    Text("نوع فروشگاه:").shkFont(13).foregroundColor(colors.onSurfaceVariant)
                    Spacer().frame(width: 4)
                    Text(store == nil ? "فروشگاه اصلی" : "زیرمجموعه").shkFont(13, .bold).foregroundColor(colors.onSurface)
                }
                .padding(.vertical, 10)

                if store == nil {
                    Text("این محصول مستقیماً توسط سیما حفاظ خزر ارسال می‌شود.")
                        .shkFont(11, lineHeight: 19)
                        .foregroundColor(colors.onSurfaceVariant)
                        .padding(.bottom, 6)
                }
                if let commitment = store?.meta?.commitmentToSend {
                    SiteDashedDivider()
                    SiteKeyValueRow(label: "تعهد ارسال به موقع", value: "\(commitment.toPersianDigits())٪", icon: RemixIcons.TruckLine, valueColor: SiteStatusColors.Success)
                }
                if let returned = store?.meta?.returnedPercent {
                    SiteDashedDivider()
                    SiteKeyValueRow(label: "درصد مرجوعی", value: "\(returned.toPersianDigits())٪", icon: RemixIcons.RefreshLine)
                }
                // فاز ۳۴ (کد ۸-ب): عملکرد فروشگاه - از همون accessor get_meta خودِ اسکریپت
                if let performance = store?.meta?.performance, !performance.isBlankShk, performance != "-" {
                    let performanceLabel: String = {
                        switch performance {
                        case "best": return "عالی"
                        case "good": return "خوب"
                        case "average": return "متوسط"
                        case "weak": return "ضعیف"
                        case "awful": return "بسیار ضعیف"
                        default: return performance
                        }
                    }()
                    SiteDashedDivider()
                    SiteKeyValueRow(label: "عملکرد فروشگاه", value: performanceLabel, icon: RemixIcons.MedalLine)
                }
                if store?.directPost == true {
                    SiteDashedDivider()
                    SiteKeyValueRow(label: "ارسال", value: "مستقیم توسط فروشگاه", icon: RemixIcons.SendPlaneLine)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surfaceVariant.opacity(0.6)))
        }
    }
}

/**
 * کلید گروه‌بندی فروشنده‌ها بر اساس فروشگاه: store == nil یعنی فروشگاه اصلی (منطق خودِ اسکریپت).
 */
func sellerStoreKey(_ seller: ProductSellerDto) -> Int { seller.store?.id ?? 0 }

/**
 * لیست فروشنده‌های یک محصول، گروه‌بندی‌شده بر اساس «فروشگاه» - برای هر فروشگاه فقط یک گزینه.
 * اگه همه‌ی موجودی‌ها متعلق به یک فروشگاه باشن، این بخش اصلاً نمایش داده نمی‌شه. انتخاب هر
 * فروشگاه، ارزان‌ترین موجودیِ همون فروشگاه رو انتخاب می‌کنه.
 */
struct SellerSelectorSection: View {
    let sellers: [ProductSellerDto]
    let selectedInventoryId: Int?
    let onSellerSelected: (ProductSellerDto) -> Void
    var mainShopLogoUrl: String? = nil
    var mainShopName: String? = nil

    @Environment(\.shkColors) private var colors

    var body: some View {
        // گروه‌بندی بر اساس فروشگاه (ترتیب اولین حضور حفظ می‌شه)
        var order: [Int] = []
        var groups: [Int: [ProductSellerDto]] = [:]
        for s in sellers {
            let key = sellerStoreKey(s)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(s)
        }
        let selectedStoreKey = sellers.first { $0.inventoryId == selectedInventoryId }.map(sellerStoreKey)

        return Group {
            if order.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    SiteSectionTitle("انتخاب فروشنده").padding(.top, 8).padding(.bottom, 2)
                    ForEach(order, id: \.self) { storeKey in
                        let storeSellers = groups[storeKey] ?? []
                        // ارزان‌ترین موجودیِ این فروشگاه (مثل سایت)
                        let cheapest = storeSellers.min { ($0.finalPrice ?? Int64.max) < ($1.finalPrice ?? Int64.max) } ?? storeSellers[0]
                        sellerRow(storeKey: storeKey, storeSellers: storeSellers, cheapest: cheapest, isSelected: storeKey == selectedStoreKey)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func sellerRow(storeKey: Int, storeSellers: [ProductSellerDto], cheapest: ProductSellerDto, isSelected: Bool) -> some View {
        let store = cheapest.store
        let logoUrl = store != nil ? store?.logo?.url : mainShopLogoUrl
        let name = store?.name ?? (mainShopName?.isBlankShk == false ? mainShopName! : "فروشگاه اصلی")
        return SiteCard(
            onClick: { if !isSelected { onSellerSelected(cheapest) } },
            contentPadding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
            borderColor: isSelected ? colors.primary : .clear
        ) {
            HStack(spacing: 0) {
                RemixIcon(isSelected ? RemixIcons.CheckboxCircleFill : RemixIcons.CheckboxBlankCircleLine,
                          tint: isSelected ? colors.primary : colors.outline, size: 22)
                Spacer().frame(width: 10)
                StoreLogoBox(logoUrl: logoUrl, name: name, size: 38)
                Spacer().frame(width: 10)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).shkFont(13, .bold).foregroundColor(colors.onSurface).lineLimit(1)
                    // زمان ارسال (مثل لیست فروشندگان سایت: send_time یا «آماده ارسال»)
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.TruckLine, tint: colors.onSurfaceVariant, size: 13)
                        Spacer().frame(width: 4)
                        Text(cheapest.sendTime.flatMap { $0.isBlankShk ? nil : $0.toPersianDigits() } ?? "آماده ارسال")
                            .shkFont(11).foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                    }
                    if let commitment = store?.meta?.commitmentToSend {
                        Text("تعهد ارسال: \(commitment.toPersianDigits())٪").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    // اگه این فروشگاه چند موجودی داره، قیمت از ارزان‌ترینشون شروع می‌شه
                    if storeSellers.count > 1 {
                        Text("از").shkFont(10).foregroundColor(colors.onSurfaceVariant)
                    }
                    Text(cheapest.formattedFinalPrice.map { "\($0.toPersianDigits()) تومان" } ?? "-")
                        .shkFont(13, .bold)
                        .foregroundColor(isSelected ? colors.primary : colors.onSurface)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - قیمت پله‌ای

/**
 * جدول قیمت پله‌ای (خرید عمده) یک موجودی خاص (discount_tree). هر ردیف یعنی «از تعداد N به بالا،
 * قیمت واحد می‌شود P». یک باکسِ کلیک‌پذیر نمایش داده می‌شه و با کلیک، جدول کامل در مودال باز می‌شه.
 */
struct TieredPricingTable: View {
    let tiers: [DiscountTierDto]?
    @Environment(\.shkColors) private var colors

    var body: some View {
        // فاز ۳۴: ردیف‌های ناقص کنار گذاشته می‌شن و count تکراری یکتا می‌شه
        var seen = Set<Int>()
        var valid: [(Int, Int64)] = []
        for t in tiers ?? [] {
            if let c = t.count, c > 0, let p = t.price, p > 0, seen.insert(c).inserted { valid.append((c, p)) }
        }
        let sorted = valid.sorted { $0.0 < $1.0 }
        let cheapest = sorted.map(\.1).min() ?? 0

        return Group {
            if !sorted.isEmpty {
                SiteCard(onClick: {
                    ShkDialogCenter.shared.show { TieredPricingModal(sortedTiers: sorted, cheapestPrice: cheapest) }
                }) {
                    HStack(spacing: 0) {
                        SiteIconBadge(icon: RemixIcons.StackLine, size: 42, iconSize: 21)
                        Spacer().frame(width: 12)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("قیمت خرید عمده (همکاری)").shkFont(13, .bold).foregroundColor(colors.onSurface)
                            Text("با خرید تعداد بیشتر، قیمت واحد کمتر می‌شود").shkFont(11, lineHeight: 18).foregroundColor(colors.onSurfaceVariant)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        RemixIcon(RemixIcons.ArrowLeftSLine, tint: colors.onSurfaceVariant, size: 20)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/** مودالِ جدول کامل قیمت‌های پله‌ای (با برچسب «به‌صرفه‌ترین قیمت» روی ارزان‌ترین پله) */
private struct TieredPricingModal: View {
    let sortedTiers: [(Int, Int64)]
    let cheapestPrice: Int64
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteDialogContent(
            title: "قیمت خرید عمده (همکاری)",
            icon: RemixIcons.StackLine,
            confirmText: "بستن",
            onConfirm: { ShkDialogCenter.shared.dismiss() }
        ) {
            VStack(spacing: 8) {
                ForEach(Array(sortedTiers.enumerated()), id: \.offset) { _, tier in
                    let (count, price) = tier
                    let isBestDeal = price == cheapestPrice
                    let primary = colors.primary
                    let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.PriceTag3Line, tint: isBestDeal ? primary : colors.onSurfaceVariant, size: 18)
                        Spacer().frame(width: 8)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(count.toPersianDigits()) عدد و بیشتر").shkFont(13, .medium).foregroundColor(colors.onSurface)
                            if isBestDeal {
                                SiteStatusChip(text: "به‌صرفه‌ترین قیمت", color: primary).padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(formatTomanFa(price)) تومان")
                            .shkFont(13, .bold)
                            .foregroundColor(isBestDeal ? primary : colors.onSurface)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(shape.fill(isBestDeal ? primary.opacity(0.07) : colors.surfaceVariant.opacity(0.6)))
                    .overlay(shape.strokeBorder(isBestDeal ? primary.opacity(0.5) : .clear, lineWidth: 1))
                }
            }
        }
    }
}

// MARK: - محصولات مرتبط

/**
 * کاروسل محصولات مرتبط: قابل کشیدن با دست + اسلاید خودکار هر ۳ ثانیه. کارت‌ها دقیقاً همون
 * ProductCard اصلی هستن.
 */
struct RelatedProductsCarousel: View {
    let products: [RelatedProductDto]
    let onProductClick: (String) -> Void

    @State private var autoIndex = 0
    @State private var isDragging = false

    var body: some View {
        // فاز ۳۴ (رفع کرش): لیست سرور گاهی یک شناسه رو بیش از یک بار داره - یکتاسازی
        var seen = Set<Int>()
        let unique = products.filter { seen.insert($0.id).inserted }

        return Group {
            if !unique.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // بازطراحی: عنوان بخش با خط قرمز (هم‌سبک ماژول‌های صفحه‌ی اصلی)
                    SiteSectionTitle("محصولات مرتبط").padding(.horizontal, 16).padding(.bottom, 10)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: 10) {
                                ForEach(Array(unique.enumerated()), id: \.element.id) { index, product in
                                    ProductCard(product: product.toProductListItemDto(), onClick: { onProductClick(product.slug) })
                                        .frame(width: PRODUCT_CARD_CAROUSEL_WIDTH)
                                        .id(index)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .simultaneousGesture(DragGesture().onChanged { _ in isDragging = true }.onEnded { _ in isDragging = false })
                        // اسلاید خودکار هر ۳ ثانیه، مگر اینکه کاربر همین الان با دست اسکرول کند
                        .task(id: unique.count) {
                            while !Task.isCancelled {
                                try? await Task.sleep(nanoseconds: 3_000_000_000)
                                if Task.isCancelled { break }
                                if !isDragging {
                                    autoIndex = (autoIndex + 1) % unique.count
                                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(autoIndex, anchor: .leading) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - مشخصات فنی

/** بازطراحی: ردیف «عنوان مشخصه ..... مقدار» - مشترک بین صفحه‌ی مشخصات و خلاصه‌ی صفحه‌ی محصول */
struct SpecKeyValueRow: View {
    let specKey: SpecificationKeyDto
    @Environment(\.shkColors) private var colors

    var body: some View {
        WeightedRow(weights: [0.42, 0.58], spacing: 10) {
            Text(specKey.key)
                .shkFont(12, lineHeight: 21)
                .foregroundColor(colors.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(specKey.value ?? "")
                .shkFont(13, .medium, lineHeight: 22)
                .foregroundColor(colors.onSurface)
                // TextAlign.Left اندروید (چپ فیزیکی حتی در RTL)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

/// معادل Row با Modifier.weight(...) کامپوز: عرض بین فرزندها به نسبت وزن‌ها تقسیم می‌شه (تراز بالا)
struct WeightedRow: Layout {
    let weights: [CGFloat]
    var spacing: CGFloat = 0

    private func widths(_ total: CGFloat, _ count: Int) -> [CGFloat] {
        let ws = (0..<count).map { $0 < weights.count ? weights[$0] : 0 }
        let sum = ws.reduce(0, +)
        let free = max(0, total - spacing * CGFloat(max(0, count - 1)))
        return ws.map { sum > 0 ? free * $0 / sum : 0 }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let total = proposal.width ?? 300
        let w = widths(total, subviews.count)
        var h: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            h = max(h, v.sizeThatFits(ProposedViewSize(width: w[i], height: nil)).height)
        }
        return CGSize(width: total, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let w = widths(bounds.width, subviews.count)
        var x = bounds.minX
        for (i, v) in subviews.enumerated() {
            v.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: w[i], height: nil))
            x += w[i] + spacing
        }
    }
}

/// معادل FullSpecsScreen اندروید: جدول کامل مشخصات فنی، هر گروه در یک کارت
struct FullSpecsScreen: View {
    let groups: [SpecificationGroupDto]
    let onBack: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        VStack(spacing: 0) {
            // بازطراحی: نوار بالای استاندارد صفحه‌ها
            SitePageTopBar(title: "مشخصات فنی محصول", onBack: onBack)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                        SiteSectionTitle(group.title).padding(.top, index == 0 ? 0 : 10)
                        let filledKeys = group.keys.filter { !($0.value?.isBlankShk ?? true) }
                        if !filledKeys.isEmpty {
                            SiteCard(contentPadding: EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14)) {
                                ForEach(Array(filledKeys.enumerated()), id: \.offset) { rowIndex, specKey in
                                    if rowIndex > 0 { SiteDashedDivider() }
                                    SpecKeyValueRow(specKey: specKey)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
        .background(colors.background.ignoresSafeArea())
    }
}
