// Valkey 上下文 - 每 VM 的 Valkey 状态
// 严格翻译自: bun/src/runtime/valkey_jsc/ValkeyContext.zig
//   每 VM 的 Valkey 状态。四个缓存的 us_socket_context_t 已经被移除 --
//   连接现在通过 RareData.valkey_group / valkey_tls_group 来关联，
//   默认 TLS SSL_CTX 由 RareData.defaultClientSslCtx() 提供。
package bao_runtime

// ============================================================================
// ValkeyContext - 每 VM 的 Valkey 状态
// 严格翻译自: ValkeyContext.zig
//   pub fn deinit(_: *@This()) void {}
// ============================================================================

/// Valkey 上下文 - 对应 Bun ValkeyContext
/// 原始 Bun 实现中此结构体仅包含一个空的 deinit 方法，
/// 因为 socket context 的缓存已移至 RareData。
public class ValkeyContext {

    public init() {
        // 空初始化 - 原始 Bun 实现中所有缓存的 socket context
        // 已迁移至 RareData.valkey_group / valkey_tls_group
    }

    /// 释放资源
    /// 对应 Bun ValkeyContext.deinit()
    public func deinit(): Unit {
        // 无操作 - 对应原始 Zig 代码中的空实现
    }
}
