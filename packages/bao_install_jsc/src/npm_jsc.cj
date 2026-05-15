// 严格翻译自: src/install_jsc/npm_jsc.zig
//! JSC host fns extracted from `src/install/npm.zig`.
package bao_install_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// NpmJSC - NPM 的 JSC 桥接
// 严格翻译自: src/install_jsc/npm_jsc.zig:6-119
// ============================================================================

/// 操作系统匹配 - 严格对应 Bun operatingSystemIsMatch
public func operatingSystemIsMatch(globalObject: JSGlobalObject, callframe: CallFrame): JSValue {
    let args = callframe.argumentsOld(1)
    var operatingSystem = OperatingSystem.negatable(.none)
    var iter = args.ptr[0].arrayIterator(globalObject)
    while (let item = iter.next()) {
        let slice = item.toSlice(globalObject, Allocator.default)
        operatingSystem.apply(slice.slice())
        if (globalObject.hasException) {
            return JSValue.zero
        }
    }
    if (globalObject.hasException) {
        return JSValue.zero
    }
    return JSValue.jsBoolean(operatingSystem.combine().isMatch(OperatingSystem.current))
}

/// Libc 匹配 - 严格对应 Bun libcIsMatch
public func libcIsMatch(globalObject: JSGlobalObject, callframe: CallFrame): JSValue {
    let args = callframe.argumentsOld(1)
    var libc = Libc.negatable(.none)
    var iter = args.ptr[0].arrayIterator(globalObject)
    while (let item = iter.next()) {
        let slice = item.toSlice(globalObject, Allocator.default)
        libc.apply(slice.slice())
        if (globalObject.hasException) {
            return JSValue.zero
        }
    }
    if (globalObject.hasException) {
        return JSValue.zero
    }
    return JSValue.jsBoolean(libc.combine().isMatch(Libc.current))
}

/// 架构匹配 - 严格对应 Bun architectureIsMatch
public func architectureIsMatch(globalObject: JSGlobalObject, callframe: CallFrame): JSValue {
    let args = callframe.argumentsOld(1)
    var architecture = Architecture.negatable(.none)
    var iter = args.ptr[0].arrayIterator(globalObject)
    while (let item = iter.next()) {
        let slice = item.toSlice(globalObject, Allocator.default)
        architecture.apply(slice.slice())
        if (globalObject.hasException) {
            return JSValue.zero
        }
    }
    if (globalObject.hasException) {
        return JSValue.zero
    }
    return JSValue.jsBoolean(architecture.combine().isMatch(Architecture.current))
}

/// Manifest 绑定 - 严格对应 Bun ManifestBindings
public class ManifestBindings {
    /// 生成绑定对象
    public static func generate(global: JSGlobalObject): JSValue {
        let obj = JSValue.createEmptyObject(global, 1)
        let parseManifestString = ZigString.static("parseManifest")
        obj.put(global, parseManifestString, JSFunction.create(global, "parseManifest", jsParseManifest, 2))
        return obj
    }

    /// 解析 Manifest - 严格对应 Bun jsParseManifest
    public static func jsParseManifest(global: JSGlobalObject, callFrame: CallFrame): JSValue {
        let args = callFrame.argumentsOld(2).slice()
        if (args.size < 2 || !args[0].isString || !args[1].isString) {
            global.throw("expected manifest filename and registry string arguments")
            return JSValue.zero
        }

        let manifestFilenameStr = args[0].toBunString(global)
        let manifestFilename = manifestFilenameStr.toUTF8(Allocator.default)

        let registryStr = args[1].toBunString(global)
        let registry = registryStr.toUTF8(Allocator.default)

        let manifestFile = Fs.cwd().openFile(manifestFilename.slice())
        if (manifestFile.isErr) {
            global.throw("failed to open manifest file '${manifestFilename.slice()}': ${manifestFile.errValue}")
            return JSValue.zero
        }

        let scope = RegistryScope(
            urlHash: RegistryScope.hash(strings.withoutTrailingSlash(registry.slice())),
            url: UrlComponents(
                host: strings.withoutTrailingSlash(strings.withoutPrefixComptime(registry.slice(), "http://")),
                hostname: strings.withoutTrailingSlash(strings.withoutPrefixComptime(registry.slice(), "http://")),
                href: registry.slice(),
                origin: strings.withoutTrailingSlash(registry.slice()),
                protocol: if (let colon = strings.indexOfChar(registry.slice(), ':')) registry.slice()[0..colon] else ""
            )
        )

        let maybePackageManifest = PackageManifest.Serializer.loadByFile(Allocator.default, scope, File.from(manifestFile))
        if (maybePackageManifest.isErr) {
            global.throw("failed to load manifest file: ${maybePackageManifest.errValue}")
            return JSValue.zero
        }

        let packageManifest = maybePackageManifest.resultValue
        if (packageManifest == None) {
            global.throw("manifest is invalid")
            return JSValue.zero
        }

        // 格式化为 JSON
        var buf = ArrayList<Byte>()
        buf.appendAll("{\"name\":\"${packageManifest.name()}\",\"versions\":[")
        for (i in 0..packageManifest.versions.size) {
            if (i == packageManifest.versions.size - 1) {
                buf.appendAll("\"${packageManifest.versions[i].fmt(packageManifest.stringBuf)}\"]}")
            } else {
                buf.appendAll("\"${packageManifest.versions[i].fmt(packageManifest.stringBuf)}\",")
            }
        }

        var result = BaoString.borrowUTF8(buf.items)
        defer {
            result.deref()
        }

        return result.toJSByParseJSON(global)
    }
}
