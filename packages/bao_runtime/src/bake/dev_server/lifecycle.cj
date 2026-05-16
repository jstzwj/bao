// 严格翻译自: src/runtime/bake/DevServer/lifecycle.rs
// WatcherContext trait impl for DevServer and WatcherAtomics::init.
//
// Watcher::init::<DevServer> dispatches through the generic
// WatcherContext vtable, so the trait methods here are the *only* path the
// watcher thread reaches — they forward to the inherent
// DevServer::{on_file_update, on_watch_error} bodies in ../DevServer.rs
// (ported from DevServer.zig:4093/4153).

package bao_runtime.bake.dev_server

import bao_watcher.*
import bao_sys.*

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
/// 转发到 DevServer.on_file_update。
public func onFileUpdate(
    server: DevServer,
    events: Array<WatchEvent>,
    changedFiles: Array<ChangedFilePath>,
    watchlist: WatchList,
): Unit {
    server.onFileUpdate(events, changedFiles, watchlist)
}

/// 当 watcher 遇到错误时调用。
/// DevServer.zig 只定义了 onWatchError; 将两个路径都路由到
/// 固有实现。
public func onWatchError(server: DevServer, err: SystemError): Unit {
    server.onWatchError(err)
}

/// WatcherAtomics 初始化。
/// 对应 DevServer.zig WatcherAtomics.init。
public func initWatcherAtomics(owner: DevServer): WatcherAtomics {
    let mkEvent = (): HotReloadEvent => HotReloadEvent.initEmpty(owner)
    return WatcherAtomics(
        events: [mkEvent(), mkEvent(), mkEvent()],
        nextEvent: NextEvent.done,
        currentEvent: None,
        pendingEvent: None,
    )
}
