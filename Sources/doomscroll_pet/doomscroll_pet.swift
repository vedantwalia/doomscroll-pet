import AppKit
import SwiftUI

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
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petPanel: NSPanel?
    private var settingsPanel: NSPanel?
    private let petModel = PetAnimationModel()

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
    @Published var selectedSprite = UserDefaults.standard.string(forKey: "selectedSprite") ?? "idle" {
        didSet { UserDefaults.standard.set(selectedSprite, forKey: "selectedSprite") }
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
    var panelMover: ((NSPoint) -> Void)?
    var openSettings: (() -> Void)?
    var setFloating: ((Bool) -> Void)?

    var displayPose: String {
        guard pose == "idle" else { return pose }
        if selectedSprite == "idle", idleAnimationEnabled {
            return "idle-loop-\(idleFrame)"
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
        guard idleAnimationEnabled else { return }

        idleTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 320_000_000)
                guard !Task.isCancelled else { break }
                idleFrame = idleFrame % 4 + 1
            }
            idleTask = nil
        }
    }

    func movePanel(to origin: NSPoint) {
        panelMover?(origin)
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
