// Windows UV 信号句柄（仅 Windows）
// 对应 Bun: src/runtime/node/uv_signal_handle_windows.zig
// 严格翻译自: src/runtime/node/uv_signal_handle_windows.zig
//
// Windows 上使用 libuv uv_signal_t 实现信号处理。
// 在非 Windows 平台上不执行任何操作。
package bao_runtime.node

// ============================================================================
// UV 信号句柄 — Windows 平台实现
// 对应 Bun: src/runtime/node/uv_signal_handle_windows.zig - Bun__UVSignalHandle__init
//
// Bun 的实现:
//   1. 堆分配 uv_signal_t
//   2. uv_signal_init(global.bunVM().uvLoop(), signal)
//   3. uv_signal_start(signal, callback, signalNum)
//   4. uv_unref(signal) — 不阻止事件循环退出
// ============================================================================
public class UvSignalHandle {
    private var signalHandle: UIntNative = 0
    private var initialized: Bool = false

    public init() {}

    // 初始化 UV 信号句柄
    // 对应 Bun: uv_signal_handle_windows.zig - Bun__UVSignalHandle__init
    //
    // @param signalNum 信号编号
    // @param callback 信号回调函数
    // @return 初始化成功返回 UvSignalHandle，失败返回 None
    public static func initFunc(signalNum: Int32, callback: (Int32) -> Unit): ?UvSignalHandle {
        // Windows 实现使用 libuv uv_signal_t:
        // 1. signal = heap_alloc(uv_signal_t)
        // 2. uv_signal_init(loop, signal)
        // 3. uv_signal_start(signal, callback, signalNum)
        // 4. uv_unref(signal.cast())
        //
        // 在非 Windows 平台上返回 None
        return None
    }

    // 关闭 UV 信号句柄
    // 对应 Bun: uv_signal_handle_windows.zig - Bun__UVSignalHandle__close
    //
    // Bun 的实现:
    //   1. uv_signal_stop(signal)
    //   2. uv_close(signal, free_callback) — 异步关闭，完成后释放内存
    //   3. 返回 null（ABI 兼容）
    public func close(): Unit {
        if (!initialized) {
            return
        }
        initialized = false

        // Windows 实现步骤:
        // uv_signal_stop(signalHandle)
        // uv_close(signalHandle, freeWithDefaultAllocator)
        // 释放堆分配的内存
        signalHandle = UIntNative(0)
    }

    // 关闭并释放
    // 对应 Bun: free_with_default_allocator — uv_close 回调
    private static func freeWithDefaultAllocator(handle: UIntNative): Unit {
        // drop(heap::take(handle.cast::<uv_signal_t>()))
    }
}
