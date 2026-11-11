import SwiftUI

// معادل ui/product/ProductDetailScreen.kt اپ اندروید

struct ProductDetailScreen: View {
    let slug: String
    let onBack: () -> Void
    let onOpenDescription: (String, String) -> Void
    let onOpenFullSpecs: ([SpecificationGroupDto]) -> Void
    var onOpenRelatedProduct: (String) -> Void = { _ in }
    var onOpenCompare: () -> Void = {}
    var onOpenBrand: (String) -> Void = { _ in }
    // فاز ۲۶: کلیک روی باکسِ دسته‌بندیِ محصول - به صفحه‌ی همون دسته‌بندی می‌ره
    var onOpenCategory: (String, String) -> Void = { _, _ in }

    @StateObject private var viewModel: ProductDetailViewModel
    @Environment(\.shkColors) private var colors

    init(slug: String, onBack: @escaping () -> Void, onOpenDescription: @escaping (String, String) -> Void,
         onOpenFullSpecs: @escaping ([SpecificationGroupDto]) -> Void, onOpenRelatedProduct: @escaping (String) -> Void = { _ in },
         onOpenCompare: @escaping () -> Void = {}, onOpenBrand: @escaping (String) -> Void = { _ in },
         onOpenCategory: @escaping (String, String) -> Void = { _, _ in }) {
        self.slug = slug
        self.onBack = onBack
        self.onOpenDescription = onOpenDescription
        self.onOpenFullSpecs = onOpenFullSpecs
        self.onOpenRelatedProduct = onOpenRelatedProduct
        self.onOpenCompare = onOpenCompare
        self.onOpenBrand = onOpenBrand
        self.onOpenCategory = onOpenCategory
        _viewModel = StateObject(wrappedValue: ProductDetailViewModel(slug: slug))
    }

    var body: some View {
        let state = viewModel.uiState
        ZStack {
            colors.background.ignoresSafeArea()
            if state.isLoading {
                // بازطراحی: لودینگ برند اپ
                SiteLoading(icon: RemixIcons.ShoppingBag3Line)
            } else if let error = state.errorMessage {
                SiteEmptyState(
                    icon: RemixIcons.ErrorWarningLine, title: error, subtitle: nil,
                    actionLabel: "تلاش دوباره", actionIcon: RemixIcons.RefreshLine, onAction: { viewModel.load() }
                )
                .padding(16)
            } else if let product = state.product {
                ProductDetailContent(
                    product: product, onBack: onBack, onOpenDescription: onOpenDescription, onOpenFullSpecs: onOpenFullSpecs,
                    onOpenRelatedProduct: onOpenRelatedProduct, onOpenCompare: onOpenCompare, onOpenBrand: onOpenBrand,
                    onOpenCategory: onOpenCategory, refreshKey: state.refreshCount,
                    onRefresh: { await viewModel.refresh() }
                )
            }
        }
    }
}

/// رنگ پیش‌فرض آیکن‌های روی کادر سفید گالری (کادر همیشه سفیده، پس رنگ ثابت)
private let GalleryIconTint = Color(argb: 0xFF3F4064)
private let GalleryButtonBackground = Color(argb: 0xFFF2F3F6)
/** فاز PA: رنگ آیکن/کادر هشدار محصول (نارنجی هشدار) و رنگ سکه‌ی امتیاز باشگاه مشتریان (طلایی) */
private let ProductWarningIconTint = Color(argb: 0xFFF59E0B)
private let ProductClubCoinColor = Color(argb: 0xFFF2A516)

/** فاز PX: قیمتِ نمایش‌داده‌شده در کادر قیمت و نوار چسبان (رشته‌های آماده با اعداد فارسی) */
private struct ProductDisplayPrice: Equatable, Hashable {
    let oldPrice: String?
    let finalPrice: String
    let discountPercent: Int?
}

/** فاز PA (۳-ک): یک لیبل ترغیب به خرید: پیشوند (با ایموجی) + عدد بولد (رنگی/پیش‌فرض) + پسوند */
private struct ProductStatText: Equatable {
    let prefix: String
    let value: String
    let suffix: String
    let valueColor: Color?
}

private struct ProductDetailContent: View {
    let product: ProductDetailDto
    let onBack: () -> Void
    let onOpenDescription: (String, String) -> Void
    let onOpenFullSpecs: ([SpecificationGroupDto]) -> Void
    let onOpenRelatedProduct: (String) -> Void
    let onOpenCompare: () -> Void
    let onOpenBrand: (String) -> Void
    let onOpenCategory: (String, String) -> Void
    let refreshKey: Int
    let onRefresh: () async -> Void

    @Environment(\.shkColors) private var colors

    private let catalogRepository = CatalogRepository()
    private let favoriteRepository = FavoriteRepository()
    private let productExtrasRepository = ProductExtrasRepository()
    private let productCompareRepository = ProductCompareRepository()
    private let reviewsRepository = ProductReviewsRepository()

    @State private var lightbox: LightboxRequest? = nil
    @State private var galleryPage = 0
    @State private var isFavorite: Bool
    @State private var isTogglingFavorite = false
    @State private var isAddingToCart = false
    @State private var quantity: Int
    @State private var showPriceChart = false
    @State private var inventories: [ProductInventoryDto]? = nil

    // ---- فاز ۴: فروشنده‌ها + محصولات مرتبط + قیمت پله‌ای ----
    @State private var productExtras: ProductExtrasResponse? = nil
    @State private var selectedSellerInventoryId: Int? = nil

    // ---- فاز ۶: اعلان قیمت/موجودی + مقایسه‌ی محصولات ----
    @State private var isTogglingNotification = false
    @State private var isAddingToCompare = false

    // ---- فاز ۵: دیدگاه‌ها + پرسش‌وپاسخ ----
    @State private var commentsInfo: CommentsInfoDto? = nil
    @State private var comments: [ProductCommentDto] = []
    @State private var commentsPage = 1
    @State private var commentsHasMore = false
    @State private var showWriteReview = false
    @State private var isSubmittingReview = false
    @State private var questionsInfo: QuestionsInfoDto? = nil
    @State private var questions: [ProductQuestionDto] = []
    @State private var questionsPage = 1
    @State private var questionsHasMore = false
    @State private var isSubmittingQuestion = false
    @State private var commentsSort = DefaultCommentSort
    @State private var ratingBreakdown: [RatingBreakdownDto]? = nil
    @State private var viewerIsBuyer = false
    @State private var commentsLoading = false
    @State private var questionsSort = DefaultQuestionSort
    @State private var questionsLoading = false

    @StateObject private var variantHolder = ProductVariantStateHolder()
    // آیتم‌هایی از بالای صفحه که الان روی صفحه دیده می‌شن (برای نمایش نوار چسبان)
    @State private var visibleTopKeys: Set<String> = ["gallery", "title", "price"]
    @State private var scrollTarget: String? = nil

    init(product: ProductDetailDto, onBack: @escaping () -> Void, onOpenDescription: @escaping (String, String) -> Void,
         onOpenFullSpecs: @escaping ([SpecificationGroupDto]) -> Void, onOpenRelatedProduct: @escaping (String) -> Void,
         onOpenCompare: @escaping () -> Void, onOpenBrand: @escaping (String) -> Void,
         onOpenCategory: @escaping (String, String) -> Void, refreshKey: Int, onRefresh: @escaping () async -> Void) {
        self.product = product
        self.onBack = onBack
        self.onOpenDescription = onOpenDescription
        self.onOpenFullSpecs = onOpenFullSpecs
        self.onOpenRelatedProduct = onOpenRelatedProduct
        self.onOpenCompare = onOpenCompare
        self.onOpenBrand = onOpenBrand
        self.onOpenCategory = onOpenCategory
        self.refreshKey = refreshKey
        self.onRefresh = onRefresh
        _isFavorite = State(initialValue: product.isFavorite)
        _quantity = State(initialValue: product.minQuantity)
    }

    // MARK: - مقادیر محاسبه‌شده

    private var gallery: [ProductImageDto] { product.galleryImages }
    private var selectedSeller: ProductSellerDto? { productExtras?.sellers.first { $0.inventoryId == selectedSellerInventoryId } }
    private var allSellers: [ProductSellerDto] { productExtras?.sellers ?? [] }
    private var storeCount: Int { Set(allSellers.map(sellerStoreKey)).count }

    // ---- فاز PA (۳-ج): گروه‌بندی فروشنده‌ها بر اساس فروشگاه ----
    private var visibleInventories: [ProductInventoryDto]? {
        guard let inventories else { return nil }
        guard storeCount > 1, let selected = selectedSeller else { return inventories }
        let key = sellerStoreKey(selected)
        let ids = Set(allSellers.filter { sellerStoreKey($0) == key }.map(\.inventoryId))
        return inventories.filter { ids.contains($0.id) }
    }

    // فاز ۲۹ (اصلاحیه): نوع اعلان بر اساس فیلد inventory (دقیقاً معادل $product->inventory سمت بک‌اند)
    private var notificationType: String { productExtras?.inventory == false ? "inventory" : "discount" }
    private var notificationLabel: String { notificationType == "inventory" ? "اعلان موجود شدن" : "اعلان تخفیف" }
    private var isNotificationEnabled: Bool {
        notificationType == "inventory" ? productExtras?.hasInventoryNotification == true : productExtras?.hasDiscountNotification == true
    }

    // فاز ۳۴ (کد ۱۱): متن اطلاعیه/هشدار محصول؛ «<p>&nbsp;</p>» و کاراکترهای نامرئی خالی حساب می‌شن
    private var plainWarnings: String? {
        guard let raw = product.warnings else { return nil }
        var text = htmlToPlainText(raw).replacingOccurrences(of: "\u{00A0}", with: " ")
        text = text.replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = text.replacingOccurrences(of: #"[\s​‌‍‎‏﻿]"#, with: "", options: .regularExpression)
        return visible.isEmpty ? nil : text
    }

    private var rawWarningsHasContent: Bool {
        guard let raw = product.warnings else { return false }
        let stripped = raw.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&[a-zA-Z#0-9]+;", with: " ", options: .regularExpression)
        return stripped.range(of: #"[\p{L}\p{N}]"#, options: .regularExpression) != nil
    }

    private var warningsText: String? {
        if let plainWarnings { return plainWarnings }
        guard rawWarningsHasContent, let raw = product.warnings else { return nil }
        return raw.replacingOccurrences(of: "<[^>]*>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private var showWarnings: Bool { !(plainWarnings?.isBlankShk ?? true) || rawWarningsHasContent }

    // ---- فاز PA (۳-ک): لیبل‌های چرخان ترغیب به خرید ----
    private var statTexts: [ProductStatText] {
        let statsEnabled = product.productStatisticsStatus == nil || product.productStatisticsStatus == "1"
        guard statsEnabled, product.inventory, let seller = selectedSeller else { return [] }
        var list: [ProductStatText] = []
        if seller.isBestPrice == true {
            list.append(ProductStatText(prefix: "🤩 بهترین قیمت در ", value: "۳۰", suffix: " روز گذشته", valueColor: SiteStatusColors.Success))
        }
        if let stockCount = seller.count, stockCount < 5 {
            list.append(ProductStatText(prefix: "📦 تنها ", value: stockCount.toPersianDigits(), suffix: " عدد در انبار باقی مانده", valueColor: colors.error))
        }
        let cartCount = product.cartCount ?? 0
        if cartCount > 0 {
            list.append(ProductStatText(prefix: "🛒 +", value: cartCount.toPersianDigits(), suffix: " عدد در سبد خرید کاربران", valueColor: nil))
        }
        // مثل سایت: تعداد بازدید و علاقه‌مندی به مضرب بالاترِ ۱۰۰ گرد می‌شه
        let views = roundUpToHundred(product.viewCount ?? 0)
        if views > 0 {
            list.append(ProductStatText(prefix: "👁️ +", value: views.toPersianDigits(), suffix: " نفر این کالا را مشاهده کرده‌اند", valueColor: nil))
        }
        let favorites = roundUpToHundred(product.favoritesCount ?? 0)
        if favorites > 0 {
            list.append(ProductStatText(prefix: "❤️ +", value: favorites.toPersianDigits(), suffix: " نفر به این کالا علاقه دارند", valueColor: nil))
        }
        return list
    }

    // فاز PA (۳-ط): امتیاز باشگاه مشتریان این خرید - امتیاز هر واحدِ موجودیِ انتخاب‌شده × تعداد
    private var clubScore: Int64 { (selectedSeller?.customerClubScore?.score ?? 0) * Int64(quantity) }
    // فاز PA (۳-م): درصد پیشنهاد خریداران
    private var suggestPercent: Double? { commentsInfo?.suggestionPercent ?? product.commentsInfo?.suggestionPercent }

    private var hasRealVariants: Bool { (visibleInventories?.count ?? 0) > 1 }
    private var showUpdatedBanner: Bool { !(product.jalaliUpdatedAt ?? []).isEmpty }
    private var showSellerSelector: Bool { storeCount > 1 }
    private var showTiered: Bool { !(selectedSeller?.discountTree ?? []).isEmpty }
    private var relatedProducts: [RelatedProductDto] { productExtras?.relatedProducts ?? [] }
    private var showDescription: Bool { !(product.content?.isBlankShk ?? true) }
    private var showSpecs: Bool { !(product.specifications ?? []).isEmpty }
    private var filledTabs: [ProductTabDto] { (product.tabs ?? []).filter { !($0.content?.isBlankShk ?? true) } }
    // فاز PA (۳-ل): «خصوصیات برجسته» (get_attrs خودِ اسکریپت)
    private var features: [ProductFeatureDto] {
        (product.outstandingFeatures ?? []).filter { !($0.key?.isBlankShk ?? true) || !($0.value?.isBlankShk ?? true) }
    }

    private var variantState: ProductVariantState { variantHolder.state }
    private var matchedVariant: ProductInventoryDto? { hasRealVariants ? variantState.matchedInventory : nil }
    // ویژگی‌های محصولِ تک‌موجودی (مثلاً فقط یک گارانتی) هم مثل محصولات چندگزینه‌ای نمایش داده می‌شن
    private var showVariantPickers: Bool {
        if hasRealVariants { return true }
        guard let only = visibleInventories, only.count == 1 else { return false }
        return only[0].props.contains { !($0.name?.isBlankShk ?? true) }
    }
    // محدوده‌ی مجاز تعداد: برای موجودیِ انتخاب‌شده‌ی چندنوعی، حداقل/حداکثر همون موجودی
    private var quantityMin: Int { matchedVariant?.minQuantity ?? product.minQuantity }
    private var quantityMax: Int { matchedVariant?.maxQuantity ?? product.maxQuantity }

    // قیمتِ کادر قیمت: موجودیِ انتخاب‌شده (چندنوعی) ← فروشنده‌ی انتخاب‌شده (چند فروشگاه) ← بهترین قیمت محصول
    private var displayPrice: ProductDisplayPrice? {
        if let v = matchedVariant {
            return ProductDisplayPrice(
                oldPrice: v.isDiscountValid ? formatTomanFa(v.price) : nil,
                finalPrice: formatTomanFa(v.finalPrice),
                discountPercent: discountPercentOf(v.price, v.finalPrice, v.isDiscountValid)
            )
        }
        if storeCount > 1, let seller = selectedSeller, seller.finalPrice != nil { return sellerDisplayPrice(seller) }
        if let best = product.bestNormalPrice { return bestNormalDisplayPrice(best) }
        return nil
    }

    // A14: قیمت نهاییِ واحد (عددی) - همون قیمتی که کادر قیمت نشون می‌ده - برای کارت‌های قسطی.
    // با عوض شدن گزینه‌ها/فروشنده یا تعداد، کارت‌ها همون لحظه دوباره حساب می‌شن.
    private var unitFinalPrice: Int64? {
        if let v = matchedVariant { return v.finalPrice }
        if storeCount > 1, let seller = selectedSeller, let price = seller.finalPrice { return price }
        if let best = product.bestNormalPrice {
            let raw = (best.discountPrice.flatMap { $0.isBlankShk ? nil : $0 } ?? best.price)
            return raw.flatMap { Int64($0.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "٬", with: "").trimmingCharacters(in: .whitespaces)) }
        }
        return product.bestPrice.map { Int64($0) }
    }
    private var installmentCards: [InstallmentCardItem] {
        product.inventory ? buildInstallmentCards(gateways: product.installmentGateways ?? ScreenshotMode.sampleInstallmentGateways, unitFinalPrice: unitFinalPrice, quantity: quantity) : []
    }

    // آیا دکمه‌ی خرید داخل کادر قیمت فعاله؟
    private var canBuy: Bool { product.inventory && (hasRealVariants ? true : product.bestInventory?.id != nil) }
    private var optionsItemKey: String { showSellerSelector ? "sellers" : "variants" }

    private var showStickyBar: Bool {
        visibleTopKeys.isDisjoint(with: ["gallery", "title", "price", "variants"])
    }

    // MARK: - بدنه

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        galleryItem.id("gallery").trackVisibility("gallery", $visibleTopKeys)
                        titleItem.id("title").trackVisibility("title", $visibleTopKeys)

                        // ================= گزینه‌های خرید: انتخاب فروشگاه =================
                        if showSellerSelector {
                            SellerSelectorSection(
                                sellers: allSellers,
                                selectedInventoryId: selectedSellerInventoryId,
                                onSellerSelected: { seller in selectedSellerInventoryId = seller.inventoryId },
                                mainShopLogoUrl: productExtras?.mainShop?.logo,
                                mainShopName: productExtras?.mainShop?.name
                            )
                            .id("sellers")
                        }

                        // ================= گزینه‌های خرید: انتخاب ویژگی‌ها =================
                        if showVariantPickers {
                            SiteCard {
                                ProductVariantPickers(state: variantState)
                            }
                            .padding(.horizontal, 16)
                            .id("variants")
                            .trackVisibility("variants", $visibleTopKeys)
                        }

                        priceItem.id("price").trackVisibility("price", $visibleTopKeys)

                        // فاز ۳۴ (کد ۱۲): بنر سبزِ تاریخ بروزرسانیِ موجودی/قیمت
                        if showUpdatedBanner {
                            HStack(spacing: 0) {
                                RemixIcon(RemixIcons.CalendarLine, tint: SiteStatusColors.Success, size: 16)
                                Spacer().frame(width: 8)
                                Text("موجودی و قیمت این محصول در مورخه \(product.jalaliUpdatedAt?.first ?? (product.jalaliUpdatedAt?.dropFirst().first ?? "")) بروزرسانی شده است.")
                                    .shkFont(11, .medium, lineHeight: 19)
                                    .foregroundColor(SiteStatusColors.Success)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(SiteStatusColors.Success.opacity(0.1)))
                            .padding(.horizontal, 16)
                        }

                        // ================= فروشنده =================
                        SellerInfoCard(seller: selectedSeller, mainShopLogoUrl: productExtras?.mainShop?.logo, mainShopName: productExtras?.mainShop?.name)
                            .padding(.horizontal, 16)

                        // فاز ۳۴ (اصلاحیه، کد ۸): کارت «خرید عمده (قیمت پله‌ای)» + مودال جدول
                        if showTiered { TieredPricingTable(tiers: selectedSeller?.discountTree) }

                        // ================= محصولات مرتبط =================
                        if !relatedProducts.isEmpty {
                            RelatedProductsCarousel(products: relatedProducts, onProductClick: onOpenRelatedProduct)
                                .padding(.top, 10)
                        }

                        // ================= خصوصیات برجسته =================
                        if !features.isEmpty {
                            ProductSection(title: "خصوصیات برجسته") { ProductFeaturesCard(features: features) }
                        }

                        if showDescription { descriptionItem }
                        if showSpecs { specsItem }

                        // ================= تب‌های محتوایی =================
                        ForEach(Array(filledTabs.enumerated()), id: \.offset) { _, tab in tabItem(tab) }

                        // ================= دیدگاه‌ها =================
                        ReviewsSection(
                            commentsInfo: commentsInfo,
                            comments: comments,
                            hasMore: commentsHasMore,
                            onLoadMore: { loadComments(commentsPage + 1) },
                            onVote: vote,
                            onWriteReviewClick: { showWriteReview = true },
                            ratingBreakdown: ratingBreakdown,
                            sortKey: commentsSort,
                            onSortChange: { commentsSort = $0; loadComments(1) },
                            isLoading: commentsLoading,
                            onImageClick: { urls, index in lightbox = LightboxRequest(urls: urls, index: index, buyerUrls: [], tabs: false) }
                        )
                        .padding(.top, 10)
                        .id("reviews")

                        // ================= پرسش و پاسخ =================
                        QnaSection(
                            questionsInfo: questionsInfo,
                            questions: questions,
                            hasMore: questionsHasMore,
                            isSubmittingQuestion: isSubmittingQuestion,
                            onLoadMore: { loadQuestions(questionsPage + 1) },
                            onSubmitQuestion: submitQuestion,
                            sortKey: questionsSort,
                            onSortChange: { questionsSort = $0; loadQuestions(1) },
                            isLoading: questionsLoading
                        )
                        .padding(.top, 10)
                        .id("qna")

                        // فضای خالی پایین تا نوار چسبان روی محتوا نیفته
                        Spacer().frame(height: 96)
                    }
                    .padding(.top, 12)
                    .animation(.easeInOut(duration: 0.25), value: showVariantPickers)
                    // فقط عکس‌برداری CI: اسکرول به موقعیت دلخواه (-shkScrollY)
                    .background(ScreenshotScrollOffset(y: ScreenshotMode.current?.scrollY ?? 0))
                }
                .refreshable {
                    // محدودیت سراسری: حداکثر ۲ بار در هر دقیقه (SitePullRefresh اندروید)
                    if PullRefreshRateLimiter.tryAcquire() {
                        await onRefresh()
                    } else {
                        ShkToast.shared.show(PULL_REFRESH_LIMIT_MESSAGE, long: true)
                    }
                }
                .onChange(of: scrollTarget) { target in
                    guard let target else { return }
                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(target, anchor: .top) }
                    scrollTarget = nil
                }
            }

            // نوار چسبان پایین: وقتی کاربر از کادرهای بالا (گالری/عنوان/قیمت/خرید) رد شد نمایش داده می‌شه
            if showStickyBar && product.inventory {
                stickyBar
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showStickyBar)
        .sheet(isPresented: $showPriceChart) {
            PriceChartSheet(chart: selectedSeller?.priceChangesChart, onDismiss: { showPriceChart = false })
                .shkSheetEnvironment()
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewSheet(
                isSubmitting: isSubmittingReview,
                onDismiss: { showWriteReview = false },
                // ضمیمه‌ی تصاویر خریدار به دیدگاه - فقط برای خریداران این محصول (مثل سایت)
                canAttachImages: viewerIsBuyer,
                onSubmit: submitReview
            )
            .shkSheetEnvironment()
        }
        .fullScreenCover(item: $lightbox) { request in
            ImageLightbox(
                imageUrls: request.urls,
                initialPage: request.index,
                onDismiss: { lightbox = nil },
                buyerImageUrls: request.buyerUrls,
                showImageSetTabs: request.tabs
            )
            .shkSheetEnvironment()
        }
        .task(id: TaskKey(productId: product.id, refreshKey: refreshKey)) { await loadSideData() }
        .onChange(of: visibleInventories ?? []) { variantHolder.update($0) }
        .onAppear { variantHolder.update(visibleInventories ?? []) }
        // موجودیِ منطبق با انتخاب، فروشنده‌ی فعال رو مشخص می‌کنه (قیمت پله‌ای/نمودار/امتیاز)
        .onChange(of: matchedVariant?.id) { matchedId in
            if let matchedId, allSellers.contains(where: { $0.inventoryId == matchedId }) {
                selectedSellerInventoryId = matchedId
            }
            if let inv = matchedVariant {
                quantity = min(max(quantity, inv.minQuantity), max(inv.minQuantity, inv.maxQuantity))
            }
        }
    }

    private struct TaskKey: Equatable { let productId: Int; let refreshKey: Int }

    // MARK: - گالری تصاویر

    /**
     * بازطراحی (درخواست ۱۸): تصویر محصول داخل یک کادر سفیدِ بزرگ (حتی در تم تاریک) با حاشیه‌ی داخلیِ زیاد؛
     * آیکن‌های اکشن و برچسب‌ها در گوشه‌ها و بیرون از محدوده‌ی خودِ عکس.
     */
    private var galleryItem: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let side = geo.size.width
                // فاز PX: اندازه‌ی دکمه‌های ستون آیکن‌ها طوری تنظیم می‌شه که همه‌ی آیکن‌ها در هر عرضی جا بشن
                let actionCount = CGFloat(5 + (showWarnings ? 1 : 0) + (gallery.isEmpty ? 0 : 1))
                let actionGap: CGFloat = side < 300 ? 6 : 8
                let actionSize = max(26, min(36, (side - actionGap * (actionCount - 1)) / actionCount))
                ZStack(alignment: .topLeading) {
                    if !gallery.isEmpty {
                        ShkPager(pageCount: gallery.count, currentPage: $galleryPage) { page in
                            RemoteImage(gallery[page].link, contentDescription: product.title, contentScale: .fit)
                                .padding(.horizontal, 48)
                                .padding(.vertical, 30)
                                .frame(width: side, height: side)
                                .contentShape(Rectangle())
                                .onTapGesture { openGalleryLightbox() }
                        }
                        .frame(width: side, height: side)
                    } else {
                        RemixIcon(RemixIcons.ImageLine, tint: GalleryIconTint.opacity(0.3), size: 64)
                            .frame(width: side, height: side)
                    }

                    // دکمه‌ی برگشت - گوشه‌ی بالا سمت راست (TopStart در راست‌به‌چپ)
                    GalleryActionButton(icon: RemixIcons.ArrowRightLine, contentDescription: "بازگشت", onClick: onBack)

                    // فاز ۳۳ (کد ۷): ستون عمودی آیکن‌ها در گوشه‌ی بالا سمت چپ، بیرون از محدوده‌ی عکس
                    VStack(spacing: actionGap) {
                        GalleryActionButton(
                            icon: isFavorite ? RemixIcons.HeartFill : RemixIcons.HeartLine, contentDescription: "علاقه‌مندی",
                            onClick: onFavoriteClick, tint: isFavorite ? colors.error : GalleryIconTint,
                            loading: isTogglingFavorite, size: actionSize
                        )
                        GalleryActionButton(icon: RemixIcons.ShareLine, contentDescription: "اشتراک‌گذاری", onClick: onShareClick, size: actionSize)
                        GalleryActionButton(
                            icon: isNotificationEnabled ? RemixIcons.Notification3Fill : RemixIcons.Notification3Line,
                            contentDescription: notificationLabel, onClick: onNotificationClick,
                            tint: isNotificationEnabled ? colors.primary : GalleryIconTint, loading: isTogglingNotification, size: actionSize
                        )
                        GalleryActionButton(icon: RemixIcons.ArrowLeftRightLine, contentDescription: "مقایسه", onClick: onCompareClick, loading: isAddingToCompare, size: actionSize)
                        GalleryActionButton(icon: RemixIcons.LineChartLine, contentDescription: "نمودار قیمت", onClick: { showPriceChart = true }, size: actionSize)
                        // فاز PA (۳-ن): آیکن هشدار - فقط وقتی محصول اطلاعیه/هشدار داره
                        if showWarnings {
                            GalleryActionButton(icon: RemixIcons.ErrorWarningLine, contentDescription: "هشدارهای محصول", onClick: openWarningsDialog,
                                                tint: ProductWarningIconTint, size: actionSize)
                        }
                        // دکمه‌ی ذره‌بین - علاوه بر خودِ تصویر، با این دکمه هم لایت‌باکس باز می‌شه
                        if !gallery.isEmpty {
                            GalleryActionButton(icon: RemixIcons.ZoomInLine, contentDescription: "بزرگ‌نمایی", onClick: openGalleryLightbox, size: actionSize)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .aspectRatio(1, contentMode: .fit)

            // فاز ۳۴ (اصلاحیه، کد ۲): لیبل‌های «اصالت کالا»/«وضعیت کالا» + شناسه‌ی محصول (سمت راست)
            // و نقطه‌های موقعیت اسلاید (سمت چپ)
            HStack(spacing: 0) {
                FlowRow(spacing: 6, lineSpacing: 6) {
                    if let original = product.bestInventory?.original {
                        let text = original ? "کالای اصل" : "کالای غیر اصل"
                        ProductLabelTag(text: text, icon: original ? RemixIcons.ShieldCheckLine : RemixIcons.ErrorWarningLine,
                                        color: original ? SiteStatusColors.Success : SiteStatusColors.Warning) {
                            showLabelInfo(text, original
                                ? "این محصول توسط فروشنده به‌عنوان کالای اصل (غیرتقلبی و دارای اصالت تضمین‌شده) ثبت شده است."
                                : "این محصول توسط فروشنده به‌عنوان کالای غیر اصل ثبت شده است.")
                        }
                    }
                    if let used = product.bestInventory?.used {
                        let text = used ? "کالای کارکرده" : "کالای نو"
                        ProductLabelTag(text: text, icon: used ? RemixIcons.RecycleLine : RemixIcons.VerifiedBadgeLine,
                                        color: used ? SiteStatusColors.Warning : SiteStatusColors.Info) {
                            showLabelInfo(text, used
                                ? "این محصول توسط فروشنده به‌عنوان کالای کارکرده (دست دوم) ثبت شده است."
                                : "این محصول توسط فروشنده به‌عنوان کالای نو ثبت شده است.")
                        }
                    }
                    // شناسه‌ی محصول (مثل سایت: uuid محصول) + کپی
                    let productCode = (product.uuid?.isBlankShk == false ? product.uuid! : String(product.id))
                    ProductIdTag(code: productCode) {
                        UIPasteboard.general.string = productCode
                        ShkToast.shared.show("شناسه محصول کپی شد")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                GalleryPagerDots(pageCount: gallery.count, currentPage: galleryPage).padding(.leading, 8)
            }
            .frame(minHeight: 28)
            .padding(2)
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - عنوان، برند، امتیاز

    private var titleItem: some View {
        SiteCard {
            // فاز ۲۶: برند و دسته‌بندی به‌صورت باکس‌های کوچک کلیک‌پذیر
            if product.brand != nil || product.category != nil || clubScore > 0 {
                HStack(spacing: 0) {
                    if let brand = product.brand {
                        ProductMetaChip(text: brand.title, icon: RemixIcons.VerifiedBadgeLine, color: colors.primary,
                                        background: colors.primary.opacity(0.1), onClick: { onOpenBrand(brand.slug) })
                    }
                    if product.brand != nil && product.category != nil {
                        Rectangle().fill(colors.outline.opacity(0.4)).frame(width: 1, height: 14).padding(.horizontal, 8)
                    }
                    if let category = product.category {
                        ProductMetaChip(text: category.title, icon: RemixIcons.LayoutGridLine, color: colors.onSurfaceVariant,
                                        background: colors.surfaceVariant, onClick: { onOpenCategory(category.slug, category.title) })
                    }
                    // فاز PA (۳-ط): سمت چپ - امتیاز باشگاه مشتریانِ این خرید (با آیکن سکه)
                    if clubScore > 0 {
                        Spacer(minLength: 8)
                        ProductMetaChip(text: "\(clubScore.toPersianDigits()) امتیاز", icon: RemixIcons.CopperCoinFill, color: colors.onSurface,
                                        background: ProductClubCoinColor.opacity(0.14), onClick: openClubScoreDialog, iconTint: ProductClubCoinColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)
            }

            Text(product.title)
                .shkFont(16, .bold, lineHeight: 28)
                .foregroundColor(colors.onSurface)
                .frame(maxWidth: .infinity, alignment: .leading)

            // فاز PA (۱): عنوان انگلیسی محصول - کم‌رنگ و چپ‌به‌راست، زیر عنوان فارسی
            if let titleEn = product.titleEn, !titleEn.isBlankShk {
                Text(titleEn)
                    .shkFont(12, lineHeight: 19)
                    .foregroundColor(colors.onSurfaceVariant)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(.top, 4)
            }

            // فاز PA (۳-م): «X٪ از کاربران، این کالا را پیشنهاد کرده اند.» + آیکن توضیح
            if let suggestPercent {
                Button(action: openSuggestDialog) {
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.ThumbUpFill, tint: SiteStatusColors.Success, size: 15)
                        Spacer().frame(width: 5)
                        Text("\(formatSuggestPercent(suggestPercent))٪ از کاربران، این کالا را پیشنهاد کرده اند.")
                            .shkFont(12, .medium, lineHeight: 18)
                            .foregroundColor(SiteStatusColors.Success)
                        Spacer().frame(width: 4)
                        RemixIcon(RemixIcons.InformationLine, contentDescription: "توضیح", tint: colors.onSurfaceVariant, size: 15)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(SitePressStyle())
                .padding(.top, 8)
            }

            // امتیاز ستاره‌ای + تعداد دیدگاه‌ها + تعداد پرسش‌ها (کلیک: رفتن به همون بخش)
            let rating = commentsInfo?.rating ?? 0
            let questionsCountText = formatQuestionsCount(questionsInfo?.count)
            if rating > 0 || commentsInfo != nil || questionsCountText != nil {
                FlowRow(spacing: 6, lineSpacing: 6) {
                    if rating > 0 {
                        ProductMetaChip(text: formatProductRating(rating), icon: RemixIcons.StarFill, color: colors.onSurface,
                                        background: ProductRatingStarColor.opacity(0.12), onClick: { scrollTarget = "reviews" }, iconTint: ProductRatingStarColor)
                    }
                    if let info = commentsInfo {
                        ProductMetaChip(text: "\(info.count.isEmpty ? "۰" : info.count.toPersianDigits()) دیدگاه", icon: RemixIcons.ChatQuoteLine,
                                        color: colors.onSurfaceVariant, background: colors.surfaceVariant, onClick: { scrollTarget = "reviews" })
                    }
                    if let questionsCountText {
                        ProductMetaChip(text: "\(questionsCountText) پرسش", icon: RemixIcons.QuestionAnswerLine,
                                        color: colors.onSurfaceVariant, background: colors.surfaceVariant, onClick: { scrollTarget = "qna" })
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - کادر قیمت + خرید

    /// فاز PA (۳-د): قیمت و لیبل حداقل/حداکثر خرید سمت راست؛ سمت چپشون تنظیم‌کننده‌ی تعداد و دکمه‌ی افزودن به سبد
    private var priceItem: some View {
        SiteCard {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    if !product.inventory {
                        HStack(spacing: 0) {
                            SiteIconBadge(icon: RemixIcons.ErrorWarningLine, size: 38, iconSize: 19, tint: colors.error)
                            Spacer().frame(width: 10)
                            Text("ناموجود").shkFont(16, .bold).foregroundColor(colors.error)
                        }
                    } else if let price = displayPrice {
                        // با عوض شدن گزینه‌ها، قیمت با یک انیمیشن کوتاه جایگزین می‌شه تا تغییرش دیده بشه
                        ZStack(alignment: .leading) {
                            priceBlock(price)
                                .id(price)
                                .transition(.asymmetric(
                                    insertion: .offset(y: 14).combined(with: .opacity),
                                    removal: .offset(y: -14).combined(with: .opacity)
                                ))
                        }
                        .animation(.easeInOut(duration: 0.25), value: price)

                        if let ago = selectedSeller?.priceUpdatedAtAgo, !ago.isBlankShk {
                            HStack(spacing: 0) {
                                RemixIcon(RemixIcons.TimeLine, tint: colors.onSurfaceVariant, size: 13)
                                Spacer().frame(width: 4)
                                Text("آخرین به‌روزرسانی قیمت: \(ago)").shkFont(10, lineHeight: 16).foregroundColor(colors.onSurfaceVariant)
                            }
                            .padding(.top, 6)
                        }
                    }

                    // فاز ۳۴ (اصلاحیه، کد ۲): لیبل حداقل/حداکثر تعداد خرید دقیقاً زیر قیمت
                    if product.inventory && (quantityMin > 1 || quantityMax < Int.max) {
                        HStack(alignment: .center, spacing: 0) {
                            RemixIcon(RemixIcons.InformationLine, tint: SiteStatusColors.Info, size: 14)
                            Spacer().frame(width: 5)
                            Text(minMaxText).shkFont(11, lineHeight: 18).foregroundColor(colors.onSurface)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surfaceVariant.opacity(0.6)))
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // سمت چپ: تنظیم تعداد (ردیف ۱) + افزودن به سبد (ردیف ۲) - برای همه‌ی محصولات
                Spacer().frame(width: 10)
                VStack(spacing: 8) {
                    if canBuy {
                        ProductQuantityStepper(
                            quantity: quantity,
                            onIncrease: { if quantity < quantityMax { quantity += 1 } },
                            onDecrease: { if quantity > quantityMin { quantity -= 1 } },
                            height: 40,
                            increaseEnabled: quantity < quantityMax,
                            decreaseEnabled: quantity > quantityMin,
                            fillWidth: true
                        )
                        SitePrimaryButton(text: "افزودن به سبد", onClick: addCurrentSelectionToCart, icon: RemixIcons.ShoppingCart2Line,
                                          loading: isAddingToCart, height: 44, fontSize: 13, fillWidth: true)
                    } else {
                        SitePrimaryButton(text: "ناموجود", onClick: {}, enabled: false, height: 44, fontSize: 13, fillWidth: true)
                    }
                }
                .frame(width: 150)
            }

            // A14: کارت‌های «هر قسط با ...» درست زیر دکمه‌ی افزودن به سبد
            let installments = installmentCards
            if !installments.isEmpty {
                ProductInstallmentCards(cards: installments)
                    .padding(.top, 12)
            }

            // فاز PX: راهنمای انتخاب - وقتی محصول چندنوعیه و هنوز ترکیب معتبری انتخاب نشده
            if hasRealVariants && product.inventory && matchedVariant == nil {
                Button(action: { scrollTarget = optionsItemKey }) {
                    HStack(spacing: 0) {
                        RemixIcon(RemixIcons.ArrowUpLine, tint: SiteStatusColors.Warning, size: 15)
                        Spacer().frame(width: 6)
                        Text("برای افزودن به سبد، ابتدا گزینه‌های محصول را از بالا انتخاب کنید.")
                            .shkFont(11, .medium, lineHeight: 18)
                            .foregroundColor(colors.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SiteStatusColors.Warning.opacity(0.1)))
                }
                .buttonStyle(SitePressStyle())
                .padding(.top, 12)
            }

            // فاز PA (۳-ک): لیبل‌های چرخانِ ترغیب به خرید، داخل همین کادر
            let stats = statTexts
            if !stats.isEmpty {
                Spacer().frame(height: 12)
                ProductStatsTicker(texts: stats)
            }
        }
        .padding(.horizontal, 16)
    }

    private var minMaxText: String {
        var s = ""
        if quantityMin > 1 { s += "حداقل خرید: \(quantityMin.toPersianDigits()) عدد" }
        if quantityMin > 1 && quantityMax < Int.max { s += "\n" }
        if quantityMax < Int.max { s += "حداکثر خرید: \(quantityMax.toPersianDigits()) عدد" }
        return s
    }

    @ViewBuilder
    private func priceBlock(_ price: ProductDisplayPrice) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let old = price.oldPrice {
                // قیمت قبلی (خط‌خورده) + درصد تخفیف (قرص قرمز)
                HStack(spacing: 0) {
                    Text(old).shkFont(12).strikethrough().foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                    if let percent = price.discountPercent, percent > 0 {
                        Spacer().frame(width: 6)
                        Text("\(percent.toPersianDigits())%-")
                            .shkFont(11, .bold, lineHeight: 16)
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(colors.primary))
                    }
                }
                Spacer().frame(height: 2)
                ProductFinalPrice(price: price.finalPrice, color: colors.primary, fontSize: 20)
            } else {
                ProductFinalPrice(price: price.finalPrice, color: colors.onSurface, fontSize: 20)
            }
        }
    }

    // MARK: - توضیحات، مشخصات، تب‌ها

    private var descriptionItem: some View {
        ProductSection(title: "توضیحات محصول") {
            SiteCard {
                let previewText = String(htmlToPlainText(product.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(220))
                Text("\(previewText)...")
                    .shkFont(13, lineHeight: 24)
                    .foregroundColor(colors.onSurfaceVariant)
                    .lineLimit(4)
                Spacer().frame(height: 12)
                SiteSecondaryButton(text: "مشاهده‌ی کامل توضیحات محصول", onClick: { onOpenDescription("توضیحات محصول", product.content ?? "") },
                                    icon: RemixIcons.FileTextLine, height: 44, fontSize: 13, fillWidth: true)
            }
        }
    }

    /// فاز ۳۳ (کد ۹): فقط گروه اول داخل یک کارت واحد نمایش داده می‌شه
    private var specsItem: some View {
        let specifications = product.specifications ?? []
        return ProductSection(title: "مشخصات فنی") {
            SiteCard {
                ForEach(Array(specifications.prefix(1).enumerated()), id: \.offset) { _, group in
                    let filledKeys = group.keys.filter { !($0.value?.isBlankShk ?? true) }
                    if !filledKeys.isEmpty {
                        HStack(spacing: 6) {
                            RemixIcon(RemixIcons.ListCheck2, tint: colors.primary, size: 16)
                            Text(group.title).shkFont(13, .bold).foregroundColor(colors.primary)
                        }
                        .padding(.bottom, 4)
                        ForEach(Array(filledKeys.enumerated()), id: \.offset) { index, specKey in
                            if index > 0 { SiteDashedDivider() }
                            SpecKeyValueRow(specKey: specKey)
                        }
                        Spacer().frame(height: 8)
                    }
                }
                SiteSecondaryButton(text: "مشاهده‌ی کامل جدول مشخصات محصول", onClick: { onOpenFullSpecs(specifications) },
                                    icon: RemixIcons.FileList3Line, height: 44, fontSize: 13, fillWidth: true)
            }
        }
    }

    /// هر تب محتوایی (مثل «دیتاشیت محصول») یک بخش جدا: پیش‌نمایش متن + دکمه‌ی «مشاهده‌ی کامل»
    private func tabItem(_ tab: ProductTabDto) -> some View {
        let tabPreview = String(
            htmlToPlainText(tab.content ?? "")
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .replacingOccurrences(of: #"[\u{FFFC}\s]+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
                .prefix(220)
        )
        return ProductSection(title: tab.title) {
            SiteCard {
                if !tabPreview.isEmpty {
                    Text("\(tabPreview)...")
                        .shkFont(13, lineHeight: 24)
                        .foregroundColor(colors.onSurfaceVariant)
                        .lineLimit(4)
                    Spacer().frame(height: 12)
                }
                SiteSecondaryButton(text: "مشاهده‌ی کامل \(tab.title)", onClick: { onOpenDescription(tab.title, tab.content ?? "") },
                                    icon: RemixIcons.FileTextLine, height: 44, fontSize: 13, fillWidth: true)
            }
        }
    }

    // MARK: - نوار چسبان

    private var stickyBar: some View {
        // فاز PX: همون قیمتِ کادر قیمت (برای چندنوعی: قیمت موجودیِ انتخاب‌شده)
        let stickyPrice = displayPrice?.finalPrice == "-" ? nil : displayPrice?.finalPrice
        return StickyAddToCartBar(
            quantity: quantity,
            minQuantity: quantityMin,
            maxQuantity: quantityMax,
            isAdding: isAddingToCart,
            // فاز PX: محصول چندنوعی بعد از انتخاب ترکیب معتبر، مثل محصول تک‌نوعی رفتار می‌کنه
            hasVariants: hasRealVariants && matchedVariant == nil,
            onDecrease: { if quantity > quantityMin { quantity -= 1 } },
            onIncrease: { if quantity < quantityMax { quantity += 1 } },
            onAddClick: {
                if hasRealVariants && matchedVariant == nil {
                    // محصول چندنوعی بدون انتخاب: برگرد به انتخابگرهای ویژگی (بالای کادر قیمت)
                    scrollTarget = optionsItemKey
                } else if hasRealVariants || product.bestInventory?.id != nil {
                    addCurrentSelectionToCart()
                }
            },
            priceText: stickyPrice,
            oldPriceText: displayPrice?.oldPrice
        )
    }

    // MARK: - داده‌های جانبی

    private func loadSideData() async {
        // آدرس همین محصول برای گفتینو («صفحه‌ی فعلی»)
        CurrentPageViewModel.shared.currentPageUrl = "\(ApiConstants.BASE_URL.hasSuffix("/") ? String(ApiConstants.BASE_URL.dropLast()) : ApiConstants.BASE_URL)/product/\(product.slug)"
        CurrentPageViewModel.shared.currentPageLabel = product.title
        RecentlyViewedManager.shared.recordView(RecentlyViewedProduct(
            slug: product.slug, title: product.title, imageUrl: product.galleryImages.first?.link,
            bestPrice: product.bestPrice.map { Int64($0) }
        ))
        loadComments(1)
        loadQuestions(1)
        async let inventoriesTask: Void = loadInventories()
        async let extrasTask: Void = loadExtras()
        _ = await (inventoriesTask, extrasTask)
    }

    private func loadInventories() async {
        guard product.inventory else { return }
        switch await catalogRepository.getProductInventories(product.slug) {
        case .success(let data): inventories = data
        case .error: inventories = []
        }
    }

    private func loadExtras() async {
        switch await productExtrasRepository.getProductExtras(product.slug) {
        case .success(let data):
            productExtras = data
            // بعد از بروزرسانی، فروشنده‌ی انتخاب‌شده (اگه هنوز هست) حفظ می‌شه
            if let id = selectedSellerInventoryId, data.sellers.contains(where: { $0.inventoryId == id }) {
                // همون فروشنده
            } else {
                selectedSellerInventoryId = data.sellers.first?.inventoryId
            }
        case .error(let message):
            print("ProductDetailScreen: getProductExtras failed for \(product.slug): \(message)")
        }
    }

    private func loadComments(_ page: Int) {
        Task {
            let requestedSort = commentsSort
            if page == 1 { commentsLoading = true }
            let result = await reviewsRepository.getCommentsSorted(product.slug, page: page, sort: requestedSort)
            if requestedSort != commentsSort { return }
            commentsLoading = false
            if case .success(let body) = result {
                commentsInfo = body.commentsInfo
                ratingBreakdown = body.ratingBreakdown
                viewerIsBuyer = body.viewerIsBuyer == true
                let data = body.comments?.data ?? []
                comments = page == 1 ? data : comments + data
                commentsPage = body.comments?.currentPage ?? page
                commentsHasMore = (body.comments?.currentPage ?? 1) < (body.comments?.lastPage ?? 1)
            }
        }
    }

    private func loadQuestions(_ page: Int) {
        Task {
            let requestedSort = questionsSort
            if page == 1 { questionsLoading = true }
            let result = await reviewsRepository.getQuestionsSorted(product.slug, page: page, sort: requestedSort)
            if requestedSort != questionsSort { return }
            questionsLoading = false
            if case .success(let body) = result {
                questionsInfo = body.questionsInfo
                let data = body.questions?.data ?? []
                questions = page == 1 ? data : questions + data
                questionsPage = body.questions?.currentPage ?? page
                questionsHasMore = (body.questions?.currentPage ?? 1) < (body.questions?.lastPage ?? 1)
            }
        }
    }

    // MARK: - اکشن‌ها

    private func vote(_ commentId: Int, _ up: Bool) {
        Task {
            if case .success(let r) = await reviewsRepository.voteComment(commentId, up: up) {
                comments = comments.map { c in
                    guard c.id == commentId else { return c }
                    var copy = c
                    copy.voteUp = r.voteUp
                    copy.voteDown = r.voteDown
                    return copy
                }
            }
        }
    }

    private func submitQuestion(_ question: String) {
        Task {
            isSubmittingQuestion = true
            let result = await reviewsRepository.submitQuestion(product.slug, question: question)
            isSubmittingQuestion = false
            if case .success(let body) = result {
                ShkToast.shared.show(body.message ?? "سؤال ثبت شد")
                loadQuestions(1)
            }
        }
    }

    private func submitReview(_ content: String, _ rating: Int, _ suggest: Bool?, _ strengths: [String], _ weakness: [String], _ images: [Data]) {
        Task {
            isSubmittingReview = true
            let result = await reviewsRepository.submitComment(
                slug: product.slug, content: content, rating: rating, suggestion: suggest,
                strengths: strengths, weakness: weakness, images: images.isEmpty ? nil : images
            )
            isSubmittingReview = false
            switch result {
            case .success(let body):
                ShkToast.shared.show(body.message ?? "دیدگاه ثبت شد")
                showWriteReview = false
                loadComments(1)
            case .error(let message):
                ShkToast.shared.show(message)
            }
        }
    }

    private func onCompareClick() {
        if isAddingToCompare { return }
        isAddingToCompare = true
        Task {
            // فاز ۲۹: قبل از افزودن، چک می‌کنیم این محصول از قبل تو لیست مقایسه هست یا نه
            let alreadyInCompare: Bool
            if case .success(let list) = await productCompareRepository.getCompares() {
                alreadyInCompare = list.compares.contains { $0.slug == product.slug }
            } else {
                alreadyInCompare = false
            }
            if alreadyInCompare {
                isAddingToCompare = false
                // فاز ۲۹: مودال «این محصول قبلاً به لیست مقایسه اضافه شده»
                let open = onOpenCompare
                ShkDialogCenter.shared.show {
                    SiteDialogContent(
                        title: "افزودن به مقایسه", icon: RemixIcons.ArrowLeftRightLine,
                        message: "این محصول قبلاً به لیست مقایسه اضافه شده است.",
                        confirmText: "رفتن به صفحه مقایسه",
                        onConfirm: { ShkDialogCenter.shared.dismiss(); open() },
                        dismissText: "بستن",
                        onDismiss: { ShkDialogCenter.shared.dismiss() }
                    )
                }
            } else {
                switch await productCompareRepository.addToCompare(product.slug) {
                case .success(let r):
                    ShkToast.shared.show(r.message ?? "به لیست مقایسه اضافه شد")
                    onOpenCompare()
                case .error(let message):
                    ShkToast.shared.show(message)
                }
                isAddingToCompare = false
            }
        }
    }

    private func onNotificationClick() {
        if isTogglingNotification { return }
        isTogglingNotification = true
        let type = notificationType
        let label = notificationLabel
        Task {
            let message: String
            switch await productExtrasRepository.toggleNotification(product.slug, type: type) {
            case .success(let r):
                if type == "inventory" { productExtras?.hasInventoryNotification = r.enabled }
                else { productExtras?.hasDiscountNotification = r.enabled }
                // فاز ۳۳ (کد ۱۰): به‌جای toast از مودال استفاده می‌کنیم
                message = r.message ?? (r.enabled ? "اعلان فعال شد" : "اعلان غیرفعال شد")
            case .error(let m):
                message = m
            }
            isTogglingNotification = false
            ShkDialogCenter.shared.show {
                SiteDialogContent(title: label, icon: RemixIcons.Notification3Line, message: message,
                                  confirmText: "باشه", onConfirm: { ShkDialogCenter.shared.dismiss() })
            }
        }
    }

    private func onShareClick() {
        let base = ApiConstants.BASE_URL.hasSuffix("/") ? String(ApiConstants.BASE_URL.dropLast()) : ApiConstants.BASE_URL
        presentShareSheet(text: "\(product.title)\n\(base)/product/\(product.slug)")
    }

    private func onFavoriteClick() {
        if isTogglingFavorite { return }
        isTogglingFavorite = true
        Task {
            switch await favoriteRepository.toggleFavorite(product.id) {
            case .success(let fav): isFavorite = fav
            case .error(let message): ShkToast.shared.show(message)
            }
            isTogglingFavorite = false
        }
    }

    /// افزودن موجودیِ تکی (بدون انتخاب نوع) به سبد - مشترک بین باکس خرید و نوار چسبان
    private func addSingleInventoryToCart() {
        guard let inventoryId = selectedSeller?.inventoryId ?? product.bestInventory?.id else { return }
        addToCart(inventoryId)
    }

    private func addToCart(_ inventoryId: Int) {
        isAddingToCart = true
        CartViewModel.shared.addToCart(inventoryId: inventoryId, count: quantity) { success, message in
            isAddingToCart = false
            // message == nil یعنی مودال ورود نمایش داده شده (کاربر مهمان) - toast لازم نیست
            if let text = success ? "به سبد خرید اضافه شد" : message { ShkToast.shared.show(text) }
        }
    }

    /// فاز PX: دکمه‌ی خرید داخل کادر قیمت (و نوار چسبان)
    private func addCurrentSelectionToCart() {
        if !hasRealVariants {
            addSingleInventoryToCart()
            return
        }
        guard let inv = matchedVariant else {
            ShkToast.shared.show(variantState.isComplete ? "این ترکیب موجود نیست؛ لطفاً گزینه‌ی دیگری انتخاب کنید" : "لطفاً ابتدا گزینه‌های محصول را انتخاب کنید")
            scrollTarget = optionsItemKey
            return
        }
        addToCart(inv.id)
    }

    private func openGalleryLightbox() {
        // فاز PA (۳-الف): تب‌های «تصاویر رسمی» / «تصاویر خریداران» مثل سایت
        lightbox = LightboxRequest(
            urls: gallery.map(\.link),
            index: galleryPage,
            buyerUrls: (product.buyerImages ?? []).map(\.link).filter { !$0.isBlankShk },
            tabs: true
        )
    }

    // فاز ۳۴ (کد ۹): مودال توضیح لیبل «اصالت کالا»/«وضعیت کالا»
    private func showLabelInfo(_ title: String, _ description: String) {
        ShkDialogCenter.shared.show {
            SiteDialogContent(title: title, icon: RemixIcons.ShieldCheckLine, message: description,
                              confirmText: "باشه", onConfirm: { ShkDialogCenter.shared.dismiss() })
        }
    }

    // فاز PA (۳-ن): مودال هشدارها/اطلاعیه‌ی محصول
    private func openWarningsDialog() {
        guard let text = warningsText, !text.isBlankShk else { return }
        ShkDialogCenter.shared.show {
            WarningsDialog(text: text)
        }
    }

    // فاز PA (۳-م): توضیح درصد پیشنهاد خریداران (متن خودِ سایت)
    private func openSuggestDialog() {
        guard let suggestPercent else { return }
        ShkDialogCenter.shared.show {
            SiteDialogContent(
                title: "\(formatSuggestPercent(suggestPercent))٪ از کاربران، این کالا را پیشنهاد کرده اند.",
                icon: RemixIcons.ThumbUpLine, iconTint: SiteStatusColors.Success,
                message: "کاربران با ارایه تجربه خرید خود یکی از گزینه های پیشنهاد یا عدم پیشنهاد محصول را انتخاب میکنند.",
                confirmText: "باشه", onConfirm: { ShkDialogCenter.shared.dismiss() }
            )
        }
    }

    // فاز PA (۳-ط): توضیح امتیاز باشگاه مشتریان این خرید
    private func openClubScoreDialog() {
        guard clubScore > 0 else { return }
        let q = quantity, score = clubScore
        ShkDialogCenter.shared.show {
            SiteDialogContent(
                title: "امتیاز باشگاه مشتریان", icon: RemixIcons.CopperCoinLine, iconTint: ProductClubCoinColor,
                message: "با خرید \(q.toPersianDigits()) عدد از این محصول، \(score.toPersianDigits()) امتیاز باشگاه مشتریان دریافت می‌کنید.",
                confirmText: "باشه", onConfirm: { ShkDialogCenter.shared.dismiss() }
            )
        }
    }
}

/// درخواست باز کردن لایت‌باکس
struct LightboxRequest: Identifiable {
    let id = UUID()
    let urls: [String]
    let index: Int
    let buyerUrls: [String]
    let tabs: Bool
}

/// مودال «هشدارها و نکات مهم محصول»
private struct WarningsDialog: View {
    let text: String
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteDialogContent(
            title: "هشدارها و نکات مهم محصول", icon: RemixIcons.ErrorWarningLine, iconTint: ProductWarningIconTint,
            confirmText: "متوجه شدم", onConfirm: { ShkDialogCenter.shared.dismiss() }
        ) {
            Text("لطفاً پیش از ثبت سفارش، نکات زیر را که برای این محصول ثبت شده است مطالعه کنید.")
                .shkFont(12, lineHeight: 21)
                .foregroundColor(colors.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Spacer().frame(height: 12)
            HStack(alignment: .top, spacing: 8) {
                RemixIcon(RemixIcons.InformationLine, tint: ProductWarningIconTint, size: 18)
                Text(text)
                    .shkFont(13, .medium, lineHeight: 24)
                    .foregroundColor(colors.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ProductWarningIconTint.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ProductWarningIconTint.opacity(0.25), lineWidth: 1))
        }
    }
}

// MARK: - اجزای کوچک صفحه

/// ثبت دیده‌شدن یک آیتم لیست (برای نمایش نوار چسبان؛ معادل layoutInfo.visibleItemsInfo)
private extension View {
    func trackVisibility(_ key: String, _ set: Binding<Set<String>>) -> some View {
        onAppear { set.wrappedValue.insert(key) }
            .onDisappear { set.wrappedValue.remove(key) }
    }
}

/**
 * بازطراحی: نوار چسبان پایین صفحه - قیمت، تنظیم‌کننده‌ی تعداد و دکمه‌ی اصلی قرمز.
 * برای محصولات چندنوعی فقط دکمه‌ی «انتخاب و افزودن به سبد» نمایش داده می‌شه.
 */
private struct StickyAddToCartBar: View {
    let quantity: Int
    let minQuantity: Int
    let maxQuantity: Int
    let isAdding: Bool
    let hasVariants: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onAddClick: () -> Void
    var priceText: String? = nil
    // فاز PA (۳-ز): قیمت قبل از تخفیف (خط‌خورده)
    var oldPriceText: String? = nil
    @Environment(\.shkColors) private var colors

    var body: some View {
        HStack(spacing: 0) {
            if !hasVariants {
                if let priceText {
                    VStack(alignment: .leading, spacing: 0) {
                        if let oldPriceText, !oldPriceText.isBlankShk {
                            Text(oldPriceText).shkFont(11, lineHeight: 15).strikethrough().foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                        }
                        HStack(spacing: 3) {
                            Text(priceText)
                                .shkFont(17, .bold, lineHeight: 24)
                                .foregroundColor(!(oldPriceText?.isBlankShk ?? true) ? colors.primary : colors.onSurface)
                                .lineLimit(1)
                            Text("تومان").shkFont(10).foregroundColor(colors.onSurfaceVariant).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(width: 8)
                }
                ProductQuantityStepper(
                    quantity: quantity, onIncrease: onIncrease, onDecrease: onDecrease, height: 44,
                    increaseEnabled: quantity < maxQuantity, decreaseEnabled: quantity > minQuantity,
                    increaseDescription: "زیاد کردن", decreaseDescription: "کم کردن"
                )
                Spacer().frame(width: 8)
            }
            SitePrimaryButton(
                text: hasVariants ? "انتخاب و افزودن به سبد" : "افزودن به سبد",
                onClick: onAddClick,
                icon: hasVariants ? RemixIcons.ShoppingCart2Line : nil,
                loading: isAdding,
                height: 44,
                fontSize: 13,
                fillWidth: hasVariants || priceText == nil
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            TopRoundedShape(radius: 20)
                .fill(colors.surface)
                .shadow(color: .black.opacity(0.14), radius: 9, x: 0, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

/// شکل با گوشه‌های گرد فقط در بالا (RoundedCornerShape(topStart, topEnd))
struct TopRoundedShape: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(radius, rect.height / 2, rect.width / 2)
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/** بازطراحی: عنوان بخش (خط قرمز) + محتوای بخش با فاصله‌ی استاندارد */
private struct ProductSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SiteSectionTitle(title)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }
}

/**
 * قیمت نهایی بزرگ و بولد + «تومان» کوچک کنارش. اگه جا نباشه «تومان» به خط بعد می‌ره.
 */
private struct ProductFinalPrice: View {
    let price: String
    let color: Color
    var fontSize: CGFloat = 22
    @Environment(\.shkColors) private var colors

    var body: some View {
        FlowRow(spacing: 5, lineSpacing: 0) {
            Text(price).shkFont(fontSize, .bold, lineHeight: 30).foregroundColor(color).lineLimit(1).fixedSize()
            Text("تومان").shkFont(12, lineHeight: 16).foregroundColor(colors.onSurfaceVariant).padding(.top, 10)
        }
    }
}

/**
 * بازطراحی: دکمه‌ی آیکنیِ کادردارِ کوچک روی کادر سفید گالری - در حال انجام عملیات، به‌جای آیکن یک لودینگ کوچک.
 */
private struct GalleryActionButton: View {
    let icon: String
    let contentDescription: String
    let onClick: () -> Void
    var tint: Color = GalleryIconTint
    var loading: Bool = false
    var size: CGFloat = 36
    @Environment(\.shkColors) private var colors

    var body: some View {
        Button(action: onClick) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous).fill(GalleryButtonBackground)
                if loading {
                    MaterialSpinner(color: colors.primary, lineWidth: 2, size: 16)
                } else {
                    RemixIcon(icon, contentDescription: contentDescription, tint: tint, size: size < 32 ? 16 : 19)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(SitePressStyle())
    }
}

/**
 * نقطه‌های موقعیت اسلاید گالری (نقطه‌ی فعال قرص قرمز) - رنگ نقطه‌های غیرفعالِ ثابت چون کادر گالری سفیده.
 */
private struct GalleryPagerDots: View {
    let pageCount: Int
    let currentPage: Int
    @Environment(\.shkColors) private var colors

    var body: some View {
        if pageCount > 1 {
            let maxDots = 5
            let start = pageCount <= maxDots ? 0 : min(max(currentPage - maxDots / 2, 0), pageCount - maxDots)
            let end = min(pageCount, start + maxDots)
            HStack(spacing: 4) {
                ForEach(start..<end, id: \.self) { index in
                    let isActive = index == currentPage
                    Capsule()
                        .fill(isActive ? colors.primary : Color(argb: 0xFFD6D9E0))
                        .frame(width: isActive ? 15 : 6, height: 6)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: currentPage)
        }
    }
}

/** فاز ۳۴ (اصلاحیه، کد ۲): تگ کوچیک برای لیبل‌های «اصالت کالا»/«وضعیت کالا» - کلیک: مودال توضیحی */
private struct ProductLabelTag: View {
    let text: String
    let icon: String
    let color: Color
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 4) {
                RemixIcon(icon, tint: color, size: 14)
                Text(text).shkFont(11, .bold, lineHeight: 16).foregroundColor(color).lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.12)))
        }
        .buttonStyle(SitePressStyle())
    }
}

/** بازطراحی: چیپ کوچک کلیک‌پذیر (برند، دسته‌بندی، امتیاز، تعداد دیدگاه/پرسش) */
private struct ProductMetaChip: View {
    let text: String
    let icon: String
    let color: Color
    let background: Color
    let onClick: () -> Void
    var iconTint: Color? = nil

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 4) {
                RemixIcon(icon, tint: iconTint ?? color, size: 14)
                Text(text).shkFont(11, .bold, lineHeight: 16).foregroundColor(color).lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(background))
        }
        .buttonStyle(SitePressStyle())
    }
}

/** فاز PA (۳-د): تگ شناسه‌ی محصول با دکمه‌ی کپی (داخل کادر سفید گالری، پس رنگ‌ها ثابت) */
private struct ProductIdTag: View {
    let code: String
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 0) {
                RemixIcon(RemixIcons.Hashtag, tint: GalleryIconTint, size: 13)
                Spacer().frame(width: 3)
                Text(code.toPersianDigits()).shkFont(11, .bold, lineHeight: 16).foregroundColor(GalleryIconTint).lineLimit(1)
                Spacer().frame(width: 5)
                RemixIcon(RemixIcons.FileCopyLine, contentDescription: "کپی شناسه محصول", tint: GalleryIconTint.opacity(0.75), size: 13)
            }
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(GalleryButtonBackground))
        }
        .buttonStyle(SitePressStyle())
    }
}

/**
 * فاز PA (۳-ک): کادر کوچکِ لیبل‌های چرخان ترغیب به خرید - هر ۳ ثانیه (مثل سایت) لیبل بعدی با
 * انیمیشن اسلاید عمودی + محو شدن جایگزین می‌شه.
 */
private struct ProductStatsTicker: View {
    let texts: [ProductStatText]
    @State private var index = 0
    @Environment(\.shkColors) private var colors

    var body: some View {
        let current = index < texts.count ? texts[index] : texts[0]
        ZStack {
            statText(current)
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
        }
        .frame(maxWidth: .infinity, minHeight: 34 - 12)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(colors.surfaceVariant.opacity(0.6)))
        .clipped()
        .task(id: texts.count) {
            index = 0
            guard texts.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 0.35)) { index = (index + 1) % texts.count }
            }
        }
    }

    private func statText(_ stat: ProductStatText) -> some View {
        (Text(stat.prefix).foregroundColor(colors.onSurface)
            + Text(stat.value).font(ShkFont.yekan(12, .bold)).foregroundColor(stat.valueColor ?? colors.onSurface)
            + Text(stat.suffix).foregroundColor(colors.onSurface))
            .shkFont(12, lineHeight: 20)
            .lineLimit(1)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/**
 * فاز PA (۳-ل): کارت «خصوصیات برجسته» - هر ردیف «عنوان: مقدار» با نقطه‌ی رنگی؛ اگه فهرست بلند باشه،
 * ابتدا ۵ مورد نمایش داده می‌شه و با «بیشتر/کمتر» باز و بسته می‌شه.
 */
private struct ProductFeaturesCard: View {
    let features: [ProductFeatureDto]
    @State private var expanded = false
    @Environment(\.shkColors) private var colors

    var body: some View {
        let collapsedCount = 5
        let canExpand = features.count > collapsedCount
        let visible = expanded || !canExpand ? features : Array(features.prefix(collapsedCount))
        SiteCard {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, feature in
                if index > 0 { Spacer().frame(height: 8) }
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(colors.primary).frame(width: 6, height: 6).padding(.top, 8)
                    featureText(feature).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if canExpand {
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() } }) {
                    HStack(spacing: 2) {
                        Text(expanded ? "کمتر" : "بیشتر").shkFont(12, .bold).foregroundColor(colors.primary)
                        RemixIcon(expanded ? RemixIcons.ArrowUpSLine : RemixIcons.ArrowDownSLine, tint: colors.primary, size: 16)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .buttonStyle(SitePressStyle())
                .padding(.top, 10)
            }
        }
    }

    private func featureText(_ feature: ProductFeatureDto) -> some View {
        let key = feature.key ?? ""
        let keyPart = key.isBlankShk ? Text("") : Text("\(key): ").foregroundColor(colors.onSurfaceVariant)
        return (keyPart + Text(feature.value ?? "").font(ShkFont.yekan(13, .bold)).foregroundColor(colors.onSurface))
            .shkFont(13, lineHeight: 22)
    }
}

// MARK: - توابع کمکی

/** مثل سایت (Math.ceil(n / 100) * 100): گرد کردن به مضرب بالاترِ ۱۰۰ */
private func roundUpToHundred(_ value: Int64) -> Int64 { value <= 0 ? 0 : ((value + 99) / 100) * 100 }

/** درصد پیشنهاد به همون شکل سایت (عدد صحیح بدون اعشار، در غیر این صورت با اعشار) */
private func formatSuggestPercent(_ value: Double) -> String {
    let text = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int64(value)) : String(value)
    return text.toPersianDigits()
}

/** درصد تخفیف (عدد صحیح) - فقط وقتی تخفیف معتبره و قیمت نهایی کمتر از قیمت اصلیه */
private func discountPercentOf(_ price: Int64, _ finalPrice: Int64, _ discountValid: Bool) -> Int? {
    if !discountValid || price <= 0 || finalPrice >= price { return nil }
    let p = Int((price - finalPrice) * 100 / price)
    return p > 0 ? p : nil
}

/** قیمت فروشنده‌ی انتخاب‌شده (وقتی محصول در چند فروشگاه موجوده) */
private func sellerDisplayPrice(_ seller: ProductSellerDto) -> ProductDisplayPrice {
    let finalPrice = seller.finalPrice ?? 0
    let originalPrice = seller.price ?? 0
    let hasDiscount = seller.isDiscountValid && originalPrice > finalPrice
    return ProductDisplayPrice(
        oldPrice: hasDiscount ? formatTomanFa(originalPrice) : nil,
        finalPrice: formatTomanFa(finalPrice),
        discountPercent: discountPercentOf(originalPrice, finalPrice, hasDiscount)
    )
}

/** بهترین قیمت محصول (best_normal_price) */
private func bestNormalDisplayPrice(_ best: BestNormalPriceDto) -> ProductDisplayPrice {
    guard let discount = best.discountPrice, !discount.isBlankShk else {
        return ProductDisplayPrice(oldPrice: nil, finalPrice: best.price?.toPersianDigits() ?? "-", discountPercent: nil)
    }
    let original = Int64(best.price?.replacingOccurrences(of: ",", with: "") ?? "")
    let discounted = Int64(discount.replacingOccurrences(of: ",", with: ""))
    var percent: Int? = nil
    if let original, let discounted, original > 0 {
        let p = Int((original - discounted) * 100 / original)
        percent = p > 0 ? p : nil
    }
    return ProductDisplayPrice(oldPrice: best.price?.toPersianDigits(), finalPrice: discount.toPersianDigits(), discountPercent: percent)
}

/// منوی اشتراک‌گذاری سیستم (معادل Intent.ACTION_SEND + createChooser)
@MainActor
func presentShareSheet(text: String) {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
          var top = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
    while let presented = top.presentedViewController { top = presented }
    let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
    controller.popoverPresentationController?.sourceView = top.view
    top.present(controller, animated: true)
}
