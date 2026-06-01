// PostgreSQL 数据类型标签 (OID 映射)
// 严格翻译自: bun/src/sql/postgres/types/Tag.zig
// 包含所有 PostgreSQL 数据类型的 OID 到枚举的映射
package bao_runtime.sql.postgresql

/// PostgreSQL 数据类型标签
/// 通过 OID 标识 PostgreSQL 中的各种数据类型
/// 对应 Bun Tag (enum(short))
public enum PGTag {
    // ===== 基本类型 =====
    | `Bool`             // OID 16
    | Bytea            // OID 17
    | Char             // OID 18
    | Name             // OID 19
    | PgInt8             // OID 20 (int8/bigint)
    | PgInt2             // OID 21 (int2/smallint)
    | PgInt2Vector       // OID 22
    | PgInt4             // OID 23 (int4/integer)
    | Text             // OID 25
    | Oid              // OID 26
    | Xid              // OID 28
    | Cid              // OID 29
    | Json             // OID 114
    | Xml              // OID 142
    | Point            // OID 600
    | Lseg             // OID 601
    | Path             // OID 602
    | Box              // OID 603
    | Polygon          // OID 604
    | Line             // OID 628
    | Cidr             // OID 650
    | Float4           // OID 700 (real)
    | Float8           // OID 701 (double precision)
    | Circle           // OID 718
    | Macaddr8         // OID 774
    | Money            // OID 790
    | Macaddr          // OID 829
    | Inet             // OID 869
    | Aclitem          // OID 1033
    | Bpchar           // OID 1042 (char(n))
    | Varchar          // OID 1043 (varchar(n))
    | Date             // OID 1082
    | Time             // OID 1083
    | Timestamp        // OID 1114
    | Timestamptz      // OID 1184
    | Interval         // OID 1186
    | PgDatabase       // OID 1248
    | Timetz           // OID 1266
    | Bit              // OID 1560
    | Varbit           // OID 1562
    | Numeric          // OID 1700
    | Uuid             // OID 2950
    | Jsonb            // OID 3802
    | Jsonpath         // OID 4072

    // ===== 数组类型 =====
    | BoolArray          // OID 1000
    | ByteaArray         // OID 1001
    | CharArray          // OID 1002
    | NameArray          // OID 1003
    | PgInt8Array          // OID 1016
    | PgInt2Array          // OID 1005
    | PgInt2VectorArray    // OID 1006
    | PgInt4Array          // OID 1007
    | TextArray          // OID 1009
    | OidArray           // OID 1028
    | TidArray           // OID 1010
    | XidArray           // OID 1011
    | CidArray           // OID 1012
    | JsonArray          // OID 199
    | XmlArray           // OID 143
    | PointArray         // OID 1017
    | LsegArray          // OID 1018
    | PathArray          // OID 1019
    | BoxArray           // OID 1020
    | PolygonArray       // OID 1027
    | LineArray          // OID 629
    | CidrArray          // OID 651
    | Float4Array        // OID 1021
    | Float8Array        // OID 1022
    | CircleArray        // OID 719
    | Macaddr8Array      // OID 775
    | MoneyArray         // OID 791
    | MacaddrArray       // OID 1040
    | InetArray          // OID 1041
    | AclitemArray       // OID 1034
    | BpcharArray        // OID 1014
    | VarcharArray       // OID 1015
    | DateArray          // OID 1182
    | TimeArray          // OID 1183
    | TimestampArray     // OID 1115
    | TimestamptzArray   // OID 1185
    | IntervalArray      // OID 1187
    | PgDatabaseArray2   // OID 12052
    | TimetzArray        // OID 1270
    | BitArray           // OID 1561
    | VarbitArray        // OID 1563
    | NumericArray       // OID 1231
    | JsonbArray         // OID 3807
    | JsonpathArray      // OID 4073

    // ===== 未知类型 =====
    | Unknown(UInt16)    // 未在映射中的 OID

    /// 通过 OID 获取 PGTag
    /// 对应 Bun Tag 枚举的 @enumFromInt
    public static func fromOID(oid: UInt16): PGTag {
        match (oid) {
            case 16 => `Bool`
            case 17 => Bytea
            case 18 => Char
            case 19 => Name
            case 20 => PgInt8
            case 21 => PgInt2
            case 22 => PgInt2Vector
            case 23 => PgInt4
            case 25 => Text
            case 26 => Oid
            case 28 => Xid
            case 29 => Cid
            case 114 => Json
            case 142 => Xml
            case 600 => Point
            case 601 => Lseg
            case 602 => Path
            case 603 => Box
            case 604 => Polygon
            case 628 => Line
            case 650 => Cidr
            case 700 => Float4
            case 701 => Float8
            case 718 => Circle
            case 774 => Macaddr8
            case 790 => Money
            case 829 => Macaddr
            case 869 => Inet
            case 1033 => Aclitem
            case 1042 => Bpchar
            case 1043 => Varchar
            case 1082 => Date
            case 1083 => Time
            case 1114 => Timestamp
            case 1184 => Timestamptz
            case 1186 => Interval
            case 1248 => PgDatabase
            case 1266 => Timetz
            case 1560 => Bit
            case 1562 => Varbit
            case 1700 => Numeric
            case 2950 => Uuid
            case 3802 => Jsonb
            case 4072 => Jsonpath
            // 数组类型
            case 1000 => BoolArray
            case 1001 => ByteaArray
            case 1002 => CharArray
            case 1003 => NameArray
            case 1005 => PgInt2Array
            case 1006 => PgInt2VectorArray
            case 1007 => PgInt4Array
            case 1009 => TextArray
            case 1010 => TidArray
            case 1011 => XidArray
            case 1012 => CidArray
            case 1014 => BpcharArray
            case 1015 => VarcharArray
            case 1016 => PgInt8Array
            case 1017 => PointArray
            case 1018 => LsegArray
            case 1019 => PathArray
            case 1020 => BoxArray
            case 1021 => Float4Array
            case 1022 => Float8Array
            case 1027 => PolygonArray
            case 1028 => OidArray
            case 1034 => AclitemArray
            case 1040 => MacaddrArray
            case 1041 => InetArray
            case 143 => XmlArray
            case 199 => JsonArray
            case 629 => LineArray
            case 651 => CidrArray
            case 675 => Macaddr8Array
            case 719 => CircleArray
            case 775 => Macaddr8Array
            case 791 => MoneyArray
            case 1115 => TimestampArray
            case 1182 => DateArray
            case 1183 => TimeArray
            case 1185 => TimestamptzArray
            case 1187 => IntervalArray
            case 12052 => PgDatabaseArray2
            case 1231 => NumericArray
            case 1270 => TimetzArray
            case 1561 => BitArray
            case 1563 => VarbitArray
            case 3807 => JsonbArray
            case 4073 => JsonpathArray
            case _ => Unknown(oid)
        }
    }

    /// 获取标签名称
    /// 对应 Bun Tag.tagName()
    public func tagName(): ?String {
        match (this) {
            case `Bool` => "bool"
            case Bytea => "bytea"
            case Char => "char"
            case Name => "name"
            case PgInt8 => "int8"
            case PgInt2 => "int2"
            case PgInt2Vector => "int2vector"
            case PgInt4 => "int4"
            case Text => "text"
            case Oid => "oid"
            case Xid => "xid"
            case Cid => "cid"
            case Json => "json"
            case Xml => "xml"
            case Point => "point"
            case Lseg => "lseg"
            case Path => "path"
            case Box => "box"
            case Polygon => "polygon"
            case Line => "line"
            case Cidr => "cidr"
            case Float4 => "float4"
            case Float8 => "float8"
            case Circle => "circle"
            case Macaddr8 => "macaddr8"
            case Money => "money"
            case Macaddr => "macaddr"
            case Inet => "inet"
            case Aclitem => "aclitem"
            case Bpchar => "bpchar"
            case Varchar => "varchar"
            case Date => "date"
            case Time => "time"
            case Timestamp => "timestamp"
            case Timestamptz => "timestamptz"
            case Interval => "interval"
            case PgDatabase => "pg_database"
            case Timetz => "timetz"
            case Bit => "bit"
            case Varbit => "varbit"
            case Numeric => "numeric"
            case Uuid => "uuid"
            case Jsonb => "jsonb"
            case Jsonpath => "jsonpath"
            case BoolArray => "bool_array"
            case ByteaArray => "bytea_array"
            case CharArray => "char_array"
            case NameArray => "name_array"
            case PgInt8Array => "int8_array"
            case PgInt2Array => "int2_array"
            case PgInt2VectorArray => "int2vector_array"
            case PgInt4Array => "int4_array"
            case TextArray => "text_array"
            case OidArray => "oid_array"
            case TidArray => "tid_array"
            case XidArray => "xid_array"
            case CidArray => "cid_array"
            case JsonArray => "json_array"
            case XmlArray => "xml_array"
            case PointArray => "point_array"
            case LsegArray => "lseg_array"
            case PathArray => "path_array"
            case BoxArray => "box_array"
            case PolygonArray => "polygon_array"
            case LineArray => "line_array"
            case CidrArray => "cidr_array"
            case Float4Array => "float4_array"
            case Float8Array => "float8_array"
            case CircleArray => "circle_array"
            case Macaddr8Array => "macaddr8_array"
            case MoneyArray => "money_array"
            case MacaddrArray => "macaddr_array"
            case InetArray => "inet_array"
            case AclitemArray => "aclitem_array"
            case BpcharArray => "bpchar_array"
            case VarcharArray => "varchar_array"
            case DateArray => "date_array"
            case TimeArray => "time_array"
            case TimestampArray => "timestamp_array"
            case TimestamptzArray => "timestamptz_array"
            case IntervalArray => "interval_array"
            case PgDatabaseArray2 => "pg_database_array2"
            case TimetzArray => "timetz_array"
            case BitArray => "bit_array"
            case VarbitArray => "varbit_array"
            case NumericArray => "numeric_array"
            case JsonbArray => "jsonb_array"
            case JsonpathArray => "jsonpath_array"
            case Unknown(_) => None
        }
    }

    /// 是否支持二进制格式
    /// 对应 Bun Tag.isBinaryFormatSupported()
    public func isBinaryFormatSupported(): Bool {
        match (this) {
            case `Bool` | Timestamp | Timestamptz | Time |
                 PgInt4Array | Float4Array | PgInt4 | Float8 | Float4 |
                 Bytea | Numeric => true
            case _ => false
        }
    }

    /// 获取格式代码
    /// 对应 Bun Tag.formatCode()
    /// 返回 1 表示二进制，0 表示文本
    public func formatCode(): UInt16 {
        if (isBinaryFormatSupported()) {
            return 1
        }
        return 0
    }

    /// 转为整数 (OID)
    /// 对应 Bun 中 @intFromEnum(tag)
    public func toInt(): Int32 {
        match (this) {
            case `Bool` => 16
            case Bytea => 17
            case Char => 18
            case Name => 19
            case PgInt8 => 20
            case PgInt2 => 21
            case PgInt2Vector => 22
            case PgInt4 => 23
            case Text => 25
            case Oid => 26
            case Xid => 28
            case Cid => 29
            case Json => 114
            case Xml => 142
            case Float4 => 700
            case Float8 => 701
            case Numeric => 1700
            case Bpchar => 1042
            case Varchar => 1043
            case Date => 1082
            case Time => 1083
            case Timestamp => 1114
            case Timestamptz => 1184
            case Interval => 1186
            case Timetz => 1266
            case Bit => 1560
            case Varbit => 1562
            case Uuid => 2950
            case Jsonb => 3802
            case Jsonpath => 4072
            case _ => 0
        }
    }

    /// 是否为数组类型
    public func isArray(): Bool {
        match (this) {
            case BoolArray | ByteaArray | CharArray | NameArray |
                 PgInt8Array | PgInt2Array | PgInt2VectorArray | PgInt4Array |
                 TextArray | OidArray | TidArray | XidArray | CidArray |
                 JsonArray | XmlArray | PointArray | LsegArray |
                 PathArray | BoxArray | PolygonArray | LineArray |
                 CidrArray | Float4Array | Float8Array | CircleArray |
                 Macaddr8Array | MoneyArray | MacaddrArray | InetArray |
                 AclitemArray | BpcharArray | VarcharArray | DateArray |
                 TimeArray | TimestampArray | TimestamptzArray | IntervalArray |
                 PgDatabaseArray2 | TimetzArray | BitArray | VarbitArray |
                 NumericArray | JsonbArray | JsonpathArray => true
            case _ => false
        }
    }
}
