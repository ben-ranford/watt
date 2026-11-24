import Foundation

/// Explicit release endpoints and trust are supplied by validated release configuration.
@MainActor
final class ProductionUpdateSource: UpdateSource {
    static let manifestLimit = 1024 * 1024
    static let archiveLimit = 256 * 1024 * 1024
    private let manifestURL: URL
    private let artifactURL: URL
    private let trust: UpdateTrust
    private let configuration: URLSessionConfiguration
    private let deadline: TimeInterval

    init(manifestURL: URL, artifactURL: URL, trust: UpdateTrust,
         configuration: URLSessionConfiguration = .ephemeral, deadline: TimeInterval = 60) throws {
        guard Self.validURL(manifestURL), Self.validURL(artifactURL), deadline.isFinite, deadline > 0, deadline <= 300 else {
            throw ServiceFailure.invalidData
        }
        self.manifestURL = manifestURL; self.artifactURL = artifactURL; self.trust = trust
        self.configuration = configuration; self.deadline = deadline
    }
    fileprivate static func validURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.fragment == nil, url.query == nil,
              url.port == nil || url.port == 443 else { return false }
        return true
    }
    func check() async throws -> SignedUpdate? {
        let result = try await fetch(manifestURL, limit: Self.manifestLimit, allowNoContent: true, progress: nil)
        guard let bytes = result else { return nil }
        do {
            let release = try JSONDecoder().decode(SignedUpdate.self, from: bytes)
            _ = try trust.authenticate(release)
            return release
        } catch {
            let reason = error as? ServiceFailure ?? .invalidData
            UpdateDiagnostics.record(error, as: reason, during: "manifest")
            throw reason
        }
    }
    func download(_ release: SignedUpdate) async throws -> Data {
        try await download(release, progress: { _ in })
    }
    func download(_ release: SignedUpdate, progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async throws -> Data {
        let manifest = try trust.authenticate(release)
        try trust.requireCompatible(manifest)
        guard let bytes = try await fetch(artifactURL, limit: Self.archiveLimit, allowNoContent: false, progress: progress) else {
            throw ServiceFailure.invalidData
        }
        try trust.authenticate(bytes, manifest: manifest)
        return bytes
    }
    private func fetch(_ url: URL, limit: Int, allowNoContent: Bool,
                       progress: (@MainActor (UpdateDownloadProgress) -> Void)?) async throws -> Data? {
        try Task.checkCancellation()
        let relay = UpdateProgressRelay(callback: progress)
        let transfer = BoundedUpdateTransfer(url: url, limit: limit, allowNoContent: allowNoContent,
                                             configuration: configuration, deadline: deadline, progress: { relay.report($0) })
        do {
            let result = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in transfer.start(continuation) }
            } onCancel: { transfer.cancel() }
            relay.finish(bytes: result?.count)
            return result
        } catch { relay.finish(bytes: nil); throw error }
    }
}

@MainActor
private final class UpdateProgressRelay {
    private let callback: (@MainActor (UpdateDownloadProgress) -> Void)?
    private var finished = false
    private var received: Int64 = -1
    init(callback: (@MainActor (UpdateDownloadProgress) -> Void)?) { self.callback = callback }
    func report(_ value: UpdateDownloadProgress) {
        guard !finished, value.isValid, value.received > received else { return }
        received = value.received; callback?(value)
    }
    func finish(bytes: Int?) {
        finished = true
        if let bytes, bytes > 0 { callback?(UpdateDownloadProgress(received: Int64(bytes), total: Int64(bytes))) }
    }
}

/// All mutable state is protected by lock, including cancellation before start and final delivery.
private final class BoundedUpdateTransfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let url: URL
    private let limit: Int
    private let allowNoContent: Bool
    private let configuration: URLSessionConfiguration
    private let deadline: TimeInterval
    private let progress: (@MainActor (UpdateDownloadProgress) -> Void)?
    private var session: URLSession?
    private var continuation: CheckedContinuation<Data?, Error>?
    private var timer: DispatchWorkItem?
    private var done = false
    private var cancelled = false
    private var responseAccepted = false
    private var noContent = false
    private var expected: Int64 = -1
    private var redirects = 0
    private var bytes = Data()

    init(url: URL, limit: Int, allowNoContent: Bool, configuration: URLSessionConfiguration, deadline: TimeInterval,
         progress: (@MainActor (UpdateDownloadProgress) -> Void)?) {
        self.url = url; self.limit = limit; self.allowNoContent = allowNoContent
        self.configuration = configuration.copy() as! URLSessionConfiguration
        self.deadline = deadline; self.progress = progress
    }
    func start(_ continuation: CheckedContinuation<Data?, Error>) {
        lock.lock()
        if cancelled { lock.unlock(); continuation.resume(throwing: ServiceFailure.cancelled); return }
        self.continuation = continuation
        configuration.timeoutIntervalForRequest = deadline; configuration.timeoutIntervalForResource = deadline
        configuration.urlCache = nil; configuration.httpCookieStorage = nil; configuration.urlCredentialStorage = nil
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        self.session = session
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: deadline)
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let timeout = DispatchWorkItem { [weak self] in self?.finish(.failure(ServiceFailure.timedOut)) }
        timer = timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + deadline, execute: timeout)
        session.dataTask(with: request).resume()
        lock.unlock()
    }
    func cancel() {
        lock.lock(); cancelled = true; lock.unlock()
        finish(.failure(ServiceFailure.cancelled))
    }
    private func finish(_ result: Result<Data?, Error>) {
        lock.lock()
        guard !done, let continuation else { lock.unlock(); return }
        done = true; self.continuation = nil
        let session = self.session; self.session = nil
        timer?.cancel(); timer = nil
        lock.unlock()
        session?.invalidateAndCancel()
        continuation.resume(with: result)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        lock.lock()
        redirects += 1
        let candidate = request.url
        let allowed = !done && redirects <= 3 && candidate?.scheme == "https" && candidate?.host?.lowercased() == url.host?.lowercased()
            && (candidate?.port ?? 443) == (url.port ?? 443) && candidate?.user == nil && candidate?.password == nil
            && candidate?.query == nil && candidate?.fragment == nil
        lock.unlock()
        completionHandler(allowed ? request : nil)
        if !allowed {
            UpdateDiagnostics.record(UpdateResponseRejection(status: response.statusCode), as: .invalidData, during: "redirect")
            finish(.failure(ServiceFailure.invalidData))
        }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        lock.lock()
        guard !done, let http = response as? HTTPURLResponse, let finalURL = http.url,
              finalURL.scheme == "https", finalURL.host?.lowercased() == url.host?.lowercased(),
              (finalURL.port ?? 443) == (url.port ?? 443),
              http.statusCode == 200 || (allowNoContent && http.statusCode == 204),
              http.value(forHTTPHeaderField: "Content-Encoding").map({ $0.lowercased() == "identity" }) ?? true,
              response.expectedContentLength <= Int64(limit) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            lock.unlock(); completionHandler(.cancel)
            UpdateDiagnostics.record(UpdateResponseRejection(status: status), as: .invalidData, during: "response")
            finish(.failure(ServiceFailure.invalidData)); return
        }
        expected = response.expectedContentLength; noContent = http.statusCode == 204; responseAccepted = true
        lock.unlock(); completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard !done else { lock.unlock(); return }
        guard responseAccepted, !noContent, data.count <= limit - bytes.count else {
            lock.unlock(); finish(.failure(ServiceFailure.invalidData)); return
        }
        bytes.append(data)
        let received = Int64(bytes.count), total = expected > 0 ? expected : Int64(limit)
        guard received <= total else { lock.unlock(); finish(.failure(ServiceFailure.invalidData)); return }
        let progress = self.progress
        lock.unlock()
        if let progress { Task { @MainActor in progress(UpdateDownloadProgress(received: received, total: total)) } }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let accepted = responseAccepted, noContent = self.noContent, bytes = self.bytes, expected = self.expected
        let alreadyDone = done
        lock.unlock()
        if alreadyDone { return }
        if let error {
            let reason = UpdateFailureClassification.transport(error)
            UpdateDiagnostics.record(error, as: reason, during: "transfer")
            finish(.failure(reason))
        } else if !accepted || (expected >= 0 && !noContent && expected != bytes.count) {
            finish(.failure(ServiceFailure.invalidData))
        } else { finish(.success(noContent ? nil : bytes)) }
    }
}
