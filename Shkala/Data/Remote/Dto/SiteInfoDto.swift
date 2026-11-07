import Foundation

// معادل SiteInfoResponse اپ اندروید (dto/OrderDto.kt)
struct SiteInfoResponse: ShkDTO {
    let status: String?
    let logoUrl: String?
    let logoDarkUrl: String?
    let siteName: String?

    enum CodingKeys: String, CodingKey {
        case status
        case logoUrl = "logo_url"
        case logoDarkUrl = "logo_dark_url"
        case siteName = "site_name"
    }
}
