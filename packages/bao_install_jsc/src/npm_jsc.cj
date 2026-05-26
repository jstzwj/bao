// 严格翻译自: src/install_jsc/npm_jsc.zig
//! JSC host fns extracted from `src/install/npm.zig`.
package bao_install_jsc

import bao_jsc.*
import bao_collections.*
import bao_install.*

// ============================================================================
// NpmJSC - NPM 的 JSC 桥接
// ============================================================================

/// 操作系统匹配
public func operatingSystemIsMatch(globalObject: JSGlobalObject, callframe: CallFrame): JsValue {
    let values = collectStringArray(globalObject, callframe.argument(0))
    let operatingSystem = OperatingSystem.fromJsonArray(values)
    return JsValue.jsBoolean(operatingSystem.isMatch(OperatingSystem.current))
}

/// Libc 匹配
public func libcIsMatch(globalObject: JSGlobalObject, callframe: CallFrame): JsValue {
    let values = collectStringArray(globalObject, callframe.argument(0))
    let libc = LibcType.fromJsonArray(values)
    return JsValue.jsBoolean(libc.isMatch(LibcType.current))
}

/// 架构匹配
public func architectureIsMatch(globalObject: JSGlobalObject, callframe: CallFrame): JsValue {
    let values = collectStringArray(globalObject, callframe.argument(0))
    let architecture = Architecture.fromJsonArray(values)
    return JsValue.jsBoolean(architecture.isMatch(Architecture.current))
}

/// Manifest 绑定
public class ManifestBindings {
    /// 生成绑定对象
    public static func generate(global: JSGlobalObject): JsValue {
        let obj = JsObject.make()
        obj.set("parseManifest", JsValue("parseManifest"))
        return JsValue(obj)
    }

    /// 解析 Manifest - 文件反序列化桥接尚未暴露
    public static func jsParseManifest(global: JSGlobalObject, callFrame: CallFrame): JsValue {
        let input = callFrame.argument(0)
        if (!input.isString()) {
            global.throwInvalidArguments("parseManifest expects a path string")
            return JsValue.jsUndefined()
        }

        let obj = JsObject.make()
        obj.set("path", JsValue(input.toString()))
        obj.set("ok", JsValue(false))
        obj.set("error", JsValue("Manifest filesystem deserialization is not exposed to bao_install_jsc yet"))
        return JsValue(obj)
    }
}

private func collectStringArray(globalObject: JSGlobalObject, value: JsValue): ArrayList<String> {
    let result = ArrayList<String>()
    if (value.isUndefinedOrNull()) {
        return result
    }

    if (value.isString()) {
        result.append(value.toString())
        return result
    }

    let len = value.getLength(globalObject.globalThis)
    var i: UInt64 = 0
    while (i < len) {
        let item = value.getIndex(globalObject.globalThis, UInt32(i))
        if (!item.isUndefinedOrNull()) {
            result.append(item.toString())
        }
        i += UInt64(1)
    }
    return result
}
