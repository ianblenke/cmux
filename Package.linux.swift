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
        // Requires: zig build -Dapp-runtime=none in ghostty/
        .systemLibrary(
            name: "CGhostty",
            path: "Sources/CGhostty"
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

        // Linux GTK4 application
        .executableTarget(
            name: "cmux-linux",
            dependencies: ["cmux-pal", "cmux-core", "CGtk4"],
            path: "Sources/Linux",
            linkerSettings: [
                .linkedLibrary("gtk-4"),
                .linkedLibrary("gio-2.0"),
                .linkedLibrary("gobject-2.0"),
                .linkedLibrary("glib-2.0"),
            ]
        )
    ]
)
