# Safari Web Extension source

This folder contains the Safari extension manifest, background script, and
popup. Monitoring starts with `instagram.com` and `reddit.com`. The popup can
enable or pause monitoring, choose a 1, 5, 10, or 15 minute visit limit, and add
or remove website domains. Adding a domain requests Safari website access for
that domain and its subdomains. Settings are stored in `browser.storage.local`.

The background monitor tells the native app to bring the cat onscreen shortly
before a limit expires, and sends the warning when the limit is reached. The
user chooses whether to close the timed tab; it is never closed automatically.

Safari Web Extensions are packaged inside a macOS app by Xcode; this is not a
standalone “Load unpacked” browser extension.

See the [build and setup guide](../docs/BUILDING.md) for Xcode integration and
native messaging configuration.
