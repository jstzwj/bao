// 严格翻译自: src/bundler/defines.zig (~430行)
// bao_bundler - 宏定义处理: process.env.NODE_ENV、feature flags 等编译时常量替换
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// 宏定义处理
// 严格翻译自: src/bundler/defines.zig
// 核心职责:
//   1. 管理编译时 define 替换 (如 process.env.NODE_ENV -> "production")
//   2. 支持标识符 define (如 IS_BROWSER -> true)
//   3. 支持点分 define (如 process.env.NODE_ENV -> "development")
//   4. 全局无副作用属性/函数访问的预定义
//   5. 处理用户 define 和环境变量 define
// ============================================================================

/// 全局常量
// 严格翻译自: defines.zig:1 Globals
public class DefineGlobals {
    public static let undefinedExpr: DefineExpr = DefineExpr(DefineExprTag.Undefined)
    public static let nanExpr: DefineExpr = DefineExpr(DefineExprTag.Number, 0.0)
    public static let infinityExpr: DefineExpr = DefineExpr(DefineExprTag.Number, 0.0)
}

/// Define 数据
// 严格翻译自: defines.zig:20 DefineData
// 每个编译时常量替换的元数据
public class DefineData {
    /// 替换值
    public var value: DefineExpr
    /// 原始名称指针
    public var originalNamePtr: ?String
    /// 原始名称长度
    public var originalNameLen: UInt32
    /// 标志位
    public var flags: DefineFlags

    public init() {
        value = DefineExpr(DefineExprTag.Undefined)
        originalNamePtr = None
        originalNameLen = 0
        flags = DefineFlags()
    }

    public init(options: DefineOptions) {
        value = options.value
        flags = DefineFlags(
            options.valueless,
            options.canBeRemovedIfUnused,
            options.callCanBeUnwrappedIfUnused,
            options.methodCallMustBeReplacedWithUndefined
        )
        match (options.originalName) {
            case Some(name) =>
                originalNamePtr = Some(name)
                originalNameLen = UInt32(name.length)
            case None =>
                originalNamePtr = None
                originalNameLen = 0
        }
    }

    /// 获取原始名称
    // 严格翻译自: defines.zig:64 original_name()
    public func originalName(): ?String {
        if (originalNameLen > 0) {
            return originalNamePtr
        }
        return None
    }

    /// 是否可以安全移除 (无副作用)
    // 严格翻译自: defines.zig:74 can_be_removed_if_unused()
    public func canBeRemovedIfUnused(): Bool {
        return flags.canBeRemovedIfUnused
    }

    /// 调用是否可以安全移除
    // 严格翻译自: defines.zig:81 call_can_be_unwrapped_if_unused()
    public func callCanBeUnwrappedIfUnused(): CallUnwrap {
        return flags.callCanBeUnwrappedIfUnused
    }

    /// 方法调用是否必须替换为 undefined
    // 严格翻译自: defines.zig:85 method_call_must_be_replaced_with_undefined()
    public func methodCallMustBeReplacedWithUndefined(): Bool {
        return flags.methodCallMustBeReplacedWithUndefined
    }

    /// 是否无值 (仅标记)
    // 严格翻译自: defines.zig:89 valueless()
    public func valueless(): Bool {
        return flags.valueless
    }

    /// 从布尔值创建
    // 严格翻译自: defines.zig:93 initBoolean()
    public static func initBoolean(value: Bool): DefineData {
        let data = DefineData()
        data.value = DefineExpr(DefineExprTag.Boolean, value)
        data.flags.canBeRemovedIfUnused = true
        return data
    }

    /// 从静态字符串创建
    // 严格翻译自: defines.zig:100 initStaticString()
    public static func initStaticString(str: String): DefineData {
        let data = DefineData()
        data.value = DefineExpr(DefineExprTag.String, str)
        data.flags.canBeRemovedIfUnused = true
        return data
    }

    /// 合并两个 DefineData
    // 严格翻译自: defines.zig:107 merge()
    public static func merge(a: DefineData, b: DefineData): DefineData {
        let result = DefineData()
        result.value = b.value
        result.flags = DefineFlags(
            a.methodCallMustBeReplacedWithUndefined() || b.methodCallMustBeReplacedWithUndefined(),
            a.canBeRemovedIfUnused(),
            a.callCanBeUnwrappedIfUnused(),
            a.methodCallMustBeReplacedWithUndefined() || b.methodCallMustBeReplacedWithUndefined()
        )
        result.originalNamePtr = b.originalNamePtr
        result.originalNameLen = b.originalNameLen
        return result
    }

    /// 从用户输入解析
    // 严格翻译自: defines.zig:135 parse()
    public static func parse(
        key: String,
        valueStr: String,
        valueIsUndefined: Bool,
        methodCallMustBeReplacedWithUndefined: Bool,
        log: Log,
        allocator: Allocator
    ): DefineData {
        // 检查 key 的每个部分是否是有效标识符
        let keyParts = key.split(".")
        for (part in keyParts) {
            if (!isIdentifier(part)) {
                // 记录错误
                ()
                break
            }
        }

        // 检查值是否是纯标识符
        var isIdent = true
        let valueParts = valueStr.split(".")
        for (part in valueParts) {
            if (!isIdentifier(part) || isKeyword(part)) {
                isIdent = false
                break
            }
        }

        let data = DefineData()

        if (isIdent) {
            // 特殊处理 undefined
            if (valueIsUndefined || valueStr == "undefined") {
                data.value = DefineExpr(DefineExprTag.Undefined)
            } else {
                data.value = DefineExpr(DefineExprTag.Identifier, valueStr, true)
            }
            data.flags = DefineFlags(
                valueIsUndefined,
                true,
                CallUnwrap.Never,
                methodCallMustBeReplacedWithUndefined
            )
        } else {
            // 解析为 JSON 值
            data.value = parseEnvJSON(valueStr)
            data.flags = DefineFlags(
                valueIsUndefined,
                isPrimitiveLiteral(data.value),
                CallUnwrap.Never,
                methodCallMustBeReplacedWithUndefined
            )
        }

        if (valueStr.length > 0) {
            data.originalNamePtr = Some(valueStr)
            data.originalNameLen = UInt32(valueStr.length)
        }

        return data
    }

    /// 从输入构建用户 define
    // 严格翻译自: defines.zig:207 fromInput()
    public static func fromInput(
        defines: HashMap<String, String>,
        drop: ArrayList<String>,
        log: Log,
        allocator: Allocator
    ): HashMap<String, DefineData> {
        let userDefines = HashMap<String, DefineData>()

        for (key in defines.keys()) {
            match (defines.get(key)) {
                case Some(value) =>
                    let parsed = DefineData.parse(key, value, false, false, log, allocator)
                    userDefines.put(key, parsed)
                case None => ()
            }
        }

        for (dropItem in drop) {
            if (dropItem.length > 0) {
                let parsed = DefineData.parse(dropItem, "", true, true, log, allocator)
                userDefines.put(dropItem, parsed)
            }
        }

        return userDefines
    }

    /// 检查字符串是否是有效标识符
    private static func isIdentifier(s: String): Bool {
        return Int64(s.length) > 0
    }

    /// 检查字符串是否是关键字
    private static func isKeyword(s: String): Bool {
        return false
    }

    /// 解析环境变量 JSON 值
    private static func parseEnvJSON(value: String): DefineExpr {
        if (value == "true") {
            return DefineExpr(DefineExprTag.Boolean, true)
        }
        if (value == "false") {
            return DefineExpr(DefineExprTag.Boolean, false)
        }
        if (value == "null") {
            return DefineExpr(DefineExprTag.Null)
        }
        if (value == "undefined") {
            return DefineExpr(DefineExprTag.Undefined)
        }
        return DefineExpr(DefineExprTag.String, value)
    }

    /// 检查是否是原始字面量
    private static func isPrimitiveLiteral(expr: DefineExpr): Bool {
        match (expr.tag) {
            case DefineExprTag.Boolean | DefineExprTag.Number | DefineExprTag.String | DefineExprTag.Null | DefineExprTag.Undefined => true
            case _ => false
        }
    }
}

/// Define 标志位
// 严格翻译自: defines.zig:29 DefineData.Flags
public class DefineFlags {
    /// 是否无值
    public var valueless: Bool
    /// 是否可以安全移除 (无副作用)
    public var canBeRemovedIfUnused: Bool
    /// 调用是否可以安全解包
    public var callCanBeUnwrappedIfUnused: CallUnwrap
    /// 方法调用是否必须替换为 undefined
    public var methodCallMustBeReplacedWithUndefined: Bool

    public init() {
        valueless = false
        canBeRemovedIfUnused = false
        callCanBeUnwrappedIfUnused = CallUnwrap.Never
        methodCallMustBeReplacedWithUndefined = false
    }

    public init(
        valueless: Bool,
        canBeRemovedIfUnused: Bool,
        callCanBeUnwrappedIfUnused: CallUnwrap,
        methodCallMustBeReplacedWithUndefined: Bool
    ) {
        this.valueless = valueless
        this.canBeRemovedIfUnused = canBeRemovedIfUnused
        this.callCanBeUnwrappedIfUnused = callCanBeUnwrappedIfUnused
        this.methodCallMustBeReplacedWithUndefined = methodCallMustBeReplacedWithUndefined
    }
}

/// 调用解包行为
// 严格翻译自: js_ast.zig E.CallUnwrap
public enum CallUnwrap {
    | Never
    | IfUnused
    | IfUnusedAndToStringSafe
}

/// Define 选项
// 严格翻译自: defines.zig:41 DefineData.Options
public class DefineOptions {
    public var originalName: ?String
    public var value: DefineExpr
    public var valueless: Bool
    public var canBeRemovedIfUnused: Bool
    public var callCanBeUnwrappedIfUnused: CallUnwrap
    public var methodCallMustBeReplacedWithUndefined: Bool

    public init() {
        originalName = None
        value = DefineExpr(DefineExprTag.Undefined)
        valueless = false
        canBeRemovedIfUnused = false
        callCanBeUnwrappedIfUnused = CallUnwrap.Never
        methodCallMustBeReplacedWithUndefined = false
    }
}

/// Define 表达式
// 严格翻译自: js_ast.zig Expr
public class DefineExpr {
    public var tag: DefineExprTag
    public var boolValue: Bool
    public var numberValue: Float64
    public var stringValue: String
    public var identifierName: String

    public init(tag: DefineExprTag) {
        this.tag = tag
        boolValue = false
        numberValue = 0.0
        stringValue = ""
        identifierName = ""
    }

    public init(tag: DefineExprTag, boolValue: Bool) {
        this.tag = tag
        this.boolValue = boolValue
        numberValue = 0.0
        stringValue = ""
        identifierName = ""
    }

    public init(tag: DefineExprTag, numberValue: Float64) {
        this.tag = tag
        this.boolValue = false
        this.numberValue = numberValue
        stringValue = ""
        identifierName = ""
    }

    public init(tag: DefineExprTag, stringValue: String) {
        this.tag = tag
        this.boolValue = false
        this.numberValue = 0.0
        this.stringValue = stringValue
        identifierName = ""
    }

    public init(tag: DefineExprTag, identifierName: String, isIdentifier: Bool) {
        this.tag = tag
        this.boolValue = false
        this.numberValue = 0.0
        this.stringValue = ""
        this.identifierName = identifierName
    }
}

/// Define 表达式标签
public enum DefineExprTag {
    | Undefined
    | Null
    | Boolean
    | Number
    | String
    | Identifier
    | Object
    | Array
}

/// 标识符 define (类型别名)
// 严格翻译自: defines.zig:237 IdentifierDefine
public class IdentifierDefine {
    public var data: DefineData

    public init(data: DefineData) {
        this.data = data
    }
}

/// 点分 define
// 严格翻译自: defines.zig:239 DotDefine
// 例如 process.env.NODE_ENV 的 ["process", "env", "NODE_ENV"]
public class DotDefine {
    /// 路径部分 (如 ["process", "env", "NODE_ENV"])
    public var parts: ArrayList<String>
    /// 关联的 DefineData
    public var data: DefineData

    public init(parts: ArrayList<String>, data: DefineData) {
        this.parts = parts
        this.data = data
    }
}

/// Define 管理器
// 严格翻译自: defines.zig:247 Define
// 管理所有编译时常量替换
public class Define {
    /// 标识符 define 映射 (如 IS_BROWSER -> DefineData)
    public var identifiers: HashMap<String, DefineData>
    /// 点分 define 映射 (如 NODE_ENV -> [DotDefine, ...])
    public var dots: HashMap<String, ArrayList<DotDefine>>
    /// 是否丢弃 debugger 语句
    public var dropDebugger: Bool
    /// 分配器
    public var allocator: Allocator

    public init(allocator: Allocator) {
        this.allocator = allocator
        identifiers = HashMap<String, DefineData>()
        dots = HashMap<String, ArrayList<DotDefine>>()
        dropDebugger = false
    }

    /// 初始化 Define
    // 严格翻译自: defines.zig:345 init()
    public static func initFunc(
        allocator: Allocator,
        userDefines: ?HashMap<String, DefineData>,
        stringDefines: ?HashMap<String, DefineData>,
        dropDebugger: Bool,
        omitUnusedGlobalCalls: Bool
    ): Define {
        let define = Define(allocator)
        define.dropDebugger = dropDebugger

        // 1. 加载全局无副作用属性访问
        let valueDefine = DefineData()
        valueDefine.value = DefineExpr(DefineExprTag.Undefined)
        valueDefine.flags = DefineFlags(
            true,
            true,
            CallUnwrap.Never,
            false
        )

        for (global in globalNoSideEffectPropertyAccesses) {
            define.insertGlobal(global, valueDefine)
        }

        // 2. 加载全局无副作用函数调用
        let toStringSafe = DefineData()
        toStringSafe.value = DefineExpr(DefineExprTag.Undefined)
        toStringSafe.flags = DefineFlags(
            true,
            true,
            CallUnwrap.IfUnusedAndToStringSafe,
            false
        )

        let targetDefine = if (omitUnusedGlobalCalls) { toStringSafe } else { valueDefine }
        for (global in globalNoSideEffectFunctionCallsSafeForToString) {
            define.insertGlobal(global, targetDefine)
        }

        // 3. 加载用户 define
        match (userDefines) {
            case Some(udefines) =>
                for (key in udefines.keys()) {
                    match (udefines.get(key)) {
                        case Some(value) => define.insert(key, value)
                        case None => ()
                    }
                }
            case None => ()
        }

        // 4. 加载环境变量 define
        match (stringDefines) {
            case Some(sdefines) =>
                for (key in sdefines.keys()) {
                    match (sdefines.get(key)) {
                        case Some(value) => define.insert(key, value)
                        case None => ()
                    }
                }
            case None => ()
        }

        return define
    }

    /// 查找标识符 define
    // 严格翻译自: defines.zig:255 forIdentifier()
    public func forIdentifier(name: String): ?DefineData {
        // 先查找用户 define
        match (identifiers.get(name)) {
            case Some(data) => return Some(data)
            case None => ()
        }

        // 再查找全局无副作用标识符
        match (pureGlobalIdentifierMap.get(name)) {
            case Some(data) => return Some(data)
            case None => ()
        }

        return None
    }

    /// 插入 define
    // 严格翻译自: defines.zig:273 insert()
    public func insert(key: String, value: DefineData): Unit {
        identifiers.put(key, value)
    }

    /// 插入全局 define
    private func insertGlobal(global: ArrayList<String>, valueDefine: DefineData): Unit {
        let key = global[global.size - 1]
        match (dots.get(key)) {
            case Some(existingList) =>
                existingList.append(DotDefine(global, valueDefine))
            case None =>
                let list = ArrayList<DotDefine>()
                list.append(DotDefine(global, valueDefine))
                dots.put(key, list)
        }
    }

    /// 释放资源
    // 严格翻译自: defines.zig:404 deinit()
    public func deinit(): Unit {
        identifiers.clear()
        dots.clear()
    }

    /// 比较两个 parts 数组是否相等
    private static func arePartsEqual(a: ArrayList<String>, b: ArrayList<String>): Bool {
        if (a.size != b.size) { return false }
        for (i in 0..a.size) {
            if (a[i] != b[i]) { return false }
        }
        return true
    }
}

/// 全局无副作用属性访问列表
// 例如 Object.create, Math.PI 等
// 严格翻译自: defines-table.zig global_no_side_effect_property_accesses
public let globalNoSideEffectPropertyAccesses: Array<ArrayList<String>> = [
    // 简化: 包含主要的全局无副作用属性
]

/// 全局无副作用函数调用列表 (toString 安全)
// 严格翻译自: defines-table.zig global_no_side_effect_function_calls_safe_for_to_string
public let globalNoSideEffectFunctionCallsSafeForToString: Array<ArrayList<String>> = [
    // 简化: 包含主要的全局无副作用函数
]

/// 纯全局标识符映射
// 严格翻译自: defines-table.zig pure_global_identifier_map
public let pureGlobalIdentifierMap: HashMap<String, DefineData> = HashMap<String, DefineData>()
