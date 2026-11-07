import SwiftUI
import AVFoundation

// ===================================================================================
// استوری‌های صفحه‌ی اصلی (HomeStories.kt اندروید) - شبیه‌سازی کامپوننت Stories.vue سایت:
//  - ردیف دایره‌ها: هر نما ۴ استوری، اگه کمتر از ۴ تا باشه وسط‌چین، حلقه‌ی گرادیان قرمز
//    (۳۱۵ درجه، قرمز → قرمز نیمه‌شفاف؛ تاریک: قرمز کامل) + کادر سفید ۳ پیکسلی، عنوان ۱۲ با «...»
//  - نمایشگر تمام‌صفحه با محو شدن ۰٫۲ ثانیه‌ای، جابه‌جایی محو بین استوری‌ها، نوارهای پیشرفت
//    بالا (قابل لمس)، سربرگ (کاور، عنوان، زمان، پخش/توقف، بستن)، سایه‌ی بالا و پایین، لایک و صدا
//    (سمت چپ)، دکمه‌ی لینک و کارت محصول
//  - تصویر: پخش خودکار ۶ ثانیه (پیشرفت ۱٪ هر ۶۰ میلی‌ثانیه)، بعد استوری بعدی؛ بعد از آخری اولی
//  - ویدیو: پخش با صدا، پیشرفت = زمان ویدیو، پایان = استوری بعدی (آخری همون‌جا می‌مونه)
//  - لمس روی خود تصویر/ویدیو = قطع/وصل صدا؛ کشیدن افقی = استوری بعد/قبل (مثل swiper-rtl)
// ===================================================================================

private let StoryDark = Color(argb: 0xFF1C1C25)
private let StoryDanger = Color(argb: 0xFFFA4248)
private let STORY_IMAGE_STEP_NS: UInt64 = 60_000_000
private let STORY_IMAGE_STEPS = 100

/// ردیف دایره‌های استوری - بین خط‌چین هدر و اسلایدر اصلی
struct HomeStoriesBar: View {
    let stories: [StoryDto]
    let onOpen: (Int) -> Void
    @State private var width: CGFloat = 0

    var body: some View {
        let itemWidth = width / 4
        Group {
            if stories.count < 4 {
                // مثل کلاس centered سایت: وقتی کل استوری‌ها در یک نما جا می‌شن، وسط‌چین
                HStack(spacing: 0) {
                    ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                        StoryBarItem(story: story, width: itemWidth) { onOpen(index) }
                    }
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                            StoryBarItem(story: story, width: itemWidth) { onOpen(index) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(GeometryReader { g in
            Color.clear.onAppear { width = g.size.width }.onChange(of: g.size.width) { width = $0 }
        })
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

private struct StoryBarItem: View {
    let story: StoryDto
    let width: CGFloat
    let onClick: () -> Void
    @Environment(\.shkColors) private var colors
    private let ringSize: CGFloat = 74

    var body: some View {
        VStack(spacing: 0) {
            StoryRing(coverUrl: story.cover, title: story.title, size: ringSize)
            Spacer().frame(height: 8)
            Text(story.title ?? "")
                .shkFont(12, lineHeight: 18)
                .foregroundColor(colors.onBackground)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
                .frame(width: ringSize)
        }
        .frame(width: max(width, ringSize))
        .contentShape(Rectangle())
        .onTapGesture(perform: onClick)
    }
}

/// حلقه‌ی گرادیان دور کاور (.story-cover سایت)
private struct StoryRing: View {
    let coverUrl: String?
    let title: String?
    let size: CGFloat
    @Environment(\.shkColors) private var colors
    @Environment(\.shkIsDark) private var isDark

    var body: some View {
        let inner = isDark ? ShkColors.DarkBackground : Color.white
        // linear-gradient(315deg, primary, primary/0.5): از پایین-راست به بالا-چپ
        ZStack {
            Circle().fill(LinearGradient(
                colors: [colors.primary, colors.primary.opacity(isDark ? 1 : 0.5)],
                startPoint: .bottomTrailing, endPoint: .topLeading
            ))
            Circle().fill(inner).padding(2)
            RemoteImage(coverUrl, contentDescription: title, contentScale: .crop)
                .clipShape(Circle())
                .padding(5)
        }
        .frame(width: size, height: size)
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - نمایشگر تمام‌صفحه

/// نمایشگر تمام‌صفحه‌ی استوری‌ها (.show-story سایت در موبایل). [stories] همیشه فهرست فعلی
/// صفحه‌ی اصلیه تا لایک‌ها همین‌جا به‌روز بشن.
struct StoryViewer: View {
    let stories: [StoryDto]
    let startIndex: Int
    let onDismiss: () -> Void
    let onLike: (Int) -> Void
    let onOpenProduct: (String) -> Void
    let onOpenLink: (String) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var index: Int
    // باز و بسته شدن: محو ۰٫۲ ثانیه‌ای (transition: all ease .2s سایت)
    @State private var shown = false
    @State private var closing = false
    // وضعیت پخش (مثل متغیرهای Stories.vue): بی‌صدا، پخش خودکار تصویر، پخش ویدیو، درصد نوار فعال
    @State private var muted = false
    @State private var imageAutoplay = false
    @State private var imageStep = 0
    @State private var videoPaused = false
    @State private var videoPlaying = false
    @State private var videoProgress: Double = 0

    init(stories: [StoryDto], startIndex: Int, onDismiss: @escaping () -> Void, onLike: @escaping (Int) -> Void,
         onOpenProduct: @escaping (String) -> Void, onOpenLink: @escaping (String) -> Void) {
        self.stories = stories
        self.startIndex = startIndex
        self.onDismiss = onDismiss
        self.onLike = onLike
        self.onOpenProduct = onOpenProduct
        self.onOpenLink = onOpenLink
        _index = State(initialValue: min(max(startIndex, 0), max(stories.count - 1, 0)))
    }

    private var safeIndex: Int { min(max(index, 0), max(stories.count - 1, 0)) }
    // اپ به پس‌زمینه رفت: ویدیو و شمارش تصویر متوقف می‌شه (بدون صفر شدن)
    private var appActive: Bool { scenePhase == .active }

    var body: some View {
        ZStack(alignment: .top) {
            StoryDark.ignoresSafeArea()
            if !stories.isEmpty {
                let story = stories[safeIndex]
                ZStack {
                    StoryPage(
                        story: story,
                        active: true,
                        muted: muted,
                        imagePlaying: imageAutoplay,
                        videoPlaying: videoPlaying,
                        videoPaused: videoPaused || !appActive,
                        onToggleMute: { muted.toggle() },
                        onTogglePlay: {
                            if story.isVideo {
                                videoPaused = videoPlaying
                            } else {
                                // مثل O() سایت: توقف = نوار صفر، پخش = از اول
                                imageStep = 0
                                imageAutoplay.toggle()
                            }
                        },
                        onClose: { requestClose(nil) },
                        onSwipe: { towardNext in towardNext ? goNext() : goPrev() },
                        onVideoPlayingChange: { videoPlaying = $0 },
                        onVideoProgress: { videoProgress = $0 },
                        onVideoEnded: { goNext() },
                        onLike: { onLike(story.id) },
                        onOpenProduct: { slug in requestClose { onOpenProduct(slug) } },
                        onOpenLink: { url in requestClose { onOpenLink(url) } }
                    )
                    .id(story.id)
                    .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.3), value: safeIndex)

                progressBars(story: story)
            }
        }
        .opacity(shown && !closing ? 1 : 0)
        .animation(.easeInOut(duration: 0.2), value: shown && !closing)
        .onAppear { shown = true }
        .onChange(of: stories.isEmpty) { empty in if empty { onDismiss() } }
        // هر بار استوری عوض می‌شه: صدا وصل، نوار از صفر، تصویر = شروع پخش خودکار، ویدیو = پخش از اول
        .task(id: stories.isEmpty ? -1 : stories[safeIndex].id) {
            guard !stories.isEmpty else { return }
            muted = false
            imageStep = 0
            videoProgress = 0
            videoPlaying = false
            videoPaused = false
            imageAutoplay = !stories[safeIndex].isVideo
        }
        // پخش خودکار تصویر: ۱٪ هر ۶۰ میلی‌ثانیه؛ بعد از ۶ ثانیه استوری بعدی (بعد از آخری، اولی)
        .task(id: AutoplayKey(storyId: stories.isEmpty ? -1 : stories[safeIndex].id, autoplay: imageAutoplay, active: appActive)) {
            guard !stories.isEmpty, !stories[safeIndex].isVideo, imageAutoplay, appActive else { return }
            while imageStep < STORY_IMAGE_STEPS {
                try? await Task.sleep(nanoseconds: STORY_IMAGE_STEP_NS)
                if Task.isCancelled { return }
                imageStep += 1
            }
            index = safeIndex + 1 < stories.count ? safeIndex + 1 : 0
        }
        .statusBarHidden(false)
    }

    private struct AutoplayKey: Equatable { let storyId: Int; let autoplay: Bool; let active: Bool }

    private func goNext() { if safeIndex + 1 < stories.count { index = safeIndex + 1 } }
    private func goPrev() { if safeIndex > 0 { index = safeIndex - 1 } }

    private func requestClose(_ action: (() -> Void)?) {
        if closing { return }
        closing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
            action?()
        }
    }

    /// نوارهای پیشرفت بالای صفحه (.story-pagination) - هر نوار قابل لمس
    private func progressBars(story: StoryDto) -> some View {
        let activeProgress = story.isVideo ? videoProgress : Double(imageStep) / Double(STORY_IMAGE_STEPS)
        return HStack(spacing: 3) {
            ForEach(stories.indices, id: \.self) { i in
                let fill: Double = i < safeIndex ? 1 : (i == safeIndex ? min(max(activeProgress, 0), 1) : 0)
                // پر شدن از سمت راست (شروع نوار در اپ راست‌به‌چپ) - مثل span سایت با right:0
                GeometryReader { g in
                    ZStack(alignment: .trailing) {
                        Color.white.opacity(0.4)
                        Color.white.frame(width: g.size.width * fill)
                    }
                    .frame(width: g.size.width, height: 2)
                    .clipShape(Capsule())
                    .frame(height: g.size.height)
                }
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity)
                .frame(height: 16)
                .contentShape(Rectangle())
                .onTapGesture { index = i }
            }
        }
        .padding(.horizontal, 15)
        .padding(.top, 5)
    }
}

/// یک استوری (.story-data سایت)
private struct StoryPage: View {
    let story: StoryDto
    let active: Bool
    let muted: Bool
    let imagePlaying: Bool
    let videoPlaying: Bool
    let videoPaused: Bool
    let onToggleMute: () -> Void
    let onTogglePlay: () -> Void
    let onClose: () -> Void
    let onSwipe: (Bool) -> Void
    let onVideoPlayingChange: (Bool) -> Void
    let onVideoProgress: (Double) -> Void
    let onVideoEnded: () -> Void
    let onLike: () -> Void
    let onOpenProduct: (String) -> Void
    let onOpenLink: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            let hasProduct = story.product != nil
            // story-meta و لینک: ۸٪ از پایین، و اگه کارت محصول هست ۱۵٪
            let widgetsBottom = geo.size.height * (hasProduct ? 0.15 : 0.08)
            ZStack {
                StoryDark
                // رسانه + لایه‌ی لمس (cover-data سایت: لمس = قطع/وصل صدا) + کشیدن افقی
                ZStack {
                    if story.isVideo, let file = story.file, !file.isBlankShk {
                        StoryVideoPlayer(
                            url: file, active: active, paused: videoPaused, muted: muted,
                            onPlayingChange: onVideoPlayingChange, onProgress: onVideoProgress, onEnded: onVideoEnded
                        )
                    } else if !story.isVideo {
                        RemoteImage(story.file, contentDescription: story.title, contentScale: .crop)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleMute)
                .gesture(
                    DragGesture(minimumDistance: 20).onEnded { value in
                        // swiper-rtl: کشیدن انگشت به راست = استوری بعدی، به چپ = قبلی
                        let dx = value.translation.width
                        if dx > 60 { onSwipe(true) } else if dx < -60 { onSwipe(false) }
                    }
                )

                // سایه‌ی مشکی بالا (۱۵٪) و پایین (۳۰٪)
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: geo.size.height * 0.15)
                    Spacer()
                    LinearGradient(colors: [.clear, Color.black.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                        .frame(height: geo.size.height * 0.3)
                }
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    header
                    Spacer()
                }

                // لایک و صدا (سمت چپ - story-meta سایت)
                if !(story.file?.isBlankShk ?? true) {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            likeColumn
                        }
                        .padding(.trailing, 15)
                        .padding(.bottom, widgetsBottom)
                    }
                }

                // دکمه‌ی لینک (فقط وقتی عنوان و آدرس هر دو پر باشن)
                if let linkTitle = story.link?.title, !linkTitle.isBlankShk,
                   let linkUrl = story.link?.url, !linkUrl.isBlankShk {
                    VStack {
                        Spacer()
                        Button { onOpenLink(linkUrl) } label: {
                            HStack(spacing: 5) {
                                Text(linkTitle).shkFont(13).foregroundColor(StoryDark).lineLimit(1)
                                RemixIcon(RemixIcons.LinkM, tint: StoryDark, size: 18)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                            .materialShadow(2)
                        }
                        .buttonStyle(SitePressStyle())
                        .padding(.bottom, widgetsBottom)
                    }
                }

                // کارت محصول (پایین صفحه)
                if let product = story.product {
                    VStack {
                        Spacer()
                        StoryProductCard(product: product) { onOpenProduct(product.slug) }
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                    }
                }
            }
        }
    }

    /// سربرگ: کاور، عنوان و زمان (راست) + پخش/توقف و بستن (چپ)
    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    Color(argb: 0xFFEEEFF1)
                    RemoteImage(story.cover, contentDescription: story.title, contentScale: .crop)
                }
                .frame(width: 24, height: 24)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                Text(story.title ?? "")
                    .shkFont(12)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 110, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, 8)
                Text((story.createdAgo ?? "").toPersianDigits())
                    .shkFont(10)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.leading, 8)
                Spacer(minLength: 0)
            }
            let playing = story.isVideo ? videoPlaying : imagePlaying
            StoryHeaderButton(icon: playing ? RemixIcons.PauseMiniLine : RemixIcons.PlayFill, contentDescription: playing ? "توقف" : "پخش", onClick: onTogglePlay)
            Spacer().frame(width: 5)
            StoryHeaderButton(icon: RemixIcons.CloseLine, contentDescription: "بستن", onClick: onClose)
        }
        .padding(.leading, 18)
        .padding(.trailing, 15)
        .padding(.top, 25)
    }

    private var likeColumn: some View {
        let liked = story.isLiked == true
        return VStack(spacing: 0) {
            VStack(spacing: 4) {
                RemixIcon(liked ? RemixIcons.HeartFill : RemixIcons.HeartLine, contentDescription: "لایک", tint: liked ? StoryDanger : .white, size: 22)
                Text(formatTomanFa(Int64(story.like ?? 0)))
                    .shkFont(12, .bold)
                    .foregroundColor(.white)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onLike)
            if story.isVideo {
                Spacer().frame(height: 15)
                RemixIcon(muted ? RemixIcons.VolumeMuteLine : RemixIcons.VolumeUpLine, contentDescription: muted ? "وصل صدا" : "قطع صدا", tint: .white, size: 20)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onToggleMute)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.2)))
    }
}

/// دکمه‌های سربرگ نمایشگر (۲۶×۲۶، پس‌زمینه‌ی مشکی ۲۰٪، گوشه‌ی ۸)
private struct StoryHeaderButton: View {
    let icon: String
    let contentDescription: String
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            RemixIcon(icon, contentDescription: contentDescription, tint: .white, size: 16)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black.opacity(0.2)))
        }
        .buttonStyle(SitePressStyle())
    }
}

/// کارت محصول داخل استوری (.story-product سایت) - همیشه سفید، حتی در حالت تاریک
private struct StoryProductCard: View {
    let product: ProductListItemDto
    let onClick: () -> Void

    var body: some View {
        let inStock = product.inStockStatus != false
        let price = product.bestNormalPrice
        let showDiscount = inStock && product.inventory && !(price?.discountPrice?.isBlankShk ?? true)
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                ZStack {
                    Color(argb: 0xFFF0F3F8)
                    RemoteImage(product.mainImageUrl, contentDescription: product.title, contentScale: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(5)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text(product.title)
                        .shkFont(13, lineHeight: 15)
                        .foregroundColor(StoryDark)
                        .lineLimit(1)
                        .padding(.trailing, 35)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer().frame(height: 10)
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        // امتیاز (بدون امتیاز = «-» مثل سایت)
                        let rating = product.commentsInfo?.rating.flatMap { $0 > 0 ? $0 : nil }
                        RemixIcon(RemixIcons.StarFill, tint: Color(argb: 0xFFF0BB40), size: 11)
                        Spacer().frame(width: 4)
                        Text(rating.map(formatRating) ?? "-").shkFont(13, .bold).foregroundColor(StoryDark)
                        Rectangle().fill(Color(argb: 0xFFE9ECF1)).frame(width: 1, height: 12).padding(.horizontal, 8)
                        Text(priceText(inStock: inStock, price: price))
                            .shkFont(inStock && product.inventory ? 14 : 12, .bold)
                            .foregroundColor(StoryDark)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 5)
            }
            .padding(6)

            // درصد تخفیف (گوشه‌ی بالا-چپ کارت)
            if showDiscount, let percent = price?.percent {
                HStack(spacing: 2) {
                    Text(percent.toPersianDigits()).shkFont(11, .bold, lineHeight: 15).foregroundColor(.white)
                    RemixIcon(RemixIcons.PercentFill, tint: StoryDark, size: 10)
                }
                .padding(.leading, 6)
                .padding(.trailing, 6)
                .padding(.top, 3)
                .padding(.bottom, 2)
                .background(StoryDanger)
                .clipShape(StoryBadgeShape())
                .padding(.top, 10)
                .padding(.trailing, 5)
            }
        }
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(perform: onClick)
    }

    private func priceText(inStock: Bool, price: BestNormalPriceDto?) -> String {
        if !inStock { return "استعلام موجودی" }
        if !product.inventory { return "ناموجود" }
        if let d = price?.discountPrice, !d.isBlankShk { return "\(d.toPersianDigits()) تومان" }
        if let p = price?.price, !p.isBlankShk { return "\(p.toPersianDigits()) تومان" }
        return "-"
    }
}

/// گوشه‌های بج تخفیف: بالا ۱۲، پایین-انتها ۴، پایین-شروع ۱۲ (در RTL: پایین-چپ ۴)
private struct StoryBadgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        // در چیدمان راست‌به‌چپ «end» = چپ: گوشه‌ی پایین-چپ ۴، بقیه ۱۲
        let r: CGFloat = 12, small: CGFloat = 4
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + small, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + small, y: rect.maxY - small), radius: small, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private func formatRating(_ value: Double) -> String {
    let text = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    return text.toPersianDigits()
}

// MARK: - پخش ویدیو

/// پخش ویدیوی استوری با AVPlayer خود iOS؛ تصویر مثل object-fit: cover سایت کل صفحه رو پر می‌کنه
private struct StoryVideoPlayer: UIViewRepresentable {
    let url: String
    let active: Bool
    let paused: Bool
    let muted: Bool
    let onPlayingChange: (Bool) -> Void
    let onProgress: (Double) -> Void
    let onEnded: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        if let u = URL(string: url) {
            let player = AVPlayer(url: u)
            view.playerLayer.player = player
            view.playerLayer.videoGravity = .resizeAspectFill
            context.coordinator.attach(player)
        }
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        let c = context.coordinator
        c.onPlayingChange = onPlayingChange
        c.onProgress = onProgress
        c.onEnded = onEnded
        c.player?.isMuted = muted
        c.setPlaying(active && !paused)
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: Coordinator) {
        coordinator.release()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    final class Coordinator {
        var player: AVPlayer? = nil
        var onPlayingChange: (Bool) -> Void = { _ in }
        var onProgress: (Double) -> Void = { _ in }
        var onEnded: () -> Void = {}
        private var timeObserver: Any? = nil
        private var endObserver: NSObjectProtocol? = nil
        private var isPlaying = false

        func attach(_ player: AVPlayer) {
            self.player = player
            timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 10), queue: .main) { [weak self] time in
                guard let self, let item = player.currentItem else { return }
                let duration = item.duration.seconds
                self.onProgress(duration.isFinite && duration > 0 ? time.seconds / duration : 0)
                let playing = player.timeControlStatus == .playing
                if playing != self.isPlaying {
                    self.isPlaying = playing
                    self.onPlayingChange(playing)
                }
            }
            endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { [weak self] _ in
                self?.isPlaying = false
                self?.onPlayingChange(false)
                self?.onEnded()
            }
        }

        func setPlaying(_ play: Bool) {
            guard let player else { return }
            if play && player.rate == 0 { player.play() } else if !play && player.rate != 0 { player.pause() }
        }

        func release() {
            if let timeObserver { player?.removeTimeObserver(timeObserver) }
            if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
            timeObserver = nil
            endObserver = nil
            player?.pause()
            player = nil
        }
    }
}

/// پس‌زمینه‌ی شفافِ صفحه‌ی تمام‌صفحه (تا محو شدن نمایشگر استوری روی خود اپ دیده بشه، مثل Dialog اندروید)
struct ClearFullScreenBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async { view.superview?.superview?.backgroundColor = .clear }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
