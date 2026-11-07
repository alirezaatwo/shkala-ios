import Foundation

// معادل بخش جزئیات/ثبت data/remote/dto/TicketDto.kt اپ اندروید (فهرست تیکت‌ها در AccountDto.swift)

struct TicketPrioritiesResponse: ShkDTO {
    let status: String
    let priorities: [TicketPriorityDto]
    enum CodingKeys: String, CodingKey { case status, priorities }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        priorities = c.lossyList(TicketPriorityDto.self, .priorities) ?? []
    }
}

struct TicketPriorityDto: ShkDTO, Identifiable, Equatable {
    let id: String
    let label: String
    enum CodingKeys: String, CodingKey { case id, label }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id) ?? ""
        label = c.lenientString(.label) ?? ""
    }
}

struct TicketDetailResponse: ShkDTO {
    let status: String
    let message: String?
    let ticket: TicketDetailDto?
    enum CodingKeys: String, CodingKey { case status, message, ticket }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        ticket = try? c.decodeIfPresent(TicketDetailDto.self, forKey: .ticket)
    }
}

struct TicketDetailDto: ShkDTO {
    let id: Int
    let title: String
    let priority: String
    let status: String
    let jalaliCreatedAt: [JSONValue]?
    let jalaliUpdatedAt: [JSONValue]?
    let answers: [TicketAnswerDto]
    enum CodingKeys: String, CodingKey {
        case id, title, priority, status
        case jalaliCreatedAt = "jalali_created_at", jalaliUpdatedAt = "jalali_updated_at", answers = "ticket_answers"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        priority = c.lenientString(.priority) ?? ""
        status = c.lenientString(.status) ?? ""
        jalaliCreatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliCreatedAt)
        jalaliUpdatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliUpdatedAt)
        answers = c.lossyList(TicketAnswerDto.self, .answers) ?? []
    }
}

struct TicketAnswerDto: ShkDTO, Identifiable {
    let id: Int
    let userId: Int
    let type: String
    let content: String?
    let file: TicketFileDto?
    let jalaliCreatedAt: [JSONValue]?
    let user: TicketAnswerUserDto?
    enum CodingKeys: String, CodingKey {
        case id, userId = "user_id", type, content, file = "get_file", jalaliCreatedAt = "jalali_created_at", user
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        userId = c.lenientInt(.userId) ?? 0
        type = c.lenientString(.type) ?? ""
        content = c.lenientString(.content)
        file = try? c.decodeIfPresent(TicketFileDto.self, forKey: .file)
        jalaliCreatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliCreatedAt)
        user = try? c.decodeIfPresent(TicketAnswerUserDto.self, forKey: .user)
    }
}

struct TicketFileDto: ShkDTO {
    let link: String
    let alt: String?
    let name: String?
    let size: String?
    enum CodingKeys: String, CodingKey { case link, alt, name, size }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        link = c.lenientString(.link) ?? ""
        alt = c.lenientString(.alt)
        name = c.lenientString(.name)
        size = c.lenientString(.size)
    }
}

struct TicketAnswerUserDto: ShkDTO {
    let id: Int
    let name: String?
    let avatar: String?
    let type: String?
    enum CodingKeys: String, CodingKey { case id, name = "get_name", avatar = "get_avatar", type }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        name = c.lenientString(.name)
        avatar = c.lenientString(.avatar)
        type = c.lenientString(.type)
    }
}

struct TicketStoreResponse: ShkDTO {
    let status: String
    let message: String?
    let ticketId: Int?
    enum CodingKeys: String, CodingKey { case status, message, ticketId = "ticket_id" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        message = c.lenientString(.message)
        ticketId = c.lenientInt(.ticketId)
    }
}
