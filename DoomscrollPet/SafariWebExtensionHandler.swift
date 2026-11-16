import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    // Replace with the same App Group identifier enabled for both Xcode targets.
    private let appGroup = "group.com.example.DoomscrollPet"

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
            defaults?.set(Date().timeIntervalSince1970, forKey: "warning.timestamp")
        }

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["ok": true]]
        context.completeRequest(returningItems: [response])
    }
}
