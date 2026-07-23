//
//  ImageDownsampler.swift
//  CachedAsyncImage
//
//  Created by Quien on 2026-07-22.
//

import CoreGraphics
import Foundation
import ImageIO

/// Decodes image data downsampled to a target size using ImageIO,
/// so a large source image is never fully decoded just to be displayed small.
enum ImageDownsampler {

  /// Returns a thumbnail `CGImage` whose largest dimension is at most `maxPixelSize`, or `nil`
  /// if `data` is not decodable.
  static func downsample(_ data: Data, maxPixelSize: CGFloat) -> CGImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard
      let source = CGImageSourceCreateWithData(data as CFData, sourceOptions)
    else {
      return nil
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ]
    return CGImageSourceCreateThumbnailAtIndex(
      source,
      0,
      options as CFDictionary
    )
  }
}
