import Foundation
import OSLog

/// Debug logging for device runs. Filter Xcode Console by subsystem **Tocco** or text **`[Tocco:`**.
enum ToccoDebug {
    private static let subsystem = "Tocco"
    private static let log = Logger(subsystem: subsystem, category: "app")

    private static var lastThrottled: [String: TimeInterval] = [:]
    private static let throttleLock = NSLock()
    private static var didLogConsoleNoiseHint = false
    private static var didLogContentViewAppear = false

    static func info(_ category: String, _ message: String) {
        let line = "[Tocco:\(category)] \(message)"
        log.info("\(line, privacy: .public)")
        print(line)
    }

    static func warn(_ category: String, _ message: String) {
        let line = "[Tocco:\(category)] ⚠️ \(message)"
        log.warning("\(line, privacy: .public)")
        print(line)
    }

    static func error(_ category: String, _ message: String) {
        let line = "[Tocco:\(category)] ❌ \(message)"
        log.error("\(line, privacy: .public)")
        print(line)
    }

    /// Prints at most once per `interval` seconds for each `key` (any thread).
    static func throttled(_ key: String, interval: TimeInterval, category: String, _ message: String) {
        let now = ProcessInfo.processInfo.systemUptime
        throttleLock.lock()
        defer { throttleLock.unlock() }
        if let last = lastThrottled[key], now - last < interval { return }
        lastThrottled[key] = now
        info(category, message)
    }

    /// Call from makeUIView; only prints once per process (SwiftUI may create ARView more than once).
    static func logConsoleNoiseHint() {
        throttleLock.lock()
        defer { throttleLock.unlock() }
        guard !didLogConsoleNoiseHint else { return }
        didLogConsoleNoiseHint = true
        info(
            "Help",
            "Many 'engine:…rematerial', 'BuiltinRenderGraphResources/AR', VideoLightSpill, and CoreMotion plist messages come from iOS AR/RealityKit, not from Tocco code. Use filter: subsystem:Tocco OR [Tocco:"
        )
    }

    static func logContentViewAppearOnce() {
        throttleLock.lock()
        defer { throttleLock.unlock() }
        guard !didLogContentViewAppear else { return }
        didLogContentViewAppear = true
        info("App", "ContentView appeared — look for [Tocco:…] lines; UI + camera means ARView is up")
    }
}
