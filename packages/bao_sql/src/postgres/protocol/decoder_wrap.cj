// 严格翻译自: src/sql/postgres/protocol/DecoderWrap.zig
// PostgreSQL 协议解码器包装
package bao_sql.postgres.protocol


/// 解码器包装器 - 用于包装协议消息的解码函数
/// 对应 Bun: DecoderWrap (generic type)
public class DecoderWrap<T> {
    /// 解码消息
    /// 对应 Bun: DecoderWrap.decode
    public static func decode(target: T, context: Any): AnyPostgresError {
        // 在具体实现中，这会调用实际的解码函数
        // 使用 NewReader 包装 context 进行读取
        return AnyPostgresError.ConnectionClosed
    }
}
