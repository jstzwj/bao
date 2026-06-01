// MySQL SSL 模式
// 严格翻译自: src/sql/mysql/SSLMode.zig
package bao_runtime.sql.mysql

/// MySQL SSL 连接模式
/// 对应 Bun: SSLMode (enum u8)
public enum SSLMode {
    | Disable     // 0
    | Prefer      // 1
    | Require     // 2
    | VerifyCA    // 3
    | VerifyFull  // 4
}
