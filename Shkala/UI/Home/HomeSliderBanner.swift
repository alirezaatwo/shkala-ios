import SwiftUI

/// فاز ۱۷: بنر اسلایدر صفحه‌ی اصلی - دقیقاً همون داده‌ای که ماژول اسلایدر بنری قالب فعال سایت
/// (پنل ادمین > سازنده‌ی صفحه‌ی اصلی) داره.
///
/// چرخش خودکار هر ۷ ثانیه، دقیقاً هم‌زمان با تنظیم autoplay خود سایت (delay: 7000).
/// ۱.۶: [heightDp] = «ارتفاع اسلایدر موبایل» همین ماژول در ویرایشگر قالب سایت. null = نسبت ابعاد ۱۶:۵.۵
struct HomeSliderBanner: View {
    let slides: [HomeSlideDto]
    var heightDp: Int? = nil
    let onSlideClick: (HomeSlideDto) -> Void

    @Environment(\.shkColors) private var colors
    @State private var page: Int

    init(slides: [HomeSlideDto], heightDp: Int? = nil, onSlideClick: @escaping (HomeSlideDto) -> Void) {
        self.slides = slides
        self.heightDp = heightDp
        self.onSlideClick = onSlideClick
        // فاز ۲۲: حلقه‌ی بی‌نهایت - صفحه‌های مجازیِ خیلی زیاد که با % به اسلاید واقعی مپ می‌شن
        _page = State(initialValue: slides.count > 1 ? infiniteStartPage(slides.count) : 0)
    }

    var body: some View {
        if !slides.isEmpty {
            ZStack(alignment: .bottom) {
                ShkPager(
                    pageCount: slides.count > 1 ? INFINITE_PAGE_COUNT : 1,
                    currentPage: $page,
                    autoAdvanceSeconds: slides.count > 1 ? 7 : nil
                ) { p in
                    let slide = slides[p % slides.count]
                    sized(
                        RemoteImage(slide.image, contentDescription: slide.alt, contentScale: .crop)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { if !(slide.link?.isBlankShk ?? true) { onSlideClick(slide) } }
                }

                if slides.count > 1 {
                    HStack(spacing: 0) {
                        ForEach(slides.indices, id: \.self) { index in
                            let isSelected = page % slides.count == index
                            Circle()
                                .fill(isSelected ? colors.primary : colors.surface.opacity(0.6))
                                .frame(width: isSelected ? 8 : 6, height: isSelected ? 8 : 6)
                                .padding(.horizontal, 3)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func sized<V: View>(_ v: V) -> some View {
        if let heightDp, heightDp > 0 {
            v.frame(maxWidth: .infinity).frame(height: CGFloat(heightDp))
        } else {
            // فاز ۲۳: نسبت ابعاد ۱۶:۵.۵
            Color.clear.aspectRatio(16 / 5.5, contentMode: .fit).overlay(v)
        }
    }
}

/// تعداد صفحه‌ی مجازیِ اسلایدرهای حلقه‌ی بی‌نهایت (معادل Int.MAX_VALUE اندروید)
let INFINITE_PAGE_COUNT = Int(Int32.max)

/// صفحه‌ی شروعِ وسطِ صفحه‌های مجازی که با % دقیقاً به اسلاید اول مپ می‌شه
func infiniteStartPage(_ count: Int) -> Int {
    let middle = INFINITE_PAGE_COUNT / 2
    return middle - (middle % count)
}
