import AppKit
import OSLog
import WebKit

private let sourceURL = URL(string: "https://cryptobubbles.net/zh")!
private let logger = Logger(
    subsystem: "net.cryptobubbles.wallpaper",
    category: "runtime"
)
private let debugWindowEnabled =
    CommandLine.arguments.contains("--debug-window") ||
    ProcessInfo.processInfo.environment["CB_DEBUG_WINDOW"] == "1"
private let adResponseUserScript = WKUserScript(
    source: #"""
(() => {
  const nativeFetch = window.fetch.bind(window);
  const emptyAds = {
    banner_topbar: [],
    banner_searchresults: [],
    banner_coinlistrow: [],
    banner_mobilecoindetails: [],
    bubble: [],
    bubbleDetails: [],
    exchangeTradeLink: []
  };

  window.fetch = function(input, init) {
    let requestURL;
    try {
      const request = input instanceof Request ? input.url : String(input);
      requestURL = new URL(request, location.href);
    } catch (_) {
      return nativeFetch(input, init);
    }

    if (requestURL.origin === location.origin && requestURL.pathname === "/backend/ads.php") {
      return Promise.resolve(new Response(JSON.stringify(emptyAds), {
        status: 200,
        headers: {"Content-Type": "application/json"}
      }));
    }

    return nativeFetch(input, init);
  };
})();
"""#,
    injectionTime: .atDocumentStart,
    forMainFrameOnly: true
)

@MainActor
private final class WallpaperCoordinator: NSObject, WKNavigationDelegate {
    private var windows: [NSWindow] = []
    private var webViews: [WKWebView] = []
    private weak var statusItem: NSStatusItem?
    private weak var statusMenuItem: NSMenuItem?
    private var retryTimer: Timer?
    private var pendingScreenRebuild: DispatchWorkItem?
    private var screenConfigurationSignature: String?

    func attachStatusItem(_ statusItem: NSStatusItem, statusMenuItem: NSMenuItem) {
        self.statusItem = statusItem
        self.statusMenuItem = statusMenuItem
    }

    func start() {
        screenConfigurationSignature = currentScreenConfigurationSignature()
        createWindows()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadAfterWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        updateStatus("连接 Crypto Bubbles…")
    }

    func reloadAll() {
        retryTimer?.invalidate()
        retryTimer = nil
        updateStatus("重新连接 Crypto Bubbles…")
        webViews.forEach { $0.reload() }
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        pendingScreenRebuild?.cancel()
        pendingScreenRebuild = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        webViews.removeAll()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }
        guard
            let url = navigationAction.request.url,
            url.host == sourceURL.host
        else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        retryTimer?.invalidate()
        retryTimer = nil
        logger.info("Navigation finished: \(webView.url?.absoluteString ?? "nil", privacy: .public)")
        updateStatus("官网页面已加载")
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        logger.info("Navigation committed: \(webView.url?.absoluteString ?? "nil", privacy: .public)")
        webView.evaluateJavaScript(
            "JSON.stringify({readyState:document.readyState,title:document.title,canvas:document.querySelectorAll('canvas').length,chart:document.querySelectorAll('.bubble-chart').length,bodyHeight:document.body?.scrollHeight})"
        ) { result, error in
            if let error {
                logger.error("DOM probe failed: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("DOM probe: \(String(describing: result), privacy: .public)")
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        logger.error("Navigation failed: \(error.localizedDescription, privacy: .public)")
        scheduleRetry()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        logger.error("Provisional navigation failed: \(error.localizedDescription, privacy: .public)")
        scheduleRetry()
    }

    @objc private func screenParametersDidChange() {
        let signature = currentScreenConfigurationSignature()
        guard signature != screenConfigurationSignature else {
            logger.debug("Ignoring screen parameter change without a display configuration change")
            return
        }

        screenConfigurationSignature = signature
        pendingScreenRebuild?.cancel()
        let rebuild = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingScreenRebuild = nil
            logger.info("Display configuration changed; rebuilding wallpaper windows")
            self.createWindows()
        }
        pendingScreenRebuild = rebuild
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: rebuild)
    }

    @objc private func reloadAfterWake() {
        reloadAll()
    }

    private func createWindows() {
        guard !NSScreen.screens.isEmpty else { return }

        stop()
        let debugWindow = debugWindowEnabled
        for screen in NSScreen.screens {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .default()
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            configuration.userContentController.addUserScript(adResponseUserScript)
            let screenSize = screen.frame.size
            let cropHeight: CGFloat = screenSize.width < 1099 ? 90 : 99
            let webView = WKWebView(
                frame: NSRect(
                    x: 0,
                    y: 0,
                    width: screenSize.width,
                    height: screenSize.height + cropHeight
                ),
                configuration: configuration
            )
            webView.autoresizingMask = [.width]
            webView.navigationDelegate = self
            webView.setValue(false, forKey: "drawsBackground")
            webView.wantsLayer = true
            webView.layer?.backgroundColor = NSColor.black.cgColor

            let clipView = NSView(
                frame: NSRect(origin: .zero, size: screenSize)
            )
            clipView.wantsLayer = true
            clipView.layer?.backgroundColor = NSColor.black.cgColor
            clipView.layer?.masksToBounds = true
            clipView.addSubview(webView)

            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            window.ignoresMouseEvents = !debugWindow
            window.level = debugWindow
                ? .normal
                : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            window.collectionBehavior = debugWindow
                ? [.fullScreenAuxiliary]
                : [.canJoinAllSpaces, .stationary, .ignoresCycle]
            window.contentView = clipView
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()

            windows.append(window)
            webViews.append(webView)
            webView.load(
                URLRequest(
                    url: sourceURL,
                    cachePolicy: .reloadRevalidatingCacheData,
                    timeoutInterval: 30
                )
            )
        }
    }

    private func currentScreenConfigurationSignature() -> String {
        // Dock visibility changes visibleFrame, not the physical display configuration.
        NSScreen.screens.map { screen in
            let displayID = (
                screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            )?.stringValue ?? screen.localizedName
            let frame = screen.frame
            return "\(displayID):\(NSStringFromRect(frame)):\(screen.backingScaleFactor)"
        }
        .sorted()
        .joined(separator: "|")
    }

    private func scheduleRetry() {
        updateStatus("官网暂时不可用，30 秒后重试…")
        retryTimer?.invalidate()
        retryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadAll()
            }
        }
    }

    private func updateStatus(_ message: String) {
        statusMenuItem?.title = message
    }

}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = WallpaperCoordinator()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(debugWindowEnabled ? .regular : .accessory)
        configureStatusItem()
        coordinator.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func reloadWallpaper() {
        coordinator.reloadAll()
    }

    @objc private func quitApplication() {
        coordinator.stop()
        NSApp.terminate(nil)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "chart.line.uptrend.xyaxis.circle.fill",
            accessibilityDescription: "Crypto Bubbles"
        )
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "Crypto Bubbles 壁纸"

        let menu = NSMenu()
        let status = NSMenuItem(title: "连接官网行情…", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let reload = NSMenuItem(
            title: "立即刷新",
            action: #selector(reloadWallpaper),
            keyEquivalent: "r"
        )
        reload.target = self
        menu.addItem(reload)

        let quit = NSMenuItem(
            title: "退出壁纸",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
        coordinator.attachStatusItem(item, statusMenuItem: status)
    }
}

@main
@MainActor
private enum CryptoBubblesWallpaperApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
