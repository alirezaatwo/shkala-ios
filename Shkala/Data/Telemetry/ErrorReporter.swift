import Foundation

/**
 * معادل data/telemetry/ErrorReporter.kt: گزارش خطاهای اپ (فقط با رضایت کاربر؛ پیش‌فرض: بدون رضایت و بدون ثبت هیچ چیزی).
 *  - کرش‌ها: هندلر سراسری استثناها (NSSetUncaughtExceptionHandler) که خطا رو هم‌زمان در صف روی دیسک می‌نویسه و
 *    بعد به هندلر قبلی می‌سپاره تا رفتار عادی کرش حفظ بشه.
 *    تفاوت اجباری iOS: فقط استثناهای Objective-C/UIKit قابل گرفتن هستن؛ کرش‌های خودِ Swift (مثل fatalError یا
 *    باز کردن nil) را سیستم‌عامل بدون فرصت ثبت می‌بنده.
 *  - خطاهای API: از ApiClient.recordApiError (معادل ErrorRecordingInterceptor) - فقط مسیر (بدون query و توکن)
 *  - خطاهای کنترل‌شده: [report]
 * صف روی دیسک حداکثر ۱۰۰ مورد نگه می‌داره؛ ارسال در دسته‌های ۲۰تایی هنگام شروع اپ (بعد از heartbeat) و هر وقت
 * صف به ۲۰ مورد رسید. موارد ارسال‌شده از صف حذف می‌شن.
 */
enum ErrorReporter {
    private static let QUEUE_FILE = "error_report_queue.json"
    private static let MAX_QUEUE = 100
    private static let BATCH_SIZE = 20
    private static let DEDUP_WINDOW_MS: Int64 = 60_000
    private static let MAX_MESSAGE = 1000
    private static let MAX_STACKTRACE = 8000

    /// همه‌ی کارهای فایل صف و وضعیت داخلی روی همین صف سریالی
    private static let fileQueue = DispatchQueue(label: "com.shkala.app.error-reporter")
    private static let stateLock = NSLock()

    private static var _isConsented = false
    /// رضایت کاربر (از حافظه خونده و این‌جا کش می‌شه تا هندلر کرش بتونه هم‌زمان چک کنه)
    static var isConsented: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _isConsented
    }

    private static var recentKeys: [String: Int64] = [:]
    private static var uploading = false
    private static var initialized = false
    private static var previousHandler: (@convention(c) (NSException) -> Void)? = nil

    /// یک خطای در صف ارسال (id برای حذف دقیق موارد ارسال‌شده از صف)
    private struct QueuedAppError: Codable {
        var id: String? = nil
        var error: AppErrorItemDto? = nil
    }

    /// از شروع اپ صدا زده می‌شه (معادل ShkalaApplication.onCreate)
    static func initialize() {
        stateLock.lock()
        if initialized { stateLock.unlock(); return }
        initialized = true
        _isConsented = AppMetaPreferenceManager.getErrorReportConsent() == true
        stateLock.unlock()
        installCrashHandler()
    }

    /// ثبت انتخاب کاربر؛ با «خیر» صف فعلی هم پاک می‌شه
    static func setConsent(_ consented: Bool) {
        AppMetaPreferenceManager.setErrorReportConsent(consented)
        stateLock.lock(); _isConsented = consented; stateLock.unlock()
        if consented {
            Task.detached(priority: .utility) { await uploadPending() }
        } else {
            fileQueue.async { try? FileManager.default.removeItem(at: queueFile()) }
        }
    }

    /// ثبت یک خطای کنترل‌شده (مثلاً داخل catch)
    static func report(type: String = "error", message: String, error: Error? = nil, screen: String? = nil) {
        guard isConsented else { return }
        let text = message.isBlankShk ? (error.map { String(describing: Swift.type(of: $0)) } ?? "error") : message
        let item = buildItem(
            type: type,
            message: text,
            stacktrace: error.map { "\($0)\n" + Thread.callStackSymbols.joined(separator: "\n") },
            screen: screen
        )
        enqueueAsync(item)
    }

    /// خطای API (از ApiClient)
    static func recordApiError(endpoint: String, httpCode: Int?, message: String) {
        guard isConsented else { return }
        enqueueAsync(buildItem(type: "api", message: message, endpoint: endpoint, httpCode: httpCode))
    }

    /// ارسال صف (دسته‌های ۲۰تایی) - فقط با رضایت؛ خطاها بی‌صدا نادیده گرفته می‌شن
    static func uploadPending() async {
        guard isConsented else { return }
        stateLock.lock()
        if uploading { stateLock.unlock(); return }
        uploading = true
        stateLock.unlock()
        defer { stateLock.lock(); uploading = false; stateLock.unlock() }

        let installId = AppMetaPreferenceManager.getOrCreateInstallId()
        let deviceModel = await MainActor.run { AppDeviceInfo.deviceModel() }
        // حداکثر ۵ دسته (کل ظرفیت صف) در هر بار
        for _ in 0..<(MAX_QUEUE / BATCH_SIZE) {
            guard isConsented else { return }
            let batch = Array(fileQueue.sync { readQueue() }.prefix(BATCH_SIZE))
            if batch.isEmpty { return }
            let items = batch.compactMap { $0.error }
            if !items.isEmpty {
                let body = AppErrorsUploadRequest(
                    installId: installId,
                    appVersion: AppDeviceInfo.versionName(),
                    deviceModel: deviceModel,
                    errors: items
                )
                guard let response = try? await ApiService.uploadAppErrors(body), response.isSuccessful else { return }
            }
            let sentIds = Set(batch.compactMap { $0.id })
            fileQueue.sync {
                // موارد بدون id (خراب) هم همراه همین دسته حذف می‌شن
                writeQueue(readQueue().filter { $0.id != nil && !sentIds.contains($0.id!) })
            }
        }
    }

    private static func installCrashHandler() {
        previousHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            if ErrorReporter.isConsented {
                let item = ErrorReporter.buildItem(
                    type: "crash",
                    message: "\(exception.name.rawValue): \(exception.reason ?? "")",
                    stacktrace: exception.callStackSymbols.joined(separator: "\n"),
                    screen: "thread:\(Thread.isMainThread ? "main" : (Thread.current.name ?? "background"))"
                )
                // هم‌زمان: پروسه چند لحظه‌ی دیگه بسته می‌شه
                ErrorReporter.fileQueue.sync { _ = ErrorReporter.appendToQueue(item) }
            }
            ErrorReporter.previousHandler?(exception)
        }
    }

    private static func buildItem(
        type: String,
        message: String,
        stacktrace: String? = nil,
        screen: String? = nil,
        endpoint: String? = nil,
        httpCode: Int? = nil
    ) -> AppErrorItemDto {
        AppErrorItemDto(
            type: type,
            message: String(message.prefix(MAX_MESSAGE)),
            stacktrace: stacktrace.map { String($0.prefix(MAX_STACKTRACE)) },
            screen: screen.map { String($0.prefix(190)) },
            endpoint: endpoint.map { String($0.prefix(190)) },
            httpCode: httpCode,
            occurredAt: Int64(Date().timeIntervalSince1970)
        )
    }

    private static func enqueueAsync(_ item: AppErrorItemDto) {
        // خطاهای یکسان در بازه‌ی ۶۰ ثانیه فقط یک‌بار ثبت می‌شن
        let key = "\(item.type)|\(item.endpoint ?? "")|\(item.httpCode.map(String.init) ?? "")|\(item.message)"
        let now = nowMs()
        stateLock.lock()
        if let last = recentKeys[key], now - last < DEDUP_WINDOW_MS {
            stateLock.unlock()
            return
        }
        recentKeys[key] = now
        if recentKeys.count > 200 {
            recentKeys = recentKeys.filter { now - $0.value < DEDUP_WINDOW_MS }
        }
        stateLock.unlock()
        fileQueue.async {
            let size = appendToQueue(item)
            if size >= BATCH_SIZE {
                Task.detached(priority: .utility) { await uploadPending() }
            }
        }
    }

    /// افزودن به صف روی دیسک (حداکثر ۱۰۰ مورد؛ قدیمی‌ترها حذف می‌شن) - خروجی: اندازه‌ی صف. فقط روی fileQueue.
    private static func appendToQueue(_ item: AppErrorItemDto) -> Int {
        var queue = readQueue()
        queue.append(QueuedAppError(id: UUID().uuidString, error: item))
        if queue.count > MAX_QUEUE { queue = Array(queue.suffix(MAX_QUEUE)) }
        writeQueue(queue)
        return queue.count
    }

    private static func queueFile() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(QUEUE_FILE)
    }

    private static func readQueue() -> [QueuedAppError] {
        guard let data = try? Data(contentsOf: queueFile()) else { return [] }
        return (try? JSONDecoder().decode([QueuedAppError].self, from: data)) ?? []
    }

    private static func writeQueue(_ queue: [QueuedAppError]) {
        let file = queueFile()
        if queue.isEmpty {
            try? FileManager.default.removeItem(at: file)
            return
        }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(queue) {
            try? data.write(to: file, options: .atomic)
        }
    }
}
