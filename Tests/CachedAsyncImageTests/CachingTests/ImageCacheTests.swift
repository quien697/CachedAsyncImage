//
//  ImageCacheTests.swift
//  CachedAsyncImage
//
//  Created by Quien on 2026-07-22.
//

import Foundation
import Testing
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

@testable import CachedAsyncImage

@Suite struct ImageCacheTests {

  /// Counts how many times the loader is invoked, safely across concurrency.
  private actor CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
  }

  private func makeTempDirectory() -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ImageCacheTests-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
  }

  private func makePNGData(width: Int, height: Int) -> Data {
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
      data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
  }

  @Test func deduplicatesConcurrentLoadsOfSameURL() async throws {
    let cache = ImageCache(disk: DiskCache(directory: makeTempDirectory(), maxBytes: 10_000_000))
    let counter = CallCounter()
    let pngData = makePNGData(width: 100, height: 100)
    let loader: @Sendable (URL) async throws -> Data = { _ in
      await counter.increment()
      try? await Task.sleep(nanoseconds: 50_000_000)  // hold so the second request overlaps
      return pngData
    }
    let url = URL(string: "https://example.com/photo.png")!

    async let first = cache.image(for: url, maxPixelSize: 10, loader: loader)
    async let second = cache.image(for: url, maxPixelSize: 10, loader: loader)
    _ = try await (first, second)

    #expect(await counter.count == 1)
  }

  @Test func secondRequestServedFromCacheWithoutReloading() async throws {
    let cache = ImageCache(disk: DiskCache(directory: makeTempDirectory(), maxBytes: 10_000_000))
    let counter = CallCounter()
    let pngData = makePNGData(width: 100, height: 100)
    let loader: @Sendable (URL) async throws -> Data = { _ in
      await counter.increment()
      return pngData
    }
    let url = URL(string: "https://example.com/photo.png")!

    _ = try await cache.image(for: url, maxPixelSize: 10, loader: loader)
    _ = try await cache.image(for: url, maxPixelSize: 10, loader: loader)

    #expect(await counter.count == 1)
  }
}
