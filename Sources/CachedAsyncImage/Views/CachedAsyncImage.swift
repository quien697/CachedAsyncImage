//
//  CachedAsyncImage.swift
//  CachedAsyncImage
//
//  Created by Quien on 2026-07-22.
//

import SwiftUI

/// A drop-in replacement for `AsyncImage` that caches loaded images (memory + disk) and
/// decodes them downsampled to `targetSize`, so previously viewed images display instantly and
/// oversized images are never fully decoded.
public struct CachedAsyncImage<Content: View>: View {
  @Environment(\.displayScale) private var displayScale
  @State private var phase: CachedAsyncImagePhase = .empty
  private let url: URL?
  private let targetSize: CGSize
  private let content: (CachedAsyncImagePhase) -> Content

  /// - Parameters:
  ///   - url: The remote image URL, or `nil` for no image.
  ///   - targetSize: The display size in points; the image is downsampled to fit it.
  ///   - content: Builds the view for each phase (empty / success / failure).
  public init(
    url: URL?,
    targetSize: CGSize,
    @ViewBuilder content: @escaping (CachedAsyncImagePhase) -> Content
  ) {
    self.url = url
    self.targetSize = targetSize
    self.content = content
  }

  public var body: some View {
    content(phase)
      .task(id: url) {
        await load()
      }
  }

  private func load() async {
    guard let url else {
      phase = .empty
      return
    }
    phase = .empty
    let maxPixelSize = max(targetSize.width, targetSize.height) * displayScale
    do {
      if let image = try await ImageCache.shared.image(
        for: url, maxPixelSize: maxPixelSize, loader: Self.load(from:))
      {
        phase = .success(Image(decorative: image.cgImage, scale: displayScale))
      } else {
        phase = .failure(CachedAsyncImageError.decodingFailed)
      }
    } catch {
      phase = .failure(error)
    }
  }

  private static func load(from url: URL) async throws -> Data {
    try await URLSession.shared.data(from: url).0
  }
}

#Preview {
  CachedAsyncImage(
    url: URL(string: "https://picsum.photos/200"),
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
  }  // CachedAsyncImage
  .frame(width: 100, height: 100)
}
