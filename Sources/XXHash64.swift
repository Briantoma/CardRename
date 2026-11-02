import Foundation

/// Streaming xxHash64 (seed 0), the checksum Labroll Utility writes in its logs and MHL files.
/// Self-contained so the app keeps building with the Command Line Tools only.
struct XXHash64 {
    private static let p1: UInt64 = 11400714785074694791
    private static let p2: UInt64 = 14029467366897019727
    private static let p3: UInt64 = 1609587929392839161
    private static let p4: UInt64 = 9650029242287828579
    private static let p5: UInt64 = 2870177450012600261

    private var v1: UInt64
    private var v2: UInt64
    private var v3: UInt64
    private var v4: UInt64
    private var total: UInt64 = 0
    private var buffer = [UInt8](repeating: 0, count: 32)
    private var buffered = 0
    private let seed: UInt64

    init(seed: UInt64 = 0) {
        self.seed = seed
        v1 = seed &+ Self.p1 &+ Self.p2
        v2 = seed &+ Self.p2
        v3 = seed
        v4 = seed &- Self.p1
    }

    static func hex(_ data: Data) -> String {
        var hasher = XXHash64()
        hasher.update(data)
        return hasher.hexDigest()
    }

    mutating func update(_ data: Data) {
        data.withUnsafeBytes { update($0) }
    }

    mutating func update(_ bytes: UnsafeRawBufferPointer) {
        var offset = 0
        let count = bytes.count
        total &+= UInt64(count)

        if buffered > 0 {
            let take = min(32 - buffered, count)
            for i in 0..<take { buffer[buffered + i] = bytes[i] }
            buffered += take
            offset = take
            guard buffered == 32 else { return }
            let full = buffer
            full.withUnsafeBytes { stripe($0, at: 0) }
            buffered = 0
        }
        while offset + 32 <= count {
            stripe(bytes, at: offset)
            offset += 32
        }
        while offset < count {
            buffer[buffered] = bytes[offset]
            buffered += 1
            offset += 1
        }
    }

    func digest() -> UInt64 {
        var h: UInt64
        if total >= 32 {
            h = rotl(v1, 1) &+ rotl(v2, 7) &+ rotl(v3, 12) &+ rotl(v4, 18)
            h = merge(h, v1)
            h = merge(h, v2)
            h = merge(h, v3)
            h = merge(h, v4)
        } else {
            h = seed &+ Self.p5
        }
        h &+= total

        var i = 0
        buffer.withUnsafeBytes { tail in
            while i + 8 <= buffered {
                h ^= round(0, word64(tail, i))
                h = rotl(h, 27) &* Self.p1 &+ Self.p4
                i += 8
            }
            if i + 4 <= buffered {
                h ^= UInt64(UInt32(littleEndian: tail.loadUnaligned(fromByteOffset: i, as: UInt32.self))) &* Self.p1
                h = rotl(h, 23) &* Self.p2 &+ Self.p3
                i += 4
            }
            while i < buffered {
                h ^= UInt64(tail[i]) &* Self.p5
                h = rotl(h, 11) &* Self.p1
                i += 1
            }
        }

        h ^= h >> 33
        h &*= Self.p2
        h ^= h >> 29
        h &*= Self.p3
        h ^= h >> 32
        return h
    }

    /// Lowercase, 16 characters, as Python's xxhash.xxh64().hexdigest().
    func hexDigest() -> String { String(format: "%016llx", digest()) }

    private mutating func stripe(_ bytes: UnsafeRawBufferPointer, at offset: Int) {
        v1 = round(v1, word64(bytes, offset))
        v2 = round(v2, word64(bytes, offset + 8))
        v3 = round(v3, word64(bytes, offset + 16))
        v4 = round(v4, word64(bytes, offset + 24))
    }

    private func word64(_ bytes: UnsafeRawBufferPointer, _ offset: Int) -> UInt64 {
        UInt64(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
    }

    private func round(_ acc: UInt64, _ input: UInt64) -> UInt64 {
        rotl(acc &+ input &* Self.p2, 31) &* Self.p1
    }

    private func merge(_ acc: UInt64, _ value: UInt64) -> UInt64 {
        (acc ^ round(0, value)) &* Self.p1 &+ Self.p4
    }

    private func rotl(_ x: UInt64, _ r: UInt64) -> UInt64 { (x << r) | (x >> (64 - r)) }
}
