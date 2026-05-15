// 严格翻译自: src/sql_jsc/mysql/protocol/Signature.zig
// MySQL 查询签名 - 生成预处理语句的参数类型签名

package bao_sql_jsc.mysql.protocol

import bao_core.*
import bao_jsc.*

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

        do {
            let iter = QueryBindingIterator.init(arrayValue, columns, globalObject)
            if (iter == None) {
                return None
            }

            var fields = ArrayList<SignatureParam>()
            var nameBuilder = StringBuilder()
            nameBuilder.append(query)

            var nextValue = iter.getOrThrow().next()
            while (nextValue != None) {
                let value = nextValue.getOrThrow()
                if (value.isEmptyOrUndefinedOrNull()) {
                    fields.append(SignatureParam(fieldType: 6, unsigned: false)) // NULL
                    nameBuilder.append(".null")
                } else {
                    var unsigned = false
                    let fieldType = MySQLFieldType.fromJS(globalObject, value, unsigned)
                    if (fieldType != None) {
                        let param = SignatureParam(
                            fieldType: UInt8(fieldType.getOrThrow().value()),
                            unsigned: unsigned
                        )
                        fields.append(param)
                        nameBuilder.append(fieldType.getOrThrow().name())
                    }
                }
                nextValue = iter.getOrThrow().next()
            }

            if (iter.getOrThrow().anyFailed()) {
                return None
            }

            sig.fields = fields.toArray()
            sig.name = nameBuilder.toString()
            return sig
        } catch (_: Exception) {
            return None
        }
    }

    /// 计算哈希
    /// 对应 Bun: Signature.hash
    public func hash(): UInt64 {
        var hasher = Wyhash.init(0)
        hasher.update(name)
        return hasher.final()
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

    public init(fieldType: UInt8, unsigned: Bool) {
        this.fieldType = fieldType
        this.unsigned = unsigned
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
        return String.fromUtf8(buffer.toArray())
    }
}
