// 严格翻译自: src/sql/postgres/
// PostgreSQL 客户端 wire-protocol 消息层
package bao_sql

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_hash.*
import bao_base64.*
import bao_http.*
import bao_sql.postgres.PostgresProtocol
import std.random.*

private func parseInt64OrZero(s: String): Int64 {
    var value: Int64 = 0
    var sign: Int64 = 1
    var i: Int64 = 0
    let trimmed = pgTrim(s)
    if (trimmed.size == 0) {
        return 0
    }
    if (trimmed[0] == UInt8(45)) {
        sign = -1
        i = 1
    } else if (trimmed[0] == UInt8(43)) {
        i = 1
    }
    while (i < trimmed.size) {
        let c = trimmed[i]
        if (c < UInt8(48) || c > UInt8(57)) {
            return 0
        }
        value = value * 10 + Int64(c - UInt8(48))
        i += 1
    }
    return value * sign
}

private func parseUInt16OrNone(s: String): ?UInt16 {
    var value: Int64 = 0
    let trimmed = pgTrim(s)
    if (trimmed.size == 0) {
        return None
    }
    for (c in trimmed) {
        if (c < UInt8(48) || c > UInt8(57)) {
            return None
        }
        value = value * 10 + Int64(c - UInt8(48))
        if (value > 65535) {
            return None
        }
    }
    return Some(UInt16(value))
}

private func parseFloat64OrZero(s: String): Float64 {
    let trimmed = pgTrim(s)
    if (trimmed == "NaN" || trimmed == "nan") { return Float64.NaN }
    if (trimmed == "Infinity" || trimmed == "inf") { return Float64.Inf }
    if (trimmed == "-Infinity" || trimmed == "-inf") { return -Float64.Inf }
    if (trimmed.size == 0) { return 0.0 }
    var sign = 1.0
    var value = 0.0
    var frac = 0.1
    var i: Int64 = 0
    if (trimmed[0] == UInt8(45)) {
        sign = -1.0
        i = 1
    } else if (trimmed[0] == UInt8(43)) {
        i = 1
    }
    while (i < trimmed.size && trimmed[i] >= UInt8(48) && trimmed[i] <= UInt8(57)) {
        value = value * 10.0 + Float64(trimmed[i] - UInt8(48))
        i += 1
    }
    if (i < trimmed.size && trimmed[i] == UInt8(46)) {
        i += 1
        while (i < trimmed.size && trimmed[i] >= UInt8(48) && trimmed[i] <= UInt8(57)) {
            value += Float64(trimmed[i] - UInt8(48)) * frac
            frac *= 0.1
            i += 1
        }
    }
    if (i < trimmed.size && (trimmed[i] == UInt8(101) || trimmed[i] == UInt8(69))) {
        i += 1
        var expSign: Int64 = 1
        var exp: Int64 = 0
        if (i < trimmed.size && trimmed[i] == UInt8(45)) {
            expSign = -1
            i += 1
        } else if (i < trimmed.size && trimmed[i] == UInt8(43)) {
            i += 1
        }
        while (i < trimmed.size && trimmed[i] >= UInt8(48) && trimmed[i] <= UInt8(57)) {
            exp = exp * 10 + Int64(trimmed[i] - UInt8(48))
            i += 1
        }
        value *= pgPow10(exp * expSign)
    }
    return value * sign
}

private func pgPow10(exp: Int64): Float64 {
    var result = 1.0
    if (exp >= 0) {
        for (_ in 0..exp) { result *= 10.0 }
    } else {
        for (_ in 0..(-exp)) { result *= 0.1 }
    }
    return result
}

private func sliceString(s: String, start: Int64, end: Int64): String {
    let actualStart = if (start < 0) { 0 } else { start }
    let actualEnd = if (end > s.size) { s.size } else { end }
    if (actualStart >= actualEnd) {
        return ""
    }
    return s[actualStart..actualEnd]
}

private func pgTrim(s: String): String {
    var start: Int64 = 0
    var end = s.size
    while (start < end && pgIsAsciiWhitespace(s[start])) {
        start += 1
    }
    while (end > start && pgIsAsciiWhitespace(s[end - 1])) {
        end -= 1
    }
    return s[start..end]
}

private func pgIsAsciiWhitespace(c: UInt8): Bool {
    return c == UInt8(32) || c == UInt8(9) || c == UInt8(10) || c == UInt8(13)
}

private func pgStringBytes(s: String): Array<UInt8> {
    let bytes = ArrayList<UInt8>()
    for (b in s) {
        bytes.append(b)
    }
    return bytes.toOwnedSlice()
}

private func pgConcatBytes(a: Array<UInt8>, b: Array<UInt8>): Array<UInt8> {
    let result = ArrayList<UInt8>()
    for (x in a) { result.append(x) }
    for (x in b) { result.append(x) }
    return result.toOwnedSlice()
}

private func pgHexLower(bytes: Array<UInt8>): String {
    let chars: Array<UInt8> = [
        UInt8(48), UInt8(49), UInt8(50), UInt8(51), UInt8(52), UInt8(53), UInt8(54), UInt8(55),
        UInt8(56), UInt8(57), UInt8(97), UInt8(98), UInt8(99), UInt8(100), UInt8(101), UInt8(102)
    ]
    var result = ""
    for (b in bytes) {
        result += "${Rune(UInt32(chars[Int64((b >> 4) & UInt8(15))]))}"
        result += "${Rune(UInt32(chars[Int64(b & UInt8(15))]))}"
    }
    return result
}

private func pgMd5LeftRotate(x: UInt32, c: Int64): UInt32 {
    return (x << c) | (x >> (32 - c))
}

private func pgMd5(data: Array<UInt8>): Array<UInt8> {
    let s: Array<Int64> = [
        7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
        5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
        4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
        6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
    ]
    let k: Array<UInt32> = [
        UInt32(0xd76aa478), UInt32(0xe8c7b756), UInt32(0x242070db), UInt32(0xc1bdceee),
        UInt32(0xf57c0faf), UInt32(0x4787c62a), UInt32(0xa8304613), UInt32(0xfd469501),
        UInt32(0x698098d8), UInt32(0x8b44f7af), UInt32(0xffff5bb1), UInt32(0x895cd7be),
        UInt32(0x6b901122), UInt32(0xfd987193), UInt32(0xa679438e), UInt32(0x49b40821),
        UInt32(0xf61e2562), UInt32(0xc040b340), UInt32(0x265e5a51), UInt32(0xe9b6c7aa),
        UInt32(0xd62f105d), UInt32(0x02441453), UInt32(0xd8a1e681), UInt32(0xe7d3fbc8),
        UInt32(0x21e1cde6), UInt32(0xc33707d6), UInt32(0xf4d50d87), UInt32(0x455a14ed),
        UInt32(0xa9e3e905), UInt32(0xfcefa3f8), UInt32(0x676f02d9), UInt32(0x8d2a4c8a),
        UInt32(0xfffa3942), UInt32(0x8771f681), UInt32(0x6d9d6122), UInt32(0xfde5380c),
        UInt32(0xa4beea44), UInt32(0x4bdecfa9), UInt32(0xf6bb4b60), UInt32(0xbebfbc70),
        UInt32(0x289b7ec6), UInt32(0xeaa127fa), UInt32(0xd4ef3085), UInt32(0x04881d05),
        UInt32(0xd9d4d039), UInt32(0xe6db99e5), UInt32(0x1fa27cf8), UInt32(0xc4ac5665),
        UInt32(0xf4292244), UInt32(0x432aff97), UInt32(0xab9423a7), UInt32(0xfc93a039),
        UInt32(0x655b59c3), UInt32(0x8f0ccc92), UInt32(0xffeff47d), UInt32(0x85845dd1),
        UInt32(0x6fa87e4f), UInt32(0xfe2ce6e0), UInt32(0xa3014314), UInt32(0x4e0811a1),
        UInt32(0xf7537e82), UInt32(0xbd3af235), UInt32(0x2ad7d2bb), UInt32(0xeb86d391)
    ]
    let msg = ArrayList<UInt8>()
    for (b in data) { msg.append(b) }
    let bitLen = UInt64(data.size) * UInt64(8)
    msg.append(UInt8(0x80))
    while ((msg.size % 64) != 56) { msg.append(UInt8(0)) }
    for (i in 0..8) {
        msg.append(UInt8((bitLen >> (UInt64(i) * UInt64(8))) & UInt64(0xff)))
    }

    var a0: UInt32 = UInt32(0x67452301)
    var b0: UInt32 = UInt32(0xefcdab89)
    var c0: UInt32 = UInt32(0x98badcfe)
    var d0: UInt32 = UInt32(0x10325476)
    var offset: Int64 = 0
    while (offset < msg.size) {
        let m = Array<UInt32>(16, repeat: UInt32(0))
        for (j in 0..16) {
            let p = offset + j * 4
            m[j] = UInt32(msg[p]) | (UInt32(msg[p + 1]) << 8) | (UInt32(msg[p + 2]) << 16) | (UInt32(msg[p + 3]) << 24)
        }
        var a = a0
        var b = b0
        var c = c0
        var d = d0
        for (i in 0..64) {
            var f: UInt32 = UInt32(0)
            var g: Int64 = 0
            if (i < 16) {
                f = (b & c) | ((b ^ UInt32(0xffffffff)) & d)
                g = i
            } else if (i < 32) {
                f = (d & b) | ((d ^ UInt32(0xffffffff)) & c)
                g = (5 * i + 1) % 16
            } else if (i < 48) {
                f = b ^ c ^ d
                g = (3 * i + 5) % 16
            } else {
                f = c ^ (b | (d ^ UInt32(0xffffffff)))
                g = (7 * i) % 16
            }
            let temp = d
            d = c
            c = b
            b = b + pgMd5LeftRotate(a + f + k[i] + m[g], s[i])
            a = temp
        }
        a0 = a0 + a
        b0 = b0 + b
        c0 = c0 + c
        d0 = d0 + d
        offset += 64
    }

    let out = ArrayList<UInt8>()
    for (word in [a0, b0, c0, d0]) {
        out.append(UInt8(word & UInt32(0xff)))
        out.append(UInt8((word >> 8) & UInt32(0xff)))
        out.append(UInt8((word >> 16) & UInt32(0xff)))
        out.append(UInt8((word >> 24) & UInt32(0xff)))
    }
    return out.toOwnedSlice()
}

private func buildPostgresMD5Password(password: String, user: String, salt: Array<UInt8>): String {
    let inner = pgHexLower(pgMd5(pgConcatBytes(pgStringBytes(password), pgStringBytes(user))))
    let outer = pgHexLower(pgMd5(pgConcatBytes(pgStringBytes(inner), salt)))
    return "md5${outer}"
}

private func pgXorBytes(a: Array<UInt8>, b: Array<UInt8>): Array<UInt8> {
    let result = ArrayList<UInt8>()
    let count = if (a.size < b.size) { a.size } else { b.size }
    for (i in 0..count) { result.append(a[i] ^ b[i]) }
    return result.toOwnedSlice()
}

private func pgInt32Bytes(value: UInt32): Array<UInt8> {
    return [UInt8((value >> 24) & UInt32(0xff)), UInt8((value >> 16) & UInt32(0xff)), UInt8((value >> 8) & UInt32(0xff)), UInt8(value & UInt32(0xff))]
}

private func pgPbkdf2Sha256(password: Array<UInt8>, salt: Array<UInt8>, iterations: UInt32): Array<UInt8> {
    let saltBlock = pgConcatBytes(salt, pgInt32Bytes(UInt32(1)))
    var u = HmacSha256.hmac(password, saltBlock)
    var result = u
    var i: UInt32 = 1
    while (i < iterations) {
        u = HmacSha256.hmac(password, u)
        result = pgXorBytes(result, u)
        i += 1
    }
    return result
}

private func pgParseSaslField(message: String, key: UInt8): String {
    let parts = message.split(",")
    for (part in parts) {
        if (part.size > 2 && part[0] == key && part[1] == UInt8(61)) {
            return part[2..part.size]
        }
    }
    return ""
}

private func pgGenerateNonce(): String {
    let rng = Random()
    let bytes = ArrayList<UInt8>()
    var value = rng.nextUInt64()
    for (i in 0..18) {
        if ((i % 8) == 0) { value = rng.nextUInt64() }
        bytes.append(UInt8((value >> UInt64((i % 8) * 8)) & UInt64(0xff)))
    }
    return Base64.encode(bytes.toOwnedSlice())
}

private func pgBuildSaslInitialResponse(mechanism: String, data: String): Array<UInt8> {
    let writer = PgMessageBuilder()
    writer.byte(UInt8(112))
    let len = writer.reserveLength()
    writer.string(mechanism)
    writer.int4(UInt32(data.size))
    writer.write(pgStringBytes(data))
    writer.writeLength(len)
    return writer.bytes()
}

private func pgBuildSaslResponse(data: String): Array<UInt8> {
    let writer = PgMessageBuilder()
    writer.byte(UInt8(112))
    let len = writer.reserveLength()
    writer.write(pgStringBytes(data))
    writer.writeLength(len)
    return writer.bytes()
}

private func pgSliceBytes(bytes: Array<UInt8>, start: Int64, end: Int64): Array<UInt8> {
    let result = ArrayList<UInt8>()
    var i = start
    while (i < end && i < bytes.size) {
        result.append(bytes[i])
        i += 1
    }
    return result.toOwnedSlice()
}

private func pgReadUInt32(bytes: Array<UInt8>, offset: Int64): UInt32 {
    if (offset + 3 >= bytes.size) {
        return UInt32(0)
    }
    return (UInt32(bytes[offset]) << 24) | (UInt32(bytes[offset + 1]) << 16) | (UInt32(bytes[offset + 2]) << 8) | UInt32(bytes[offset + 3])
}

private func pgReadUInt16(bytes: Array<UInt8>, offset: Int64): UInt16 {
    if (offset + 1 >= bytes.size) {
        return UInt16(0)
    }
    return (UInt16(bytes[offset]) << 8) | UInt16(bytes[offset + 1])
}

private func pgBytesToString(bytes: Array<UInt8>, start: Int64, end: Int64): String {
    var result = ""
    var i = start
    while (i < end && i < bytes.size) {
        result += "${Rune(UInt32(bytes[i]))}"
        i += 1
    }
    return result
}

private func pgReadZString(bytes: Array<UInt8>, start: Int64): (String, Int64) {
    var i = start
    while (i < bytes.size && bytes[i] != UInt8(0)) {
        i += 1
    }
    let s = pgBytesToString(bytes, start, i)
    let next = if (i < bytes.size) { i + 1 } else { i }
    return (s, next)
}

private func pgReadTwoZStrings(bytes: Array<UInt8>): Array<String> {
    let result = ArrayList<String>()
    let first = pgReadZString(bytes, 0)
    let second = pgReadZString(bytes, first[1])
    result.append(first[0])
    result.append(second[0])
    return result.toOwnedSlice()
}

private func normalizePgHost(host: String): String {
    if (host == "localhost") {
        return "127.0.0.1"
    }
    return host
}

private func isSslDisabled(mode: PostgresSSLMode): Bool {
    match (mode) {
        case PostgresSSLMode.Disable => true
        case _ => false
    }
}

private func isSslRequired(mode: PostgresSSLMode): Bool {
    match (mode) {
        case PostgresSSLMode.Require | PostgresSSLMode.VerifyCa | PostgresSSLMode.VerifyFull => true
        case _ => false
    }
}

private func parseBackendError(payload: Array<UInt8>): PostgresError {
    var severity = "ERROR"
    var code = ""
    var message = "PostgreSQL backend error"
    var offset: Int64 = 0
    while (offset < payload.size && payload[offset] != UInt8(0)) {
        let fieldType = payload[offset]
        let item = pgReadZString(payload, offset + 1)
        if (fieldType == UInt8(83)) { severity = item[0] }
        if (fieldType == UInt8(67)) { code = item[0] }
        if (fieldType == UInt8(77)) { message = item[0] }
        offset = item[1]
    }
    return PostgresError(code, message, severity)
}

private func parseCommandComplete(payload: Array<UInt8>, result: SqlResult): Unit {
    let tag = pgReadZString(payload, 0)[0]
    let count = parseLastIntegerToken(tag)
    result.changes = count
}

private func parseLastIntegerToken(s: String): Int64 {
    var value: Int64 = 0
    var found = false
    var multiplier: Int64 = 1
    var i = s.size - 1
    while (i >= 0) {
        let c = s[i]
        if (c >= UInt8(48) && c <= UInt8(57)) {
            found = true
            value += Int64(c - UInt8(48)) * multiplier
            multiplier *= 10
        } else if (found) {
            break
        }
        i -= 1
    }
    return value
}

private func parseRowDescription(payload: Array<UInt8>, result: SqlResult, columns: ArrayList<PgColumnInfo>): Unit {
    columns.clear()
    if (payload.size < 2) { return }
    let count = Int64(pgReadUInt16(payload, 0))
    var offset: Int64 = 2
    for (_ in 0..count) {
        let name = pgReadZString(payload, offset)
        if (name[1] + 18 > payload.size) { return }
        let typeOid = pgReadUInt32(payload, name[1] + 6)
        let formatCode = pgReadUInt16(payload, name[1] + 16)
        result.columns.append(name[0])
        columns.append(PgColumnInfo(name[0], typeOid, formatCode == UInt16(1)))
        offset = name[1] + 18
    }
}

private func parseDataRow(payload: Array<UInt8>, result: SqlResult, columns: ArrayList<PgColumnInfo>): Unit {
    if (payload.size < 2) { return }
    let count = Int64(pgReadUInt16(payload, 0))
    var offset: Int64 = 2
    let row = ArrayList<SqlValue>()
    for (i in 0..count) {
        if (offset + 4 > payload.size) { return }
        let rawLen = pgReadUInt32(payload, offset)
        offset += 4
        if (rawLen == UInt32(4294967295)) {
            row.append(SqlValue.Null)
        } else {
            let len = Int64(rawLen)
            let end = offset + len
            if (end > payload.size) { return }
            let typeOid = if (i < columns.size) { columns[i].typeOid } else { UInt32(0) }
            let binary = if (i < columns.size) { columns[i].binary } else { false }
            row.append(pgDecodeValue(pgSliceBytes(payload, offset, end), typeOid, binary))
            offset = end
        }
    }
    result.rows.append(row)
}

private func pgDecodeValue(bytes: Array<UInt8>, typeOid: UInt32, binary: Bool): SqlValue {
    if (binary) {
        if (typeOid == UInt32(16) && bytes.size == 1) {
            return SqlValue.Integer(if (bytes[0] == UInt8(0)) { Int64(0) } else { Int64(1) })
        }
        if (typeOid == UInt32(20) && bytes.size == 8) { return SqlValue.Integer(pgReadInt64BE(bytes, 0)) }
        if (typeOid == UInt32(21) && bytes.size == 2) { return SqlValue.Integer(Int64(pgReadInt16BE(bytes, 0))) }
        if (typeOid == UInt32(23) && bytes.size == 4) { return SqlValue.Integer(Int64(pgReadInt32BE(bytes, 0))) }
        if (typeOid == UInt32(700) && bytes.size == 4) { return SqlValue.Float(Float64(pgReadFloat32BE(bytes, 0))) }
        if (typeOid == UInt32(701) && bytes.size == 8) { return SqlValue.Float(pgReadFloat64BE(bytes, 0)) }
        if (typeOid == UInt32(1082) && bytes.size == 4) { return SqlValue.Integer(Int64(pgReadInt32BE(bytes, 0))) }
        if ((typeOid == UInt32(1083) || typeOid == UInt32(1114) || typeOid == UInt32(1184)) && bytes.size == 8) { return SqlValue.Integer(pgReadInt64BE(bytes, 0)) }
        if (typeOid == UInt32(17)) { return SqlValue.Blob(bytes) }
        if (typeOid == UInt32(1700)) { return SqlValue.Text(pgDecodeBinaryNumeric(bytes)) }
        if (typeOid == UInt32(2950) && bytes.size == 16) { return SqlValue.Text(pgFormatUuid(bytes)) }
        if (pgIsArrayOid(typeOid)) { return SqlValue.Text(pgDecodeBinaryArray(bytes, typeOid)) }
    }
    let text = pgBytesToString(bytes, 0, bytes.size)
    if (typeOid == UInt32(16)) {
        if (text == "t" || text == "true" || text == "1") { return SqlValue.Integer(1) }
        return SqlValue.Integer(0)
    }
    if (typeOid == UInt32(20) || typeOid == UInt32(21) || typeOid == UInt32(23) || typeOid == UInt32(26) || typeOid == UInt32(28) || typeOid == UInt32(29)) {
        return SqlValue.Integer(parseInt64OrZero(text))
    }
    if (typeOid == UInt32(700) || typeOid == UInt32(701)) {
        return SqlValue.Float(parseFloat64OrZero(text))
    }
    if (typeOid == UInt32(1700)) {
        return SqlValue.Text(text)
    }
    if (typeOid == UInt32(17)) {
        return SqlValue.Blob(pgDecodeByteaText(text))
    }
    if (pgIsTextLikeOid(typeOid)) {
        return SqlValue.Text(text)
    }
    if (pgIsArrayOid(typeOid)) {
        return SqlValue.Text(text)
    }
    return SqlValue.Text(text)
}

private func pgReadInt16BE(bytes: Array<UInt8>, offset: Int64): Int16 {
    return Int16(pgReadUInt16(bytes, offset))
}

private func pgReadInt32BE(bytes: Array<UInt8>, offset: Int64): Int32 {
    return Int32(pgReadUInt32(bytes, offset))
}

private func pgReadInt64BE(bytes: Array<UInt8>, offset: Int64): Int64 {
    return Int64(pgReadUInt64BE(bytes, offset))
}

private func pgReadUInt64BE(bytes: Array<UInt8>, offset: Int64): UInt64 {
    if (offset + 7 >= bytes.size) { return UInt64(0) }
    var result: UInt64 = UInt64(0)
    for (i in 0..8) {
        result = (result << UInt64(8)) | UInt64(bytes[offset + i])
    }
    return result
}

private func pgReadFloat32BE(bytes: Array<UInt8>, offset: Int64): Float32 {
    if (offset + 3 >= bytes.size) { return 0.0f32 }
    return Float32.fromBits(pgReadUInt32(bytes, offset))
}

private func pgReadFloat64BE(bytes: Array<UInt8>, offset: Int64): Float64 {
    if (offset + 7 >= bytes.size) { return 0.0 }
    return Float64.fromBits(pgReadUInt64BE(bytes, offset))
}

private func pgFormatUuid(bytes: Array<UInt8>): String {
    if (bytes.size != 16) { return pgBytesToString(bytes, 0, bytes.size) }
    var result = ""
    for (i in 0..16) {
        if (i == 4 || i == 6 || i == 8 || i == 10) { result += "-" }
        result += pgHexLower([bytes[i]])
    }
    return result
}

private func pgDecodeBinaryNumeric(bytes: Array<UInt8>): String {
    if (bytes.size < 8) { return "0" }
    let ndigits = Int64(pgReadInt16BE(bytes, 0))
    let weight = Int64(pgReadInt16BE(bytes, 2))
    let sign = pgReadUInt16(bytes, 4)
    let dscale = Int64(pgReadInt16BE(bytes, 6))
    if (sign == UInt16(0xC000)) { return "NaN" }
    if (sign == UInt16(0xD000)) { return "Infinity" }
    if (sign == UInt16(0xF000)) { return "-Infinity" }
    if (ndigits <= 0) { return "0" }
    let groups = ArrayList<Int64>()
    var offset: Int64 = 8
    for (_ in 0..ndigits) {
        if (offset + 2 > bytes.size) { groups.append(0) } else { groups.append(Int64(pgReadUInt16(bytes, offset))) }
        offset += 2
    }
    var result = ""
    if (sign == UInt16(0x4000)) { result += "-" }
    if (weight < 0) {
        result += "0"
    } else {
        var wrote = false
        for (i in 0..(weight + 1)) {
            let group = if (i < groups.size) { groups[i] } else { 0 }
            if (!wrote) {
                if (group != 0) {
                    result += group.toString()
                    wrote = true
                }
            } else {
                result += pgPad4(group)
            }
        }
        if (!wrote) { result += "0" }
    }
    if (dscale > 0) {
        result += "."
        var fractional = ""
        var groupIndex = weight + 1
        while (fractional.size < dscale) {
            let group = if (groupIndex >= 0 && groupIndex < groups.size) { groups[groupIndex] } else { 0 }
            fractional += pgPad4(group)
            groupIndex += 1
        }
        result += fractional[0..dscale]
    }
    return result
}

private func pgPad4(value: Int64): String {
    let s = value.toString()
    if (s.size >= 4) { return s }
    var out = ""
    for (_ in 0..(4 - s.size)) { out += "0" }
    return out + s
}

private func pgIsTextLikeOid(typeOid: UInt32): Bool {
    return typeOid == UInt32(18) || typeOid == UInt32(19) || typeOid == UInt32(25) || typeOid == UInt32(114) || typeOid == UInt32(142) || typeOid == UInt32(600) || typeOid == UInt32(601) || typeOid == UInt32(602) || typeOid == UInt32(603) || typeOid == UInt32(604) || typeOid == UInt32(628) || typeOid == UInt32(650) || typeOid == UInt32(718) || typeOid == UInt32(774) || typeOid == UInt32(790) || typeOid == UInt32(829) || typeOid == UInt32(869) || typeOid == UInt32(1033) || typeOid == UInt32(1042) || typeOid == UInt32(1043) || typeOid == UInt32(1082) || typeOid == UInt32(1083) || typeOid == UInt32(1114) || typeOid == UInt32(1184) || typeOid == UInt32(1186) || typeOid == UInt32(1266) || typeOid == UInt32(1560) || typeOid == UInt32(1562) || typeOid == UInt32(2950) || typeOid == UInt32(3802) || typeOid == UInt32(4072)
}

private func pgIsArrayOid(typeOid: UInt32): Bool {
    return typeOid == UInt32(1000) || typeOid == UInt32(1001) || typeOid == UInt32(1002) || typeOid == UInt32(1003) || typeOid == UInt32(1016) || typeOid == UInt32(1005) || typeOid == UInt32(1006) || typeOid == UInt32(1007) || typeOid == UInt32(1009) || typeOid == UInt32(1028) || typeOid == UInt32(1010) || typeOid == UInt32(1011) || typeOid == UInt32(1012) || typeOid == UInt32(199) || typeOid == UInt32(143) || typeOid == UInt32(1017) || typeOid == UInt32(1018) || typeOid == UInt32(1019) || typeOid == UInt32(1020) || typeOid == UInt32(1027) || typeOid == UInt32(629) || typeOid == UInt32(651) || typeOid == UInt32(1021) || typeOid == UInt32(1022) || typeOid == UInt32(719) || typeOid == UInt32(775) || typeOid == UInt32(791) || typeOid == UInt32(1040) || typeOid == UInt32(1041) || typeOid == UInt32(1034) || typeOid == UInt32(1014) || typeOid == UInt32(1015) || typeOid == UInt32(1182) || typeOid == UInt32(1183) || typeOid == UInt32(1115) || typeOid == UInt32(1185) || typeOid == UInt32(1187) || typeOid == UInt32(1270) || typeOid == UInt32(1561) || typeOid == UInt32(1563) || typeOid == UInt32(1231) || typeOid == UInt32(3807) || typeOid == UInt32(4073)
}

private func pgDecodeBinaryArray(bytes: Array<UInt8>, arrayOid: UInt32): String {
    if (bytes.size < 12) { return "{}" }
    let dimensions = Int64(pgReadInt32BE(bytes, 0))
    let elemOid = pgReadUInt32(bytes, 8)
    if (dimensions <= 0) { return "{}" }
    if (dimensions > 1) { return pgBytesToString(bytes, 0, bytes.size) }
    if (bytes.size < 20) { return "{}" }
    let length = Int64(pgReadInt32BE(bytes, 12))
    var offset: Int64 = 20
    let parts = ArrayList<String>()
    for (_ in 0..length) {
        if (offset + 4 > bytes.size) { break }
        let rawLen = pgReadUInt32(bytes, offset)
        offset += 4
        if (rawLen == UInt32(4294967295)) {
            parts.append("NULL")
        } else {
            let len = Int64(rawLen)
            if (offset + len > bytes.size) { break }
            let elementBytes = pgSliceBytes(bytes, offset, offset + len)
            parts.append(pgDecodeArrayElement(elementBytes, elemOid, arrayOid))
            offset += len
        }
    }
    return pgJoinArrayParts(parts)
}

private func pgDecodeArrayElement(bytes: Array<UInt8>, elemOid: UInt32, arrayOid: UInt32): String {
    if (elemOid == UInt32(16)) { return if (bytes.size > 0 && bytes[0] != UInt8(0)) { "t" } else { "f" } }
    if (elemOid == UInt32(20) && bytes.size == 8) { return pgReadInt64BE(bytes, 0).toString() }
    if (elemOid == UInt32(21) && bytes.size == 2) { return Int64(pgReadInt16BE(bytes, 0)).toString() }
    if (elemOid == UInt32(23) && bytes.size == 4) { return Int64(pgReadInt32BE(bytes, 0)).toString() }
    if (elemOid == UInt32(700) && bytes.size == 4) { return Float64(pgReadFloat32BE(bytes, 0)).toString() }
    if (elemOid == UInt32(701) && bytes.size == 8) { return pgReadFloat64BE(bytes, 0).toString() }
    if (elemOid == UInt32(1700)) { return pgDecodeBinaryNumeric(bytes) }
    if (elemOid == UInt32(17)) { return pgQuoteArrayElement("\\x${pgHexLower(bytes)}") }
    if (elemOid == UInt32(2950) && bytes.size == 16) { return pgFormatUuid(bytes) }
    if (arrayOid == UInt32(1021)) { return Float64(pgReadFloat32BE(bytes, 0)).toString() }
    return pgQuoteArrayElement(pgBytesToString(bytes, 0, bytes.size))
}

private func pgJoinArrayParts(parts: ArrayList<String>): String {
    var result = "{"
    for (i in 0..parts.size) {
        if (i > 0) { result += "," }
        result += parts[i]
    }
    result += "}"
    return result
}

private func pgQuoteArrayElement(value: String): String {
    var result = "\""
    for (b in value) {
        if (b == UInt8(34) || b == UInt8(92)) { result += "\\" }
        result += "${Rune(UInt32(b))}"
    }
    result += "\""
    return result
}

private func pgHexValue(c: UInt8): UInt8 {
    if (c >= UInt8(48) && c <= UInt8(57)) { return c - UInt8(48) }
    if (c >= UInt8(97) && c <= UInt8(102)) { return c - UInt8(97) + UInt8(10) }
    if (c >= UInt8(65) && c <= UInt8(70)) { return c - UInt8(65) + UInt8(10) }
    return UInt8(0)
}

private func pgDecodeByteaText(text: String): Array<UInt8> {
    if (text.size >= 2 && text[0] == UInt8(92) && (text[1] == UInt8(120) || text[1] == UInt8(88))) {
        let out = ArrayList<UInt8>()
        var i: Int64 = 2
        while (i + 1 < text.size) {
            out.append((pgHexValue(text[i]) << 4) | pgHexValue(text[i + 1]))
            i += 2
        }
        return out.toOwnedSlice()
    }
    return pgStringBytes(text)
}

private class PgBackendMessage {
    public var tag: UInt8
    public var payload: Array<UInt8>

    public init(tag: UInt8, payload: Array<UInt8>) {
        this.tag = tag
        this.payload = payload
    }
}

private class PgColumnInfo {
    public var name: String
    public var typeOid: UInt32
    public var binary: Bool

    public init(name: String, typeOid: UInt32, binary: Bool) {
        this.name = name
        this.typeOid = typeOid
        this.binary = binary
    }
}

private class PgMessageBuilder {
    private var data: ArrayList<UInt8>

    public init() {
        data = ArrayList<UInt8>()
    }

    public func byte(value: UInt8): Unit {
        data.append(value)
    }

    public func write(bytes: Array<UInt8>): Unit {
        for (b in bytes) {
            data.append(b)
        }
    }

    public func int4(value: UInt32): Unit {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    public func short(value: UInt16): Unit {
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    public func string(value: String): Unit {
        write(pgStringBytes(value))
        byte(UInt8(0))
    }

    public func writeNull(): Unit {
        int4(UInt32(4294967295))
    }

    public func reserveLength(): Int64 {
        let pos = data.size
        int4(UInt32(0))
        return pos
    }

    public func writeLength(pos: Int64): Unit {
        let length = UInt32(data.size - pos)
        data[pos] = UInt8((length >> 24) & 0xFF)
        data[pos + 1] = UInt8((length >> 16) & 0xFF)
        data[pos + 2] = UInt8((length >> 8) & 0xFF)
        data[pos + 3] = UInt8(length & 0xFF)
    }

    public func bytes(): Array<UInt8> {
        return data.toOwnedSlice()
    }
}

// ============================================================================
// PostgreSQL 连接配置
// 严格翻译自: src/sql/postgres/PostgresProtocol.rs - StartupMessage
// 对应 Bun: PostgreSQL 连接参数管理
// ============================================================================

/// PostgreSQL SSL 模式
/// 严格翻译自: src/sql/postgres/SSLMode.rs
/// 对应 Bun: PostgresSSLMode
public enum PostgresSSLMode {
    | Disable     // 不使用 SSL
    | Prefer      // 优先使用 SSL，失败则回退
    | Require     // 必须使用 SSL
    | VerifyCa    // 使用 SSL 并验证 CA
    | VerifyFull  // 使用 SSL 并验证完整证书链

    public func toString(): String {
        match (this) {
            case Disable => "disable"
            case Prefer => "prefer"
            case Require => "require"
            case VerifyCa => "verify-ca"
            case VerifyFull => "verify-full"
        }
    }

    /// 从字符串解析
    public static func parse(value: String): PostgresSSLMode {
        match (value) {
            case "disable" => Disable
            case "prefer" => Prefer
            case "require" => Require
            case "verify-ca" => VerifyCa
            case "verify-full" => VerifyFull
            case _ => Prefer
        }
    }
}

/// PostgreSQL 连接字符串解析结果
/// 严格翻译自: src/sql/postgres/PostgresProtocol.rs
/// 对应 Bun: PostgreSQL 连接参数
///
/// 连接字符串格式:
///   postgresql://user:password@host:port/database?sslmode=require
///   postgres://user:password@host:port/database
public class PostgresConfig {
    /// 主机名
    public var host: String

    /// 端口
    public var port: UInt16

    /// 数据库名
    public var database: String

    /// 用户名
    public var user: String

    /// 密码
    public var password: String

    /// SSL 模式
    public var sslMode: PostgresSSLMode

    /// 连接超时 (秒)
    public var connectTimeout: Int64

    /// 语句超时 (毫秒)
    public var statementTimeout: Int64

    /// 应用名称
    public var applicationName: String

    /// 连接池大小
    public var poolSize: Int64

    /// 额外参数
    public var params: HashMap<String, String>

    public init() {
        host = "localhost"
        port = UInt16(5432)
        database = "postgres"
        user = "postgres"
        password = ""
        sslMode = PostgresSSLMode.Prefer
        connectTimeout = 30
        statementTimeout = 0
        applicationName = "bao"
        poolSize = 10
        params = HashMap<String, String>()
    }

    /// 从连接字符串解析
    /// 对应 Bun: PostgreSQL URL 解析
    public static func parse(connectionString: String): ?PostgresConfig {
        let config = PostgresConfig()
        var s = connectionString

        // 去除协议前缀
        if (s.startsWith("postgresql://")) {
            s = sliceString(s, 13, s.size)
        } else if (s.startsWith("postgres://")) {
            s = sliceString(s, 11, s.size)
        }

        match (s.lastIndexOf('@')) {
            case Some(atIndex) =>
                let userInfo = sliceString(s, 0, atIndex)
                s = sliceString(s, atIndex + 1, s.size)
                match (userInfo.indexOf(':')) {
                    case Some(colonIndex) =>
                        config.user = sliceString(userInfo, 0, colonIndex)
                        config.password = sliceString(userInfo, colonIndex + 1, userInfo.size)
                    case None => config.user = userInfo
                }
            case None => ()
        }

        match (s.lastIndexOf('?')) {
            case Some(queryIndex) =>
                let queryString = sliceString(s, queryIndex + 1, s.size)
                s = sliceString(s, 0, queryIndex)
                parseQueryParams(config, queryString)
            case None => ()
        }

        match (s.indexOf('/')) {
            case Some(slashIndex) =>
                config.database = sliceString(s, slashIndex + 1, s.size)
                s = sliceString(s, 0, slashIndex)
            case None => ()
        }

        match (s.lastIndexOf(':')) {
            case Some(colonIdx) =>
                config.host = sliceString(s, 0, colonIdx)
                match (parseUInt16OrNone(sliceString(s, colonIdx + 1, s.size))) {
                    case Some(p) => config.port = p
                    case None => ()
                }
            case None => config.host = s
        }

        return Some(config)
    }

    /// 解析查询参数
    private static func parseQueryParams(config: PostgresConfig, query: String): Unit {
        let pairs = query.split("&")
        for (pair in pairs) {
            match (pair.indexOf('=')) {
                case Some(eqIdx) =>
                    let key = sliceString(pair, 0, eqIdx)
                    let value = sliceString(pair, eqIdx + 1, pair.size)
                    match (key) {
                        case "sslmode" => config.sslMode = PostgresSSLMode.parse(value)
                        case "connect_timeout" => config.connectTimeout = parseInt64OrZero(value)
                        case "statement_timeout" => config.statementTimeout = parseInt64OrZero(value)
                        case "application_name" => config.applicationName = value
                        case _ => config.params.put(key, value)
                    }
                case None => ()
            }
        }
    }

    /// 转为连接字符串
    public func toConnectionString(): String {
        var s = "postgresql://${user}"
        if (password.size > 0) {
            s += ":${password}"
        }
        s += "@${host}:${port}/${database}"
        s += "?sslmode=${sslMode.toString()}"
        s += "&application_name=${applicationName}"
        return s
    }

    public func toString(): String {
        return "PostgresConfig(host=${host}, port=${port}, database=${database}, user=${user})"
    }
}

// ============================================================================
// PostgreSQL 认证
// 严格翻译自: src/sql/postgres/protocol/Authentication.rs
// 对应 Bun: PostgreSQL 认证协议
// ============================================================================

/// PostgreSQL 认证方法
/// 严格翻译自: src/sql/postgres/protocol/Authentication.rs
public enum PostgresAuthMethod {
    | None         // 无需认证
    | Password     // 明文密码
    | MD5          // MD5 加密密码
    | SCRAM256     // SCRAM-SHA-256
    | GSS          // GSSAPI
    | SSPI         // SSPI
    | SASL         // SASL (通用)

    public func toString(): String {
        match (this) {
            case None => "none"
            case Password => "password"
            case MD5 => "md5"
            case SCRAM256 => "scram-sha-256"
            case GSS => "gss"
            case SSPI => "sspi"
            case SASL => "sasl"
        }
    }
}

/// PostgreSQL 认证状态
class PostgresAuthState {
    public var method: PostgresAuthMethod
    public var salt: Array<UInt8>         // MD5 salt
    public var saslMechanism: String       // SASL mechanism name
    public var serverFirstBytes: Array<UInt8>  // SCRAM server-first-message
    public var clientNonce: String
    public var clientFirstBare: String
    public var serverSignature: String
    public var completed: Bool

    public init() {
        method = PostgresAuthMethod.None
        salt = Array<UInt8>()
        saslMechanism = ""
        serverFirstBytes = Array<UInt8>()
        clientNonce = ""
        clientFirstBare = ""
        serverSignature = ""
        completed = false
    }
}

// ============================================================================
// PostgreSQL 后端消息类型
// 严格翻译自: src/sql/postgres/PostgresProtocol.rs - BackendMessage
// ============================================================================

/// PostgreSQL 后端消息类型标识
/// 严格翻译自: src/sql/postgres/protocol/ - 各种消息类型
enum PostgresBackendMessageType {
    | Authentication    // 'R'
    | BackendKeyData    // 'K'
    | BindComplete      // '2'
    | CloseComplete     // '3'
    | CommandComplete   // 'C'
    | CopyData          // 'd'
    | CopyDone          // 'c'
    | CopyInResponse    // 'G'
    | CopyOutResponse   // 'H'
    | DataRow           // 'D'
    | EmptyQueryResponse // 'I'
    | ErrorResponse     // 'E'
    | FunctionCallResponse // 'V'
    | NoData            // 'n'
    | NoticeResponse    // 'N'
    | NotificationResponse // 'A'
    | ParameterDescription // 't'
    | ParameterStatus   // 'S'
    | ParseComplete     // '1'
    | PortalSuspended   // 's'
    | ReadyForQuery     // 'Z'
    | RowDescription    // 'T'
}

/// PostgreSQL 事务状态
/// 严格翻译自: src/sql/postgres/protocol/TransactionStatusIndicator.rs
public enum PostgresTransactionStatus {
    | Idle     // 'I' — 空闲 (不在事务中)
    | InTrans  // 'T' — 在事务中
    | Error    // 'E' — 在失败的事务中

    public static func fromByte(b: UInt8): PostgresTransactionStatus {
        if (b == 73) { return Idle }
        if (b == 84) { return InTrans }
        if (b == 69) { return Error }
        return Idle
    }
}

// ============================================================================
// PostgresConnection — PostgreSQL 连接
// 严格翻译自: src/sql/postgres/
// 对应 Bun: bun:pg 中的连接实现
// ============================================================================

/// PostgreSQL 数据库连接
/// 对应 Bun: src/sql/postgres/ 中的 PostgreSQL 客户端
/// Bun 的 PostgreSQL 支持通过直接实现 wire protocol 实现，不依赖 libpq。
public class PostgresConnection {
    /// 连接配置
    public var config: PostgresConfig

    /// 是否已连接
    private var connected: Bool

    /// 后端进程 ID
    /// 对应 Bun: BackendKeyData.process_id
    public var backendPid: Int32

    /// 后端密钥
    /// 对应 Bun: BackendKeyData.secret_key
    public var backendKey: Int32

    /// 认证状态
    private var authState: PostgresAuthState

    /// 事务状态
    /// 对应 Bun: TransactionStatusIndicator
    public var transactionStatus: PostgresTransactionStatus

    /// 服务器参数
    /// 对应 Bun: ParameterStatus
    public var serverParams: HashMap<String, String>

    /// Socket 文件描述符
    private var socketFd: Int64

    private var socket: ?TcpSocket

    private var tlsContext: ?SslContext

    private var tlsSocket: ?SslSocket

    /// 已构造但尚未通过 socket 发送的 wire-protocol 消息
    private var pendingWrites: ArrayList<Array<UInt8>>

    private var readBuffer: ArrayList<UInt8>

    private var currentColumns: ArrayList<PgColumnInfo>

    public init() {
        config = PostgresConfig()
        connected = false
        backendPid = 0
        backendKey = 0
        authState = PostgresAuthState()
        transactionStatus = PostgresTransactionStatus.Idle
        serverParams = HashMap<String, String>()
        socketFd = -1
        socket = None
        tlsContext = None
        tlsSocket = None
        pendingWrites = ArrayList<Array<UInt8>>()
        readBuffer = ArrayList<UInt8>()
        currentColumns = ArrayList<PgColumnInfo>()
    }

    public init(config: PostgresConfig) {
        this.config = config
        connected = false
        backendPid = 0
        backendKey = 0
        authState = PostgresAuthState()
        transactionStatus = PostgresTransactionStatus.Idle
        serverParams = HashMap<String, String>()
        socketFd = -1
        socket = None
        tlsContext = None
        tlsSocket = None
        pendingWrites = ArrayList<Array<UInt8>>()
        readBuffer = ArrayList<UInt8>()
        currentColumns = ArrayList<PgColumnInfo>()
    }

    /// 连接到 PostgreSQL 服务器
    /// 对应 Bun: PostgreSQL wire protocol StartupMessage + Authentication
    public func connect(): Unit {
        // 实际实现 (wire protocol):
        // 1. 创建 TCP 连接到 host:port
        //    let addr = SocketAddress(config.host, config.port)
        //    let socket = Socket.connect(addr)
        //    this.socketFd = socket.fd
        //
        // 2. 可选: SSL 协商 (SSLRequest 消息)
        //    if (config.sslMode != Disable) {
        //        sendSSLRequest()
        //        let sslResponse = readByte()
        //        if (sslResponse == 'S') {
        //            // 执行 SSL/TLS 握手
        //            performTLSHandshake()
        //        } else if (config.sslMode == Require || ...) {
        //            throw PostgresError("SSL required but server does not support it")
        //        }
        //    }
        //
        // 3. 发送 StartupMessage
        //    sendStartupMessage()
        //
        // 4. 处理认证流程
        //    handleAuthentication()
        //
        // 5. 读取 BackendKeyData, ParameterStatus, ReadyForQuery

        pendingWrites.clear()
        readBuffer.clear()
        openTcpSocket()
        if (!isSslDisabled(config.sslMode)) {
            let upgraded = requestTlsUpgrade()
            if (!upgraded && isSslRequired(config.sslMode)) {
                closeSocketOnly()
                throw PostgresError("SSL required but server did not accept SSLRequest")
            }
            if (!upgraded && !socket.isSome()) {
                pendingWrites.clear()
                readBuffer.clear()
                openTcpSocket()
            }
        }
        queueMessage(buildStartupMessageBytes())
        flushPendingWrites()
        handleStartupResponses()
        connected = true
    }

    /// 从连接字符串连接
    public func connect(connectionString: String): Unit {
        match (PostgresConfig.parse(connectionString)) {
            case Some(cfg) =>
                this.config = cfg
                connect()
            case None => throw PostgresError("Invalid connection string: ${connectionString}")
        }
    }

    /// 断开连接
    /// 对应 Bun: 发送 Terminate 消息并关闭 socket
    public func disconnect(): Unit {
        if (connected) {
            queueMessage(PostgresProtocol.Terminate)
            flushPendingWrites()
            closeSocketOnly()
            connected = false
        }
    }

    /// 是否已连接
    public func isConnected(): Bool {
        return connected
    }

    /// 执行 SQL 查询
    /// 对应 Bun: PostgreSQL SimpleQuery protocol
    public func query(sql: String): SqlResult {
        if (!connected) {
            throw PostgresError("Not connected")
        }

        queueMessage(PostgresProtocol.buildQueryBytes(sql))
        flushPendingWrites()
        return readQueryResult()
    }

    /// 执行 SQL 语句 (无返回结果)
    public func exec(sql: String): Int64 {
        if (!connected) {
            throw PostgresError("Not connected")
        }
        queueMessage(PostgresProtocol.buildQueryBytes(sql))
        flushPendingWrites()
        let result = readQueryResult()
        return result.changes
    }

    /// 准备语句
    /// 对应 Bun: PostgreSQL Extended Query protocol (Parse + Sync)
    func prepare(sql: String): PostgresPreparedStatement {
        let stmt = PostgresPreparedStatement(this, sql)
        stmt.parse()
        return stmt
    }

    public func queuedMessageCount(): Int64 {
        return pendingWrites.size
    }

    public func queuedMessage(index: Int64): Array<UInt8> {
        return pendingWrites[index]
    }

    public func clearQueuedMessages(): Unit {
        pendingWrites.clear()
    }

    public func queueMessage(bytes: Array<UInt8>): Unit {
        pendingWrites.append(bytes)
    }

    public func flushPendingWrites(): Unit {
        let s = socket
        if (!s.isSome()) {
            return
        }
        for (msg in pendingWrites) {
            var written: Int64 = 0
            while (written < msg.size) {
                let chunk = pgSliceBytes(msg, written, msg.size)
                let sent = writeSocket(chunk)
                if (sent <= 0) {
                    throw PostgresError("PostgreSQL socket closed while sending")
                }
                written += sent
            }
        }
        pendingWrites.clear()
    }

    private func writeSocket(data: Array<UInt8>): Int64 {
        let tls = tlsSocket
        if (tls.isSome()) {
            let sent = tls.getOrThrow().write(data)
            if (sent < 0) {
                throw PostgresError("Failed to send PostgreSQL TLS message")
            }
            return sent
        }
        let s = socket
        if (!s.isSome()) {
            throw PostgresError("PostgreSQL socket is not open")
        }
        let sendResult = s.getOrThrow().send(data)
        let sentOpt = sendResult.result()
        if (!sentOpt.isSome()) {
            throw PostgresError("Failed to send PostgreSQL message")
        }
        return sentOpt.getOrThrow()
    }

    private func openTcpSocket(): Unit {
        let addrs = resolvePostgresAddresses()
        for (addr in addrs) {
            let created = TcpSocket.create(addr.family())
            let createdOpt = created.result()
            if (!createdOpt.isSome()) {
                continue
            }
            let tcp = createdOpt.getOrThrow()
            let connectResult = tcp.connect(addr)
            if (connectResult.isOk()) {
                socketFd = tcp.getFd()
                socket = Some(tcp)
                return
            }
            tcp.close()
        }
        throw PostgresError("Failed to connect to PostgreSQL server ${config.host}:${config.port}")
    }

    private func resolvePostgresAddresses(): Array<SocketAddr> {
        let lookup = BasicDnsResolver.lookup(config.host, config.port)
        let lookupOpt = lookup.result()
        if (lookupOpt.isSome() && lookupOpt.getOrThrow().size > 0) {
            return lookupOpt.getOrThrow()
        }
        return [SocketAddr.V4(SocketAddrV4(config.port, normalizePgHost(config.host)))]
    }

    private func requestTlsUpgrade(): Bool {
        queueMessage(PostgresProtocol.SSLRequest)
        flushPendingWrites()
        let sslByte = readOneByte()
        if (sslByte == UInt8(83)) {
            let ok = performTlsHandshake()
            if (!ok && !isSslRequired(config.sslMode)) {
                closeSocketOnly()
            }
            return ok
        }
        if (sslByte == UInt8(78)) {
            return false
        }
        throw PostgresError("Invalid PostgreSQL SSLRequest response")
    }

    private func performTlsHandshake(): Bool {
        let sslConfig = SSLConfig()
        sslConfig.serverName = config.host
        sslConfig.rejectUnauthorized = isSslRequired(config.sslMode)
        let context = SslContext(sslConfig)
        if (!context.createClient()) {
            return false
        }
        let sslOpt = context.newSsl()
        if (!sslOpt.isSome()) {
            context.deinit()
            return false
        }
        let ssl = sslOpt.getOrThrow()
        ssl.setFd(socketFd)
        if (!ssl.doHandshake(config.host)) {
            ssl.close()
            context.deinit()
            socket = None
            socketFd = -1
            return false
        }
        tlsContext = Some(context)
        tlsSocket = Some(ssl)
        return true
    }

    private func closeSocketOnly(): Unit {
        let tls = tlsSocket
        if (tls.isSome()) {
            tls.getOrThrow().close()
            tlsSocket = None
            tlsContext = None
            socket = None
            socketFd = -1
            return
        }
        let s = socket
        if (s.isSome()) {
            s.getOrThrow().close()
        }
        socket = None
        socketFd = -1
    }

    private func buildStartupMessageBytes(): Array<UInt8> {
        let params = ArrayList<(String, String)>()
        params.append(("user", config.user))
        params.append(("database", config.database))
        params.append(("client_encoding", "UTF8"))
        params.append(("application_name", config.applicationName))
        var length: UInt32 = 4 + 4 + 1
        for (pair in params) {
            length += UInt32(pair[0].size + 1 + pair[1].size + 1)
        }
        let writer = PgMessageBuilder()
        writer.int4(length)
        writer.int4(196608)
        for (pair in params) {
            writer.string(pair[0])
            writer.string(pair[1])
        }
        writer.byte(UInt8(0))
        return writer.bytes()
    }

    private func readOneByte(): UInt8 {
        let bytes = readFromSocket(1)
        if (bytes.size < 1) {
            throw PostgresError("PostgreSQL socket closed while reading")
        }
        return bytes[0]
    }

    private func readMessage(): PgBackendMessage {
        let tag = readOneByte()
        let lengthBytes = readFromSocket(4)
        let length = pgReadUInt32(lengthBytes, 0)
        let payloadLen = Int64(length) - 4
        let payload = if (payloadLen > 0) { readFromSocket(payloadLen) } else { Array<UInt8>() }
        return PgBackendMessage(tag, payload)
    }

    private func readFromSocket(count: Int64): Array<UInt8> {
        while (readBuffer.size < count) {
            let tmp = Array<UInt8>(4096, { _ => UInt8(0) })
            let n = readSocket(tmp)
            if (n <= 0) {
                throw PostgresError("PostgreSQL socket closed")
            }
            for (i in 0..n) {
                readBuffer.append(tmp[i])
            }
        }
        let result = ArrayList<UInt8>()
        for (i in 0..count) {
            result.append(readBuffer[i])
        }
        let remaining = ArrayList<UInt8>()
        for (i in count..readBuffer.size) {
            remaining.append(readBuffer[i])
        }
        readBuffer = remaining
        return result.toOwnedSlice()
    }

    private func readSocket(buf: Array<UInt8>): Int64 {
        let tls = tlsSocket
        if (tls.isSome()) {
            let n = tls.getOrThrow().read(buf)
            if (n < 0) {
                throw PostgresError("Failed to read from PostgreSQL TLS socket")
            }
            return n
        }
        let s = socket
        if (!s.isSome()) {
            throw PostgresError("PostgreSQL socket is not open")
        }
        let recvResult = s.getOrThrow().recv(buf)
        let nOpt = recvResult.result()
        if (!nOpt.isSome()) {
            throw PostgresError("Failed to read from PostgreSQL socket")
        }
        return nOpt.getOrThrow()
    }

    private func handleStartupResponses(): Unit {
        var done = false
        while (!done) {
            let msg = readMessage()
            if (msg.tag == UInt8(82)) {
                handleAuthenticationMessage(msg.payload)
            } else if (msg.tag == UInt8(75)) {
                if (msg.payload.size >= 8) {
                    backendPid = Int32(pgReadUInt32(msg.payload, 0))
                    backendKey = Int32(pgReadUInt32(msg.payload, 4))
                }
            } else if (msg.tag == UInt8(83)) {
                let pair = pgReadTwoZStrings(msg.payload)
                if (pair[0].size > 0) {
                    serverParams.put(pair[0], pair[1])
                }
            } else if (msg.tag == UInt8(90)) {
                if (msg.payload.size > 0) {
                    transactionStatus = PostgresTransactionStatus.fromByte(msg.payload[0])
                }
                done = true
            } else if (msg.tag == UInt8(69)) {
                throw parseBackendError(msg.payload)
            }
        }
    }

    private func handleAuthenticationMessage(payload: Array<UInt8>): Unit {
        if (payload.size < 4) {
            throw PostgresError("Invalid Authentication message")
        }
        let authType = pgReadUInt32(payload, 0)
        if (authType == 0) {
            authState.completed = true
        } else if (authType == 3) {
            authState.method = PostgresAuthMethod.Password
            queueMessage(buildPasswordMessage(config.password))
            flushPendingWrites()
        } else if (authType == 5) {
            if (payload.size < 8) {
                throw PostgresError("Invalid MD5 Authentication message")
            }
            authState.method = PostgresAuthMethod.MD5
            authState.salt = pgSliceBytes(payload, 4, 8)
            queueMessage(buildPasswordMessage(buildPostgresMD5Password(config.password, config.user, authState.salt)))
            flushPendingWrites()
        } else if (authType == 10) {
            authState.method = PostgresAuthMethod.SCRAM256
            authState.saslMechanism = "SCRAM-SHA-256"
            authState.clientNonce = pgGenerateNonce()
            authState.clientFirstBare = "n=${config.user},r=${authState.clientNonce}"
            queueMessage(pgBuildSaslInitialResponse(authState.saslMechanism, "n,,${authState.clientFirstBare}"))
            flushPendingWrites()
        } else if (authType == 11) {
            handleSaslContinue(payload)
        } else if (authType == 12) {
            handleSaslFinal(payload)
        } else {
            throw PostgresError("Unsupported PostgreSQL authentication method ${authType}")
        }
    }

    private func handleSaslContinue(payload: Array<UInt8>): Unit {
        if (payload.size < 5) {
            throw PostgresError("Invalid SASLContinue Authentication message")
        }
        let serverFirst = pgBytesToString(payload, 4, payload.size)
        authState.serverFirstBytes = pgSliceBytes(payload, 4, payload.size)
        let nonce = pgParseSaslField(serverFirst, UInt8(114))
        let saltBase64 = pgParseSaslField(serverFirst, UInt8(115))
        let iterationsText = pgParseSaslField(serverFirst, UInt8(105))
        if (nonce.size == 0 || saltBase64.size == 0 || iterationsText.size == 0) {
            throw PostgresError("Invalid SCRAM-SHA-256 server-first-message")
        }
        if (!nonce.startsWith(authState.clientNonce)) {
            throw PostgresError("Invalid SCRAM-SHA-256 nonce")
        }
        let iterations = UInt32(parseInt64OrZero(iterationsText))
        if (iterations == UInt32(0)) {
            throw PostgresError("Invalid SCRAM-SHA-256 iteration count")
        }
        let channelBinding = "c=biws"
        let finalWithoutProof = "${channelBinding},r=${nonce}"
        let authMessage = "${authState.clientFirstBare},${serverFirst},${finalWithoutProof}"
        let saltedPassword = pgPbkdf2Sha256(pgStringBytes(config.password), Base64.decode(saltBase64), iterations)
        let clientKey = HmacSha256.hmac(saltedPassword, pgStringBytes("Client Key"))
        let storedKey = Sha256.hash(clientKey)
        let clientSignature = HmacSha256.hmac(storedKey, pgStringBytes(authMessage))
        let clientProof = pgXorBytes(clientKey, clientSignature)
        let serverKey = HmacSha256.hmac(saltedPassword, pgStringBytes("Server Key"))
        authState.serverSignature = Base64.encode(HmacSha256.hmac(serverKey, pgStringBytes(authMessage)))
        queueMessage(pgBuildSaslResponse("${finalWithoutProof},p=${Base64.encode(clientProof)}"))
        flushPendingWrites()
    }

    private func handleSaslFinal(payload: Array<UInt8>): Unit {
        if (payload.size < 4) {
            throw PostgresError("Invalid SASLFinal Authentication message")
        }
        let serverFinal = pgBytesToString(payload, 4, payload.size)
        let verifier = pgParseSaslField(serverFinal, UInt8(118))
        if (authState.serverSignature.size > 0 && verifier.size > 0 && verifier != authState.serverSignature) {
            throw PostgresError("Invalid SCRAM-SHA-256 server signature")
        }
        authState.completed = true
    }

    private func buildPasswordMessage(password: String): Array<UInt8> {
        let writer = PgMessageBuilder()
        writer.byte(UInt8(112))
        writer.int4(UInt32(4 + password.size + 1))
        writer.string(password)
        return writer.bytes()
    }

    public func readQueryResult(): SqlResult {
        let result = SqlResult()
        currentColumns.clear()
        var done = false
        while (!done) {
            let msg = readMessage()
            if (msg.tag == UInt8(67)) {
                parseCommandComplete(msg.payload, result)
            } else if (msg.tag == UInt8(84)) {
                parseRowDescription(msg.payload, result, currentColumns)
            } else if (msg.tag == UInt8(68)) {
                parseDataRow(msg.payload, result, currentColumns)
            } else if (msg.tag == UInt8(49) || msg.tag == UInt8(50) || msg.tag == UInt8(51) || msg.tag == UInt8(110) || msg.tag == UInt8(116)) {
                ()
            } else if (msg.tag == UInt8(115)) {
                done = true
            } else if (msg.tag == UInt8(90)) {
                if (msg.payload.size > 0) {
                    transactionStatus = PostgresTransactionStatus.fromByte(msg.payload[0])
                }
                done = true
            } else if (msg.tag == UInt8(69)) {
                throw parseBackendError(msg.payload)
            }
        }
        return result
    }

    /// 获取服务器版本
    public func serverVersion(): String {
        match (serverParams.get("server_version")) {
            case Some(v) => v
            case None => "unknown"
        }
    }

    /// 获取服务器编码
    public func serverEncoding(): String {
        match (serverParams.get("server_encoding")) {
            case Some(v) => v
            case None => "UTF8"
        }
    }
}

// ============================================================================
// PostgresPreparedStatement — PostgreSQL 预编译语句
// 严格翻译自: src/sql/postgres/protocol/ - Parse/Bind/Execute/Describe
// ============================================================================

/// PostgreSQL 预编译语句
/// 对应 Bun: PostgreSQL Extended Query protocol
///
/// Extended Query 流程:
///   Parse    → 编译 SQL
///   Bind     → 绑定参数
///   Execute  → 执行
///   Sync     → 同步
class PostgresPreparedStatement {
    private var conn: PostgresConnection
    private var sql: String
    private var bound: Bool
    /// 语句名称 (空字符串表示匿名语句)
    private var stmtName: String

    /// portal 名称 (空字符串表示匿名 portal)
    private var portalName: String

    private var parsed: Bool

    public init(conn: PostgresConnection, sql: String) {
        this.conn = conn
        this.sql = sql
        this.bound = false
        this.stmtName = ""
        this.portalName = ""
        this.parsed = false
    }

    public func parse(): Unit {
        if (!parsed) {
            let writer = PgMessageBuilder()
            writer.byte(UInt8(80))
            let len = writer.reserveLength()
            writer.string(stmtName)
            writer.string(sql)
            writer.short(UInt16(0))
            writer.writeLength(len)
            writer.write(PostgresProtocol.Sync)
            conn.queueMessage(writer.bytes())
            conn.flushPendingWrites()
            conn.readQueryResult()
            parsed = true
        }
    }

    /// 绑定参数
    /// 对应 Bun: PostgreSQL Bind 消息
    public func bind(params: Array<SqlValue>): Unit {
        parse()
        conn.queueMessage(buildBindMessage(params))
        bound = true
    }

    /// 执行
    /// 对应 Bun: PostgreSQL Execute + Sync
    public func exec(): Int64 {
        if (!bound) {
            throw PostgresError("Parameters not bound")
        }
        conn.queueMessage(buildExecuteSyncMessage())
        conn.flushPendingWrites()
        let result = conn.readQueryResult()
        return result.changes
    }

    /// 查询
    public func query(): SqlResult {
        if (!bound) {
            throw PostgresError("Parameters not bound")
        }
        conn.queueMessage(buildExecuteSyncMessage())
        conn.flushPendingWrites()
        return conn.readQueryResult()
    }

    /// 重置
    public func reset(): Unit {
        bound = false
    }

    /// 释放
    public func finalize(): Unit {
        let writer = PgMessageBuilder()
        writeCloseMessage(writer, UInt8(80), portalName)
        writeCloseMessage(writer, UInt8(83), stmtName)
        writer.write(PostgresProtocol.Sync)
        conn.queueMessage(writer.bytes())
        conn.flushPendingWrites()
        conn.readQueryResult()
        bound = false
        parsed = false
    }

    private func buildBindMessage(params: Array<SqlValue>): Array<UInt8> {
        let writer = PgMessageBuilder()
        writer.byte(UInt8(66))
        let len = writer.reserveLength()
        writer.string(portalName)
        writer.string(stmtName)
        writer.short(UInt16(0))
        writer.short(UInt16(params.size))
        for (param in params) {
            writeParameter(writer, param)
        }
        writer.short(UInt16(0))
        writer.writeLength(len)
        return writer.bytes()
    }

    private func writeParameter(writer: PgMessageBuilder, param: SqlValue): Unit {
        match (param) {
            case SqlValue.Null => writer.writeNull()
            case SqlValue.Integer(v) =>
                let text = v.toString()
                writer.int4(UInt32(text.size))
                writer.write(pgStringBytes(text))
            case SqlValue.Float(v) =>
                let text = v.toString()
                writer.int4(UInt32(text.size))
                writer.write(pgStringBytes(text))
            case SqlValue.Text(v) =>
                writer.int4(UInt32(v.size))
                writer.write(pgStringBytes(v))
            case SqlValue.Blob(v) =>
                writer.int4(UInt32(v.size))
                writer.write(v)
        }
    }

    private func buildExecuteSyncMessage(): Array<UInt8> {
        let writer = PgMessageBuilder()
        writer.byte(UInt8(69))
        let len = writer.reserveLength()
        writer.string(portalName)
        writer.int4(UInt32(0))
        writer.writeLength(len)
        writer.write(PostgresProtocol.Sync)
        return writer.bytes()
    }

    private func writeCloseMessage(writer: PgMessageBuilder, tag: UInt8, name: String): Unit {
        writer.byte(UInt8(67))
        let len = writer.reserveLength()
        writer.byte(tag)
        writer.string(name)
        writer.writeLength(len)
    }
}

// ============================================================================
// PostgresError — PostgreSQL 错误
// 严格翻译自: src/sql/postgres/AnyPostgresError.rs
// ============================================================================

/// PostgreSQL 错误
/// 对应 Bun: ErrorResponse 消息解析
public class PostgresError <: BaoError {
    /// 错误字段 (PostgreSQL ErrorResponse 中的字段)
    public var severity: String
    public var sqlState: String
    public var detail: ?String
    public var hint: ?String
    public var position: ?Int64
    public var where_: ?String
    public var schemaName: ?String
    public var tableName: ?String
    public var columnName: ?String
    public var constraintName: ?String

    public init(message: String) {
        super(ErrorCode.Unexpected, "PostgreSQL error: ${message}")
        this.severity = "ERROR"
        this.sqlState = ""
        this.detail = None
        this.hint = None
        this.position = None
        this.where_ = None
        this.schemaName = None
        this.tableName = None
        this.columnName = None
        this.constraintName = None
    }

    public init(code: String, message: String, severity: String) {
        super(ErrorCode.Unexpected, "[${code}] ${message}")
        this.severity = severity
        this.sqlState = code
        this.detail = None
        this.hint = None
        this.position = None
        this.where_ = None
        this.schemaName = None
        this.tableName = None
        this.columnName = None
        this.constraintName = None
    }

    public func toString(): String {
        var s = "[${severity}] ${sqlState}: ${message}"
        match (detail) { case Some(d) => s += "\n  Detail: ${d}" case None => () }
        match (hint) { case Some(h) => s += "\n  Hint: ${h}" case None => () }
        return s
    }
}
