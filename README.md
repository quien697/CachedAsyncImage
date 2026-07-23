# CachedAsyncImage

![iOS](https://img.shields.io/badge/iOS-17-blue.svg) ![Swift](https://img.shields.io/badge/Swift-6-orange.svg) ![SwiftUI](https://img.shields.io/badge/SwiftUI-brightgreen.svg) ![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg) ![Xcode](https://img.shields.io/badge/Xcode-26.5-blue) ![License](https://img.shields.io/badge/license-MIT-green)

A drop-in replacement for `AsyncImage` that caches loaded images and decodes them downsampled to their display size.



## 📝 Overview

1. A reusable SwiftUI view for loading remote images, distributed via Swift Package Manager.
2. Backed by a two-tier cache: an in-memory tier of decoded images and an LRU-evicted on-disk tier of raw downloaded data.
3. Decodes images downsampled to the target display size via ImageIO, so oversized images are never fully decoded just to be displayed small.
4. Deduplicates concurrent requests for the same URL into a single load.
5. Built with pure SwiftUI and no third-party dependencies.



## ✨ Features

1. **Two-tier cache** — an `NSCache`-backed memory tier in front of a size-bounded, LRU-evicted disk tier, so previously viewed images display instantly.
2. **Downsampled decoding** — images are decoded directly at their target pixel size using ImageIO, avoiding the cost of decoding full-resolution images for small thumbnails.
3. **Request deduplication** — concurrent loads for the same URL share a single network request instead of firing duplicates.
4. **Familiar API** — mirrors `AsyncImage`'s phase-based `content` closure (`empty` / `success` / `failure`).
5. **Shared cache** — a single process-wide cache instance, so any view in the app benefits from images already loaded elsewhere.



## 🛠️ Technologies & Frameworks

- iOS 17
- Swift 6
- SwiftUI
- Swift Package Manager - distribution



## 🔧 Development Tools

- Xcode 26.5
- Version control: GitHub / Git
- AI tools: [Claude Code](https://claude.com/claude-code)



## 📦 Installation

### Swift Package Manager

In Xcode, go to **File → Add Package Dependencies…** and enter the repository URL:

```
https://github.com/quien697/CachedAsyncImage.git
```

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/quien697/CachedAsyncImage.git", from: "1.0.0")
]
```

Then add the product to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["CachedAsyncImage"]
)
```



## 💻 Usage

Use `CachedAsyncImage` anywhere you'd use `AsyncImage`, passing the target display size so the image is downsampled to fit it.

```swift
import CachedAsyncImage
import SwiftUI

struct ContentView: View {
    var body: some View {
        CachedAsyncImage(
            url: URL(string: "https://example.com/photo.jpg"),
            targetSize: CGSize(width: 100, height: 100)
        ) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Image(systemName: "photo")
            }
        }
        .frame(width: 100, height: 100)
    }
}
```



## 📂 Folder Structure

```text
CachedAsyncImage/
└─ Sources/
   └─ CachedAsyncImage/
      ├─ Models/     # CachedAsyncImagePhase, CachedAsyncImageError
      ├─ Views/      # CachedAsyncImage
      └─ Caching/    # ImageCache, DiskCache, ImageDownsampler
```



## 👨‍💻 Author

**Tsung-Hsun Liu**
📧 [quien697@gmail.com](mailto:quien697@gmail.com)
🌐 [tsunghsun.me](https://www.tsunghsun.me)



## 📄 License

MIT License © 2026 Tsung-Hsun Liu
