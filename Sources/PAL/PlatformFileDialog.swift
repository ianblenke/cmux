// Platform Abstraction Layer — File Dialogs
// REQ-XP-002: PAL protocol definitions

import Foundation

/// Abstracts file open/save dialogs (NSOpenPanel / GtkFileChooser).
public protocol PlatformFileDialog {
    /// Show an open file dialog. Returns selected URLs or empty array if cancelled.
    func openFile(title: String, allowedTypes: [String], allowsMultiple: Bool,
                  completion: @escaping ([URL]) -> Void)

    /// Show a save file dialog. Returns selected URL or nil if cancelled.
    func saveFile(title: String, defaultName: String, allowedTypes: [String],
                  completion: @escaping (URL?) -> Void)
}
