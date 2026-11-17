# Doomscroll Pet

Doomscroll Pet is a native macOS desktop companion with a small pixel cat that
floats in the lower-right corner of your screen. Click the cat for a short
greeting animation, or right-click it to replay the greeting or quit.

> **Status:** The native desktop pet is a Swift Package Manager executable.
> Safari monitoring and packaging remain a later phase and still require Xcode.

<p align="center">
  <img src="docs/doomscroll-pet.gif" alt="Doomscroll Pet idling, jumping, and celebrating" width="192">
</p>

## What it does

- Displays the included pixel cat as a transparent, always-on-top desktop panel.
- Opens at the lower-right of the main screen and remains stationary.
- Uses the bundled jump and celebration poses for a click greeting.
- Does not yet monitor Safari or close tabs.

The timer is approximate because the extension checks periodically. Site
matching and the threshold are represented in the extension source; settings
controls in the current app scaffold are not all wired to extension storage.

## Project layout

```text
.
├── Sources/doomscroll_pet/
│   ├── doomscroll_pet.swift        # SwiftUI app and AppKit floating panel
│   └── Resources/                  # Swift Package Manager cat pose images
├── DoomscrollPet/                  # Later Xcode/Safari integration scaffold
├── SafariWebExtension/
│   ├── background.js               # Tab monitoring and warning flow
│   ├── manifest.json
│   └── popup.html
└── docs/
    └── BUILDING.md                 # Xcode integration and test checklist
```

## Requirements

- macOS 14 or later
- Swift 6.4 or later (Xcode Command Line Tools are sufficient for the native pet)

## Build and setup

From the repository root, build and launch the native pet:

```sh
swift build
swift run doomscroll_pet
```

Right-click the cat to quit. Safari extension setup is documented separately in
[the build and setup guide](docs/BUILDING.md) and is intentionally deferred.

## Safety and privacy notes

- The current Swift Package Manager target only displays the cat; it does not
  access Safari, read browsing activity, or close tabs.
- The separate Safari scaffold has not been built, signed, or enabled.
