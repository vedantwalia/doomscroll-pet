# Build and setup

## Standalone desktop pet

The standalone desktop companion builds with Swift Package Manager. From the
repository root, run:

```sh
swift build
swift run doomscroll_pet
```

This Swift Package Manager version always shows the cat in the lower-right
corner. The Safari companion described below uses the Xcode app and keeps the
cat hidden until a watched-site timer is close to its limit.

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
   under **Safari → Settings → Extensions**.
5. Open the extension from Safari’s toolbar. It starts with Instagram and
   Reddit. Choose a visit limit, and use **Add** to add another website. Safari
   asks before giving the extension access to each added site.

The cat enters about 30 seconds before the visit limit, walks toward the top of
Safari, and shows the break prompt at the limit. **Close tab** closes only the
tab that started the timer after the cat’s playful pounce; **Keep browsing** or
closing the prompt leaves the tab open and sends the cat away.

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
- [ ] Verify the cat stays hidden, then enters shortly before the configured limit.
- [ ] Verify it walks to the Safari toolbar and the prompt appears at the limit.
- [ ] Verify **Keep browsing** and closing the prompt leave the tab open.
- [ ] Verify **Close tab** closes only the timed tab, then the cat exits.
- [ ] Verify Instagram, Reddit, and one user-added website.
- [ ] Verify behavior when the app or extension is unavailable.
