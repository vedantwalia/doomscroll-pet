import AppKit
import SwiftUI
import SafariServices
import Combine
import CoreGraphics

@main
struct DoomscrollPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A menu-bar scene gives the accessory app a real control surface
        // without SwiftUI creating a blank document window at launch.
        MenuBarExtra("Doomscroll Pet", systemImage: "cat.fill") {
            Button("Settings…") { appDelegate.showSettings() }
            Divider()
            Button("Quit Doomscroll Pet") { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var petPanel: NSPanel?
    private var settingsPanel: NSPanel?
    private var warningPanel: NSPanel?
    private var warningTabID: Int?
    private let petModel = PetAnimationModel()
    private var warningPoll: Timer?
    private var lastWarningTimestamp: Double = 0
    private var lastApproachTimestamp: Double = 0
    private var lastHideTimestamp: Double = 0
    private var lastSpriteTestTimestamp: Double = 0
    private var pendingSpriteTestTimestamp: Double = 0
    private var spriteTestHideTask: Task<Void, Never>?
    private let appGroupIdentifier = "group.com.vedantwalia.DoomscrollPet"
    private let extensionBundleIdentifier = "com.vedantwalia.DoomscrollPet.Extension"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let size = NSSize(width: 128, height: 128)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.contentView = NSHostingView(rootView: FloatingPetView(model: petModel))
        petModel.panelMover = { [weak panel] origin in
            panel?.setFrameOrigin(origin)
        }
        petModel.openSettings = { [weak self] in self?.showSettings() }
        petModel.setFloating = { [weak panel] isFloating in
            panel?.level = isFloating ? .floating : .normal
            panel?.isFloatingPanel = isFloating
        }
        petModel.setVisible = { [weak panel] isVisible in
            if isVisible { panel?.orderFrontRegardless() }
            else { panel?.orderOut(nil) }
        }
        petModel.setFloating?(petModel.alwaysOnTop)
        startWarningPolling()

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: visibleFrame.minX - size.width, y: visibleFrame.minY + 16))
        }

        panel.orderOut(nil)
        petPanel = panel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func startWarningPolling() {
        warningPoll?.invalidate()
        warningPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.checkForSafariWarning() }
        }
    }

    private func checkForSafariWarning() async {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        let now = Date().timeIntervalSince1970
        defaults.set(now, forKey: "app.lastHeartbeat")

        let hideTimestamp = defaults.double(forKey: "approach.hideTimestamp")
        let approachTimestamp = defaults.double(forKey: "approach.timestamp")
        if approachTimestamp > lastApproachTimestamp,
           approachTimestamp > hideTimestamp,
           now - approachTimestamp < 60,
           let domain = defaults.string(forKey: "approach.domain") {
            lastApproachTimestamp = approachTimestamp
            await petModel.enterScreen(near: safariTabBarOrigin())
            NSLog("Doomscroll Pet is approaching for %@", domain)
        }

        if hideTimestamp > lastHideTimestamp {
            lastHideTimestamp = hideTimestamp
            // App Group defaults persist across launches. Ignore a previous
            // visit's hide event when a newer approach event is already active.
            if hideTimestamp >= approachTimestamp {
                let hiddenTabID = defaults.integer(forKey: "approach.hideTabId")
                if defaults.integer(forKey: "warning.tabId") == hiddenTabID {
                    defaults.removeObject(forKey: "warning.domain")
                    defaults.removeObject(forKey: "warning.timestamp")
                }
                if warningTabID == hiddenTabID {
                    warningTabID = nil
                    warningPanel?.close()
                    warningPanel = nil
                    dispatchSafariResponse("doomscroll.dismiss", tabID: hiddenTabID)
                }
                petModel.walkOffscreen()
            }
        }

        let spriteTestTimestamp = defaults.double(forKey: "spriteTest.timestamp")
        if spriteTestTimestamp > lastSpriteTestTimestamp {
            lastSpriteTestTimestamp = spriteTestTimestamp
            if now - spriteTestTimestamp <= 60 {
                pendingSpriteTestTimestamp = spriteTestTimestamp
            }
        }
        if pendingSpriteTestTimestamp > 0 {
            let delay = max(1, min(defaults.integer(forKey: "spriteTest.delaySeconds"), 60))
            if now - pendingSpriteTestTimestamp >= Double(delay) {
                pendingSpriteTestTimestamp = 0
                defaults.removeObject(forKey: "spriteTest.timestamp")
                NSLog("Doomscroll Pet sprite test: entering after %d seconds", delay)
                if petModel.isOnScreen {
                    await petModel.walkOffscreenAndWait()
                }
                await petModel.enterScreen(near: safariTabBarOrigin())
                spriteTestHideTask?.cancel()
                spriteTestHideTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    guard !Task.isCancelled, let self else { return }
                    if self.warningTabID == nil {
                        await self.petModel.walkOffscreenAndWait()
                    }
                    self.spriteTestHideTask = nil
                }
            }
        }

        guard let domain = defaults.string(forKey: "warning.domain") else { return }
        let timestamp = defaults.double(forKey: "warning.timestamp")
        guard timestamp > lastWarningTimestamp, now - timestamp < 30 else { return }

        lastWarningTimestamp = timestamp
        let tabID = defaults.integer(forKey: "warning.tabId")
        let minutes = defaults.integer(forKey: "warning.thresholdMinutes")
        defaults.removeObject(forKey: "warning.domain")
        defaults.removeObject(forKey: "warning.timestamp")
        if !petModel.isOnScreen {
            await petModel.enterScreen(near: safariTabBarOrigin())
        } else {
            await petModel.waitForEntrance()
        }
        presentSafariWarning(domain: domain, tabID: tabID, minutes: max(minutes, 1))
    }

    private func safariTabBarOrigin() -> NSPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? .zero
        let fallback = NSPoint(x: visible.maxX - 180, y: visible.maxY - 190)
        guard let screen,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let safariWindow = windows.first(where: {
                  ($0[kCGWindowOwnerName as String] as? String) == "Safari"
                      && ($0[kCGWindowLayer as String] as? Int ?? 1) == 0
              }),
              let bounds = safariWindow[kCGWindowBounds as String] as? NSDictionary,
              let quartzFrame = CGRect(dictionaryRepresentation: bounds) else { return fallback }

        let appKitTop = screen.frame.maxY - quartzFrame.minY
        let x = min(max(visible.minX + 24, quartzFrame.minX + quartzFrame.width * 0.72), visible.maxX - 128)
        let y = min(max(visible.minY + 24, appKitTop - 118), visible.maxY - 128)
        return NSPoint(x: x, y: y)
    }

    private func presentSafariWarning(domain: String, tabID: Int, minutes: Int) {
        warningTabID = tabID
        let size = NSSize(width: 360, height: 176)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "A gentle pause"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: SafariWarningView(
            domain: domain,
            minutes: minutes,
            keepBrowsing: { [weak self] in self?.respondToWarning(closeTab: false) },
            closeTab: { [weak self] in self?.respondToWarning(closeTab: true) }
        ))

        if let petFrame = petPanel?.frame, let screen = petPanel?.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            let x = min(max(visible.minX + 12, petFrame.maxX - size.width), visible.maxX - size.width - 12)
            let y = min(petFrame.maxY + 10, visible.maxY - size.height - 12)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }

        let previousWarningPanel = warningPanel
        warningPanel = panel
        previousWarningPanel?.close()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func respondToWarning(closeTab: Bool) {
        guard let tabID = warningTabID else { return }
        warningTabID = nil
        warningPanel?.close()
        let message = closeTab ? "doomscroll.confirm-close" : "doomscroll.dismiss"
        if closeTab {
            Task { @MainActor in
                await petModel.playTabCloseGesture()
                dispatchSafariResponse(message, tabID: tabID)
                await petModel.walkOffscreenAndWait()
            }
        } else {
            dispatchSafariResponse(message, tabID: tabID)
            petModel.walkOffscreen()
        }
    }

    private func dispatchSafariResponse(_ message: String, tabID: Int) {
        SFSafariApplication.dispatchMessage(
            withName: message,
            toExtensionWithIdentifier: extensionBundleIdentifier,
            userInfo: ["tabId": tabID]
        ) { error in
            if let error {
                NSLog("Doomscroll Pet could not send the Safari response: %@", error.localizedDescription)
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow, panel === warningPanel,
              let tabID = warningTabID else { return }
        warningTabID = nil
        dispatchSafariResponse("doomscroll.dismiss", tabID: tabID)
        warningPanel = nil
        petModel.walkOffscreen()
    }

    func showSettings() {
        if let settingsPanel {
            settingsPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Doomscroll Pet Settings"
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: PetSettingsView(model: petModel))
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsPanel = panel
    }
}

private struct SafariWarningView: View {
    let domain: String
    let minutes: Int
    let keepBrowsing: () -> Void
    let closeTab: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You’ve been on \(domain) for about \(minutes) minutes.")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text("Want to take a short break?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Button("Keep browsing", action: keepBrowsing)
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Button("Close tab", role: .destructive, action: closeTab)
            }
        }
        .padding(18)
        .frame(width: 360, height: 128, alignment: .center)
    }
}

private struct FloatingPetView: View {
    @ObservedObject var model: PetAnimationModel

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: model.displayPose, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .accessibilityLabel("Doomscroll Pet, a pixel cat")
            } else {
                Image(systemName: "cat.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Doomscroll Pet")
            }
        }
        .frame(width: 112, height: 112)
        .contentShape(Rectangle())
        .overlay {
            PetDragHandle(
                onTap: { model.playGreeting() },
                onMove: { model.movePanel(to: $0) }
            )
        }
        .onAppear { model.startIdleAnimation() }
        .contextMenu {
            Button("Play greeting") { model.playGreeting() }
            Button("Settings…") { model.openSettings?() }
            Button("Reset to screen corner") { model.resetPosition() }
            Divider()
            Button("Quit Doomscroll Pet") { NSApp.terminate(nil) }
        }
    }
}

private struct PetDragHandle: NSViewRepresentable {
    let onTap: () -> Void
    let onMove: (NSPoint) -> Void

    func makeNSView(context: Context) -> PetDragNSView {
        let view = PetDragNSView()
        view.onTap = onTap
        view.onMove = onMove
        return view
    }

    func updateNSView(_ view: PetDragNSView, context: Context) {
        view.onTap = onTap
        view.onMove = onMove
    }
}

private struct PetSettingsView: View {
    @ObservedObject var model: PetAnimationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Cat sprite", selection: $model.selectedSprite) {
                Text("Classic").tag("idle")
                Text("Sleepy").tag("sleep")
                Text("Walking").tag("walk1")
                Text("Celebrating").tag("celebrate")
            }
            .pickerStyle(.menu)
            Toggle("Gentle idle animation", isOn: $model.idleAnimationEnabled)
            Toggle("Keep cat above other windows", isOn: $model.alwaysOnTop)
            Divider()
            HStack {
                Button("Reset position") { model.resetPosition() }
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320, height: 228)
    }
}

private final class PetDragNSView: NSView {
    var onTap: (() -> Void)?
    var onMove: ((NSPoint) -> Void)?
    private var startScreenPoint = NSPoint.zero
    private var startWindowOrigin = NSPoint.zero
    private var didMove = false

    override var isOpaque: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: didMove ? .closedHand : .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        startScreenPoint = window.convertPoint(toScreen: event.locationInWindow)
        startWindowOrigin = window.frame.origin
        didMove = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard window != nil else { return }
        let current = window!.convertPoint(toScreen: event.locationInWindow)
        let dx = current.x - startScreenPoint.x
        let dy = current.y - startScreenPoint.y
        guard hypot(dx, dy) > 3 else { return }
        didMove = true
        onMove?(NSPoint(x: startWindowOrigin.x + dx, y: startWindowOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if !didMove { onTap?() }
        didMove = false
    }
}

@MainActor
private final class PetAnimationModel: ObservableObject {
    @Published var pose = "idle"
    @Published var idleFrame = 1
    @Published var travelFrame = 1
    private(set) var isOnScreen = false
    private var isLeavingAfterAction = false
    @Published var selectedSprite = UserDefaults.standard.string(forKey: "selectedSprite") ?? "idle" {
        didSet {
            UserDefaults.standard.set(selectedSprite, forKey: "selectedSprite")
            updateIdleAnimation()
        }
    }
    @Published var idleAnimationEnabled = UserDefaults.standard.object(forKey: "idleAnimationEnabled") == nil
        || UserDefaults.standard.bool(forKey: "idleAnimationEnabled") {
        didSet {
            UserDefaults.standard.set(idleAnimationEnabled, forKey: "idleAnimationEnabled")
            updateIdleAnimation()
        }
    }
    @Published var alwaysOnTop = UserDefaults.standard.object(forKey: "alwaysOnTop") == nil
        || UserDefaults.standard.bool(forKey: "alwaysOnTop") {
        didSet {
            UserDefaults.standard.set(alwaysOnTop, forKey: "alwaysOnTop")
            setFloating?(alwaysOnTop)
        }
    }
    private var animationTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var travelTask: Task<Void, Never>?
    private var lastPanelOrigin = NSPoint.zero
    var panelMover: ((NSPoint) -> Void)?
    var openSettings: (() -> Void)?
    var setFloating: ((Bool) -> Void)?
    var setVisible: ((Bool) -> Void)?

    var displayPose: String {
        if pose == "oneko-walk-right" || pose == "oneko-walk-up" || pose == "oneko-exit" {
            return "\(pose)-\(travelFrame)"
        }
        guard pose == "idle" else { return pose }
        if selectedSprite == "idle", idleAnimationEnabled {
            return "idle-loop-\(idleFrame)"
        }
        if selectedSprite == "walk1", idleAnimationEnabled {
            return "walk\((idleFrame - 1) % 3 + 1)"
        }
        return selectedSprite
    }

    func startIdleAnimation() {
        updateIdleAnimation()
    }

    private func updateIdleAnimation() {
        idleTask?.cancel()
        idleTask = nil
        idleFrame = 1
        guard idleAnimationEnabled, selectedSprite == "idle" || selectedSprite == "walk1" else { return }

        idleTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 320_000_000)
                guard !Task.isCancelled else { break }
                let frameCount = selectedSprite == "walk1" ? 3 : 4
                idleFrame = idleFrame % frameCount + 1
            }
            idleTask = nil
        }
    }

    func movePanel(to origin: NSPoint) {
        lastPanelOrigin = origin
        panelMover?(origin)
    }

    func enterScreen(near target: NSPoint) async {
        travelTask?.cancel()
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        isOnScreen = true
        isLeavingAfterAction = false
        setVisible?(true)
        let visible = screen.visibleFrame
        let start = NSPoint(x: visible.minX - 128, y: visible.minY + 16)
        movePanel(to: start)
        let corner = NSPoint(x: target.x, y: start.y)

        travelTask = Task { @MainActor in
            await animateLeg(from: start, to: corner, poseName: "oneko-walk-right")
            guard !Task.isCancelled else { return }
            await animateLeg(from: corner, to: target, poseName: "oneko-walk-up")
            guard !Task.isCancelled else { return }
            pose = "idle"
            travelTask = nil
        }
        await travelTask?.value
    }

    func waitForEntrance() async {
        await travelTask?.value
    }

    func walkOffscreen() {
        guard isOnScreen, !isLeavingAfterAction else { return }
        isLeavingAfterAction = true
        travelTask?.cancel()
        travelTask = Task { @MainActor in await animateOffscreenAndHide() }
    }

    func playTabCloseGesture() async {
        isLeavingAfterAction = true
        travelTask?.cancel()
        for frame in 1...4 {
            guard !Task.isCancelled else { return }
            pose = "oneko-exit"
            travelFrame = frame
            try? await Task.sleep(nanoseconds: 180_000_000)
        }
    }

    func walkOffscreenAndWait() async {
        guard isOnScreen else { return }
        isLeavingAfterAction = true
        travelTask?.cancel()
        let task = Task { @MainActor in await animateOffscreenAndHide() }
        travelTask = task
        await task.value
    }

    private func animateOffscreenAndHide() async {
        guard isOnScreen else { return }
        let target = NSPoint(
            x: (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.maxX ?? lastPanelOrigin.x + 900,
            y: lastPanelOrigin.y
        )
        await animateLeg(from: lastPanelOrigin, to: target, poseName: "oneko-walk-right")
        guard !Task.isCancelled else { return }
        isOnScreen = false
        pose = "idle"
        setVisible?(false)
        travelTask = nil
        isLeavingAfterAction = false
    }

    private func animateLeg(from start: NSPoint, to end: NSPoint, poseName: String) async {
        let distance = hypot(end.x - start.x, end.y - start.y)
        let steps = max(1, Int(distance / 9))
        pose = poseName
        for step in 0...steps {
            guard !Task.isCancelled else { return }
            let progress = CGFloat(step) / CGFloat(steps)
            let position = NSPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
            travelFrame = (step / 6) % 4 + 1
            movePanel(to: position)
            try? await Task.sleep(nanoseconds: 32_000_000)
        }
    }

    func resetPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        panelMover?(NSPoint(x: screen.visibleFrame.maxX - 148, y: screen.visibleFrame.minY + 16))
    }

    func playGreeting() {
        animationTask?.cancel()
        pose = "jump"
        animationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            pose = "celebrate"
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            pose = "idle"
        }
    }
}
