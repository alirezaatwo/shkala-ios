import UIKit
import QuickLook

// ===================================================================================
// معادل ui/account/InvoicePdfGenerator.kt
// فاکتور PDF سفارش، دقیقاً با همان چیدمان، اندازه‌ها و رنگ‌های اپ اندروید (A4 افقی ۸۴۲×۵۹۵).
// ===================================================================================

// ابعاد دقیق A4 افقی (Landscape) - همون چیزی که خود سایت استفاده می‌کنه
private let PAGE_WIDTH: CGFloat = 842
private let PAGE_HEIGHT: CGFloat = 595

private let MARGIN_LEFT: CGFloat = 55
private let MARGIN_RIGHT: CGFloat = 54
private let CONTENT_RIGHT: CGFloat = PAGE_WIDTH - MARGIN_RIGHT // ≈ 788
private let CONTENT_LEFT: CGFloat = MARGIN_LEFT // 55
private let CONTENT_WIDTH: CGFloat = CONTENT_RIGHT - CONTENT_LEFT // ≈ 733

private func hexColor(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
    UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// بازطراحی: رنگ‌های برند (قرمز #E60012) + خاکستری‌های روشن برای جدول
private let BRAND_RED = hexColor(0xE60012)
private let BRAND_RED_DARK = hexColor(0xB8000E)
private let BRAND_RED_SOFT = hexColor(0xFDECEE)
private let BORDER_COLOR = hexColor(0xE3E4EA)
private let HEADER_BG = hexColor(0xF3F4F7)
private let ZEBRA_BG = hexColor(0xF8F9FB)
private let TEXT_DARK = hexColor(0x2B2D36)
private let TEXT_MUTED = hexColor(0x7A7F8C)

// اطلاعات ثابت خود فروشگاه - دقیقاً مطابق نمونه‌ی واقعی فاکتور سایت.
private enum SellerInfo {
    static let TITLE = "سیما حفاظ خزر | نظارت، امنیت، انرژی و تکنولوژی"
    static let STATE = "گیلان"
    static let CITY = "رشت"
    static let PHONE = "01333234659"
    static let POSTAL_CODE = "4155740006"
    static let ADDRESS = "گیلان، رشت، رشتیان، بلوار شمسی‌پور، ابتدای خیابان احمدیان، فروشگاه سیما حفاظ خزر"
}

/** تراز متن (معادل Layout.Alignment اندروید در متن راست‌به‌چپ) */
private enum CellAlign { case normal, opposite, center }

enum InvoicePdfGenerator {

    /**
     * لوگو رو هر بار مستقیم از سایت می‌گیره (نه از فایلی که تو خود اپ
     * بسته‌بندی شده) - این‌جوری اگه روزی از پنل ادمین لوگو عوض بشه، بدون
     * نیاز به بیلد جدید اپ، خودکار به‌روز می‌شه. فقط اگه دانلود لوگو به هر
     * دلیلی (قطعی اینترنت و غیره) شکست بخوره، از نسخه‌ی پشتیبان داخل اپ استفاده می‌کنه.
     */
    static func generate(order: OrderDetailDto, logoUrl: String?) async throws -> URL {
        let logo = await fetchLogo(logoUrl)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: PAGE_WIDTH, height: PAGE_HEIGHT))
        let data = renderer.pdfData { context in
            context.beginPage()
            InvoiceDrawer(cg: context.cgContext, logo: logo).draw(order)
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("invoices", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("invoice-\(order.uuid).pdf")
        try data.write(to: file)
        return file
    }

    private static func fetchLogo(_ logoUrl: String?) async -> UIImage? {
        if let logoUrl, let url = URL(string: logoUrl) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            if let (data, _) = try? await URLSession.shared.data(for: request), let image = UIImage(data: data) {
                return image
            }
        }
        // نسخه‌ی پشتیبان (فقط اگه دانلود لوگوی واقعی ممکن نبود)
        return UIImage(named: "logo_invoice")
    }

    /** باز کردن PDF در نمایشگر سیستم (معادل ACTION_VIEW اندروید؛ اشتراک‌گذاری از دکمه‌ی همان نمایشگر) */
    @MainActor
    static func openOrSharePdf(_ file: URL) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              var top = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        let preview = QLPreviewController()
        let source = PdfPreviewSource(file: file)
        preview.dataSource = source
        objc_setAssociatedObject(preview, &PdfPreviewSource.key, source, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        top.present(preview, animated: true)
    }
}

private final class PdfPreviewSource: NSObject, QLPreviewControllerDataSource {
    static var key: UInt8 = 0
    let file: URL
    init(file: URL) { self.file = file }
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { file as NSURL }
}

/**
 * رسم فاکتور - بازطراحی با سبک جدید برند: نوار قرمز بالای صفحه با لوگو، کارت‌های گوشه‌گرد
 * خریدار/فروشنده، جدول تمیز با سرتیتر گوشه‌گرد قرمز و ردیف‌های راه‌راه خاکستری روشن، کادر
 * جمع‌ها و پانویس با اطلاعات تماس فروشگاه.
 */
private struct InvoiceDrawer {
    let cg: CGContext
    let logo: UIImage?

    private func font(_ size: CGFloat, _ isBold: Bool) -> UIFont {
        ShkFont.uiYekan(size, isBold ? .bold : .normal)
    }

    private func drawCellText(_ text: String, _ rect: CGRect, _ size: CGFloat, isBold: Bool = false, color: UIColor = TEXT_DARK, align: CellAlign = .normal) {
        if text.trimmingCharacters(in: .whitespaces).isEmpty { return }
        let style = NSMutableParagraphStyle()
        style.baseWritingDirection = .rightToLeft
        switch align {
        case .normal: style.alignment = .right
        case .opposite: style.alignment = .left
        case .center: style.alignment = .center
        }
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [.font: font(size, isBold), .foregroundColor: color, .paragraphStyle: style]
        let attributed = NSAttributedString(string: text, attributes: attrs)
        let width = max(rect.width - 10, 10)
        let bounds = attributed.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let height = ceil(bounds.height)
        let y = max(rect.minY + (rect.height - height) / 2, rect.minY + 1)
        attributed.draw(with: CGRect(x: rect.maxX - 5 - width, y: y, width: width, height: height), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    private func fill(_ rect: CGRect, _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fill(rect)
    }

    private func fillRound(_ rect: CGRect, _ radius: CGFloat, _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath)
        cg.fillPath()
    }

    private func strokeRound(_ rect: CGRect, _ radius: CGFloat, _ color: UIColor = BORDER_COLOR, _ width: CGFloat = 0.8) {
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath)
        cg.strokePath()
    }

    /** مستطیل گوشه‌گرد با گوشه‌های جداگانه (بالا/پایین) - برای سرتیتر و ردیف آخر جدول */
    private func roundRectPath(_ rect: CGRect, top: CGFloat, bottom: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + top), radius: top)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        p.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - bottom, y: rect.maxY), radius: bottom)
        p.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bottom), radius: bottom)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        p.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + top, y: rect.minY), radius: top)
        p.closeSubpath()
        return p
    }

    private func fillPath(_ path: CGPath, _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.addPath(path)
        cg.fillPath()
    }

    private func strokePath(_ path: CGPath, _ color: UIColor = BORDER_COLOR, _ width: CGFloat = 0.8) {
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.addPath(path)
        cg.strokePath()
    }

    private func hLine(_ x0: CGFloat, _ x1: CGFloat, _ y: CGFloat, _ color: UIColor = BORDER_COLOR, _ width: CGFloat = 0.7) {
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.move(to: CGPoint(x: x0, y: y))
        cg.addLine(to: CGPoint(x: x1, y: y))
        cg.strokePath()
    }

    private func vLine(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat, _ color: UIColor = BORDER_COLOR, _ width: CGFloat = 0.7) {
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.move(to: CGPoint(x: x, y: y0))
        cg.addLine(to: CGPoint(x: x, y: y1))
        cg.strokePath()
    }

    private func rect(_ l: CGFloat, _ t: CGFloat, _ r: CGFloat, _ b: CGFloat) -> CGRect {
        CGRect(x: l, y: t, width: r - l, height: b - t)
    }

    func draw(_ order: OrderDetailDto) {
        // ---- نوار قرمز بالای صفحه: لوگو (راست)، «فاکتور فروش» (وسط)، تاریخ/شماره سفارش (چپ) ----
        let bandHeight: CGFloat = 80
        fill(rect(0, 0, PAGE_WIDTH, bandHeight), BRAND_RED)
        fill(rect(0, bandHeight, PAGE_WIDTH, bandHeight + 3), BRAND_RED_DARK)

        let white = UIColor.white
        let jalaliDate = order.jalaliCreatedAt.jalaliDateLabel() ?? ""
        drawCellText("تاریخ: \(persianDigitsMixed(jalaliDate))", rect(CONTENT_LEFT, 20, CONTENT_LEFT + 210, 38), 10.5, isBold: true, color: white, align: .opposite)
        drawCellText("شماره سفارش: \(order.uuid.toPersianDigits())", rect(CONTENT_LEFT, 42, CONTENT_LEFT + 210, 60), 10.5, isBold: true, color: white, align: .opposite)

        drawCellText("فاکتور فروش", rect(PAGE_WIDTH / 2 - 110, 18, PAGE_WIDTH / 2 + 110, 50), 20, isBold: true, color: white, align: .center)
        // خط کوچک زیر عنوان
        fillRound(rect(PAGE_WIDTH / 2 - 22, 54, PAGE_WIDTH / 2 + 22, 57), 2, UIColor(white: 1, alpha: 170.0 / 255.0))

        // لوگو داخل یک کادر سفید گوشه‌گرد
        let logoBox = rect(CONTENT_RIGHT - 128, 14, CONTENT_RIGHT, 66)
        fillRound(logoBox, 10, white)
        if let logo, logo.size.width > 0, logo.size.height > 0 {
            let maxW = logoBox.width - 14
            let maxH = logoBox.height - 10
            let scale = min(maxW / logo.size.width, maxH / logo.size.height)
            let w = logo.size.width * scale
            let h = logo.size.height * scale
            logo.draw(in: CGRect(x: logoBox.midX - w / 2, y: logoBox.midY - h / 2, width: w, height: h))
        } else {
            drawCellText(sellerShortTitle, logoBox, 11, isBold: true, color: BRAND_RED, align: .center)
        }

        // ---- کارت‌های خریدار / فروشنده ----
        let boxTop: CGFloat = 98
        let boxHeaderHeight: CGFloat = 26
        let rowHeight: CGFloat = 24
        let boxBottom = boxTop + boxHeaderHeight + rowHeight * 3
        let gap: CGFloat = 12

        let sellerColRight = CONTENT_RIGHT
        let sellerColLeft = CONTENT_LEFT + CONTENT_WIDTH / 2 + gap / 2
        let buyerColRight = CONTENT_LEFT + CONTENT_WIDTH / 2 - gap / 2
        let buyerColLeft = CONTENT_LEFT

        drawPartyCard(buyerColLeft, buyerColRight, boxTop, boxBottom, boxHeaderHeight, "خریدار")
        drawPartyCard(sellerColLeft, sellerColRight, boxTop, boxBottom, boxHeaderHeight, "فروشنده")

        let buyerAddress = order.address?["address"]?.objectValue ?? [:]
        func field(_ key: String) -> String { buyerAddress[key]?.stringValue ?? "" }
        let buyerName = "\(field("first_name")) \(field("last_name"))".trimmingCharacters(in: .whitespaces)
        let buyerState = field("state")
        let buyerCity = field("city")
        let buyerPhone = field("phone")
        let buyerPostal = field("postal_code")
        let buyerFullAddress = field("full_address")

        var rowY = boxTop + boxHeaderHeight
        drawInfoTripleRow(buyerColLeft, buyerColRight, rowY, rowHeight, "نام", buyerName, "استان", buyerState, "شهر", buyerCity)
        drawInfoTripleRow(sellerColLeft, sellerColRight, rowY, rowHeight, "عنوان", SellerInfo.TITLE, "استان", SellerInfo.STATE, "شهر", SellerInfo.CITY)
        rowY += rowHeight

        drawInfoDoubleRow(buyerColLeft, buyerColRight, rowY, rowHeight, "کدپستی", persianDigitsMixed(buyerPostal), "تلفن", persianDigitsMixed(buyerPhone))
        drawInfoDoubleRow(sellerColLeft, sellerColRight, rowY, rowHeight, "کدپستی", persianDigitsMixed(SellerInfo.POSTAL_CODE), "تلفن", persianDigitsMixed(SellerInfo.PHONE))
        rowY += rowHeight

        drawInfoSingleRow(buyerColLeft, buyerColRight, rowY, rowHeight, "نشانی", buyerFullAddress, isLast: true)
        drawInfoSingleRow(sellerColLeft, sellerColRight, rowY, rowHeight, "نشانی", SellerInfo.ADDRESS, isLast: true)

        // ---- جدول اقلام ----
        let tableTop = boxBottom + 16
        let tableHeaderHeight: CGFloat = 28
        let itemRowHeight: CGFloat = 27
        let totalsRowHeight: CGFloat = 28

        // عرض ستون‌ها (راست به چپ) - همون نسبت‌های قبلی
        let cIdW: CGFloat = 85.6
        let cQtyW: CGFloat = 43.5
        let cUnitW: CGFloat = 70.6
        let cDiscW: CGFloat = 63.7
        let cFinalW: CGFloat = 70.7
        let cDescW = CONTENT_WIDTH - cIdW - cQtyW - cUnitW - cDiscW - cFinalW // ≈ 400

        let xId1 = CONTENT_RIGHT, xId0 = xId1 - cIdW
        let xDesc1 = xId0, xDesc0 = xDesc1 - cDescW
        let xQty1 = xDesc0, xQty0 = xQty1 - cQtyW
        let xUnit1 = xQty0, xUnit0 = xUnit1 - cUnitW
        let xDisc1 = xUnit0, xDisc0 = xDisc1 - cDiscW
        let xFinal1 = xDisc0, xFinal0 = CONTENT_LEFT
        let columnSeparators = [xId0, xDesc0, xQty0, xUnit0, xDisc0]

        // سرتیتر گوشه‌گرد قرمز
        fillPath(roundRectPath(rect(CONTENT_LEFT, tableTop, CONTENT_RIGHT, tableTop + tableHeaderHeight), top: 8, bottom: 0), BRAND_RED)
        for x in columnSeparators { vLine(x, tableTop + 6, tableTop + tableHeaderHeight - 6, UIColor(white: 1, alpha: 90.0 / 255.0)) }
        let headerBottom = tableTop + tableHeaderHeight
        drawCellText("شناسه محصول", rect(xId0, tableTop, xId1, headerBottom), 9.5, isBold: true, color: white, align: .center)
        drawCellText("شرح کالا یا خدمات", rect(xDesc0, tableTop, xDesc1, headerBottom), 9.5, isBold: true, color: white, align: .center)
        drawCellText("تعداد", rect(xQty0, tableTop, xQty1, headerBottom), 9.5, isBold: true, color: white, align: .center)
        drawCellText("مبلغ واحد", rect(xUnit0, tableTop, xUnit1, headerBottom), 9.5, isBold: true, color: white, align: .center)
        drawCellText("تخفیف کل", rect(xDisc0, tableTop, xDisc1, headerBottom), 9.5, isBold: true, color: white, align: .center)
        drawCellText("مبلغ نهایی", rect(xFinal0, tableTop, xFinal1, headerBottom), 9.5, isBold: true, color: white, align: .center)

        var rowTop = headerBottom
        let allItems = order.consignments.flatMap(\.items)
        var sumCount = 0
        var sumDiscount: Int64 = 0
        var sumFinal: Int64 = 0
        var sumUnitTotal: Int64 = 0

        for (index, item) in allItems.enumerated() {
            let props = (item.props ?? []).map { "\($0.name ?? "null"): \($0.displayValue ?? "null")" }.joined(separator: " | ")
            let desc = props.trimmingCharacters(in: .whitespaces).isEmpty ? item.title : "\(item.title) | \(props)"
            let unitPrice = item.price ?? 0
            let discountTotal = (item.discount ?? 0) * Int64(item.count)
            let rowBottom = rowTop + itemRowHeight

            // ردیف‌های راه‌راه (زوج سفید، فرد خاکستری خیلی روشن)
            fill(rect(CONTENT_LEFT, rowTop, CONTENT_RIGHT, rowBottom), index % 2 == 1 ? ZEBRA_BG : .white)
            for x in columnSeparators { vLine(x, rowTop, rowBottom) }
            hLine(CONTENT_LEFT, CONTENT_RIGHT, rowBottom)

            drawCellText(item.product?.uuid ?? "-", rect(xId0, rowTop, xId1, rowBottom), 8.5, color: TEXT_MUTED, align: .center)
            drawCellText(desc, rect(xDesc0 + 4, rowTop, xDesc1 - 4, rowBottom), 9)
            drawCellText(item.count.toPersianDigits(), rect(xQty0, rowTop, xQty1, rowBottom), 9.5, align: .center)
            drawCellText("\(formatToman(unitPrice)) تومان", rect(xUnit0, rowTop, xUnit1, rowBottom), 8.5, align: .center)
            drawCellText("\(formatToman(discountTotal)) تومان", rect(xDisc0, rowTop, xDisc1, rowBottom), 8.5, color: discountTotal > 0 ? BRAND_RED : TEXT_DARK, align: .center)
            drawCellText("\(formatToman(item.fullCountPrice - discountTotal)) تومان", rect(xFinal0, rowTop, xFinal1, rowBottom), 8.5, isBold: true, align: .center)

            sumCount += item.count
            sumDiscount += discountTotal
            sumFinal += item.fullCountPrice - discountTotal
            sumUnitTotal += unitPrice * Int64(item.count)
            rowTop += itemRowHeight
        }

        // ردیف جمع کل - خاکستری با گوشه‌های گرد پایین
        let totalsBottom = rowTop + totalsRowHeight
        fillPath(roundRectPath(rect(CONTENT_LEFT, rowTop, CONTENT_RIGHT, totalsBottom), top: 0, bottom: 8), HEADER_BG)
        for x in columnSeparators.dropFirst() { vLine(x, rowTop, totalsBottom) }
        // کادر دور کل بدنه‌ی جدول (زیر سرتیتر تا پایین ردیف جمع)
        strokePath(roundRectPath(rect(CONTENT_LEFT, headerBottom, CONTENT_RIGHT, totalsBottom), top: 0, bottom: 8))
        drawCellText("جمع کل:", rect(xDesc0, rowTop, xId1, totalsBottom), 10.5, isBold: true, align: .opposite)
        drawCellText(sumCount.toPersianDigits(), rect(xQty0, rowTop, xQty1, totalsBottom), 9.5, isBold: true, align: .center)
        drawCellText("\(formatToman(sumUnitTotal)) تومان", rect(xUnit0, rowTop, xUnit1, totalsBottom), 8.5, isBold: true, align: .center)
        drawCellText("\(formatToman(sumDiscount)) تومان", rect(xDisc0, rowTop, xDisc1, totalsBottom), 8.5, isBold: true, align: .center)
        drawCellText("\(formatToman(sumFinal)) تومان", rect(xFinal0, rowTop, xFinal1, totalsBottom), 8.5, isBold: true, align: .center)

        rowTop += totalsRowHeight + 12

        // ---- کادر جمع‌ها: هزینه‌ی ارسال (راست) | مبلغ پرداخت‌شده (چپ، قرمز و پررنگ) ----
        let sendPrice = order.totalBill?.sendPrice ?? 0
        let finalPaid = (order.totalBill?.price ?? 0) + (order.taxAmount ?? 0) + sendPrice
        let bottomRowHeight: CGFloat = 32
        let bottomSplit = CONTENT_LEFT + CONTENT_WIDTH * 0.578

        let sendRect = rect(bottomSplit + 5, rowTop, CONTENT_RIGHT, rowTop + bottomRowHeight)
        let paidRect = rect(CONTENT_LEFT, rowTop, bottomSplit - 5, rowTop + bottomRowHeight)
        fillRound(sendRect, 8, HEADER_BG)
        fillRound(paidRect, 8, BRAND_RED_SOFT)
        strokeRound(paidRect, 8, BRAND_RED, 1)

        drawCellText("هزینه ارسال: \(formatToman(sendPrice)) تومان", sendRect, 10, align: .center)
        drawCellText("مبلغ پرداخت شده: \(formatToman(finalPaid)) تومان", paidRect, 11.5, isBold: true, color: BRAND_RED, align: .center)

        rowTop += bottomRowHeight + 16

        // ---- پانویس: اطلاعات تماس فروشگاه + راهنمای چاپ (پایین صفحه، یا بلافاصله بعد از محتوا اگه جا نبود) ----
        let footerTop = max(rowTop, PAGE_HEIGHT - 58)
        hLine(CONTENT_LEFT, CONTENT_RIGHT, footerTop, BRAND_RED, 1.2)
        drawCellText(
            "\(sellerShortTitle)  |  تلفن: \(persianDigitsMixed(SellerInfo.PHONE))  |  نشانی: \(SellerInfo.ADDRESS)",
            rect(CONTENT_LEFT, footerTop + 5, CONTENT_RIGHT, footerTop + 23), 8.5, color: TEXT_DARK, align: .center
        )
        drawCellText(
            "* در صورت چاپ فاکتور لطفا اندازه صفحه را روی A4 و حالت پرینت را حداقل روی background graphics تنظیم نمایید.",
            rect(CONTENT_LEFT, footerTop + 24, CONTENT_RIGHT, footerTop + 42), 8, color: TEXT_MUTED, align: .center
        )
    }

    private var sellerShortTitle: String {
        (SellerInfo.TITLE.components(separatedBy: "|").first ?? "").trimmingCharacters(in: .whitespaces)
    }

    /** قاب کارت خریدار/فروشنده: کادر گوشه‌گرد، نوار عنوان خاکستری روشن با خط قرمز کوچک کنار عنوان */
    private func drawPartyCard(_ left: CGFloat, _ right: CGFloat, _ top: CGFloat, _ bottom: CGFloat, _ headerHeight: CGFloat, _ title: String) {
        let card = rect(left, top, right, bottom)
        fillRound(card, 10, .white)
        fillPath(roundRectPath(rect(left, top, right, top + headerHeight), top: 10, bottom: 0), HEADER_BG)
        strokeRound(card, 10)
        fillRound(rect(right - 14, top + 7, right - 10, top + headerHeight - 7), 2, BRAND_RED)
        drawCellText(title, rect(left, top, right - 14, top + headerHeight), 11.5, isBold: true)
    }

    private func drawInfoTripleRow(_ left: CGFloat, _ right: CGFloat, _ top: CGFloat, _ height: CGFloat, _ l1: String, _ v1: String, _ l2: String, _ v2: String, _ l3: String, _ v3: String) {
        let w = right - left
        let c1r = right, c1l = right - w * 0.5
        let c2r = c1l, c2l = right - w * 0.75
        let c3r = c2l, c3l = left
        vLine(c1l, top + 5, top + height - 5)
        vLine(c2l, top + 5, top + height - 5)
        hLine(left + 8, right - 8, top + height)
        drawCellText("\(l1): \(v1)", rect(c1l, top, c1r - 4, top + height), 8.8)
        drawCellText("\(l2): \(v2)", rect(c2l, top, c2r, top + height), 8.8)
        drawCellText("\(l3): \(v3)", rect(c3l + 4, top, c3r, top + height), 8.8)
    }

    private func drawInfoDoubleRow(_ left: CGFloat, _ right: CGFloat, _ top: CGFloat, _ height: CGFloat, _ l1: String, _ v1: String, _ l2: String, _ v2: String) {
        let mid = left + (right - left) / 2
        vLine(mid, top + 5, top + height - 5)
        hLine(left + 8, right - 8, top + height)
        drawCellText("\(l1): \(v1)", rect(mid, top, right - 4, top + height), 8.8)
        drawCellText("\(l2): \(v2)", rect(left + 4, top, mid, top + height), 8.8)
    }

    private func drawInfoSingleRow(_ left: CGFloat, _ right: CGFloat, _ top: CGFloat, _ height: CGFloat, _ label: String, _ value: String, isLast: Bool = false) {
        if !isLast { hLine(left + 8, right - 8, top + height) }
        drawCellText("\(label): \(value)", rect(left + 4, top, right - 4, top + height), 8.8)
    }

    private func formatToman(_ amount: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return persianDigitsMixed(formatter.string(from: NSNumber(value: amount)) ?? String(amount))
    }

    private func persianDigitsMixed(_ s: String) -> String {
        let digits: [Character] = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
        return String(s.map { c in
            if let v = c.wholeNumberValue, c.isASCII { return digits[v] }
            return c
        })
    }
}
