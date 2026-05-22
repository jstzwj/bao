// 严格翻译自: src/sql_jsc/postgres/Signature.zig
// Postgres 查询签名

package bao_sql_jsc.postgres

import bao_core.*
import bao_jsc.*
import bao_sql_jsc.shared.*
import bao_collections.ArrayList

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
        // Stub: simplified hash
        var h: UInt64 = 0
        for (i in 0..name.size) {
            h = h * 31 + UInt64(Int64(name[Int64(i)]))
        }
        return h
    }

    /// 生成签名
    /// 对应 Bun: Signature.generate
    public static func generate(globalObject: JscJSGlobalObject, query: String,
                                 arrayValue: JscValue, columns: JscValue,
                                 preparedStatementId: UInt64, unnamed: Bool): ?PostgresSignature {
        let sig = PostgresSignature()
        sig.query = query
        sig.name = query

        let iterOpt = QueryBindingIterator.initFunc(arrayValue, columns, globalObject)
        if (iterOpt.isNone()) {
            return None
        }

        var fields = ArrayList<Int32>()
        var nameParts = ArrayList<String>()
        nameParts.append(query)

        var nextValue = iterOpt.getOrThrow().next()
        while (nextValue.isSome()) {
            let value = nextValue.getOrThrow()
            if (value.isEmptyOrUndefinedOrNull()) {
                fields.append(0)
                nameParts.append(".null")
            } else {
                // Stub: would determine tag from JS value
                let tag = PostgresTag.Text
                nameParts.append(".text")
                fields.append(0)
            }
            nextValue = iterOpt.getOrThrow().next()
        }

        if (!unnamed) {
            let maxLen = if (sig.name.size > 40) { 40 } else { sig.name.size }
            sig.preparedStatementName = "P${sig.name[0..maxLen]}$${preparedStatementId}"
        }

        sig.fields = fields.items()
        var nameResult = ""
        for (p in nameParts) {
            nameResult = nameResult + p
        }
        sig.name = nameResult
        return sig
    }
}
