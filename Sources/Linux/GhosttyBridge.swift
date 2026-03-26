// Ghostty Bridge — Swift wrapper for the libghostty C embedding API on Linux
// REQ-XP-020: GTK4 application framework
// REQ-TC-001: Ghostty-based terminal emulation
//
// DISABLED: The embedded API's Zig global constructors crash on Linux
// because the objc runtime import in embedded.zig runs during dlopen.
// This file is preserved as the integration blueprint for when the
// embedded apprt is made Linux-safe.
//
// To re-enable:
// 1. Make embedded.zig's objc import conditional (#if os(macos))
// 2. Rebuild libghostty with: zig build -Dapp-runtime=none
// 3. Uncomment CGhostty linkage in Package.linux.swift
// 4. Remove the #if false guard below

#if false  // Disabled until embedded apprt is Linux-safe

import Foundation
import CGtk4
import CGhostty

// ... (full implementation preserved in git history)

#endif  // false
