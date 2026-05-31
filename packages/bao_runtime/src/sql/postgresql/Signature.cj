// PostgreSQL 预处理语句签名 JSC 绑定
// 严格翻译自: bun/src/sql_jsc/postgres/Signature.zig
//   const Signature = @This();
//   fields: []const int4, name: []const u8, query: []const u8, prepared_statement_name: []const u8
package bao_runtime.sql.postgresql


/// 预处理语句签名
/// 对应 Bun Signature
/// 用于标识一个预处理语句的参数类型和查询文本
/// 签名由查询文本 + 参数类型组成，用于缓存和复用预处理语句
public class PGSignature {
    /// 参数字段类型列表 (PostgreSQL 类型 OID)
    public var fields: Array<UInt32>
    /// 签名名称 (查询文本 + 参数类型后缀)
    public var name: String
    /// 原始查询文本
    public var query: String
    /// 预处理语句名称 (发送给 PostgreSQL 的名称)
    public var preparedStatementName: String

    public init() {
        fields = Array<UInt32>()
        name = ""
        query = ""
        preparedStatementName = ""
    }

    public init(fields: Array<UInt32>, name: String, query: String, preparedStatementName: String) {
        this.fields = fields
        this.name = name
        this.query = query
        this.preparedStatementName = preparedStatementName
    }

    /// 创建空签名
    /// 对应 Bun Signature.empty()
    public static func empty(): PGSignature {
        PGSignature()
    }

    /// 计算签名哈希
    /// 对应 Bun Signature.hash()
    public func hash(): UInt64 {
        // 使用 Wyhash 对 name + fields 进行哈希
        // 简化实现使用 FNV-1a
        var h = UInt64(14695981039346656037)
        for (c in name) {
            h = h ^ UInt64(c)
            h = h * UInt64(1099511628211)
        }
        for (f in fields) {
            h = h ^ UInt64(f)
            h = h * UInt64(1099511628211)
        }
        return h
    }

    /// 从 JS 值生成签名
    /// 对应 Bun Signature.generate()
    ///
    /// 参数:
    ///   query - 查询文本
    ///   bindings - 绑定参数数组 (来自 JS)
    ///   columns - 列信息 (来自 JS, 可能为 undefined)
    ///   preparedStatementId - 递增的语句 ID
    ///   unnamed - 是否为无名预处理语句
    public static func generate(
        query: String,
        bindings: Array<PGTag>,
        preparedStatementId: UInt64,
        unnamed: Bool
    ): PGSignature {
        let fields = Array<UInt32>()
        var nameBuilder = query

        for (tag in bindings) {
            // 追加类型后缀到名称
            let suffix = tagToSuffix(tag)
            nameBuilder = nameBuilder + suffix

            // 决定是否由客户端指定类型
            match (tag) {
                case PGTag.Bool | PGTag.Int4 | PGTag.Int8 |
                     PGTag.Float8 | PGTag.Int2 | PGTag.Numeric |
                     PGTag.Float4 | PGTag.Bytea => {
                    // 客户端指定类型
                    fields.append(UInt32(tag.toInt()))
                }
                case _ => {
                    // 让 PostgreSQL 决定类型
                    fields.append(0)
                }
            }
        }

        // 生成预处理语句名称
        let stmtName = if (unnamed) {
            ""
        } else {
            let prefix = if (nameBuilder.size > 40) {
                nameBuilder.substring(0, 40)
            } else {
                nameBuilder
            }
            "P${prefix}$${preparedStatementId}"
        }

        return PGSignature(fields, nameBuilder, query, stmtName)
    }

    /// 释放资源
    /// 对应 Bun Signature.deinit()
    public func deinit() {
        fields = Array<UInt32>()
        name = ""
        query = ""
        preparedStatementName = ""
    }

    // ========================================================================
    // 私有辅助
    // ========================================================================

    private static func tagToSuffix(tag: PGTag): String {
        match (tag) {
            case PGTag.Int8 => ".int8"
            case PGTag.Int4 => ".int4"
            case PGTag.Int2 => ".int2"
            case PGTag.Float8 => ".float8"
            case PGTag.Float4 => ".float4"
            case PGTag.Numeric => ".numeric"
            case PGTag.JSON | PGTag.JSONB => ".json"
            case PGTag.Bool => ".bool"
            case PGTag.Timestamp => ".timestamp"
            case PGTag.Timestamptz => ".timestamptz"
            case PGTag.Bytea => ".bytea"
            case _ => ".string"
        }
    }
}
