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
