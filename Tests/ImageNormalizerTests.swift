//
//  ImageNormalizerTests.swift
//  EnglishHelper — Tests
//
//  Claude's vision API rejects HEIC + oversized images; the normalizer must hand it a downscaled JPEG.
//  (HEIC decoding is ImageIO's job and is verified end-to-end against the live API; here we cover the
//  format conversion + downscale + no-upscale + non-image guard with deterministic synthetic images.)
//

import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Adapters

@Suite struct ImageNormalizerTests {

    /// A solid-colour image encoded in `format` (e.g. PNG) — a non-JPEG source to convert FROM.
    private func makeImage(width: Int, height: Int, format: UTType = .png) -> Data {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.1, green: 0.5, blue: 0.8, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cg = ctx.makeImage()!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, format.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cg, nil)
        _ = CGImageDestinationFinalize(dest)
        return out as Data
    }

    private func dimensions(_ data: Data) -> (w: Int, h: Int) {
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        return (props[kCGImagePropertyPixelWidth] as! Int, props[kCGImagePropertyPixelHeight] as! Int)
    }

    @Test func downscalesLargeImageAndReencodesAsJPEG() throws {
        let big = makeImage(width: 4000, height: 3000, format: .png)
        let jpeg = try #require(ImageNormalizer.jpegForUpload(big, maxPixel: 1568))
        #expect(jpeg.starts(with: [0xFF, 0xD8, 0xFF]))     // JPEG magic — the API accepts this, not the PNG
        let (w, h) = dimensions(jpeg)
        #expect(max(w, h) == 1568)                          // long edge capped
        #expect(w == 1568 && h == 1176)                     // aspect preserved (4000x3000)
    }

    @Test func smallImageIsNotUpscaled() throws {
        let small = makeImage(width: 800, height: 600)
        let jpeg = try #require(ImageNormalizer.jpegForUpload(small, maxPixel: 1568))
        #expect(jpeg.starts(with: [0xFF, 0xD8, 0xFF]))     // still converted to JPEG
        #expect(dimensions(jpeg) == (800, 600))             // but NOT enlarged
    }

    @Test func nonImageReturnsNil() {
        #expect(ImageNormalizer.jpegForUpload(Data([0x00, 0x01, 0x02, 0x03, 0xFF])) == nil)
    }
}
