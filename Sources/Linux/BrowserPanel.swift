// Browser Panel — in-app browser using WebKitGTK
// REQ-BP-001: Browser panel rendering
// REQ-BP-002: URL navigation

import Foundation
import CGtk4
import CWebKit

/// Creates a browser panel widget with a URL bar and WebView
func createBrowserPanel(url: String = "https://google.com") -> UnsafeMutablePointer<GtkWidget>? {
    // Vertical box: URL bar + WebView
    guard let vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0) else { return nil }
    let vboxPtr = unsafeBitCast(vbox, to: UnsafeMutablePointer<GtkBox>.self)

    // URL bar
    guard let urlBar = gtk_entry_new() else { return nil }
    let entryPtr = unsafeBitCast(urlBar, to: UnsafeMutablePointer<GtkEntry>.self)
    let bufferPtr = gtk_entry_get_buffer(entryPtr)
    gtk_entry_buffer_set_text(bufferPtr, url, Int32(url.utf8.count))
    gtk_entry_set_placeholder_text(entryPtr, "Enter URL...")
    gtk_box_append(vboxPtr, urlBar)

    // WebView
    guard let webView = webkit_web_view_new() else { return nil }
    let wvPtr = unsafeBitCast(webView, to: UnsafeMutablePointer<WebKitWebView>.self)
    gtk_widget_set_hexpand(webView, 1)
    gtk_widget_set_vexpand(webView, 1)
    gtk_box_append(vboxPtr, webView)

    // Store reference for scripting
    activeBrowserWebView = wvPtr

    // Load URL
    url.withCString { cStr in
        webkit_web_view_load_uri(wvPtr, cStr)
    }

    // Navigate on Enter in URL bar
    let activateCb: @convention(c) (UnsafeMutablePointer<GtkEntry>?, gpointer?) -> Void = { entry, webViewPtr in
        guard let entry = entry, let wv = webViewPtr else { return }
        let buffer = gtk_entry_get_buffer(entry)
        guard let text = gtk_entry_buffer_get_text(buffer) else { return }
        let urlStr = String(cString: text)
        let fullUrl = urlStr.hasPrefix("http") ? urlStr : "https://\(urlStr)"
        let wkView = unsafeBitCast(wv, to: UnsafeMutablePointer<WebKitWebView>.self)
        fullUrl.withCString { cStr in
            webkit_web_view_load_uri(wkView, cStr)
        }
    }
    g_signal_connect_data(urlBar, "activate",
        unsafeBitCast(activateCb, to: GCallback.self),
        UnsafeMutableRawPointer(webView),
        nil, GConnectFlags(rawValue: 0))

    return vbox
}

/// Track the active browser WebView for scripting
var activeBrowserWebView: UnsafeMutablePointer<WebKitWebView>?

/// Evaluate JavaScript in the active browser panel
func evaluateJavaScriptInBrowser(_ script: String) {
    guard let wv = activeBrowserWebView else {
        cmuxLog("[browser] No active browser for JS eval")
        return
    }
    script.withCString { cStr in
        webkit_web_view_evaluate_javascript(wv, cStr, -1, nil, nil, nil, nil, nil)
    }
    cmuxLog("[browser] Evaluated JS: \(script.prefix(50))...")
}

/// Navigate the active browser to a URL
func navigateBrowser(_ url: String) {
    guard let wv = activeBrowserWebView else {
        cmuxLog("[browser] No active browser for navigation")
        return
    }
    let fullUrl = url.hasPrefix("http") ? url : "https://\(url)"
    fullUrl.withCString { cStr in
        webkit_web_view_load_uri(wv, cStr)
    }
    cmuxLog("[browser] Navigated to \(fullUrl)")
}

/// Add browser.open to the socket API
func openBrowserInSplit(url: String) {
    guard let contentBox = workspaceManager.contentBoxWidget else { return }
    guard workspaceManager.activeIndex >= 0,
          workspaceManager.activeIndex < workspaceManager.workspaces.count else { return }

    let ws = workspaceManager.workspaces[workspaceManager.activeIndex]

    // Create browser panel
    guard let browserWidget = createBrowserPanel(url: url) else { return }

    // If no splits, create a horizontal split with terminal + browser
    if let currentWidget = ws.contentWidget {
        guard let paned = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL) else { return }
        let panedOp = OpaquePointer(paned)

        // Remove current from parent
        let parent = gtk_widget_get_parent(currentWidget)
        if let parent = parent {
            gtk_box_remove(unsafeBitCast(parent, to: UnsafeMutablePointer<GtkBox>.self), currentWidget)
        }

        // Set terminal as start, browser as end
        gtk_paned_set_start_child(panedOp, currentWidget)
        gtk_paned_set_resize_start_child(panedOp, 1)
        gtk_paned_set_end_child(panedOp, browserWidget)
        gtk_paned_set_resize_end_child(panedOp, 1)

        gtk_box_append(contentBox, paned)
        workspaceManager.workspaces[workspaceManager.activeIndex].contentWidget = paned
    } else {
        gtk_box_append(contentBox, browserWidget)
        workspaceManager.workspaces[workspaceManager.activeIndex].contentWidget = browserWidget
    }

    cmuxLog("[browser] Opened \(url)")
}
