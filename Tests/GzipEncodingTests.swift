//
//  GzipEncodingTests.swift
//  EnglishHelper — Tests
//
//  Guards the request-body gzip used by ClaudeLLMClient: valid gzip framing, real round-trip, and the
//  "don't inflate tiny bodies" property the client relies on (it only sends gzip when it's smaller).
//

import Testing
import Foundation
import Compression
@testable import Adapters

@Suite struct GzipEncodingTests {

    @Test func gzipHasValidFramingRoundTripsAndShrinksLargeData() throws {
        let original = Data(String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 400).utf8)
        let gz = try #require(original.gzipped())

        // gzip magic (1f 8b) + CM=deflate (08).
        #expect(Array(gz.prefix(3)) == [0x1f, 0x8b, 0x08])
        // Compressible data must actually shrink (that's the whole point on a slow uplink).
        #expect(gz.count < original.count)
        // ISIZE trailer (last 4 bytes, little-endian) == original length mod 2^32.
        let isize = gz.suffix(4).reversed().reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        #expect(isize == UInt32(truncatingIfNeeded: original.count))
        // Full round-trip: inflating the gzip payload reproduces the original bytes exactly.
        #expect(inflate(gz, expectedSize: original.count) == original)
    }

    @Test func gzipDoesNotShrinkTinyData() throws {
        // A 2-byte body can't beat the ~18-byte gzip envelope — which is exactly why the client only
        // swaps in the gzip body when `gzipped.count < bodyData.count`.
        let tiny = Data("hi".utf8)
        let gz = try #require(tiny.gzipped())
        #expect(gz.count >= tiny.count)
    }

    /// Inflate a gzip container (10-byte header + raw DEFLATE + 8-byte CRC32/ISIZE trailer).
    private func inflate(_ gz: Data, expectedSize: Int) -> Data? {
        guard gz.count > 18, expectedSize > 0 else { return nil }
        let deflate = gz.subdata(in: 10..<(gz.count - 8))
        var out = Data(count: expectedSize)
        let written = out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
            deflate.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
                guard let d = dst.bindMemory(to: UInt8.self).baseAddress,
                      let s = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(d, expectedSize, s, deflate.count, nil, COMPRESSION_ZLIB)
            }
        }
        return written == expectedSize ? out : nil
    }
}
