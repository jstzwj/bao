// 文件系统事件 — macOS FSEvents 类型定义
// 对应 Bun: src/runtime/node/fs_events.zig
// 严格翻译自: src/runtime/node/fs_events.zig
package bao_runtime.node

// ============================================================================
// FSEvents 类型定义
// 对应 Bun: src/runtime/node/fs_events.zig - 常量和类型
// ============================================================================
public class FsEventConstants {
    // FSEventStreamCreateFlags
    public static let kFSEventStreamCreateFlagNoDefer: Int32 = 2
    public static let kFSEventStreamCreateFlagFileEvents: Int32 = 16

    // FSEventStreamEventFlags
    public static let kFSEventStreamEventFlagEventIdsWrapped: Int32 = 8
    public static let kFSEventStreamEventFlagHistoryDone: Int32 = 16
    public static let kFSEventStreamEventFlagItemChangeOwner: Int32 = 0x4000
    public static let kFSEventStreamEventFlagItemCreated: Int32 = 0x100
    public static let kFSEventStreamEventFlagItemFinderInfoMod: Int32 = 0x2000
    public static let kFSEventStreamEventFlagItemInodeMetaMod: Int32 = 0x400
    public static let kFSEventStreamEventFlagItemIsDir: Int32 = 0x20000
    public static let kFSEventStreamEventFlagItemModified: Int32 = 0x1000
    public static let kFSEventStreamEventFlagItemRemoved: Int32 = 0x200
    public static let kFSEventStreamEventFlagItemRenamed: Int32 = 0x800
    public static let kFSEventStreamEventFlagItemXattrMod: Int32 = 0x4000
    public static let kFSEventStreamEventFlagKernelDropped: Int32 = 0x80
    public static let kFSEventStreamEventFlagKernelReset: Int32 = 0x200000
    public static let kFSEventStreamEventFlagMount: Int32 = 0x40
    public static let kFSEventStreamEventFlagRootChanged: Int32 = 0x20
    public static let kFSEventStreamEventFlagUnmount: Int32 = 0x80
    public static let kFSEventStreamEventFlagUserDropped: Int32 = 0x1

    // CFStringEncoding
    public static let kCFStringEncodingUTF8: UInt32 = 0x8000100

    // noErr
    public static let noErr: Int32 = 0
}
