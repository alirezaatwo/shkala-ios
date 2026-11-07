import Foundation

// معادل data/remote/dto/WalletDto.kt اپ اندروید - همان کلیدهای JSON.

/// تبدیل inputs فرم بانک (مقادیر عدد/رشته/بولی) به دیکشنری رشته‌ای - مثل PayResponse
private func decodeStringMap<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> [String: String]? {
    guard let raw = try? c.decodeIfPresent([String: JSONValue].self, forKey: key) else { return nil }
    return raw.compactMapValues { v in
        switch v {
        case .string(let s): return s
        case .number(let n): return n == n.rounded() ? String(Int64(n)) : String(n)
        case .bool(let b): return b ? "1" : "0"
        default: return nil
        }
    }
}

struct WalletInfoResponse: ShkDTO {
    let status: String
    let walletAmount: Int64
    let suggestedAmounts: [Int64]
    let withdrawalLimit: Int64
    let paymentGateways: [PaymentGatewayDto]
    let bankCards: [BankCardDto]
    let withdrawals: [WithdrawalDto]
    let pagination: SimplePaginationDto?

    enum CodingKeys: String, CodingKey {
        case status, walletAmount = "wallet_amount", suggestedAmounts = "suggested_amounts",
             withdrawalLimit = "withdrawal_limit", paymentGateways = "payment_gateways",
             bankCards = "bank_cards", withdrawals, pagination
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        walletAmount = c.lenientInt64(.walletAmount) ?? 0
        if let raw = try? c.decodeIfPresent([JSONValue].self, forKey: .suggestedAmounts) {
            suggestedAmounts = raw.compactMap { v in
                switch v {
                case .number(let n): return Int64(n)
                case .string(let s): return Int64(s)
                default: return nil
                }
            }
        } else {
            suggestedAmounts = []
        }
        withdrawalLimit = c.lenientInt64(.withdrawalLimit) ?? 0
        paymentGateways = c.lossyList(PaymentGatewayDto.self, .paymentGateways) ?? []
        bankCards = c.lossyList(BankCardDto.self, .bankCards) ?? []
        withdrawals = c.lossyList(WithdrawalDto.self, .withdrawals) ?? []
        pagination = try? c.decodeIfPresent(SimplePaginationDto.self, forKey: .pagination)
    }
}

struct BankCardDto: ShkDTO, Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let cardNumber: String
    let shebaNumber: String
    enum CodingKeys: String, CodingKey { case id, name, cardNumber = "card_number", shebaNumber = "sheba_number" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        name = c.lenientString(.name) ?? ""
        cardNumber = c.lenientString(.cardNumber) ?? ""
        shebaNumber = c.lenientString(.shebaNumber) ?? ""
    }
}

struct WithdrawalDto: ShkDTO, Identifiable {
    let id: Int
    let formattedAmount: String
    let status: String
    let jalaliCreatedAt: [JSONValue]?
    enum CodingKeys: String, CodingKey { case id, formattedAmount = "get_formatted_amount", status, jalaliCreatedAt = "jalali_created_at" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        formattedAmount = c.lenientString(.formattedAmount) ?? ""
        status = c.lenientString(.status) ?? ""
        jalaliCreatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliCreatedAt)
    }
}

struct WalletChargeResponse: ShkDTO {
    let status: String
    let message: String?
    let action: String?
    let method: String?
    let inputs: [String: String]?
    let bridgeUrl: String?
    enum CodingKeys: String, CodingKey { case status, message, action, method, inputs, bridgeUrl = "bridge_url" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        action = c.lenientString(.action)
        method = c.lenientString(.method)
        inputs = decodeStringMap(c, .inputs)
        bridgeUrl = c.lenientString(.bridgeUrl)
    }
}

struct AddBankCardResponse: ShkDTO {
    let status: String
    let message: String?
    let card: BankCardDto?
    enum CodingKeys: String, CodingKey { case status, message, card }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        card = try? c.decodeIfPresent(BankCardDto.self, forKey: .card)
    }
}

struct LastChargeTransactionResponse: ShkDTO {
    let status: String
    let referenceId: String?
    let statusValue: String?
    enum CodingKeys: String, CodingKey { case status, referenceId = "reference_id", statusValue = "status_value" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        referenceId = c.lenientString(.referenceId)
        statusValue = c.lenientString(.statusValue)
    }
}
