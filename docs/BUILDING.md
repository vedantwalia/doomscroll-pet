# Build and setup

## Native desktop pet (current phase)

The native companion builds directly with Swift Package Manager; Xcode project
generation is not needed yet. From the repository root, run:

```sh
swift build
swift run doomscroll_pet
```

The app appears as a transparent, always-on-top pixel cat in the lower-right
corner of the main screen. Click it to play the greeting animation. Right-click
and choose **Quit Doomscroll Pet** to exit. The PNG poses are bundled from
`Sources/doomscroll_pet/Resources` by the package manifest.

The app supports macOS 14 or later and Swift 6.4 or later.

## Safari extension (later phase)

Safari Web Extensions must be embedded and signed by an Xcode macOS app target.
The native desktop pet can already be built and run separately with SwiftPM.

## Xcode integration

1. In Xcode, create a macOS App project named `DoomscrollPet`.
2. Add **File → New → Target → Safari Web Extension**.
3. Replace the generated extension resources with the files in
   `SafariWebExtension/`.
4. Add `DoomscrollPet/DoomscrollPetApp.swift` to the macOS app target.
5. Add `DoomscrollPet/SafariWebExtensionHandler.swift` to the extension's native
   handler target.
6. Enable the same App Group on both targets, for example
   `group.com.yourname.DoomscrollPet`.
7. Replace `group.com.example.DoomscrollPet` in both Swift files with that
   App Group identifier.
8. Replace `com.example.DoomscrollPet.Extension` in
   `DoomscrollPetApp.swift` with the generated Safari extension bundle ID.
9. In `SafariWebExtension/background.js`, replace the example native application
   identifier with the containing app's actual bundle identifier if required by
   the Xcode-generated native messaging configuration.
10. Build and run the app. Enable Doomscroll Pet in Safari → Settings →
    Extensions and grant access to the sites you want to monitor.

The exact extension packaging and native messaging registration depend on the
Xcode-generated target configuration. Use the generated Safari Web Extension
template as the source of truth for the Xcode version in use.

## Verification checklist

- [ ] Embed the Safari extension in an Xcode macOS app with valid signing and entitlements.
- [ ] Enable the extension in Safari and grant site access.
- [ ] Verify a warning after the configured interval on a disposable test tab.
- [ ] Verify **Keep browsing** leaves the tab open.
- [ ] Verify **Close tab** closes only the tab that triggered the warning.
- [ ] Verify behavior when the app or extension is unavailable.

The Xcode build, signing, entitlements, and runtime checks have not been
performed. Treat this as a source scaffold, not a finished installer.
