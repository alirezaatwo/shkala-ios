import Foundation

/// معادل ProductsPage اپ اندروید
struct ProductsPage {
    let items: [ProductListItemDto]
    let pagination: PaginationDto
    // فاز ۲۶ (اصلاحیه): فیلترهای اختصاصیِ در دسترس برای همین کوئری (مثلاً همین دسته‌بندی)
    var dynamicFilters: [DynamicFilterDto] = []
}

/// فاز ۱۰: مرتب‌سازی و فیلترهای صفحات دسته‌بندی/برند - دقیقاً همون گزینه‌هایی که
/// ProductsArchiveService.php در سایت پشتیبانی می‌کنه
enum ProductSortOption: CaseIterable {
    case DEFAULT, LATEST, MOST_VIEWED, POPULAR, MOST_SALE, CHEAPEST, EXPENSIVE
}

struct ProductSortFilter: Equatable {
    var sort: ProductSortOption = .DEFAULT
    var onlyAvailable: Bool = false
    var onlyDiscounted: Bool = false
    // فیلترهای اختصاصیِ انتخاب‌شده - کلید = عنوان دقیق فیلتر، مقدار = مقدار انتخاب‌شده
    var dynamicFilters: [String: String] = [:]
}

/// معادل CatalogRepository اپ اندروید (data/CatalogRepository.kt) - همان پیام‌های خطا.
final class CatalogRepository {
    private static let NETWORK_ERROR = "خطا در اتصال به اینترنت."

    func getSiteInfo() async -> ApiResult<SiteInfoResponse> {
        do {
            let response = try await ApiService.getSiteInfo()
            if response.isSuccessful, let body = response.body {
                return .success(body)
            }
            return .error("دریافت اطلاعات سایت با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    // فاز ۳۱: نمادهای اعتماد پایین منوی همبرگری
    func getTrustSeals() async -> ApiResult<[TrustSealDto]> {
        do {
            let response = try await ApiService.getTrustSeals()
            if response.isSuccessful, let seals = response.body?.seals {
                return .success(seals)
            }
            return .error("دریافت نمادهای اعتماد با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    func getSocialLinks() async -> ApiResult<SocialLinksResponse> {
        do {
            let response = try await ApiService.getSocialLinks()
            if response.isSuccessful, let body = response.body {
                return .success(body)
            }
            return .error("دریافت لینک‌های شبکه‌های اجتماعی با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    // فاز ۱۷: بنرهای اسلایدر صفحه‌ی اصلی
    func getHomeSlider() async -> ApiResult<HomeSliderResponse> {
        do {
            let response = try await ApiService.getHomeSlider()
            if response.isSuccessful, let body = response.body {
                return .success(body)
            }
            return .error("دریافت بنرهای صفحه‌ی اصلی با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    func getCategories() async -> ApiResult<[CategoryDto]> {
        do {
            let response = try await ApiService.getCategories()
            if response.isSuccessful, let body = response.body {
                return .success(body.categories)
            }
            return .error("دریافت دسته‌بندی‌ها با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    func getProducts(
        page: Int = 1,
        category: String? = nil,
        search: String? = nil,
        cheapest: Bool = false,
        brand: String? = nil,
        sortFilter: ProductSortFilter = ProductSortFilter(),
        random: Bool = false
    ) async -> ApiResult<ProductsPage> {
        do {
            // فاز ۲۶ (اصلاحیه): دقیقاً همون فرمتی که خودِ اسکریپت انتظار داره - filters[عنوان فیلتر]=مقدار
            var dynamic: [String: String] = [:]
            for (title, value) in sortFilter.dynamicFilters where !value.isBlankShk {
                dynamic["filters[\(title)]"] = value
            }
            let sort = sortFilter.sort
            let response = try await ApiService.getProducts(
                page: page,
                category: category,
                search: search,
                cheapest: (cheapest || sort == .CHEAPEST) ? 1 : nil,
                brand: brand,
                latest: sort == .LATEST ? 1 : nil,
                mostViewed: sort == .MOST_VIEWED ? 1 : nil,
                popular: sort == .POPULAR ? 1 : nil,
                mostSale: sort == .MOST_SALE ? 1 : nil,
                expensive: sort == .EXPENSIVE ? 1 : nil,
                available: sortFilter.onlyAvailable ? 1 : nil,
                discount: sortFilter.onlyDiscounted ? 1 : nil,
                random: random ? 1 : nil,
                dynamicFilters: dynamic
            )
            if response.isSuccessful, let body = response.body {
                return .success(ProductsPage(
                    items: body.products,
                    pagination: body.pagination,
                    dynamicFilters: body.filters?.dynamics ?? []
                ))
            }
            return .error("دریافت محصولات با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    func getBrand(_ slug: String) async -> ApiResult<BrandDto> {
        do {
            let response = try await ApiService.getBrand(slug)
            if response.isSuccessful, let brand = response.body?.brand {
                return .success(brand)
            }
            return .error("دریافت اطلاعات برند با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    // فاز ۱۸: ماژول بنرهای ۴تایی صفحه‌ی اصلی
    func getHomeBanners() async -> ApiResult<HomeBannersResponse> {
        do {
            let response = try await ApiService.getHomeBanners()
            if response.isSuccessful, let body = response.body {
                return .success(body)
            }
            return .error("دریافت بنرهای صفحه‌ی اصلی با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    // فاز ۱۸ (درخواست بعدی): ماژول بنر دوتایی زیر کاروسل پیشنهاد شگفت‌انگیز
    func getHomeBanners2() async -> ApiResult<HomeBannersResponse> {
        do {
            let response = try await ApiService.getHomeBanners2()
            if response.isSuccessful, let body = response.body {
                return .success(body)
            }
            return .error("دریافت بنر صفحه‌ی اصلی با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    // ماژول «نخری بردن!» صفحه‌ی اصلی - محصولات موجودِ رو به اتمام
    func getLowStockProducts(limit: Int = 15) async -> ApiResult<[ProductListItemDto]> {
        do {
            let response = try await ApiService.getLowStockProducts(limit: limit)
            if response.isSuccessful, let body = response.body {
                return .success(body.products ?? [])
            }
            return .error("دریافت محصولات با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    // ماژول «آخرین محصولاتی که مشاهده کردید» - اطلاعات کارت محصولات به ترتیب slugهای ورودی
    func getProductsBySlugs(_ slugs: [String]) async -> ApiResult<[ProductListItemDto]> {
        if slugs.isEmpty { return .success([]) }
        do {
            let response = try await ApiService.getProductsBySlugs(slugs)
            if response.isSuccessful, let body = response.body {
                return .success(body.products ?? [])
            }
            return .error("دریافت محصولات با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    // «همین لحظه در سبد خرید دیگران» - کل فهرست (کاروسل ۱۰ تای اول رو نشون می‌ده)
    func getInCartsNow() async -> ApiResult<InCartsNowResponse> {
        do {
            let response = try await ApiService.getInCartsNow()
            if response.isSuccessful, let body = response.body {
                return .success(body)
            }
            return .error("دریافت محصولات با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    // رنگ‌های ماژول «پیشنهاد شگفت‌انگیز»
    func getHomeUi() async -> ApiResult<HomeUiResponse> {
        do {
            let response = try await ApiService.getHomeUi()
            if response.isSuccessful, let body = response.body {
                return .success(body)
            }
            return .error("دریافت تنظیمات صفحه‌ی اصلی با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    // پیشنهاد شگفت‌انگیز (همون ماژول قالب سایت)؛ خطا = سرور قدیمی‌تر از ۱.۷.۹ یا قطعی اینترنت
    func getHomeAmazingOffer() async -> ApiResult<AmazingOfferResponse> {
        do {
            let response = try await ApiService.getHomeAmazingOffer()
            if response.isSuccessful, let body = response.body, body.found != nil {
                return .success(body)
            }
            return .error("دریافت پیشنهاد شگفت‌انگیز با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    // استوری‌ها - فقط وقتی کلید سایت روشنه فهرست برمی‌گرده
    func getStories() async -> ApiResult<[StoryDto]> {
        do {
            let response = try await ApiService.getStories()
            if response.isSuccessful, let body = response.body {
                return .success(body.enabled == true ? (body.stories ?? []) : [])
            }
            return .error("دریافت استوری‌ها با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }

    func likeStory(_ id: Int) async -> ApiResult<StoryLikeResponse> {
        do {
            let response = try await ApiService.likeStory(id)
            if response.isSuccessful, let body = response.body {
                return .success(body)
            }
            return .error("ثبت لایک با خطا مواجه شد.")
        } catch {
            return .error(Self.NETWORK_ERROR)
        }
    }
}

extension ApiResult {
    /// معادل (result as? ApiResult.Success)?.data
    var successValue: T? {
        if case .success(let v) = self { return v }
        return nil
    }
}
