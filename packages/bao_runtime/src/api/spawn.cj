// 严格翻译自: src/runtime/api/bun/spawn.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_sys.*

// ============================================================================
// BunSpawn - Bun 自定义 spawn 实现 (用于 Linux/FreeBSD PTY 支持)
// 对应 Bun: src/runtime/api/bun/spawn.zig
// ============================================================================

/// 文件操作动作
public enum FileActionType: UInt8 {
    case none = 0
    case close = 1
    case dup2 = 2
    case open = 3
}

/// 单个文件操作
public class Action {
    var kind: FileActionType = FileActionType.none
    var path: String = null      // null-terminated string
    var fds: [Int32, Int32]
    var flags: Int32 = 0
    var mode: Int32 = 0

    public static func init(): Action {
        return Action{}
    }

    public func deinit(allocator: Allocator) {
        if (this.kind == .open) {
            if (this.path != null) {
                allocator.free(bun.span(this.path))
            }
        }
    }
}

/// 文件操作集合
public class Actions {
    var chdirBuf: String = null     // null-terminated string
    var actions: ArrayListUnmanaged<Action> = ArrayListUnmanaged()
    var detached: Bool = false

    public static func init(): Actions {
        return Actions{}
    }

    public func deinit() {
        if (this.chdirBuf != null) {
            default_allocator.free(bun.span(this.chdirBuf))
        }

        for (action in this.actions.items) {
            action.deinit(default_allocator)
        }

        this.actions.deinit(default_allocator)
    }

    /// 添加 open 操作
    public func open(fd: FD, path: String, flags: UInt32, mode: Int32) {
        let posixPath = try toPosixPath(path)
        return this.openZ(fd, posixPath, flags, mode)
    }

    /// 添加 open 操作 (null-terminated)
    public func openZ(fd: FD, path: String, flags: UInt32, mode: Int32) {
        try this.actions.append(default_allocator, Action{
            kind = .open,
            path = (try default_allocator.dupeZ(UInt8, bun.span(path))).ptr,
            flags = Int32(flags),
            mode = Int32(mode),
            fds = [fd.native(), 0],
        })
    }

    /// 添加 close 操作
    public func close(fd: FD) {
        try this.actions.append(default_allocator, Action{
            kind = .close,
            fds = [fd.native(), 0],
        })
    }

    /// 添加 dup2 操作
    public func dup2(fd: FD, newfd: FD) {
        try this.actions.append(default_allocator, Action{
            kind = .dup2,
            fds = [fd.native(), newfd.native()],
        })
    }

    /// 添加 inherit 操作 (dup2(fd, fd))
    public func inherit(fd: FD) {
        try this.dup2(fd, fd)
    }

    /// 设置工作目录
    public func chdir(path: String) {
        if (this.chdirBuf != null) {
            default_allocator.free(bun.span(this.chdirBuf))
        }
        this.chdirBuf = (try default_allocator.dupeZ(UInt8, path)).ptr
    }
}

/// 进程属性
public class Attr {
    var detached: Bool = false
    var newProcessGroup: Bool = false
    var ptySlaveFd: Int32 = -1
    var flags: UInt16 = 0
    var resetSignals: Bool = false
    var linuxPdeathsig: Int32 = 0

    public static func init(): Attr {
        return Attr{}
    }

    public func deinit() {}

    public func get(): UInt16 {
        return this.flags
    }

    public func set(flags: UInt16) {
        this.flags = flags
        // FreeBSD 没有 POSIX_SPAWN_SETSID
        if (C.POSIX_SPAWN_SETSID != null) {
            this.detached = (flags & C.POSIX_SPAWN_SETSID) != 0
        }
    }

    public func resetSignals() {
        this.resetSignals = true
    }
}

// ============================================================================
// PosixSpawn - 系统 posix_spawn 封装
// ============================================================================

/// waitpid 结果
public class WaitPidResult {
    var pid: PidT
    var status: UInt32
}

/// posix_spawn 属性封装
public class PosixSpawnAttr {
    var attr: PosixSpawnattrT
    var detached: Bool = false
    var ptySlaveFd: Int32 = -1

    public static func init(): PosixSpawnAttr {
        var attr = PosixSpawnattrT()
        switch (Posix.errno(Posix.posix_spawnattr_init(attr))) {
            case .SUCCESS => return PosixSpawnAttr{ attr = attr }
            case .NOMEM => throw Error.SystemResources
            case .INVAL => unreachable
            else => let err => throw unexpectedErrno(err)
        }
    }

    public func deinit() {
        _ = Posix.posix_spawnattr_destroy(this.attr)
    }

    public func get(): UInt16 {
        var flags: Int16
        switch (Posix.errno(Posix.posix_spawnattr_getflags(this.attr, flags))) {
            case .SUCCESS => return UInt16(flags)
            case .INVAL => unreachable
            else => let err => throw unexpectedErrno(err)
        }
    }

    public func set(flags: UInt16) {
        switch (Posix.errno(Posix.posix_spawnattr_setflags(this.attr, Int16(flags)))) {
            case .SUCCESS => return
            case .INVAL => unreachable
            else => let err => throw unexpectedErrno(err)
        }
    }

    public func resetSignals() {
        if (posix_spawnattr_reset_signals(this.attr) != 0) {
            throw Error.SystemResources
        }
    }

    // 外部 C 函数
    extern func posix_spawnattr_reset_signals(attr: PosixSpawnattrT): Int32
}

/// posix_spawn 文件操作封装
public class PosixSpawnActions {
    var actions: PosixSpawnFileActionsT

    public static func init(): PosixSpawnActions {
        var actions = PosixSpawnFileActionsT()
        switch (Posix.errno(Posix.posix_spawn_file_actions_init(actions))) {
            case .SUCCESS => return PosixSpawnActions{ actions = actions }
            case .NOMEM => throw Error.SystemResources
            case .INVAL => unreachable
            else => let err => throw unexpectedErrno(err)
        }
    }

    public func deinit() {
        _ = Posix.posix_spawn_file_actions_destroy(this.actions)
        this = uninitialized
    }

    public func open(fd: FD, path: String, flags: UInt32, mode: ModeT) {
        let posixPath = try toPosixPath(path)
        return this.openZ(fd, posixPath, flags, mode)
    }

    public func openZ(fd: FD, path: String, flags: UInt32, mode: ModeT) {
        switch (Posix.errno(Posix.posix_spawn_file_actions_addopen(this.actions, fd.cast(), path, Int32(flags), mode))) {
            case .SUCCESS => return
            case .BADF => throw Error.InvalidFileDescriptor
            case .NOMEM => throw Error.SystemResources
            case .NAMETOOLONG => throw Error.NameTooLong
            case .INVAL => unreachable
            else => let err => throw unexpectedErrno(err)
        }
    }

    public func close(fd: FD) {
        switch (Posix.errno(Posix.posix_spawn_file_actions_addclose(this.actions, fd.cast()))) {
            case .SUCCESS => return
            case .BADF => throw Error.InvalidFileDescriptor
            case .NOMEM => throw Error.SystemResources
            case .INVAL => unreachable
            else => let err => throw unexpectedErrno(err)
        }
    }

    public func dup2(fd: FD, newfd: FD) {
        if (fd == newfd) {
            return this.inherit(fd)
        }

        switch (Posix.errno(Posix.posix_spawn_file_actions_adddup2(this.actions, fd.cast(), newfd.cast()))) {
            case .SUCCESS => return
            case .BADF => throw Error.InvalidFileDescriptor
            case .NOMEM => throw Error.SystemResources
            case .INVAL => unreachable
            else => let err => throw unexpectedErrno(err)
        }
    }

    public func inherit(fd: FD) {
        switch (Posix.errno(Posix.posix_spawn_file_actions_addinherit_np(this.actions, fd.cast()))) {
            case .SUCCESS => return
            case .BADF => throw Error.InvalidFileDescriptor
            case .NOMEM => throw Error.SystemResources
            case .INVAL => unreachable
            else => let err => throw unexpectedErrno(err)
        }
    }

    public func chdir(path: String) {
        let posixPath = try toPosixPath(path)
        return this.chdirZ(posixPath)
    }

    func chdirZ(path: String) {
        switch (Posix.errno(Posix.posix_spawn_file_actions_addchdir_np(this.actions, path))) {
            case .SUCCESS => return
            case .NOMEM => throw Error.SystemResources
            case .NAMETOOLONG => throw Error.NameTooLong
            case .BADF => unreachable
            case .INVAL => unreachable
            else => let err => throw unexpectedErrno(err)
        }
    }
}

/// POSIX 上使用 BunSpawn 类型，Windows 使用 PosixSpawn 类型
public typealias SpawnActions = Actions   // POSIX
public typealias SpawnAttr = Attr          // POSIX

// ============================================================================
// PosixSpawn 顶层函数
// ============================================================================

/// 使用 posix_spawn 创建子进程
public func spawnZ(
    path: String,
    actions: SpawnActions,
    attr: SpawnAttr,
    argv: Array<String>,
    envp: Array<String>,
): Maybe<PidT> {
    let ptySlaveFd = if (attr != null) attr.ptySlaveFd else -1
    let detached = if (attr != null) attr.detached else false

    // Linux/FreeBSD 始终使用 posix_spawn_bun (vfork)
    // macOS PTY 场景也使用 posix_spawn_bun
    let useBunSpawn = Environment.isLinux || Environment.isFreeBSD || (Environment.isMac && ptySlaveFd >= 0)

    if (useBunSpawn) {
        return BunSpawnRequest.spawn(
            path,
            BunSpawnRequest{
                actions = if (actions != null) {
                    ActionsList{ ptr = actions.actions.items.ptr, len = actions.actions.items.len }
                } else {
                    ActionsList{ ptr = null, len = 0 }
                },
                chdirBuf = if (actions != null) actions.chdirBuf else null,
                detached = detached,
                newProcessGroup = if (attr != null) attr.newProcessGroup else false,
                ptySlaveFd = ptySlaveFd,
                linuxPdeathsig = if (attr != null) attr.linuxPdeathsig else 0,
            },
            argv,
            envp,
        )
    }

    // macOS 非 PTY: 使用系统 posix_spawn
    var posixActions = PosixSpawnActions.init() catch {
        return Maybe<PidT>.err(SysError{
            errno = Int64(Posix.E.NOMEM),
            syscall = .posix_spawn,
        })
    }
    defer posixActions.deinit()

    var posixAttr = PosixSpawnAttr.init() catch {
        return Maybe<PidT>.err(SysError{
            errno = Int64(Posix.E.NOMEM),
            syscall = .posix_spawn,
        })
    }
    defer posixAttr.deinit()

    if (attr != null) {
        var flags = attr.flags
        if (attr.newProcessGroup) {
            flags |= C.POSIX_SPAWN_SETPGROUP
        }
        if (flags != 0) {
            posixAttr.set(flags) catch {}
        }
        if (attr.resetSignals) {
            posixAttr.resetSignals() catch {}
        }
    }

    // 转换操作
    if (actions != null) {
        for (action in actions.actions.items) {
            switch (action.kind) {
                case .close => posixActions.close(FD.fromNative(action.fds[0])) catch {}
                case .dup2 => posixActions.dup2(FD.fromNative(action.fds[0]), FD.fromNative(action.fds[1])) catch {}
                case .open => posixActions.openZ(FD.fromNative(action.fds[0]), action.path, UInt32(action.flags), Int32(action.mode)) catch {}
                case .none => {}
            }
        }

        if (actions.chdirBuf != null) {
            posixActions.chdir(bun.span(actions.chdirBuf)) catch {}
        }
    }

    var pid: PidT
    let rc = Posix.posix_spawn(pid, path, posixActions.actions, posixAttr.attr, argv, envp)

    if (rc == 0) {
        return Maybe<PidT>.result(pid)
    }

    return Maybe<PidT>.err(SysError{
        errno = Int64(rc),
        syscall = .posix_spawn,
        path = bun.asByteSlice(path),
    })
}

/// waitpid 封装
public func waitpid(pid: PidT, flags: UInt32): Maybe<WaitPidResult> {
    var status: Int32 = 0
    while (true) {
        let rc = Posix.waitpid(pid, status, Int32(flags))
        switch (Posix.errno(rc)) {
            case .SUCCESS => return Maybe<WaitPidResult>.result(WaitPidResult{
                pid = PidT(rc),
                status = UInt32(status),
            })
            case .INTR => continue
            else => return Sys.Maybe(WaitPidResult).errnoSys(rc, .waitpid)
        }
    }
}

/// wait4 封装 (带资源使用信息)
public func wait4(pid: PidT, flags: UInt32, usage: Rusage): Maybe<WaitPidResult> {
    var status: Int32 = 0
    while (true) {
        let rc = Posix.wait4(pid, status, Int32(flags), usage)
        switch (Posix.errno(rc)) {
            case .SUCCESS => return Maybe<WaitPidResult>.result(WaitPidResult{
                pid = PidT(rc),
                status = UInt32(status),
            })
            case .INTR => continue
            else => return Sys.Maybe(WaitPidResult).errnoSys(rc, .waitpid)
        }
    }
}

// ============================================================================
// BunSpawnRequest - posix_spawn_bun 请求
// ============================================================================

public class BunSpawnRequest {
    var chdirBuf: String = null
    var detached: Bool = false
    var newProcessGroup: Bool = false
    var actions: ActionsList = ActionsList{}
    var ptySlaveFd: Int32 = -1
    var linuxPdeathsig: Int32 = 0

    public class ActionsList {
        var ptr: UnsafePointer<Action> = null
        var len: Int64 = 0
    }

    // 外部 C 函数
    extern func posix_spawn_bun(
        pid: UnsafePointer<Int32>,
        path: String,
        request: BunSpawnRequest,
        argv: Array<String>,
        envp: Array<String>,
    ): Int64

    /// 通过 posix_spawn_bun 创建子进程
    public static func spawn(
        path: String,
        req: BunSpawnRequest,
        argv: Array<String>,
        envp: Array<String>,
    ): Maybe<PidT> {
        var req = req
        var pid: Int32 = 0

        let rc = posix_spawn_bun(pid, path, req, argv, envp)
        if (Environment.allow_assert) {
            Sys.syslog("posix_spawn_bun(\{argv[0] ?? ""}) = \{rc} (\{pid})")
        }

        if (rc == 0) {
            return Maybe<PidT>.result(pid)
        }

        return Maybe<PidT>.err(SysError{
            errno = Int64(rc),
            syscall = .posix_spawn,
            path = bun.span(argv[0] ?? ""),
        })
    }
}

// ============================================================================
// 类型别名
// ============================================================================

public typealias PidT = PidT
public typealias FdT = FdT
public typealias ModeT = ModeT
public typealias Rusage = Rusage
public let default_allocator = default_allocator
