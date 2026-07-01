//
//  ImageNormalizer.swift
//  EnglishHelper — Data (Adapters)
//
//  Claude's vision API ONLY accepts JPEG/PNG/GIF/WebP and downsizes anything large. The default iPhone
//  photo format is HEIC, which the API REJECTS outright ("Could not process image") — so a raw HEIC from
//  the share sheet (or any oversized image) fails. This decodes ANY source format via ImageIO (HEIC
//  included, more reliably than UIImage on the Simulator) and re-encodes a downscaled JPEG. Used by the
//  LLM client right before upload, so every image — whatever its source — is in an accepted format.
//

import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

public enum ImageNormalizer {
    /// Decode `data` and return a JPEG whose long edge is at most `maxPixel` (no upscaling). EXIF
    /// orientation is baked in so rotated photos OCR correctly. Returns nil only if `data` isn't a
    /// decodable image. `maxPixel` defaults to 1568 — Claude's recommended long edge, beyond which it
    /// downsizes anyway, so capping here cuts upload size and tokens.
    public static func jpegForUpload(_ data: Data, maxPixel: Int = 1568, quality: CGFloat = 0.8) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        // CreateThumbnailFromImageAlways + MaxPixelSize downscales the FULL image to fit `maxPixel`
        // (it caps, never upscales); WithTransform applies the EXIF orientation.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, cgImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
