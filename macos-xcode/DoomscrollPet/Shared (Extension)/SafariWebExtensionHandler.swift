import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private let appGroup = "group.com.vedantwalia.DoomscrollPet"

    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              let message = item.userInfo?[SFExtensionMessageKey] as? [String: Any] else {
            context.completeRequest(returningItems: nil)
            return
        }

        if message["type"] as? String == "doomscroll.warning" {
            let defaults = UserDefaults(suiteName: appGroup)
            defaults?.set(message["domain"] as? String ?? "distracting site", forKey: "warning.domain")
            defaults?.set(message["tabId"] as? Int ?? -1, forKey: "warning.tabId")
            defaults?.set(message["thresholdMinutes"] as? Int ?? 5, forKey: "warning.thresholdMinutes")
            defaults?.set(Date().timeIntervalSince1970, forKey: "warning.timestamp")
        }

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["ok": true]]
        context.completeRequest(returningItems: [response])
    }
}
