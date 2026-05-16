// 严格翻译自: src/sql/postgres/types/Tag.zig
// PostgreSQL 类型 OID 标签
package bao_sql.postgres.types

/// PostgreSQL 类型 OID 标签
/// 对应 Bun: Tag (enum short)
/// 包含所有 PostgreSQL 数据类型的 OID 值
public enum Tag {
    | bool                    // 16
    | bytea                   // 17
    | char                    // 18
    | name                    // 19
    | int8                    // 20
    | int2                    // 21
    | int2vector              // 22
    | int4                    // 23
    | text                    // 25
    | oid                     // 26
    | xid                     // 28
    | cid                     // 29
    | json                    // 114
    | xml                     // 142
    | point                   // 600
    | lseg                    // 601
    | path                    // 602
    | box                     // 603
    | polygon                 // 604
    | line                    // 628
    | cidr                    // 650
    | float4                  // 700
    | float8                  // 701
    | circle                  // 718
    | macaddr8                // 774
    | money                   // 790
    | macaddr                 // 829
    | inet                    // 869
    | aclitem                 // 1033
    | bpchar                  // 1042
    | varchar                 // 1043
    | date                    // 1082
    | time                    // 1083
    | timestamp               // 1114
    | timestamptz             // 1184
    | interval                // 1186
    | pg_database             // 1248
    | timetz                  // 1266
    | bit                     // 1560
    | varbit                  // 1562
    | numeric                 // 1700
    | uuid                    // 2950
    // 数组类型
    | bool_array              // 1000
    | bytea_array             // 1001
    | char_array              // 1002
    | name_array              // 1003
    | int8_array              // 1016
    | int2_array              // 1005
    | int2vector_array        // 1006
    | int4_array              // 1007
    | text_array              // 1009
    | oid_array               // 1028
    | tid_array               // 1010
    | xid_array               // 1011
    | cid_array               // 1012
    | json_array              // 199
    | xml_array               // 143
    | point_array             // 1017
    | lseg_array              // 1018
    | path_array              // 1019
    | box_array               // 1020
    | polygon_array           // 1027
    | line_array              // 629
    | cidr_array              // 651
    | float4_array            // 1021
    | float8_array            // 1022
    | circle_array            // 719
    | macaddr8_array          // 775
    | money_array             // 791
    | macaddr_array           // 1040
    | inet_array              // 1041
    | aclitem_array           // 1034
    | bpchar_array            // 1014
    | varchar_array           // 1015
    | date_array              // 1182
    | time_array              // 1183
    | timestamp_array         // 1115
    | timestamptz_array       // 1185
    | interval_array          // 1187
    | pg_database_array       // 12052
    | timetz_array            // 1270
    | bit_array               // 1561
    | varbit_array            // 1563
    | numeric_array           // 1231
    | jsonb                   // 3802
    | jsonb_array             // 3807
    | jsonpath                // 4072
    | jsonpath_array          // 4073
    | pg_database_array2      // 10052
    | unknown(Int16)

    /// 获取 OID 值
    /// 对应 Bun: Tag 的枚举值
    public func getOid(): Int16 {
        match (this) {
            case bool => 16
            case bytea => 17
            case char => 18
            case name => 19
            case int8 => 20
            case int2 => 21
            case int2vector => 22
            case int4 => 23
            case text => 25
            case oid => 26
            case xid => 28
            case cid => 29
            case json => 114
            case xml => 142
            case point => 600
            case lseg => 601
            case path => 602
            case box => 603
            case polygon => 604
            case line => 628
            case cidr => 650
            case float4 => 700
            case float8 => 701
            case circle => 718
            case macaddr8 => 774
            case money => 790
            case macaddr => 829
            case inet => 869
            case aclitem => 1033
            case bpchar => 1042
            case varchar => 1043
            case date => 1082
            case time => 1083
            case timestamp => 1114
            case timestamptz => 1184
            case interval => 1186
            case pg_database => 1248
            case timetz => 1266
            case bit => 1560
            case varbit => 1562
            case numeric => 1700
            case uuid => 2950
            case bool_array => 1000
            case bytea_array => 1001
            case char_array => 1002
            case name_array => 1003
            case int8_array => 1016
            case int2_array => 1005
            case int2vector_array => 1006
            case int4_array => 1007
            case text_array => 1009
            case oid_array => 1028
            case tid_array => 1010
            case xid_array => 1011
            case cid_array => 1012
            case json_array => 199
            case xml_array => 143
            case point_array => 1017
            case lseg_array => 1018
            case path_array => 1019
            case box_array => 1020
            case polygon_array => 1027
            case line_array => 629
            case cidr_array => 651
            case float4_array => 1021
            case float8_array => 1022
            case circle_array => 719
            case macaddr8_array => 775
            case money_array => 791
            case macaddr_array => 1040
            case inet_array => 1041
            case aclitem_array => 1034
            case bpchar_array => 1014
            case varchar_array => 1015
            case date_array => 1182
            case time_array => 1183
            case timestamp_array => 1115
            case timestamptz_array => 1185
            case interval_array => 1187
            case pg_database_array => 12052
            case timetz_array => 1270
            case bit_array => 1561
            case varbit_array => 1563
            case numeric_array => 1231
            case jsonb => 3802
            case jsonb_array => 3807
            case jsonpath => 4072
            case jsonpath_array => 4073
            case pg_database_array2 => 10052
            case unknown(v) => v
        }
    }

    /// 从 OID 值创建 Tag
    /// 对应 Bun: @enumFromInt
    public static func fromOid(oid: Int16): Tag {
        match (oid) {
            case 16 => Tag.bool
            case 17 => Tag.bytea
            case 18 => Tag.char
            case 19 => Tag.name
            case 20 => Tag.int8
            case 21 => Tag.int2
            case 22 => Tag.int2vector
            case 23 => Tag.int4
            case 25 => Tag.text
            case 26 => Tag.oid
            case 28 => Tag.xid
            case 29 => Tag.cid
            case 114 => Tag.json
            case 142 => Tag.xml
            case 600 => Tag.point
            case 601 => Tag.lseg
            case 602 => Tag.path
            case 603 => Tag.box
            case 604 => Tag.polygon
            case 628 => Tag.line
            case 650 => Tag.cidr
            case 700 => Tag.float4
            case 701 => Tag.float8
            case 718 => Tag.circle
            case 774 => Tag.macaddr8
            case 790 => Tag.money
            case 829 => Tag.macaddr
            case 869 => Tag.inet
            case 1033 => Tag.aclitem
            case 1042 => Tag.bpchar
            case 1043 => Tag.varchar
            case 1082 => Tag.date
            case 1083 => Tag.time
            case 1114 => Tag.timestamp
            case 1184 => Tag.timestamptz
            case 1186 => Tag.interval
            case 1248 => Tag.pg_database
            case 1266 => Tag.timetz
            case 1560 => Tag.bit
            case 1562 => Tag.varbit
            case 1700 => Tag.numeric
            case 2950 => Tag.uuid
            case 1000 => Tag.bool_array
            case 1001 => Tag.bytea_array
            case 1002 => Tag.char_array
            case 1003 => Tag.name_array
            case 1016 => Tag.int8_array
            case 1005 => Tag.int2_array
            case 1006 => Tag.int2vector_array
            case 1007 => Tag.int4_array
            case 1009 => Tag.text_array
            case 1028 => Tag.oid_array
            case 1010 => Tag.tid_array
            case 1011 => Tag.xid_array
            case 1012 => Tag.cid_array
            case 199 => Tag.json_array
            case 143 => Tag.xml_array
            case 1017 => Tag.point_array
            case 1018 => Tag.lseg_array
            case 1019 => Tag.path_array
            case 1020 => Tag.box_array
            case 1027 => Tag.polygon_array
            case 629 => Tag.line_array
            case 651 => Tag.cidr_array
            case 1021 => Tag.float4_array
            case 1022 => Tag.float8_array
            case 719 => Tag.circle_array
            case 775 => Tag.macaddr8_array
            case 791 => Tag.money_array
            case 1040 => Tag.macaddr_array
            case 1041 => Tag.inet_array
            case 1034 => Tag.aclitem_array
            case 1014 => Tag.bpchar_array
            case 1015 => Tag.varchar_array
            case 1182 => Tag.date_array
            case 1183 => Tag.time_array
            case 1115 => Tag.timestamp_array
            case 1185 => Tag.timestamptz_array
            case 1187 => Tag.interval_array
            case 12052 => Tag.pg_database_array
            case 1270 => Tag.timetz_array
            case 1561 => Tag.bit_array
            case 1563 => Tag.varbit_array
            case 1231 => Tag.numeric_array
            case 3802 => Tag.jsonb
            case 3807 => Tag.jsonb_array
            case 4072 => Tag.jsonpath
            case 4073 => Tag.jsonpath_array
            case 10052 => Tag.pg_database_array2
            case _ => Tag.unknown(oid)
        }
    }

    /// 是否支持二进制格式
    /// 对应 Bun: Tag.isBinaryFormatSupported
    public func isBinaryFormatSupported(): Bool {
        match (this) {
            case bool => true
            case timestamp => true
            case timestamptz => true
            case time => true
            case int4_array => true
            case float4_array => true
            case int4 => true
            case float8 => true
            case float4 => true
            case bytea => true
            case numeric => true
            case _ => false
        }
    }

    /// 获取格式代码 (0=文本, 1=二进制)
    /// 对应 Bun: Tag.formatCode
    public func formatCode(): Int16 {
        if (this.isBinaryFormatSupported()) {
            return 1
        }
        return 0
    }

    /// 获取标签名
    /// 对应 Bun: Tag.tagName
    public func tagName(): ?String {
        match (this) {
            case bool => Some("bool")
            case bytea => Some("bytea")
            case char => Some("char")
            case name => Some("name")
            case int8 => Some("int8")
            case int2 => Some("int2")
            case int4 => Some("int4")
            case text => Some("text")
            case oid => Some("oid")
            case json => Some("json")
            case float4 => Some("float4")
            case float8 => Some("float8")
            case date => Some("date")
            case time => Some("time")
            case timestamp => Some("timestamp")
            case timestamptz => Some("timestamptz")
            case varchar => Some("varchar")
            case numeric => Some("numeric")
            case uuid => Some("uuid")
            case jsonb => Some("jsonb")
            case _ => None
        }
    }
}
