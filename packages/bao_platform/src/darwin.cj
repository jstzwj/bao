// 严格翻译自: src/platform/darwin.zig
// macOS/Darwin 平台特定 API

package bao_platform

// ============================================================================
// nocancel - 不可取消的 libc 函数
// 严格翻译自: darwin.zig:8-30
//   pub const nocancel = struct {
//       pub extern "c" fn @"recvfrom$NOCANCEL"(...) isize;
//       pub extern "c" fn @"sendto$NOCANCEL"(...) isize;
//       ...
//   };
//
// PORT NOTE: macOS 的 $NOCANCEL 变体是为了避免 pthread cancellation point。
// 仓颉中没有直接等价物, 这些函数需要通过 FFI 链接到 C 库。
// ============================================================================

/// macOS 不可取消系统调用
/// 对应 Bun darwin.zig nocancel 命名空间
public class Nocancel {
    /// recvfrom 系统调用 (不可取消版本)
    // 对应 C: recvfrom$NOCANCEL
    public static func recvfrom(sockfd: Int32, buf: CPointer<Unit>, len: UInt64, flags: UInt32): Int64 {
        // PORT NOTE: 需要 FFI 调用 recvfrom$NOCANCEL
        return 0
    }

    /// sendto 系统调用 (不可取消版本)
    // 对应 C: sendto$NOCANCEL
    public static func sendto(sockfd: Int32, buf: CPointer<Unit>, len: UInt64, flags: UInt32): Int64 {
        // PORT NOTE: 需要 FFI 调用 sendto$NOCANCEL
        return 0
    }

    /// connect 系统调用 (不可取消版本)
    // 对应 C: connect$NOCANCEL
    public static func connect(sockfd: Int32): Int32 {
        // PORT NOTE: 需要 FFI 调用 connect$NOCANCEL
        return 0
    }

    /// accept 系统调用 (不可取消版本)
    // 对应 C: accept$NOCANCEL
    public static func accept(sockfd: Int32): Int32 {
        // PORT NOTE: 需要 FFI 调用 accept$NOCANCEL
        return -1
    }

    /// read 系统调用 (不可取消版本)
    // 对应 C: read$NOCANCEL
    public static func read(fd: Int32, buf: CPointer<UInt8>, nbyte: UInt64): Int64 {
        // PORT NOTE: 需要 FFI 调用 read$NOCANCEL
        return 0
    }

    /// write 系统调用 (不可取消版本)
    // 对应 C: write$NOCANCEL
    public static func write(fd: Int32, buf: CPointer<UInt8>, nbyte: UInt64): Int64 {
        // PORT NOTE: 需要 FFI 调用 write$NOCANCEL
        return 0
    }

    /// poll 系统调用 (不可取消版本)
    // 对应 C: poll$NOCANCEL
    public static func poll(fds: CPointer<Unit>, nfds: Int32, timeout: Int32): Int64 {
        // PORT NOTE: 需要 FFI 调用 poll$NOCANCEL
        return 0
    }
}

// ============================================================================
// OSLog - macOS 系统日志
// 严格翻译自: darwin.zig:32-102
//   pub const OSLog = opaque {
//       pub const Category = enum(u8) { ... };
//       pub const Subsystem = struct { ... };
//       pub fn init() ?*OSLog { ... }
//       pub fn signpost(log: *OSLog, name: i32) Signpost { ... }
//       ...
//   };
// ============================================================================

/// OSLog 类别
// 严格翻译自: darwin.zig:33-39
public enum OSLogCategory {
    | PointsOfInterest  // 0
    | Dynamicity        // 1
    | SizeAndThroughput // 2
    | TimeProfile       // 3
    | SystemReporting   // 4
    | UserCustom        // 5

    public operator func == (rhs: OSLogCategory): Bool {
        match (this) {
            case PointsOfInterest => match (rhs) { case PointsOfInterest => true; case _ => false }
            case Dynamicity => match (rhs) { case Dynamicity => true; case _ => false }
            case SizeAndThroughput => match (rhs) { case SizeAndThroughput => true; case _ => false }
            case TimeProfile => match (rhs) { case TimeProfile => true; case _ => false }
            case SystemReporting => match (rhs) { case SystemReporting => true; case _ => false }
            case UserCustom => match (rhs) { case UserCustom => true; case _ => false }
        }
    }
    public operator func != (rhs: OSLogCategory): Bool {
        !(this == rhs)
    }
}

/// OSLog 子系统常量
// 严格翻译自: darwin.zig:43-49
public class OSSubsystem {
    public static let NETWORK = "com.apple.network"
    public static let FILE_IO = "com.apple.disk_io"
    public static let GRAPHICS = "com.apple.graphics"
    public static let MEMORY = "com.apple.memory"
    public static let PERFORMANCE = "com.apple.performance"
}

/// Signpost 类型
// 严格翻译自: darwin.zig:68-72
public enum SignpostType {
    | Event          // 0
    | IntervalBegin  // 1
    | IntervalEnd    // 2

    public operator func == (rhs: SignpostType): Bool {
        match (this) {
            case Event => match (rhs) { case Event => true; case _ => false }
            case IntervalBegin => match (rhs) { case IntervalBegin => true; case _ => false }
            case IntervalEnd => match (rhs) { case IntervalEnd => true; case _ => false }
        }
    }
    public operator func != (rhs: SignpostType): Bool {
        !(this == rhs)
    }
}

/// Signpost - 性能标记
// 严格翻译自: darwin.zig:76-101
public class Signpost {
    public var id: UInt64
    public var name: Int32

    public init(id: UInt64, name: Int32) {
        this.id = id
        this.name = name
    }

    /// 发出事件
    // 严格翻译自: darwin.zig:81-83
    //   pub fn emit(this: *const Signpost, category: Category) void { ... }
    public func emit(category: OSLogCategory): Unit {
        // PORT NOTE: 需要调用 Bun__signpost_emit FFI
    }

    /// 开始时间区间
    // 严格翻译自: darwin.zig:94-99
    public func interval(category: OSLogCategory): SignpostInterval {
        return SignpostInterval(signpost: this, category: category)
    }
}

/// Signpost 时间区间
// 严格翻译自: darwin.zig:85-100
public class SignpostInterval {
    public var signpost: Signpost
    public var category: OSLogCategory

    public init(signpost: Signpost, category: OSLogCategory) {
        this.signpost = signpost
        this.category = category
    }

    /// 结束时间区间
    // 严格翻译自: darwin.zig:89-91
    //   pub fn end(this: *const Interval) void { ... }
    public func end(): Unit {
        // PORT NOTE: 需要调用 Bun__signpost_emit FFI with IntervalEnd
    }
}
