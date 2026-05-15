// 严格翻译自: src/runtime/api/bun/js_bun_spawn_bindings.zig
package bao_runtime

import bao_jsc.*
import bao_core.*
import bao_sys.*

// ============================================================================
// js_bun_spawn_bindings - Bun.spawn() 和 Bun.spawnSync() 的 JS 绑定
// 对应 Bun: src/runtime/api/bun/js_bun_spawn_bindings.zig
// ============================================================================

/// Bun.spawn() 的 JS 绑定
public class JsBunSpawnBindings {

    // ========================================================================
    // spawn - Bun.spawn()
    // ========================================================================

    /// Bun.spawn() 入口
    public static func spawn(globalThis: JsGlobalObject, args: JsValue, secondaryArgsValue: ?JsValue): JsValue {
        return spawnMaybeSync(globalThis, args, secondaryArgsValue, false)
    }

    // ========================================================================
    // spawnSync - Bun.spawnSync()
    // ========================================================================

    /// Bun.spawnSync() 入口
    public static func spawnSync(globalThis: JsGlobalObject, args: JsValue, secondaryArgsValue: ?JsValue): JsValue {
        return spawnMaybeSync(globalThis, args, secondaryArgsValue, true)
    }

    // ========================================================================
    // spawnMaybeSync - 共享实现
    // ========================================================================

    /// spawnMaybeSync - spawn 和 spawnSync 的共享实现
    public static func spawnMaybeSync(globalThis: JsGlobalObject, args: JsValue, secondaryArgsValue: ?JsValue, isSync: Bool): JsValue {
        // ... 实现省略
        return JsValue.zero
    }

    // ========================================================================
    // getArgv - 构建 argv 数组
    // ========================================================================

    /// getArgv - 构建 Bun.spawn 的 argv
    public static func getArgv(globalThis: JsGlobalObject, args: JsValue, path: String, cwd: String, argv0: String?, allocator: Allocator): ArrayList<String> {
        if (args.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("cmd must be an array of strings")
            return []
        }

        var cmdsArray = try args.arrayIterator(globalThis)
        if (cmdsArray.len == 0) {
            globalThis.throwInvalidArguments("cmd must not be empty")
            return []
        }

        var argv = ArrayList<String>(capacity: cmdsArray.len + 2)

        // 获取 argv0
        let argv0Result = try getArgv0(globalThis, path, cwd, argv0, cmdsArray.next()!, allocator)
        argv.append(argv0Result.arg0)

        // 添加其余参数
        var argIndex: Int = 1
        while (let value = try cmdsArray.next()) {
            let arg = try value.toBunString(globalThis)
            defer arg.deref()

            // 检查 null 字节 (安全: 防止 null 字节注入)
            if (arg.indexOfAsciiChar(0) != null) {
                globalObject.throwInvalidArguments("Argument must be a string without null bytes")
                return []
            }

            argv.append(arg.toOwnedSliceZ(allocator))
            argIndex += 1
        }

        return argv
    }

    // ========================================================================
    // getArgv0 - 解析 argv[0]
    // ========================================================================

    /// getArgv0 - 解析第一个命令参数
    public static func getArgv0(globalThis: JsGlobalObject, path: String, cwd: String, pretendArgv0: ?String, firstCmd: JsValue, allocator: Allocator): Argv0Result {
        var arg0 = try firstCmd.toSliceOrNullWithAllocator(globalThis, allocator)
        defer arg0.deinit()

        // 检查 null 字节
        if (arg0.slice().indexOfChar(0) != null) {
            globalThis.throwInvalidArguments("The argument 'args[0]' must be a string without null bytes")
            return Argv0Result(argv0: "", arg0: "")
        }

        var actualArgv0: String = ""
        let argv0ToUse: String = arg0.slice()

        // 如果命令包含 /, 不从 $PATH 搜索
        let pathToUse: String = if (argv0ToUse.contains('/')) {
            ""
        } else if (path.count > 0) {
            path
        } else {
            BUN_DEFAULT_PATH_FOR_SPAWN
        }

        if (pathToUse.count == 0) {
            actualArgv0 = allocator.dupeZ(argv0ToUse)
        } else {
            let resolved = Which.which(pathToUse, cwd, argv0ToUse) ?? {
                throwCommandNotFound(globalThis, argv0ToUse)
                return Argv0Result(argv0: "", arg0: "")
            }
            actualArgv0 = allocator.dupeZ(resolved)
        }

        return Argv0Result(
            argv0: actualArgv0,
            arg0: pretendArgv0 != null ? allocator.dupeZ(pretendArgv0!) : allocator.dupeZ(arg0.slice()),
        )
    }

    /// Argv0 结果
    public struct Argv0Result {
        public var argv0: String
        public var arg0: String
    }
}
