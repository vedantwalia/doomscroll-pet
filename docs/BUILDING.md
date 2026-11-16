# Build and setup

## Native desktop pet

The standalone desktop companion builds with Swift Package Manager. From the
repository root, run:

```sh
swift build
swift run doomscroll_pet
```

The app appears as a transparent, always-on-top pixel cat in the lower-right
corner of the main screen. Click it to play the greeting animation. Right-click
and choose **Quit Doomscroll Pet** to exit. Sprite PNGs are bundled from
`Sources/doomscroll_pet/Resources` by the package manifest.

The app supports macOS 14 or later.

## Safari extension app

The Xcode project is in `macos-xcode/DoomscrollPet/`. Open
`DoomscrollPet.xcodeproj`, choose the **DoomscrollPet (macOS)** scheme, select
**My Mac**, then build or run.

The Mac app and Safari extension targets share the App Group
`group.com.vedantwalia.DoomscrollPet`. Before running the signed app:

1. Select the **DoomscrollPet (macOS)** project and open **Signing & Capabilities**.
2. Choose your Apple development team for both the macOS app and
   **DoomscrollPet Extension (macOS)** targets.
3. Make sure the App Groups capability is available for your team and that
   `group.com.vedantwalia.DoomscrollPet` is registered for the app identifier.
   If your team uses another group identifier, update both targets' entitlements
   and the matching identifier in `macOS (App)/AppDelegate.swift` and
   `Shared (Extension)/SafariWebExtensionHandler.swift`.
4. Run the **DoomscrollPet (macOS)** scheme. In Safari, enable Doomscroll Pet
   under **Safari → Settings → Extensions**, then grant access to sites you want
   the extension to monitor.

A local unsigned build can be checked without selecting a team:

```sh
xcodebuild \
  -project 'macos-xcode/DoomscrollPet/DoomscrollPet.xcodeproj' \
  -scheme 'DoomscrollPet (macOS)' \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

The macOS scheme was verified to build successfully. Installing and running the
Safari flow still requires development signing with the shared App Group
entitlement, and Safari site access must be enabled by the user.

## Verification checklist

- [x] Build the macOS app and Safari extension targets.
- [ ] Sign both targets with a development team and the shared App Group.
- [ ] Enable the extension in Safari and grant site access.
- [ ] Verify a warning after the configured interval on a disposable test tab.
- [ ] Verify **Keep browsing** leaves the tab open.
- [ ] Verify **Close tab** closes only the tab that triggered the warning.
- [ ] Verify behavior when the app or extension is unavailable.
