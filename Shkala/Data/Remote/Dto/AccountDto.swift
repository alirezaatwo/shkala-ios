import Foundation

// معادل AccountFeaturesDto.kt + NotificationDto.kt + TransactionDto.kt + بخش‌های فهرستیِ
// PrefactorDto.kt و TicketDto.kt و AccountSummaryResponse (OrderDto.kt) اپ اندروید - همان کلیدهای JSON.

/** پاسخ ساده‌ی { status, message } (SimpleStatusResponse اندروید) */
struct SimpleStatusResponse: ShkDTO {
    let status: String?
    let message: String?
    enum CodingKeys: String, CodingKey { case status, message }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        message = c.lenientString(.message)
    }
}

// ---- آمار حساب ----

struct AccountSummaryResponse: ShkDTO {
    let status: String
    let totalOrders: Int
    let totalSpent: Int64
    let walletAmount: Int64
    let pendingOrders: Int
    let ticketsCount: Int
    let questionsCount: Int
    let commentsCount: Int
    let clubScore: Int
    let level: String
    let unreadNotificationsCount: Int
    // آستانه‌های امتیاز سطح نقره‌ای/طلایی (تنظیمات پنل ادمین) - برای مودال «سطح کاربری»
    let silverLevel: Int64?
    let goldLevel: Int64?

    enum CodingKeys: String, CodingKey {
        case status, level
        case totalOrders = "total_orders", totalSpent = "total_spent", walletAmount = "wallet_amount"
        case pendingOrders = "pending_orders", ticketsCount = "tickets_count", questionsCount = "questions_count"
        case commentsCount = "comments_count", clubScore = "club_score"
        case unreadNotificationsCount = "unread_notifications_count"
        case silverLevel = "silver_level", goldLevel = "gold_level"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status) ?? ""
        totalOrders = c.lenientInt(.totalOrders) ?? 0
        totalSpent = c.lenientInt64(.totalSpent) ?? 0
        walletAmount = c.lenientInt64(.walletAmount) ?? 0
        pendingOrders = c.lenientInt(.pendingOrders) ?? 0
        ticketsCount = c.lenientInt(.ticketsCount) ?? 0
        questionsCount = c.lenientInt(.questionsCount) ?? 0
        commentsCount = c.lenientInt(.commentsCount) ?? 0
        clubScore = c.lenientInt(.clubScore) ?? 0
        level = c.lenientString(.level) ?? ""
        unreadNotificationsCount = c.lenientInt(.unreadNotificationsCount) ?? 0
        silverLevel = c.lenientInt64(.silverLevel)
        goldLevel = c.lenientInt64(.goldLevel)
    }
}

// ---- علاقه‌مندی‌ها ----

struct FavoritesResponse: ShkDTO {
    let status: String?
    let favorites: [FavoriteDto]
    let pagination: SimplePaginationDto?
    enum CodingKeys: String, CodingKey { case status, favorites, pagination }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        favorites = c.lossyList(FavoriteDto.self, .favorites) ?? []
        pagination = try? c.decodeIfPresent(SimplePaginationDto.self, forKey: .pagination)
    }
}

struct FavoriteDto: ShkDTO, Identifiable {
    let id: Int
    let product: ProductListItemDto
    enum CodingKeys: String, CodingKey { case id, product }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        product = try c.decode(ProductListItemDto.self, forKey: .product)
    }
}

// ---- دیدگاه‌ها ----

struct CommentsResponse: ShkDTO {
    let status: String?
    let comments: [UserCommentDto]
    let pagination: SimplePaginationDto?
    enum CodingKeys: String, CodingKey { case status, comments, pagination }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        comments = c.lossyList(UserCommentDto.self, .comments) ?? []
        pagination = try? c.decodeIfPresent(SimplePaginationDto.self, forKey: .pagination)
    }
}

struct UserCommentDto: ShkDTO, Identifiable {
    let id: Int
    let content: String?
    let strengths: [String]?
    let weakness: [String]?
    let isBuyer: Bool
    let buySuggest: Bool?
    let jalaliCreatedAt: [JSONValue]?
    let voteUp: Int
    let voteDown: Int
    let productStatus: String?
    let answer: String?
    let product: UserCommentProductDto?

    enum CodingKeys: String, CodingKey {
        case id, content, product
        case answer = "get_answer"
        case strengths = "get_strengths", weakness = "get_weakness", isBuyer = "is_buyer", buySuggest = "buy_suggest"
        case jalaliCreatedAt = "jalali_created_at", voteUp = "vote_up", voteDown = "vote_down"
        case productStatus = "get_product_status"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        content = c.lenientString(.content)
        strengths = c.lossyList(String.self, .strengths)
        weakness = c.lossyList(String.self, .weakness)
        isBuyer = c.lenientBool(.isBuyer) ?? false
        buySuggest = c.lenientBool(.buySuggest)
        jalaliCreatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliCreatedAt)
        voteUp = c.lenientInt(.voteUp) ?? 0
        voteDown = c.lenientInt(.voteDown) ?? 0
        productStatus = c.lenientString(.productStatus)
        answer = c.lenientString(.answer)
        product = try? c.decodeIfPresent(UserCommentProductDto.self, forKey: .product)
    }
}

struct UserCommentProductDto: ShkDTO {
    let id: Int
    let title: String
    let slug: String
    enum CodingKeys: String, CodingKey { case id, title, slug }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        slug = c.lenientString(.slug) ?? ""
    }
}

// ---- پروفایل ----

struct ProfileEditResponse: ShkDTO {
    let status: String?
    let genderList: [GenderDto]
    let user: ProfileUserDto
    enum CodingKeys: String, CodingKey { case status, genderList = "gender_list", user }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        genderList = c.lossyList(GenderDto.self, .genderList) ?? []
        user = try c.decode(ProfileUserDto.self, forKey: .user)
    }
}

struct GenderDto: ShkDTO, Equatable {
    let id: String
    let label: String
    enum CodingKeys: String, CodingKey { case id, label }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id) ?? ""
        label = c.lenientString(.label) ?? ""
    }
}

struct ProfileUserDto: ShkDTO {
    let id: Int
    let name: String?
    let username: String?
    let email: String?
    let phone: String
    let nationalNumber: String?
    let bio: String?
    let gender: String?
    let avatarUrl: String?
    let social: SocialDto?
    let jalaliBirthday: String?

    enum CodingKeys: String, CodingKey {
        case id, name, username, email, phone, bio, gender
        case nationalNumber = "national_number", avatarUrl = "get_avatar", social = "get_social", jalaliBirthday = "jalali_birthday"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        name = c.lenientString(.name)
        username = c.lenientString(.username)
        email = c.lenientString(.email)
        phone = c.lenientString(.phone) ?? ""
        nationalNumber = c.lenientString(.nationalNumber)
        bio = c.lenientString(.bio)
        gender = c.lenientString(.gender)
        avatarUrl = c.lenientString(.avatarUrl)
        social = try? c.decodeIfPresent(SocialDto.self, forKey: .social)
        jalaliBirthday = c.lenientString(.jalaliBirthday)
    }
}

struct SocialDto: ShkDTO {
    let instagram: String?
    let telegram: String?
    let twitter: String?
    let facebook: String?
    enum CodingKeys: String, CodingKey { case instagram, telegram, twitter, facebook }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        instagram = c.lenientString(.instagram)
        telegram = c.lenientString(.telegram)
        twitter = c.lenientString(.twitter)
        facebook = c.lenientString(.facebook)
    }
}

// ---- نشست‌های فعال ----

struct SessionsResponse: ShkDTO {
    let status: String?
    let sessions: [SessionDto]
    let currentSessionId: Int?
    enum CodingKeys: String, CodingKey { case status, sessions, currentSessionId = "current_session_id" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        sessions = c.lossyList(SessionDto.self, .sessions) ?? []
        currentSessionId = c.lenientInt(.currentSessionId)
    }
}

struct SessionDto: ShkDTO, Identifiable {
    let id: Int
    let name: String?
    let isCurrent: Bool
    let lastUsedAt: String?
    let createdAt: String?
    enum CodingKeys: String, CodingKey { case id, name, isCurrent = "is_current", lastUsedAt = "last_used_at", createdAt = "created_at" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        name = c.lenientString(.name)
        isCurrent = c.lenientBool(.isCurrent) ?? false
        lastUsedAt = c.lenientString(.lastUsedAt)
        createdAt = c.lenientString(.createdAt)
    }
}

struct TerminateSessionResponse: ShkDTO {
    let status: String?
    let message: String?
    let wasCurrent: Bool?
    enum CodingKeys: String, CodingKey { case status, message, wasCurrent = "was_current" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        message = c.lenientString(.message)
        wasCurrent = c.lenientBool(.wasCurrent)
    }
}

// ---- اعلان‌ها ----

struct NotificationsResponse: ShkDTO {
    let status: String?
    let notifications: [NotificationDto]
    let pagination: SimplePaginationDto?
    // بازطراحی - مرحله ۲: تعداد کل اعلان‌های خوانده‌نشده (برای بج آیکن اعلان هدر)
    let unreadCount: Int?
    enum CodingKeys: String, CodingKey { case status, notifications, pagination, unreadCount = "unread_count" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        notifications = c.lossyList(NotificationDto.self, .notifications) ?? []
        pagination = try? c.decodeIfPresent(SimplePaginationDto.self, forKey: .pagination)
        unreadCount = c.lenientInt(.unreadCount)
    }
}

struct NotificationDto: ShkDTO, Identifiable {
    let id: String
    let message: String?
    let date: String?
    var isRead: Bool
    enum CodingKeys: String, CodingKey { case id, message, date, isRead = "is_read" }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id) ?? ""
        message = c.lenientString(.message)
        date = c.lenientString(.date)
        isRead = c.lenientBool(.isRead) ?? false
    }
}

// ---- تراکنش‌ها ----

struct TransactionsResponse: ShkDTO {
    let status: String?
    let transactions: [TransactionDto]
    let pagination: SimplePaginationDto?
    enum CodingKeys: String, CodingKey { case status, transactions, pagination }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        transactions = c.lossyList(TransactionDto.self, .transactions) ?? []
        pagination = try? c.decodeIfPresent(SimplePaginationDto.self, forKey: .pagination)
    }
}

struct TransactionDto: ShkDTO, Identifiable {
    let id: Int
    let amount: Int64
    let transactionId: String
    let type: String
    let formattedAmount: String
    let description: String?
    let status: String
    let jalaliCreatedAt: [JSONValue]?
    enum CodingKeys: String, CodingKey {
        case id, amount, type, description, status
        case transactionId = "transaction_id", formattedAmount = "get_formatted_amount", jalaliCreatedAt = "jalali_created_at"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        amount = c.lenientInt64(.amount) ?? 0
        transactionId = c.lenientString(.transactionId) ?? ""
        type = c.lenientString(.type) ?? ""
        formattedAmount = c.lenientString(.formattedAmount) ?? ""
        description = c.lenientString(.description)
        status = c.lenientString(.status) ?? ""
        jalaliCreatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliCreatedAt)
    }
}

// ---- پیش‌فاکتورها (فهرست) ----

struct PrefactorsResponse: ShkDTO {
    let status: String?
    let prefactors: [PrefactorDto]
    let pagination: SimplePaginationDto?
    enum CodingKeys: String, CodingKey { case status, prefactors, pagination }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        prefactors = c.lossyList(PrefactorDto.self, .prefactors) ?? []
        pagination = try? c.decodeIfPresent(SimplePaginationDto.self, forKey: .pagination)
    }
}

struct PrefactorDto: ShkDTO, Identifiable {
    let id: Int
    let uuid: String
    let title: String?
    let isExpired: Bool
    let jalaliExpiredAt: [JSONValue]?
    let jalaliCreatedAt: [JSONValue]?
    let status: String
    enum CodingKeys: String, CodingKey {
        case id, uuid, title, status
        case isExpired = "is_expired", jalaliExpiredAt = "jalali_expired_at", jalaliCreatedAt = "jalali_created_at"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        uuid = c.lenientString(.uuid) ?? ""
        title = c.lenientString(.title)
        isExpired = c.lenientBool(.isExpired) ?? false
        jalaliExpiredAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliExpiredAt)
        jalaliCreatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliCreatedAt)
        status = c.lenientString(.status) ?? ""
    }
}

// ---- تیکت‌ها (فهرست) ----

struct TicketsResponse: ShkDTO {
    let status: String?
    let tickets: [TicketDto]
    let pagination: SimplePaginationDto?
    enum CodingKeys: String, CodingKey { case status, tickets, pagination }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = c.lenientString(.status)
        tickets = c.lossyList(TicketDto.self, .tickets) ?? []
        pagination = try? c.decodeIfPresent(SimplePaginationDto.self, forKey: .pagination)
    }
}

struct TicketDto: ShkDTO, Identifiable {
    let id: Int
    let title: String
    let priority: String
    let status: String
    let jalaliCreatedAt: [JSONValue]?
    let jalaliUpdatedAt: [JSONValue]?
    enum CodingKeys: String, CodingKey {
        case id, title, priority, status
        case jalaliCreatedAt = "jalali_created_at", jalaliUpdatedAt = "jalali_updated_at"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id) ?? 0
        title = c.lenientString(.title) ?? ""
        priority = c.lenientString(.priority) ?? ""
        status = c.lenientString(.status) ?? ""
        jalaliCreatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliCreatedAt)
        jalaliUpdatedAt = try? c.decodeIfPresent([JSONValue].self, forKey: .jalaliUpdatedAt)
    }
}
