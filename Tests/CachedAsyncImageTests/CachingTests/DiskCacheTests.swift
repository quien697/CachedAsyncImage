//
//  DiskCacheTests.swift
//  CachedAsyncImage
//
//  Created by Quien on 2026-07-22.
//

import Foundation
import Testing

@testable import CachedAsyncImage

@Suite struct DiskCacheTests {

  /// Creates a fresh, empty temporary directory for an isolated cache under test.
  private func makeTempDirectory() -> URL {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "DiskCacheTests-\(UUID().uuidString)",
        isDirectory: true
      )
    try? FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }

  @Test func storesAndRetrievesData() async {
    let cache = DiskCache(directory: makeTempDirectory(), maxBytes: 1_000_000)
    let data = Data("hello".utf8)

    await cache.store(data, forKey: "greeting")
    let retrieved = await cache.data(forKey: "greeting")

    #expect(retrieved == data)
  }

  @Test func returnsNilForMissingKey() async {
    let cache = DiskCache(directory: makeTempDirectory(), maxBytes: 1_000_000)

    let retrieved = await cache.data(forKey: "absent")

    #expect(retrieved == nil)
  }

  @Test func evictsLeastRecentlyUsedWhenOverCapacity() async {
    let cache = DiskCache(directory: makeTempDirectory(), maxBytes: 250)
    let hundredBytes = Data(repeating: 0, count: 100)

    await cache.store(hundredBytes, forKey: "a")  // total 100
    await cache.store(hundredBytes, forKey: "b")  // total 200
    await cache.store(hundredBytes, forKey: "c")  // total 300 > 250 → evict LRU ("a")

    #expect(await cache.data(forKey: "a") == nil)
    #expect(await cache.data(forKey: "b") != nil)
    #expect(await cache.data(forKey: "c") != nil)
  }

  @Test func accessUpdatesRecency() async {
    let cache = DiskCache(directory: makeTempDirectory(), maxBytes: 250)
    let hundredBytes = Data(repeating: 0, count: 100)

    await cache.store(hundredBytes, forKey: "a")
    await cache.store(hundredBytes, forKey: "b")
    _ = await cache.data(forKey: "a")  // touch "a" → "b" becomes least-recently-used
    await cache.store(hundredBytes, forKey: "c")  // over cap → evict "b"

    #expect(await cache.data(forKey: "b") == nil)
    #expect(await cache.data(forKey: "a") != nil)
    #expect(await cache.data(forKey: "c") != nil)
  }
}
