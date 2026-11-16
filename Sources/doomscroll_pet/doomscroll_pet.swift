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
        .contentShape(Rectangle())
        .onTapGesture { model.playGreeting() }
        .contextMenu {
            Button("Play greeting") { model.playGreeting() }
            Divider()
            Button("Quit Doomscroll Pet") { NSApp.terminate(nil) }
        }
    }
}

@MainActor
private final class PetAnimationModel: ObservableObject {
    @Published var pose = "idle"
    private var animationTask: Task<Void, Never>?

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
