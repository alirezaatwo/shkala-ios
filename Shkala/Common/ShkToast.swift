import SwiftUI

/// معادل Toast.makeText(...).show() اپ اندروید: پیام کوتاه پایین صفحه که خودش محو می‌شه.
/// (iOS «Toast» سیستمی نداره - همون ظاهر Toast اندروید اینجا ساخته شده)
@MainActor
final class ShkToast: ObservableObject {
    static let shared = ShkToast()

    struct Message: Equatable { let id = UUID(); let text: String }

    @Published private(set) var current: Message? = nil
    private var hideTask: Task<Void, Never>? = nil

    /// long=true معادل Toast.LENGTH_LONG (۳.۵ ثانیه)، وگرنه LENGTH_SHORT (۲ ثانیه)
    func show(_ text: String, long: Bool = false) {
        let message = Message(text: text)
        withAnimation(.easeOut(duration: 0.2)) { current = message }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: long ? 3_500_000_000 : 2_000_000_000)
            if Task.isCancelled { return }
            if current == message { withAnimation(.easeIn(duration: 0.2)) { current = nil } }
        }
    }
}

/// لایه‌ی نمایش توست - یک‌بار بالای کل اپ قرار می‌گیره
struct ShkToastHost: View {
    @ObservedObject private var toast = ShkToast.shared

    var body: some View {
        VStack {
            Spacer()
            if let message = toast.current {
                Text(message.text)
                    .shkFont(14, lineHeight: 20)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(argb: 0xEE3A3A3A)))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 86)
                    .transition(.opacity)
                    .id(message.id)
            }
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
    }
}
