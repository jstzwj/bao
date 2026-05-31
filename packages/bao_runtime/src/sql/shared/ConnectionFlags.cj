// SQL 共享连接标志
// 严格翻译自: src/sql/shared/ConnectionFlags.zig
package bao_runtime.sql.shared

/// SQL 连接内部标志
/// 对应 Bun: ConnectionFlags (packed struct)
public class ConnectionFlags {
    /// 是否准备好接收查询
    public var isReadyForQuery: Bool
    /// 是否正在处理数据
    public var isProcessingData: Bool
    /// 是否使用无名预编译语句
    public var useUnnamedPreparedStatements: Bool
    /// 是否等待预编译
    public var waitingToPrepare: Bool
    /// 是否有背压
    public var hasBackpressure: Bool

    public init() {
        isReadyForQuery = false
        isProcessingData = false
        useUnnamedPreparedStatements = false
        waitingToPrepare = false
        hasBackpressure = false
    }
}
