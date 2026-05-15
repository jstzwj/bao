// bao_watcher - 跨平台文件系统监视器
// 严格翻译自:
//   src/watcher/Watcher.zig       - Watcher 主结构 (跨平台抽象)
//   src/watcher/WatcherTrace.zig  - 调试/追踪日志
//   src/watcher/INotifyWatcher.zig - Linux inotify 实现
//   src/watcher/KEventWatcher.zig  - BSD/macOS kqueue 实现 (参考, 不翻译)
//
// Bun 的 Watcher 架构:
//   - Watcher 是跨平台文件监视器的顶层结构
//   - 通过 comptime 选择 Platform 实现: Linux → INotifyWatcher, macOS → KEventWatcher
//   - 在独立线程中运行 watchLoop, 通过回调通知文件变更
//   - WatchList 使用 MultiArrayList<WatchItem> 存储监视项
//   - 支持文件和目录监视, 以及自动监视父目录
//   - WatcherTrace 可选地将事件写入 JSON 文件用于调试
package bao_watcher

import bao_core.*
import bao_sys.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// 公共导出 - 对应 Bun src/watcher/Watcher.zig 中的 pub const
// 严格翻译自:
//   pub const Event = WatchEvent;
//   pub const Item = WatchItem;
//   pub const ItemList = WatchList;
//   pub const HashType = u32;
// ============================================================================

// -- watcher_event.cj --
// WatcherEventOp, WatcherEvent, WatchItem, WatchItemKind
// FileChangeCallback, ErrorCallback

// -- watcher.cj --
// Watcher 主类 (跨平台文件监视器)
// start, stop, deinit, addFile, addDirectory, remove, flushEvictions

// -- inotify_watcher.cj --
// InotifyWatcher (Linux inotify 实现)
// InotifyEvent (inotify_event C 结构映射)
// watchPath, watchDir, unwatch, read, stop

// -- watcher_trace.cj --
// WatcherTrace (调试追踪)
// init, writeEvents, deinit
