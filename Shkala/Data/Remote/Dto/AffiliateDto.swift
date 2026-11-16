import Foundation

/**
 * معادل AffiliateDto.kt اپ اندروید (۳.۷).
 * لینک همکاری در فروش که با اپ باز شده (POST api/v2/affiliate/referral):
 * saved = معرف برای همین نصب و همین محصول ۷ روز ثبت شد (موقع افزودن به سبد اپ روی کالا می‌نشینه)؛
 * در هر حالت product برمی‌گرده تا صفحه‌ی محصول اپ باز بشه.
 */
struct AffiliateReferralResponse: ShkDTO {
    let status: String?
    let saved: Bool?
    let product: AffiliateReferralProductDto?

    enum CodingKeys: String, CodingKey { case status, saved, product }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        saved = c.lenientBool(.saved)
        product = try? c.decodeIfPresent(AffiliateReferralProductDto.self, forKey: .product)
    }
}

struct AffiliateReferralProductDto: ShkDTO {
    let id: Int64?
    let uuid: String?
    let slug: String?

    enum CodingKeys: String, CodingKey { case id, uuid, slug }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt64(.id)
        uuid = c.lenientString(.uuid)
        slug = c.lenientString(.slug)
    }
}
