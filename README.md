# Doomscroll Pet

Doomscroll Pet is a native macOS desktop companion and Safari extension. Its
pixel cat waits offscreen, walks up to Safari near a visit limit, and leaves
playfully after you choose to close the timed tab or keep browsing.

> **Status:** The macOS Safari app and extension are in
> `macos-xcode/DoomscrollPet/`. The separate Swift Package Manager build is a
> standalone cat preview.

<p align="center">
  <img src="docs/doomscroll-pet.gif" alt="Doomscroll Pet walking through its four-frame animation" width="192">
</p>

## What it does

- Starts with Instagram and Reddit and lets you add more websites in the Safari
  toolbar popup.
- Brings the animated cat onscreen shortly before the selected visit limit.
- Keeps tab closure under your control: **Close tab** acts on the tab being
  timed; **Keep browsing** leaves it open.

The timer checks periodically, so the entrance and prompt can be slightly early
or late.

## Project layout

```text
.
├── Sources/doomscroll_pet/
│   ├── doomscroll_pet.swift        # SwiftUI app and AppKit floating panel
│   └── Resources/                  # Swift Package Manager cat pose images
├── macos-xcode/DoomscrollPet/      # Signed macOS host app and Safari extension
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

For the Safari companion, open the Xcode project and choose the
**DoomscrollPet (macOS)** scheme. Sign both macOS targets with your development
team, then run the app. Use Safari’s toolbar popup to set a limit and edit the
watched websites. See [the build guide](docs/BUILDING.md) for steps.

The standalone cat preview can also be built from the repository root:

```sh
swift build
swift run doomscroll_pet
```

The Swift Package Manager preview does not monitor Safari.

## Safety and privacy notes

- The Safari extension only monitors domains on your saved list after you grant
  it website access in Safari.
- The extension asks for access when you add a website, and tab closure requires
  choosing **Close tab** in the cat prompt.
