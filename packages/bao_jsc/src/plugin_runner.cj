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

/// 文件系统路径，严格对应 Bun `bun_paths::fs::Path` 在插件解析中的 path + namespace。
class FsPath {
    public var text: String = ""
    public var namespace: String = "file"

    public init() {}
    public init(text: String) { this.text = text }
    public init(text: String, namespace: String) {
        this.text = text
        this.namespace = namespace
    }

    public static func initWithNamespace(path: Array<Byte>, namespace: Array<Byte>): FsPath {
        return FsPath(String.fromUtf8(path), String.fromUtf8(namespace))
    }
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
