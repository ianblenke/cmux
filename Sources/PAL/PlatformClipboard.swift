// Platform Abstraction Layer — Clipboard
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Abstracts clipboard operations (NSPasteboard / GdkClipboard).
public protocol PlatformClipboard {
    /// Copy a string to the clipboard.
    func copy(_ string: String)

    /// Read text from the clipboard, if available.
    func paste() -> String?

    /// Copy image data to the clipboard.
    func copyImage(_ data: Data, type: String)
}
