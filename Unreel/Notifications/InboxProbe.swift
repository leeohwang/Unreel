import UIKit
import WebKit

/// Opens Instagram's inbox page in an invisible web view, using the login the app's
/// main web view already has, and reads which chats are unread (see inbox-probe.js).
/// This is the same page you'd see yourself: it makes no other requests to Instagram.
@MainActor
final class InboxProbe: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    struct Chat: Decodable, Equatable {
        let id: String?
        let name: String
        let preview: String?
    }

    struct Result: Decodable {
        let path: String
        let loggedIn: Bool
        let listFound: Bool
        let rowCount: Int
        let titleCount: Int?
        let badgeCount: Int?
        let threads: [Chat]
        let outline: String?

        /// The best unread count the page gave us.
        var unreadCount: Int? {
            if !threads.isEmpty { return max(threads.count, badgeCount ?? 0) }
            return badgeCount ?? titleCount ?? (listFound ? 0 : nil)
        }
    }

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Result?, Never>?
    private var timeoutTask: Task<Void, Never>?

    /// Loads the inbox and returns what it found, or nil if the page didn't
    /// finish in time (or `cancel()` was called).
    func run(rules: InboxRules, timeout: TimeInterval = 25, debug: Bool = false) async -> Result? {
        guard continuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            start(rules: rules, timeout: timeout, debug: debug)
        }
    }

    func cancel() { finish(nil) }

    private func start(rules: InboxRules, timeout: TimeInterval, debug: Bool) {
        guard let source = Self.script(rules: rules, waitMs: Int((timeout - 3) * 1000), debug: debug) else {
            finish(nil)
            return
        }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()    // shares the login with the main web view
        config.mediaTypesRequiringUserActionForPlayback = .all
        let content = WKUserContentController()
        content.add(WeakHandler(self), name: "unreelInbox")
        content.addUserScript(WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController = content

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        webView.customUserAgent = InstagramWebView.safariUserAgent
        webView.navigationDelegate = self
        webView.isUserInteractionEnabled = false
        // WebKit slows pages that aren't in a window, so park it, invisible, in ours if there is one.
        webView.alpha = 0
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.windows.first }).first {
            window.insertSubview(webView, at: 0)
        }
        self.webView = webView
        webView.load(URLRequest(url: InstagramWebView.instagramURL("/direct/inbox/")))

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            self?.finish(nil)
        }
    }

    private func finish(_ result: Result?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        if let webView {
            webView.stopLoading()
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "unreelInbox")
            webView.removeFromSuperview()
        }
        webView = nil
        continuation?.resume(returning: result)
        continuation = nil
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: body),
              let result = try? JSONDecoder().decode(Result.self, from: data) else {
            finish(nil)
            return
        }
        finish(result)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(nil) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(nil) }

    private static func script(rules: InboxRules, waitMs: Int, debug: Bool) -> String? {
        guard let url = Bundle.main.url(forResource: "inbox-probe", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8),
              var options = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(rules)) as? [String: Any]
        else { return nil }
        options["waitMs"] = max(5000, waitMs)
        // The page can take a while to reach document-end, so also give the script an
        // absolute deadline that lands before our own timeout fires.
        options["deadline"] = Int(Date().timeIntervalSince1970 * 1000) + max(5000, waitMs)
        options["settleMs"] = 1500
        options["debug"] = debug
        guard let json = try? JSONSerialization.data(withJSONObject: options),
              let jsonString = String(data: json, encoding: .utf8) else { return nil }
        return source.replacingOccurrences(of: "__UNREEL_INBOX__", with: jsonString)
    }
}

private final class WeakHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
