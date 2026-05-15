// 严格翻译自: src/install_jsc/install_binding.zig
//! JSC bindings for install lockfile parsing.
package bao_install_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// BunInstallJsBindings - Install JS 绑定
// 严格翻译自: src/install_jsc/install_binding.zig:1-73
// ============================================================================

/// Install JS 绑定 - 严格对应 Bun bun_install_js_bindings
public class BunInstallJsBindings {
    /// 生成绑定对象 - 严格对应 Bun generate
    public static func generate(global: JSGlobalObject): JSValue {
        let obj = JSValue.createEmptyObject(global, 1)
        let parseLockfile = ZigString.static("parseLockfile")
        obj.put(global, parseLockfile, JSFunction.create(global, "parseLockfile", jsParseLockfile, 1))
        return obj
    }

    /// 解析 Lockfile - 严格对应 Bun jsParseLockfile
    /// Zig: pub fn jsParseLockfile(globalObject, callFrame) bun.JSError!JSValue
    public static func jsParseLockfile(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let allocator = Allocator.default
        let log = Logger.Log.init(allocator)

        let args = callFrame.argumentsOld(1).slice()
        let cwd = args[0].toSliceOrNull(globalObject)

        let dir = openDirAbsoluteNotForDeletingOrRenaming(cwd.slice())
        if (dir.isErr) {
            globalObject.throw("failed to open: ${dir.errValue}, '${cwd.slice()}'")
            return JSValue.zero
        }

        let lockfilePath = Path.joinAbsStringZ(cwd.slice(), ["bun.lockb"], .auto)

        var lockfile = Lockfile()
        lockfile.initEmpty(allocator)

        if (globalObject.bunVM().transpiler.resolver.envLoader == None) {
            globalObject.bunVM().transpiler.resolver.envLoader = globalObject.bunVM().transpiler.env
        }

        let manager = globalObject.bunVM().transpiler.resolver.getPackageManager()
        let loadResult = lockfile.loadFromDir(FD.fromStdDir(dir), manager, allocator, log, true)

        match (loadResult) {
            case .err => err =>
                globalObject.throw("failed to load lockfile: ${err.value}, '${lockfilePath}'")
                return JSValue.zero
            case .notFound =>
                globalObject.throw("lockfile not found: '${lockfilePath}'")
                return JSValue.zero
            case .ok => ()
        }

        let stringified = handleOom(fmtAllocPrint(allocator, "${lockfile}"))
        var str = BaoString.cloneUTF8(stringified)
        defer {
            str.deref()
        }

        return str.toJSByParseJSON(globalObject)
    }
}
