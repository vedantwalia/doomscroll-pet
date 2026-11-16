import SwiftUI
import AppKit
import SafariServices
import Combine

@main
struct DoomscrollPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup("Doomscroll Pet") { SettingsView() }
            .windowResizability(.contentSize)
    }
}

@MainActor
final class PetModel: ObservableObject {
    static let shared = PetModel()
    @Published var enabled = true
    @Published var closeAfterWarning = true
    @Published var thresholdMinutes = 5
    @Published var graceSeconds = 30
    @Published var watchedDomains = "youtube.com, instagram.com, reddit.com, tiktok.com"
    @Published var warningDomain: String?
    @Published var status = "Watching for distracting-site sessions"
    @Published var petPose = "idle"
    @Published var showWarning = false
    @Published var warningTabId: Int = -1
    private var warningPoll: Timer?
    private let appGroup = "group.com.example.DoomscrollPet"
    // Replace with the Safari Web Extension target's generated bundle identifier.
    private let extensionBundleIdentifier = "com.example.DoomscrollPet.Extension"

    func startWarningPolling() {
        warningPoll?.invalidate()
        warningPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self,
                  let defaults = UserDefaults(suiteName: self.appGroup),
                  let domain = defaults.string(forKey: "warning.domain") else { return }
            let timestamp = defaults.double(forKey: "warning.timestamp")
            guard timestamp > 0,
                  Date().timeIntervalSince1970 - timestamp < 20,
                  !self.showWarning else { return }
            self.warningTabId = defaults.integer(forKey: "warning.tabId")
            defaults.removeObject(forKey: "warning.domain")
            defaults.removeObject(forKey: "warning.timestamp")
            self.receiveWarning(domain: domain)
        }
    }

    func receiveWarning(domain: String) {
        guard enabled else { return }
        warningDomain = domain
        status = "You've been on \(domain) for 5 minutes."
        petPose = "wake"
        showWarning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.petPose = "walk1" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.petPose = "jump" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.petPose = "idle" }
    }

    func dismissWarning() {
        SFSafariApplication.dispatchMessage(withName: "doomscroll.dismiss",
                                            toExtensionWithIdentifier: extensionBundleIdentifier,
                                            userInfo: ["tabId": warningTabId]) { _ in }
        showWarning = false
        status = "Warning dismissed — tab remains open"
        petPose = "celebrate"
    }

    func confirmClose() {
        // The Safari extension handler receives this confirmation and closes only
        // the tab associated with the pending warning.
        let tabId = warningTabId
        SFSafariApplication.dispatchMessage(withName: "doomscroll.confirm-close",
                                            toExtensionWithIdentifier: extensionBundleIdentifier,
                                            userInfo: ["tabId": tabId]) { error in
            DispatchQueue.main.async {
                if let error {
                    self.status = "Safari couldn't close the tab: \\(error.localizedDescription)"
                } else {
                    self.status = "Close request sent to Safari"
                }
            }
        }
        showWarning = false
        petPose = "click"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.petPose = "celebrate" }
    }
}

extension Notification.Name {
    static let doomscrollConfirmClose = Notification.Name("doomscrollConfirmClose")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        PetWindowController.shared.show()
        PetModel.shared.startWarningPolling()
    }
}

@MainActor
final class PetWindowController {
    static let shared = PetWindowController()
    private var window: NSWindow?
    func show() {
        guard window == nil else { return }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 116, height: 116),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .floating
        w.hasShadow = false
        w.ignoresMouseEvents = false
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.contentView = NSHostingView(rootView: FloatingPetView())
        if let screen = NSScreen.main {
            w.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 128,
                                     y: screen.visibleFrame.minY + 10))
        }
        w.orderFrontRegardless()
        window = w
    }
}

struct FloatingPetView: View {
    @ObservedObject var model = PetModel.shared
    var body: some View {
        VStack(spacing: 2) {
            if model.showWarning {
                Text("5-minute break?").font(.caption2.bold())
                    .padding(5).background(.regularMaterial, in: Capsule())
            }
            SpriteImage(name: model.petPose)
                .frame(width: 96, height: 96)
        }
        .frame(width: 116, height: 116)
        .popover(isPresented: $model.showWarning) {
            VStack(alignment: .leading, spacing: 12) {
                Text("A gentle nudge").font(.headline)
                Text("You've been on \(model.warningDomain ?? "this site") for 5 minutes. Want to close this tab and take a break?")
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Keep browsing") { model.dismissWarning() }
                    Button("Close tab") { model.confirmClose() }.keyboardShortcut(.defaultAction)
                }
            }.padding().frame(width: 290)
        }
    }
}

struct SpriteImage: View {
    let name: String
    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Resources"),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
        } else {
            Image(systemName: "cat.fill").resizable().scaledToFit().padding(18)
                .foregroundStyle(.orange)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model = PetModel.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                Image(systemName: "cat.fill").font(.system(size: 34)).foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text("Doomscroll Pet").font(.title2.bold())
                    Text("Safari-first focus companion").foregroundStyle(.secondary)
                }
            }
            Toggle("Enable pet", isOn: $model.enabled)
            Toggle("Ask before closing a tab", isOn: $model.closeAfterWarning)
            HStack {
                Text("Intervention after")
                Spacer()
                Text("5 minutes").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Watched websites").font(.headline)
                TextEditor(text: $model.watchedDomains).frame(height: 75)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(.quaternary))
            }
            Label(model.status, systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.secondary)
            Text("Safari extension must be enabled in Safari → Settings → Extensions.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(20).frame(width: 400)
        .onAppear { PetWindowController.shared.show() }
    }
}
