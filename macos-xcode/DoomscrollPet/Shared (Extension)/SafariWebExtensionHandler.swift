import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private let appGroup = "group.com.vedantwalia.DoomscrollPet"
    // Safari can invoke the extension a few seconds after the app's last
    // heartbeat while macOS is waking the app or scheduling its run loop.
    // Keep the check bounded, but avoid rejecting a live companion on a
    // timing race.
    private let appHeartbeatTimeout: TimeInterval = 15

    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any] else {
            context.completeRequest(returningItems: nil)
            return
        }

        var appIsRunning: Bool?
        if let defaults = UserDefaults(suiteName: appGroup) {
            switch message["type"] as? String {
            case "doomscroll.approach":
                defaults.set(message["domain"] as? String ?? "distracting site", forKey: "approach.domain")
                defaults.set(message["tabId"] as? Int ?? -1, forKey: "approach.tabId")
                defaults.set(Date().timeIntervalSince1970, forKey: "approach.timestamp")
            case "doomscroll.warning":
                defaults.set(message["domain"] as? String ?? "distracting site", forKey: "warning.domain")
                defaults.set(message["tabId"] as? Int ?? -1, forKey: "warning.tabId")
                defaults.set(message["thresholdMinutes"] as? Int ?? 5, forKey: "warning.thresholdMinutes")
                defaults.set(Date().timeIntervalSince1970, forKey: "warning.timestamp")
            case "doomscroll.hide":
                defaults.removeObject(forKey: "approach.domain")
                defaults.set(message["tabId"] as? Int ?? -1, forKey: "approach.hideTabId")
                defaults.set(Date().timeIntervalSince1970, forKey: "approach.hideTimestamp")
            case "doomscroll.sprite-test":
                let now = Date().timeIntervalSince1970
                let heartbeat = defaults.double(forKey: "app.lastHeartbeat")
                appIsRunning = heartbeat > 0 && now - heartbeat < appHeartbeatTimeout
                if appIsRunning == true {
                    defaults.set(now, forKey: "spriteTest.timestamp")
                    defaults.set(min(max(message["delaySeconds"] as? Int ?? 10, 1), 60), forKey: "spriteTest.delaySeconds")
                }
            default:
                break
            }
        }

        let response = NSExtensionItem()
        var responseMessage: [String: Any] = ["ok": true]
        if let appIsRunning {
            responseMessage["appRunning"] = appIsRunning
        }
        response.userInfo = [SFExtensionMessageKey: responseMessage]
        context.completeRequest(returningItems: [response])
    }
}
