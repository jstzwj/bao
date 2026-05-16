// 严格翻译自: src/sql/shared/ConnectionFlags.zig
// 连接标志位
package bao_sql.shared

/// 连接标志位 (packed struct)
/// 对应 Bun: ConnectionFlags (packed struct)
public class ConnectionFlags {
    public var isReadyForQuery: Bool
    public var isProcessingData: Bool
    public var useUnnamedPreparedStatements: Bool
    public var waitingToPrepare: Bool
    public var hasBackpressure: Bool

    public init() {
        isReadyForQuery = false
        isProcessingData = false
        useUnnamedPreparedStatements = false
        waitingToPrepare = false
        hasBackpressure = false
    }
}
