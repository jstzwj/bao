// 严格翻译自: src/sql_jsc/postgres/types/tag_jsc.zig
// Postgres Tag JS 转换 - 标签到 JS 值和类型判断

package bao_sql_jsc

import bao_core.*
import bao_jsc.*

/// Tag JS 转换辅助函数
/// 对应 Bun: types/tag_jsc.zig
/// 提供 Tag 到 JS 类型数组的映射和 JS 值推断类型

/// 获取 JS TypedArray 类型
/// 对应 Bun: Tag.toJSTypedArrayType
public func tagToJSTypedArrayType(tag: PostgresTag): ?Int64 {
    return match (tag) {
        case Int4Array => Int64(7)   // Int32Array
        case Float4Array => Int64(9) // Float32Array
        case _ => None
    }
}

/// Tag 到 JS 值的转换
/// 对应 Bun: Tag.toJS
public func tagToJS(tag: PostgresTag, globalObject: JscJSGlobalObject,
                     value: JscValue): JscValue {
    return match (tag) {
        case Numeric => JscValue(value.toNumber(globalObject))
        case Float4 | Float8 => JscValue(value.toNumber(globalObject))
        case Json | Jsonb =>
            PostgresJsonType.toJS(globalObject, value.toArrayBuffer(globalObject).getOrThrow().byteSlice())
        case Bool => JscValue(value.toBoolean())
        case Timestamp | Timestamptz =>
            PostgresDateType.toJS(globalObject, Int64(value.getUnixTimestamp() * 1000))
        case Bytea =>
            PostgresByteaType.toJS(globalObject, value.toArrayBuffer(globalObject).getOrThrow().byteSlice())
        case Int8 => JscValue.fromInt64NoTruncate(globalObject, value.toInt64())
        case Int4 => JscValue(value.toInt32())
        case _ => PostgresStringType.toJS(globalObject, value.toBunString(globalObject))
    }
}

/// 从 JS 值推断 Tag
/// 对应 Bun: Tag.fromJS
public func tagFromJS(globalObject: JscJSGlobalObject, value: JscValue): PostgresTag {
    if (value.isEmptyOrUndefinedOrNull()) {
        return PostgresTag.Numeric
    }

    if (value.isString()) {
        return PostgresTag.Text
    }
    if (value.isDate()) {
        return PostgresTag.Timestamptz
    }
    if (value.isTypedArrayOrArrayBuffer()) {
        return PostgresTag.Bytea
    }
    if (value.isInt32()) {
        return PostgresTag.Int4
    }
    if (value.isAnyInt()) {
        let int_ = value.toInt64()
        if (int_ >= Int64(Int32.MinValue) && int_ <= Int64(Int32.MaxValue)) {
            return PostgresTag.Int4
        }
        return PostgresTag.Int8
    }
    if (value.isNumber()) {
        return PostgresTag.Float8
    }
    if (value.isBoolean()) {
        return PostgresTag.Bool
    }

    return PostgresTag.Numeric
}
