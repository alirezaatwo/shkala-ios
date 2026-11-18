import SwiftUI

// فقط عکس‌برداری (شاخه‌ی موقت): داده‌ی نمونه‌ی همکاری با «-shkPartner <حالت>»
enum ScreenshotPartnerSamples {
    static var variant: String? {
        let args = ProcessInfo.processInfo.arguments
        guard ScreenshotMode.isActive, let i = args.firstIndex(of: "-shkPartner"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func state() -> PartnerStateDto? {
        guard let v = variant else { return nil }
        let level: Int
        var state = "draft"
        var extra = ""
        switch v {
        case "new": level = 0
        case "docs": level = 1
        case "bale": level = 3
        case "ready": level = 4
        case "submitted": level = 4; state = "submitted"; extra = #","submitted_at":"1405/08/27 - 16:22""#
        case "rejected": level = 4; state = "rejected"; extra = #","reject_reason":"تصویر جواز کسب خوانا نیست؛ لطفاً عکس واضح‌تری بارگذاری کنید.","retry_at":"1405/08/30 - 16:22""#
        default: level = 0
        }
        func doc(_ kind: String, _ step: String, _ req: Bool, _ pdf: Bool, _ up: Bool, _ name: String) -> String {
            #"{"kind":"\#(kind)","step":"\#(step)","required":\#(req),"accept":"\#(pdf ? ".jpg,.png,.pdf" : ".jpg,.png")","uploaded":\#(up),"name":\#(up ? "\"\(name)\"" : "null")}"#
        }
        let docs = [
            doc("national_card", "documents", true, false, level >= 1, "national-card.jpg"),
            doc("license", "documents", true, true, level >= 2, "license.pdf"),
            doc("business_card", "documents", false, true, false, ""),
            doc("storefront", "documents", false, false, level >= 2, "shop.jpg"),
            doc("instagram", "instagram", true, false, level >= 3, "instagram.png"),
        ].joined(separator: ",")
        let json = """
        {"ready":true,"state":"\(state)","editable":\(state == "draft"),"steps":{
        "account":{"name":true,"phone":true,"address":\(level >= 1),"ok":\(level >= 1)},
        "documents":{"ok":\(level >= 2)},
        "instagram":{"ok":\(level >= 3),"page_url":"https://instagram.com/example"},
        "bale":{"ready":true,"ok":\(level >= 4),"linked":\(level >= 4),"checked_at":\(level >= 4 ? "\"1405/08/27 - 16:20\"" : "null"),"code":"K7XR2MQP","bot":"@ShopPartnerBot","bot_url":"https://ble.ir","channel_url":"https://ble.ir"}},
        "documents":[\(docs)],"can_submit":\(level >= 4 && state == "draft"),"max_kb":10240\(extra)}
        """
        return try? ShkJSON.decoder.decode(PartnerStateDto.self, from: Data(json.utf8))
    }

    static func commissions() -> PartnerCommissionsResponse? {
        guard variant != nil else { return nil }
        func rate(_ c: String, _ max: String, _ p: Bool) -> String { #"{"commission":\#(c),"max":\#(max),"partner":\#(p)}"# }
        let items: [(String, [String], [Bool], String)] = [
            ("دوربین مداربسته بولت ۴ مگاپیکسل دید در شب رنگی", ["3", "4", "5.5"], [true, true, true], "150000"),
            ("دستگاه ضبط NVR هشت کانال پشتیبانی تا ۸ مگاپیکسل", ["2", "2.5", "3"], [false, true, true], "null"),
            ("هارد دیسک اینترنال ۲ ترابایت مخصوص دوربین مداربسته", ["1.5", "2", "2"], [false, false, true], "50000"),
            ("دوربین دام وای‌فای چرخشی با هشدار حرکت", ["4", "5", "6"], [true, true, true], "null"),
            ("منبع تغذیه سوئیچینگ ۱۲ ولت ۱۰ آمپر", ["null", "1", "1.5"], [false, false, false], "null"),
        ]
        let products = items.enumerated().map { i, it in
            #"{"id":\#(i + 1),"uuid":"u\#(i)","slug":"p\#(i)","title":"\#(it.0)","image":null,"link":"https://example.com/p/u\#(i)?u=12","rates":{"bronze":\#(rate(it.1[0], it.3, it.2[0])),"silver":\#(rate(it.1[1], it.3, it.2[1])),"gold":\#(rate(it.1[2], it.3, it.2[2]))}}"#
        }.joined(separator: ",")
        let status = variant == "suspended" ? "suspended" : "active"
        let json = #"{"status":"ok","partner_status":"\#(status)","level":"silver","products":[\#(products)],"pagination":{"current_page":1,"last_page":1}}"#
        return try? ShkJSON.decoder.decode(PartnerCommissionsResponse.self, from: Data(json.utf8))
    }
}
