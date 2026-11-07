import SwiftUI
import MapLibre

/**
 * معادل ui/checkout/MapPickerScreen.kt: از همون روش شناخته‌شده‌ی «پین ثابت وسط صفحه» استفاده می‌کنه
 * (دقیقاً مثل گوگل‌مپ/اسنپ): کاربر نقشه رو جابه‌جا می‌کنه، پین همیشه وسط می‌مونه،
 * و مختصات دقیقاً همونیه که زیر پینه.
 * بازطراحی: نوار بالای استاندارد، نقشه در قاب گوشه‌گرد، راهنمای شناور و کارت پایینِ ثابت.
 */
struct MapPickerScreen: View {
    let onBack: () -> Void
    let onConfirm: (Double, Double) -> Void

    @Environment(\.shkColors) private var colors
    @ObservedObject private var flow = LocationPickFlowState.shared
    @State private var currentLat: Double = 35.6997
    @State private var currentLng: Double = 51.3380
    @State private var initialized = false

    var body: some View {
        VStack(spacing: 0) {
            SitePageTopBar(title: "انتخاب موقعیت روی نقشه", onBack: onBack)

            ZStack(alignment: .top) {
                if initialized {
                    NeshanMapView(initialLat: currentLat, initialLng: currentLng) { lat, lng in
                        currentLat = lat
                        currentLng = lng
                    }
                }

                // راهنمای شناور بالای نقشه
                HStack(spacing: 0) {
                    RemixIcon(RemixIcons.DragMove2Line, tint: colors.primary, size: 16)
                    Spacer().frame(width: 6)
                    Text("نقشه را جابه‌جا کنید تا پین دقیقاً روی موقعیت مدنظر قرار بگیرد")
                        .shkFont(11, lineHeight: 18)
                        .foregroundColor(colors.onSurface)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(colors.surface))
                .materialShadow(4)
                .padding(12)

                // پین ثابت وسط صفحه - همیشه همون‌جا می‌مونه، نقشه زیرش حرکت می‌کنه
                // (نوک پین دقیقاً روی مرکز نقشه قرار می‌گیره + یک نقطه‌ی سایه زیرش)
                ZStack {
                    Circle().fill(Color.black.opacity(0.25)).frame(width: 10, height: 10)
                    RemixIcon(RemixIcons.MapPin2Fill, contentDescription: "موقعیت انتخاب‌شده", tint: colors.primary, size: 46)
                        .offset(y: -19)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    SiteIconBadge(icon: RemixIcons.Focus3Line, size: 38, iconSize: 19, radius: 11)
                    Spacer().frame(width: 10)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("مختصات انتخاب‌شده").shkFont(11).foregroundColor(colors.onSurfaceVariant)
                        Text("\(String(String(currentLat).prefix(8)).toPersianDigits()), \(String(String(currentLng).prefix(8)).toPersianDigits())")
                            .shkFont(13, .bold)
                            .foregroundColor(colors.onSurface)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer().frame(height: 14)
                SitePrimaryButton(text: "تایید این موقعیت", onClick: {
                    flow.pickedLat = currentLat
                    flow.pickedLng = currentLng
                    onConfirm(currentLat, currentLng)
                }, icon: RemixIcons.CheckLine, fillWidth: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                TopRoundedShape(radius: 20)
                    .fill(colors.surface)
                    .shadow(color: .black.opacity(0.14), radius: 9, x: 0, y: -2)
                    .ignoresSafeArea(edges: .bottom)
            )
            .padding(.top, 12)
        }
        .background(colors.background)
        .onAppear {
            if !initialized {
                currentLat = flow.pickedLat ?? 35.6997
                currentLng = flow.pickedLng ?? 51.3380
                initialized = true
            }
        }
    }
}

/// نقشه‌ی MapLibre با استایل نشان (همون استایل اپ اندروید)؛ با ایستادن نقشه، مرکزش گزارش می‌شه
private struct NeshanMapView: UIViewRepresentable {
    let initialLat: Double
    let initialLng: Double
    let onCameraIdle: (Double, Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCameraIdle: onCameraIdle) }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero, styleURL: URL(string: "https://static.neshan.org/sdk/maplibre/styles/light.json"))
        map.delegate = context.coordinator
        map.setCenter(CLLocationCoordinate2D(latitude: initialLat, longitude: initialLng), zoomLevel: 15, animated: false)
        // نقشه همیشه چپ‌به‌راست (جهت RTL اپ نباید روی کنترل‌های نقشه اثر بذاره)
        map.semanticContentAttribute = .forceLeftToRight
        map.logoView.isHidden = false
        return map
    }

    func updateUIView(_ uiView: MLNMapView, context: Context) {
        context.coordinator.onCameraIdle = onCameraIdle
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        var onCameraIdle: (Double, Double) -> Void
        init(onCameraIdle: @escaping (Double, Double) -> Void) { self.onCameraIdle = onCameraIdle }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            let target = mapView.centerCoordinate
            onCameraIdle(target.latitude, target.longitude)
        }
    }
}
