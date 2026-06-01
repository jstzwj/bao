// bao_spawn_sys - spawn_process_posix + 选项/结果类型
// Simplified for Cangjie compatibility
package bao_spawn_sys

import bao_core.*
import bao_sys.*
import bao_collections.*

/// PID 类型
public type SpawnPidT = Int32

/// 文件描述符类型
public type FdT = Int32

/// pidfd 类型
public type PidFdType = Int32

/// Unix rusage 结构体
public struct Rusage {
    public var ruMaxrss: Int64 = Int64(0)
    public init() {}
}

/// Windows timeval
public struct WinTimeval {
    public var sec: Int64 = Int64(0)
    public var usec: Int64 = Int64(0)
    public init() {}
}

/// Windows Rusage
public struct WinRusage {
    public var utime: WinTimeval = WinTimeval()
    public var stime: WinTimeval = WinTimeval()
    public init() {}
}

/// rusage_zeroed
public func rusageZeroed(): Rusage { Rusage() }

/// 文件操作类型
public enum FileActionType {
    | None
    | Open
    | Close
    | Dup2
}

/// 单个文件操作
public struct SpawnAction {
    public var kind: FileActionType = FileActionType.None
    public init() {}
}

/// O 标志常量
public class OFlags {
    public static let RDONLY: UInt32 = UInt32(0)
    public static let WRONLY: UInt32 = UInt32(1)
    public static let RDWR: UInt32 = UInt32(2)
}

/// 标准流类型
public enum StdioKind {
    | Stdin
    | Stdout
    | Stderr
}

/// PosixStdio - simplified
public enum PosixStdio {
    | Inherit
    | Ignore
    | Buffer
}

/// Dup2 structure
public struct Dup2 {
    public var out: StdioKind = StdioKind.Stdin
    public var to: StdioKind = StdioKind.Stdout
    public init() {}
}

/// ActionsList
public struct ActionsList {
    public var ptr: CPointer<SpawnAction>
    public var len: Int64
    public init() {
        ptr = CPointer<SpawnAction>()
        len = 0
    }
    public init(ptr: CPointer<SpawnAction>, len: Int64) {
        this.ptr = ptr
        this.len = len
    }
}

/// BunSpawnRequest
public struct BunSpawnRequest {
    public var actions: ActionsList = ActionsList()
    public var chdirBuf: CPointer<UInt8> = CPointer<UInt8>()
    public var detached: Bool = false
    public init() {}
}

/// Spawn options
public class SpawnOptions {
    public var cwd: String = ""
    public var env: HashMap<String, String> = HashMap<String, String>()
    public var argv: Array<String> = []
    public init() {}
}

/// SysError
public struct SysError {
    public var errno: UInt16 = UInt16(0)
    public var syscall: String = ""
    public init(errno: UInt16, syscall: String) {
        this.errno = errno
        this.syscall = syscall
    }
}

/// SysMaybe

/// Pdeathsig helper

/// Environment constants

/// WaiterThreadFlag

/// Spawn entry point
public func spawnProcess(path: String, argv: Array<String>, env: Array<String>): SysMaybe<Int32> {
    return SysMaybe<Int32>.Ok(Int32(0))
}
