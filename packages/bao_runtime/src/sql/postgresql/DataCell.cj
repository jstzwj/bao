// PostgreSQL DataCell JSC 绑定 — PostgreSQL 数据类型到 JS 值的转换
// 严格翻译自: bun/src/sql_jsc/postgres/DataCell.zig
//   pub fn fromBytes(binary: bool, bigint: bool, oid: types.Tag, bytes: []const u8, globalObject: *jsc.JSGlobalObject) !SQLDataCell
package bao_runtime.sql.postgresql


/// PostgreSQL 数据单元格转换器
/// 将 PostgreSQL 二进制/文本格式的列数据解码为 SQLDataCell
/// 对应 Bun DataCell (文件级函数集合)
public class PGDataCellConverter {

    /// 从字节数组解码 PostgreSQL 数据
    /// 对应 Bun DataCell.fromBytes()
    ///
    /// 参数:
    ///   binary - 是否为二进制格式
    ///   bigint - 是否将 int8 解码为 BigInt (否则为字符串)
    ///   oid - PostgreSQL 类型标签
    ///   bytes - 原始字节
    public static func fromBytes(binary: Bool, bigint: Bool, oid: PGTag, bytes: Array<UInt8>): SQLDataCell {
        if (bytes.size == 0) {
            return SQLDataCell.nullCell()
        }

        match (oid) {
            // === 整数类型 ===
            case PGTag.Int2 => {
                if (binary) {
                    let value = parseBinaryInt2(bytes)
                    return SQLDataCell.fromInt32(value)
                } else {
                    let value = parseInt32(bytes)
                    return SQLDataCell.fromInt32(value)
                }
            }
            case PGTag.Int4 => {
                if (binary) {
                    let value = parseBinaryInt4(bytes)
                    return SQLDataCell.fromInt32(value)
                } else {
                    let value = parseInt32(bytes)
                    return SQLDataCell.fromInt32(value)
                }
            }
            case PGTag.Int8 => {
                if (bigint) {
                    let value = parseInt64(bytes)
                    return SQLDataCell.fromInt64(value)
                } else {
                    let s = bytesToString(bytes)
                    return SQLDataCell.fromString(s)
                }
            }
            case PGTag.OID | PGTag.XID | PGTag.CID => {
                if (binary) {
                    let value = parseBinaryUInt32(bytes)
                    let cell = SQLDataCell()
                    cell.tag = SQLDataCellTag.UInt4
                    cell.uint4Value = value
                    return cell
                } else {
                    let value = parseUInt32(bytes)
                    let cell = SQLDataCell()
                    cell.tag = SQLDataCellTag.UInt4
                    cell.uint4Value = value
                    return cell
                }
            }

            // === 浮点类型 ===
            case PGTag.Float8 => {
                if (binary && bytes.size == 8) {
                    let value = parseBinaryFloat64(bytes)
                    return SQLDataCell.fromFloat64(value)
                } else {
                    let value = parseFloat64(bytes)
                    return SQLDataCell.fromFloat64(value)
                }
            }
            case PGTag.Float4 => {
                if (binary && bytes.size == 4) {
                    let value = Float64(parseBinaryFloat32(bytes))
                    return SQLDataCell.fromFloat64(value)
                } else {
                    let value = parseFloat64(bytes)
                    return SQLDataCell.fromFloat64(value)
                }
            }

            // === Numeric (高精度十进制) ===
            case PGTag.Numeric => {
                if (binary) {
                    // 二进制格式解码为字符串表示
                    let result = parseBinaryNumeric(bytes)
                    return SQLDataCell.fromString(result)
                } else {
                    // 文本格式直接作为字符串
                    let s = bytesToString(bytes)
                    return SQLDataCell.fromString(s)
                }
            }

            // === JSON 类型 ===
            case PGTag.JSON | PGTag.JSONB => {
                let s = bytesToString(bytes)
                return SQLDataCell.fromJson(s)
            }

            // === 布尔类型 ===
            case PGTag.Bool => {
                if (binary) {
                    let b = bytes.size > 0 && bytes[0] == 1
                    return SQLDataCell.fromBool(b)
                } else {
                    let b = bytes.size > 0 && bytes[0] == UInt8('t')
                    return SQLDataCell.fromBool(b)
                }
            }

            // === 日期/时间类型 ===
            case PGTag.Date | PGTag.Timestamp | PGTag.Timestamptz => {
                if (bytes.size == 0) {
                    return SQLDataCell.nullCell()
                }
                if (binary && bytes.size == 8) {
                    if (oid == PGTag.Timestamptz) {
                        let v = parseBinaryDate(bytes)
                        return SQLDataCell.fromDateWithTimeZone(v)
                    } else {
                        let v = parseBinaryDate(bytes)
                        return SQLDataCell.fromDate(v)
                    }
                } else {
                    // 文本格式 — 简化处理，返回字符串让 JS 端解析
                    let s = bytesToString(bytes)
                    if (s == "NULL") {
                        return SQLDataCell.nullCell()
                    }
                    // 简化：文本格式日期作为字符串返回
                    return SQLDataCell.fromString(s)
                }
            }
            case PGTag.Time | PGTag.Timetz => {
                if (bytes.size == 0) {
                    return SQLDataCell.nullCell()
                }
                if (binary) {
                    // 二进制 time 格式: 微秒 (8 字节)
                    // 二进制 timetz 格式: 微秒 (8 字节) + 时区偏移秒 (4 字节)
                    let s = bytesToString(bytes)
                    return SQLDataCell.fromString(s)
                } else {
                    let s = bytesToString(bytes)
                    return SQLDataCell.fromString(s)
                }
            }

            // === Bytea (二进制数据) ===
            case PGTag.Bytea => {
                if (binary) {
                    return SQLDataCell.fromBytea(bytes)
                } else {
                    // 文本格式: \x 前缀的十六进制
                    if (bytes.size >= 2 && bytes[0] == UInt8('\\') && bytes[1] == UInt8('x')) {
                        let hexBytes = bytes.toArray()
                        let decoded = parseBytea(hexBytes.slice(2))
                        return SQLDataCell.fromBytea(decoded)
                    }
                    // 无法识别的格式
                    return SQLDataCell.fromBytea(bytes)
                }
            }

            // === 文本/字符串类型 ===
            case PGTag.Text | PGTag.Varchar | PGTag.BPChar | PGTag.Char | PGTag.Name => {
                let s = bytesToString(bytes)
                return SQLDataCell.fromString(s)
            }

            // === 数组类型 ===
            case PGTag.Int4Array | PGTag.Float4Array => {
                if (binary) {
                    return parseBinaryArray(bytes, oid)
                } else {
                    return parseTextArray(bytes, bigint, oid)
                }
            }

            // === 文本数组类型 ===
            case PGTag.TextArray | PGTag.VarcharArray | PGTag.BPCharArray |
                 PGTag.CharArray | PGTag.NameArray | PGTag.JSONArray | PGTag.JSONBArray |
                 PGTag.Int8Array | PGTag.Int2Array | PGTag.Float8Array |
                 PGTag.BoolArray | PGTag.ByteaArray | PGTag.DateArray |
                 PGTag.TimestampArray | PGTag.TimestamptzArray |
                 PGTag.TimeArray | PGTag.TimetzArray | PGTag.NumericArray |
                 PGTag.OIDArray | PGTag.XIDArray | PGTag.CIDArray => {
                return parseTextArray(bytes, bigint, oid)
            }

            // === 默认：作为字符串处理 ===
            case _ => {
                let s = bytesToString(bytes)
                return SQLDataCell.fromString(s)
            }
        }
    }

    // ========================================================================
    // Putter — 将 DataRow 解码为单元格列表
    // ========================================================================

    /// 数据单元格放置器
    /// 对应 Bun DataCell.Putter
    public class Putter {
        public var list: Array<SQLDataCell>
        public var fields: Array<FieldDescription>
        public var binary: Bool
        public var bigint: Bool
        public var count: Int64
        /// JS 全局对象引用 (在 JSC 环境中使用)
        public var globalObjectRef: Int64

        public init(fields: Array<FieldDescription>) {
            list = Array<SQLDataCell>(fields.size, item: SQLDataCell.nullCell())
            this.fields = fields
            binary = false
            bigint = false
            count = 0
            globalObjectRef = 0
        }

        /// 放置解码后的单元格
        /// 对应 Bun DataCell.Putter.put()
        public func put(index: UInt32, data: ?Array<UInt8>): Bool {
            if (index >= fields.size) {
                return false
            }
            if (index >= list.size) {
                return false
            }

            let field = fields[index]
            let oid = field.typeOID
            let tag = PGTag.fromOID(UInt16(oid & 0xFFFF))

            match (data) {
                case Some(bytes) => {
                    let useBinary = (field.binary || binary) && tag.isBinaryFormatSupported()
                    let cell = PGDataCellConverter.fromBytes(useBinary, bigint, tag, bytes)
                    list[index] = cell
                }
                case None => {
                    list[index] = SQLDataCell.nullCell()
                }
            }
            count += 1

            // 设置索引信息
            list[index].columnIndex = index
            match (field.nameOrIndex) {
                case ColumnIdentifier.Index(i) => {
                    list[index].isIndexedColumn = 1
                    list[index].columnIndex = i
                }
                case ColumnIdentifier.Duplicate => {
                    list[index].isIndexedColumn = 2
                }
                case _ => {
                    list[index].isIndexedColumn = 0
                }
            }
            return true
        }

        /// 放置原始数据单元格
        /// 对应 Bun DataCell.Putter.putRaw()
        public func putRaw(index: UInt32, data: ?Array<UInt8>): Bool {
            if (index >= fields.size) {
                return false
            }
            if (index >= list.size) {
                return false
            }
            list[index] = SQLDataCell.fromRaw(data)
            count += 1
            return true
        }

        /// 转为 JS 值数组
        /// 对应 Bun DataCell.Putter.toJS()
        public func toJSValues(): Array<JSCellValue> {
            let result = Array<JSCellValue>()
            for (cell in list) {
                result.append(cell.toJSValue())
            }
            return result
        }
    }

    // ========================================================================
    // 二进制解析辅助函数
    // ========================================================================

    /// 解析二进制 Int2 (2 字节, 大端)
    private static func parseBinaryInt2(bytes: Array<UInt8>): Int32 {
        if (bytes.size == 1) {
            return Int32(bytes[0])
        } else if (bytes.size == 2) {
            // 大端读取
            return Int32(readUInt16BE(bytes, 0))
        } else if (bytes.size == 4) {
            return Int32(readUInt32BE(bytes, 0))
        }
        return 0
    }

    /// 解析二进制 Int4 (4 字节, 大端)
    private static func parseBinaryInt4(bytes: Array<UInt8>): Int32 {
        match (bytes.size) {
            case 1 => Int32(bytes[0])
            case 2 => Int32(readUInt16BE(bytes, 0))
            case 4 => Int32(readUInt32BE(bytes, 0))
            case _ => 0
        }
    }

    /// 解析二进制 UInt32 (4 字节, 大端)
    private static func parseBinaryUInt32(bytes: Array<UInt8>): UInt32 {
        match (bytes.size) {
            case 1 => UInt32(bytes[0])
            case 2 => readUInt16BE(bytes, 0)
            case 4 => readUInt32BE(bytes, 0)
            case _ => UInt32(0)
        }
    }

    /// 解析二进制 Float64 (8 字节, 大端 IEEE 754)
    private static func parseBinaryFloat64(bytes: Array<UInt8>): Float64 {
        if (bytes.size == 8) {
            let bits = readUInt64BE(bytes, 0)
            return Float64.fromBits(bits)
        }
        return 0.0
    }

    /// 解析二进制 Float32 (4 字节, 大端 IEEE 754)
    private static func parseBinaryFloat32(bytes: Array<UInt8>): Float32 {
        if (bytes.size == 4) {
            let bits = readUInt32BE(bytes, 0)
            return Float32.fromBits(bits)
        }
        return 0.0f
    }

    /// 解析二进制日期 (8 字节, 大端)
    private static func parseBinaryDate(bytes: Array<UInt8>): Float64 {
        if (bytes.size == 8) {
            let microseconds = readInt64BE(bytes, 0)
            // PostgreSQL 日期: 自 2000-01-01 以来的微秒数
            // 转换为 JS Date 毫秒: (microseconds / 1000) + pgEpochMs
            let pgEpochMs = 946684800000.0  // 2000-01-01 00:00:00 UTC 的毫秒数
            return Float64(microseconds) / 1000.0 + pgEpochMs
        }
        return 0.0
    }

    /// 解析二进制 Numeric
    /// 对应 Bun parseBinaryNumeric()
    private static func parseBinaryNumeric(bytes: Array<UInt8>): String {
        if (bytes.size < 8) {
            return "0"
        }

        var offset = 0
        // 读取头部
        let ndigits = Int16(readUInt16BE(bytes, offset)); offset += 2
        let weight = Int16(readUInt16BE(bytes, offset)); offset += 2
        let sign = readUInt16BE(bytes, offset); offset += 2
        let dscale = Int16(readUInt16BE(bytes, offset)); offset += 2

        // 特殊值
        match (sign) {
            case 0xC000 => return "NaN"
            case 0xD000 => return "Infinity"
            case 0xF000 => return "-Infinity"
            case 0x4000 | 0x0000 => {} // 正常值
            case _ => return "NaN"
        }

        if (ndigits == 0) {
            return "0"
        }

        // 读取数字位
        let digits = Array<UInt16>()
        while (offset + 1 < bytes.size && digits.size < ndigits) {
            digits.append(readUInt16BE(bytes, offset))
            offset += 2
        }

        // 构建十进制字符串
        var result = ""
        var isNegative = (sign == 0x4000)

        if (isNegative) {
            result = result + "-"
        }

        // 整数部分
        var decimalPos = (Int32(weight) + 1) * 4
        if (decimalPos < 0) {
            decimalPos = 0
        }

        if (weight < 0) {
            result = result + "0"
        } else {
            var firstNonZero = false
            var idx = 0
            while (idx <= weight) {
                let digit = if (idx < digits.size) digits[idx] else 0
                let digitStr = formatDigit(digit)
                if (!firstNonZero) {
                    // 跳过前导零
                    var startIdx = 0
                    while (startIdx < digitStr.size && digitStr[startIdx] == '0') {
                        startIdx += 1
                    }
                    if (startIdx < digitStr.size) {
                        result = result + digitStr.substring(startIdx)
                        firstNonZero = true
                    }
                } else {
                    result = result + digitStr
                }
                idx += 1
            }
        }

        // 小数部分
        if (dscale > 0) {
            result = result + "."
            var idx = Int32(weight) + 1
            while (idx < dscale) {
                if (idx >= 0 && idx < digits.size) {
                    result = result + formatDigit(digits[idx])
                } else {
                    result = result + "0000"
                }
                idx += 4
            }
            // 截断到 dscale 精度
            let targetLen = Int64(isNegative ? 2 : 1) + Int64(decimalPos) + 1 + Int64(dscale)
            if (result.size > targetLen) {
                result = result.substring(0, targetLen)
            }
        }

        if (result.isEmpty || result == "-" || result == "-0") {
            return "0"
        }
        return result
    }

    /// 格式化数字位 (4 位十进制)
    private static func formatDigit(d: UInt16): String {
        let v = Int32(d)
        let d3 = v / 1000
        let d2 = (v % 1000) / 100
        let d1 = (v % 100) / 10
        let d0 = v % 10
        return "${d3}${d2}${d1}${d0}"
    }

    /// 解析 bytea 十六进制格式
    /// 对应 Bun parseBytea()
    private static func parseBytea(hex: Array<UInt8>): Array<UInt8> {
        let len = hex.size / 2
        let buf = Array<UInt8>(len, item: 0)
        var i = 0
        while (i + 1 < hex.size) {
            buf[i / 2] = hexDecode(hex[i]) * UInt8(16) + hexDecode(hex[i + 1])
            i += 2
        }
        return buf
    }

    /// 解析二进制数组 (int4_array, float4_array)
    private static func parseBinaryArray(bytes: Array<UInt8>, oid: PGTag): SQLDataCell {
        if (bytes.size < 12) {
            return SQLDataCell.nullCell()
        }
        // 简化: 返回原始字节让上层处理
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.TypedArray
        cell.typedArrayValue = SQLDataCellTypedArray(
            bytes, bytes,
            UInt32(bytes.size), UInt32(bytes.size),
            oidToJSType(oid)
        )
        cell.freeValue = 1
        return cell
    }

    /// 解析文本格式数组
    /// 对应 Bun parseArray()
    private static func parseTextArray(bytes: Array<UInt8>, bigint: Bool, oid: PGTag): SQLDataCell {
        // 简化实现 — 文本数组解析
        // 完整实现需要递归解析 {item,item,...} 格式
        let text = bytesToString(bytes)
        let cells = parseArrayText(text, bigint, oid)
        let arr = SQLDataCellArray(cells)
        let cell = SQLDataCell()
        cell.tag = SQLDataCellTag.Array
        cell.arrayValue = arr
        cell.freeValue = 1
        return cell
    }

    /// 解析数组文本表示
    private static func parseArrayText(text: String, bigint: Bool, oid: PGTag): Array<SQLDataCell> {
        let cells = Array<SQLDataCell>()
        if (text.size < 2 || text[0] != '{') {
            return cells
        }
        // 空数组
        if (text.size == 2 && text[1] == '}') {
            return cells
        }
        // 提取元素
        let content = text.substring(1, text.size - 1)
        let elements = splitArrayElements(content)
        for (elem in elements) {
            if (elem == "NULL") {
                cells.append(SQLDataCell.nullCell())
            } else if (elem.startsWith("\"") && elem.endsWith("\"")) {
                // 引号字符串
                let unquoted = elem.substring(1, elem.size - 1)
                cells.append(SQLDataCell.fromString(unquoted))
            } else {
                // 根据类型尝试解析
                let cell = parseArrayElement(elem, bigint, oid)
                cells.append(cell)
            }
        }
        return cells
    }

    /// 分割数组元素
    private static func splitArrayElements(content: String): Array<String> {
        let result = Array<String>()
        var current = ""
        var inQuotes = false
        var depth = 0
        for (c in content) {
            if (c == '"') {
                inQuotes = !inQuotes
                current = current + String(c)
            } else if (!inQuotes && c == '{') {
                depth += 1
                current = current + String(c)
            } else if (!inQuotes && c == '}') {
                depth -= 1
                current = current + String(c)
            } else if (!inQuotes && c == ',' && depth == 0) {
                result.append(current)
                current = ""
            } else {
                current = current + String(c)
            }
        }
        if (!current.isEmpty) {
            result.append(current)
        }
        return result
    }

    /// 解析数组元素
    private static func parseArrayElement(elem: String, bigint: Bool, oid: PGTag): SQLDataCell {
        match (oid) {
            case PGTag.Int4Array | PGTag.Int2Array => {
                let v = Int32(elem)
                return SQLDataCell.fromInt32(v)
            }
            case PGTag.Int8Array => {
                if (bigint) {
                    let v = Int64(elem)
                    return SQLDataCell.fromInt64(v)
                } else {
                    return SQLDataCell.fromString(elem)
                }
            }
            case PGTag.Float8Array | PGTag.Float4Array => {
                let v = Float64(elem)
                return SQLDataCell.fromFloat64(v)
            }
            case PGTag.BoolArray => {
                let b = elem == "t" || elem == "true" || elem == "1"
                return SQLDataCell.fromBool(b)
            }
            case PGTag.JSONArray | PGTag.JSONBArray => {
                return SQLDataCell.fromJson(elem)
            }
            case _ => {
                return SQLDataCell.fromString(elem)
            }
        }
    }

    // ========================================================================
    // 通用辅助函数
    // ========================================================================

    /// 将字节数组转为字符串
    public static func bytesToString(bytes: Array<UInt8>): String {
        bytes.toArray().map({ b => Char.fromUInt8(b) }).toString()
    }

    /// 解析文本 Int32
    private static func parseInt32(bytes: Array<UInt8>): Int32 {
        let s = bytesToString(bytes)
        Int32(s)
    }

    /// 解析文本 Int64
    private static func parseInt64(bytes: Array<UInt8>): Int64 {
        let s = bytesToString(bytes)
        Int64(s)
    }

    /// 解析文本 UInt32
    private static func parseUInt32(bytes: Array<UInt8>): UInt32 {
        let s = bytesToString(bytes)
        UInt32(s)
    }

    /// 解析文本 Float64
    private static func parseFloat64(bytes: Array<UInt8>): Float64 {
        let s = bytesToString(bytes)
        Float64(s)
    }

    /// 十六进制解码单个字符
    private static func hexDecode(b: UInt8): UInt8 {
        if (b >= UInt8('0') && b <= UInt8('9')) {
            return b - UInt8('0')
        } else if (b >= UInt8('a') && b <= UInt8('f')) {
            return b - UInt8('a') + 10
        } else if (b >= UInt8('A') && b <= UInt8('F')) {
            return b - UInt8('A') + 10
        }
        return 0
    }

    /// OID 到 JS TypedArray 类型映射
    private static func oidToJSType(oid: PGTag): JSTypedArrayType {
        match (oid) {
            case PGTag.Int4Array => JSTypedArrayType.Int32Array
            case PGTag.Float4Array => JSTypedArrayType.Float32Array
            case PGTag.Float8Array => JSTypedArrayType.Float64Array
            case _ => JSTypedArrayType.Uint8Array
        }
    }

    /// 从大端字节数组读取 UInt16
    private static func readUInt16BE(bytes: Array<UInt8>, offset: Int64): UInt16 {
        let b0 = UInt16(bytes[offset]) << 8
        let b1 = UInt16(bytes[offset + 1])
        return b0 | b1
    }

    /// 从大端字节数组读取 UInt32
    private static func readUInt32BE(bytes: Array<UInt8>, offset: Int64): UInt32 {
        let b0 = UInt32(bytes[offset]) << 24
        let b1 = UInt32(bytes[offset + 1]) << 16
        let b2 = UInt32(bytes[offset + 2]) << 8
        let b3 = UInt32(bytes[offset + 3])
        return b0 | b1 | b2 | b3
    }

    /// 从大端字节数组读取 UInt64
    private static func readUInt64BE(bytes: Array<UInt8>, offset: Int64): UInt64 {
        let hi = UInt64(readUInt32BE(bytes, offset)) << 32
        let lo = UInt64(readUInt32BE(bytes, offset + 4))
        return hi | lo
    }

    /// 从大端字节数组读取 Int64
    private static func readInt64BE(bytes: Array<UInt8>, offset: Int64): Int64 {
        Int64(readUInt64BE(bytes, offset))
    }

    /// 反转 Postgres 字符串中的转义
    /// 对应 Bun unescapePostgresString()
    public static func unescapePostgresString(input: Array<UInt8>): Array<UInt8> {
        let result = Array<UInt8>()
        var i = 0
        while (i < input.size) {
            if (input[i] == UInt8('\\') && i + 1 < input.size) {
                i += 1
                match (input[i]) {
                    case UInt8('b') => result.append(UInt8(0x08))
                    case UInt8('f') => result.append(UInt8(0x0C))
                    case UInt8('n') => result.append(UInt8('\n'))
                    case UInt8('r') => result.append(UInt8('\r'))
                    case UInt8('t') => result.append(UInt8('\t'))
                    case UInt8('"') => result.append(UInt8('"'))
                    case UInt8('\\') => result.append(UInt8('\\'))
                    case UInt8('\'') => result.append(UInt8('\''))
                    case UInt8('/') => result.append(UInt8('/'))
                    case UInt8('x') => {
                        // 十六进制转义 \xNN
                        if (i + 2 < input.size) {
                            let hi = hexDecode(input[i + 1])
                            let lo = hexDecode(input[i + 2])
                            result.append(hi * UInt8(16) + lo)
                            i += 2
                        }
                    }
                    case _ => {
                        result.append(input[i])
                    }
                }
            } else {
                result.append(input[i])
            }
            i += 1
        }
        return result
    }
}
