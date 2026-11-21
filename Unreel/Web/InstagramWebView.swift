import SwiftUI
import UIKit
import WebKit

/// instagram.com in a web view, with Reels / Explore / (optionally) the feed blocked.
struct InstagramWebView: UIViewRepresentable {
    let rules: Rules
    let blockFeed: Bool
    let navigator: WebNavigator
    let onBlocked: @MainActor (BlockKind, Bool) -> Void

    static func instagramURL(_ path: String) -> URL {
        URL(string: "https://www.instagram.com" + (path.hasPrefix("/") ? path : "/" + path))
            ?? URL(string: "https://www.instagram.com/")!
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        // No autoplaying video anywhere.
        config.mediaTypesRequiringUserActionForPlayback = .all

        let content = WKUserContentController()
        content.add(WeakScriptHandler(context.coordinator), name: "unreel")
        config.userContentController = content

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = Self.safariUserAgent
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.pullToRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        context.coordinator.webView = webView
        navigator.attach(webView)
        context.coordinator.installScript(force: true)
        webView.load(URLRequest(url: Self.instagramURL(rules.redirectPath)))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.installScript(force: false)
    }

    /// Instagram serves its full mobile site to Safari. A plain WKWebView user agent gets a degraded page.
    static var safariUserAgent: String {
        let parts = UIDevice.current.systemVersion.split(separator: ".")
        let major = parts.first.map(String.init) ?? "18"
        let minor = parts.count > 1 ? String(parts[1]) : "0"
        let os = parts.joined(separator: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(os) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(major).\(minor) Mobile/15E148 Safari/604.1"
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: InstagramWebView
        weak var webView: WKWebView?
        private var installedConfig = ""

        private static let cageSource: String = {
            guard let url = Bundle.main.url(forResource: "cage", withExtension: "js"),
                  let source = try? String(contentsOf: url, encoding: .utf8) else {
                fatalError("cage.js is missing from the app bundle")
            }
            return source
        }()

        init(parent: InstagramWebView) { self.parent = parent }

        private var configJSON: String {
            struct PageConfig: Encodable {
                let redirectPath: String
                let blockFeed: Bool
                let blockedPaths: [PathRule]
                let hideSelectors: [String]
                let feedSelectors: [String]
                let hideFixedBarsWith: [String]
            }
            let r = parent.rules
            let page = PageConfig(redirectPath: r.redirectPath, blockFeed: parent.blockFeed,
                                  blockedPaths: r.blockedPaths, hideSelectors: r.hideSelectors,
                                  feedSelectors: r.feedSelectors, hideFixedBarsWith: r.hideFixedBarsWith ?? [])
            let data = (try? JSONEncoder().encode(page)) ?? Data("{}".utf8)
            return String(decoding: data, as: UTF8.self)
        }

        /// (Re)installs the page script when rules or settings change, and applies them to the open page.
        func installScript(force: Bool) {
            guard let webView else { return }
            let json = configJSON
            guard force || json != installedConfig else { return }
            installedConfig = json
            let content = webView.configuration.userContentController
            content.removeAllUserScripts()
            content.addUserScript(WKUserScript(
                source: "window.__unreelConfig = \(json);\n" + Self.cageSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true))
            webView.evaluateJavaScript("window.__unreel && window.__unreel.configure(\(json));")
        }

        @objc func pullToRefresh(_ control: UIRefreshControl) {
            webView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { control.endRefreshing() }
        }

        // MARK: Messages from cage.js (in-page navigations)

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  body["type"] as? String == "blocked",
                  let kind = (body["kind"] as? String).flatMap(BlockKind.init(rawValue:)) else { return }
            parent.onBlocked(kind, body["count"] as? Bool ?? true)
        }

        // MARK: Full page navigations

        private static func isInstagram(_ host: String) -> Bool {
            host == "instagram.com" || host.hasSuffix(".instagram.com")
        }

        /// Hosts the login flow may need ("Continue with Facebook", Accounts Center).
        private static func isLoginHost(_ host: String) -> Bool {
            ["facebook.com", "fb.com", "meta.com"].contains { host == $0 || host.hasSuffix("." + $0) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { return decisionHandler(.allow) }
            // Sub-frames (ads, embeds) are left alone; only top-level pages are policed.
            if let frame = action.targetFrame, !frame.isMainFrame { return decisionHandler(.allow) }

            let scheme = url.scheme?.lowercased() ?? ""
            if ["about", "blob", "data"].contains(scheme) { return decisionHandler(.allow) }
            guard scheme == "http" || scheme == "https" else {
                // Never hand off to the Instagram app (that would defeat the point). Allow mail/phone links.
                if ["mailto", "tel", "sms"].contains(scheme) { UIApplication.shared.open(url) }
                return decisionHandler(.cancel)
            }

            let host = url.host?.lowercased() ?? ""
            if Self.isInstagram(host) {
                if let rule = parent.rules.match(path: url.path.isEmpty ? "/" : url.path, blockFeed: parent.blockFeed) {
                    decisionHandler(.cancel)
                    parent.onBlocked(rule.kind, rule.count ?? true)
                    let target = rule.redirect ?? parent.rules.redirectPath
                    webView.load(URLRequest(url: InstagramWebView.instagramURL(target)))
                    return
                }
                return decisionHandler(.allow)
            }
            if Self.isLoginHost(host) { return decisionHandler(.allow) }

            // Everything else (links in bios, shared articles) opens in Safari.
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }

        /// target="_blank" links open in the same web view.
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if action.targetFrame == nil { webView.load(action.request) }
            return nil
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }
    }
}

/// Avoids the retain cycle WKUserContentController creates with its message handlers.
@MainActor
private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
