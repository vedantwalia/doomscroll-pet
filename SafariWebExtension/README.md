# Safari Web Extension source

This folder contains the Safari extension manifest, background script, and
popup. The toolbar popup can enable or pause monitoring, choose a 1, 5, 10, or
15 minute threshold, and edit the watched domain list. Settings are stored in
`browser.storage.local` and read by the background monitor.

Safari Web Extensions are packaged inside a macOS app by Xcode; this is not a
standalone “Load unpacked” browser extension.

See the [build and setup guide](../docs/BUILDING.md) for Xcode integration and
native messaging configuration.
