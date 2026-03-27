// swift-tools-version:5.9
// Linux build configuration for cmux
// This file is used instead of Package.swift when building on Linux.
// Usage: cp Package.linux.swift Package.swift && swift build

import PackageDescription

let package = Package(
    name: "cmux-linux",
    products: [
        .executable(name: "cmux-linux", targets: ["cmux-linux"]),
        .library(name: "cmux-pal", targets: ["cmux-pal"]),
        .library(name: "cmux-core", targets: ["cmux-core"])
    ],
    targets: [
        // C module for GTK4 system library
        .systemLibrary(
            name: "CGtk4",
            path: "Sources/CGtk4",
            pkgConfig: "gtk4",
            providers: [
                .apt(["libgtk-4-dev"]),
                .brew(["gtk4"])  // for macOS development
            ]
        ),

        // C module for libghostty
        .systemLibrary(
            name: "CGhostty",
            path: "Sources/CGhostty"
        ),

        // C module for WebKitGTK (browser panels)
        .systemLibrary(
            name: "CWebKit",
            path: "Sources/CWebKit",
            pkgConfig: "webkitgtk-6.0",
            providers: [.apt(["libwebkitgtk-6.0-dev"])]
        ),

        // Platform Abstraction Layer — protocol definitions only
        .target(
            name: "cmux-pal",
            path: "Sources/PAL"
        ),

        // Core logic — platform-agnostic shared code
        .target(
            name: "cmux-core",
            dependencies: ["cmux-pal"],
            path: "Sources/Core"
        ),

        // C helpers for ghostty ABI-correct function calls
        .target(
            name: "CGhosttyHelpers",
            dependencies: ["CGtk4"],
            path: "Sources/CGhosttyHelpers",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags([
                    "-I/usr/include/gtk-4.0",
                    "-I/usr/include/glib-2.0",
                    "-I/usr/lib/glib-2.0/include",
                    "-I/usr/include/pango-1.0",
                    "-I/usr/include/harfbuzz",
                    "-I/usr/include/gdk-pixbuf-2.0",
                    "-I/usr/include/cairo",
                    "-I/usr/include/graphene-1.0",
                    "-I/usr/lib/graphene-1.0/include",
                ]),
            ],
            linkerSettings: [.linkedLibrary("dl"), .linkedLibrary("gtk-4")]
        ),

        // Linux GTK4 application
        .executableTarget(
            name: "cmux-linux",
            dependencies: ["cmux-pal", "cmux-core", "CGtk4", "CGhosttyHelpers", "CWebKit"],
            path: "Sources/Linux",
            linkerSettings: [
                .linkedLibrary("gtk-4"),
                .linkedLibrary("gio-2.0"),
                .linkedLibrary("gobject-2.0"),
                .linkedLibrary("glib-2.0"),
                .linkedLibrary("webkitgtk-6.0"),
                // libghostty loaded via dlopen to avoid Zig global init crash
                // .unsafeFlags(["-Lghostty/zig-out/lib", "-Xlinker", "-rpath=ghostty/zig-out/lib"]),
                // .linkedLibrary("ghostty"),
            ]
        )
    ]
)
