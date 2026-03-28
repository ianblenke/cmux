// Socket Control Server — Unix socket API for cmux CLI automation
// REQ-SC-001: Socket control access modes
// REQ-SC-007: Socket path resolution

import Foundation
import CGtk4
#if canImport(Glibc)
import Glibc
#endif

/// JSON-RPC request
struct SocketRequest: Codable {
    let jsonrpc: String?  // "2.0"
    let method: String
    let params: [String: String]?
    let id: Int?
}

/// JSON-RPC response
struct SocketResponse: Codable {
    let jsonrpc: String
    let result: AnyCodable?
    let error: SocketError?
    let id: Int?

    struct SocketError: Codable {
        let code: Int
        let message: String
    }
}

/// Type-erased Codable wrapper
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let b = try? container.decode(Bool.self) { value = b }
        else if let a = try? container.decode([String: String].self) { value = a }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let s = value as? String { try container.encode(s) }
        else if let i = value as? Int { try container.encode(i) }
        else if let b = value as? Bool { try container.encode(b) }
        else if let d = value as? [String: String] { try container.encode(d) }
        else if let a = value as? [String] { try container.encode(a) }
        else if let d = value as? [[String: String]] { try container.encode(d) }
        else { try container.encode(String(describing: value)) }
    }
}

/// The socket control server
class SocketControlServer {
    let socketPath: String
    private var serverFd: Int32 = -1
    private var running = false
    private var thread: Thread?

    init(socketPath: String? = nil) {
        if let path = socketPath {
            self.socketPath = path
        } else {
            // Default path: /tmp/cmux-<pid>.sock
            let pid = ProcessInfo.processInfo.processIdentifier
            self.socketPath = "/tmp/cmux-\(pid).sock"
        }
    }

    /// Start listening on the Unix socket
    func start() {
        // Remove stale socket
        unlink(socketPath)

        // Create socket
        serverFd = socket(AF_UNIX, Int32(SOCK_STREAM.rawValue), 0)
        guard serverFd >= 0 else {
            cmuxLog("[socket] Failed to create socket: \(errno)")
            return
        }

        // Bind
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            let raw = UnsafeMutableRawPointer(ptr)
            pathBytes.withUnsafeBufferPointer { buf in
                raw.copyMemory(from: buf.baseAddress!, byteCount: min(buf.count, 104))
            }
        }

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(serverFd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            cmuxLog("[socket] Failed to bind \(socketPath): \(errno)")
            close(serverFd)
            return
        }

        // Set permissions (user-only)
        chmod(socketPath, 0o600)

        // Listen
        guard listen(serverFd, 5) == 0 else {
            cmuxLog("[socket] Failed to listen: \(errno)")
            close(serverFd)
            return
        }

        running = true

        // Write socket path for CLI discovery
        let pathFile = "/tmp/cmux-socket-path"
        try? socketPath.write(toFile: pathFile, atomically: true, encoding: .utf8)

        cmuxLog("[socket] Listening on \(socketPath)")

        // Accept connections in background thread
        thread = Thread {
            while self.running {
                let clientFd = accept(self.serverFd, nil, nil)
                if clientFd < 0 {
                    if self.running { usleep(10000) }
                    continue
                }
                self.handleClient(clientFd)
            }
        }
        thread?.start()
    }

    /// Stop the server
    func stop() {
        running = false
        close(serverFd)
        unlink(socketPath)
    }

    /// Handle a single client connection
    private func handleClient(_ fd: Int32) {
        defer { close(fd) }

        // Read request (up to 64KB)
        var buffer = [UInt8](repeating: 0, count: 65536)
        let bytesRead = read(fd, &buffer, buffer.count - 1)
        guard bytesRead > 0 else { return }

        let requestStr = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""

        // Parse JSON-RPC request
        guard let requestData = requestStr.data(using: .utf8),
              let request = try? JSONDecoder().decode(SocketRequest.self, from: requestData) else {
            sendError(fd, id: nil, code: -32700, message: "Parse error")
            return
        }

        // Handle workspace.list with raw JSON (AnyCodable can't encode [[String:String]])
        if request.method == "workspace.list" {
            let raw = handleWorkspaceList(id: request.id)
            let bytes = Array(raw.utf8)
            _ = write(fd, bytes, bytes.count)
            return
        }

        // Route to handler
        let response = handleRequest(request)

        // Send response
        if let responseData = try? JSONEncoder().encode(response),
           let responseStr = String(data: responseData, encoding: .utf8) {
            let bytes = Array(responseStr.utf8)
            _ = write(fd, bytes, bytes.count)
        }
    }

    /// Handle workspace.list specially (returns raw JSON)
    private func handleWorkspaceList(id: Int?) -> String {
        let items = workspaceManager.workspaces.map { ws -> String in
            let active = ws.id == workspaceManager.activeWorkspace?.id
            let escapedTitle = ws.title.replacingOccurrences(of: "\"", with: "\\\"")
            let escapedCwd = ws.cwd.replacingOccurrences(of: "\"", with: "\\\"")
            return "{\"id\":\"\(ws.id)\",\"title\":\"\(escapedTitle)\",\"cwd\":\"\(escapedCwd)\",\"active\":\"\(active)\",\"hasUnread\":\"\(ws.hasUnread)\"}"
        }
        return "{\"jsonrpc\":\"2.0\",\"id\":\(id ?? 0),\"result\":[\(items.joined(separator: ","))]}"
    }

    /// Route a request to the appropriate handler
    private func handleRequest(_ request: SocketRequest) -> SocketResponse {
        let id = request.id

        switch request.method {
        case "system.identify":
            return successResponse(id: id, result: [
                "app": "cmux-linux",
                "version": "0.1.0",
                "platform": "linux",
                "pid": String(ProcessInfo.processInfo.processIdentifier),
            ])

        case "workspace.list":
            // Use raw JSON to avoid AnyCodable array serialization issues
            return SocketResponse(jsonrpc: "2.0", result: AnyCodable("__RAW__"), error: nil, id: id)

        case "workspace.create":
            // Schedule workspace creation on GTK main thread
            let dir = request.params?["directory"]
            pendingCreateDir = request.params?["directory"]
            pendingCreateTitle = request.params?["title"]
            g_idle_add({ _ -> gboolean in
                if let gApp = getGhosttyApp() {
                    _ = workspaceManager.createWorkspace(
                        ghosttyApp: gApp,
                        workingDirectory: pendingCreateDir,
                        title: pendingCreateTitle)
                }
                pendingCreateDir = nil
                pendingCreateTitle = nil
                return 0
            }, nil)
            return successResponse(id: id, result: ["ok": "true"])

        case "workspace.select":
            if let indexStr = request.params?["index"], let index = Int(indexStr) {
                pendingSelectIndex = index - 1
                g_idle_add({ _ -> gboolean in
                    workspaceManager.switchTo(index: pendingSelectIndex)
                    return 0
                }, nil)
                return successResponse(id: id, result: ["ok": "true"])
            }
            return errorResponse(id: id, code: -32602, message: "Missing 'index' parameter")

        case "workspace.close":
            pendingSocketAction = { workspaceManager.closeActive() }
            g_idle_add({ _ -> gboolean in
                pendingSocketAction?(); pendingSocketAction = nil; return 0
            }, nil)
            return successResponse(id: id, result: ["ok": "true"])

        case "workspace.split":
            let orientation = request.params?["orientation"] ?? "horizontal"
            let orient: PaneSplit.SplitOrientation = orientation == "vertical" ? .vertical : .horizontal
            pendingSocketAction = { workspaceManager.splitActivePane(orientation: orient) }
            g_idle_add({ _ -> gboolean in
                pendingSocketAction?(); pendingSocketAction = nil; return 0
            }, nil)
            return successResponse(id: id, result: ["ok": "true"])

        case "surface.send_text":
            if let text = request.params?["text"] {
                let hasSurface = workspaceManager.activeSurface != nil
                cmuxLog("[socket] send_text: \(text.prefix(40).debugDescription) surface=\(hasSurface)")
                pendingSendText = text
                g_idle_add({ _ -> gboolean in
                    if let t = pendingSendText {
                        if getGhosttyApp() == nil {
                            cmuxLog("[socket] send_text: ghosttyApp is nil!")
                        }
                        getGhosttyApp()?.sendText(t)
                        pendingSendText = nil
                    }
                    return 0
                }, nil)
                return successResponse(id: id, result: ["ok": "true", "surface": hasSurface ? "true" : "false"])
            }
            return errorResponse(id: id, code: -32602, message: "Missing 'text' parameter")

        case "surface.pty_write":
            // Direct PTY write — bypasses ghostty IO thread for E2E testing
            if let text = request.params?["text"] {
                var fd = workspaceManager.activePtyFd
                // If no fd assigned yet, rescan (PTY opens asynchronously after surface creation)
                if fd < 0 {
                    workspaceManager.rescanPtyFds()
                    fd = workspaceManager.activePtyFd
                }
                if fd >= 0 {
                    let bytes = Array(text.utf8)
                    let written = write(fd, bytes, bytes.count)
                    cmuxLog("[socket] pty_write: fd=\(fd) wrote=\(written) bytes to PTY master")
                    return successResponse(id: id, result: ["ok": "true", "fd": String(fd), "written": String(written)])
                }
                return errorResponse(id: id, code: -32000, message: "No PTY master fd for active workspace")
            }
            return errorResponse(id: id, code: -32602, message: "Missing 'text' parameter")

        case "surface.send_key":
            if let key = request.params?["key"], let surface = workspaceManager.activeSurface {
                // Send text that includes control characters
                getGhosttyApp()?.sendText(key)
                return successResponse(id: id, result: ["ok": "true"])
            }
            return errorResponse(id: id, code: -32602, message: "Missing 'key' parameter")

        case "system.ready":
            let hasSurface = workspaceManager.activeSurface != nil
            let wsCount = workspaceManager.workspaces.count
            return successResponse(id: id, result: [
                "ready": hasSurface ? "true" : "false",
                "surface": hasSurface ? "true" : "false",
                "workspaces": String(wsCount),
            ])

        case "surface.size":
            // Return the ghostty surface's actual grid/pixel dimensions
            if let surface = workspaceManager.activeSurface,
               let gApp = getGhosttyApp(),
               let glArea = workspaceManager.activeWorkspace?.glArea {
                let widget = unsafeBitCast(glArea, to: UnsafeMutablePointer<GtkWidget>.self)
                let gtkW = gtk_widget_get_width(widget)
                let gtkH = gtk_widget_get_height(widget)
                return successResponse(id: id, result: [
                    "gtk_width": String(gtkW),
                    "gtk_height": String(gtkH),
                    "surface": "true",
                ])
            }
            return successResponse(id: id, result: ["surface": "false"])

        case "system.status":
            let ws = workspaceManager.workspaces
            let active = workspaceManager.activeWorkspace
            return SocketResponse(jsonrpc: "2.0", result: AnyCodable([
                "workspaces": String(ws.count),
                "active_workspace": active.map { String($0.id) } ?? "none",
                "active_title": active?.title ?? "",
                "active_cwd": active?.cwd ?? "",
                "active_branch": active?.gitBranch ?? "",
                "has_browser": activeBrowserWebView != nil ? "true" : "false",
                "socket": socketServer?.socketPath ?? "",
                "pid": String(ProcessInfo.processInfo.processIdentifier),
            ]), error: nil, id: id)

        case "browser.snapshot":
            // Get a simplified DOM structure for AI agents
            let js = """
            (function() {
                function snap(el, depth) {
                    if (depth > 4) return null;
                    var tag = el.tagName ? el.tagName.toLowerCase() : '#text';
                    var result = {tag: tag};
                    if (el.id) result.id = el.id;
                    if (el.className && typeof el.className === 'string') result.class = el.className.split(' ').slice(0,3).join(' ');
                    if (el.textContent && !el.children.length) result.text = el.textContent.slice(0,100);
                    if (el.href) result.href = el.href;
                    if (el.src) result.src = el.src;
                    if (el.children && el.children.length > 0) {
                        result.children = Array.from(el.children).slice(0,20).map(c => snap(c, depth+1)).filter(x => x);
                    }
                    return result;
                }
                return JSON.stringify(snap(document.body, 0));
            })()
            """
            pendingSocketAction = { evaluateJavaScriptInBrowser(js) }
            g_idle_add({ _ -> gboolean in
                pendingSocketAction?(); pendingSocketAction = nil; return 0
            }, nil)
            return successResponse(id: id, result: ["ok": "true", "note": "DOM snapshot sent to browser eval"])

        case "window.resize":
            if let wStr = request.params?["width"], let hStr = request.params?["height"],
               let w = Int32(wStr), let h = Int32(hStr) {
                let width = w
                let height = h
                pendingResizeW = width
                pendingResizeH = height
                g_idle_add({ _ -> gboolean in
                    if let win = workspaceManager.window {
                        gtk_window_set_default_size(win, pendingResizeW, pendingResizeH)
                        // Also try direct widget size
                        let widget = unsafeBitCast(win, to: UnsafeMutablePointer<GtkWidget>.self)
                        gtk_widget_set_size_request(widget, pendingResizeW, pendingResizeH)
                    }
                    return 0
                }, nil)
                return successResponse(id: id, result: ["ok": "true"])
            }
            return errorResponse(id: id, code: -32602, message: "Missing width/height")

        case "browser.eval":
            // Execute JavaScript in the browser panel
            let js = request.params?["script"] ?? ""
            if !js.isEmpty {
                pendingSocketAction = { evaluateJavaScriptInBrowser(js) }
                g_idle_add({ _ -> gboolean in
                    pendingSocketAction?(); pendingSocketAction = nil; return 0
                }, nil)
                return successResponse(id: id, result: ["ok": "true"])
            }
            return errorResponse(id: id, code: -32602, message: "Missing 'script' parameter")

        case "browser.navigate":
            let url = request.params?["url"] ?? ""
            if !url.isEmpty {
                pendingSocketAction = { navigateBrowser(url) }
                g_idle_add({ _ -> gboolean in
                    pendingSocketAction?(); pendingSocketAction = nil; return 0
                }, nil)
                return successResponse(id: id, result: ["ok": "true"])
            }
            return errorResponse(id: id, code: -32602, message: "Missing 'url' parameter")

        case "browser.open":
            let url = request.params?["url"] ?? "https://google.com"
            pendingSocketAction = { openBrowserInSplit(url: url) }
            g_idle_add({ _ -> gboolean in
                pendingSocketAction?(); pendingSocketAction = nil; return 0
            }, nil)
            return successResponse(id: id, result: ["ok": "true"])

        case "notify":
            let title = request.params?["title"] ?? ""
            let body = request.params?["body"] ?? ""
            workspaceManager.notifyActive(title: title, body: body)
            return successResponse(id: id, result: ["ok": "true"])

        default:
            return errorResponse(id: id, code: -32601, message: "Method not found: \(request.method)")
        }
    }

    private func successResponse(id: Int?, result: [String: String]) -> SocketResponse {
        SocketResponse(jsonrpc: "2.0", result: AnyCodable(result), error: nil, id: id)
    }

    private func errorResponse(id: Int?, code: Int, message: String) -> SocketResponse {
        SocketResponse(jsonrpc: "2.0", result: nil,
                       error: .init(code: code, message: message), id: id)
    }

    private func sendError(_ fd: Int32, id: Int?, code: Int, message: String) {
        let response = errorResponse(id: id, code: code, message: message)
        if let data = try? JSONEncoder().encode(response),
           let str = String(data: data, encoding: .utf8) {
            let bytes = Array(str.utf8)
            _ = write(fd, bytes, bytes.count)
        }
    }
}

/// Global socket server
var socketServer: SocketControlServer?
/// Pending action to execute on GTK main thread
var pendingSocketAction: (() -> Void)?
/// Stored params for workspace creation (closures can't capture in @convention(c))
var pendingCreateDir: String?
var pendingCreateTitle: String?
var pendingSelectIndex: Int = 0
var pendingSendText: String?
