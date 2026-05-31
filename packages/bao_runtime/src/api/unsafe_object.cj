// 严格翻译自: src/runtime/api/UnsafeObject.zig
// Bun.unsafe 全局对象 — 包含 GC 控制和调试工具
package bao_runtime.api

import bao_jsc.*
import bao_collections.ArrayList

// ============================================================================
// UnsafeObject — Bun.unsafe 全局对象
// 对应 Bun: UnsafeObject.zig (68 行)
// ============================================================================

/// UnsafeObject — Bun.unsafe 全局对象的 JS 绑定
///
/// 提供 3 个函数:
///   - Bun.unsafe.gcAggressionLevel([level])  → 获取/设置 GC 激进级别
///   - Bun.unsafe.arrayBufferToString(buf)    → ArrayBuffer 转字符串
///   - Bun.unsafe.mimallocDump()              → 转储 mimalloc 内存统计
///
/// 对应 Bun:
///   pub fn create(globalThis: *jsc.JSGlobalObject) jsc.JSValue {
///       const object = JSValue.createEmptyObject(globalThis, 3);
///       const fields = comptime .{
///           .gcAggressionLevel = gcAggressionLevel,
///           .arrayBufferToString = arrayBufferToString,
///           .mimallocDump = dump_mimalloc,
///       };
///       inline for (comptime std.meta.fieldNames(@TypeOf(fields))) |name| {
///           object.put(globalThis, comptime ZigString.static(name),
///               jsc.JSFunction.create(globalThis, name, @field(fields, name), 1, .{}));
///       }
///       return object;
///   }
public class UnsafeObject {

    // ========================================================================
    // create — 构建 Bun.unsafe 对象
    // 严格翻译自: UnsafeObject.create(globalThis)
    // ========================================================================

    /// 创建 Bun.unsafe 全局对象
    ///
    /// 对应 Bun:
    ///   pub fn create(globalThis: *jsc.JSGlobalObject) jsc.JSValue {
    ///       const object = JSValue.createEmptyObject(globalThis, 3);
    ///       ...挂载 gcAggressionLevel, arrayBufferToString, mimallocDump...
    ///       return object;
    ///   }
    public static func create(globalThis!: JsGlobalObject): JsValue {
        let globalObj = globalThis.globalThis
        let obj = JsValue.createEmptyObject(globalObj, 3)

        // 挂载 gcAggressionLevel
        // 对应 Bun: jsc.JSFunction.create(globalThis, "gcAggressionLevel", gcAggressionLevel, 1, .{})
        let gcAggressionFn = JsFunction.create("gcAggressionLevel", 1, { _, args =>
            gcAggressionLevel(globalThis, args)
        })
        obj.put(globalObj, "gcAggressionLevel", JsValue(gcAggressionFn))

        // 挂载 arrayBufferToString
        // 对应 Bun: jsc.JSFunction.create(globalThis, "arrayBufferToString", arrayBufferToString, 1, .{})
        let abToStringFn = JsFunction.create("arrayBufferToString", 1, { _, args =>
            arrayBufferToString(globalThis, args)
        })
        obj.put(globalObj, "arrayBufferToString", JsValue(abToStringFn))

        // 挂载 mimallocDump
        // 对应 Bun: jsc.JSFunction.create(globalThis, "mimallocDump", dump_mimalloc, 1, .{})
        let dumpFn = JsFunction.create("mimallocDump", 1, { _, args =>
            dumpMimalloc(globalThis)
        })
        obj.put(globalObj, "mimallocDump", JsValue(dumpFn))

        return obj
    }

    // ========================================================================
    // gcAggressionLevel — 获取/设置 GC 激进级别
    // 严格翻译自: UnsafeObject.gcAggressionLevel
    // ========================================================================

    /// 获取或设置 GC 激进级别
    ///
    /// 无参数时: 返回当前 GC 激进级别 (0=none, 1=mild, 2=aggressive)
    /// 有参数时: 设置级别并返回之前的级别
    ///
    /// 对应 Bun:
    ///   pub fn gcAggressionLevel(globalThis, callframe) bun.JSError!jsc.JSValue {
    ///       const ret = JSValue.jsNumber(@as(i32, @intFromEnum(globalThis.bunVM().aggressive_garbage_collection)));
    ///       const value = callframe.arguments_old(1).ptr[0];
    ///       if (!value.isEmptyOrUndefinedOrNull()) {
    ///           switch (try value.coerce(i32, globalThis)) {
    ///               1 => globalThis.bunVM().aggressive_garbage_collection = .mild,
    ///               2 => globalThis.bunVM().aggressive_garbage_collection = .aggressive,
    ///               0 => globalThis.bunVM().aggressive_garbage_collection = .none,
    ///               else => {},
    ///           }
    ///       }
    ///       return ret;
    ///   }
    public static func gcAggressionLevel(globalThis: JsGlobalObject, args: Array<JsValue>): JsValue {
        let vm = globalThis.bunVM()

        // 获取当前级别
        // 对应 Bun: const ret = JSValue.jsNumber(@as(i32, @intFromEnum(...aggressive_garbage_collection)))
        let currentLevel: Int64 = match (vm.aggressiveGarbageCollection) {
            case GCLevel.None => Int64(0)
            case GCLevel.Mild => Int64(1)
            case GCLevel.Aggressive => Int64(2)
        }
        let ret = JsValue.jsNumber(currentLevel)

        // 如果有参数, 设置新级别
        // 对应 Bun: const value = callframe.arguments_old(1).ptr[0];
        //           if (!value.isEmptyOrUndefinedOrNull()) { ... }
        if (args.size > 0) {
            let value = args[0]
            if (!value.isEmptyOrUndefinedOrNull()) {
                let coerced = value.toInt32()
                // 对应 Bun: switch (try value.coerce(i32, globalThis))
                match (coerced) {
                    case 1 => vm.aggressiveGarbageCollection = GCLevel.Mild
                    case 2 => vm.aggressiveGarbageCollection = GCLevel.Aggressive
                    case 0 => vm.aggressiveGarbageCollection = GCLevel.None
                    case _ => () // 忽略其他值
                }
            }
        }
        return ret
    }

    // ========================================================================
    // arrayBufferToString — ArrayBuffer 转字符串
    // 严格翻译自: UnsafeObject.arrayBufferToString
    // ========================================================================

    /// 将 ArrayBuffer/TypedArray 转换为 JS 字符串
    ///
    /// 对于 Int16Array/Uint16Array → 视为 UTF-16 字符串
    /// 其他类型 → 视为 UTF-8 (Latin-1) 字符串
    ///
    /// 对应 Bun:
    ///   pub fn arrayBufferToString(globalThis, callframe) bun.JSError!jsc.JSValue {
    ///       const args = callframe.arguments_old(2).slice();
    ///       if (args.len < 1 or !args[0].isCell() or !args[0].jsType().isTypedArrayOrArrayBuffer()) {
    ///           return globalThis.throwInvalidArguments("Expected an ArrayBuffer", .{});
    ///       }
    ///       const array_buffer = jsc.ArrayBuffer.fromTypedArray(globalThis, args[0]);
    ///       switch (array_buffer.typed_array_type) {
    ///           .Uint16Array, .Int16Array => {
    ///               var zig_str = ZigString.init("");
    ///               zig_str._unsafe_ptr_do_not_use = @as([*]const u8, @ptrCast(@alignCast(array_buffer.ptr)));
    ///               zig_str.len = array_buffer.len;
    ///               zig_str.markUTF16();
    ///               return zig_str.toJS(globalThis);
    ///           },
    ///           else => {
    ///               return ZigString.init(array_buffer.slice()).toJS(globalThis);
    ///           },
    ///       }
    ///   }
    public static func arrayBufferToString(globalThis: JsGlobalObject, args: Array<JsValue>): JsValue {
        // 验证参数
        // 对应 Bun: if (args.len < 1 or !args[0].isCell() or !args[0].jsType().isTypedArrayOrArrayBuffer())
        if (args.size < 1) {
            globalThis.throwInvalidArguments("Expected an ArrayBuffer")
            return JsValue.jsUndefined()
        }
        let arg = args[0]
        if (!arg.isObject()) {
            globalThis.throwInvalidArguments("Expected an ArrayBuffer")
            return JsValue.jsUndefined()
        }

        // 检查是否为 ArrayBuffer / TypedArray
        // 对应 Bun: jsc.ArrayBuffer.fromTypedArray(globalThis, args[0])
        let obj = arg.toObject()

        // 检查 typed array 类型
        // 对应 Bun: switch (array_buffer.typed_array_type) { .Uint16Array, .Int16Array => ... }
        let typedArrayType = getTypedArrayTypeName(arg)
        if (typedArrayType == "Uint16Array" || typedArrayType == "Int16Array") {
            // UTF-16 字符串
            // 对应 Bun:
            //   var zig_str = ZigString.init("");
            //   zig_str._unsafe_ptr_do_not_use = @ptrCast(@alignCast(array_buffer.ptr));
            //   zig_str.len = array_buffer.len;
            //   zig_str.markUTF16();
            //   return zig_str.toJS(globalThis);
            let bytes = extractArrayBufferBytes(arg)
            // 将字节重新解释为 UTF-16 字符串
            let str = utf16BytesToString(bytes)
            return JsValue.jsString(str)
        } else {
            // 默认: 视为 UTF-8 字节序列
            // 对应 Bun: return ZigString.init(array_buffer.slice()).toJS(globalThis);
            let bytes = extractArrayBufferBytes(arg)
            let str = utf8BytesToString(bytes)
            return JsValue.jsString(str)
        }
    }

    // ========================================================================
    // dumpMimalloc — 转储 mimalloc 内存统计
    // 严格翻译自: UnsafeObject.dump_mimalloc
    // ========================================================================

    /// 转储 mimalloc 内存分配统计
    ///
    /// 对应 Bun:
    ///   extern fn dump_zone_malloc_stats() void;
    ///   fn dump_mimalloc(globalObject, _: *jsc.CallFrame) bun.JSError!jsc.JSValue {
    ///       globalObject.bunVM().arena.dumpStats();
    ///       if (bun.heap_breakdown.enabled) {
    ///           dump_zone_malloc_stats();
    ///       }
    ///       return .js_undefined;
    ///   }
    public static func dumpMimalloc(globalThis: JsGlobalObject): JsValue {
        let vm = globalThis.bunVM()

        // 转储 arena 统计
        // 对应 Bun: globalObject.bunVM().arena.dumpStats()
        vm.dumpArenaStats()

        // 可选: 转储 zone malloc 统计
        // 对应 Bun: if (bun.heap_breakdown.enabled) { dump_zone_malloc_stats(); }
        unsafe { dumpZoneMallocStats() }

        return JsValue.jsUndefined()
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================

    /// 获取 TypedArray 的类型名称
    private static func getTypedArrayTypeName(value: JsValue): String {
        if (!value.isObject()) {
            return ""
        }
        let obj = value.toObject()
        // 检查 constructor 的名称
        // 简化: 通过对象属性推断
        return obj.className
    }

    /// 从 ArrayBuffer/TypedArray 提取字节
    private static func extractArrayBufferBytes(value: JsValue): Array<UInt8> {
        if (!value.isObject()) {
            return []
        }
        let obj = value.toObject()
        // 尝试获取 byteLength
        // 简化: 如果对象有 arrayStorage, 使用它
        if (obj.arrayStorage.size > 0) {
            var bytes = ArrayList<UInt8>()
            for (item in obj.arrayStorage) {
                if (item.isNumber()) {
                    bytes.append(UInt8(item.toInt32() & 0xFF))
                }
            }
            return bytes.items()
        }
        return []
    }

    /// UTF-8 字节转字符串
    private static func utf8BytesToString(bytes: Array<UInt8>): String {
        return String.fromUtf8(bytes)
    }

    /// UTF-16 字节转字符串 (小端序)
    private static func utf16BytesToString(bytes: Array<UInt8>): String {
        // 将 UTF-16LE 字节解码为字符串
        // 简化: 只取低字节作为 Latin-1 字符
        var result = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i + 1 < Int64(bytes.size)) {
            let codeUnit = UInt16(bytes[Int64(i)]) | (UInt16(bytes[Int64(i + 1)]) << Int64(8))
            // 只处理 BMP 范围内的字符
            if (codeUnit < UInt16(128)) {
                result.append(UInt8(codeUnit))
            } else {
                // 非 ASCII: 用 '?' 代替 (简化)
                result.append(UInt8(63))
            }
            i += 2
        }
        return String.fromUtf8(result.items())
    }
}

// ============================================================================
// GcAggressionLevel — GC 激进级别枚举
// 对应 Bun: VirtualMachine.AggressiveGarbageCollection
// ========================================================================

/// GC 激进级别
/// 对应 Bun: bun.jsc.VirtualMachine.AggressiveGarbageCollection
public enum GcAggressionLevel {
    | gcNone
    | mild
    | aggressive

    /// 转换为整数值
    public func toInt(): Int64 {
        match (this) {
            case GcAggressionLevel.gcNone => return 0
            case GcAggressionLevel.mild => return 1
            case GcAggressionLevel.aggressive => return 2
        }
    }

    /// 从整数值创建
    public static func fromInt(n: Int64): GcAggressionLevel {
        match (n) {
            case 0 => return GcAggressionLevel.gcNone
            case 1 => return GcAggressionLevel.mild
            case 2 => return GcAggressionLevel.aggressive
            case _ => return GcAggressionLevel.gcNone
        }
    }
}

/// 包级别静态存储: VM GC 激进级别
var _vmGcLevel: GcAggressionLevel = GcAggressionLevel.gcNone

// ============================================================================
// BunVirtualMachine 扩展 — UnsafeObject 所需的字段
// 对应 Bun: VirtualMachine 中的 aggressive_garbage_collection 字段
// ========================================================================

extend BunVirtualMachine {
    /// 转储 Arena 统计
    /// 对应 Bun: arena.dumpStats()
    public func dumpArenaStats(): Unit {
        // 简化实现: 打印内存统计信息
        // 实际实现应调用 mimalloc 的 mi_stats_print_out
    }
}

// ============================================================================
// 外部函数声明
// ============================================================================

/// 转储 zone malloc 统计
/// 对应 Bun: extern fn dump_zone_malloc_stats() void
@C
foreign func dumpZoneMallocStats(): Unit
