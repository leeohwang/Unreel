import SwiftUI
import WebKit

/// Lets native UI (the bottom tab bar) drive the web view and know where it is.
@MainActor
final class WebNavigator: ObservableObject {
    @Published private(set) var currentPath = "/"
    @Published private(set) var isLoading = false
    @Published private(set) var progress: Double = 0
    /// Whether Instagram's own bottom tab bar is on screen (reported by cage.js).
    /// The app shows its own tab bar only when it isn't, e.g. in DMs.
    @Published var igBarVisible = false
    /// The tab the user last tapped, for pages whose path no tab recognizes (e.g. their profile).
    @Published var lastTappedTab: String?
    /// The page's own background colour, so the header, bars and safe areas
    /// around the web view blend into it (Instagram's dark mode is a dark navy,
    /// not black). WebKit derives `underPageBackgroundColor` from the page.
    @Published private(set) var pageBackground = Color(uiColor: .pageFallback)
    /// True while the app is opening Instagram's create flow (it covers the
    /// web view so the home feed it passes through is never shown).
    @Published private(set) var isCreating = false
    /// False until Instagram has drawn its first page; until then the app shows
    /// a picture of where you left off, so launch feels instant.
    @Published private(set) var hasPainted = false
    /// Set when the create flow could not be opened.
    @Published var createFailed = false
    private var createTimeout: Task<Void, Never>?
    private weak var webView: WKWebView?
    /// A page asked for before the first load finished (e.g. a notification tap at launch).
    private var queuedPath: String?
    private var urlObservation: NSKeyValueObservation?
    private var loadingObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?
    private var backgroundObservation: NSKeyValueObservation?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        // Never leave the launch picture up if the first load stalls (offline, slow).
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            self?.hasPainted = true
        }
        // WKWebView.url also changes on in-page (pushState) navigations.
        urlObservation = webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
            let path = webView.url?.path ?? "/"
            Task { @MainActor in self?.currentPath = path.isEmpty ? "/" : path }
        }
        loadingObservation = webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
            let loading = webView.isLoading
            Task { @MainActor in self?.isLoading = loading }
        }
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            let value = webView.estimatedProgress
            Task { @MainActor in self?.progress = value }
        }
        backgroundObservation = webView.observe(\.underPageBackgroundColor, options: [.new]) { [weak self] webView, _ in
            // Ignore the colour WebKit reports before Instagram has painted anything.
            guard webView.url?.host?.hasSuffix("instagram.com") == true,
                  let color = webView.underPageBackgroundColor else { return }
            Task { @MainActor in self?.pageBackground = Color(uiColor: color) }
        }
    }

    /// Navigates inside Instagram's page when it can (fast), else loads the URL.
    func go(_ path: String) {
        guard let webView else {
            queuedPath = path
            return
        }
        let literal = (try? String(decoding: JSONEncoder().encode(path), as: UTF8.self)) ?? "\"/\""
        webView.evaluateJavaScript("window.__unreel ? window.__unreel.navigate(\(literal)) : 'none'") { result, _ in
            if (result as? String) == nil || (result as? String) == "none" {
                webView.load(URLRequest(url: InstagramWebView.instagramURL(path)))
            }
        }
    }

    enum CreateKind: String { case post, story }

    /// Hands a photo to Instagram's own create flow (see `create` in cage.js).
    /// Instagram's editor opens with it; nothing is shared until the user taps Share.
    func create(_ kind: CreateKind, jpeg: Data) {
        guard let webView else { return }
        isCreating = true
        createTimeout?.cancel()
        createTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(25))
            guard !Task.isCancelled else { return }
            self?.createFinished(ok: false)
        }
        let script = "window.__unreel ? window.__unreel.create('\(kind.rawValue)', '\(jpeg.base64EncodedString())') : 'none'"
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            if (result as? String) != "started" { Task { @MainActor in self?.createFinished(ok: false) } }
        }
    }

    func createFinished(ok: Bool) {
        guard isCreating else { return }
        createTimeout?.cancel()
        isCreating = false
        if !ok { createFailed = true }
    }

    static var snapshotURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("last-page.jpg")
    }

    func pageFinishedLoading() {
        if let path = queuedPath {
            queuedPath = nil
            go(path)
        }
        guard !hasPainted else { return }
        // Instagram keeps drawing for a moment after the load event.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            self?.hasPainted = true
        }
    }

    /// Remembers what the screen looked like, for the next launch. Kept only in
    /// this app's caches on this iPhone, protected while the phone is locked.
    func saveSnapshot() {
        guard hasPainted, !isCreating, let webView else { return }
        webView.takeSnapshot(with: nil) { image, _ in
            guard let data = image?.jpegData(compressionQuality: 0.7) else { return }
            try? data.write(to: Self.snapshotURL, options: [.atomic, .completeFileProtection])
        }
    }

    func goProfile() {
        webView?.evaluateJavaScript("window.__unreel && window.__unreel.goProfile();")
    }
}

extension UIColor {
    /// Instagram's page background, used until the page reports its own.
    static let pageFallback = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 12 / 255, green: 16 / 255, blue: 20 / 255, alpha: 1)
            : .white
    }

    /// Instagram's hairline colour (the line above its tab bar).
    static let pageSeparator = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 54 / 255, alpha: 1)
            : UIColor(white: 219 / 255, alpha: 1)
    }
}
