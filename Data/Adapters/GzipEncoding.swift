//
//  GzipEncoding.swift
//  EnglishHelper — Data (Adapters)
//
//  Gzip (RFC 1952) for request bodies: Apple `Compression` (raw DEFLATE) + a gzip header/CRC32/ISIZE
//  wrapper. Shrinks the upload on a slow cellular uplink — the photo's base64 image is the big win.
//  Output verified valid against system `gunzip`; the Anthropic Messages API accepts a gzip request
//  body sent with `Content-Encoding: gzip` (verified with a live probe).
//

import Foundation
import Compression

extension Data {
    /// A gzip-compressed copy, or nil if compression fails. Callers should use the result ONLY when it
    /// is actually smaller than the original (tiny bodies inflate by the ~18-byte gzip envelope).
    func gzipped() -> Data? {
        guard !isEmpty else { return nil }
        let deflated: Data? = withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Data? in
            guard let src = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            let capacity = count + count / 2 + 64
            let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
            defer { dst.deallocate() }
            // COMPRESSION_ZLIB emits a RAW DEFLATE stream (RFC 1951) per Apple's docs — exactly the
            // payload a gzip container wraps.
            let written = compression_encode_buffer(dst, capacity, src, count, nil, COMPRESSION_ZLIB)
            guard written > 0 else { return nil }
            return Data(bytes: dst, count: written)
        }
        guard let deflated else { return nil }
        // gzip header: magic (1f 8b), CM=deflate (08), no flags, mtime 0, no extra flags, OS unknown (ff).
        var out = Data([0x1f, 0x8b, 0x08, 0x00, 0, 0, 0, 0, 0x00, 0xff])
        out.append(deflated)
        var crc = gzipCRC32().littleEndian
        Swift.withUnsafeBytes(of: &crc) { out.append(contentsOf: $0) }
        var isize = UInt32(truncatingIfNeeded: count).littleEndian   // original size mod 2^32
        Swift.withUnsafeBytes(of: &isize) { out.append(contentsOf: $0) }
        return out
    }

    /// CRC-32 (reflected, polynomial 0xEDB88320) over the uncompressed bytes — the gzip trailer checksum.
    private func gzipCRC32() -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in self {
            crc ^= UInt32(byte)
            for _ in 0..<8 { crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb8_8320 : crc >> 1 }
        }
        return ~crc
    }
}
