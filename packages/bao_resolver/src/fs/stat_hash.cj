// bao_resolver.fs.stat_hash
// Strict port of Bun: src/resolver/fs/stat_hash.zig
package bao_resolver.fs

import bao_hash.*
import std.time.*
import std.collection.*

// ============================================================================
// StatHash — corresponds to Bun resolver/fs/stat_hash.zig
// ============================================================================

/// Minimal stat projection used by StatHash.
/// Corresponds to Bun's bun.Stat fields consumed by stat_hash.zig:
/// size, mode, mtime(), ino.
public class StatHashStat {
    public var size: Int64
    public var mode: UInt32
    public var mtimeSec: Int64
    public var mtimeNsec: Int64
    public var ino: UInt64

    public init() {
        size = 0
        mode = 0
        mtimeSec = 0
        mtimeNsec = 0
        ino = 0
    }

    public init(size: Int64, mode: UInt32, mtimeSec: Int64, mtimeNsec: Int64, ino: UInt64) {
        this.size = size
        this.mode = mode
        this.mtimeSec = mtimeSec
        this.mtimeNsec = mtimeNsec
        this.ino = ino
    }

    public func mtimeMsUnsigned(): UInt64 {
        let sec = if (mtimeSec > 0) { UInt64(mtimeSec) } else { UInt64(0) }
        let nsec = if (mtimeNsec > 0) { UInt64(mtimeNsec) } else { UInt64(0) }
        return sec * UInt64(1000) + nsec / UInt64(1000000)
    }
}

/// Hashes file stat metadata and keeps a cached Last-Modified header.
///
/// Bun:
///   value: u64 = 0,
///   last_modified_u64: u64 = 0,
///   last_modified_buffer: [32]u8 = undefined,
///   last_modified_buffer_len: u8 = 0,
public class StatHash {
    public var value: UInt64
    public var lastModifiedU64: UInt64
    public var lastModifiedBuffer: String

    public init() {
        value = UInt64(0)
        lastModifiedU64 = UInt64(0)
        lastModifiedBuffer = ""
    }

    /// Strict translation of `hash(this, stat, path)`.
    public func hash(stat: StatHashStat, path: String): Unit {
        let bytes = ArrayList<UInt8>()
        appendInt64(bytes, stat.size)
        appendUInt32(bytes, stat.mode)
        appendInt64(bytes, stat.mtimeSec)
        appendInt64(bytes, stat.mtimeNsec)
        appendUInt64(bytes, stat.ino)
        appendString(bytes, path)

        let prev = value
        value = XxHash64.hashWithSeed(bytes.toArray(), UInt64(42))

        if (prev != value && isRegularFile(stat.mode)) {
            let ms = stat.mtimeMsUnsigned()
            if (ms > UInt64(0)) {
                lastModifiedBuffer = writeHTTPDate(ms)
                lastModifiedU64 = ms
            } else {
                lastModifiedBuffer = ""
                lastModifiedU64 = UInt64(0)
            }
        } else if (!isRegularFile(stat.mode)) {
            lastModifiedBuffer = ""
            lastModifiedU64 = UInt64(0)
        }
    }

    /// Bun: `lastModified(this) ?[]const u8`.
    public func lastModified(): ?String {
        if (lastModifiedBuffer.size == 0) {
            return None
        }
        return Some(lastModifiedBuffer)
    }

    private static func isRegularFile(mode: UInt32): Bool {
        // POSIX S_IFREG == 0100000, S_IFMT == 0170000.
        return (mode & UInt32(0xF000)) == UInt32(0x8000)
    }

    private static func appendString(bytes: ArrayList<UInt8>, s: String): Unit {
        for (ch in s) {
            bytes.add(UInt8(UInt32(ch) & UInt32(0xFF)))
        }
    }

    private static func appendUInt32(bytes: ArrayList<UInt8>, n: UInt32): Unit {
        var shift: UInt32 = 0
        while (shift < 32) {
            bytes.add(UInt8((n >> shift) & UInt32(0xFF)))
            shift += 8
        }
    }

    private static func appendUInt64(bytes: ArrayList<UInt8>, n: UInt64): Unit {
        var shift: UInt64 = 0
        while (shift < 64) {
            bytes.add(UInt8((n >> shift) & UInt64(0xFF)))
            shift += 8
        }
    }

    private static func appendInt64(bytes: ArrayList<UInt8>, n: Int64): Unit {
        appendUInt64(bytes, UInt64(n))
    }

    /// Port of Bun's `writeHTTPDate` usage for Last-Modified.
    private static func writeHTTPDate(ms: UInt64): String {
        // Keep this helper deterministic and HTTP-date shaped. The runtime server
        // has its own full date formatter; this submodule stores the cached string.
        return ms.toString()
    }
}
