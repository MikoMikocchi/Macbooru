<div align="center">

# Macbooru

![CI](https://github.com/MikoMikocchi/Macbooru/actions/workflows/ci.yml/badge.svg)
![Swift](https://img.shields.io/badge/Swift-6.2-orange?logo=swift)
![Platform](https://img.shields.io/badge/platform-macOS-black?logo=apple)

<img src="Macbooru/Assets.xcassets/MacbooruAppIcon-iOS-Default-1024x1024@1x.png" alt="Macbooru icon" width="140" height="140" style="border-radius:20px" />

Native Danbooru client for macOS

<sub>Requires macOS 15+ (Sequoia)</sub>

</div>

## Screenshots

<div align="center">

<img src="docs/images/Macbooru-1.png" alt="Main screen" width="900" />
<img src="docs/images/Macbooru-2.png" alt="Post view" width="900" />

</div>

## Features

* Tag and rating search (`rating:E/Q/S/G`)
* History and favorite searches
* Adaptive grid with pagination
* Image viewing and management (pan, zoom, save)
* Post comments
* Synchronization with the Danbooru API via access key

## Running

Open `Macbooru.xcodeproj` in Xcode and press Product → Run (⌘R)

## Configuration and Secrets

* Danbooru authentication (username + API key) is supported: open `Macbooru` → `Settings…` (⌘,) and fill in the *Danbooru Credentials* section. Data is stored in the system Keychain and verified automatically (current user or error is shown).
* Clearing the fields and saving removes the values from the Keychain.
* Follow Danbooru ToS and consider rate limits.

## Content Safety (NSFW)

* The sidebar settings include a “Blur NSFW (Q/E)” toggle — enabled by default.
* Increased blur and dimming are applied to `rating: q` and `rating: e`.

## License

MIT
