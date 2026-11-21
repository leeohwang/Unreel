import Foundation
import WebKit

/// Lets native UI (the bottom tab bar) drive the web view and know where it is.
@MainActor
final class WebNavigator: ObservableObject {
    @Published private(set) var currentPath = "/"
    private weak var webView: WKWebView?
    private var urlObservation: NSKeyValueObservation?

    func attach(_ webView: WKWebView) {
        self.webView = webView
        // WKWebView.url also changes on in-page (pushState) navigations.
        urlObservation = webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
            let path = webView.url?.path ?? "/"
            Task { @MainActor in self?.currentPath = path.isEmpty ? "/" : path }
        }
    }

    func go(_ path: String) {
        webView?.load(URLRequest(url: InstagramWebView.instagramURL(path)))
    }

    func goProfile() {
        webView?.evaluateJavaScript("window.__unreel && window.__unreel.goProfile();")
    }
}
