import Foundation
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
    private weak var webView: WKWebView?
    private var urlObservation: NSKeyValueObservation?
    private var loadingObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?

    func attach(_ webView: WKWebView) {
        self.webView = webView
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
    }

    /// Navigates inside Instagram's page when it can (fast), else loads the URL.
    func go(_ path: String) {
        guard let webView else { return }
        let literal = (try? String(decoding: JSONEncoder().encode(path), as: UTF8.self)) ?? "\"/\""
        webView.evaluateJavaScript("window.__unreel ? window.__unreel.navigate(\(literal)) : 'none'") { result, _ in
            if (result as? String) == nil || (result as? String) == "none" {
                webView.load(URLRequest(url: InstagramWebView.instagramURL(path)))
            }
        }
    }

    func goProfile() {
        webView?.evaluateJavaScript("window.__unreel && window.__unreel.goProfile();")
    }
}
