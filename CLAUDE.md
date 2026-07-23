# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

CachedAsyncImage is a Swift Package: a drop-in replacement for SwiftUI's `AsyncImage` that adds a
two-tier cache (memory + disk) and downsampled decoding. Pure SwiftUI, no third-party dependencies.
iOS 17+ / macOS 12+, Swift 6 (strict concurrency), distributed via SPM.

## Commands

```bash
swift build                              # build the package
swift test                               # run all tests (Swift Testing framework)
swift test --filter ImageCacheTests      # run one test suite
swift test --filter deduplicatesConcurrentLoadsOfSameURL  # run a single test
swift format -i <files>                  # format staged files (config: .swift-format)
swiftlint lint --fix --quiet <files>     # autocorrect lint violations
swiftlint lint --quiet <files>           # check for remaining violations
```

Tests use the **Swift Testing** framework (`@Suite`, `@Test`, `#expect`), not XCTest.

A git pre-commit hook (`.git/hooks/pre-commit`) already runs `swift format` + `swiftlint --fix` on
staged `.swift` files, re-stages them, then fails the commit if lint violations remain unfixed.

## Architecture

Three-layer pipeline, each layer owned by one file under `Sources/CachedAsyncImage/`:

- **`Views/CachedAsyncImage.swift`** — the public SwiftUI view. Mirrors `AsyncImage`'s phase-based
  `content` closure (`CachedAsyncImagePhase`: `.empty` / `.success` / `.failure`). On `.task(id: url)`
  it computes `maxPixelSize` from `targetSize * displayScale` and calls into `ImageCache.shared`.
- **`Caching/ImageCache.swift`** — an `actor` coordinating the two tiers:
  - In-memory: `NSCache<NSString, CGImage>` keyed by `"\(url)|\(maxPixelSize)"` (decoded images differ
    per requested size, so the key includes size, not just URL).
  - On-disk: delegates to `DiskCache` for the raw downloaded `Data`, keyed by URL only (one download
    serves any requested size).
  - In-flight request deduplication via a `[URL: Task<Data, Error>]` dictionary — concurrent
    `image(for:)` calls for the same URL share one network load.
  - `ImageCache.shared` is a single process-wide instance in the platform caches directory, so the
    cache is shared across every view instance and every module that links this package.
- **`Caching/DiskCache.swift`** — an `actor` storing raw `Data` on disk, keyed by SHA-256 hash of the
  cache key (stable filenames across launches). Tracks per-entry size and a monotonic `sequence`
  counter to evict least-recently-used entries once `maxBytes` is exceeded.
- **`Caching/ImageDownsampler.swift`** — stateless `enum` wrapping ImageIO's
  `CGImageSourceCreateThumbnailAtIndex`, so images are decoded directly at `maxPixelSize` rather than
  decoded at full resolution and scaled down.

Data flow on load: memory cache hit → return immediately. Miss → check `DiskCache` for raw bytes →
decode/downsample/cache-in-memory. Miss there too → dedupe-load via the injected `loader` closure →
store raw bytes on disk → decode/downsample/cache-in-memory.

`SendableImage` (in `ImageCache.swift`) wraps a `CGImage` as `@unchecked Sendable` to cross actor
boundaries — safe because `CGImage` is immutable once created.

`Models/` holds the two public types consumed by callers: `CachedAsyncImagePhase` and
`CachedAsyncImageError`.

Tests live in `Tests/CachedAsyncImageTests/CachingTests/`, one file per cached type, using
`@testable import CachedAsyncImage` to reach `internal` types like `ImageCache` and `DiskCache`
directly (constructed with a temp directory rather than `ImageCache.shared`).
