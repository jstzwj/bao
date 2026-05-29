// 严格翻译自: src/runtime/api/bun/spawn.zig
package bao_runtime.api

import bao_jsc.*
import bao_collections.ArrayList
import bao_core.*
import bao_sys.*

// ============================================================================
// BunSpawn - Bun 自定义 spawn 实现 (用于 Linux/FreeBSD PTY 支持)
// 对应 Bun: src/runtime/api/bun/spawn.zig
// ============================================================================

/// 文件操作动作
public enum FileActionType {
    | none
    | close
    | dup2
    | `open`
}

/// 单个文件操作
public class Action {
    var kind: FileActionType = FileActionType.none
    var path: String = none      // null-terminated string
    var fds: Tuple<Int32, Int32>
    var flags: Int32 = 0
    var mode: Int32 = 0

    public static func initFunc(): Action {
        return Action{}
    }

    public func deinit(allocator!: Allocator) {
        if (this.kind == open) {
            if (this.path != none) {
                allocator.free(bun.span(this.path))
            }
        }
    }
}

/// 文件操作集合
public class Actions {
    var chdirBuf: String = none     // null-terminated string
    var actions: ArrayListUnmanaged<Action> = ArrayListUnmanaged()
    var detached: Bool = false

    public static func initFunc(): Actions {
        return Actions{}
    }

    public func deinit() {
        if (this.chdirBuf != none) {
            default_allocator.free(bun.span(this.chdirBuf))
        }

        for (action in this.actions.items) {
            action.deinit(default_allocator)
        }

        this.actions.deinit(default_allocator)
    }

    /// 添加 open 操作
    public func `open`(fd!: FD, path!: String, flags!: UInt32, mode!: Int32) {
        let posixPath = toPosixPath(path) 
        return this.openZ(fd, posixPath, flags, mode)
    }

    /// 添加 open 操作 (null-terminated)
    public func openZ(fd!: FD, path!: String, flags!: UInt32, mode!: Int32) {
        let action = Action()
        action.kind = FileActionType.open
        action.path = path
        action.flags = Int32(flags)
        action.mode = Int32(mode)
        action.fds = (fd.native(), 0)
        this.actions.append(default_allocator, action)
    }

    /// 添加 close 操作
    public func close(fd!: FD) {
        let action = Action()
        action.kind = FileActionType.close
        action.fds = (fd.native(), 0)
        this.actions.append(default_allocator, action)
    }

    /// 添加 dup2 操作
    public func dup2(fd!: FD, newfd!: FD) {
        let action = Action()
        action.kind = FileActionType.dup2
        action.fds = (fd.native(), newfd.native())
        this.actions.append(default_allocator, action)
    }

    /// 添加 inherit 操作 (dup2(fd, fd))
    public func inherit(fd!: FD) {
        this.dup2(fd, fd) 
    }

    /// 设置工作目录
    public func chdir(path!: String) {
        if (this.chdirBuf != none) {
            default_allocator.free(bun.span(this.chdirBuf))
        }
        this.chdirBuf = default_allocator.dupeZ(path)
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

    public static func initFunc(): Attr {
        return Attr{}
    }

    public func deinit() {}

    public func `get`(): UInt16 {
        return this.flags
    }

    public func `set`(flags!: UInt16) {
        this.flags = flags
        // FreeBSD 没有 POSIX_SPAWN_SETSID
        if (C.POSIX_SPAWN_SETSID != none) {
            this.detached = (flags & C.POSIX_SPAWN_SETSID) != 0
        }
    }

    public func doResetSignals() {
        this.resetSignals = true
    }
}

// ============================================================================
// PosixSpawn - 系统 posix_spawn 封装
// ============================================================================

/// waitpid 结果
public class WaitPidResult {
    var pid: PidT = PidT(0)
    var status: UInt32 = 0
}

/// posix_spawn 属性封装
public class PosixSpawnAttr {
    var attr: PosixSpawnattrT = PosixSpawnattrT()
    var detached: Bool = false
    var ptySlaveFd: Int32 = -1

    public static func initFunc(): PosixSpawnAttr {
        var attr = PosixSpawnattrT()
        match (Posix.errno(Posix.posix_spawnattr_init(attr))) {
            case SUCCESS => return PosixSpawnAttr{ attr = attr }
            case NOMEM => throw Error.SystemResources
            case INVAL => unreachable()
            case err => throw unexpectedErrno(err)
        }
    }

    public func deinit() {
        _ = Posix.posix_spawnattr_destroy(this.attr)
    }

    public func `get`(): UInt16 {
        var flags: Int16
        match (Posix.errno(Posix.posix_spawnattr_getflags(this.attr, flags))) {
            case SUCCESS => return UInt16(flags)
            case INVAL => unreachable()
            case err => throw unexpectedErrno(err)
        }
    }

    public func `set`(flags!: UInt16) {
        match (Posix.errno(Posix.posix_spawnattr_setflags(this.attr, Int16(flags)))) {
            case SUCCESS => return
            case INVAL => unreachable()
            case err => throw unexpectedErrno(err)
        }
    }

    public func resetSignals() {
        if (posix_spawnattr_reset_signals(this.attr) != 0) {
            throw Error.SystemResources
        }
    }

    // 外部 C 函数
    public static func posix_spawnattr_reset_signals(attr!: PosixSpawnattrT): Int32 { return 0 }
}

/// posix_spawn 文件操作封装
public class PosixSpawnActions {
    var actions: PosixSpawnFileActionsT

    public static func initFunc(): PosixSpawnActions {
        var actions = PosixSpawnFileActionsT()
        match (Posix.errno(Posix.posix_spawn_file_actions_init(actions))) {
            case SUCCESS => return PosixSpawnActions{ actions = actions }
            case NOMEM => throw Error.SystemResources
            case INVAL => unreachable()
            case err => throw unexpectedErrno(err)
        }
    }

    public func deinit() {
        _ = Posix.posix_spawn_file_actions_destroy(this.actions)
        this = uninitialized
    }

    public func `open`(fd!: FD, path!: String, flags!: UInt32, mode!: ModeT) {
        let posixPath = toPosixPath(path) 
        return this.openZ(fd, posixPath, flags, mode)
    }

    public func openZ(fd!: FD, path!: String, flags!: UInt32, mode!: ModeT) {
        match (Posix.errno(Posix.posix_spawn_file_actions_addopen(this.actions, fd.cast(), path, Int32(flags), mode))) {
            case SUCCESS => return
            case BADF => throw Error.InvalidFileDescriptor
            case NOMEM => throw Error.SystemResources
            case NAMETOOLONG => throw Error.NameTooLong
            case INVAL => unreachable()
            case err => throw unexpectedErrno(err)
        }
    }

    public func close(fd!: FD) {
        match (Posix.errno(Posix.posix_spawn_file_actions_addclose(this.actions, fd.cast()))) {
            case SUCCESS => return
            case BADF => throw Error.InvalidFileDescriptor
            case NOMEM => throw Error.SystemResources
            case INVAL => unreachable()
            case err => throw unexpectedErrno(err)
        }
    }

    public func dup2(fd!: FD, newfd!: FD) {
        if (fd == newfd) {
            return this.inherit(fd)
        }

        match (Posix.errno(Posix.posix_spawn_file_actions_adddup2(this.actions, fd.cast(), newfd.cast()))) {
            case SUCCESS => return
            case BADF => throw Error.InvalidFileDescriptor
            case NOMEM => throw Error.SystemResources
            case INVAL => unreachable()
            case err => throw unexpectedErrno(err)
        }
    }

    public func inherit(fd!: FD) {
        match (Posix.errno(Posix.posix_spawn_file_actions_addinherit_np(this.actions, fd.cast()))) {
            case SUCCESS => return
            case BADF => throw Error.InvalidFileDescriptor
            case NOMEM => throw Error.SystemResources
            case INVAL => unreachable()
            case err => throw unexpectedErrno(err)
        }
    }

    public func chdir(path!: String) {
        let posixPath = toPosixPath(path) 
        return this.chdirZ(posixPath)
    }

    func chdirZ(path!: String) {
        match (Posix.errno(Posix.posix_spawn_file_actions_addchdir_np(this.actions, path))) {
            case SUCCESS => return
            case NOMEM => throw Error.SystemResources
            case NAMETOOLONG => throw Error.NameTooLong
            case BADF => unreachable()
            case INVAL => unreachable()
            case err => throw unexpectedErrno(err)
        }
    }
}

/// POSIX 上使用 BunSpawn 类型，Windows 使用 PosixSpawn 类型
public type SpawnActions = Actions   // POSIX
public type SpawnAttr = Attr          // POSIX

// ============================================================================
// PosixSpawn 顶层函数
// ============================================================================

/// 使用 posix_spawn 创建子进程
public func spawnZ(
    path!: String,
    actions!: SpawnActions,
    attr!: SpawnAttr,
    argv!: Array<String>,
    envp!: Array<String>
): Maybe<PidT> {
    let ptySlaveFd = if (attr != none) { attr.ptySlaveFd } else { -1 }
    let detached = if (attr != none) { attr.detached } else { false }

    // Linux/FreeBSD 始终使用 posix_spawn_bun (vfork)
    // macOS PTY 场景也使用 posix_spawn_bun
    let useBunSpawn = Environment.isLinux || Environment.isFreeBSD || (Environment.isMac && ptySlaveFd >= 0)

    if (useBunSpawn) {
        return BunSpawnRequest.`spawn`(
            path,
            BunSpawnRequest{
                actions = if (actions != none) {
                    ActionsList{ ptr = actions.actions.items.ptr; len = actions.actions.items.len }
                } else {
                    ActionsList{ ptr = none; len = 0 }
                }
                chdirBuf = if (actions != none) { actions.chdirBuf } else { none }
                detached = detached
                newProcessGroup = if (attr != none) { attr.newProcessGroup } else { false }
                ptySlaveFd = ptySlaveFd
                linuxPdeathsig = if (attr != none) { attr.linuxPdeathsig } else { 0 }
            },
            argv,
            envp
        )
    }

    // macOS 非 PTY: 使用系统 posix_spawn
    var posixActions = try { PosixSpawnActions() } catch (_: Exception) {
        return Maybe<PidT>.err(SysError{
            errno = Int64(Posix.E.NOMEM)
            syscall = SysTag.PosixSpawn
        })
    }
    var posixAttr = try { PosixSpawnAttr() } catch (_: Exception) {
        return Maybe<PidT>.err(SysError{
            errno = Int64(Posix.E.NOMEM)
            syscall = SysTag.PosixSpawn
        })
    }
    if (attr != none) {
        var flags = attr.flags
        if (attr.newProcessGroup) {
            flags |= C.POSIX_SPAWN_SETPGROUP
        }

        if (flags != 0) {
            try { posixAttr.set(flags) } catch (_: Exception) {}
        }
        if (attr.resetSignals) {
            try { posixAttr.doResetSignals() } catch (_: Exception) {}
        }
    }

    // 转换操作
    if (actions != none) {
        for (action in actions.actions.items) {
            match (action.kind) {
                case close => try { posixActions.close(FD.fromNative(action.fds[0])) } catch (_: Exception) {}
                case dup2 => try { posixActions.dup2(FD.fromNative(action.fds[0]), FD.fromNative(action.fds[1])) } catch (_: Exception) {}
                case open => try { posixActions.openZ(FD.fromNative(action.fds[0]), action.path, UInt32(action.flags), Int32(action.mode)) } catch (_: Exception) {}
                case none => ()
            }
        }

        if (actions.chdirBuf != none) {
            try { posixActions.chdir(bun.span(actions.chdirBuf)) } catch (_: Exception) {}
        }
    }

    var pid: PidT
    let rc = Posix.posix_spawn(pid, path, posixActions.actions, posixAttr.attr, argv, envp)

    if (rc == 0) {
        return Maybe<PidT>.result(pid)
    }

    return Maybe<PidT>.err(SysError{
        errno = Int64(rc)
        syscall = SysTag.PosixSpawn
        path = bun.asByteSlice(path)
    })
    posixAttr.deinit()
    posixActions.deinit()
}

/// waitpid 封装
public func waitpid(pid!: PidT, flags!: UInt32): Maybe<WaitPidResult> {
    var status: Int32 = 0
    while (true) {
        let rc = PosixSysTag.Waitpid(pid, status, Int32(flags))
        match (Posix.errno(rc)) {
            case SUCCESS => return Maybe<WaitPidResult>.result(WaitPidResult{
                pid = PidT(rc)
                status = UInt32(status)
            })
            case INTR => continue
            case _ => return Sys.Maybe(WaitPidResult).errnoSys(rc, SysTag.Waitpid)
        }
    }
}

/// wait4 封装 (带资源使用信息)
public func wait4(pid!: PidT, flags!: UInt32, usage!: Rusage): Maybe<WaitPidResult> {
    var status: Int32 = 0
    while (true) {
        let rc = Posix.wait4(pid, status, Int32(flags), usage)
        match (Posix.errno(rc)) {
            case SUCCESS => return Maybe<WaitPidResult>.result(WaitPidResult{
                pid = PidT(rc)
                status = UInt32(status)
            })
            case INTR => continue
            case _ => return Sys.Maybe(WaitPidResult).errnoSys(rc, SysTag.Waitpid)
        }
    }
}

// ============================================================================
// BunSpawnRequest - posix_spawn_bun 请求
// ============================================================================

public class BunSpawnRequest {
    var chdirBuf: String = none
    var detached: Bool = false
    var newProcessGroup: Bool = false
    var actions: ActionsList = ActionsList{}
    var ptySlaveFd: Int32 = -1
    var linuxPdeathsig: Int32 = 0

//    public class ActionsList {
//        var ptr: UnsafePointer<Action> = none
//        var len: Int64 = 0
//    }

    // 外部 C 函数 - stub
    public static func posix_spawn_bun(
        pid!: UnsafePointer<Int32>,
        path!: String,
        request!: BunSpawnRequest,
        argv!: Array<String>,
        envp!: Array<String>
    ): Int64 { return -1 }

    /// 通过 posix_spawn_bun 创建子进程
    public static func `spawn`(
        path!: String,
        req!: BunSpawnRequest,
        argv!: Array<String>,
        envp!: Array<String>
    ): Maybe<PidT> {
        var pid: Int32 = 0

        let rc = posix_spawn_bun(pid, path, req, argv, envp)
        if (Environment.allow_assert) {
            Sys.syslog("posix_spawn_bun(${argv[0] ?? ""}) = ${rc} (${pid})")
        }

        if (rc == 0) {
            return Maybe<PidT>.result(pid)
        }

        return Maybe<PidT>.err(SysError{
            errno = Int64(rc)
            syscall = SysTag.PosixSpawn
            path = bun.span(argv[0] ?? "")
        })
    }
}

// ============================================================================
// 类型别名
// ============================================================================

// PidT, FdT, ModeT, Rusage, default_allocator 已通过 import 导入，无需重复定义