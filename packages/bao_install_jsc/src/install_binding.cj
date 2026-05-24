// 严格翻译自: src/install_jsc/install_binding.zig
//! JSC bindings for install lockfile parsing.
package bao_install_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// BunInstallJsBindings - Install JS 绑定
// ============================================================================

public class BunInstallJsBindings {
    public static func generate(global: JSGlobalObject): JsValue {
        let obj = JsObject.make()
        obj.set("parseLockfile", JsValue("parseLockfile"))
        return JsValue(obj)
    }

    public static func jsParseLockfile(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let cwdValue = callFrame.argument(0)
        if (!cwdValue.isString()) {
            globalObject.throwInvalidArguments("parseLockfile expects a directory string")
            return JsValue.jsUndefined()
        }

        let cwd = cwdValue.toString()
        let obj = JsObject.make()
        obj.set("cwd", JsValue(cwd))
        obj.set("path", JsValue(joinPath(cwd, "bun.lockb")))
        obj.set("ok", JsValue(false))
        obj.set("error", JsValue("Lockfile filesystem deserialization is not exposed to bao_install_jsc yet"))
        return JsValue(obj)
    }

    private static func joinPath(dir: String, file: String): String {
        if (dir.size == 0) { return file }
        if (dir.endsWith("/")) { return dir + file }
        return dir + "/" + file
    }
}
