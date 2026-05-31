// PostgreSQL 协议常量 - 固定消息字节
// 严格翻译自: bun/src/sql/postgres/PostgresProtocol.zig 中的常量部分
//   pub const CloseComplete = [_]u8{'3'} ++ toBytes(Int32(4));
//   pub const BindComplete = [_]u8{'2'} ++ toBytes(Int32(4));
//   etc.
package bao_runtime.sql.postgresql


// ============================================================================
// 固定消息字节 - 这些消息有固定格式，不需要参数
// 对应 Bun PostgresProtocol 中的常量
// ============================================================================

/// CloseComplete ('3') - 关闭完成响应
public let CLOSE_COMPLETE: Array<UInt8> = [51, 0, 0, 0, 4]  // '3' + length(4)

/// EmptyQueryResponse ('I') - 空查询响应
public let EMPTY_QUERY_RESPONSE: Array<UInt8> = [73, 0, 0, 0, 4]  // 'I' + length(4)

/// Terminate ('X') - 终止连接
public let TERMINATE: Array<UInt8> = [88, 0, 0, 0, 4]  // 'X' + length(4)

/// BindComplete ('2') - 绑定完成响应
public let BIND_COMPLETE: Array<UInt8> = [50, 0, 0, 0, 4]  // '2' + length(4)

/// ParseComplete ('1') - 解析完成响应
public let PARSE_COMPLETE: Array<UInt8> = [49, 0, 0, 0, 4]  // '1' + length(4)

/// CopyDone ('c') - 复制完成
public let COPY_DONE: Array<UInt8> = [99, 0, 0, 0, 4]  // 'c' + length(4)

/// Sync ('S') - 同步消息
public let SYNC: Array<UInt8> = [83, 0, 0, 0, 4]  // 'S' + length(4)

/// Flush ('H') - 刷新消息
public let FLUSH: Array<UInt8> = [72, 0, 0, 0, 4]  // 'H' + length(4)

/// NoData ('n') - 无数据响应
public let NO_DATA: Array<UInt8> = [110, 0, 0, 0, 4]  // 'n' + length(4)

/// SSLRequest - SSL 请求消息
/// 8 字节: length(8) + SSL request code (80877103)
public let SSL_REQUEST: Array<UInt8> = [
    0x00, 0x00, 0x00, 0x08,  // Length: 8
    0x04, 0xD2, 0x16, 0x2F   // SSL request code: 80877103
]

/// DataRow 中的 NULL 值标记
/// 对应 Bun DataRow.null_int4 (4294967295)
public let NULL_INT4: Int32 = -1

// ============================================================================
// 消息类型字节常量
// ============================================================================

/// 消息类型标识字节
public enum MessageType: UInt8 {
    // 后端消息 (服务器 -> 客户端)
    case Authentication = 82       // 'R'
    case BackendKeyData = 75       // 'K'
    case BindComplete = 50         // '2'
    case CloseComplete = 51        // '3'
    case CommandComplete = 67      // 'C'
    case CopyData = 100            // 'd'
    case CopyDone = 99             // 'c'
    case CopyInResponse = 71       // 'G'
    case CopyOutResponse = 72      // 'H'
    case CopyBothResponse = 87     // 'W'
    case DataRow = 68              // 'D'
    case EmptyQueryResponse = 73   // 'I'
    case ErrorResponse = 69        // 'E'
    case FunctionCallResponse = 86 // 'V'
    case NoData = 110              // 'n'
    case NoticeResponse = 78       // 'N'
    case NotificationResponse = 65 // 'A'
    case ParameterDescription = 116 // 't'
    case ParameterStatus = 83      // 'S'
    case ParseComplete = 49        // '1'
    case PortalSuspended = 115     // 's'
    case ReadyForQuery = 90        // 'Z'
    case RowDescription = 84       // 'T'

    // 前端消息 (客户端 -> 服务器)
    case Bind = 66                 // 'B'
    case Close = 67                // 'C'
    case Describe = 68             // 'D'
    case Execute = 69              // 'E'
    case Flush = 72                // 'H'
    case FunctionCall = 70         // 'F'
    case Parse = 80                // 'P'
    case PasswordMessage = 112     // 'p'
    case Query = 81                // 'Q'
    case SSLRequest = 0            // 特殊: 不是单字节标识
    case StartupMessage = 0        // 特殊: 无类型字节前缀
    case Sync = 83                 // 'S'
    case Terminate = 88            // 'X'

    /// 从字节值获取消息类型
    public static func fromByte(b: UInt8): ?MessageType {
        match (b) {
            case 82 => Some(Authentication)       // 'R'
            case 75 => Some(BackendKeyData)       // 'K'
            case 50 => Some(BindComplete)         // '2'
            case 51 => Some(CloseComplete)        // '3'
            case 67 => Some(CommandComplete)      // 'C'
            case 100 => Some(CopyData)            // 'd'
            case 99 => Some(CopyDone)             // 'c'
            case 71 => Some(CopyInResponse)       // 'G'
            case 72 => Some(CopyOutResponse)      // 'H'
            case 87 => Some(CopyBothResponse)     // 'W'
            case 68 => Some(DataRow)              // 'D'
            case 73 => Some(EmptyQueryResponse)   // 'I'
            case 69 => Some(ErrorResponse)        // 'E'
            case 110 => Some(NoData)              // 'n'
            case 78 => Some(NoticeResponse)       // 'N'
            case 65 => Some(NotificationResponse) // 'A'
            case 116 => Some(ParameterDescription)// 't'
            case 83 => Some(ParameterStatus)      // 'S' (注意: 与 Sync 相同)
            case 49 => Some(ParseComplete)        // '1'
            case 115 => Some(PortalSuspended)     // 's'
            case 90 => Some(ReadyForQuery)        // 'Z'
            case 84 => Some(RowDescription)       // 'T'
            case _ => None
        }
    }
}
