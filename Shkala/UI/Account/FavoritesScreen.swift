import SwiftUI

// ===================================================================================
// معادل ui/account/FavoritesScreen.kt
// ===================================================================================

/**
 * علاقه‌مندی‌های من - نوار بالا با دکمه‌ی برگشت کادردار، باکس جستجو، شبکه‌ی دوستونه‌ی کارت محصول
 * (تصویر گوشه‌گرد، عنوان، قیمت) با دکمه‌ی قلب برای حذف، و حالت خالیِ طراحی‌شده.
 */
struct FavoritesScreen: View {
    let onBack: () -> Void
    let onOpenProduct: (String) -> Void
    @Environment(\.shkColors) private var colors
    private let repository = FavoriteRepository()

    @State private var searchText = ""
    @State private var favorites: [FavoriteDto] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    private var query: String? {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? nil : q
    }

    private func load() async {
        switch await repository.getFavorites(search: query) {
        case .success(let data):
            favorites = data
            errorMessage = nil
        case .error(let message):
            errorMessage = message
        }
        isLoading = false
    }

    // بروزرسانی با کشیدن صفحه: محتوای فعلی حفظ می‌شه و خطا فقط با توست نشون داده می‌شه
    private func refresh() async {
        switch await repository.getFavorites(search: query) {
        case .success(let data):
            favorites = data
            errorMessage = nil
        case .error(let message):
            ShkToast.shared.show(message)
        }
    }

    private func remove(_ favorite: FavoriteDto) {
        Task {
            switch await repository.toggleFavorite(favorite.product.id) {
            case .success:
                favorites = favorites.filter { $0.product.id != favorite.product.id }
                ShkToast.shared.show("از علاقه‌مندی‌ها حذف شد.")
            case .error(let message):
                ShkToast.shared.show(message)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(
                title: "علاقه‌مندی‌های من",
                onBack: onBack,
                subtitle: (!isLoading && errorMessage == nil && !favorites.isEmpty) ? "\(favorites.count.toPersianDigits()) محصول" : nil
            )
            SiteSearchField(value: $searchText, placeholder: "جستجو بین علاقه‌مندی‌ها...")
                .padding(.horizontal, 16)
            Spacer().frame(height: 4)

            Group {
                if isLoading {
                    SiteLoading(message: "در حال دریافت علاقه‌مندی‌ها", icon: RemixIcons.HeartLine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    // حالت خطا/خالی هم با کشیدن صفحه دوباره بارگذاری می‌شه
                    ScrollView {
                        SiteEmptyState(icon: RemixIcons.WifiOffLine, title: "دریافت علاقه‌مندی‌ها ممکن نشد", subtitle: errorMessage)
                            .padding(16)
                    }
                    .sitePullRefresh { await load() }
                } else if favorites.isEmpty {
                    ScrollView {
                        SiteEmptyState(
                            icon: RemixIcons.HeartLine,
                            title: "علاقه‌مندی‌ای پیدا نشد",
                            subtitle: searchText.isBlankShk
                                ? "با زدن آیکن قلب در صفحه‌ی هر محصول، آن را به این فهرست اضافه کنید."
                                : "با عبارت دیگری جستجو کنید."
                        )
                        .padding(16)
                    }
                    .sitePullRefresh { await refresh() }
                } else {
                    // کشیدن صفحه به پایین برای بروزرسانی علاقه‌مندی‌ها
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .top), GridItem(.flexible(), spacing: 10, alignment: .top)], spacing: 10) {
                            // شناسه‌ی علاقه‌مندی در سرورهای قدیمی همیشه null (=0) بود؛ کلید = شناسه‌ی محصول
                            ForEach(uniqueByProduct(favorites), id: \.product.id) { favorite in
                                FavoriteCard(
                                    favorite: favorite,
                                    onClick: { onOpenProduct(favorite.product.slug) },
                                    onRemove: { remove(favorite) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .sitePullRefresh { await refresh() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.background.ignoresSafeArea())
        // جستجو با تأخیر ۳۵۰ میلی‌ثانیه (همون LaunchedEffect(searchText) + delay اندروید)
        .task(id: searchText) {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            isLoading = true
            await load()
        }
    }

    private func uniqueByProduct(_ list: [FavoriteDto]) -> [FavoriteDto] {
        var seen = Set<Int>()
        return list.filter { seen.insert($0.product.id).inserted }
    }
}

private struct FavoriteCard: View {
    let favorite: FavoriteDto
    let onClick: () -> Void
    let onRemove: () -> Void
    @Environment(\.shkColors) private var colors

    var body: some View {
        SiteCard(onClick: onClick, contentPadding: .all(10)) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(colors.surfaceVariant)
                .overlay { RemoteImage(favorite.product.mainImageUrl, contentDescription: favorite.product.title, contentScale: .crop) }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                // دکمه‌ی حذف از علاقه‌مندی‌ها (قلب پُر)
                .overlay(alignment: .topTrailing) {
                    Button(action: onRemove) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(colors.surface)
                                .shadow(color: .black.opacity(0.15), radius: 1.5, x: 0, y: 1)
                            RemixIcon(RemixIcons.HeartFill, contentDescription: "حذف از علاقه‌مندی‌ها", tint: colors.primary, size: 18)
                        }
                        .frame(width: 32, height: 32)
                    }
                    .buttonStyle(SitePressStyle())
                    .padding(6)
                }
            Spacer().frame(height: 8)
            Text(favorite.product.title)
                .shkFont(12, .medium, lineHeight: 19)
                .foregroundColor(colors.onSurface)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: 38, alignment: .top)
            Spacer().frame(height: 6)
            if let price = favorite.product.bestPrice {
                Text("\(formatTomanFa(Int64(price))) تومان")
                    .shkFont(13, .bold)
                    .foregroundColor(colors.primary)
                    .lineLimit(1)
            } else {
                Spacer().frame(height: 18)
            }
        }
    }
}
