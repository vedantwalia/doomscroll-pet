import AppKit
import SwiftUI

@main
struct DoomscrollPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The companion is presented by AppDelegate as a borderless panel.
        // Keeping a Settings scene gives the app a normal menu-bar lifecycle
        // without creating an extra window at launch.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petPanel: NSPanel?
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
}

private struct FloatingPetView: View {
    @ObservedObject var model: PetAnimationModel

    var body: some View {
        Group {
            if let url = Bundle.module.url(forResource: model.pose, withExtension: "png"),
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
        .offset(y: model.bobUp ? -2 : 1)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: model.bobUp)
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
    @Published var bobUp = false
    private var animationTask: Task<Void, Never>?
    var panelMover: ((NSPoint) -> Void)?

    func startIdleAnimation() {
        bobUp = true
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
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            pose = "celebrate"
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            pose = "idle"
        }
    }
}
