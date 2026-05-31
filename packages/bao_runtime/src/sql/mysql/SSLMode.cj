// MySQL SSL 模式
// 严格翻译自: src/sql/mysql/SSLMode.zig
package bao_runtime.sql.mysql

/// MySQL SSL 连接模式
/// 对应 Bun: SSLMode (enum u8)
public enum SSLMode <: UInt8 {
    | disable(0)
    | prefer(1)
    | require(2)
    | verify_ca(3)
    | verify_full(4)
}
