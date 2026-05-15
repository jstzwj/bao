// 严格翻译自: src/install_jsc/ini_jsc.zig
//! Test-only host fns for `bun.ini`. Kept out of `ini/` so that directory has no JSC references.
package bao_install_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// IniTestingAPIs - INI 测试 API
// 严格翻译自: src/install_jsc/ini_jsc.zig:4-130
// ============================================================================

/// INI 测试 API 集合 - 严格对应 Bun IniTestingAPIs
public class IniTestingAPIs {
    /// 从 JS 加载 npmrc - 严格对应 Bun loadNpmrcFromJS
    public static func loadNpmrcFromJS(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        let arg = callframe.argument(0)
        let npmrcContents = arg.toBunString(globalThis)
        let npmrcUtf8 = npmrcContents.toUTF8(Allocator.default)
        let source = Logger.Source.initPathString("<js>", npmrcUtf8.slice())

        let log = Logger.Log.init(Allocator.default)

        let arena = ArenaAllocator(Allocator.default)
        let allocator = arena.allocator()

        let envjs = callframe.argument(1)
        let env = if (envjs.isEmptyOrUndefinedOrNull) {
            globalThis.bunVM().transpiler.env
        } else {
            var envmap = DotEnvMapHashTable(allocator)
            let envobj = envjs.getObject()
            var objectIter = JSPropertyIterator(globalThis, envobj)

            envmap.ensureTotalCapacity(objectIter.len)

            while (let key = objectIter.next()) {
                let keyslice = key.toOwnedSlice(allocator)
                let value = objectIter.value
                if (value.isUndefined) {
                    continue
                }
                let valueStr = value.getZigString(globalThis)
                let slice = valueStr.toOwnedSlice(allocator)

                envmap.put(keyslice, DotEnvEntry(value: slice, conditional: false))
            }

            let env = DotEnvLoader(DotEnvMap(map: envmap), allocator)
            env
        }

        let install = BunInstall()
        var configs = ArrayList<ConfigIteratorItem>(allocator)
        loadNpmrc(allocator, install, env, ".npmrc", log, source, configs)
        if (configs.isErr) {
            return log.toJS(globalThis, Allocator.default, "error")
        }

        let (defaultRegistryUrl, defaultRegistryToken, defaultRegistryUsername, defaultRegistryPassword, defaultRegistryEmail) = if (let defaultRegistry = install.defaultRegistry) {
            (
                BaoString.fromBytes(defaultRegistry.url),
                BaoString.fromBytes(defaultRegistry.token),
                BaoString.fromBytes(defaultRegistry.username),
                BaoString.fromBytes(defaultRegistry.password),
                BaoString.fromBytes(defaultRegistry.email)
            )
        } else {
            (
                BaoString.static(Registry.defaultUrl),
                BaoString.empty,
                BaoString.empty,
                BaoString.empty,
                BaoString.empty
            )
        }

        return JSObject.create(
            JSObjectProps(
                default_registry_url: defaultRegistryUrl,
                default_registry_token: defaultRegistryToken,
                default_registry_username: defaultRegistryUsername,
                default_registry_password: defaultRegistryPassword,
                default_registry_email: defaultRegistryEmail
            ),
            globalThis
        ).toJS()
    }

    /// 解析 INI 字符串 - 严格对应 Bun parse
    public static func parse(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        let arguments = callframe.argumentsOld(1).slice()

        let jsstr = arguments[0]
        let bunstr = jsstr.toBunString(globalThis)
        let utf8str = bunstr.toUTF8(Allocator.default)

        var parser = IniParser(Allocator.default, "<src>", utf8str.slice(), globalThis.bunVM().transpiler.env)
        defer {
            parser.deinit()
        }

        parser.parse(parser.arena.allocator())

        return parser.out.toJS(Allocator.default, globalThis)
    }
}
