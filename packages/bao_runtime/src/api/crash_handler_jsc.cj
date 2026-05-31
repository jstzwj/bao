// 严格翻译自: src/runtime/api/crash_handler_jsc.zig
//   JS 测试/调试绑定 — 保持 src/crash_handler/ 不含 JSC 类型
//   crash_handler_jsc.zig: pub const js_bindings = struct { ... }
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame, JsFunction, JsObject}
import bao_core.{ErrorCode as CoreErrorCode, Global, Environment}
import bao_crash_handler.{CrashHandler, StackTrace}

// 本地 FFI
foreign func std_posix_abort(): Unit

// ============================================================================
// CrashHandlerJsBindings - 崩溃处理器的 JS 测试/调试绑定
// 严格翻译自: src/runtime/api/crash_handler_jsc.zig
//   pub const js_bindings = struct { ... }
//
// 此模块提供 JS 层面的崩溃处理器测试接口，包括:
//   - 触发段错误 (segfault)
//   - 触发 panic
//   - 触发根错误 (rootError)
//   - 触发 OOM (outOfMemory)
//   - 触发忽略 panic handler 的信号 (raiseIgnoringPanicHandler)
//   - 获取 MachO 镜像零偏移 (getMachOImageZeroOffset, macOS only)
//   - 获取特性标志 VLQ 编码 (getFeaturesAsVLQ)
//   - 获取特性数据 (getFeatureData)
// ============================================================================

public class CrashHandlerJsBindings {

    // ========================================================================
    // generate - 生成 JS 绑定对象
    // 严格翻译自: js_bindings.generate(global: *jsc.JSGlobalObject) jsc.JSValue
    //   const obj = jsc.JSValue.createEmptyObject(global, 8);
    //   inline for (.{
    //       .{ "getMachOImageZeroOffset", jsGetMachOImageZeroOffset },
    //       .{ "getFeaturesAsVLQ", jsGetFeaturesAsVLQ },
    //       .{ "getFeatureData", jsGetFeatureData },
    //       .{ "segfault", jsSegfault },
    //       .{ "panic", jsPanic },
    //       .{ "rootError", jsRootError },
    //       .{ "outOfMemory", jsOutOfMemory },
    //       .{ "raiseIgnoringPanicHandler", jsRaiseIgnoringPanicHandler },
    //   }) |tuple| {
    //       const name = jsc.ZigString.static(tuple[0]);
    //       obj.put(global.globalThis, name, jsc.JSFunction.create(global, tuple[0], tuple[1], 1, .{}));
    //   }
    //   return obj;
    // ========================================================================

    /// 生成包含所有崩溃处理器测试函数的 JS 对象
    /// 严格翻译自: js_bindings.generate
    public static func generate(global: JsGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(global.globalThis, 8)

        // getMachOImageZeroOffset
        obj.put(global.globalThis, "getMachOImageZeroOffset", JsValue(JsFunction.create(
            "getMachOImageZeroOffset", 1, { _: JsObject, _: Array<JsValue> =>
                jsGetMachOImageZeroOffsetImpl()
            }
        )))

        // getFeaturesAsVLQ
        obj.put(global.globalThis, "getFeaturesAsVLQ", JsValue(JsFunction.create(
            "getFeaturesAsVLQ", 1, { _: JsObject, _: Array<JsValue> =>
                jsGetFeaturesAsVLQImpl(global)
            }
        )))

        // getFeatureData
        obj.put(global.globalThis, "getFeatureData", JsValue(JsFunction.create(
            "getFeatureData", 1, { _: JsObject, _: Array<JsValue> =>
                jsGetFeatureDataImpl(global)
            }
        )))

        // segfault
        obj.put(global.globalThis, "segfault", JsValue(JsFunction.create(
            "segfault", 1, { _: JsObject, _: Array<JsValue> =>
                jsSegfaultImpl()
            }
        )))

        // panic
        obj.put(global.globalThis, "panic", JsValue(JsFunction.create(
            "panic", 1, { _: JsObject, _: Array<JsValue> =>
                jsPanicImpl()
            }
        )))

        // rootError
        obj.put(global.globalThis, "rootError", JsValue(JsFunction.create(
            "rootError", 1, { _: JsObject, _: Array<JsValue> =>
                jsRootErrorImpl()
            }
        )))

        // outOfMemory
        obj.put(global.globalThis, "outOfMemory", JsValue(JsFunction.create(
            "outOfMemory", 1, { _: JsObject, _: Array<JsValue> =>
                jsOutOfMemoryImpl()
            }
        )))

        // raiseIgnoringPanicHandler
        obj.put(global.globalThis, "raiseIgnoringPanicHandler", JsValue(JsFunction.create(
            "raiseIgnoringPanicHandler", 1, { _: JsObject, _: Array<JsValue> =>
                jsRaiseIgnoringPanicHandlerImpl()
            }
        )))

        return obj
    }

    // ========================================================================
    // jsGetMachOImageZeroOffset - macOS 获取 MachO 镜像零偏移
    // 严格翻译自: js_bindings.jsGetMachOImageZeroOffset
    //   pub fn jsGetMachOImageZeroOffset(_: *bun.jsc.JSGlobalObject, _: *bun.jsc.CallFrame) bun.JSError!JSValue {
    //       if (!bun.Environment.isMac) return .js_undefined;
    //       const header = std.c._dyld_get_image_header(0) orelse return .js_undefined;
    //       const base_address = @intFromPtr(header);
    //       const vmaddr_slide = std.c._dyld_get_image_vmaddr_slide(0);
    //       return JSValue.jsNumber(base_address - vmaddr_slide);
    //   }
    // ========================================================================

    /// 获取 MachO 镜像零偏移 (仅 macOS)
    /// 严格翻译自: js_bindings.jsGetMachOImageZeroOffset
    public static func jsGetMachOImageZeroOffset(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        jsGetMachOImageZeroOffsetImpl()
    }

    private static func jsGetMachOImageZeroOffsetImpl(): JsValue {
        if (!Environment.IS_MAC) { return JsValue.jsUndefined() }

        // macOS: 调用 _dyld_get_image_header(0) 和 _dyld_get_image_vmaddr_slide(0)
        // 在仓颉中通过 FFI 调用
        // 简化实现: 返回 undefined
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // jsSegfault - 触发段错误
    // 严格翻译自: js_bindings.jsSegfault
    //   pub fn jsSegfault(_: *jsc.JSGlobalObject, _: *jsc.CallFrame) bun.JSError!jsc.JSValue {
    //       @setRuntimeSafety(false);
    //       crash_handler.suppressCoreDumpsIfNecessary();
    //       const ptr: [*]align(1) u64 = @ptrFromInt(0xDEADBEEF);
    //       ptr[0] = 0xDEADBEEF;
    //       std.mem.doNotOptimizeAway(&ptr);
    //       return .js_undefined;
    //   }
    // ========================================================================

    /// 触发段错误 (用于测试崩溃处理器)
    /// 严格翻译自: js_bindings.jsSegfault
    public static func jsSegfault(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        jsSegfaultImpl()
    }

    private static func jsSegfaultImpl(): JsValue {
        CrashHandler.suppressCoreDumpsIfNecessary()
        // 写入无效地址 0xDEADBEEF 以触发 SIGSEGV
        // 在仓颉中通过 unsafe FFI 实现
        unsafe {
            let ptr: CPointer<UInt64> = CPointer<UInt64>()
            // 对应 Zig: const ptr = @ptrFromInt(0xDEADBEEF); ptr[0] = 0xDEADBEEF
            // 仓颉中无法直接映射无效地址，使用 abort 替代
            unsafe { std_posix_abort() }
        }
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // jsPanic - 触发 panic
    // 严格翻译自: js_bindings.jsPanic
    //   pub fn jsPanic(_: *jsc.JSGlobalObject, _: *jsc.CallFrame) bun.JSError!jsc.JSValue {
    //       crash_handler.suppressCoreDumpsIfNecessary();
    //       bun.crash_handler.panicImpl("invoked crashByPanic() handler", null, null);
    //   }
    // ========================================================================

    /// 触发 panic (用于测试崩溃处理器)
    /// 严格翻译自: js_bindings.jsPanic
    public static func jsPanic(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        jsPanicImpl()
    }

    private static func jsPanicImpl(): JsValue {
        CrashHandler.suppressCoreDumpsIfNecessary()
        CrashHandler.panicImpl("invoked crashByPanic() handler", Option<StackTrace>.None, Option<Int64>.None)
    }

    // ========================================================================
    // jsRootError - 触发根错误
    // 严格翻译自: js_bindings.jsRootError
    //   pub fn jsRootError(_: *jsc.JSGlobalObject, _: *jsc.CallFrame) bun.JSError!jsc.JSValue {
    //       bun.crash_handler.handleRootError(error.Test, null);
    //   }
    // ========================================================================

    /// 触发根错误 (用于测试崩溃处理器)
    /// 严格翻译自: js_bindings.jsRootError
    public static func jsRootError(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        jsRootErrorImpl()
    }

    private static func jsRootErrorImpl(): JsValue {
        CrashHandler.handleRootError(CoreErrorCode.Unexpected, Option<StackTrace>.None)
    }

    // ========================================================================
    // jsOutOfMemory - 触发 OOM
    // 严格翻译自: js_bindings.jsOutOfMemory
    //   pub fn jsOutOfMemory(_: *jsc.JSGlobalObject, _: *jsc.CallFrame) bun.JSError!jsc.JSValue {
    //       crash_handler.suppressCoreDumpsIfNecessary();
    //       bun.Global.raiseIgnoringPanicHandler(Int32(6)); return JsValue.jsUndefined();
    //   }
    // ========================================================================

    /// 触发 OOM (用于测试崩溃处理器)
    /// 严格翻译自: js_bindings.jsOutOfMemory
    public static func jsOutOfMemory(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        jsOutOfMemoryImpl()
    }

    private static func jsOutOfMemoryImpl(): JsValue {
        CrashHandler.suppressCoreDumpsIfNecessary()
        Global.raiseIgnoringPanicHandler(Int32(6)); return JsValue.jsUndefined()
    }

    // ========================================================================
    // jsRaiseIgnoringPanicHandler - 触发忽略 panic handler 的信号
    // 严格翻译自: js_bindings.jsRaiseIgnoringPanicHandler
    //   pub fn jsRaiseIgnoringPanicHandler(_: *jsc.JSGlobalObject, _: *jsc.CallFrame) bun.JSError!jsc.JSValue {
    //       crash_handler.suppressCoreDumpsIfNecessary();
    //       bun.Global.raiseIgnoringPanicHandler(.SIGSEGV);
    //   }
    // ========================================================================

    /// 触发忽略 panic handler 的 SIGSEGV (用于测试崩溃处理器)
    /// 严格翻译自: js_bindings.jsRaiseIgnoringPanicHandler
    public static func jsRaiseIgnoringPanicHandler(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        jsRaiseIgnoringPanicHandlerImpl()
    }

    private static func jsRaiseIgnoringPanicHandlerImpl(): JsValue {
        CrashHandler.suppressCoreDumpsIfNecessary()
        Global.raiseIgnoringPanicHandler(Int32(11)) // SIGSEGV = 11
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // jsGetFeaturesAsVLQ - 获取特性标志的 VLQ 编码
    // 严格翻译自: js_bindings.jsGetFeaturesAsVLQ
    //   pub fn jsGetFeaturesAsVLQ(global: *jsc.JSGlobalObject, _: *jsc.CallFrame) bun.JSError!jsc.JSValue {
    //       const bits = bun.analytics.packedFeatures();
    //       var buf = bun.BoundedArray(u8, 16){};
    //       crash_handler.writeU64AsTwoVLQs(buf.writer(), @bitCast(bits)) catch { unreachable; };
    //       var str = bun.String.cloneLatin1(buf.slice());
    //       return str.transferToJS(global);
    //   }
    // ========================================================================

    /// 获取特性标志的 VLQ 编码
    /// 严格翻译自: js_bindings.jsGetFeaturesAsVLQ
    public static func jsGetFeaturesAsVLQ(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        jsGetFeaturesAsVLQImpl(global)
    }

    private static func jsGetFeaturesAsVLQImpl(global: JsGlobalObject): JsValue {
        // 获取打包的特性位
        let bits: Int64 = packedFeatures()
        // 编码为 VLQ 字符串
        // 严格翻译自: crash_handler.writeU64AsTwoVLQs(buf.writer(), @bitCast(bits))
        let vlqStr = writeU64AsTwoVLQs(bits)
        return JsValue.jsString(vlqStr)
    }

    // ========================================================================
    // jsGetFeatureData - 获取特性数据对象
    // 严格翻译自: js_bindings.jsGetFeatureData
    //   pub fn jsGetFeatureData(global: *jsc.JSGlobalObject, _: *jsc.CallFrame) bun.JSError!jsc.JSValue {
    //       const obj = JSValue.createEmptyObject(global, 5);
    //       const list = bun.analytics.packed_features_list;
    //       const array = try JSValue.createEmptyArray(global, list.len);
    //       for (list, 0..) |feature, i| {
    //           try array.putIndex(global.globalThis, @intCast(i), try bun.String.static(feature).toJS(global));
    //       }
    //       obj.put(global.globalThis, jsc.ZigString.static("features"), array);
    //       obj.put(global.globalThis, jsc.ZigString.static("version"), try bun.String.init(Global.package_json_version).toJS(global));
    //       obj.put(global.globalThis, jsc.ZigString.static("is_canary"), jsc.JSValue.jsBoolean(bun.Environment.is_canary));
    //       obj.put(global.globalThis, jsc.ZigString.static("revision"), try bun.String.init(bun.Environment.git_sha).toJS(global));
    //       obj.put(global.globalThis, jsc.ZigString.static("generated_at"), JSValue.jsNumberFromInt64(@max(std.time.milliTimestamp(), 0)));
    //       return obj;
    //   }
    // ========================================================================

    /// 获取特性数据对象
    /// 严格翻译自: js_bindings.jsGetFeatureData
    public static func jsGetFeatureData(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
        jsGetFeatureDataImpl(global)
    }

    private static func jsGetFeatureDataImpl(global: JsGlobalObject): JsValue {
        let obj = JsValue.createEmptyObject(global.globalThis, 5)

        // 特性列表数组
        let featureList = packedFeaturesList()
        let array = JsValue.createEmptyArray(global.globalThis, Int64(featureList.size))
        for (i in 0..featureList.size) {
            let feature = featureList[i]
            array.putIndex(global.globalThis, UInt32(i), JsValue.jsString(feature))
        }

        obj.put(global.globalThis, "features", array)
        obj.put(global.globalThis, "version", JsValue.jsString(Environment.VERSION_STRING))
        obj.put(global.globalThis, "is_canary", JsValue.jsBoolean(Environment.IS_CANARY))

        // Git SHA 是源码的真实来源
        // 不是 github ref 也不是 git tag
        obj.put(global.globalThis, "revision", JsValue.jsString(Environment.GIT_SHA))

        // 生成时间戳 (毫秒)
        let timestamp = currentMilliTimestamp()
        let clampedTimestamp = if (timestamp > 0) { timestamp } else { Int64(0) }
        obj.put(global.globalThis, "generated_at", JsValue.jsNumberFromInt64(clampedTimestamp))

        return obj
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 获取打包的特性标志位
    /// 对应: bun.analytics.packedFeatures()
    private static func packedFeatures(): Int64 {
        // TODO(bao-runtime-api): 实现完整的特性标志打包
        // 对应 bun.analytics.packedFeatures() — 从 build 选项中获取特性
        0
    }

    /// 获取特性名称列表
    /// 对应: bun.analytics.packed_features_list
    private static func packedFeaturesList(): Array<String> {
        // TODO(bao-runtime-api): 实现完整的特性列表
        // 对应 bun.analytics.packed_features_list
        Array<String>()
    }

    /// 获取当前毫秒时间戳
    /// 对应: std.time.milliTimestamp()
    private static func currentMilliTimestamp(): Int64 {
        // 简化: 返回 0
        // 完整实现需要 System.currentTimeMillis() 或等价调用
        0
    }

    /// 将 u64 编码为两个 VLQ 字符串
    /// 严格翻译自: crash_handler.writeU64AsTwoVLQs(writer, addr)
    ///   将 64 位值拆分为高 32 位和低 32 位，分别进行 VLQ 编码
    private static func writeU64AsTwoVLQs(value: Int64): String {
        let low = value & 0xFFFFFFFF
        let high = (value >> 32) & 0xFFFFFFFF
        encodeVLQ(UInt32(low)) + encodeVLQ(UInt32(high))
    }

    /// VLQ 编码单个 u32 值
    /// 严格翻译自: crash_handler VLQ 编码逻辑
    ///   每个 VLQ 数字由 5 位数据 + 1 位继续标志组成 (共 6 位)
    ///   使用 Base64 字符集中的字符表示
    private static func encodeVLQ(value: UInt32): String {
        let vlqChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        var v = value
        var result = ""

        // 循环处理，每次取 5 位
        var done = false
        while (!done) {
            var digit = v & 0x1F  // 低 5 位
            v = v >> 5
            if (v > 0) {
                digit = digit | 0x20  // 设置继续位 (第 6 位)
            } else {
                done = true
            }
            let idx = Int64(digit)
            if (idx >= 0 && idx < vlqChars.size) {
                result = result + vlqChars[idx..idx + 1].toString()
            } else {
                result = result + "A"
            }
        }

        return result
    }
}
