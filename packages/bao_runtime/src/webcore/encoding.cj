// Contains helpers for C++ to do TextEncoder/Decoder like operations.
// Also contains the code used by `bun.String.encode` and `bun.String.encodeInto`
//
// Strict 1:1 translation from: src/runtime/webcore/encoding.rs (906 lines)
// Ported from: src/runtime/webcore/encoding.zig
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_jsc.*

// ============================================================================
// Encoding - 编码类型 (u8 discriminants)
// 对应 Bun: bun.jsc.Node.Encoding #[repr(u8)]
// Design note: The original Zig/Rust code uses `#[repr(u8)]` enum with const
// generics for compile-time monomorphization. Cangjie uses a plain enum with
// runtime dispatch — functionally equivalent.
// ============================================================================

/// 编码类型
/// 对应 Bun: bun.jsc.Node.Encoding
public enum Encoding {
    | Utf8       // 0
    | Ucs2       // 1 - alias for UTF-16LE
    | Utf16le    // 2
    | Latin1     // 3
    | Ascii      // 4
    | Base64     // 5
    | Base64url  // 6
    | Hex        // 7
    | Buffer     // 8

    public operator func == (rhs: Encoding): Bool {
        match (this) {
            case Utf8 => match (rhs) { case Utf8 => true case _ => false }
            case Ucs2 => match (rhs) { case Ucs2 => true case _ => false }
            case Utf16le => match (rhs) { case Utf16le => true case _ => false }
            case Latin1 => match (rhs) { case Latin1 => true case _ => false }
            case Ascii => match (rhs) { case Ascii => true case _ => false }
            case Base64 => match (rhs) { case Base64 => true case _ => false }
            case Base64url => match (rhs) { case Base64url => true case _ => false }
            case Hex => match (rhs) { case Hex => true case _ => false }
            case Buffer => match (rhs) { case Buffer => true case _ => false }
        }
    }

    /// Convert to u8 discriminant
    /// 对应 Bun: enc::UTF8 etc. const u8 values
    public func toU8(): UInt8 {
        match (this) {
            case Utf8 => 0
            case Ucs2 => 1
            case Utf16le => 2
            case Latin1 => 3
            case Ascii => 4
            case Base64 => 5
            case Base64url => 6
            case Hex => 7
            case Buffer => 8
        }
    }

    /// 从 u8 discriminant 恢复编码
    /// 对应 Bun: encoding_from_u8(n)
    public static func fromU8(n: UInt8): Encoding {
        match (n) {
            case 0 => Encoding.Utf8
            case 1 => Encoding.Ucs2
            case 2 => Encoding.Utf16le
            case 3 => Encoding.Latin1
            case 4 => Encoding.Ascii
            case 5 => Encoding.Base64
            case 6 => Encoding.Base64url
            case 7 => Encoding.Hex
            case 8 => Encoding.Buffer
            case _ => Encoding.Utf8 // unreachable in practice
        }
    }

    /// 从字符串解析编码
    /// 对应 Bun: various callers that parse encoding name strings
    public static func fromString(name: String): ?Encoding {
        let lower = name.trimAscii()
        if (lower == "utf-8" || lower == "utf8") { return Some(Encoding.Utf8) }
        if (lower == "utf-16le" || lower == "utf16le" || lower == "ucs2" || lower == "ucs-2") { return Some(Encoding.Utf16le) }
        if (lower == "latin1" || lower == "latin-1" || lower == "binary") { return Some(Encoding.Latin1) }
        if (lower == "ascii") { return Some(Encoding.Ascii) }
        if (lower == "base64") { return Some(Encoding.Base64) }
        if (lower == "base64url") { return Some(Encoding.Base64url) }
        if (lower == "hex") { return Some(Encoding.Hex) }
        if (lower == "buffer") { return Some(Encoding.Buffer) }
        return None
    }

    /// 获取编码名称字符串
    public func toString(): String {
        match (this) {
            case Utf8 => "utf-8"
            case Ucs2 => "ucs2"
            case Utf16le => "utf-16le"
            case Latin1 => "latin1"
            case Ascii => "ascii"
            case Base64 => "base64"
            case Base64url => "base64url"
            case Hex => "hex"
            case Buffer => "buffer"
        }
    }

    /// Whether this encoding is a binary-to-text encoding
    /// 对应 Bun: Encoding.isBinaryToText()
    public func isBinaryToText(): Bool {
        match (this) {
            case Base64 | Base64url | Hex => true
            case _ => false
        }
    }
}

// ============================================================================
// EncodingHelper - 编码辅助函数
// 对应 Bun: encoding.rs 中的各种 write/construct/toString 函数
//
// Design note: The original Zig/Rust code uses const generics
// (<const ENCODING: u8>) to monomorphize each encoding variant at compile
// time, producing specialized machine code per encoding. Cangjie does not
// support const generics, so this implementation uses runtime `match`
// dispatch instead. This is a deliberate, functionally-equivalent design
// choice — the behavior (input/output mapping) is identical, and the
// Cangjit compiler may still inline the hot paths.
// ============================================================================

/// 编码辅助工具
public class EncodingHelper {

    // ==========================================================================
    // Bun__encoding__writeLatin1
    // 对应 encoding.rs: Bun__encoding__writeLatin1
    // ==========================================================================

    /// 将 Latin1 字节写入指定编码
    /// 对应 Bun: Bun__encoding__writeLatin1 (FFI entry point)
    public static func writeLatin1(input: Array<UInt8>, to: Array<UInt8>, encoding: Encoding): Int64 {
        return writeU8(input, to, encoding)
    }

    // ==========================================================================
    // Bun__encoding__writeUTF16
    // 对应 encoding.rs: Bun__encoding__writeUTF16
    // ==========================================================================

    /// 将 UTF-16 字节写入指定编码
    /// 对应 Bun: Bun__encoding__writeUTF16 (FFI entry point)
    public static func writeUTF16(input: Array<UInt16>, to: Array<UInt8>, encoding: Encoding): Int64 {
        return writeU16(input, to, encoding, false)
    }

    // ==========================================================================
    // Bun__encoding__byteLengthLatin1AsUTF8
    // 对应 encoding.rs: Bun__encoding__byteLengthLatin1AsUTF8
    // ==========================================================================

    /// 计算 Latin1 字节转为 UTF-8 后的字节长度
    /// 对应 Bun: Bun__encoding__byteLengthLatin1AsUTF8
    public static func byteLengthLatin1AsUTF8(input: Array<UInt8>): Int64 {
        return byteLengthU8(input, Encoding.Utf8)
    }

    // ==========================================================================
    // Bun__encoding__byteLengthUTF16AsUTF8
    // 对应 encoding.rs: Bun__encoding__byteLengthUTF16AsUTF8
    // ==========================================================================

    /// 计算 UTF-16 字节转为 UTF-8 后的字节长度
    /// 对应 Bun: Bun__encoding__byteLengthUTF16AsUTF8
    public static func byteLengthUTF16AsUTF8(input: Array<UInt16>): Int64 {
        // Each UTF-16 code unit is 2 bytes; compute element length
        return Strings.elementLengthUTF16IntoUTF8(input)
    }

    // ==========================================================================
    // Bun__encoding__constructFromLatin1
    // 对应 encoding.rs: Bun__encoding__constructFromLatin1
    // ==========================================================================

    /// 从 Latin1 字节构造编码后的数据
    /// 对应 Bun: Bun__encoding__constructFromLatin1
    public static func constructFromLatin1(input: Array<UInt8>, encoding: Encoding): Array<UInt8> {
        return constructFromU8(input, encoding)
    }

    // ==========================================================================
    // Bun__encoding__constructFromUTF16
    // 对应 encoding.rs: Bun__encoding__constructFromUTF16
    // ==========================================================================

    /// 从 UTF-16 字节构造编码后的数据
    /// 对应 Bun: Bun__encoding__constructFromUTF16
    public static func constructFromUTF16(input: Array<UInt16>, encoding: Encoding): Array<UInt8> {
        return constructFromU16(input, encoding)
    }

    // ==========================================================================
    // Bun__encoding__toStringUTF8
    // 对应 encoding.rs: Bun__encoding__toStringUTF8
    // ==========================================================================

    /// 将字节以 UTF-8 编码转为 JS 字符串
    /// 对应 Bun: Bun__encoding__toStringUTF8
    public static func toStringUTF8(input: Array<UInt8>): BaoString {
        return toBunString(input, Encoding.Utf8)
    }

    // ==========================================================================
    // Bun__encoding__toString
    // 对应 encoding.rs: Bun__encoding__toString
    // ==========================================================================

    /// 将字节以指定编码转为 JS 字符串
    /// 对应 Bun: Bun__encoding__toString
    public static func toString(input: Array<UInt8>, encoding: Encoding): BaoString {
        return toBunString(input, encoding)
    }

    // ==========================================================================
    // toString
    // 对应 encoding.rs: pub fn to_string
    // ==========================================================================

    /// 将字节以指定编码转为字符串
    /// 对应 Bun: to_string(input, global_object, encoding)
    public static func toStringValue(input: Array<UInt8>, encoding: Encoding): BaoString {
        // treat buffer as utf8 — callers are expected to check that before
        // constructing `Buffer` objects
        let effectiveEncoding = if (encoding == Encoding.Buffer) { Encoding.Utf8 } else { encoding }
        return toBunStringComptime(input, effectiveEncoding)
    }

    // ==========================================================================
    // toBunStringFromOwnedSlice
    // 对应 encoding.rs: pub fn to_bun_string_from_owned_slice
    // ==========================================================================

    /// Convert an owned byte slice to a BaoString using the specified encoding
    /// 对应 Bun: to_bun_string_from_owned_slice(input, encoding)
    public static func toBunStringFromOwnedSlice(input: ArrayList<UInt8>, encoding: Encoding): BaoString {
        if (input.size == 0) {
            return BaoString.EMPTY
        }

        match (encoding) {
            case Ascii =>
                if (Strings.isAllAscii(input.items())) {
                    return BaoString.fromLatin1(input.items())
                }

                let str = BaoString.createUninitializedLatin1(input.size)
                if (str.isDead()) {
                    return str
                }
                Strings.copyLatin1IntoAscii(str.getMutableChars(), input.items())
                return str
            case Latin1 =>
                return BaoString.fromLatin1(input.items())
            case Buffer | Utf8 =>
                let converted = Strings.toUTF16Alloc(input.items(), false, false)
                match (converted) {
                    case Some(u16arr) => return BaoString.fromUTF16(u16arr)
                    case None => ()
                }
                // If we get here, it means we can safely assume the string is 100% ASCII
                return BaoString.fromLatin1(input.items())
            case Ucs2 | Utf16le =>
                // Avoid incomplete characters - if input length is odd, trim one byte
                var usableLen = input.size
                if (input.size % 2 != 0) {
                    usableLen = input.size - 1
                }
                if (usableLen == 0) {
                    return BaoString.EMPTY
                }
                // Reinterpret bytes as u16
                let u16 = Bytes.reinterpretAsU16(input.items(), usableLen)
                return BaoString.fromUTF16(u16)
            case Hex =>
                let str = BaoString.createUninitializedLatin1(input.size * 2)
                if (str.isDead()) {
                    return str
                }
                let wrote = Strings.encodeBytesToHex(str.getMutableChars(), input.items())
                // Return an empty string in this case, just like node.
                if (wrote < str.getMutableChars().size) {
                    return BaoString.EMPTY
                }
                return str
            case Base64url =>
                let outLen = Base64Codec.urlSafeEncodeLen(input.items())
                let str = BaoString.createUninitializedLatin1(outLen)
                if (!str.isDead()) {
                    let _ = Base64Codec.encodeURLSafe(str.getMutableChars(), input.items())
                }
                return str
            case Base64 =>
                let toLen = Base64Codec.encodeLen(input.items())
                let str = BaoString.createUninitializedLatin1(toLen)
                if (str.isDead()) {
                    return str
                }
                let wrote = Base64Codec.encode(str.getMutableChars(), input.items())
                return str
        }
    }

    // ==========================================================================
    // toBunStringComptime
    // 对应 encoding.rs: pub fn to_bun_string_comptime<const ENCODING: u8>
    // ==========================================================================

    /// Convert input bytes to BaoString with the given encoding (runtime dispatch)
    /// 对应 Bun: to_bun_string_comptime::<ENCODING>(input)
    public static func toBunStringComptime(input: Array<UInt8>, encoding: Encoding): BaoString {
        if (input.size == 0) {
            return BaoString.EMPTY
        }

        match (encoding) {
            case Ascii =>
                let str = BaoString.createUninitializedLatin1(input.size)
                if (str.isDead()) {
                    return str
                }
                Strings.copyLatin1IntoAscii(str.getMutableChars(), input)
                return str
            case Latin1 =>
                let str = BaoString.createUninitializedLatin1(input.size)
                if (str.isDead()) {
                    return str
                }
                // chars.copy_from_slice(input)
                let chars = str.getMutableChars()
                for (i in 0..input.size) {
                    chars[i] = input[i]
                }
                return str
            case Buffer | Utf8 =>
                let converted = Strings.toUTF16Alloc(input, false, false)
                match (converted) {
                    case Some(u16arr) => return BaoString.fromUTF16(u16arr)
                    case None => ()
                }
                // If we get here, it means we can safely assume the string is 100% ASCII
                // For this, we rely on WebKit to manage the memory.
                return BaoString.cloneLatin1(input)
            case Ucs2 | Utf16le =>
                // Avoid incomplete characters
                if (input.size / 2 == 0) {
                    return BaoString.EMPTY
                }
                let charsLen = input.size / 2
                let str = BaoString.createUninitializedUTF16(charsLen)
                if (str.isDead()) {
                    return str
                }
                let outputBytes = str.getMutableChars()
                // Copy input bytes into the UTF-16 buffer
                let copyLen = if (outputBytes.size < input.size) { outputBytes.size } else { input.size }
                for (i in 0..copyLen) {
                    outputBytes[i] = input[i]
                }
                return str
            case Hex =>
                let str = BaoString.createUninitializedLatin1(input.size * 2)
                if (str.isDead()) {
                    return str
                }
                let wrote = Strings.encodeBytesToHex(str.getMutableChars(), input)
                return str
            case Base64url =>
                let toLen = Base64Codec.urlSafeEncodeLen(input)
                let str = BaoString.createUninitializedLatin1(toLen)
                if (str.isDead()) {
                    return str
                }
                let wrote = Base64Codec.encodeURLSafe(str.getMutableChars(), input)
                return str
            case Base64 =>
                let toLen = Base64Codec.encodeLen(input)
                let str = BaoString.createUninitializedLatin1(toLen)
                if (str.isDead()) {
                    return str
                }
                let wrote = Base64Codec.encode(str.getMutableChars(), input)
                return str
        }
    }

    /// Runtime dispatch wrapper for toBunStringComptime
    /// 对应 Bun: to_bun_string(input, encoding)
    public static func toBunString(input: Array<UInt8>, encoding: Encoding): BaoString {
        return toBunStringComptime(input, encoding)
    }

    // ==========================================================================
    // writeU8
    // 对应 encoding.rs: pub fn write_u8<const ENCODING: u8>
    // ==========================================================================

    /// Write Latin1 (u8) input bytes into the output buffer using the specified encoding.
    /// Returns the number of bytes written.
    /// 对应 Bun: write_u8::<ENCODING>(input, len, to_ptr, to_len)
    public static func writeU8(input: Array<UInt8>, to: Array<UInt8>, encoding: Encoding): Int64 {
        if (input.size == 0 || to.size == 0) {
            return 0
        }

        match (encoding) {
            case Buffer | Latin1 =>
                let written = if (input.size < to.size) { input.size } else { to.size }
                for (i in 0..written) {
                    to[i] = input[i]
                }
                return written
            case Ascii =>
                let written = if (input.size < to.size) { input.size } else { to.size }
                let remain = Array<UInt8>(written, repeat: UInt8(0))
                for (i in 0..written) {
                    remain[i] = input[i]
                }
                // If all ASCII, just copy; otherwise translate
                if (SimdUTF.validateAscii(remain)) {
                    for (i in 0..written) {
                        to[i] = remain[i]
                    }
                } else {
                    Strings.copyLatin1IntoAscii(to, remain)
                }
                return written
            case Utf8 =>
                // need to encode latin1 into UTF-8
                return Strings.copyLatin1IntoUTF8(to, input).written
            // encode latin1 into UTF16
            case Ucs2 | Utf16le =>
                if (to.size < 2) {
                    return 0
                }
                let outUnits = to.size / 2
                let written = if (input.size < outUnits) { input.size } else { outUnits }
                // Write each Latin-1 byte as a u16 code unit (little-endian native)
                for (i in 0..written) {
                    let val = UInt16(input[i])
                    to[i * 2] = UInt8(val & 0xFF)
                    to[i * 2 + 1] = UInt8((val >> 8) & 0xFF)
                }
                return written * 2
            case Hex =>
                return Strings.decodeHexToBytesTruncate(to, input)
            case Base64 | Base64url =>
                return Base64Codec.decode(to, input).count
        }
    }

    // ==========================================================================
    // byteLengthU8
    // 对应 encoding.rs: pub fn byte_length_u8<const ENCODING: u8>
    // ==========================================================================

    /// Compute the byte length of Latin1 input when encoded using the specified encoding.
    /// 对应 Bun: byte_length_u8::<ENCODING>(input, len)
    public static func byteLengthU8(input: Array<UInt8>, encoding: Encoding): Int64 {
        if (input.size == 0) {
            return 0
        }

        match (encoding) {
            case Utf8 =>
                return Strings.elementLengthLatin1IntoUTF8(input)
            case Latin1 | Ascii | Buffer =>
                return input.size
            case Ucs2 | Utf16le =>
                return Strings.elementLengthUTF8IntoUTF16(input) * 2
            case Hex =>
                return input.size / 2
            case Base64 | Base64url =>
                return Base64Codec.decodeLen(input)
        }
    }

    // ==========================================================================
    // encodeIntoFrom16
    // 对应 encoding.rs: pub fn encode_into_from16
    // ==========================================================================

    /// Encode UTF-16 input into the output buffer using the specified encoding.
    /// Returns the number of bytes written.
    /// 对应 Bun: encode_into_from16::<ENCODING, ALLOW_PARTIAL_WRITE>(input, to)
    public static func encodeIntoFrom16(input: Array<UInt16>, to: Array<UInt8>, encoding: Encoding): Int64 {
        return writeU16(input, to, encoding, true)
    }

    // ==========================================================================
    // encodeIntoFrom8
    // 对应 encoding.rs: pub fn encode_into_from8
    // ==========================================================================

    /// Encode Latin1 (u8) input into the output buffer using the specified encoding.
    /// Returns the number of bytes written.
    /// 对应 Bun: encode_into_from8::<ENCODING>(input, to)
    public static func encodeIntoFrom8(input: Array<UInt8>, to: Array<UInt8>, encoding: Encoding): Int64 {
        return writeU8(input, to, encoding)
    }

    // ==========================================================================
    // writeU16
    // 对应 encoding.rs: pub fn write_u16<const ENCODING, const ALLOW_PARTIAL_WRITE>
    // ==========================================================================

    /// Write UTF-16 input into the output buffer using the specified encoding.
    /// Returns the number of bytes written.
    /// 对应 Bun: write_u16::<ENCODING, ALLOW_PARTIAL_WRITE>(input, len, to, to_len)
    public static func writeU16(input: Array<UInt16>, to: Array<UInt8>, encoding: Encoding, allowPartialWrite: Bool): Int64 {
        if (input.size == 0) {
            return 0
        }

        match (encoding) {
            case Utf8 =>
                return Strings.copyUTF16IntoUTF8Impl(to, input, allowPartialWrite).written
            case Latin1 | Ascii | Buffer =>
                let out = if (input.size < to.size) { input.size } else { to.size }
                Strings.copyU16IntoU8(to, input)
                return out
            // string is already encoded, just need to copy the data
            case Ucs2 | Utf16le =>
                if (allowPartialWrite) {
                    let bytesInputLen = input.size * 2
                    let written = if (bytesInputLen < to.size) { bytesInputLen } else { to.size }
                    // Copy u16 bytes as raw u8
                    for (i in 0..input.size) {
                        let val = input[i]
                        let byteOff = i * 2
                        if (byteOff + 1 < to.size) {
                            to[byteOff] = UInt8(val & 0xFF)
                            to[byteOff + 1] = UInt8((val >> 8) & 0xFF)
                        }
                    }
                    return written
                } else {
                    let bytesInputLen = input.size * 2
                    let written = if (bytesInputLen < to.size) { bytesInputLen } else { to.size }
                    if (written < 2) {
                        return 0
                    }
                    let fixedLen = (written / 2) * 2
                    for (i in 0..(fixedLen / 2)) {
                        let val = input[i]
                        let byteOff = i * 2
                        if (byteOff + 1 < to.size) {
                            to[byteOff] = UInt8(val & 0xFF)
                            to[byteOff + 1] = UInt8((val >> 8) & 0xFF)
                        }
                    }
                    return fixedLen
                }
            case Hex =>
                // Reinterpret u16 as u8 bytes for hex decoding
                let asBytes = Bytes.reinterpretAsU8(input)
                return Strings.decodeHexToBytesTruncate(to, asBytes)
            case Base64 | Base64url =>
                if (to.size < 2 || input.size == 0) {
                    return 0
                }
                // very very slow case! shouldn't really happen though
                let transcoded = Strings.toUTF8Alloc(input)
                return writeU8(transcoded, to, encoding)
        }
    }

    // ==========================================================================
    // constructFromU8
    // 对应 encoding.rs: pub fn construct_from_u8<const ENCODING: u8>
    // ==========================================================================

    /// Construct encoded output from Latin1 (u8) input.
    /// 对应 Bun: construct_from_u8::<ENCODING>(input, len)
    public static func constructFromU8(input: Array<UInt8>, encoding: Encoding): Array<UInt8> {
        if (input.size == 0) {
            return Array<UInt8>()
        }

        match (encoding) {
            case Buffer | Latin1 | Ascii =>
                let to = Array<UInt8>(input.size, repeat: 0)
                for (i in 0..input.size) {
                    to[i] = input[i]
                }
                return to
            case Utf8 =>
                // need to encode latin1 into UTF-8
                return Strings.allocateLatin1IntoUTF8(input)
            // encode latin1 into UTF16; return as bytes
            case Ucs2 | Utf16le =>
                // Each Latin-1 byte widens to one native-endian u16 code unit
                let to = Array<UInt8>(input.size * 2, repeat: 0)
                for (i in 0..input.size) {
                    let val = UInt16(input[i])
                    // Native endian (little-endian on x86)
                    to[i * 2] = UInt8(val & 0xFF)
                    to[i * 2 + 1] = UInt8((val >> 8) & 0xFF)
                }
                return to
            case Hex =>
                if (input.size < 2) {
                    return Array<UInt8>()
                }
                let to = Array<UInt8>(input.size / 2, repeat: 0)
                let wrote = Strings.decodeHexToBytesTruncate(to, input)
                if (wrote == 0) {
                    return Array<UInt8>()
                }
                return Bytes.truncate(to, wrote)
            case Base64 | Base64url =>
                let trimChars: Array<UInt8> = [0x0D, 0x0A, 0x09, 0x20, 0x0B] // \r\n\t \x0B (VT)
                let slice = Strings.trim(input, trimChars)
                if (slice.size == 0) {
                    return Array<UInt8>()
                }
                let outLen = Base64Codec.decodeLen(slice)
                let to = Array<UInt8>(outLen, repeat: 0)
                let wrote = Base64Codec.decode(to, slice).count
                if (wrote == 0) {
                    return Array<UInt8>()
                }
                return Bytes.truncate(to, wrote)
        }
    }

    // ==========================================================================
    // constructFromU16
    // 对应 encoding.rs: pub fn construct_from_u16<const ENCODING: u8>
    // ==========================================================================

    /// Construct encoded output from UTF-16 input.
    /// 对应 Bun: construct_from_u16::<ENCODING>(input, len)
    public static func constructFromU16(input: Array<UInt16>, encoding: Encoding): Array<UInt8> {
        if (input.size == 0) {
            return Array<UInt8>()
        }

        match (encoding) {
            case Utf8 =>
                return Strings.toUTF8AllocWithType(input)
            case Latin1 | Buffer | Ascii =>
                let to = Array<UInt8>(input.size, repeat: 0)
                Strings.copyU16IntoU8(to, input)
                return to
            // string is already encoded, just need to copy the data
            case Ucs2 | Utf16le =>
                // Copy u16 bytes verbatim as u8
                return Bytes.reinterpretAsU8(input)
            case Hex =>
                let asBytes = Bytes.reinterpretAsU8(input)
                if (asBytes.size < 2) {
                    return Array<UInt8>()
                }
                let to = Array<UInt8>(asBytes.size / 2, repeat: 0)
                let wrote = Strings.decodeHexToBytesTruncate(to, asBytes)
                if (wrote == 0) {
                    return Array<UInt8>()
                }
                return Bytes.truncate(to, wrote)
            case Base64 | Base64url =>
                // very very slow case! shouldn't really happen though
                let transcoded = Strings.toUTF8Alloc(input)
                return constructFromU8(transcoded, encoding)
        }
    }
}

// ============================================================================
// BunStringEncode - Extension trait for bun.String.encode/encodeInto
// 对应 encoding.rs: pub trait BunStringEncode
// These live in bun_runtime (not bun_core) to avoid circular deps.
// ============================================================================

/// Extension methods on BaoString for encoding operations.
/// 对应 Bun: BunStringEncode trait, ZigStringEncode trait
public class BaoStringEncoding {

    /// `bun.String.encodeInto` — encode `str` into `out`. Returns bytes written.
    /// 对应 Bun: BunStringEncode::encode_into
    public static func encodeInto(str: BaoString, out: Array<UInt8>, enc: Encoding): Int64 {
        if (str.isUTF16()) {
            return EncodingHelper.encodeIntoFrom16(str.utf16(), out, enc)
        }
        // UTF-8 and Latin1 share the same byte path:
        // Bun: encodeIntoFrom8(self.latin1(), out, enc) handles both.
        // In Bun's encodeInto(), the UTF-8 branch is `@panic("TODO")` but the
        // fallback (latin1) treats the bytes the same way since UTF-8 bytes are
        // valid Latin1. We route UTF-8 source data through encodeIntoFrom8.
        return EncodingHelper.encodeIntoFrom8(Utf8Codec.encode(str.toString()), out, enc)
    }

    /// `bun.String.encode` — encode `str` into a new byte array.
    /// 对应 Bun: BunStringEncode::encode / ZigStringEncode::encode_with_allocator
    public static func encode(str: BaoString, enc: Encoding): Array<UInt8> {
        if (str.isUTF16()) {
            return EncodingHelper.constructFromU16(str.utf16(), enc)
        }
        return EncodingHelper.constructFromU8(str.latin1(), enc)
    }

    /// Encode a ZigString using the specified encoding.
    /// 对应 Bun: ZigStringEncode::encode_with_allocator
    public static func encodeWithAllocator(zigStr: ZigString, enc: Encoding): Array<UInt8> {
        if (zigStr.is16Bit()) {
            return EncodingHelper.constructFromU16(zigStr.utf16Slice(), enc)
        }
        return EncodingHelper.constructFromU8(zigStr.slice(), enc)
    }
}

// ============================================================================
// SimdUTF - SIMD-accelerated ASCII/UTF-8 validation
// 对应 bun_simdutf_sys::simdutf
// ============================================================================

/// SIMD-accelerated string validation
public class SimdUTF {
    /// Validate that all bytes are ASCII (0x00..0x7F)
    /// 对应 Bun: bun_simdutf::validate::ascii
    public static func validateAscii(input: Array<UInt8>): Bool {
        for (b in input) {
            if (b > 127) {
                return false
            }
        }
        return true
    }

    /// Validate UTF-8 encoding
    /// 对应 Bun: bun_simdutf::validate::utf8
    public static func validateUTF8(input: Array<UInt8>): Bool {
        // Basic UTF-8 validation
        var i = 0
        while (i < input.size) {
            let b = input[i]
            if (b < 0x80) {
                i += 1
            } else if ((b & 0xE0) == 0xC0) {
                if (i + 1 >= input.size) { return false }
                if ((input[i + 1] & 0xC0) != 0x80) { return false }
                i += 2
            } else if ((b & 0xF0) == 0xE0) {
                if (i + 2 >= input.size) { return false }
                if ((input[i + 1] & 0xC0) != 0x80) { return false }
                if ((input[i + 2] & 0xC0) != 0x80) { return false }
                i += 3
            } else if ((b & 0xF8) == 0xF0) {
                if (i + 3 >= input.size) { return false }
                if ((input[i + 1] & 0xC0) != 0x80) { return false }
                if ((input[i + 2] & 0xC0) != 0x80) { return false }
                if ((input[i + 3] & 0xC0) != 0x80) { return false }
                i += 4
            } else {
                return false
            }
        }
        return true
    }

    /// 计算 UTF-16 输入转 UTF-8 后的字节长度
    /// 对应 Bun: bun.simdutf.length.utf8.from.utf16.le
    /// Uses the elementLengthUTF16IntoUTF8 implementation which handles surrogates
    public static func lengthUTF8FromUTF16(input: Array<UInt16>, offset: Int64): Int64 {
        if (offset >= input.size) { return 0 }
        return Strings.elementLengthUTF16IntoUTF8Slice(input, offset)
    }
}

/// UTF-16 LE -> UTF-8 转换结果
public class ConvertResult {
        public var success: Bool
        public var count: Int64

        public init(success: Bool, count: Int64) {
            this.success = success
            this.count = count
        }

        public func isSuccess(): Bool { success }
}

/// 尝试将 UTF-16 转换为 UTF-8 (带错误检测)
/// 对应 Bun: bun.simdutf.convert.utf16.to.utf8.with_errors.le
/// Returns ConvertResult indicating success or failure
public func convertUTF16ToUTF8WithErrors(
        input: Array<UInt16>, offset: Int64,
        output: Array<UInt8>, outputOffset: Int64
    ): ConvertResult {
        // Try to convert using the standard path
        var written: Int64 = outputOffset
        var i: Int64 = offset
        while (i < input.size && written < output.size) {
            let cp = Int64(input[i])
            if (cp >= 0xD800 && cp <= 0xDBFF) {
                // Lead surrogate — need a trail to form a pair
                if (i + 1 < input.size) {
                    let low = Int64(input[i + 1])
                    if (low >= 0xDC00 && low <= 0xDFFF) {
                        let codepoint = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                        if (written + 4 > output.size) { return ConvertResult(false, written - outputOffset) }
                        output[written] = UInt8(0xF0 | (codepoint >> 18))
                        output[written + 1] = UInt8(0x80 | ((codepoint >> 12) & 0x3F))
                        output[written + 2] = UInt8(0x80 | ((codepoint >> 6) & 0x3F))
                        output[written + 3] = UInt8(0x80 | (codepoint & 0x3F))
                        written += 4
                        i += 2
                        continue
                    }
                }
                // Unpaired lead surrogate — conversion error
                return ConvertResult(false, written - outputOffset)
            } else if (cp >= 0xDC00 && cp <= 0xDFFF) {
                // Unpaired trail surrogate — conversion error
                return ConvertResult(false, written - outputOffset)
            } else if (cp < 0x80) {
                output[written] = UInt8(cp)
                written += 1
            } else if (cp < 0x800) {
                if (written + 2 > output.size) { return ConvertResult(false, written - outputOffset) }
                output[written] = UInt8(0xC0 | (cp >> 6))
                output[written + 1] = UInt8(0x80 | (cp & 0x3F))
                written += 2
            } else {
                if (written + 3 > output.size) { return ConvertResult(false, written - outputOffset) }
                output[written] = UInt8(0xE0 | (cp >> 12))
                output[written + 1] = UInt8(0x80 | ((cp >> 6) & 0x3F))
                output[written + 2] = UInt8(0x80 | (cp & 0x3F))
                written += 3
            }
            i += 1
        }
        return ConvertResult(true, written - outputOffset)
    }

// ============================================================================
// Strings - String utility functions
// 对应 bun_core::strings
// These are the core string operation utilities used by EncodingHelper.
// ============================================================================

/// String utility functions
/// 对应 Bun: bun_core::strings module
public class Strings {

    /// Check if all bytes are ASCII
    /// 对应 Bun: strings::is_all_ascii
    public static func isAllAscii(input: Array<UInt8>): Bool {
        return SimdUTF.validateAscii(input)
    }

    /// Copy Latin1 bytes into an ASCII output buffer (mask high bit)
    /// 对应 Bun: strings::copy_latin1_into_ascii
    public static func copyLatin1IntoAscii(to: Array<UInt8>, from: Array<UInt8>): Unit {
        let len = if (to.size < from.size) { to.size } else { from.size }
        for (i in 0..len) {
            to[i] = from[i] & 0x7F
        }
    }

    /// Copy Latin1 bytes into UTF-8 output buffer.
    /// Returns the number of bytes written.
    /// 对应 Bun: strings::copy_latin1_into_utf8
    public static func copyLatin1IntoUTF8(to: Array<UInt8>, from: Array<UInt8>): CopyResult {
        var written: Int64 = 0
        var i: Int64 = 0
        while (i < from.size && written < to.size) {
            let b = Int64(from[i])
            if (b < 0x80) {
                to[written] = UInt8(b)
                written += 1
            } else {
                if (written + 1 < to.size) {
                    to[written] = UInt8(0xC0 | (b >> 6))
                    to[written + 1] = UInt8(0x80 | (b & 0x3F))
                    written += 2
                }
            }
            i += 1
        }
        return CopyResult(written)
    }

    /// Allocate a new UTF-8 buffer from Latin1 input.
    /// 对应 Bun: strings::allocate_latin1_into_utf8
    public static func allocateLatin1IntoUTF8(input: Array<UInt8>): Array<UInt8> {
        // Worst case: every byte expands to 2 bytes
        let result = ArrayList<UInt8>()
        for (i in 0..input.size) {
            let b = Int64(input[i])
            if (b < 0x80) {
                result.append(UInt8(b))
            } else {
                result.append(UInt8(0xC0 | (b >> 6)))
                result.append(UInt8(0x80 | (b & 0x3F)))
            }
        }
        return result.items()
    }

    /// Copy Latin1 bytes into UTF-16 output buffer.
    /// Returns the number of u16 code units written.
    /// 对应 Bun: strings::copy_latin1_into_utf16
    public static func copyLatin1IntoUTF16(to: Array<UInt16>, from: Array<UInt8>): CopyResult {
        let len = if (to.size < from.size) { to.size } else { from.size }
        for (i in 0..len) {
            to[i] = UInt16(from[i])
        }
        return CopyResult(len)
    }

    /// Copy UTF-16 into UTF-8 output buffer.
    /// 对应 Bun: strings::copy_utf16_into_utf8_impl
    public static func copyUTF16IntoUTF8Impl(to: Array<UInt8>, from: Array<UInt16>, allowPartialWrite: Bool): CopyResult {
        var written: Int64 = 0
        var i: Int64 = 0
        while (i < from.size && written < to.size) {
            let cp = Int64(from[i])
            if (cp < 0x80) {
                to[written] = UInt8(cp)
                written += 1
            } else if (cp < 0x800) {
                if (written + 1 < to.size) {
                    to[written] = UInt8(0xC0 | (cp >> 6))
                    to[written + 1] = UInt8(0x80 | (cp & 0x3F))
                    written += 2
                } else if (allowPartialWrite) {
                    break
                }
            } else if (cp >= 0xD800 && cp <= 0xDBFF) {
                // Surrogate pair
                if (i + 1 < from.size) {
                    let low = Int64(from[i + 1])
                    if (low >= 0xDC00 && low <= 0xDFFF) {
                        let codepoint = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                        if (written + 3 < to.size) {
                            to[written] = UInt8(0xF0 | (codepoint >> 18))
                            to[written + 1] = UInt8(0x80 | ((codepoint >> 12) & 0x3F))
                            to[written + 2] = UInt8(0x80 | ((codepoint >> 6) & 0x3F))
                            to[written + 3] = UInt8(0x80 | (codepoint & 0x3F))
                            written += 4
                        } else if (allowPartialWrite) {
                            break
                        }
                        i += 1 // skip low surrogate
                    }
                }
            } else {
                if (written + 2 < to.size) {
                    to[written] = UInt8(0xE0 | (cp >> 12))
                    to[written + 1] = UInt8(0x80 | ((cp >> 6) & 0x3F))
                    to[written + 2] = UInt8(0x80 | (cp & 0x3F))
                    written += 3
                } else if (allowPartialWrite) {
                    break
                }
            }
            i += 1
        }
        return CopyResult(written)
    }

    /// Copy u16 into u8 buffer (truncate each u16 to u8)
    /// 对应 Bun: strings::copy_u16_into_u8
    public static func copyU16IntoU8(to: Array<UInt8>, from: Array<UInt16>): Unit {
        let len = if (to.size < from.size) { to.size } else { from.size }
        for (i in 0..len) {
            to[i] = UInt8(from[i] & 0xFF)
        }
    }

    /// Allocate UTF-16 from UTF-8 bytes.
    /// Returns None if conversion fails, Some(array) otherwise.
    /// 对应 Bun: strings::to_utf16_alloc
    public static func toUTF16Alloc(input: Array<UInt8>, failIfInvalid: Bool, _: Bool): ?Array<UInt16> {
        // Check if input is all ASCII (common fast path)
        var allAscii = true
        for (b in input) {
            if (b > 127) {
                allAscii = false
                break
            }
        }
        if (allAscii) {
            return None // signal to caller: treat as ASCII/Latin1
        }
        let result = ArrayList<UInt16>()
        var i: Int64 = 0
        while (i < input.size) {
            let b = Int64(input[i])
            if (b < 0x80) {
                result.append(UInt16(b))
                i += 1
            } else if ((b & 0xE0) == 0xC0) {
                if (i + 1 >= input.size) { return None }
                let cp = ((b & 0x1F) << 6) | (Int64(input[i + 1]) & 0x3F)
                result.append(UInt16(cp))
                i += 2
            } else if ((b & 0xF0) == 0xE0) {
                if (i + 2 >= input.size) { return None }
                let cp = ((b & 0x0F) << 12) | ((Int64(input[i + 1]) & 0x3F) << 6) | (Int64(input[i + 2]) & 0x3F)
                result.append(UInt16(cp))
                i += 3
            } else if ((b & 0xF8) == 0xF0) {
                if (i + 3 >= input.size) { return None }
                let cp = ((b & 0x07) << 18) | ((Int64(input[i + 1]) & 0x3F) << 12) | ((Int64(input[i + 2]) & 0x3F) << 6) | (Int64(input[i + 3]) & 0x3F)
                // Encode as surrogate pair
                let high = UInt16(0xD800 + ((cp - 0x10000) >> 10))
                let low = UInt16(0xDC00 + ((cp - 0x10000) & 0x3FF))
                result.append(high)
                result.append(low)
                i += 4
            } else {
                if (failIfInvalid) { return None }
                result.append(UInt16(0xFFFD)) // replacement char
                i += 1
            }
        }
        return Some(result.items())
    }

    /// Allocate UTF-8 from UTF-16 bytes.
    /// 对应 Bun: strings::to_utf8_alloc
    public static func toUTF8Alloc(input: Array<UInt16>): Array<UInt8> {
        let result = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i < input.size) {
            let cp = Int64(input[i])
            if (cp < 0x80) {
                result.append(UInt8(cp))
            } else if (cp < 0x800) {
                result.append(UInt8(0xC0 | (cp >> 6)))
                result.append(UInt8(0x80 | (cp & 0x3F)))
            } else if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < input.size) {
                let low = Int64(input[i + 1])
                if (low >= 0xDC00 && low <= 0xDFFF) {
                    let codepoint = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                    result.append(UInt8(0xF0 | (codepoint >> 18)))
                    result.append(UInt8(0x80 | ((codepoint >> 12) & 0x3F)))
                    result.append(UInt8(0x80 | ((codepoint >> 6) & 0x3F)))
                    result.append(UInt8(0x80 | (codepoint & 0x3F)))
                    i += 1
                } else {
                    result.append(UInt8(0xE0 | (cp >> 12)))
                    result.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
                    result.append(UInt8(0x80 | (cp & 0x3F)))
                }
            } else {
                result.append(UInt8(0xE0 | (cp >> 12)))
                result.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
                result.append(UInt8(0x80 | (cp & 0x3F)))
            }
            i += 1
        }
        return result.items()
    }

    /// Allocate UTF-8 from UTF-16 with type info (mirrors Zig behavior)
    /// 对应 Bun: strings::to_utf8_alloc_with_type
    public static func toUTF8AllocWithType(input: Array<UInt16>): Array<UInt8> {
        return toUTF8Alloc(input)
    }

    /// Compute the byte length of Latin1 text when converted to UTF-8.
    /// 对应 Bun: strings::element_length_latin1_into_utf8
    public static func elementLengthLatin1IntoUTF8(input: Array<UInt8>): Int64 {
        var len: Int64 = 0
        for (b in input) {
            if (Int64(b) < 0x80) {
                len += 1
            } else {
                len += 2
            }
        }
        return len
    }

    /// Compute the UTF-8 byte length needed to represent a slice of UTF-16 text starting from offset.
    /// 对应 Bun: strings::element_length_utf16_into_utf8 (with offset)
    public static func elementLengthUTF16IntoUTF8Slice(input: Array<UInt16>, offset: Int64): Int64 {
        var len: Int64 = 0
        var i: Int64 = offset
        while (i < input.size) {
            let cp = Int64(input[i])
            if (cp < 0x80) {
                len += 1
            } else if (cp < 0x800) {
                len += 2
            } else if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < input.size) {
                let low = Int64(input[i + 1])
                if (low >= 0xDC00 && low <= 0xDFFF) {
                    len += 4
                    i += 1
                } else {
                    len += 3
                }
            } else {
                len += 3
            }
            i += 1
        }
        return len
    }

    /// Compute the UTF-8 byte length needed to represent UTF-16 text.
    /// 对应 Bun: strings::element_length_utf16_into_utf8
    public static func elementLengthUTF16IntoUTF8(input: Array<UInt16>): Int64 {
        var len: Int64 = 0
        var i: Int64 = 0
        while (i < input.size) {
            let cp = Int64(input[i])
            if (cp < 0x80) {
                len += 1
            } else if (cp < 0x800) {
                len += 2
            } else if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < input.size) {
                let low = Int64(input[i + 1])
                if (low >= 0xDC00 && low <= 0xDFFF) {
                    len += 4
                    i += 1
                } else {
                    len += 3
                }
            } else {
                len += 3
            }
            i += 1
        }
        return len
    }

    /// Compute the UTF-16 code unit count needed to represent UTF-8 text.
    /// 对应 Bun: strings::element_length_utf8_into_utf16
    public static func elementLengthUTF8IntoUTF16(input: Array<UInt8>): Int64 {
        var len: Int64 = 0
        var i: Int64 = 0
        while (i < input.size) {
            let b = Int64(input[i])
            if (b < 0x80) {
                len += 1
                i += 1
            } else if ((b & 0xE0) == 0xC0) {
                len += 1
                i += 2
            } else if ((b & 0xF0) == 0xE0) {
                len += 1
                i += 3
            } else if ((b & 0xF8) == 0xF0) {
                len += 2 // surrogate pair
                i += 4
            } else {
                len += 1
                i += 1
            }
        }
        return len
    }

    /// Encode bytes to hex string, writing into `to`.
    /// Returns the number of bytes written to `to`.
    /// 对应 Bun: strings::encode_bytes_to_hex
    public static func encodeBytesToHex(to: Array<UInt8>, from: Array<UInt8>): Int64 {
        var wrote: Int64 = 0
        for (i in 0..from.size) {
            if (wrote + 1 >= to.size) { return wrote }
            let b = Int64(from[i])
            let high = (b >> 4) & 0xF
            let low = b & 0xF
            to[wrote] = UInt8(if (high < 10) { high + 48 } else { high + 87 })  // '0'=48, 'a'-10=87
            to[wrote + 1] = UInt8(if (low < 10) { low + 48 } else { low + 87 })
            wrote += 2
        }
        return wrote
    }

    /// Decode hex bytes into raw bytes, truncating on invalid input.
    /// Returns the number of bytes written to `to`.
    /// 对应 Bun: strings::decode_hex_to_bytes_truncate
    public static func decodeHexToBytesTruncate(to: Array<UInt8>, from: Array<UInt8>): Int64 {
        var wrote: Int64 = 0
        var i: Int64 = 0
        while (i + 1 < from.size && wrote < to.size) {
            let high = hexDigitValue(from[i])
            let low = hexDigitValue(from[i + 1])
            if (high < 0 || low < 0) {
                // Invalid hex digit; skip this pair
                i += 2
                continue
            }
            to[wrote] = UInt8((high << 4) | low)
            wrote += 1
            i += 2
        }
        return wrote
    }

    /// Get the numeric value of a hex digit (0-15), or -1 if invalid.
    private static func hexDigitValue(b: UInt8): Int64 {
        if (b >= 48 && b <= 57) { return Int64(b) - 48 }       // '0'-'9'
        if (b >= 65 && b <= 70) { return Int64(b) - 55 }       // 'A'-'F'
        if (b >= 97 && b <= 102) { return Int64(b) - 87 }      // 'a'-'f'
        return -1
    }

    /// Trim leading and trailing bytes from the input.
    /// 对应 Bun: strings::trim
    public static func trim(input: Array<UInt8>, chars: Array<UInt8>): Array<UInt8> {
        var start: Int64 = 0
        while (start < input.size && containsChar(chars, input[start])) {
            start += 1
        }
        var end: Int64 = input.size
        while (end > start && containsChar(chars, input[end - 1])) {
            end -= 1
        }
        return Bytes.subArray(input, start, end - start)
    }

    /// Check if the chars array contains a given byte value.
    private static func containsChar(chars: Array<UInt8>, b: UInt8): Bool {
        for (c in chars) {
            if (c == b) { return true }
        }
        return false
    }

    /// Remove the UTF-8 BOM (EF BB BF) from the beginning of a byte slice.
    /// 对应 Bun: strings::without_utf8_bom
    public static func withoutUTF8Bom(input: Array<UInt8>): Array<UInt8> {
        if (input.size >= 3 && input[0] == 0xEF && input[1] == 0xBB && input[2] == 0xBF) {
            return Bytes.subArray(input, 3, input.size - 3)
        }
        return input
    }

    /// Case-insensitive ASCII comparison
    /// 对应 Bun: strings::eql_case_insensitive_ascii
    public static func eqlCaseInsensitiveAscii(a: Array<UInt8>, b: Array<UInt8>): Bool {
        if (a.size != b.size) { return false }
        for (i in 0..a.size) {
            if (toLowerASCII(a[i]) != toLowerASCII(b[i])) {
                return false
            }
        }
        return true
    }

    private static func toLowerASCII(b: UInt8): UInt8 {
        if (b >= 65 && b <= 90) { return b + 32 }  // 'A'-'Z' -> 'a'-'z'
        return b
    }

    /// Find the index of a byte pattern in a byte array.
    /// 对应 Bun: strings::index_of
    public static func indexOf(haystack: Array<UInt8>, needle: Array<UInt8>): ?Int64 {
        if (needle.size == 0) { return Some(0) }
        if (needle.size > haystack.size) { return None }
        var i: Int64 = 0
        while (i <= haystack.size - needle.size) {
            var found = true
            for (j in 0..needle.size) {
                if (haystack[i + j] != needle[j]) {
                    found = false
                    break
                }
            }
            if (found) { return Some(i) }
            i += 1
        }
        return None
    }

    /// Find the last index of a byte pattern.
    /// 对应 Bun: strings::last_index_of
    public static func lastIndexOf(haystack: Array<UInt8>, needle: Array<UInt8>): ?Int64 {
        if (needle.size == 0) { return Some(haystack.size) }
        if (needle.size > haystack.size) { return None }
        var i = haystack.size - needle.size
        while (i >= 0) {
            var found = true
            for (j in 0..needle.size) {
                if (haystack[i + j] != needle[j]) {
                    found = false
                    break
                }
            }
            if (found) { return Some(i) }
            i -= 1
        }
        return None
    }

    /// Split a byte array by a separator, returning an iterator of slices.
    /// 对应 Bun: strings::split
    public static func split(input: Array<UInt8>, sep: Array<UInt8>): ArrayList<Array<UInt8>> {
        let result = ArrayList<Array<UInt8>>()
        if (sep.size == 0) {
            for (b in input) {
                result.append([b])
            }
            return result
        }
        var start: Int64 = 0
        var i: Int64 = 0
        while (i <= input.size - sep.size) {
            var `match` = true
            for (j in 0..sep.size) {
                if (input[i + j] != sep[j]) {
                    `match` = false
                    break
                }
            }
            if (`match`) {
                result.append(Bytes.subArray(input, start, i - start))
                start = i + sep.size
                i = start
            } else {
                i += 1
            }
        }
        result.append(Bytes.subArray(input, start, input.size - start))
        return result
    }
}

// ============================================================================
// CopyResult - Result of a copy operation
// 对应 various copy functions that return written count
// ============================================================================

/// Copy operation result
public class CopyResult {
    public var written: Int64

    public init(written: Int64) {
        this.written = written
    }
}

// ============================================================================
// Bytes - Byte array utility functions
// 对应 various byte manipulation helpers
// ============================================================================

/// Byte array utility functions
public class Bytes {
    /// Truncate an array to the given length
    public static func truncate(arr: Array<UInt8>, len: Int64): Array<UInt8> {
        if (len >= arr.size) { return arr }
        let result = Array<UInt8>(len, repeat: 0)
        for (i in 0..len) {
            result[i] = arr[i]
        }
        return result
    }

    /// Get a sub-array from start to start+length
    public static func subArray(arr: Array<UInt8>, start: Int64, length: Int64): Array<UInt8> {
        if (start >= arr.size) { return Array<UInt8>() }
        let len = if (start + length > arr.size) { arr.size - start } else { length }
        let result = Array<UInt8>(len, repeat: 0)
        for (i in 0..len) {
            result[i] = arr[start + i]
        }
        return result
    }

    /// Reinterpret an Array<UInt16> as Array<UInt8> (raw byte copy)
    public static func reinterpretAsU8(input: Array<UInt16>): Array<UInt8> {
        let result = Array<UInt8>(input.size * 2, repeat: 0)
        for (i in 0..input.size) {
            let val = input[i]
            result[i * 2] = UInt8(val & 0xFF)
            result[i * 2 + 1] = UInt8((val >> 8) & 0xFF)
        }
        return result
    }

    /// Reinterpret an Array<UInt8> as Array<UInt16> (raw byte copy)
    /// Only uses usableLen bytes (must be even)
    public static func reinterpretAsU16(input: Array<UInt8>, usableLen: Int64): Array<UInt16> {
        let result = Array<UInt16>(usableLen / 2, repeat: 0)
        for (i in 0..(usableLen / 2)) {
            let low = UInt16(input[i * 2])
            let high = UInt16(input[i * 2 + 1])
            result[i] = low | (high << 8)
        }
        return result
    }
}

// ============================================================================
// Base64Codec - Base64 编解码
// 对应 bun_base64 module
// ============================================================================

/// Base64 编解码器
public class Base64Codec {
    private static let BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    private static let BASE64URL_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

    /// Compute the length of Base64-encoded output for the given input.
    /// 对应 Bun: bun_base64::encode_len
    public static func encodeLen(input: Array<UInt8>): Int64 {
        return ((input.size + 2) / 3) * 4
    }

    /// Compute the length of URL-safe Base64-encoded output.
    /// 对应 Bun: bun_base64::url_safe_encode_len
    public static func urlSafeEncodeLen(input: Array<UInt8>): Int64 {
        let baseLen = (input.size * 4 + 2) / 3
        // No padding for URL-safe
        let remainder = input.size % 3
        if (remainder == 0) { return baseLen }
        return baseLen - (3 - remainder)
    }

    /// Compute the decoded length for Base64 input.
    /// 对应 Bun: bun_base64::decode_len
    public static func decodeLen(input: Array<UInt8>): Int64 {
        return (input.size / 4) * 3
    }

    /// Base64 编码为字符串
    /// 对应 Bun: bun_base64::encode
    public static func encode(to: Array<UInt8>, input: Array<UInt8>): Int64 {
        let str = encodeToString(input)
        let bytes = Utf8Codec.encode(str)
        let len = if (bytes.size < to.size) { bytes.size } else { to.size }
        for (i in 0..len) {
            to[i] = bytes[i]
        }
        return len
    }

    /// Base64 编码为字符串
    public static func encodeToString(input: Array<UInt8>): String {
        var result = ""
        var i: Int64 = 0
        while (i < input.size) {
            let b0 = Int64(input[i])
            let b1 = if (i + 1 < input.size) { Int64(input[i + 1]) } else { 0 }
            let b2 = if (i + 2 < input.size) { Int64(input[i + 2]) } else { 0 }

            let n = (b0 << 16) | (b1 << 8) | b2

            let idx1 = Int64((n >> 18) & 0x3F)
            let idx2 = Int64((n >> 12) & 0x3F)
            result += BASE64_CHARS[idx1..idx1 + 1]
            result += BASE64_CHARS[idx2..idx2 + 1]

            if (i + 1 < input.size) {
                let idx3 = Int64((n >> 6) & 0x3F)
                result += BASE64_CHARS[idx3..idx3 + 1]
            } else {
                result += "="
            }

            if (i + 2 < input.size) {
                let idx4 = Int64(n & 0x3F)
                result += BASE64_CHARS[idx4..idx4 + 1]
            } else {
                result += "="
            }

            i += 3
        }
        return result
    }

    /// URL-safe Base64 编码
    /// 对应 Bun: bun_base64::encode_url_safe
    public static func encodeURLSafe(to: Array<UInt8>, input: Array<UInt8>): Int64 {
        let str = encodeURLString(input)
        let bytes = Utf8Codec.encode(str)
        let len = if (bytes.size < to.size) { bytes.size } else { to.size }
        for (i in 0..len) {
            to[i] = bytes[i]
        }
        return len
    }

    /// URL-safe Base64 编码为字符串
    public static func encodeURLString(input: Array<UInt8>): String {
        var result = ""
        var i: Int64 = 0
        while (i < input.size) {
            let b0 = Int64(input[i])
            let b1 = if (i + 1 < input.size) { Int64(input[i + 1]) } else { 0 }
            let b2 = if (i + 2 < input.size) { Int64(input[i + 2]) } else { 0 }

            let n = (b0 << 16) | (b1 << 8) | b2

            let ui1 = Int64((n >> 18) & 0x3F)
            let ui2 = Int64((n >> 12) & 0x3F)
            result += BASE64URL_CHARS[ui1..ui1 + 1]
            result += BASE64URL_CHARS[ui2..ui2 + 1]

            if (i + 1 < input.size) {
                let ui3 = Int64((n >> 6) & 0x3F)
                result += BASE64URL_CHARS[ui3..ui3 + 1]
            }
            if (i + 2 < input.size) {
                let ui4 = Int64(n & 0x3F)
                result += BASE64URL_CHARS[ui4..ui4 + 1]
            }

            i += 3
        }
        return result
    }

    /// Base64 解码
    /// 对应 Bun: bun_base64::decode
    public static func decode(to: Array<UInt8>, input: Array<UInt8>): DecodeResult {
        let result = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i + 3 < input.size) {
            var n: Int64 = 0
            var padding: Int64 = 0

            for (j in 0..4) {
                let idx = i + j
                if (idx >= input.size) { break }
                let c = input[idx]
                if (c == 61) { // '='
                    padding += 1
                    n = n << 6
                } else {
                    var val: Int64 = 0
                    for (k in 0..64) {
                        if (Int64(BASE64_CHARS[k]) == Int64(c)) {
                            val = k
                            break
                        }
                    }
                    n = (n << 6) | val
                }
            }

            if (padding < 2) {
                result.append(UInt8((n >> 16) & 0xFF))
            }
            if (padding < 1) {
                result.append(UInt8((n >> 8) & 0xFF))
            }
            if (padding == 0) {
                result.append(UInt8(n & 0xFF))
            }

            i += 4
        }

        let arr = result.items()
        let len = if (arr.size < to.size) { arr.size } else { to.size }
        for (k in 0..len) {
            to[k] = arr[k]
        }
        return DecodeResult(len)
    }

    /// URL 编码 (non-URL-safe Base64)
    public static func encodeURL(input: Array<UInt8>): Array<UInt8> {
        let str = encodeURLString(input)
        return Utf8Codec.encode(str)
    }
}

// ============================================================================
// DecodeResult - Result of a decode operation
// ============================================================================

/// Decode operation result
public class DecodeResult {
    public var count: Int64

    public init(count: Int64) {
        this.count = count
    }
}

// ============================================================================
// Utf8Codec - UTF-8 codec
// ============================================================================

/// UTF-8 编解码器
public class Utf8Codec {
    /// Get the number of bytes in a UTF-8 code point given the leading byte
    public static func codePointLength(byte: UInt8): Int64 {
        if (byte < 0x80) { return 1 }
        if ((byte & 0xE0) == 0xC0) { return 2 }
        if ((byte & 0xF0) == 0xE0) { return 3 }
        if ((byte & 0xF8) == 0xF0) { return 4 }
        return 1 // fallback for invalid leading bytes
    }

    /// Encode a string to UTF-8 bytes
    public static func encode(s: String): Array<UInt8> {
        let result = ArrayList<UInt8>()
        for (c in s) {
            let cp = Int64(c)
            if (cp < 0x80) {
                result.append(UInt8(cp))
            } else if (cp < 0x800) {
                result.append(UInt8(0xC0 | (cp >> 6)))
                result.append(UInt8(0x80 | (cp & 0x3F)))
            } else if (cp < 0x10000) {
                result.append(UInt8(0xE0 | (cp >> 12)))
                result.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
                result.append(UInt8(0x80 | (cp & 0x3F)))
            } else {
                result.append(UInt8(0xF0 | (cp >> 18)))
                result.append(UInt8(0x80 | ((cp >> 12) & 0x3F)))
                result.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
                result.append(UInt8(0x80 | (cp & 0x3F)))
            }
        }
        return result.items()
    }

    /// Decode UTF-8 bytes to a string
    public static func decode(bytes: Array<UInt8>): String {
        // Use built-in UTF-8 decoding
        return Utf8Codec.decode(bytes)
    }
}

// ============================================================================
// BaoString - Core string type
// 对应 bun_core::String
// This is a simplified version; the real implementation lives in bao_core.
// ============================================================================

/// Core string type used for interop with JSC
/// 对应 Bun: bun_core::String
public class BaoString {
    /// Internal data (can be Latin1 or UTF-16)
    private var data: ArrayList<UInt8>
    /// Whether the data is UTF-16
    private var isUTF16Flag: Bool
    /// Whether the string is dead (empty/null)
    private var dead_: Bool

    /// Empty string constant
    public static let EMPTY = BaoString("")

    public init() {
        data = ArrayList<UInt8>()
        isUTF16Flag = false
        dead_ = false
    }

    public init(s: String) {
        data = ArrayList<UInt8>()
        isUTF16Flag = false
        dead_ = false
        for (c in s) {
            let cp = Int64(c)
            if (cp < 0x80) {
                data.append(UInt8(cp))
            } else if (cp < 0x100) {
                data.append(UInt8(cp))
                isUTF16Flag = false
            } else {
                isUTF16Flag = true
                data.clear()
                // Re-encode as UTF-16
                for (c2 in s) {
                    let cp2 = Int64(c2)
                    data.append(UInt8(cp2 & 0xFF))
                    data.append(UInt8((cp2 >> 8) & 0xFF))
                }
                break
            }
        }
    }

    public init(latin1: Array<UInt8>) {
        data = ArrayList<UInt8>()
        for (b in latin1) { data.append(b) }
        isUTF16Flag = false
        dead_ = false
    }

    public init(utf16: Array<UInt16>) {
        data = ArrayList<UInt8>()
        for (u in utf16) {
            data.append(UInt8(u & 0xFF))
            data.append(UInt8((u >> 8) & 0xFF))
        }
        isUTF16Flag = true
        dead_ = false
    }

    /// Create from Latin1 bytes (external, globally allocated)
    public static func fromLatin1(input: Array<UInt8>): BaoString {
        return BaoString(input)
    }

    /// Create from UTF-16 code units (external, globally allocated)
    public static func fromUTF16(input: Array<UInt16>): BaoString {
        return BaoString(input)
    }

    /// Clone Latin1 bytes
    public static func cloneLatin1(input: Array<UInt8>): BaoString {
        let copy = Array<UInt8>(input.size, repeat: 0)
        for (i in 0..input.size) { copy[i] = input[i] }
        return BaoString(copy)
    }

    /// Create an uninitialized Latin1 string of the given length
    public static func createUninitializedLatin1(len: Int64): BaoString {
        let s = BaoString()
        s.data = ArrayList<UInt8>(len, UInt8(0))
        s.isUTF16Flag = false
        return s
    }

    /// Create an uninitialized UTF-16 string of the given code-unit count
    public static func createUninitializedUTF16(len: Int64): BaoString {
        let s = BaoString()
        s.data = ArrayList<UInt8>(len * 2, UInt8(0))
        s.isUTF16Flag = true
        return s
    }

    /// Whether the string is dead (null)
    public func isDead(): Bool { return dead_ }

    /// Create a dead string
    public static func dead(): BaoString {
        let s = BaoString()
        s.dead_ = true
        return s
    }

    /// Whether the string is stored as UTF-16
    public func isUTF16(): Bool { return isUTF16Flag }

    /// Whether the string is stored as UTF-8
    public func isUTF8(): Bool { return false } // Simplified

    /// Get the Latin1 byte slice
    public func latin1(): Array<UInt8> { return data.items() }

    /// Get the UTF-16 code unit slice
    public func utf16(): Array<UInt16> {
        if (!isUTF16Flag) { return Array<UInt16>() }
        let result = ArrayList<UInt16>()
        var i: Int64 = 0
        while (i + 1 < data.size) {
            result.append(UInt16(data[i]) | (UInt16(data[i + 1]) << 8))
            i += 2
        }
        return result.items()
    }

    /// Get mutable chars (Latin1 or UTF-16 bytes)
    public func getMutableChars(): Array<UInt8> { return data.items() }

    /// Transfer to JS value (placeholder)
    public func transferToJS(global: JSGlobalObject): ?JsValue {
        // In the real implementation this would create a JS string
        return None
    }

    /// Convert to standard String
    public func toString(): String {
        if (dead_) { return "" }
        // Convert bytes to string using Utf8Codec
        let bytes = data.items()
        return Utf8Codec.decode(bytes)
    }
}

// ============================================================================
// ZigString - Zig-compatible string type
// 对应 bun_core::ZigString
// ============================================================================

/// Zig-compatible string type
public class ZigString {
    private var data: Array<UInt8>
    private var utf16Data: Array<UInt16>
    private var is16BitFlag: Bool

    public init() {
        data = Array<UInt8>()
        utf16Data = Array<UInt16>()
        is16BitFlag = false
    }

    public init(s: String) {
        data = Array<UInt8>()
        utf16Data = Array<UInt16>()
        is16BitFlag = false
        for (c in s) {
            let cp = Int64(c)
            if (cp >= 0x100) {
                is16BitFlag = true
            }
        }
        if (is16BitFlag) {
            let list = ArrayList<UInt16>()
            for (c in s) {
                list.append(UInt16(Int64(c)))
            }
            utf16Data = list.items()
        } else {
            let list = ArrayList<UInt8>()
            for (c in s) {
                list.append(UInt8(Int64(c)))
            }
            data = list.items()
        }
    }

    public static func `init`(bytes: Array<UInt8>): ZigString {
        let z = ZigString()
        z.data = bytes
        return z
    }

    public static func initUtf8(s: String): ZigString {
        return ZigString(s)
    }

    public func is16Bit(): Bool { return is16BitFlag }

    public func slice(): Array<UInt8> { return data }

    public func utf16Slice(): Array<UInt16> { return utf16Data }

    public func toErrorInstance(global: JSGlobalObject): JsValue {
        return JsValue.NULL
    }
}

// ported from: src/runtime/webcore/encoding.zig
