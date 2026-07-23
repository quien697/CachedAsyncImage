//
//  CachedAsyncImagePhase.swift
//  CachedAsyncImage
//
//  Created by Quien on 2026-07-23.
//

import SwiftUI

/// The loading state of a `CachedAsyncImage`, mirroring SwiftUI's `AsyncImagePhase`
/// so it is a drop-in replacement.
public enum CachedAsyncImagePhase {
  case empty
  case success(Image)
  case failure(Error)
}
