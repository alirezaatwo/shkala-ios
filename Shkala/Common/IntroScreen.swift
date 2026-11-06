import SwiftUI
import UIKit

/// هر اسلاید: تصویر طراحی‌شده + رنگ شاخص همون اسلاید (برای نشانگر و دکمه)
private struct IntroSlide {
    let image: String
    let accent: UInt32
}

private let introSlides: [IntroSlide] = [
    IntroSlide(image: "intro_slide_1", accent: 0xFFE30613), // محصولات نظارتی - قرمز
    IntroSlide(image: "intro_slide_2", accent: 0xFF1E5BFF), // محصولات شبکه - آبی
    IntroSlide(image: "intro_slide_3", accent: 0xFF8A2BE2), // ذخیره‌سازها - بنفش
    IntroSlide(image: "intro_slide_4", accent: 0xFFC2A800), // سیستم‌های امنیتی - زرد
    IntroSlide(image: "intro_slide_5", accent: 0xFF12A83A), // انرژی خورشیدی - سبز
    IntroSlide(image: "intro_slide_6", accent: 0xFF0AA5B4), // گیت ضد سرقت - فیروزه‌ای
]

/// رنگ بین دو رنگ ARGB (معادل lerp(Color, Color, f) اندروید)
private func lerpColor(_ a: UInt32, _ b: UInt32, _ f: CGFloat) -> Color {
    func comp(_ c: UInt32, _ shift: UInt32) -> CGFloat { CGFloat((c >> shift) & 0xFF) / 255 }
    let t = min(max(f, 0), 1)
    func mix(_ shift: UInt32) -> CGFloat { comp(a, shift) + (comp(b, shift) - comp(a, shift)) * t }
    return Color(.sRGB, red: mix(16), green: mix(8), blue: mix(0), opacity: mix(24))
}

/// اینترو اسلایدی - فقط یه‌بار (اولین باری که اپ نصب/باز می‌شه) نمایش داده می‌شه.
/// معادل IntroScreen.kt اپ اندروید: اسلاید افقی، نوار کنترل شناور پایین (رد کردن، نشانگر
/// قرصی، دکمه‌ی بعدی با حلقه‌ی پیشرفت) که رنگش به‌نرمی با رنگ هر اسلاید عوض می‌شه، و در
/// اسلاید آخر دکمه به «شروع کنید» تبدیل می‌شه.
struct IntroScreen: View {
    let onFinish: () -> Void
    /// برای عکس‌برداری خودکار: شروع از یک اسلاید مشخص
    var initialPage: Int = 0

    @Environment(\.shkColors) private var colors
    @State private var position: CGFloat = 0     // صفحه‌ی جاری + کسر جابه‌جایی (مثل currentPage + currentPageOffsetFraction)
    @State private var dragOffset: CGFloat = 0
    @State private var barVisible = false
    @State private var didSetInitial = false

    private var lastIndex: Int { introSlides.count - 1 }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let livePosition = min(max(position + dragOffset / width, 0), CGFloat(lastIndex))
            let currentPage = Int(position.rounded())
            let fromIndex = min(max(Int(floor(livePosition)), 0), lastIndex)
            let toIndex = min(fromIndex + 1, lastIndex)
            let accent = lerpColor(introSlides[fromIndex].accent, introSlides[toIndex].accent, livePosition - CGFloat(fromIndex))
            let isLast = currentPage == lastIndex

            ZStack(alignment: .bottom) {
                Color.white
                // اسلاید کاملاً خطی (افقی) - در جهت راست‌به‌چپ: اسلاید بعدی از سمت چپ میاد
                ZStack {
                    ForEach(introSlides.indices, id: \.self) { index in
                        slideImage(introSlides[index].image)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .offset(x: (livePosition - CGFloat(index)) * width)
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in dragOffset = value.translation.width }
                        .onEnded { value in
                            let predicted = position + value.predictedEndTranslation.width / width
                            var target = Int(position.rounded())
                            if predicted - position > 0.5 || value.translation.width / width > 0.5 { target += 1 }
                            if predicted - position < -0.5 || value.translation.width / width < -0.5 { target -= 1 }
                            target = min(max(target, 0), lastIndex)
                            let current = position + dragOffset / width
                            position = min(max(current, 0), CGFloat(lastIndex))
                            dragOffset = 0
                            withAnimation(.easeOut(duration: 0.3)) { position = CGFloat(target) }
                        }
                )

                // نوار کنترل شناور پایین
                if barVisible {
                    controlBar(accent: accent, isLast: isLast, currentPage: currentPage)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 22)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea(edges: [])
        .onAppear {
            if !didSetInitial {
                didSetInitial = true
                position = CGFloat(min(max(initialPage, 0), lastIndex))
            }
            withAnimation(.easeInOut(duration: 0.5)) { barVisible = true }
        }
    }

    @ViewBuilder
    private func slideImage(_ name: String) -> some View {
        if let image = UIImage(named: name) ?? Bundle.main.path(forResource: name, ofType: "jpg").flatMap(UIImage.init(contentsOfFile:)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color.white
        }
    }

    private func goTo(_ page: Int) {
        withAnimation(.easeInOut(duration: 0.35)) {
            position = CGFloat(min(max(page, 0), lastIndex))
        }
    }

    private func controlBar(accent: Color, isLast: Bool, currentPage: Int) -> some View {
        HStack(spacing: 0) {
            // رد کردن
            HStack {
                Text("رد کردن")
                    .shkFont(13, .medium)
                    .foregroundColor(colors.onSurfaceVariant)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Capsule())
                    .onTapGesture { if !isLast { onFinish() } }
                    .opacity(isLast ? 0 : 1)
                    .animation(.default, value: isLast)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            // نشانگر قرصی صفحات
            HStack(spacing: 6) {
                ForEach(introSlides.indices, id: \.self) { index in
                    let selected = currentPage == index
                    Capsule()
                        .fill(selected ? accent : colors.onSurfaceVariant.opacity(0.25))
                        .frame(width: selected ? 22 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.3), value: selected)
                        .onTapGesture { goTo(index) }
                }
            }

            // بعدی / شروع کنید
            HStack {
                Spacer(minLength: 0)
                ZStack {
                    if isLast {
                        Button(action: onFinish) {
                            HStack(spacing: 6) {
                                Text("شروع کنید")
                                    .shkFont(14, .bold)
                                    .foregroundColor(.white)
                                RemixIcon(RemixIcons.ArrowLeftLine, tint: .white, size: 18)
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 48)
                            .background(accent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeInOut(duration: 0.25)).combined(with: .scale(scale: 0.85)),
                            removal: .opacity.animation(.easeInOut(duration: 0.2)).combined(with: .scale(scale: 0.85))
                        ))
                    } else {
                        NextRingButton(
                            progress: CGFloat(currentPage + 1) / CGFloat(introSlides.count),
                            accent: accent,
                            track: colors.onSurfaceVariant.opacity(0.15),
                            onTap: { goTo(currentPage + 1) }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.animation(.easeInOut(duration: 0.25)).combined(with: .scale(scale: 0.85)),
                            removal: .opacity.animation(.easeInOut(duration: 0.2)).combined(with: .scale(scale: 0.85))
                        ))
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isLast)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(8)
        .background(colors.surface.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
    }
}

/// دکمه‌ی «بعدی» با حلقه‌ی پیشرفت دورش
private struct NextRingButton: View {
    let progress: CGFloat
    let accent: Color
    let track: Color
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: 3)
                .padding(1.5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(1.5)
                .animation(.easeInOut(duration: 0.4), value: progress)
            Circle()
                .fill(accent)
                .frame(width: 42, height: 42)
            RemixIcon(RemixIcons.ArrowLeftLine, contentDescription: "بعدی", tint: .white, size: 20)
        }
        .frame(width: 54, height: 54)
        .contentShape(Circle())
        .onTapGesture(perform: onTap)
        .environment(\.layoutDirection, .leftToRight)
    }
}
