// MySQL 类型定义
// 对应 Bun: src/sql/mysql/MySQLTypes.zig
package bao_sql

/// MySQL 整数类型别名
/// 对应 Bun: int1, int2, int3, int4, int8
public type MySQLInt8 = UInt8   // int1 = u8
public type MySQLInt16 = UInt16 // int2 = u16
// int3 = u24 (仓颉没有 u24，使用 UInt32 替代)
public type MySQLInt24 = UInt32 // int3 = u24 -> UInt32
public type MySQLInt32 = UInt32 // int4 = u32
public type MySQLInt64 = UInt64 // int8 = u64

/// MySQL 字符集
/// 对应 Bun: CharacterSet (enum u8)
/// 参考: https://dev.mysql.com/doc/refman/8.0/en/charset-charsets.html
public enum CharacterSet <: UInt8 {
    | big5_chinese_ci(UInt8)             // 1
    | latin2_czech_cs(UInt8)             // 2
    | dec8_swedish_ci(UInt8)             // 3
    | cp850_general_ci(UInt8)            // 4
    | latin1_german1_ci(UInt8)           // 5
    | hp8_english_ci(UInt8)              // 6
    | koi8r_general_ci(UInt8)            // 7
    | latin1_swedish_ci(UInt8)           // 8
    | latin2_general_ci(UInt8)           // 9
    | swe7_swedish_ci(UInt8)             // 10
    | ascii_general_ci(UInt8)            // 11
    | ujis_japanese_ci(UInt8)            // 12
    | sjis_japanese_ci(UInt8)            // 13
    | cp1251_bulgarian_ci(UInt8)         // 14
    | latin1_danish_ci(UInt8)            // 15
    | hebrew_general_ci(UInt8)           // 16
    | tis620_thai_ci(UInt8)              // 18
    | euckr_korean_ci(UInt8)             // 19
    | latin7_estonian_cs(UInt8)          // 20
    | latin2_hungarian_ci(UInt8)         // 21
    | koi8u_general_ci(UInt8)            // 22
    | cp1251_ukrainian_ci(UInt8)         // 23
    | gb2312_chinese_ci(UInt8)           // 24
    | greek_general_ci(UInt8)            // 25
    | cp1250_general_ci(UInt8)           // 26
    | latin2_croatian_ci(UInt8)          // 27
    | gbk_chinese_ci(UInt8)              // 28
    | cp1257_lithuanian_ci(UInt8)        // 29
    | latin5_turkish_ci(UInt8)           // 30
    | latin1_german2_ci(UInt8)           // 31
    | armscii8_general_ci(UInt8)         // 32
    | utf8mb3_general_ci(UInt8)          // 33
    | cp1250_czech_cs(UInt8)             // 34
    | ucs2_general_ci(UInt8)             // 35
    | cp866_general_ci(UInt8)            // 36
    | keybcs2_general_ci(UInt8)          // 37
    | macce_general_ci(UInt8)            // 38
    | macroman_general_ci(UInt8)         // 39
    | cp852_general_ci(UInt8)            // 40
    | latin7_general_ci(UInt8)           // 41
    | latin7_general_cs(UInt8)           // 42
    | macce_bin(UInt8)                   // 43
    | cp1250_croatian_ci(UInt8)          // 44
    | utf8mb4_general_ci(UInt8)          // 45
    | utf8mb4_bin(UInt8)                 // 46
    | latin1_bin(UInt8)                  // 47
    | latin1_general_ci(UInt8)           // 48
    | latin1_general_cs(UInt8)           // 49
    | cp1251_bin(UInt8)                  // 50
    | cp1251_general_ci(UInt8)           // 51
    | cp1251_general_cs(UInt8)           // 52
    | macroman_bin(UInt8)                // 53
    | utf16_general_ci(UInt8)            // 54
    | utf16_bin(UInt8)                   // 55
    | utf16le_general_ci(UInt8)          // 56
    | cp1256_general_ci(UInt8)           // 57
    | cp1257_bin(UInt8)                  // 58
    | cp1257_general_ci(UInt8)           // 59
    | utf32_general_ci(UInt8)            // 60
    | utf32_bin(UInt8)                   // 61
    | utf16le_bin(UInt8)                 // 62
    | binary(UInt8)                      // 63
    | armscii8_bin(UInt8)                // 64
    | ascii_bin(UInt8)                   // 65
    | cp1250_bin(UInt8)                  // 66
    | cp1256_bin(UInt8)                  // 67
    | cp866_bin(UInt8)                   // 68
    | dec8_bin(UInt8)                    // 69
    | greek_bin(UInt8)                   // 70
    | hebrew_bin(UInt8)                  // 71
    | hp8_bin(UInt8)                     // 72
    | keybcs2_bin(UInt8)                 // 73
    | koi8r_bin(UInt8)                   // 74
    | koi8u_bin(UInt8)                   // 75
    | utf8mb3_tolower_ci(UInt8)          // 76
    | latin2_bin(UInt8)                  // 77
    | latin5_bin(UInt8)                  // 78
    | latin7_bin(UInt8)                  // 79
    | cp850_bin(UInt8)                   // 80
    | cp852_bin(UInt8)                   // 81
    | swe7_bin(UInt8)                    // 82
    | utf8mb3_bin(UInt8)                 // 83
    | big5_bin(UInt8)                    // 84
    | euckr_bin(UInt8)                   // 85
    | gb2312_bin(UInt8)                  // 86
    | gbk_bin(UInt8)                     // 87
    | sjis_bin(UInt8)                    // 88
    | tis620_bin(UInt8)                  // 89
    | ucs2_bin(UInt8)                    // 90
    | ujis_bin(UInt8)                    // 91
    | geostd8_general_ci(UInt8)          // 92
    | geostd8_bin(UInt8)                 // 93
    | latin1_spanish_ci(UInt8)           // 94
    | cp932_japanese_ci(UInt8)           // 95
    | cp932_bin(UInt8)                   // 96
    | eucjpms_japanese_ci(UInt8)         // 97
    | eucjpms_bin(UInt8)                 // 98
    | cp1250_polish_ci(UInt8)            // 99
    | utf16_unicode_ci(UInt8)            // 101
    | utf16_icelandic_ci(UInt8)          // 102
    | utf16_latvian_ci(UInt8)            // 103
    | utf16_romanian_ci(UInt8)           // 104
    | utf16_slovenian_ci(UInt8)          // 105
    | utf16_polish_ci(UInt8)             // 106
    | utf16_estonian_ci(UInt8)           // 107
    | utf16_spanish_ci(UInt8)            // 108
    | utf16_swedish_ci(UInt8)            // 109
    | utf16_turkish_ci(UInt8)            // 110
    | utf16_czech_ci(UInt8)              // 111
    | utf16_danish_ci(UInt8)             // 112
    | utf16_lithuanian_ci(UInt8)         // 113
    | utf16_slovak_ci(UInt8)             // 114
    | utf16_spanish2_ci(UInt8)           // 115
    | utf16_roman_ci(UInt8)              // 116
    | utf16_persian_ci(UInt8)            // 117
    | utf16_esperanto_ci(UInt8)          // 118
    | utf16_hungarian_ci(UInt8)          // 119
    | utf16_sinhala_ci(UInt8)            // 120
    | utf16_german2_ci(UInt8)            // 121
    | utf16_croatian_ci(UInt8)           // 122
    | utf16_unicode_520_ci(UInt8)        // 123
    | utf16_vietnamese_ci(UInt8)         // 124
    | ucs2_unicode_ci(UInt8)             // 128
    | ucs2_icelandic_ci(UInt8)           // 129
    | ucs2_latvian_ci(UInt8)             // 130
    | ucs2_romanian_ci(UInt8)            // 131
    | ucs2_slovenian_ci(UInt8)           // 132
    | ucs2_polish_ci(UInt8)              // 133
    | ucs2_estonian_ci(UInt8)            // 134
    | ucs2_spanish_ci(UInt8)             // 135
    | ucs2_swedish_ci(UInt8)             // 136
    | ucs2_turkish_ci(UInt8)             // 137
    | ucs2_czech_ci(UInt8)               // 138
    | ucs2_danish_ci(UInt8)              // 139
    | ucs2_lithuanian_ci(UInt8)          // 140
    | ucs2_slovak_ci(UInt8)              // 141
    | ucs2_spanish2_ci(UInt8)            // 142
    | ucs2_roman_ci(UInt8)               // 143
    | ucs2_persian_ci(UInt8)             // 144
    | ucs2_esperanto_ci(UInt8)           // 145
    | ucs2_hungarian_ci(UInt8)           // 146
    | ucs2_sinhala_ci(UInt8)             // 147
    | ucs2_german2_ci(UInt8)             // 148
    | ucs2_croatian_ci(UInt8)            // 149
    | ucs2_unicode_520_ci(UInt8)         // 150
    | ucs2_vietnamese_ci(UInt8)          // 151
    | ucs2_general_mysql500_ci(UInt8)    // 159
    | utf32_unicode_ci(UInt8)            // 160
    | utf32_icelandic_ci(UInt8)          // 161
    | utf32_latvian_ci(UInt8)            // 162
    | utf32_romanian_ci(UInt8)           // 163
    | utf32_slovenian_ci(UInt8)          // 164
    | utf32_polish_ci(UInt8)             // 165
    | utf32_estonian_ci(UInt8)           // 166
    | utf32_spanish_ci(UInt8)            // 167
    | utf32_swedish_ci(UInt8)            // 168
    | utf32_turkish_ci(UInt8)            // 169
    | utf32_czech_ci(UInt8)              // 170
    | utf32_danish_ci(UInt8)             // 171
    | utf32_lithuanian_ci(UInt8)         // 172
    | utf32_slovak_ci(UInt8)             // 173
    | utf32_spanish2_ci(UInt8)           // 174
    | utf32_roman_ci(UInt8)              // 175
    | utf32_persian_ci(UInt8)            // 176
    | utf32_esperanto_ci(UInt8)          // 177
    | utf32_hungarian_ci(UInt8)          // 178
    | utf32_sinhala_ci(UInt8)            // 179
    | utf32_german2_ci(UInt8)            // 180
    | utf32_croatian_ci(UInt8)           // 181
    | utf32_unicode_520_ci(UInt8)        // 182
    | utf32_vietnamese_ci(UInt8)         // 183
    | utf8mb3_unicode_ci(UInt8)          // 192
    | utf8mb3_icelandic_ci(UInt8)        // 193
    | utf8mb3_latvian_ci(UInt8)          // 194
    | utf8mb3_romanian_ci(UInt8)         // 195
    | utf8mb3_slovenian_ci(UInt8)        // 196
    | utf8mb3_polish_ci(UInt8)           // 197
    | utf8mb3_estonian_ci(UInt8)         // 198
    | utf8mb3_spanish_ci(UInt8)          // 199
    | utf8mb3_swedish_ci(UInt8)          // 200
    | utf8mb3_turkish_ci(UInt8)          // 201
    | utf8mb3_czech_ci(UInt8)            // 202
    | utf8mb3_danish_ci(UInt8)           // 203
    | utf8mb3_lithuanian_ci(UInt8)       // 204
    | utf8mb3_slovak_ci(UInt8)           // 205
    | utf8mb3_spanish2_ci(UInt8)         // 206
    | utf8mb3_roman_ci(UInt8)            // 207
    | utf8mb3_persian_ci(UInt8)          // 208
    | utf8mb3_esperanto_ci(UInt8)        // 209
    | utf8mb3_hungarian_ci(UInt8)        // 210
    | utf8mb3_sinhala_ci(UInt8)          // 211
    | utf8mb3_german2_ci(UInt8)          // 212
    | utf8mb3_croatian_ci(UInt8)         // 213
    | utf8mb3_unicode_520_ci(UInt8)      // 214
    | utf8mb3_vietnamese_ci(UInt8)       // 215
    | utf8mb3_general_mysql500_ci(UInt8) // 223
    | utf8mb4_unicode_ci(UInt8)          // 224
    | utf8mb4_icelandic_ci(UInt8)        // 225
    | utf8mb4_latvian_ci(UInt8)          // 226
    | utf8mb4_romanian_ci(UInt8)         // 227
    | utf8mb4_slovenian_ci(UInt8)        // 228
    | utf8mb4_polish_ci(UInt8)           // 229
    | utf8mb4_estonian_ci(UInt8)         // 230
    | utf8mb4_spanish_ci(UInt8)          // 231
    | utf8mb4_swedish_ci(UInt8)          // 232
    | utf8mb4_turkish_ci(UInt8)          // 233
    | utf8mb4_czech_ci(UInt8)            // 234
    | utf8mb4_danish_ci(UInt8)           // 235
    | utf8mb4_lithuanian_ci(UInt8)       // 236
    | utf8mb4_slovak_ci(UInt8)           // 237
    | utf8mb4_spanish2_ci(UInt8)         // 238
    | utf8mb4_roman_ci(UInt8)            // 239
    | utf8mb4_persian_ci(UInt8)          // 240
    | utf8mb4_esperanto_ci(UInt8)        // 241
    | utf8mb4_hungarian_ci(UInt8)        // 242
    | utf8mb4_sinhala_ci(UInt8)          // 243
    | utf8mb4_german2_ci(UInt8)          // 244
    | utf8mb4_croatian_ci(UInt8)         // 245
    | utf8mb4_unicode_520_ci(UInt8)      // 246
    | utf8mb4_vietnamese_ci(UInt8)       // 247
    | gb18030_chinese_ci(UInt8)          // 248
    | gb18030_bin(UInt8)                 // 249
    | gb18030_unicode_520_ci(UInt8)      // 250
    | unknown(UInt8)                     // 其他

    /// 默认字符集
    public static let defaultCharSet: CharacterSet = CharacterSet.utf8mb4_general_ci(45)

    /// 获取字符集标签名称
    /// 对应 Bun: CharacterSet.label
    public func label(): String {
        let val = this.toUInt8()
        if (val > 0 && val < 100) {
            return this.toString()
        }
        return "(unknown)"
    }
}

/// MySQL 字段类型
/// 对应 Bun: FieldType (enum u8)
/// 参考: https://dev.mysql.com/doc/dev/mysql-server/latest/binary__log__types_8h.html
public enum FieldType <: UInt8 {
    | MYSQL_TYPE_DECIMAL(UInt8)     // 0x00
    | MYSQL_TYPE_TINY(UInt8)       // 0x01
    | MYSQL_TYPE_SHORT(UInt8)      // 0x02
    | MYSQL_TYPE_LONG(UInt8)       // 0x03
    | MYSQL_TYPE_FLOAT(UInt8)      // 0x04
    | MYSQL_TYPE_DOUBLE(UInt8)     // 0x05
    | MYSQL_TYPE_NULL(UInt8)       // 0x06
    | MYSQL_TYPE_TIMESTAMP(UInt8)  // 0x07
    | MYSQL_TYPE_LONGLONG(UInt8)   // 0x08
    | MYSQL_TYPE_INT24(UInt8)      // 0x09 MEDIUMINT
    | MYSQL_TYPE_DATE(UInt8)       // 0x0a
    | MYSQL_TYPE_TIME(UInt8)       // 0x0b
    | MYSQL_TYPE_DATETIME(UInt8)   // 0x0c
    | MYSQL_TYPE_YEAR(UInt8)       // 0x0d
    | MYSQL_TYPE_NEWDATE(UInt8)    // 0x0e
    | MYSQL_TYPE_VARCHAR(UInt8)    // 0x0f
    | MYSQL_TYPE_BIT(UInt8)        // 0x10
    | MYSQL_TYPE_TIMESTAMP2(UInt8) // 0x11
    | MYSQL_TYPE_DATETIME2(UInt8)  // 0x12
    | MYSQL_TYPE_TIME2(UInt8)      // 0x13
    | MYSQL_TYPE_JSON(UInt8)       // 0xf5
    | MYSQL_TYPE_NEWDECIMAL(UInt8) // 0xf6
    | MYSQL_TYPE_ENUM(UInt8)       // 0xf7
    | MYSQL_TYPE_SET(UInt8)        // 0xf8
    | MYSQL_TYPE_TINY_BLOB(UInt8)  // 0xf9
    | MYSQL_TYPE_MEDIUM_BLOB(UInt8)// 0xfa
    | MYSQL_TYPE_LONG_BLOB(UInt8)  // 0xfb
    | MYSQL_TYPE_BLOB(UInt8)       // 0xfc
    | MYSQL_TYPE_VAR_STRING(UInt8) // 0xfd
    | MYSQL_TYPE_STRING(UInt8)     // 0xfe
    | MYSQL_TYPE_GEOMETRY(UInt8)   // 0xff

    /// 判断该字段类型是否支持二进制格式
    /// 对应 Bun: FieldType.isBinaryFormatSupported
    public func isBinaryFormatSupported(): Bool {
        match (this) {
            case MYSQL_TYPE_TINY(_) => true
            case MYSQL_TYPE_SHORT(_) => true
            case MYSQL_TYPE_LONG(_) => true
            case MYSQL_TYPE_LONGLONG(_) => true
            case MYSQL_TYPE_FLOAT(_) => true
            case MYSQL_TYPE_DOUBLE(_) => true
            case MYSQL_TYPE_TIME(_) => true
            case MYSQL_TYPE_DATE(_) => true
            case MYSQL_TYPE_DATETIME(_) => true
            case MYSQL_TYPE_TIMESTAMP(_) => true
            case _ => false
        }
    }

    /// 从整数值创建
    public static func fromInt(value: UInt8): FieldType {
        match (value) {
            case 0x00 => FieldType.MYSQL_TYPE_DECIMAL(0x00)
            case 0x01 => FieldType.MYSQL_TYPE_TINY(0x01)
            case 0x02 => FieldType.MYSQL_TYPE_SHORT(0x02)
            case 0x03 => FieldType.MYSQL_TYPE_LONG(0x03)
            case 0x04 => FieldType.MYSQL_TYPE_FLOAT(0x04)
            case 0x05 => FieldType.MYSQL_TYPE_DOUBLE(0x05)
            case 0x06 => FieldType.MYSQL_TYPE_NULL(0x06)
            case 0x07 => FieldType.MYSQL_TYPE_TIMESTAMP(0x07)
            case 0x08 => FieldType.MYSQL_TYPE_LONGLONG(0x08)
            case 0x09 => FieldType.MYSQL_TYPE_INT24(0x09)
            case 0x0a => FieldType.MYSQL_TYPE_DATE(0x0a)
            case 0x0b => FieldType.MYSQL_TYPE_TIME(0x0b)
            case 0x0c => FieldType.MYSQL_TYPE_DATETIME(0x0c)
            case 0x0d => FieldType.MYSQL_TYPE_YEAR(0x0d)
            case 0x0e => FieldType.MYSQL_TYPE_NEWDATE(0x0e)
            case 0x0f => FieldType.MYSQL_TYPE_VARCHAR(0x0f)
            case 0x10 => FieldType.MYSQL_TYPE_BIT(0x10)
            case 0x11 => FieldType.MYSQL_TYPE_TIMESTAMP2(0x11)
            case 0x12 => FieldType.MYSQL_TYPE_DATETIME2(0x12)
            case 0x13 => FieldType.MYSQL_TYPE_TIME2(0x13)
            case 0xf5 => FieldType.MYSQL_TYPE_JSON(0xf5)
            case 0xf6 => FieldType.MYSQL_TYPE_NEWDECIMAL(0xf6)
            case 0xf7 => FieldType.MYSQL_TYPE_ENUM(0xf7)
            case 0xf8 => FieldType.MYSQL_TYPE_SET(0xf8)
            case 0xf9 => FieldType.MYSQL_TYPE_TINY_BLOB(0xf9)
            case 0xfa => FieldType.MYSQL_TYPE_MEDIUM_BLOB(0xfa)
            case 0xfb => FieldType.MYSQL_TYPE_LONG_BLOB(0xfb)
            case 0xfc => FieldType.MYSQL_TYPE_BLOB(0xfc)
            case 0xfd => FieldType.MYSQL_TYPE_VAR_STRING(0xfd)
            case 0xfe => FieldType.MYSQL_TYPE_STRING(0xfe)
            case 0xff => FieldType.MYSQL_TYPE_GEOMETRY(0xff)
            case _ => FieldType.MYSQL_TYPE_NULL(0x06)
        }
    }
}
