import SwiftUI

// معادل DropdownMenu متریال اپ اندروید: منوی کشویی که زیر دکمه‌ی خودش باز می‌شه، روی بقیه‌ی
// محتوای صفحه (حتی بیرون از ScrollView) قرار می‌گیره و با لمس بیرونش بسته می‌شه.
// دکمه با shkDropdown(...) منو رو اعلام می‌کنه و یک لایه‌ی بالاتر (shkDropdownHost) رسمش می‌کنه.

struct ShkDropdownItem {
    let anchor: Anchor<CGRect>
    let width: CGFloat
    let content: AnyView
    let onDismiss: () -> Void
}

struct ShkDropdownKey: PreferenceKey {
    static var defaultValue: [ShkDropdownItem] = []
    static func reduce(value: inout [ShkDropdownItem], nextValue: () -> [ShkDropdownItem]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// منوی کشویی زیر همین view (عرض ثابت [width])
    func shkDropdown<Content: View>(isPresented: Binding<Bool>, width: CGFloat = 280, @ViewBuilder content: @escaping () -> Content) -> some View {
        anchorPreference(key: ShkDropdownKey.self, value: .bounds) { anchor in
            isPresented.wrappedValue
                ? [ShkDropdownItem(anchor: anchor, width: width, content: AnyView(content()), onDismiss: { isPresented.wrappedValue = false })]
                : []
        }
    }

    /// لایه‌ی رسم منوهای کشویی - یک‌بار دور محتوای اصلی صفحه
    func shkDropdownHost() -> some View {
        overlayPreferenceValue(ShkDropdownKey.self) { items in
            GeometryReader { proxy in
                if let item = items.last {
                    let rect = proxy[item.anchor]
                    let maxX = proxy.size.width - 8
                    // مثل DropdownMenu: لبه‌ی چپ منو هم‌تراز لبه‌ی چپ دکمه، و اگه جا نشد به داخل صفحه رونده می‌شه
                    let x = max(8, min(rect.minX, maxX - item.width))
                    let y = rect.maxY + 4
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .contentShape(Rectangle())
                            .onTapGesture { item.onDismiss() }
                        item.content
                            .environment(\.layoutDirection, .rightToLeft)
                            .frame(width: item.width)
                            .offset(x: x, y: y)
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
    }
}

/// ظاهر کادر منوی کشویی متریال (گوشه‌ی ۴، رنگ surfaceContainer، سایه)
struct ShkDropdownSurface<Content: View>: View {
    var maxHeight: CGFloat = 420
    @ViewBuilder let content: () -> Content
    @Environment(\.shkColors) private var colors
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            content()
                .padding(.vertical, 8)
                .background(GeometryReader { g in
                    Color.clear.onAppear { contentHeight = g.size.height }.onChange(of: g.size.height) { contentHeight = $0 }
                })
        }
        .frame(height: min(max(contentHeight, 1), maxHeight))
        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(colors.surfaceContainer))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .materialShadow(3)
    }
}
