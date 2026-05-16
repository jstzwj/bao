// 严格翻译自: src/jsc/PluginRunner.rs
// PluginRunner — 具体的 JSC 感知插件解析钩子
//
// LAYERING: 静态字节辅助函数 (extract_namespace / could_be_plugin) 位于
// bun_bundler::transpiler::PluginRunner (无 JSC, 最低层)。
// 有状态的结构体在此处, 因为其唯一字段是类型化的 *mut JSGlobalObject。
// bun_bundler::Linker 通过 *mut dyn PluginResolver 引用它,
// 因此 linker 保持无 JSC 而无需类型擦除为 *mut c_void 或在 fn-ptr 后重复主体

package bao_jsc

import bao_bundler.BunPluginTarget
import bao_bundler.PluginResolver
import bao_core.OwnedString
import bao_core.BunString

// Local FsPath stub for plugin runner
class FsPath {
    public var text: String = ""
    public init() {}
    public init(text: String) { this.text = text }
}

// ========== PluginRunner ==========
// 严格翻译自 PluginRunner.rs PluginRunner
// Spec PluginRunner.zig:7
public class PluginRunner {
    // JS 全局对象引用
    public var globalObject: JSGlobalObject = JSGlobalObject()

    public init() {}

    public init(globalObject: JSGlobalObject) {
        this.globalObject = globalObject
    }

    // ========== extract_namespace ==========
    // 严格翻译自 PluginRunner::extract_namespace
    // 从说明符中提取命名空间部分
    public static func extractNamespace(specifier: Array<Byte>): Array<Byte> {
        // 查找冒号分隔符
        var i: Int64 = 0
        while (i < specifier.size) {
            if (specifier[i] == ':'.toByte()) {
                return specifier.slice(0, i)
            }
            i++
        }
        []
    }

    // ========== could_be_plugin ==========
    // 严格翻译自 PluginRunner::could_be_plugin
    // 检查说明符是否可能是插件引用
    public static func couldBePlugin(specifier: Array<Byte>): Bool {
        // 插件说明符必须包含冒号
        var i: Int64 = 0
        while (i < specifier.size) {
            if (specifier[i] == ':'.toByte()) {
                return i > 0
            }
            i++
        }
        false
    }
}

// ========== PluginResolver 实现 ==========
// 严格翻译自 PluginRunner.rs impl PluginResolver for PluginRunner
// Spec PluginRunner.zig:34 onResolve
public extension PluginRunner {

    // 严格翻译自 on_resolve
    // 插件解析回调
    public func onResolve(
        specifier: Array<Byte>,
        importer: Array<Byte>,
        log: Log,
        loc: Loc,
        target: BunPluginTarget
    ): Result<?FsPath> {
        let namespaceSlice = extractNamespace(specifier)
        let namespace: BunString = if (!namespaceSlice.isEmpty() && namespaceSlice != "file".toArrayByte()) {
            BunString(namespaceSlice)
        } else {
            BunString("")
        }

        // 计算路径偏移
        let pathOffset: Int64 = if (namespace.length() > 0) {
            Int64(namespace.length()) + 1
        } else {
            0
        }

        // 调用 JS 端的解析插件
        let onResolvePlugin = try globalObject.runOnResolvePlugins(
            namespace,
            BunString(specifier).substring(pathOffset),
            BunString(importer),
            target
        )

        // 如果没有匹配的插件, 返回 None
        if (onResolvePlugin == None) {
            return Ok(None)
        }

        let plugin = onResolvePlugin.getOrThrow()

        // 获取 path 属性
        let pathValue = try plugin.get(globalObject, "path")
        if (pathValue == None || pathValue.getOrThrow().isEmptyOrUndefinedOrNull()) {
            return Ok(None)
        }
        let pathVal = pathValue.getOrThrow()
        if (!pathVal.isString()) {
            log.addError(None, loc, "Expected \"path\" to be a string".toArrayByte())
            return Ok(None)
        }

        // 获取文件路径字符串
        let filePath = try OwnedString(pathVal.toBunString(globalObject))

        // 验证路径非空
        if (filePath.length() == 0) {
            log.addError(None, loc, "Expected \"path\" to be a non-empty string in onResolve plugin".toArrayByte())
            return Ok(None)
        }

        // 验证路径不包含特殊值
        if (filePath.eql(".") || filePath.eql("..") || filePath.eql("...") || filePath.eql(" ")) {
            log.addError(None, loc, "Invalid file path from onResolve plugin".toArrayByte())
            return Ok(None)
        }

        var staticNamespace: Bool = true
        var userNamespace: BunString = ""

        // 获取 namespace 属性
        let namespaceValue = try plugin.get(globalObject, "namespace")
        if (namespaceValue != None) {
            let nsVal = namespaceValue.getOrThrow()
            if (!nsVal.isString()) {
                log.addError(None, loc, "Expected \"namespace\" to be a string".toArrayByte())
                return Ok(None)
            }

            let namespaceStr = try nsVal.toBunString(globalObject)
            if (namespaceStr.length() == 0) {
                userNamespace = BunString("file")
            } else if (namespaceStr.eql("file")) {
                userNamespace = BunString("file")
            } else if (namespaceStr.eql("bun")) {
                userNamespace = BunString("bun")
            } else if (namespaceStr.eql("node")) {
                userNamespace = BunString("node")
            } else {
                staticNamespace = false
                userNamespace = namespaceStr
            }
        } else {
            userNamespace = BunString("file")
        }

        // 构建结果路径
        let pathStatic: Array<Byte> = filePath.toString().toArrayByte()

        if (staticNamespace) {
            let ns: Array<Byte> = if (userNamespace.eql("bun")) {
                "bun".toArrayByte()
            } else if (userNamespace.eql("node")) {
                "node".toArrayByte()
            } else {
                "file".toArrayByte()
            }
            Ok(Some(FsPath.initWithNamespace(pathStatic, ns)))
        } else {
            let nsStatic: Array<Byte> = userNamespace.toString().toArrayByte()
            Ok(Some(FsPath.initWithNamespace(pathStatic, nsStatic)))
        }
    }
}

// ========== 支撑类型 ==========
// 日志类型
public class Log {
    public init() {}

    public func addError(source: ?Any, loc: Loc, message: Array<Byte>) {
        // 添加错误到日志
    }
}

// 源码位置
public class Loc {
    public init() {}
}

// OwnedString — 拥有的字符串
public class OwnedString {
    private var value: BunString = ""

    public init() {}

    public init(value: BunString) {
        this.value = value
    }

    public func length(): Int64 {
        Int64(value.length())
    }

    public func eql(other: String): Bool {
        value == other
    }

    public func toString(): String {
        value
    }
}

// String 扩展
public extension String {
    public func toBunString(): BunString {
        BunString(this)
    }

    public func toArrayByte(): Array<Byte> {
        this.toArray()
    }
}
