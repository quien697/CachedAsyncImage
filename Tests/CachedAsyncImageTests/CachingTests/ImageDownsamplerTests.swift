//
//  ImageDownsamplerTests.swift
//  CachedAsyncImage
//
//  Created by Quien on 2026-07-22.
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import CachedAsyncImage

@Suite struct ImageDownsamplerTests {

  /// Encodes a solid-color image of the given pixel dimensions as PNG data.
  private func makePNGData(width: Int, height: Int) -> Data {
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = context.makeImage()!

    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
      data,
      UTType.png.identifier as CFString,
      1,
      nil
    )!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
  }

  @Test func downsamplesLargeImageToMaxPixelSize() {
    let data = makePNGData(width: 100, height: 100)

    let image = ImageDownsampler.downsample(data, maxPixelSize: 10)

    #expect(image != nil)
    #expect((image?.width ?? .max) <= 10)
    #expect((image?.height ?? .max) <= 10)
  }

  @Test func returnsNilForInvalidData() {
    let image = ImageDownsampler.downsample(
      Data("not an image".utf8),
      maxPixelSize: 10
    )

    #expect(image == nil)
  }
}
