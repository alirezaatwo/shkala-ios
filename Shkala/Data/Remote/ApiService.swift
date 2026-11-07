import Foundation

/// معادل ApiService اپ اندروید (data/remote/ApiService.kt) - همان مسیرها.
/// هر مرحله فقط اندپوینت‌هایی که لازم داره اضافه می‌کنه.
enum ApiService {
    private static var api: ApiClient { .shared }

    // ---- ورود ----

    static func sendCode(_ body: SendCodeRequest) async throws -> ApiResponse<SendCodeResponse> {
        try await api.call(.post, "api/v2/auth/send-code", body: body, as: SendCodeResponse.self)
    }

    static func verifyCode(_ body: VerifyCodeRequest) async throws -> ApiResponse<VerifyCodeResponse> {
        try await api.call(.post, "api/v2/auth/verify-code", body: body, as: VerifyCodeResponse.self)
    }

    static func loginWithPassword(_ body: PasswordLoginRequest) async throws -> ApiResponse<VerifyCodeResponse> {
        try await api.call(.post, "api/v2/auth/login-password", body: body, as: VerifyCodeResponse.self)
    }

    static func me() async throws -> ApiResponse<MeResponse> {
        try await api.call(.get, "api/v2/auth/me", as: MeResponse.self)
    }

    // ---- اطلاعات سایت ----

    static func getSiteInfo() async throws -> ApiResponse<SiteInfoResponse> {
        try await api.call(.get, "api/v2/site-info", as: SiteInfoResponse.self)
    }

    static func getTrustSeals() async throws -> ApiResponse<TrustSealsResponse> {
        try await api.call(.get, "api/v2/site-info/trust-seals", as: TrustSealsResponse.self)
    }

    static func getSocialLinks() async throws -> ApiResponse<SocialLinksResponse> {
        try await api.call(.get, "api/v2/site-info/social-links", as: SocialLinksResponse.self)
    }

    // ---- کاتالوگ ----

    static func getCategories() async throws -> ApiResponse<CategoriesResponse> {
        try await api.call(.get, "api/v2/categories", as: CategoriesResponse.self)
    }

    // فاز ۷/۱۳: برند و فهرست برندها، دسته‌بندی‌های مقاله
    static func getBrand(_ slug: String) async throws -> ApiResponse<BrandResponse> {
        try await api.call(.get, "api/v2/brands/\(enc(slug))", as: BrandResponse.self)
    }

    static func getBrandsList() async throws -> ApiResponse<BrandListResponse> {
        try await api.call(.get, "api/v2/brands", as: BrandListResponse.self)
    }

    static func getArticleCategories() async throws -> ApiResponse<ArticleCategoriesResponse> {
        try await api.call(.get, "api/v2/article-categories", as: ArticleCategoriesResponse.self)
    }

    static func getArticles(category: String? = nil, page: Int = 1) async throws -> ApiResponse<ArticlesResponse> {
        try await api.call(.get, "api/v2/articles", query: ["category": category, "page": String(page)], as: ArticlesResponse.self)
    }

    static func getArticleDetail(_ slug: String) async throws -> ApiResponse<ArticleDetailResponse> {
        try await api.call(.get, "api/v2/articles/\(enc(slug))", as: ArticleDetailResponse.self)
    }

    // فاز ۱۶: دیدگاه‌های مقاله - فهرست عمومی (بدون نیاز به لاگین) و ثبت دیدگاه (نیازمند لاگین)
    static func getArticleComments(_ slug: String) async throws -> ApiResponse<ArticleCommentsResponse> {
        try await api.call(.get, "api/v2/articles/\(enc(slug))/comments", as: ArticleCommentsResponse.self)
    }

    static func addArticleComment(_ slug: String, content: String, replyTo: Int? = nil) async throws -> ApiResponse<ArticleAddCommentResponse> {
        try await api.call(.post, "api/v2/articles/\(enc(slug))/comments", form: ["content": content, "reply_to": replyTo.map { String($0) }], as: ArticleAddCommentResponse.self)
    }

    /// فاز ۱۰: مرتب‌سازی/فیلتر - دقیقاً همون پارامترهایی که ProductsArchiveService.php سایت می‌فهمه؛
    /// فیلترهای اختصاصی با فرمت filters[عنوان]=مقدار
    static func getProducts(
        page: Int = 1,
        category: String? = nil,
        search: String? = nil,
        cheapest: Int? = nil,
        brand: String? = nil,
        latest: Int? = nil,
        mostViewed: Int? = nil,
        popular: Int? = nil,
        mostSale: Int? = nil,
        expensive: Int? = nil,
        available: Int? = nil,
        discount: Int? = nil,
        random: Int? = nil,
        dynamicFilters: [String: String] = [:]
    ) async throws -> ApiResponse<ProductsResponse> {
        var query: [String: String?] = [
            "page": String(page), "cat": category, "search": search, "cheapest": cheapest.map(String.init),
            "brand": brand, "latest": latest.map(String.init), "most_viewed": mostViewed.map(String.init),
            "popular": popular.map(String.init), "most_sale": mostSale.map(String.init),
            "expensive": expensive.map(String.init), "available": available.map(String.init),
            "discount": discount.map(String.init), "random": random.map(String.init),
        ]
        for (k, v) in dynamicFilters { query[k] = v }
        return try await api.call(.get, "api/v2/products", query: query, as: ProductsResponse.self)
    }

    // ---- ماژول‌های صفحه‌ی اصلی ----

    static func getHomeSlider(mobile: Int = 1) async throws -> ApiResponse<HomeSliderResponse> {
        try await api.call(.get, "api/v2/home-slider", query: ["mobile": String(mobile)], as: HomeSliderResponse.self)
    }

    static func getHomeBanners() async throws -> ApiResponse<HomeBannersResponse> {
        try await api.call(.get, "api/v2/home-banners", as: HomeBannersResponse.self)
    }

    static func getHomeBanners2() async throws -> ApiResponse<HomeBannersResponse> {
        try await api.call(.get, "api/v2/home-banners-2", as: HomeBannersResponse.self)
    }

    static func getLowStockProducts(limit: Int = 15) async throws -> ApiResponse<HomeProductListResponse> {
        try await api.call(.get, "api/v2/home/low-stock-products", query: ["limit": String(limit)], as: HomeProductListResponse.self)
    }

    static func getProductsBySlugs(_ slugs: [String]) async throws -> ApiResponse<HomeProductListResponse> {
        try await api.call(.get, "api/v2/home/products-by-slugs", queryList: slugs.map { ("slugs[]", $0) }, as: HomeProductListResponse.self)
    }

    static func getInCartsNow() async throws -> ApiResponse<InCartsNowResponse> {
        try await api.call(.get, "api/v2/home/in-carts-now", as: InCartsNowResponse.self)
    }

    static func getHomeUi() async throws -> ApiResponse<HomeUiResponse> {
        try await api.call(.get, "api/v2/home/ui", as: HomeUiResponse.self)
    }

    static func getHomeAmazingOffer() async throws -> ApiResponse<AmazingOfferResponse> {
        try await api.call(.get, "api/v2/home/amazing-offer", as: AmazingOfferResponse.self)
    }

    static func getStories() async throws -> ApiResponse<StoriesResponse> {
        try await api.call(.get, "api/v2/stories", as: StoriesResponse.self)
    }

    static func likeStory(_ id: Int) async throws -> ApiResponse<StoryLikeResponse> {
        try await api.call(.post, "api/v2/stories/\(id)/like", as: StoryLikeResponse.self)
    }

    // ---- صفحه‌ی محصول ----

    private static func enc(_ v: String) -> String {
        v.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? v
    }

    static func getProductDetail(_ slug: String) async throws -> ApiResponse<ProductDetailResponse> {
        try await api.call(.get, "api/v2/products/\(enc(slug))", as: ProductDetailResponse.self)
    }

    static func getProductExtras(_ slug: String) async throws -> ApiResponse<ProductExtrasResponse> {
        try await api.call(.get, "api/v2/products/\(enc(slug))/extras", as: ProductExtrasResponse.self)
    }

    static func getProductInventories(_ slug: String) async throws -> ApiResponse<ProductInventoriesResponse> {
        try await api.call(.get, "api/v2/products/\(enc(slug))/inventories", as: ProductInventoriesResponse.self)
    }

    static func toggleFavorite(_ productId: Int) async throws -> ApiResponse<ToggleFavoriteResponse> {
        try await api.call(.post, "api/v2/products/\(productId)/favorite", as: ToggleFavoriteResponse.self)
    }

    /// مرتب‌سازی دیدگاه‌ها مثل سایت: فقط یکی از این‌ها با مقدار ۱ فرستاده می‌شه (nil = ارسال نمی‌شه)
    static func getProductComments(_ slug: String, page: Int, latest: Int? = nil, useful: Int? = nil, buyers: Int? = nil) async throws -> ApiResponse<ProductCommentsResponse> {
        try await api.call(.get, "api/v2/products/\(enc(slug))/comments", query: [
            "cpage": String(page), "clatest": latest.map(String.init), "useful": useful.map(String.init), "buyers": buyers.map(String.init),
        ], as: ProductCommentsResponse.self)
    }

    static func submitProductComment(_ slug: String, parts: [MultipartPart]) async throws -> ApiResponse<SubmitResponse> {
        try await api.callMultipart(.post, "api/v2/products/\(enc(slug))/comments", parts: parts, as: SubmitResponse.self)
    }

    static func voteProductComment(_ commentId: Int, type: String) async throws -> ApiResponse<CommentVoteResponse> {
        try await api.call(.post, "api/v2/comments/\(commentId)/vote", form: ["type": type], as: CommentVoteResponse.self)
    }

    static func getProductQuestions(_ slug: String, page: Int, latest: Int? = nil, noAnswer: Int? = nil, withAnswer: Int? = nil) async throws -> ApiResponse<ProductQuestionsResponse> {
        try await api.call(.get, "api/v2/products/\(enc(slug))/questions", query: [
            "qpage": String(page), "qlatest": latest.map(String.init), "noanswer": noAnswer.map(String.init), "answer": withAnswer.map(String.init),
        ], as: ProductQuestionsResponse.self)
    }

    static func submitProductQuestion(_ slug: String, question: String) async throws -> ApiResponse<SubmitResponse> {
        try await api.call(.post, "api/v2/products/\(enc(slug))/questions", form: ["question": question], as: SubmitResponse.self)
    }

    static func submitQuestionAnswer(_ questionId: Int, answer: String) async throws -> ApiResponse<SubmitResponse> {
        try await api.call(.post, "api/v2/questions/\(questionId)/answers", form: ["answer": answer], as: SubmitResponse.self)
    }

    static func toggleProductNotification(_ slug: String, type: String) async throws -> ApiResponse<NotifyToggleResponse> {
        try await api.call(.post, "api/v2/products/\(enc(slug))/notify", form: ["type": type], as: NotifyToggleResponse.self)
    }

    static func getCompares() async throws -> ApiResponse<CompareListResponse> {
        try await api.call(.get, "api/v2/compares", as: CompareListResponse.self)
    }

    static func addToCompare(_ slug: String, type: String? = nil) async throws -> ApiResponse<CompareActionResponse> {
        try await api.call(.post, "api/v2/compares/\(enc(slug))", form: ["type": type], as: CompareActionResponse.self)
    }

    static func removeFromCompare(_ compareId: Int) async throws -> ApiResponse<CompareActionResponse> {
        try await api.call(.delete, "api/v2/compares/\(compareId)", as: CompareActionResponse.self)
    }

    // فاز ۹: جست‌وجوی محصول برای افزودن به مقایسه (فقط هم‌دسته با محصولات فعلی مقایسه)
    static func searchCompareProducts(search: String? = nil, page: Int = 1) async throws -> ApiResponse<CompareSearchResponse> {
        try await api.call(.get, "api/v2/compares-search", query: ["search": search, "page": String(page)], as: CompareSearchResponse.self)
    }

    // ---- سبد خرید ----

    static func getCart() async throws -> ApiResponse<CartResponse> {
        try await api.call(.get, "api/v2/cart", as: CartResponse.self)
    }

    /// پیش‌فاکتور سبد خرید (آدرس امضاشده‌ی صفحه‌ی پیش‌فاکتور برای وب‌ویو)
    static func getCartPrefactorLink() async throws -> ApiResponse<CartPrefactorLinkResponse> {
        try await api.call(.get, "api/v2/cart/prefactor", as: CartPrefactorLinkResponse.self)
    }

    static func addToCart(inventoryId: Int, count: Int) async throws -> ApiResponse<AddToCartResponse> {
        try await api.call(.post, "api/v2/cart/add", form: ["inventory_id": String(inventoryId), "count": String(count)], as: AddToCartResponse.self)
    }

    static func increaseCartItem(consignmentItemId: Int, inventoryId: Int) async throws -> ApiResponse<CartItemResponse> {
        try await api.call(.post, "api/v2/cart/increase", form: ["consignment_item_id": String(consignmentItemId), "inventory_id": String(inventoryId)], as: CartItemResponse.self)
    }

    static func decreaseCartItem(consignmentItemId: Int, inventoryId: Int) async throws -> ApiResponse<CartItemResponse> {
        try await api.call(.post, "api/v2/cart/decrease", form: ["consignment_item_id": String(consignmentItemId), "inventory_id": String(inventoryId)], as: CartItemResponse.self)
    }

    static func removeCartItem(consignmentItemId: Int) async throws -> ApiResponse<CartItemResponse> {
        try await api.call(.post, "api/v2/cart/remove", form: ["consignment_item_id": String(consignmentItemId)], as: CartItemResponse.self)
    }

    // ---- آدرس‌ها ----

    static func getAddresses() async throws -> ApiResponse<AddressesResponse> {
        try await api.call(.get, "api/v2/addresses", as: AddressesResponse.self)
    }

    private static func addressForm(
        _ firstName: String, _ lastName: String, _ state: String, _ city: String, _ phone: String,
        _ postalCode: String, _ fullAddress: String, _ mapLat: Double?, _ mapLng: Double?
    ) -> [String: String?] {
        [
            "first_name": firstName, "last_name": lastName, "state": state, "city": city, "phone": phone,
            "postal_code": postalCode, "full_address": fullAddress,
            "map[lat]": mapLat.map { String($0) }, "map[lng]": mapLng.map { String($0) },
        ]
    }

    static func createAddress(
        firstName: String, lastName: String, state: String, city: String, phone: String,
        postalCode: String, fullAddress: String, mapLat: Double? = nil, mapLng: Double? = nil
    ) async throws -> ApiResponse<AddressResponse> {
        try await api.call(.post, "api/v2/addresses",
                           form: addressForm(firstName, lastName, state, city, phone, postalCode, fullAddress, mapLat, mapLng),
                           as: AddressResponse.self)
    }

    static func updateAddress(
        id: Int, firstName: String, lastName: String, state: String, city: String, phone: String,
        postalCode: String, fullAddress: String, mapLat: Double? = nil, mapLng: Double? = nil
    ) async throws -> ApiResponse<AddressResponse> {
        try await api.call(.put, "api/v2/addresses/\(id)",
                           form: addressForm(firstName, lastName, state, city, phone, postalCode, fullAddress, mapLat, mapLng),
                           as: AddressResponse.self)
    }

    static func selectAddress(id: Int) async throws -> ApiResponse<AddressResponse> {
        try await api.call(.post, "api/v2/addresses/\(id)/select", as: AddressResponse.self)
    }

    static func deleteAddress(id: Int) async throws -> ApiResponse<Bool> {
        try await api.callIgnoringBody(.delete, "api/v2/addresses/\(id)")
    }

    // ---- روش ارسال ----

    static func getShipping() async throws -> ApiResponse<ShippingResponse> {
        try await api.call(.get, "api/v2/shipping", as: ShippingResponse.self)
    }

    static func selectShippingMethod(type: String, consignmentUuid: String, sendMethodUuid: String) async throws -> ApiResponse<Bool> {
        try await api.callIgnoringBody(.post, "api/v2/shipping/select-method", form: [
            "type": type, "consignment_uuid": consignmentUuid, "send_method_uuid": sendMethodUuid,
        ])
    }

    static func selectShopAddress(receptionCenterId: String) async throws -> ApiResponse<Bool> {
        try await api.callIgnoringBody(.post, "api/v2/shipping/select-shop-address", form: ["reception_center_id": receptionCenterId])
    }

    // فاز ۱۴: کد تخفیف تسویه‌حساب
    static func applyDiscount(code: String) async throws -> ApiResponse<DiscountResponse> {
        try await api.call(.post, "api/v2/shipping/discount", form: ["code": code], as: DiscountResponse.self)
    }

    static func removeDiscount() async throws -> ApiResponse<DiscountResponse> {
        try await api.call(.delete, "api/v2/shipping/discount", as: DiscountResponse.self)
    }

    // ---- پرداخت ----

    static func getPaymentGateways() async throws -> ApiResponse<PaymentGatewaysResponse> {
        try await api.call(.get, "api/v2/payment-gateways", as: PaymentGatewaysResponse.self)
    }

    static func pay(paymentGateway: String, description: String? = nil, useWallet: Int? = nil) async throws -> ApiResponse<PayResponse> {
        try await api.call(.post, "api/v2/checkout/pay", form: [
            "payment_gateway": paymentGateway, "description": description, "use_wallet": useWallet.map(String.init),
        ], as: PayResponse.self)
    }

    // فاز ۱۵: پرداخت ترکیبی کیف پول + کارت‌به‌کارت - اگه کل مبلغ با کیف پول پوشش داده بشه نیازی به رسید نیست
    static func payCardToCard(receipt: MultipartPart?, useWallet: Bool) async throws -> ApiResponse<CardToCardResponse> {
        var parts: [MultipartPart] = []
        if let receipt { parts.append(receipt) }
        if useWallet { parts.append(.text("use_wallet", "1")) }
        return try await api.callMultipart(.post, "api/v2/checkout/pay/card-to-card", parts: parts, as: CardToCardResponse.self)
    }

    // ثبت سفارش و پرداخت با هماهنگی کارشناس فروشگاه (مکانیزم کارت‌به‌کارت با رسید خودکار)
    static func payCoordinated(description: String? = nil) async throws -> ApiResponse<CardToCardResponse> {
        try await api.call(.post, "api/v2/checkout/pay/coordinated", form: ["description": description], as: CardToCardResponse.self)
    }

    static func getOrderStatus(uuid: String) async throws -> ApiResponse<OrderStatusResponse> {
        try await api.call(.get, "api/v2/orders/\(enc(uuid))", as: OrderStatusResponse.self)
    }

    // ---- سفارش‌های من ----

    /// جستجو بر اساس شماره‌ی سفارش (روی rejected_orders هم اعمال می‌شه)
    // ---- مرحله‌ی ۵: حساب کاربری ----

    /// Boolean رتروفیت در کوئری = «true»/«false»
    private static func qb(_ v: Bool?) -> String? { v.map { $0 ? "true" : "false" } }

    static func getAccountSummary() async throws -> ApiResponse<AccountSummaryResponse> {
        try await api.call(.get, "api/v2/my-orders-summary", as: AccountSummaryResponse.self)
    }

    static func getTransactions(page: Int = 1, search: String? = nil, accepted: Bool? = nil, rejected: Bool? = nil,
                                deposit: Bool? = nil, withdrawal: Bool? = nil) async throws -> ApiResponse<TransactionsResponse> {
        try await api.call(.get, "api/v2/transactions", query: [
            "page": String(page), "search": search, "accepted": qb(accepted), "rejected": qb(rejected),
            "deposit": qb(deposit), "withdrawal": qb(withdrawal),
        ], as: TransactionsResponse.self)
    }

    static func getNotifications(page: Int = 1) async throws -> ApiResponse<NotificationsResponse> {
        try await api.call(.get, "api/v2/notifications", query: ["page": String(page)], as: NotificationsResponse.self)
    }

    static func markNotificationAsRead(_ id: String) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.call(.post, "api/v2/notifications/\(enc(id))/mark-read", as: SimpleStatusResponse.self)
    }

    static func getPrefactors(page: Int = 1, search: String? = nil, paid: Bool? = nil, waitingPayment: Bool? = nil) async throws -> ApiResponse<PrefactorsResponse> {
        try await api.call(.get, "api/v2/prefactors", query: [
            "page": String(page), "search": search, "paid": qb(paid), "waiting_payment": qb(waitingPayment),
        ], as: PrefactorsResponse.self)
    }

    static func getPrefactorDetail(_ uuid: String) async throws -> ApiResponse<PrefactorDetailResponse> {
        try await api.call(.get, "api/v2/prefactors/\(enc(uuid))", as: PrefactorDetailResponse.self)
    }

    static func selectPrefactorAddress(_ uuid: String, addressId: Int) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.call(.post, "api/v2/prefactors/\(enc(uuid))/address", form: ["address_id": String(addressId)], as: SimpleStatusResponse.self)
    }

    // فاز ۳۱: انتخاب تحویل حضوری از شعبه برای پیش‌فاکتور - دقیقاً مثل
    // selectShopAddress تسویه‌حساب عادی، فقط مسیرش مخصوص همین پیش‌فاکتوره
    static func selectPrefactorShopAddress(_ uuid: String, receptionCenterId: String) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.call(.post, "api/v2/prefactors/\(enc(uuid))/shop-address", form: ["reception_center_id": receptionCenterId], as: SimpleStatusResponse.self)
    }

    static func selectPrefactorShippingMethod(_ uuid: String, type: String, consignmentUuid: String, sendMethodUuid: String) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.call(.post, "api/v2/prefactors/\(enc(uuid))/shipping-method", form: [
            "type": type, "consignment_uuid": consignmentUuid, "send_method_uuid": sendMethodUuid,
        ], as: SimpleStatusResponse.self)
    }

    static func getPrefactorGateways(_ uuid: String) async throws -> ApiResponse<PrefactorGatewaysResponse> {
        try await api.call(.get, "api/v2/prefactors/\(enc(uuid))/gateways", as: PrefactorGatewaysResponse.self)
    }

    static func payPrefactor(_ uuid: String, paymentGateway: String, description: String? = nil) async throws -> ApiResponse<PrefactorPayResponse> {
        try await api.call(.post, "api/v2/prefactors/\(enc(uuid))/pay", form: ["payment_gateway": paymentGateway, "description": description], as: PrefactorPayResponse.self)
    }

    static func payPrefactorCardToCard(_ uuid: String, parts: [MultipartPart]) async throws -> ApiResponse<PrefactorPayResponse> {
        try await api.callMultipart(.post, "api/v2/prefactors/\(enc(uuid))/pay-card-to-card", parts: parts, as: PrefactorPayResponse.self)
    }

    // ابزارهای کاربردی: فهرست ابزارها و ماشین‌حساب هارد دوربین
    static func getTools() async throws -> ApiResponse<ToolsResponse> {
        try await api.call(.get, "api/v2/tools", as: ToolsResponse.self)
    }

    static func getHddCalculator() async throws -> ApiResponse<HddToolResponse> {
        try await api.call(.get, "api/v2/tools/hdd-calculator", as: HddToolResponse.self)
    }

    static func getHddProducts(tb: Double) async throws -> ApiResponse<HddProductsResponse> {
        try await api.call(.get, "api/v2/tools/hdd-calculator/products", query: ["tb": String(tb)], as: HddProductsResponse.self)
    }

    // فاز ۳۱: پرسش‌های متداول
    static func getFaqs() async throws -> ApiResponse<FaqsResponse> {
        try await api.call(.get, "api/v2/faqs", as: FaqsResponse.self)
    }

    // فاز ۳۲: صفحات ثابت اسکریپت (مثل «قوانین و شرایط») - نمایش نیتیو محتوای HTML
    static func getPage(_ slug: String) async throws -> ApiResponse<PageResponse> {
        try await api.call(.get, "api/v2/pages/\(enc(slug))", as: PageResponse.self)
    }

    // فاز ۳۲: فرم‌های داینامیک اسکریپت (مثل «تماس با ما») - نمایش نیتیو + ثبت پاسخ
    static func getForm(_ slug: String) async throws -> ApiResponse<FormResponse> {
        try await api.call(.get, "api/v2/forms/\(enc(slug))", as: FormResponse.self)
    }

    static func submitFormAnswer(_ slug: String, body: FormAnswerSubmitRequest) async throws -> ApiResponse<FormAnswerSubmitResponse> {
        try await api.call(.post, "api/v2/forms/\(enc(slug))/answer", body: body, as: FormAnswerSubmitResponse.self)
    }

    static func getTickets(page: Int = 1, search: String? = nil, waitingAdmin: Bool? = nil, waitingUser: Bool? = nil, closed: Bool? = nil) async throws -> ApiResponse<TicketsResponse> {
        try await api.call(.get, "api/v2/tickets", query: [
            "page": String(page), "search": search, "waiting_admin": qb(waitingAdmin), "waiting_user": qb(waitingUser), "closed": qb(closed),
        ], as: TicketsResponse.self)
    }

    static func getTicketPriorities() async throws -> ApiResponse<TicketPrioritiesResponse> {
        try await api.call(.get, "api/v2/tickets/priorities", as: TicketPrioritiesResponse.self)
    }

    static func createTicket(parts: [MultipartPart]) async throws -> ApiResponse<TicketStoreResponse> {
        try await api.callMultipart(.post, "api/v2/tickets", parts: parts, as: TicketStoreResponse.self)
    }

    static func getTicketDetail(_ id: Int) async throws -> ApiResponse<TicketDetailResponse> {
        try await api.call(.get, "api/v2/tickets/\(id)", as: TicketDetailResponse.self)
    }

    static func answerTicket(_ id: Int, content: String) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.call(.post, "api/v2/tickets/\(id)/answer", form: ["content": content], as: SimpleStatusResponse.self)
    }

    static func sendTicketAttachment(_ id: Int, parts: [MultipartPart]) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.callMultipart(.post, "api/v2/tickets/\(id)/attachment", parts: parts, as: SimpleStatusResponse.self)
    }

    static func getFavorites(page: Int = 1, search: String? = nil) async throws -> ApiResponse<FavoritesResponse> {
        try await api.call(.get, "api/v2/favorites", query: ["page": String(page), "search": search], as: FavoritesResponse.self)
    }

    static func getMyComments(page: Int = 1, search: String? = nil) async throws -> ApiResponse<CommentsResponse> {
        try await api.call(.get, "api/v2/comments", query: ["page": String(page), "search": search], as: CommentsResponse.self)
    }

    static func getProfile() async throws -> ApiResponse<ProfileEditResponse> {
        try await api.call(.get, "api/v2/profile", as: ProfileEditResponse.self)
    }

    static func updateProfile(parts: [MultipartPart]) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.callMultipart(.post, "api/v2/profile", parts: parts, as: SimpleStatusResponse.self)
    }

    static func changePassword(current: String?, new: String, newConfirmation: String) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.call(.post, "api/v2/profile/change-password", form: ["current": current, "new": new, "new_confirmation": newConfirmation], as: SimpleStatusResponse.self)
    }

    // ---- کیف پول ----

    static func getWalletInfo() async throws -> ApiResponse<WalletInfoResponse> {
        try await api.call(.get, "api/v2/wallet", as: WalletInfoResponse.self)
    }

    static func chargeWallet(amount: Int64, paymentGateway: String) async throws -> ApiResponse<WalletChargeResponse> {
        try await api.call(.post, "api/v2/wallet/charge", form: ["amount": String(amount), "payment_gateway": paymentGateway], as: WalletChargeResponse.self)
    }

    static func addWithdrawal(amount: Int64, bankCardId: Int) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.call(.post, "api/v2/wallet/withdrawals", form: ["amount": String(amount), "bank_card": String(bankCardId)], as: SimpleStatusResponse.self)
    }

    static func deleteWithdrawal(_ id: Int) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.call(.delete, "api/v2/wallet/withdrawals/\(id)", as: SimpleStatusResponse.self)
    }

    static func addBankCard(name: String, cardNumber: String, shebaNumber: String) async throws -> ApiResponse<AddBankCardResponse> {
        try await api.call(.post, "api/v2/wallet/bank-cards", form: ["name": name, "card_number": cardNumber, "sheba_number": shebaNumber], as: AddBankCardResponse.self)
    }

    static func deleteBankCard(_ id: Int) async throws -> ApiResponse<SimpleStatusResponse> {
        try await api.call(.delete, "api/v2/wallet/bank-cards/\(id)", as: SimpleStatusResponse.self)
    }

    // ویرایش کارت بانکی (مسیر جدید API؛ سایت فقط افزودن/حذف داره)
    static func updateBankCard(id: Int, name: String, cardNumber: String, shebaNumber: String) async throws -> ApiResponse<AddBankCardResponse> {
        try await api.call(.post, "api/v2/wallet/bank-cards/\(id)/update", form: ["name": name, "card_number": cardNumber, "sheba_number": shebaNumber], as: AddBankCardResponse.self)
    }

    static func getLastChargeTransaction() async throws -> ApiResponse<LastChargeTransactionResponse> {
        try await api.call(.get, "api/v2/wallet/last-charge-transaction", as: LastChargeTransactionResponse.self)
    }

    static func getSessions() async throws -> ApiResponse<SessionsResponse> {
        try await api.call(.get, "api/v2/sessions", as: SessionsResponse.self)
    }

    static func terminateSession(_ id: Int) async throws -> ApiResponse<TerminateSessionResponse> {
        try await api.call(.delete, "api/v2/sessions/\(id)", as: TerminateSessionResponse.self)
    }

    static func getMyOrders(page: Int = 1, search: String? = nil) async throws -> ApiResponse<OrdersListResponse> {
        try await api.call(.get, "api/v2/my-orders", query: ["page": String(page), "search": search], as: OrdersListResponse.self)
    }

    static func getMyOrderDetail(id: Int) async throws -> ApiResponse<OrderDetailResponse> {
        try await api.call(.get, "api/v2/my-orders/\(id)", as: OrderDetailResponse.self)
    }

    static func getMyOrderReceipt(id: Int) async throws -> ApiResponse<Data> {
        try await api.callRaw(.get, "api/v2/my-orders/\(id)/receipt")
    }

    static func getInvoiceBridge(id: Int) async throws -> ApiResponse<InvoiceBridgeResponse> {
        try await api.call(.get, "api/v2/my-orders/\(id)/invoice-bridge", as: InvoiceBridgeResponse.self)
    }

    // ---- وضعیت اپ ----

    /// شناسه‌ی نصب و نسخه‌ی اپ برای آمار لایو «کاربران آنلاین» در پنل (null = هدر ارسال نمی‌شه)
    static func getAppStatus(installId: String?, appVersion: String?) async throws -> ApiResponse<AppStatusResponse> {
        try await api.call(
            .get, "api/v2/app/status",
            headers: ["X-Shk-Install": installId, "X-Shk-Version": appVersion],
            as: AppStatusResponse.self
        )
    }
}

/// معادل currentAppVersionName اپ اندروید: نسخه‌ی نمایشی اپ (CFBundleShortVersionString)
func currentAppVersionName() -> String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
}
