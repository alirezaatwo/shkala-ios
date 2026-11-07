import SwiftUI
import UIKit

/// معادل AsyncImage کتابخونه‌ی Coil اپ اندروید: بارگذاری تصویر از آدرس، با کش حافظه (NSCache)
/// و کش دیسک (URLCache) - تا برگشت به صفحه‌ها و اسکرول کاروسل‌ها تصویرها رو دوباره دانلود نکنه.
final class ShkImageLoader {
    static let shared = ShkImageLoader()

    private let memory = NSCache<NSString, UIImage>()
    private let session: URLSession
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    private let lock = NSLock()

    private init() {
        memory.totalCostLimit = 80 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 250 * 1024 * 1024, diskPath: "shk_images")
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 60
        session = URLSession(configuration: config)
    }

    func cached(_ url: String) -> UIImage? { memory.object(forKey: url as NSString) }

    func load(_ url: String) async -> UIImage? {
        if let img = cached(url) { return img }
        lock.lock()
        if let task = inflight[url] {
            lock.unlock()
            return await task.value
        }
        let task = Task<UIImage?, Never> { [session, memory] in
            guard let u = URL(string: url) ?? URL(string: url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else { return nil }
            guard let (data, _) = try? await session.data(from: u), let image = UIImage(data: data) else { return nil }
            // پیش‌رمزگشایی تا اسکرول روان بمونه
            let decoded = image.preparingForDisplay() ?? image
            memory.setObject(decoded, forKey: url as NSString, cost: data.count)
            return decoded
        }
        inflight[url] = task
        lock.unlock()
        let result = await task.value
        lock.lock(); inflight[url] = nil; lock.unlock()
        return result
    }
}

/// نحوه‌ی جاگیری تصویر (ContentScale اندروید)
enum ShkContentScale {
    /// Crop: کل کادر پر و اضافه‌ی تصویر بریده می‌شه
    case crop
    /// Fit: کل تصویر داخل کادر
    case fit
    /// FillWidth: عرض کامل و ارتفاع به نسبت ابعاد واقعی تصویر (کادر ارتفاع ثابت نداره)
    case fillWidth
    /// اندازه‌ی کادر از خود تصویر (مثل لوگو با ارتفاع ثابت و عرض wrap): تا لود نشده، عرض صفر
    case wrap
}

struct RemoteImage: View {
    let url: String?
    var contentDescription: String? = nil
    var contentScale: ShkContentScale = .crop

    @State private var image: UIImage? = nil
    @State private var loadedUrl: String? = nil

    init(_ url: String?, contentDescription: String? = nil, contentScale: ShkContentScale = .crop) {
        self.url = url
        self.contentDescription = contentDescription
        self.contentScale = contentScale
        // اگه تصویر از قبل در کش حافظه باشه، همون فریم اول نمایش داده می‌شه (بدون چشمک)
        let cached = url.flatMap { ShkImageLoader.shared.cached($0) }
        _image = State(initialValue: cached)
        _loadedUrl = State(initialValue: cached == nil ? nil : url)
    }

    var body: some View {
        let current = (loadedUrl == url) ? image : nil
        content(current)
            .accessibilityLabel(contentDescription ?? "")
            .accessibilityHidden(contentDescription == nil)
            .task(id: url) {
                guard let url, !url.isEmpty else { image = nil; loadedUrl = nil; return }
                if loadedUrl == url, image != nil { return }
                let img = await ShkImageLoader.shared.load(url)
                if Task.isCancelled { return }
                image = img
                loadedUrl = url
            }
    }

    @ViewBuilder
    private func content(_ img: UIImage?) -> some View {
        switch contentScale {
        case .crop:
            Color.clear
                .overlay {
                    if let img {
                        Image(uiImage: img).resizable().scaledToFill()
                    }
                }
                .clipped()
        case .fit:
            Color.clear
                .overlay {
                    if let img {
                        Image(uiImage: img).resizable().scaledToFit()
                    }
                }
        case .fillWidth:
            if let img, img.size.width > 0 {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(img.size.width / img.size.height, contentMode: .fit)
                    .frame(maxWidth: .infinity)
            } else {
                Color.clear.frame(maxWidth: .infinity).frame(height: 0)
            }
        case .wrap:
            if let img {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fit)
            } else {
                Color.clear.frame(width: 0)
            }
        }
    }
}
