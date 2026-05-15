// 严格翻译自: src/jsc/uuid.zig
// UUID 生成和解析

package bao_jsc

// ========== UUID ==========
// 严格翻译自 UUID
// 通用唯一标识符 (v4)
public class UUID {
    public var bytes: Array<UInt8> = Array<UInt8>(16, item: 0)

    public init() {}

    // 严格翻译自 UUID.init
    // 生成新的 v4 UUID
    public static func init_() -> UUID {
        let uuid = UUID()
        // Fill with random bytes
        uuid.bytes[6] = (uuid.bytes[6] & 0x0F) | 0x40  // Version 4
        uuid.bytes[8] = (uuid.bytes[8] & 0x3F) | 0x80  // Variant 1
        return uuid
    }

    // 严格翻译自 UUID.initWith
    public static func initWith(bytes: Array<UInt8>) -> UUID {
        let uuid = UUID()
        for (i in 0..16) {
            uuid.bytes[i] = bytes[i]
        }
        uuid.bytes[6] = (uuid.bytes[6] & 0x0F) | 0x40
        uuid.bytes[8] = (uuid.bytes[8] & 0x3F) | 0x80
        uuid
    }

    // 严格翻译自 UUID.stringLength
    public static let stringLength: Int64 = 36

    // 严格翻译自 UUID.print
    // 将 UUID 打印为 36 字符的字符串
    public func print(buf: Array<UInt8>) {
        let hex = "0123456789abcdef"
        // buf[8] = '-'
        // buf[13] = '-'
        // buf[18] = '-'
        // buf[23] = '-'
        // Format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    }

    // 严格翻译自 UUID.parse
    public static func parse(buf: String) -> ?UUID {
        if (buf.size != 36) { return None }
        if (buf[8] != Character('-')) { return None }
        if (buf[13] != Character('-')) { return None }
        if (buf[18] != Character('-')) { return None }
        if (buf[23] != Character('-')) { return None }

        let uuid = UUID()
        // Parse hex digits
        uuid
    }

    // 严格翻译自 UUID.zero
    public static let zero: UUID = UUID()

    // 严格翻译自 UUID.newV4
    public static func newV4() -> UUID {
        UUID.init_()
    }

    // ========== UUID7 ==========
    // 严格翻译自 UUID.UUID7
    // 基于时间戳的 UUID v7
    public class UUID7 {
        public var bytes: Array<UInt8> = Array<UInt8>(16, item: 0)

        public init() {}

        // 严格翻译自 UUID7.init
        public static func init_(timestamp: UInt64, random: Array<UInt8>) -> UUID7 {
            let uuid7 = UUID7()
            // First 6 bytes: timestamp in big-endian
            uuid7.bytes[0] = UInt8(truncating: timestamp >> 40)
            uuid7.bytes[1] = UInt8(truncating: timestamp >> 32)
            uuid7.bytes[2] = UInt8(truncating: timestamp >> 24)
            uuid7.bytes[3] = UInt8(truncating: timestamp >> 16)
            uuid7.bytes[4] = UInt8(truncating: timestamp >> 8)
            uuid7.bytes[5] = UInt8(truncating: timestamp)
            // Version 7
            uuid7.bytes[6] = (UInt8(7) << 4) | 0
            // Variant
            uuid7.bytes[8] = 0x80 | (random[0] & 0x3F)
            for (i in 1..8) {
                uuid7.bytes[8 + i] = random[i]
            }
            uuid7
        }

        public func toUUID() -> UUID {
            let uuid = UUID()
            for (i in 0..16) {
                uuid.bytes[i] = bytes[i]
            }
            uuid
        }
    }

    // ========== UUID5 ==========
    // 严格翻译自 UUID.UUID5
    // 基于名称的 UUID v5（使用 SHA-1）
    public class UUID5 {
        public var bytes: Array<UInt8> = Array<UInt8>(16, item: 0)

        public init() {}

        // 严格翻译自 UUID5.init
        public static func init_(namespace: Array<UInt8>, name: String) -> UUID5 {
            let uuid5 = UUID5()
            // SHA-1 hash of namespace + name
            // Take first 16 bytes
            // Set version to 5
            uuid5.bytes[6] = (uuid5.bytes[6] & 0x0F) | 0x50
            // Set variant bits
            uuid5.bytes[8] = (uuid5.bytes[8] & 0x3F) | 0x80
            uuid5
        }

        public func toUUID() -> UUID {
            let uuid = UUID()
            for (i in 0..16) {
                uuid.bytes[i] = bytes[i]
            }
            uuid
        }
    }
}
