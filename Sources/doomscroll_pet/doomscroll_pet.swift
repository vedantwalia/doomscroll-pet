import AppKit
import SwiftUI

@main
struct DoomscrollPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A menu-bar scene gives the accessory app a real control surface
        // without SwiftUI creating a blank document window at launch.
        MenuBarExtra("Doomscroll Pet", systemImage: "cat.fill") {
            Toggle("Oneko mode", isOn: appDelegate.onekoMode)
            Button("Settings…") { appDelegate.showSettings() }
            Divider()
            Button("Quit Doomscroll Pet") { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petPanel: NSPanel?
    private var settingsPanel: NSPanel?
    private let petModel = PetAnimationModel()
    var onekoMode: Binding<Bool> {
        Binding(get: { self.petModel.onekoMode }, set: { self.petModel.onekoMode = $0 })
    }

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
        petModel.setFloating?(petModel.alwaysOnTop)

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visibleFrame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: visibleFrame.maxX - size.width - 20,
                y: visibleFrame.minY + 16
            ))
        }

        panel.orderFrontRegardless()
        petPanel = panel
        petModel.startOnekoModeIfEnabled()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showSettings() {
        if let settingsPanel {
            settingsPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 280),
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

private struct FloatingPetView: View {
    @ObservedObject var model: PetAnimationModel

    var body: some View {
        Group {
            if let url = Bundle.module.url(forResource: model.displayPose, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .scaleEffect(x: model.facingLeft ? -1 : 1, y: 1)
                    .scaleEffect(model.selectedSprite == "dog" ? 0.8 : 1)
                    .accessibilityLabel(model.selectedSprite == "dog" ? "Doomscroll Pet, a pixel dog" : "Doomscroll Pet, a pixel cat")
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
                onMove: { model.dragPanel(to: $0) }
            )
        }
        .onAppear { model.startIdleAnimation() }
        .contextMenu {
            Button("Play greeting") { model.playGreeting() }
            Toggle("Oneko mode", isOn: $model.onekoMode)
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
            Picker("Companion", selection: $model.selectedSprite) {
                Text("Corgi").tag("dog")
                Text("Classic").tag("idle")
                Text("Sleepy").tag("sleep")
                Text("Walking").tag("walk1")
                Text("Celebrating").tag("celebrate")
            }
            .pickerStyle(.menu)
            Toggle("Gentle idle animation", isOn: $model.idleAnimationEnabled)
            Toggle("Keep companion above other windows", isOn: $model.alwaysOnTop)
            Toggle("Oneko mode: roam the desktop", isOn: $model.onekoMode)
            Text("Your companion wanders until Oneko mode is turned off.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            HStack {
                Button("Reset position") { model.resetPosition() }
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340, height: 280)
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
    @Published var facingLeft = false
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
    @Published var onekoMode = UserDefaults.standard.bool(forKey: "onekoMode") {
        didSet {
            UserDefaults.standard.set(onekoMode, forKey: "onekoMode")
            if onekoMode { startOnekoMode() }
            else { onekoTask?.cancel(); onekoTask = nil; pose = "idle"; facingLeft = false }
        }
    }
    private var animationTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?
    private var onekoTask: Task<Void, Never>?
    private var travelTask: Task<Void, Never>?
    private var lastPanelOrigin = NSPoint.zero
    var panelMover: ((NSPoint) -> Void)?
    var openSettings: (() -> Void)?
    var setFloating: ((Bool) -> Void)?

    var displayPose: String {
        if selectedSprite == "dog" {
            switch pose {
            case "oneko-walk-right": return "dog-walk-right-\(travelFrame)"
            case "oneko-walk-up": return "dog-walk-up-\(travelFrame)"
            case "oneko-walk-down": return "dog-walk-down-\(travelFrame)"
            default: return idleAnimationEnabled ? "dog-idle-loop-\(idleFrame)" : "dog-idle-loop-1"
            }
        }
        if ["oneko-walk-right", "oneko-walk-up", "oneko-walk-down"].contains(pose) {
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

    func startOnekoModeIfEnabled() {
        if onekoMode { startOnekoMode() }
    }

    private func updateIdleAnimation() {
        idleTask?.cancel()
        idleTask = nil
        idleFrame = 1
        guard idleAnimationEnabled, selectedSprite == "idle" || selectedSprite == "walk1" || selectedSprite == "dog" else { return }

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

    func dragPanel(to origin: NSPoint) {
        travelTask?.cancel()
        movePanel(to: origin)
    }

    func resetPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        movePanel(to: NSPoint(x: screen.visibleFrame.maxX - 148, y: screen.visibleFrame.minY + 16))
    }

    private func startOnekoMode() {
        if onekoTask != nil { return }
        travelTask?.cancel()
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        if lastPanelOrigin == .zero {
            movePanel(to: NSPoint(
                x: CGFloat.random(in: (visible.minX + 24)...max(visible.minX + 24, visible.maxX - 152)),
                y: CGFloat.random(in: (visible.minY + 16)...max(visible.minY + 16, visible.maxY - 144))
            ))
        }
        onekoTask = Task { @MainActor in
            while !Task.isCancelled && onekoMode {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.0...4.6) * 1_000_000_000))
                guard !Task.isCancelled, onekoMode else { break }
                if Int.random(in: 0..<7) == 0 {
                    pose = Bool.random() ? "sleep" : "celebrate"
                    try? await Task.sleep(nanoseconds: 1_100_000_000)
                    guard !Task.isCancelled else { break }
                    pose = "idle"
                }
                let screens = NSScreen.screens.isEmpty ? [screen] : NSScreen.screens
                let destinationScreen = screens.randomElement() ?? screen
                let frame = destinationScreen.visibleFrame
                let target = NSPoint(
                    x: CGFloat.random(in: (frame.minX + 24)...max(frame.minX + 24, frame.maxX - 152)),
                    y: CGFloat.random(in: (frame.minY + 16)...max(frame.minY + 16, frame.maxY - 144))
                )
                guard hypot(target.x - lastPanelOrigin.x, target.y - lastPanelOrigin.y) > 68 else { continue }
                let movement = Task { @MainActor in await walk(to: target, from: lastPanelOrigin) }
                travelTask = movement
                await movement.value
                travelTask = nil
                if !Task.isCancelled { pose = "idle"; facingLeft = false }
            }
            onekoTask = nil
        }
    }

    private func walk(to target: NSPoint, from origin: NSPoint) async {
        var current = origin
        if abs(target.x - current.x) > 3 {
            let next = NSPoint(x: target.x, y: current.y)
            facingLeft = target.x < current.x
            await animateLeg(from: current, to: next, poseName: "oneko-walk-right")
            current = next
        }
        guard !Task.isCancelled else { return }
        if abs(target.y - current.y) > 3 {
            facingLeft = false
            let pose = target.y > current.y ? "oneko-walk-up" : "oneko-walk-down"
            await animateLeg(from: current, to: NSPoint(x: current.x, y: target.y), poseName: pose)
        }
    }

    private func animateLeg(from start: NSPoint, to end: NSPoint, poseName: String) async {
        let steps = max(1, Int(hypot(end.x - start.x, end.y - start.y) / 8))
        pose = poseName
        for step in 0...steps {
            guard !Task.isCancelled else { return }
            let progress = CGFloat(step) / CGFloat(steps)
            movePanel(to: NSPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            ))
            travelFrame = (step / 6) % 4 + 1
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
    }

    func playGreeting() {
        animationTask?.cancel()
        if selectedSprite == "dog" {
            pose = "idle"
            return
        }
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
