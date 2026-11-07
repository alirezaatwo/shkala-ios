import SwiftUI
import Photos

/**
 * معادل ui/common/ImageLightbox.kt: نمایش تمام‌صفحه‌ی عکس‌های محصول - قابل swipe بین عکس‌ها (حلقه‌ی
 * بی‌نهایت)، قابل زوم با دو انگشت و دابل‌تپ، و دکمه‌ی ذخیره در گالری گوشی.
 */
struct ImageLightbox: View {
    let imageUrls: [String]
    let initialPage: Int
    let onDismiss: () -> Void
    // فاز PA: مثل صفحه‌ی وب محصول - «تصاویر رسمی» + «تصاویر خریداران» در یک اسلایدر پشت سر هم
    var buyerImageUrls: [String] = []
    var showImageSetTabs: Bool = false

    @State private var page: Int = 0
    @State private var didInit = false
    @State private var isZoomed = false

    /// تعداد دورهای حلقه‌ی لایت‌باکس (عملاً بی‌نهایت برای کاربر)
    private static let LIGHTBOX_LOOP_CYCLES = 2000

    private var allUrls: [String] { showImageSetTabs ? imageUrls + buyerImageUrls : imageUrls }
    private var realCount: Int { allUrls.count }
    private var loop: Bool { realCount > 1 }
    private func realIndex(_ p: Int) -> Int { realCount == 0 ? 0 : ((p % realCount) + realCount) % realCount }

    var body: some View {
        let officialCount = imageUrls.count
        let currentReal = realIndex(page)
        // دسته‌ی فعلی: تصاویر رسمی یا تصاویر خریداران
        let isBuyerSet = showImageSetTabs && currentReal >= officialCount
        let setSize = isBuyerSet ? buyerImageUrls.count : officialCount
        let indexInSet = isBuyerSet ? currentReal - officialCount : currentReal

        ZStack {
            Color.black.ignoresSafeArea()
            if realCount > 0 {
                ShkPager(
                    pageCount: loop ? realCount * Self.LIGHTBOX_LOOP_CYCLES : realCount,
                    currentPage: $page,
                    swipeEnabled: !isZoomed
                ) { p in
                    ZoomableImage(url: allUrls[realIndex(p)], isZoomed: p == page ? $isZoomed : .constant(false))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                HStack {
                    // بازطراحی: دکمه‌های کادردارِ نیمه‌شفاف با آیکن Remix
                    LightboxActionButton(icon: RemixIcons.CloseLine, contentDescription: "بستن", onClick: onDismiss)
                    Spacer()
                    LightboxActionButton(icon: RemixIcons.Download2Line, contentDescription: "ذخیره در گالری") {
                        if currentReal < allUrls.count { saveImageToGallery(allUrls[currentReal]) }
                    }
                }
                .padding(16)

                // تب‌های «تصاویر رسمی» / «تصاویر خریداران» (تب دوم فقط وقتی تصویر خریدار وجود داره)
                if showImageSetTabs {
                    HStack(spacing: 4) {
                        LightboxSetTab(text: "تصاویر رسمی", selected: !isBuyerSet) {
                            withAnimation(.easeInOut(duration: 0.3)) { page = page - realIndex(page) + 0 }
                        }
                        if !buyerImageUrls.isEmpty {
                            LightboxSetTab(text: "تصاویر خریداران (\(buyerImageUrls.count.toPersianDigits()))", selected: isBuyerSet) {
                                withAnimation(.easeInOut(duration: 0.3)) { page = page - realIndex(page) + officialCount }
                            }
                        }
                    }
                    .padding(4)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
                    // ۷۰ از بالای صفحه (زیر دکمه‌های بستن/ذخیره تا روی هم نیفتن)
                    .padding(.top, -4)
                }
                Spacer()
                // شماره‌ی عکس فعلی (مثلاً ۲ / ۵)
                if setSize > 1 {
                    Text("\((indexInSet + 1).toPersianDigits()) / \(setSize.toPersianDigits())")
                        .shkFont(12, .bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.16)))
                        .padding(.bottom, 28)
                }
            }
        }
        .overlay(ShkToastHost())
        .onAppear {
            if didInit { return }
            didInit = true
            let start = min(max(initialPage, 0), max(realCount - 1, 0))
            page = loop ? realCount * (Self.LIGHTBOX_LOOP_CYCLES / 2) + start : start
        }
    }

    private func saveImageToGallery(_ url: String) {
        Task {
            guard let image = await ShkImageLoader.shared.load(url) else {
                ShkToast.shared.show("خطا در دریافت عکس")
                return
            }
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                ShkToast.shared.show("ذخیره‌سازی ناموفق بود")
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                ShkToast.shared.show("عکس ذخیره شد")
            } catch {
                ShkToast.shared.show("خطا در ذخیره‌سازی عکس")
            }
        }
    }
}

/// فاز PA: تب قرصیِ انتخاب دسته‌ی تصاویر روی زمینه‌ی مشکی لایت‌باکس
private struct LightboxSetTab: View {
    let text: String
    let selected: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            Text(text)
                .shkFont(12, .bold)
                .foregroundColor(selected ? Color(argb: 0xFF111111) : .white)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(selected ? Color.white : Color.clear))
                .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .buttonStyle(SitePressStyle())
    }
}

/// دکمه‌ی آیکنیِ کادردارِ نیمه‌شفاف روی زمینه‌ی مشکی لایت‌باکس
private struct LightboxActionButton: View {
    let icon: String
    let contentDescription: String
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.16))
                RemixIcon(icon, contentDescription: contentDescription, tint: .white, size: 22)
            }
            .frame(width: 42, height: 42)
        }
        .buttonStyle(SitePressStyle())
    }
}

/// عکس قابل زوم: دو انگشت (۱ تا ۵ برابر)، جابه‌جایی عکسِ زوم‌شده، و دابل‌تپ (۲.۵ برابر حول نقطه‌ی لمس)
private struct ZoomableImage: View {
    let url: String
    @Binding var isZoomed: Bool

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var size: CGSize = .zero

    var body: some View {
        RemoteImage(url, contentScale: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(scale)
            .offset(offset)
            .background(GeometryReader { g in Color.clear.onAppear { size = g.size } })
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture(count: 2).onEnded { tap in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if scale > 1 {
                            // دابل‌تپ دوم: با انیمیشن نرم برگرد به حالت عادی
                            setScale(1, .zero)
                        } else {
                            // دابل‌تپ اول: زوم دقیقاً حول همون نقطه‌ی لمس‌شده
                            let s: CGFloat = 2.5
                            let dx = tap.location.x - size.width / 2
                            let dy = tap.location.y - size.height / 2
                            setScale(s, clamped(s, CGSize(width: -dx * (s - 1), height: -dy * (s - 1))))
                        }
                    }
                }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let s = min(max(baseScale * value, 1), 5)
                        scale = s
                        offset = s > 1 ? clamped(s, offset) : .zero
                        isZoomed = s > 1
                    }
                    .onEnded { _ in
                        baseScale = scale
                        baseOffset = offset
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // فقط وقتی عکس زوم شده، حرکت تک‌انگشتی عکس رو جابه‌جا می‌کنه؛ در حالت عادی به پیجر می‌رسه
                        guard scale > 1 else { return }
                        offset = clamped(scale, CGSize(width: baseOffset.width + value.translation.width, height: baseOffset.height + value.translation.height))
                    }
                    .onEnded { _ in baseOffset = offset },
                including: scale > 1 ? .all : .subviews
            )
    }

    private func setScale(_ s: CGFloat, _ o: CGSize) {
        scale = s; baseScale = s
        offset = o; baseOffset = o
        isZoomed = s > 1
    }

    private func clamped(_ s: CGFloat, _ o: CGSize) -> CGSize {
        let maxX = max(0, size.width * (s - 1) / 2)
        let maxY = max(0, size.height * (s - 1) / 2)
        return CGSize(width: min(max(o.width, -maxX), maxX), height: min(max(o.height, -maxY), maxY))
    }
}
