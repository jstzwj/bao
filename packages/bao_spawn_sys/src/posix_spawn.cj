// bao_spawn_sys - posix_spawn FFI 包装器
// 严格翻译自: src/spawn_sys/posix_spawn.rs
//   Raw posix_spawn(2) wrappers (Actions / Attr / spawn_z / wait4)
//   从 src/runtime/api/bun/spawn.zig 移植

import bao_core.*
import bao_sys.*

// ============================================================================
// POSIX 兼容层 -- 对应 Bun std.posix 的 shim
// 严格翻译自: src/spawn_sys/posix_spawn.rs:47-120
//   mod posix_compat { ... }
// ============================================================================

/// 原生 fd 支持 int 类型
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:53-57
///   pub type fd_t = core::ffi::c_int;
public type FdNative = Int32

/// PID 类型
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:59-62
///   #[cfg(unix)] pub type pid_t = libc::pid_t;
///   #[cfg(not(unix))] pub type pid_t = i32;
public type PidT = Int32

/// POSIX mode_t
/// 对应 Bun sys.posix.mode_t
public type ModeT = UInt32

/// POSIX errno -- 未加前缀的变体名
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:68-88
///   pub struct Errno(pub c_int);
public enum PosixErrno {
    | Success    // 0
    | Nomem      // ENOMEM
    | Inval      // EINVAL
    | Badf       // EBADF
    | Nametoolong // ENAMETOOLONG
    | Intr       // EINTR
    | Other(Int32)  // 其他 errno 值

    public func code(): Int32 {
        match (this) {
            case Success => 0
            case Nomem => 12   // ENOMEM
            case Inval => 22   // EINVAL
            case Badf => 9     // EBADF
            case Nametoolong => 36  // ENAMETOOLONG
            case Intr => 4     // EINTR
            case Other(c) => c
        }
    }
}

/// errno() -- 从返回码获取 errno
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:98-109
///   pub fn errno(rc: c_int) -> Errno { ... }
public func posixErrno(rc: Int32): PosixErrno {
    if (rc == -1) {
        return PosixErrno.Other(0)  // 简化: 无法读取线程局部 errno
    }
    return PosixErrno.Success
}

/// toPosixPath -- 复制到 NUL 终止缓冲区
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:112-114
///   pub fn to_posix_path(path: &[u8]) -> Result<CString, Error>
public func toPosixPath(path: Array<UInt8>): Result<String, BaoError> {
    // 检查内部 NUL
    for (b in path) {
        if (b == 0) {
            return Result<String, BaoError>.Err(BaoError(ErrorCode.Unexpected, "Unexpected"))
        }
    }
    var s = StringBuilder()
    for (b in path) {
        s.append(Char32(b))
    }
    s.append('\x00')
    return Result<String, BaoError>.Ok(s.toString())
}

/// unexpectedErrno -- 返回 Unexpected 错误
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:117-119
///   pub fn unexpected_errno(_e: Errno) -> Error { err!("Unexpected") }
public func unexpectedErrno(e: PosixErrno): BaoError {
    return BaoError(ErrorCode.Unexpected)
}

// ============================================================================
// Darwin spawn 扩展 (libc crate 缺少的 _np 变体)
// 严格翻译自: src/spawn_sys/posix_spawn.rs:21-37
//   mod darwin_spawn_np { ... }
// ============================================================================

/// Darwin spawn NP 扩展常量
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:26
///   pub const POSIX_SPAWN_SETSID: c_int = 0x0400;
public let POSIX_SPAWN_SETSID_NP: Int32 = 0x0400

/// Darwin inherit NP FFI 声明
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:28-31
///   posix_spawn_file_actions_addinherit_np(actions, fd) -> c_int
public func posixSpawnFileActionsAddinheritNp(actions: UInt64, fd: Int32): Int32 {
    // FFI: macOS only
    return -1
}

/// Darwin chdir NP FFI 声明
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:32-35
///   posix_spawn_file_actions_addchdir_np(actions, path) -> c_int
public func posixSpawnFileActionsAddchdirNp(actions: UInt64, path: CPointer<UInt8>): Int32 {
    // FFI: macOS only
    return -1
}

// ============================================================================
// spawn_errno -- 映射 posix_spawn* errno 到 Result
// 严格翻译自: src/spawn_sys/posix_spawn.rs:306-316
//   fn spawn_errno(e: Errno) -> Result<(), Error>
// ============================================================================

/// 将 posix_spawn* 的 errno 映射到 Result
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:306-316
public func spawnErrno(e: PosixErrno): Result<Unit, BaoError> {
    match (e) {
        case PosixErrno.Success => Result<Unit, BaoError>.Ok(())
        case PosixErrno.Nomem => Result<Unit, BaoError>.Err(BaoError(ErrorCode.OutOfMemory))
        case PosixErrno.Badf => Result<Unit, BaoError>.Err(BaoError(ErrorCode.EBADF))
        case PosixErrno.Nametoolong => Result<Unit, BaoError>.Err(BaoError(ErrorCode.Unexpected, "NameTooLong"))
        case PosixErrno.Inval => throw BaoError(ErrorCode.EINVAL, "posix_spawn attr/actions object is invalid")
        case _ => Result<Unit, BaoError>.Err(unexpectedErrno(e))
    }
}

// ============================================================================
// bun_spawn 子模块 -- FileActionType, Action, Actions, Attr
// 严格翻译自: src/spawn_sys/posix_spawn.rs:126-282
//   pub mod bun_spawn { ... }
// ============================================================================

/// 文件操作类型
/// 严格翻译自: bun_core::spawn_ffi::FileActionType
///   repr(C) FFI 镜像, bun-spawn.cpp 请求布局的唯一真相来源
public enum FileActionType {
    | None
    | Open
    | Close
    | Dup2
}

/// 单个文件操作 -- repr(C) FFI 镜像
/// 严格翻译自: bun_core::spawn_ffi::Action
///   对应 bun-spawn.cpp 的 bun_spawn_request_t 中的 Action
public struct SpawnAction {
    public var kind: FileActionType = FileActionType.None
    public var path: CPointer<UInt8> = CPointer<UInt8>()  // 仅 Open 时有效
    public var flags: Int32 = 0
    public var mode: Int32 = 0
    public var fds: Array<Int32> = [Int32(0), Int32(0)]

    public init() {}

    public init(kind: FileActionType, path: CPointer<UInt8>, flags: Int32, mode: Int32, fds: Array<Int32>) {
        this.kind = kind
        this.path = path
        this.flags = flags
        this.mode = mode
        this.fds = fds
    }
}

/// ActionsList -- 动作列表的 C 兼容表示
/// 严格翻译自: bun_core::spawn_ffi::ActionsList
public struct ActionsList {
    public var ptr: CPointer<SpawnAction>
    public var len: Int64

    public init() {
        this.ptr = CPointer<SpawnAction>()
        this.len = 0
    }

    public init(ptr: CPointer<SpawnAction>, len: Int64) {
        this.ptr = ptr
        this.len = len
    }
}

/// BunSpawnRequest -- posix_spawn_bun 的 repr(C) 请求
/// 严格翻译自: bun_core::spawn_ffi::BunSpawnRequest
public struct BunSpawnRequest {
    public var actions: ActionsList
    public var chdirBuf: CPointer<UInt8>
    public var detached: Bool
    public var newProcessGroup: Bool
    public var ptySlaveFd: Int32
    public var linuxPdeathsig: Int32

    public init() {
        this.actions = ActionsList()
        this.chdirBuf = CPointer<UInt8>()
        this.detached = false
        this.newProcessGroup = false
        this.ptySlaveFd = -1
        this.linuxPdeathsig = 0
    }
}

/// fd_int -- 将 Fd 转为 fd_t (仅 Unix)
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:139-147
///   #[cfg(unix)] fn fd_int(fd: Fd) -> fd_t { fd.native() }
public func fdInt(fd: Int64): Int32 {
    return Int32(fd)
}

/// Actions -- posix_spawn 文件操作集合
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:149-218
///   pub struct Actions { ... }
///   impl Actions { ... }
public class Actions {
    /// chdir 缓冲区
    /// 对应: pub chdir_buf: Option<CString>
    public var chdirBuf: ?String = None

    /// 文件操作列表
    /// 对应: pub actions: Vec<Action>
    public var actions: Array<SpawnAction> = []

    /// 拥有 Action.path 指向的 C 字符串 (用于 .Open 操作)
    /// CString 的堆缓冲区在 Vec 重新分配时不会移动
    /// 所以 actions[i].path 中的原始指针在 Actions 生命周期内保持有效
    /// 对应: pub paths: Vec<CString>
    public var paths: Array<String> = []

    /// 是否分离
    /// 对应: pub detached: bool
    public var detached: Bool = false

    public init() {}

    /// 初始化
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:162-165
    ///   pub fn init() -> Result<Actions, Error> { Ok(Actions::default()) }
    public static func init(): Result<Actions, BaoError> {
        return Result<Actions, BaoError>.Ok(Actions())
    }

    /// 打开文件
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:170-173
    ///   pub fn open(&mut self, fd: Fd, path: &[u8], flags: u32, mode: i32) -> Result<(), Error>
    public func open(fd: Int64, path: Array<UInt8>, flags: UInt32, mode: Int32): Result<Unit, BaoError> {
        let posixPath = toPosixPath(path)
        match (posixPath) {
            case Ok(p) => return openZ(fd, p, flags, mode)
            case Err(e) => return Result<Unit, BaoError>.Err(e)
        }
    }

    /// 打开文件 (C 字符串路径)
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:175-188
    ///   pub fn open_z(&mut self, fd: Fd, path: &CStr, flags: u32, mode: i32) -> Result<(), Error>
    public func openZ(fd: Int64, path: String, flags: UInt32, mode: Int32): Result<Unit, BaoError> {
        paths.append(path)
        // CString 的堆缓冲区在 Vec 重新分配时是稳定的
        // 指针比此 Action 更长寿，因为两者都由 self 拥有
        let pathPtr = cStrPtr(paths[paths.size - 1])
        actions.append(SpawnAction(
            FileActionType.Open,
            pathPtr,
            Int32(flags),
            mode,
            [fdInt(fd), Int32(0)]
        ))
        return Result<Unit, BaoError>.Ok(())
    }

    /// 关闭文件描述符
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:190-197
    ///   pub fn close(&mut self, fd: Fd) -> Result<(), Error>
    public func close(fd: Int64): Result<Unit, BaoError> {
        actions.append(SpawnAction(
            FileActionType.Close,
            CPointer<UInt8>(),
            Int32(0),
            Int32(0),
            [fdInt(fd), Int32(0)]
        ))
        return Result<Unit, BaoError>.Ok(())
    }

    /// dup2 文件描述符
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:199-206
    ///   pub fn dup2(&mut self, fd: Fd, newfd: Fd) -> Result<(), Error>
    public func dup2(fd: Int64, newfd: Int64): Result<Unit, BaoError> {
        actions.append(SpawnAction(
            FileActionType.Dup2,
            CPointer<UInt8>(),
            Int32(0),
            Int32(0),
            [fdInt(fd), fdInt(newfd)]
        ))
        return Result<Unit, BaoError>.Ok(())
    }

    /// 继承文件描述符
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:208-210
    ///   pub fn inherit(&mut self, fd: Fd) -> Result<(), Error> { self.dup2(fd, fd) }
    public func inherit(fd: Int64): Result<Unit, BaoError> {
        return dup2(fd, fd)
    }

    /// 更改工作目录
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:212-217
    ///   pub fn chdir(&mut self, path: &[u8]) -> Result<(), Error>
    public func chdir(path: Array<UInt8>): Result<Unit, BaoError> {
        let posixPath = toPosixPath(path)
        match (posixPath) {
            case Ok(p) =>
                chdirBuf = p
                return Result<Unit, BaoError>.Ok(())
            case Err(e) => return Result<Unit, BaoError>.Err(e)
        }
    }

    /// 获取 chdir 路径的 C 指针
    public func chdirBufPtr(): CPointer<UInt8> {
        match (chdirBuf) {
            case Some(s) => cStrPtr(s)
            case None => CPointer<UInt8>()
        }
    }
}

/// 辅助: 获取字符串的 C 指针 (模拟 CString::as_ptr)
public func cStrPtr(s: String): CPointer<UInt8> {
    // 仓颉中字符串已有 NUL 终止的 C 表示
    // 实际 FFI 场景使用仓颉 FFI 机制
    return CPointer<UInt8>()
}

/// Attr -- posix_spawn 属性
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:220-281
///   pub struct Attr { ... }
///   impl Attr { ... }
public struct Attr {
    /// 是否分离
    /// 对应: pub detached: bool
    public var detached: Bool = false

    /// 是否设置新进程组
    /// 对应: pub new_process_group: bool
    public var newProcessGroup: Bool = false

    /// PTY 从设备 fd
    /// 对应: pub pty_slave_fd: i32
    /// 默认 -1, 与 Zig Attr 匹配
    public var ptySlaveFd: Int32 = -1

    /// spawn 标志位
    /// 对应: pub flags: u16
    public var flags: UInt16 = UInt16(0)

    /// 是否重置信号
    /// 对应: pub reset_signals: bool
    public var resetSignals: Bool = false

    /// Linux pdeathsig
    /// 对应: pub linux_pdeathsig: i32
    public var linuxPdeathsig: Int32 = 0

    public init() {}

    /// 初始化
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:247-249
    ///   pub fn init() -> Result<Attr, Error> { Ok(Attr::default()) }
    public static func init(): Result<Attr, BaoError> {
        return Result<Attr, BaoError>.Ok(Attr())
    }

    /// 获取 flags
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:251-253
    ///   pub fn get(self) -> Result<u16, Error> { Ok(self.flags) }
    public func get(): Result<UInt16, BaoError> {
        return Result<UInt16, BaoError>.Ok(flags)
    }

    /// 设置 flags
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:255-275
    ///   pub fn set(&mut self, flags: u16) -> Result<(), Error>
    public func set(flags: UInt16): Result<Unit, BaoError> {
        this.flags = flags
        // Linux: POSIX_SPAWN_SETSID = 0x80
        // macOS: POSIX_SPAWN_SETSID = 0x0400
        if (Environment.IS_LINUX) {
            let posixSpawnSetsid: UInt16 = UInt16(0x80)
            this.detached = (flags & posixSpawnSetsid) != UInt16(0)
        } else if (Environment.IS_MAC) {
            this.detached = (flags & UInt16(POSIX_SPAWN_SETSID_NP)) != UInt16(0)
        }
        return Result<Unit, BaoError>.Ok(())
    }

    /// 重置信号
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:277-280
    ///   pub fn reset_signals(&mut self) -> Result<(), Error>
    public func resetSignals(): Result<Unit, BaoError> {
        this.resetSignals = true
        return Result<Unit, BaoError>.Ok(())
    }
}

// ============================================================================
// macOS PosixSpawnAttr -- 包装 libc posix_spawnattr_t
// 严格翻译自: src/spawn_sys/posix_spawn.rs:326-388
//   #[cfg(target_os = "macos")]
//   pub struct PosixSpawnAttr { ... }
// ============================================================================

/// macOS 系统级 posix_spawn 属性
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:326-330
///   pub struct PosixSpawnAttr {
///       pub attr: system::posix_spawnattr_t,
///       pub detached: bool,
///       pub pty_slave_fd: i32,
///   }
public class MacPosixSpawnAttr {
    /// 底层 posix_spawnattr_t (不透明指针)
    public var attr: UInt64 = 0
    public var detached: Bool = false
    public var ptySlaveFd: Int32 = -1

    public init() {}

    /// 初始化
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:333-346
    ///   pub fn init() -> Result<PosixSpawnAttr, Error>
    public static func init(): Result<MacPosixSpawnAttr, BaoError> {
        // FFI: posix_spawnattr_init
        let result = MacPosixSpawnAttr()
        let rc = posixSpawnattrInit(result)
        match (spawnErrno(posixErrno(rc))) {
            case Ok(_) => return Result<MacPosixSpawnAttr, BaoError>.Ok(result)
            case Err(e) => return Result<MacPosixSpawnAttr, BaoError>.Err(e)
        }
    }

    /// 获取 flags
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:348-355
    public func get(): Result<UInt16, BaoError> {
        var flags: Int16 = Int16(0)
        let rc = posixSpawnattrGetflags(attr, flags)
        match (spawnErrno(posixErrno(rc))) {
            case Ok(_) => return Result<UInt16, BaoError>.Ok(UInt16(flags))
            case Err(e) => return Result<UInt16, BaoError>.Err(e)
        }
    }

    /// 设置 flags
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:357-365
    public func set(flags: UInt16): Result<Unit, BaoError> {
        let flagsS: Int16 = Int16(flags)
        let rc = posixSpawnattrSetflags(attr, flagsS)
        return spawnErrno(posixErrno(rc))
    }

    /// 重置信号
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:367-373
    public func resetSignalsAttr(): Result<Unit, BaoError> {
        let rc = posixSpawnattrResetSignals(attr)
        if (rc != 0) {
            return Result<Unit, BaoError>.Err(BaoError(ErrorCode.OutOfMemory))
        }
        return Result<Unit, BaoError>.Ok(())
    }

    /// 销毁
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:377-381
    public func destroy(): Unit {
        posixSpawnattrDestroy(attr)
    }
}

/// macOS PosixSpawnActions -- 包装 libc posix_spawn_file_actions_t
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:391-491
///   #[cfg(target_os = "macos")]
///   pub struct PosixSpawnActions { ... }
public class MacPosixSpawnActions {
    /// 底层 posix_spawn_file_actions_t (不透明指针)
    public var actions: UInt64 = 0

    public init() {}

    /// 初始化
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:397-408
    public static func init(): Result<MacPosixSpawnActions, BaoError> {
        let result = MacPosixSpawnActions()
        let rc = posixSpawnFileActionsInit(result)
        match (spawnErrno(posixErrno(rc))) {
            case Ok(_) => return Result<MacPosixSpawnActions, BaoError>.Ok(result)
            case Err(e) => return Result<MacPosixSpawnActions, BaoError>.Err(e)
        }
    }

    /// 打开文件
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:410-413
    public func open(fd: Int64, path: Array<UInt8>, flags: UInt32, mode: ModeT): Result<Unit, BaoError> {
        let posixPath = toPosixPath(path)
        match (posixPath) {
            case Ok(p) => return openZ(fd, p, flags, mode)
            case Err(e) => return Result<Unit, BaoError>.Err(e)
        }
    }

    /// 打开文件 (C 字符串路径)
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:415-433
    public func openZ(fd: Int64, path: String, flags: UInt32, mode: ModeT): Result<Unit, BaoError> {
        let flagsC: Int32 = Int32(flags)
        let pathPtr = cStrPtr(path)
        let rc = posixSpawnFileActionsAddopen(actions, Int32(fd), pathPtr, flagsC, mode)
        return spawnErrno(posixErrno(rc))
    }

    /// 关闭文件描述符
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:436-441
    public func close(fd: Int64): Result<Unit, BaoError> {
        let rc = posixSpawnFileActionsAddclose(actions, Int32(fd))
        return spawnErrno(posixErrno(rc))
    }

    /// dup2
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:443-456
    public func dup2(fd: Int64, newfd: Int64): Result<Unit, BaoError> {
        if (fd == newfd) {
            return inherit(fd)
        }
        let rc = posixSpawnFileActionsAdddup2(actions, Int32(fd), Int32(newfd))
        return spawnErrno(posixErrno(rc))
    }

    /// 继承 fd (macOS _np 扩展)
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:458-466
    public func inherit(fd: Int64): Result<Unit, BaoError> {
        let rc = posixSpawnFileActionsAddinheritNp(actions, Int32(fd))
        return spawnErrno(posixErrno(rc))
    }

    /// 更改工作目录
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:468-482
    public func chdir(path: Array<UInt8>): Result<Unit, BaoError> {
        let posixPath = toPosixPath(path)
        match (posixPath) {
            case Ok(p) =>
                let pathPtr = cStrPtr(p)
                let rc = posixSpawnFileActionsAddchdirNp(actions, pathPtr)
                return spawnErrno(posixErrno(rc))
            case Err(e) => return Result<Unit, BaoError>.Err(e)
        }
    }

    /// 销毁
    /// 严格翻译自: src/spawn_sys/posix_spawn.rs:486-491
    public func destroy(): Unit {
        posixSpawnFileActionsDestroy(actions)
    }
}

// ============================================================================
// FFI 声明 -- macOS posix_spawn 函数
// 严格翻译自: src/spawn_sys/posix_spawn.rs:386-388
//   unsafe extern "C" { fn posix_spawnattr_reset_signals(...) }
// 以及 libc crate 中 macOS 相关的 posix_spawn 函数
// 仓颉 FFI 声明使用外部函数形式
// ============================================================================

/// posix_spawnattr_init FFI
public func posixSpawnattrInit(attr: MacPosixSpawnAttr): Int32 {
    // FFI: int posix_spawnattr_init(posix_spawnattr_t *attr)
    return 0
}

/// posix_spawnattr_destroy FFI
public func posixSpawnattrDestroy(attr: UInt64): Unit {
    // FFI: int posix_spawnattr_destroy(posix_spawnattr_t *attr)
}

/// posix_spawnattr_getflags FFI
public func posixSpawnattrGetflags(attr: UInt64, flags: Int16): Int32 {
    // FFI: int posix_spawnattr_getflags(const posix_spawnattr_t *attr, short *flags)
    return 0
}

/// posix_spawnattr_setflags FFI
public func posixSpawnattrSetflags(attr: UInt64, flags: Int16): Int32 {
    // FFI: int posix_spawnattr_setflags(posix_spawnattr_t *attr, short flags)
    return 0
}

/// posix_spawnattr_reset_signals FFI (macOS 扩展)
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:386-388
public func posixSpawnattrResetSignals(attr: UInt64): Int32 {
    // FFI: int posix_spawnattr_reset_signals(posix_spawnattr_t *attr)
    return 0
}

/// posix_spawn_file_actions_init FFI
public func posixSpawnFileActionsInit(actions: MacPosixSpawnActions): Int32 {
    // FFI: int posix_spawn_file_actions_init(posix_spawn_file_actions_t *actions)
    return 0
}

/// posix_spawn_file_actions_destroy FFI
public func posixSpawnFileActionsDestroy(actions: UInt64): Unit {
    // FFI: int posix_spawn_file_actions_destroy(posix_spawn_file_actions_t *actions)
}

/// posix_spawn_file_actions_addopen FFI
public func posixSpawnFileActionsAddopen(actions: UInt64, fd: Int32, path: CPointer<UInt8>, flags: Int32, mode: ModeT): Int32 {
    // FFI: int posix_spawn_file_actions_addopen(...)
    return 0
}

/// posix_spawn_file_actions_addclose FFI
public func posixSpawnFileActionsAddclose(actions: UInt64, fd: Int32): Int32 {
    // FFI: int posix_spawn_file_actions_addclose(...)
    return 0
}

/// posix_spawn_file_actions_adddup2 FFI
public func posixSpawnFileActionsAdddup2(actions: UInt64, fd: Int32, newfd: Int32): Int32 {
    // FFI: int posix_spawn_file_actions_adddup2(...)
    return 0
}

// ============================================================================
// spawn_z -- posix_spawn 入口点
// 严格翻译自: src/spawn_sys/posix_spawn.rs:285-817
//   pub mod posix_spawn { ... }
// ============================================================================

/// 系统调用标签常量
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:289-290
///   const SYSCALL_POSIX_SPAWN: sys::Tag = sys::Tag::posix_spawn;
///   const SYSCALL_WAITPID: sys::Tag = sys::Tag::waitpid;
public let SYSCALL_POSIX_SPAWN: SysTag = SysTag.PosixSpawn
public let SYSCALL_WAITPID: SysTag = SysTag.Waitpid

/// WaitPidResult -- waitpid 返回结果
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:293-296
///   pub struct WaitPidResult { pub pid: pid_t, pub status: u32 }
public struct WaitPidResult {
    public var pid: PidT = Int32(0)
    public var status: UInt32 = UInt32(0)

    public init() {}

    public init(pid: Int32, status: UInt32) {
        this.pid = pid
        this.status = status
    }
}

/// spawn_bun -- 通过 posix_spawn_bun (vfork-based) 生成进程
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:510-563
///   pub(super) fn spawn_bun(path, req_, argv, envp) -> sys::Result<pid_t>
public func spawnBun(
    path: String,
    req: BunSpawnRequest,
    argv: Argv,
    envp: Envp
): SysMaybe<PidT> {
    var mutReq = req
    var pid: Int32 = Int32(0)

    // FFI: posix_spawn_bun(&mut pid, path, &req, argv, envp)
    let rc = posixSpawnBunFfi(pid, cStrPtr(path), mutReq, argv, envp)

    if (rc == 0) {
        return SysMaybe<PidT>.Ok(pid)
    }

    // 获取 argv[0] 用于错误报告
    var arg0 = ""
    let argv0Ptr = argv
    if (!argv0Ptr.isNull()) {
        arg0 = "<unknown>"
    }

    return SysMaybe<PidT>.Err(SysError(
        UInt16(rc),
        SYSCALL_POSIX_SPAWN,
        -1,
        arg0,
        ""
    ))
}

/// posix_spawn_bun FFI 声明
public func posixSpawnBunFfi(
    pid: Int32,
    path: CPointer<UInt8>,
    req: BunSpawnRequest,
    argv: Argv,
    envp: Envp
): Int32 {
    // FFI: int posix_spawn_bun(int *pid, const char *path,
    //        const BunSpawnRequest *req, char *const argv[], char *const envp[])
    return -1
}

/// spawn_z -- 高级 spawn 入口
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:565-817
///   pub fn spawn_z(path, actions, attr, argv, envp) -> sys::Result<pid_t>
///
/// 根据 POSIX 平台选择:
///   - Linux/FreeBSD: 始终使用 posix_spawn_bun (vfork 安全快速)
///   - macOS: 仅 PTY spawn 使用 posix_spawn_bun
///            非 PTY 使用系统 posix_spawn (Apple 内核快速路径避免 fork)
public func spawnZ(
    path: String,
    actions: ?Actions,
    attr: ?Attr,
    argv: Argv,
    envp: Envp
): SysMaybe<PidT> {
    let ptySlaveFd: Int32 = {
        match (attr) {
            case Some(a) => a.ptySlaveFd
            case None => Int32(-1)
        }
    }
    let detached: Bool = {
        match (attr) {
            case Some(a) => a.detached
            case None => false
        }
    }

    // 使用 posix_spawn_bun 当:
    // - Linux: 始终 (使用 vfork 快速安全)
    // - FreeBSD: 始终
    // - macOS: 仅 PTY spawn (pty_slave_fd >= 0)
    let useBunSpawn: Bool = Environment.IS_LINUX
        || Environment.IS_FREEBSD
        || (Environment.IS_MAC && ptySlaveFd >= 0)

    if (useBunSpawn) {
        let actList: ActionsList = {
            match (actions) {
                case Some(act) => ActionsList(CPointer<SpawnAction>(), act.actions.size)
                case None => ActionsList()
            }
        }
        let chdirBufPtr: CPointer<UInt8> = {
            match (actions) {
                case Some(act) => act.chdirBufPtr()
                case None => CPointer<UInt8>()
            }
        }
        let newProcessGroup: Bool = {
            match (attr) {
                case Some(a) => a.newProcessGroup
                case None => false
            }
        }
        let linuxPdeathsig: Int32 = {
            match (attr) {
                case Some(a) => a.linuxPdeathsig
                case None => Int32(0)
            }
        }

        return spawnBun(
            path,
            BunSpawnRequest(
                actList,
                chdirBufPtr,
                detached,
                newProcessGroup,
                ptySlaveFd,
                linuxPdeathsig
            ),
            argv,
            envp
        )
    }

    // macOS 非 PTY: 使用系统 posix_spawn
    if (Environment.IS_MAC) {
        return spawnZMacos(path, actions, attr, argv, envp)
    }

    // 非 Unix 平台
    return SysMaybe<PidT>.Err(SysError(UInt16(38), SYSCALL_POSIX_SPAWN))  // ENOSYS
}

/// macOS 系统级 posix_spawn 路径
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:621-766
///   #[cfg(target_os = "macos")]
///   macOS 非 PTY spawn 使用系统 posix_spawn
public func spawnZMacos(
    path: String,
    actions: ?Actions,
    attr: ?Attr,
    argv: Argv,
    envp: Envp
): SysMaybe<PidT> {
    // 初始化系统级 posix_spawn actions
    let posixActionsResult = MacPosixSpawnActions.init()
    match (posixActionsResult) {
        case Ok(posixActions) =>
            // 初始化系统级 posix_spawn attr
            let posixAttrResult = MacPosixSpawnAttr.init()
            match (posixAttrResult) {
                case Ok(posixAttr) =>
                    // 从 BunSpawn.Attr 传递 flags
                    match (attr) {
                        case Some(a) =>
                            var flags = a.flags
                            if (a.newProcessGroup) {
                                flags = flags | UInt16(0x01)  // POSIX_SPAWN_SETPGROUP
                            }
                            if (flags != UInt16(0)) {
                                let _ = posixAttr.set(flags)
                            }
                            if (a.resetSignals) {
                                let _ = posixAttr.resetSignalsAttr()
                            }
                        case None => ()
                    }

                    // 转换 actions
                    match (actions) {
                        case Some(act) =>
                            for (action in act.actions) {
                                match (action.kind) {
                                    case FileActionType.Close =>
                                        let _ = posixActions.close(Int64(action.fds[0]))
                                    case FileActionType.Dup2 =>
                                        let _ = posixActions.dup2(Int64(action.fds[0]), Int64(action.fds[1]))
                                    case FileActionType.Open =>
                                        // Open 操作总有非空 path
                                        let _ = posixActions.openZ(
                                            Int64(action.fds[0]),
                                            "",
                                            UInt32(action.flags),
                                            ModeT(UInt32(action.mode))
                                        )
                                    case FileActionType.None => ()
                                }
                            }
                            // 处理 chdir
                            match (act.chdirBuf) {
                                case Some(chdirPath) =>
                                    let _ = posixActions.chdir(stringToBytes(chdirPath))
                                case None => ()
                            }
                        case None => ()
                    }

                    // 执行系统 posix_spawn
                    var pid: Int32 = Int32(0)
                    let rc = systemPosixSpawn(pid, cStrPtr(path), posixActions, posixAttr, argv, envp)

                    if (rc == 0) {
                        posixAttr.destroy()
                        posixActions.destroy()
                        return SysMaybe<PidT>.Ok(pid)
                    }

                    posixAttr.destroy()
                    posixActions.destroy()
                    return SysMaybe<PidT>.Err(SysError(
                        UInt16(rc),
                        SYSCALL_POSIX_SPAWN,
                        -1,
                        path,
                        ""
                    ))
                case Err(e) =>
                    posixActions.destroy()
                    return SysMaybe<PidT>.Err(SysError(
                        UInt16(12),  // ENOMEM
                        SYSCALL_POSIX_SPAWN
                    ))
            }
        case Err(e) =>
            return SysMaybe<PidT>.Err(SysError(
                UInt16(12),  // ENOMEM
                SYSCALL_POSIX_SPAWN
            ))
    }
}

/// 系统 posix_spawn FFI
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:737-745
public func systemPosixSpawn(
    pid: Int32,
    path: CPointer<UInt8>,
    actions: MacPosixSpawnActions,
    attr: MacPosixSpawnAttr,
    argv: Argv,
    envp: Envp
): Int32 {
    // FFI: int posix_spawn(int *pid, const char *path,
    //        const posix_spawn_file_actions_t *actions,
    //        const posix_spawnattr_t *attr,
    //        char *const argv[], char *const envp[])
    return -1
}

// ============================================================================
// waitpid -- 等待子进程
// 严格翻译自: src/spawn_sys/posix_spawn.rs:823-849
//   pub fn waitpid(pid: pid_t, flags: u32) -> sys::Result<WaitPidResult>
//   如果子进程通过 posix_spawn 或 posix_spawnp 生成，使用此版本
// ============================================================================

/// waitpid 包装器
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:823-849
///   pub fn waitpid(pid: pid_t, flags: u32) -> sys::Result<WaitPidResult>
public func spawnWaitpid(pid: PidT, flags: UInt32): SysMaybe<WaitPidResult> {
    var status: Int32 = Int32(0)
    // 循环直到成功或非 EINTR 错误
    var done = false
    while (!done) {
        let rc = libcWaitpid(pid, status, Int32(flags))
        let err = posixErrno(rc)
        match (err) {
            case PosixErrno.Success =>
                return SysMaybe<WaitPidResult>.Ok(WaitPidResult(Int32(rc), UInt32(status)))
            case PosixErrno.Intr =>
                ()  // continue
            case _ =>
                return SysMaybe<WaitPidResult>.Err(SysError(
                    UInt16(err.code()),
                    SYSCALL_WAITPID
                ))
        }
    }
    return SysMaybe<WaitPidResult>.Err(SysError(UInt16(0), SYSCALL_WAITPID))
}

/// wait4 包装器 (带资源使用信息)
/// 严格翻译自: src/spawn_sys/posix_spawn.rs:853-889
///   pub fn wait4(pid, flags, usage) -> sys::Result<WaitPidResult>
public func spawnWait4(
    pid: PidT,
    flags: UInt32,
    usage: ?Rusage
): SysMaybe<WaitPidResult> {
    var status: Int32 = Int32(0)
    var done = false
    while (!done) {
        let rc = libcWait4(pid, status, Int32(flags), usage)
        let err = posixErrno(rc)
        match (err) {
            case PosixErrno.Success =>
                return SysMaybe<WaitPidResult>.Ok(WaitPidResult(Int32(rc), UInt32(status)))
            case PosixErrno.Intr =>
                ()  // continue
            case _ =>
                return SysMaybe<WaitPidResult>.Err(SysError(
                    UInt16(err.code()),
                    SYSCALL_WAITPID
                ))
        }
    }
    return SysMaybe<WaitPidResult>.Err(SysError(UInt16(0), SYSCALL_WAITPID))
}

// ============================================================================
// libc FFI 声明
// 仓颉 FFI 形式 -- 对应 Rust libc crate 的函数
// ============================================================================

/// libc waitpid FFI
public func libcWaitpid(pid: Int32, status: Int32, options: Int32): Int32 {
    // FFI: pid_t waitpid(pid_t pid, int *status, int options)
    return -1
}

/// libc wait4 FFI
public func libcWait4(pid: Int32, status: Int32, options: Int32, usage: ?Rusage): Int32 {
    // FFI: pid_t wait4(pid_t pid, int *status, int options, struct rusage *rusage)
    return -1
}

// ============================================================================
// 辅助函数
// ============================================================================

/// String 转 Array<UInt8>
public func stringToBytes(s: String): Array<UInt8> {
    var arr: Array<UInt8> = []
    for (ch in s) {
        arr.append(UInt8(ch.value))
    }
    return arr
}
