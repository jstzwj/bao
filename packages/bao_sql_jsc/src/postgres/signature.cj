// 严格翻译自: src/sql_jsc/postgres/Signature.zig
// Postgres 查询签名

package bao_sql_jsc

import bao_core.*
import bao_jsc.*

/// Postgres 签名
/// 对应 Bun: postgres/Signature.zig
/// 用于标识预处理语句的参数类型组合
public class PostgresSignature {
    public var fields: Array<Int32> = []
    public var name: String = ""
    public var query: String = ""
    public var preparedStatementName: String = ""

    public init() {}

    /// 创建空签名
    public static func empty(): PostgresSignature {
        return PostgresSignature()
    }

    /// 释放资源
    public func deinit(): Unit {
        if (preparedStatementName.size > 0) {
            preparedStatementName = ""
        }
        if (name.size > 0) {
            name = ""
        }
        if (fields.size > 0) {
            fields = []
        }
        if (query.size > 0) {
            query = ""
        }
    }

    /// 计算哈希
    /// 对应 Bun: Signature.hash
    public func hash(): UInt64 {
        var hasher = Wyhash.init(0)
        hasher.update(name)
        return hasher.final()
    }

    /// 生成签名
    /// 对应 Bun: Signature.generate
    public static func generate(globalObject: JscJSGlobalObject, query: String,
                                 arrayValue: JscValue, columns: JscValue,
                                 preparedStatementId: UInt64, unnamed: Bool): ?PostgresSignature {
        let sig = PostgresSignature()
        sig.query = query
        sig.name = query

        do {
            let iter = QueryBindingIterator.init(arrayValue, columns, globalObject)
            if (iter == None) {
                return None
            }

            var fields = ArrayList<Int32>()
            var nameBuilder = StringBuilder()
            nameBuilder.append(query)

            var nextValue = iter.getOrThrow().next()
            while (nextValue != None) {
                let value = nextValue.getOrThrow()
                if (value.isEmptyOrUndefinedOrNull()) {
                    fields.append(0)
                    nameBuilder.append(".null")
                } else {
                    let tag = tagFromJS(globalObject, value)
                    let tagName = tag.name()
                    nameBuilder.append(".${tagName}")

                    match (tag) {
                        case Bool | Int4 | Int8 | Float8 | Int2 | Numeric | Float4 | Bytea =>
                            fields.append(tag.toInt())
                        case _ =>
                            fields.append(0)
                    }
                }
                nextValue = iter.getOrThrow().next()
            }

            if (iter.getOrThrow().anyFailed()) {
                return None
            }

            if (!unnamed) {
                let maxLen = if (sig.name.size > 40) 40 else sig.name.size
                sig.preparedStatementName = "P${sig.name[0..maxLen]}\$${preparedStatementId}"
            }

            sig.fields = fields.toArray()
            return sig
        } catch (_: Exception) {
            return None
        }
    }
}
