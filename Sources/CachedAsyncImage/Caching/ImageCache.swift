//
//  ImageCache.swift
//  CachedAsyncImage
//
//  Created by Quien on 2026-07-22.
//

import CoreGraphics
import Foundation

/// A downsampled `CGImage` safe to hand across concurrency domains. `CGImage` is immutable
/// once created, so reading it from multiple domains is safe.
struct SendableImage: @unchecked Sendable {
  let cgImage: CGImage
}

/// A two-tier image cache: an in-memory tier of decoded, downsampled images keyed by
/// URL + size, backed by a `DiskCache` of the original downloaded data. Concurrent requests
/// for the same URL share a single load.
actor ImageCache {
  private let disk: DiskCache
  private let memory = NSCache<NSString, CGImage>()
  private var inFlight: [URL: Task<Data, Error>] = [:]

  /// The process-wide cache. Both the app and any package that links CachedAsyncImage share
  /// this instance, so an image loaded in one is served from cache in the other.
  static let shared: ImageCache = {
    let caches =
      FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
      ?? FileManager.default.temporaryDirectory
    let directory = caches.appendingPathComponent(
      "CachedAsyncImage",
      isDirectory: true
    )
    return ImageCache(
      disk: DiskCache(directory: directory, maxBytes: 200 * 1024 * 1024)
    )
  }()

  init(disk: DiskCache) {
    self.disk = disk
  }

  /// Returns the downsampled image for `url`, loading it via `loader` only on a full cache
  /// miss. A failed load is propagated and not cached.
  func image(
    for url: URL,
    maxPixelSize: CGFloat,
    loader: @Sendable @escaping (URL) async throws -> Data
  ) async throws -> SendableImage? {
    let memoryKey = Self.memoryKey(url: url, maxPixelSize: maxPixelSize)
    if let cached = memory.object(forKey: memoryKey) {
      return SendableImage(cgImage: cached)
    }
    if let data = await disk.data(forKey: url.absoluteString) {
      return decodeAndStore(
        data,
        memoryKey: memoryKey,
        maxPixelSize: maxPixelSize
      )
    }
    let data = try await loadData(for: url, loader: loader)
    await disk.store(data, forKey: url.absoluteString)
    return decodeAndStore(
      data,
      memoryKey: memoryKey,
      maxPixelSize: maxPixelSize
    )
  }

  private func decodeAndStore(
    _ data: Data,
    memoryKey: NSString,
    maxPixelSize: CGFloat
  ) -> SendableImage? {
    guard
      let image = ImageDownsampler.downsample(data, maxPixelSize: maxPixelSize)
    else {
      return nil
    }
    memory.setObject(image, forKey: memoryKey)
    return SendableImage(cgImage: image)
  }

  private func loadData(
    for url: URL,
    loader: @Sendable @escaping (URL) async throws -> Data
  ) async throws -> Data {
    if let existing = inFlight[url] {
      return try await existing.value
    }
    let task = Task { try await loader(url) }
    inFlight[url] = task
    defer { inFlight[url] = nil }
    return try await task.value
  }

  private static func memoryKey(url: URL, maxPixelSize: CGFloat) -> NSString {
    "\(url.absoluteString)|\(Int(maxPixelSize))" as NSString
  }
}
