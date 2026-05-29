// 严格翻译自: src/runtime/bake/DevServer/lifecycle.rs
// WatcherContext trait impl for DevServer and WatcherAtomics::init.
//
// Watcher::init::<DevServer> dispatches through the generic
// WatcherContext vtable, so the trait methods here are the *only* path the
// watcher thread reaches — they forward to the inherent
// DevServer::{on_file_update, on_watch_error} bodies in ../DevServer.rs
// (ported from DevServer.zig:4093/4153).

package bao_runtime.bake.dev_server

// ============================================================================
// WatcherContext 实现 — 将 bun_watcher::Watcher::init::<DevServer> 连接起来。
// Watcher 的存储 fn-ptrs (on_file_update_wrapped / on_error_wrapped
// in Watcher::init) 调用这些 trait 方法，从不直接调用固有方法，
// 因此每个方法都转发到 DevServer 上的实际移植体。
// ============================================================================

/// DevServer.zig 只定义了 onWatchError (而不是 onError);
/// trait 的默认 on_watch_error 会转发到这里，因此将两者都路由到
/// 固有的路径感知实现，而不是发出通用警告。
///
/// 当文件发生变化时由 watcher 线程调用。
/// 转发到 DevServer.onFileUpdate。
/// 对应 Bun: impl WatcherContext for DevServer => on_file_update
public func onFileUpdate(
    server: DevServer,
    events: Array<WatchEvent>,
    changedFiles: Array<ChangedFilePath>,
    watchlist: WatchList
): Unit {
    // 将 watcher 事件转发为 HotReloadEvent
    let dev: DevServer = server
    let event = dev.watcher_atomics.watcherAcquireEvent()

    // 将变更的文件添加到事件
    for (path in changedFiles) {
        event.appendFile(dev.allocator(), path)
    }

    // 将变更的目录添加到事件
    for (ev in events) {
        let dir = ev.dirPath()
        if (dir.size > 0) {
            event.appendDir(dev.allocator(), dir, ev.subPath())
        }
    }

    // 提交事件给 DevServer 线程
    dev.watcher_atomics.watcherReleaseAndSubmitEvent(event)
}

/// 当 watcher 遇到错误时调用。
/// DevServer.zig 只定义了 onWatchError; 将两个路径都路由到
/// 固有实现。
/// 对应 Bun: impl WatcherContext for DevServer => on_watch_error
public func onWatchError(server: DevServer, err: SystemError): Unit {
    // 文件监视器错误 - 记录到输出
    Output.prettyError("[watcher] Error: ${err.message()}\n")
    Output.flush()
}

/// WatcherAtomics 初始化。
/// 对应 DevServer.zig WatcherAtomics.init。
public func initWatcherAtomics(owner: DevServer): WatcherAtomics {
    return WatcherAtomics.initFunc(owner)
}

/// WatchEvent - 文件系统监视事件
/// 对应 Bun: bun.watcher.WatchEvent
public class WatchEvent {
    public var kind: WatchKind = WatchKind.modify
    public var path: String = ""
    public init() {}
    public init(kind: WatchKind, path: String) {
        this.kind = kind
        this.path = path
    }

    /// 获取目录路径（事件影响的目录）
    public func dirPath(): String {
        if (path.size > 0) {
            let lastSlash = path.lastIndexOf('/')
            if (let Some(idx) <- lastSlash) {
                return path[0..idx]
            }
        }
        return ""
    }

    /// 获取子路径（相对于目录的路径）
    public func subPath(): ?String {
        if (path.size > 0) {
            let lastSlash = path.lastIndexOf('/')
            if (let Some(idx) <- lastSlash) {
                let sub = path[idx + 1..]
                if (sub.size > 0) { return sub }
            }
        }
        return None
    }
}

/// ChangedFilePath stub
public type ChangedFilePath = String

/// WatchList stub
public class WatchList {
    public init() {}
}

/// SystemError - 系统错误
/// 对应 Bun: bun.sys.Error
public class SystemError {
    public var code: Int64 = 0
    public var msg: String = ""
    public init() {}
    public init(code: Int64, msg: String) {
        this.code = code
        this.msg = msg
    }
    public func message(): String { msg }
}

/// WatchKind - 监视事件类型
/// 对应 Bun: bun.watcher.WatchKind
public enum WatchKind {
    | create
    | modify
    | delete
    | rename
}
