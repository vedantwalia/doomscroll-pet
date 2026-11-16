# Doomscroll Pet

Doomscroll Pet is a macOS companion and Safari Web Extension that gives you a
gentle nudge after spending time on selected websites. A floating cat appears
with a warning and lets you choose whether to keep browsing or close the tab.
It does not close tabs automatically.

> **Status:** This repository contains source files, not a ready-to-install app.
> An Xcode macOS app and Safari Web Extension project still need to be created,
> configured, signed, and tested. See [the build and setup guide](docs/BUILDING.md).

## What it does

- Tracks the active Safari tab on YouTube, Instagram, Reddit, and TikTok by default.
- Sends a warning to the companion app after approximately five minutes.
- Offers **Keep browsing** and **Close tab** choices; closing requires explicit
  confirmation in the app.
- Displays a small animated cat using the included PNG poses.

The timer is approximate because the extension checks periodically. Site
matching and the threshold are represented in the extension source; settings
controls in the current app scaffold are not all wired to extension storage.

## Project layout

```text
.
├── DoomscrollPet/
│   ├── Resources/                  # Cat pose images
│   ├── DoomscrollPetApp.swift      # macOS app and floating pet UI
│   └── SafariWebExtensionHandler.swift
├── SafariWebExtension/
│   ├── background.js               # Tab monitoring and warning flow
│   ├── manifest.json
│   └── popup.html
└── docs/
    └── BUILDING.md                 # Xcode integration and test checklist
```

## Requirements

- macOS and Xcode with the Safari Web Extension target template
- A Safari browser for extension testing
- Matching bundle identifiers and an App Group configured for both targets

## Build and setup

Follow [docs/BUILDING.md](docs/BUILDING.md) to create the Xcode targets, wire up
the extension resources, configure identifiers, and test the warning flow.

## Safety and privacy notes

- The extension requests broad host access in its manifest so it can observe
  the active tab URL. Its default watched-domain list is limited to four sites.
- Tab closure is intended to happen only after the user selects **Close tab**.
- Review the requested Safari permissions and the source before enabling the
  extension. No production build or runtime behavior has been verified yet.
