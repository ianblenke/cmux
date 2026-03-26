// Platform Abstraction Layer — Browser Web View
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Abstracts a browser panel (WKWebView / WebKitGTK).
public protocol PlatformWebView: AnyObject {
    /// Load the given URL.
    func load(url: URL)

    /// Evaluate JavaScript in the web view context.
    func evaluateJavaScript(_ script: String, completion: @escaping (Any?, Error?) -> Void)

    /// The current page URL.
    var currentURL: URL? { get }

    /// The current page title.
    var currentTitle: String? { get }

    /// Whether a page is currently loading.
    var isLoading: Bool { get }

    /// Navigate back in history.
    func goBack()

    /// Navigate forward in history.
    func goForward()

    /// Reload the current page.
    func reload()

    /// The native view/widget for embedding.
    var nativeView: AnyObject { get }

    // MARK: - Callbacks

    var onNavigate: ((URL) -> Void)? { get set }
    var onTitleChange: ((String) -> Void)? { get set }
    var onLoadingChange: ((Bool) -> Void)? { get set }
}

/// Factory for creating web views.
public protocol PlatformWebViewFactory {
    func createWebView(config: BrowserConfig) -> any PlatformWebView
}
