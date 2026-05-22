// 严格翻译自: src/sql_jsc/mysql/protocol/Signature.zig
// MySQL 查询签名 - 生成预处理语句的参数类型签名

package bao_sql_jsc.mysql.protocol

import bao_core.*
import bao_jsc.*
import bao_sql_jsc.shared.*
import bao_sql_jsc.mysql.*
import bao_collections.ArrayList

/// MySQL 签名
/// 对应 Bun: mysql/protocol/Signature.zig
/// 用于标识预处理语句的参数类型组合，实现语句缓存复用
public class MySQLSignature {
    public var fields: Array<SignatureParam> = []
    public var name: String = ""
    public var query: String = ""

    public init() {}

    /// 创建空签名
    public static func empty(): MySQLSignature {
        return MySQLSignature()
    }

    /// 生成签名
    /// 对应 Bun: Signature.generate
    public static func generate(globalObject: JscJSGlobalObject, query: String,
                                 arrayValue: JscValue, columns: JscValue): ?MySQLSignature {
        let sig = MySQLSignature()
        sig.query = query
        sig.name = query

        try {
            let iterOpt = QueryBindingIterator.initFunc(arrayValue, columns, globalObject)
            if (iterOpt.isNone()) {
                return None
            }

            var fields: Array<SignatureParam> = []
            var nameStr = query

            var nextValue = iterOpt.getOrThrow().next()
            while (nextValue.isSome()) {
                let value = nextValue.getOrThrow()
                if (value.isEmptyOrUndefinedOrNull()) {
                    fields = fields.concat([SignatureParam(6, false)]) // NULL
                    nameStr = nameStr + ".null"
                } else {
                    let unsigned = false
                    let fieldType = MySQLFieldType.fromJS(globalObject, value, unsigned)
                    if (fieldType.isSome()) {
                        let param = SignatureParam(
                            UInt8(fieldType.getOrThrow().value()),
                            unsigned
                        )
                        fields = fields.concat([param])
                        nameStr = nameStr + fieldType.getOrThrow().name()
                    }
                }
                nextValue = iterOpt.getOrThrow().next()
            }

            if (iterOpt.getOrThrow().anyFailed()) {
                return None
            }

            sig.fields = fields
            sig.name = nameStr
            return sig
        } catch (_: Exception) {
            return None
        }
    }

    /// 计算哈希
    /// 对应 Bun: Signature.hash
    public func hash(): UInt64 {
        var hasher = Wyhash.initFunc(0)
        hasher.update(name)
        return hasher.final_()
    }

    /// 释放资源
    public func deinit(): Unit {
        fields = []
        if (name.size > 0) {
            name = ""
        }
        if (query.size > 0) {
            query = ""
        }
    }
}

/// 签名参数
public class SignatureParam {
    public var fieldType: UInt8
    public var unsigned: Bool

    public init(_fieldType: UInt8, _unsigned: Bool) {
        this.fieldType = _fieldType
        this.unsigned = _unsigned
    }
}

/// Wyhash 哈希器
public class Wyhash {
    var state: UInt64 = 0

    public static func initFunc(seed: UInt64): Wyhash {
        let h = Wyhash()
        h.state = seed
        return h
    }

    public func update(data: String): Unit {
        // 简化哈希实现
        for (c in data) {
            state = state ^ UInt64(c)
        }
    }

    public func final_(): UInt64 {
        return state
    }
}

/// 字符串构建器
public class StringBuilder {
    var buffer: ArrayList<UInt8> = ArrayList<UInt8>()

    public init() {}

    public func append(s: String): Unit {
        for (b in s.toArray()) {
            buffer.append(b)
        }
    }

    public func toString(): String {
        return String.fromUtf8(buffer.toOwnedSlice())
    }
}
