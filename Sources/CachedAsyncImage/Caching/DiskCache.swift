//
//  DiskCache.swift
//  CachedAsyncImage
//
//  Created by Quien on 2026-07-22.
//

import Foundation
import CommonCrypto

/// A bounded, on-disk data cache. Keys are hashed to stable filenames so entries survive
/// across app launches. When the total size exceeds `maxBytes`, least-recently-used entries
/// are evicted.
actor DiskCache {
  private struct Entry {
    var size: Int
    var sequence: UInt64
  }

  private let directory: URL
  private let maxBytes: Int
  private var entries: [String: Entry] = [:]
  private var totalBytes = 0
  private var sequence: UInt64 = 0

  init(directory: URL, maxBytes: Int) {
    self.directory = directory
    self.maxBytes = maxBytes
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  /// Writes `data` under `key`, overwriting any existing entry, then evicts LRU entries if
  /// the cache is over its size bound.
  func store(_ data: Data, forKey key: String) {
    let name = Self.filename(forKey: key)
    do {
      try data.write(to: directory.appendingPathComponent(name))
    } catch {
      return
    }
    if let existing = entries[name] {
      totalBytes -= existing.size
    }
    sequence += 1
    entries[name] = Entry(size: data.count, sequence: sequence)
    totalBytes += data.count
    evictIfNeeded()
  }

  /// Returns the data stored under `key`, or `nil` if absent, marking the entry as most
  /// recently used.
  func data(forKey key: String) -> Data? {
    let name = Self.filename(forKey: key)
    guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else {
      return nil
    }
    sequence += 1
    entries[name]?.sequence = sequence
    return data
  }

  private func evictIfNeeded() {
    while totalBytes > maxBytes,
      let victim = entries.min(by: { $0.value.sequence < $1.value.sequence })?.key
    {
      try? FileManager.default.removeItem(at: directory.appendingPathComponent(victim))
      totalBytes -= entries[victim]?.size ?? 0
      entries[victim] = nil
    }
  }

  private static func filename(forKey key: String) -> String {
    let data = Data(key.utf8)
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes { buffer in
      _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
    }
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
