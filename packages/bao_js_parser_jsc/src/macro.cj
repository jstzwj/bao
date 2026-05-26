// 严格翻译自: src/js_parser_jsc/Macro.zig
//! Runtime macro system bridge.
package bao_js_parser_jsc

import bao_ast.*
import bao_core.Result
import bao_core.BaoError
import bao_core.ErrorCode
import bao_jsc.JsValue
import bao_jsc.JSGlobalObject
import bao_jsc.JsObject
import bao_jsc.BunVirtualMachine
import bao_jsc.BunVirtualMachineOptions
import bao_jsc.JsArrayIterator_
import bao_jsc.JSPromiseStatus
import bao_jsc.JsValueType
import bao_jsc.JsVirtualMachine
import bao_collections.ArrayList
import bao_collections.HashMap

// ============================================================================
// 宏模块常量
// ============================================================================

public let MACRO_NAMESPACE: String = "macro"
public let MACRO_NAMESPACE_WITH_COLON: String = "macro:"

public func isMacroPath(str: String): Bool {
    return str.startsWith(MACRO_NAMESPACE_WITH_COLON)
}

public enum MacroError {
    | MacroFailed
    | OutOfMemory
    | ToJS(ToJSError)
    | JSError
    | JSTerminated

    public func toBaoError(): BaoError {
        match (this) {
            case MacroFailed => BaoError(ErrorCode.BundlerError, "MacroFailed")
            case OutOfMemory => BaoError(ErrorCode.OutOfMemory, "OutOfMemory")
            case ToJS(err) => BaoError(ErrorCode.BundlerError, errName(err))
            case JSError => BaoError(ErrorCode.BundlerError, "JSError")
            case JSTerminated => BaoError(ErrorCode.Aborted, "JSTerminated")
        }
    }
}

private func errName(err: ToJSError): String {
    match (err) {
        case CannotConvertArgumentTypeToJS => "CannotConvertArgumentTypeToJS"
        case CannotConvertIdentifierToJS => "CannotConvertIdentifierToJS"
        case MacroError => "MacroError"
        case OutOfMemory => "OutOfMemory"
        case JSError => "JSError"
        case JSTerminated => "JSTerminated"
    }
}

public class MacroContext {
    public var macros: HashMap<Int64, Macro>
    public var javascriptObject: JsValue

    public init() {
        macros = HashMap<Int64, Macro>()
        javascriptObject = JsValue.jsUndefined()
    }

    public static func initFunc(): MacroContext {
        return MacroContext()
    }

    public func getRemap(path: String): ?MacroRemapEntry {
        return None
    }

    public func call(
        importRecordPath: String,
        sourceDir: String,
        caller: ASTNode,
        functionName: String
    ): Result<ASTNode, BaoError> {
        let importRecordPathWithoutMacroPrefix = if (isMacroPath(importRecordPath)) {
            importRecordPath[Int64(MACRO_NAMESPACE_WITH_COLON.size)..importRecordPath.size]
        } else {
            importRecordPath
        }

        let inputSpecifier = importRecordPathWithoutMacroPrefix
        let hash = MacroEntryPoint.generateID(inputSpecifier, functionName)
        var `macro` = match (macros.get(hash)) {
            case Some(existing) => existing
            case None =>
                let created = Macro.initFunc(inputSpecifier, functionName, inputSpecifier, hash)
                macros.put(hash, created)
                created
        }

        if (`macro`.disabled) {
            return Result<ASTNode, BaoError>.Ok(caller)
        }

        let vm = `macro`.vm
        vm.enableMacroMode()
        let result = MacroRunner.run(
            `macro`,
            functionName,
            caller,
            hash,
            javascriptObject
        )
        vm.disableMacroMode()

        match (result) {
            case Ok(expr) => return Result<ASTNode, BaoError>.Ok(expr)
            case Err(err) => return Result<ASTNode, BaoError>.Err(err.toBaoError())
        }
    }
}

public class MacroRemapEntry {
    public var path: String

    public init(path: String) {
        this.path = path
    }
}

public class MacroEntryPoint {
    public static func generateID(inputSpecifier: String, functionName: String): Int64 {
        var hash: Int64 = 5381
        for (ch in inputSpecifier) {
            hash = ((hash * 33) + Int64(ch)) & Int64(0x7fffffff)
        }
        for (ch in functionName) {
            hash = ((hash * 33) + Int64(ch)) & Int64(0x7fffffff)
        }
        return hash
    }
}

public class MacroResult {
    public var importStatements: ArrayList<Any>
    public var replacement: ASTNode

    public init(replacement: ASTNode) {
        importStatements = ArrayList<Any>()
        this.replacement = replacement
    }
}

public class Macro {
    public var vm: BunVirtualMachine
    public var resolved: String
    public var disabled: Bool

    public init() {
        if (BunVirtualMachine.isLoaded()) {
            vm = BunVirtualMachine.get()
        } else {
            vm = BunVirtualMachine.create(BunVirtualMachineOptions())
        }
        resolved = ""
        disabled = true
    }

    public static func disabledSentinel(): Macro {
        return Macro()
    }

    public static func initFunc(inputSpecifier: String, functionName: String, specifier: String, hash: Int64): Macro {
        let `macro` = Macro()
        `macro`.disabled = false
        `macro`.resolved = inputSpecifier
        `macro`.vm.enableMacroMode()
        let loaded = `macro`.vm.loadMacroEntryPoint(inputSpecifier, functionName, specifier, hash)
        if (loaded.isNone()) {
            `macro`.disabled = true
        }
        `macro`.vm.disableMacroMode()
        return `macro`
    }
}

public class MacroRunner {
    public init() {}

    public static func runAsync(
        `macro`: Macro,
        functionName: String,
        caller: ASTNode,
        args: Array<JsValue>,
        id: Int64
    ): Result<ASTNode, MacroError> {
        let callback = match (`macro`.vm.macros.get(id)) {
            case Some(cb) => cb
            case None => return Result<ASTNode, MacroError>.Ok(caller)
        }
        let result = callback.get(functionName)
        let runner = MacroRun(`macro`, functionName, caller)
        return runner.run(result)
    }

    public static func run(
        `macro`: Macro,
        functionName: String,
        caller: ASTNode,
        id: Int64,
        javascriptObject: JsValue
    ): Result<ASTNode, MacroError> {
        var jsArgs = ArrayList<JsValue>()

        match (caller.value) {
            case call: ECall =>
                for (arg in call.args) {
                    match (exprToJS(arg, JSGlobalObject(`macro`.vm))) {
                        case Ok(value) => jsArgs.append(value)
                        case Err(err) => return Result<ASTNode, MacroError>.Err(MacroError.ToJS(err))
                    }
                }
            case _ =>
                if (caller.tag != ExprTag.Call) {
                    return Result<ASTNode, MacroError>.Err(MacroError.MacroFailed)
                }
        }

        if (!javascriptObject.isUndefined()) {
            jsArgs.append(javascriptObject)
        }

        return runAsync(`macro`, functionName, caller, jsArgs.items(), id)
    }
}

public class MacroRun {
    public var caller: ASTNode
    public var functionName: String
    public var `macro`: Macro
    public var visited: HashMap<Int64, ASTNode>
    public var isTopLevel: Bool

    public init(`macro`: Macro, functionName: String, caller: ASTNode) {
        this.`macro` = `macro`
        this.functionName = functionName
        this.caller = caller
        this.visited = HashMap<Int64, ASTNode>()
        this.isTopLevel = false
    }

    public func run(value: JsValue): Result<ASTNode, MacroError> {
        if (value.isUndefined()) { return coerceUndefined(value) }
        if (value.isNull()) { return Result<ASTNode, MacroError>.Ok(ASTNode(ExprTag.Null, caller.loc, ENull())) }
        if (value.isBoolean()) { return Result<ASTNode, MacroError>.Ok(ASTNode(ExprTag.Boolean, caller.loc, EBoolean(value.toBoolean()))) }
        if (value.isNumber()) { return Result<ASTNode, MacroError>.Ok(ASTNode(ExprTag.Number, caller.loc, ENumber(value.asNumber()))) }
        if (value.isString()) { return Result<ASTNode, MacroError>.Ok(ASTNode(ExprTag.StringExpr, caller.loc, EString(value.toString()))) }
        if (value.isArray()) { return coerceArray(value) }
        if (value.isError() || value.isAggregateError(`macro`.vm.globalObject) || value.isException()) {
            let _ = `macro`.vm.uncaughtException(`macro`.vm.globalObject, value, false)
            return Result<ASTNode, MacroError>.Err(MacroError.MacroFailed)
        }
        if (value.valueType == JsValueType.Promise) { return coercePromise(value) }
        if (value.isObject()) { return coerceObject(value) }

        return Result<ASTNode, MacroError>.Err(MacroError.MacroFailed)
    }

    private func coerceUndefined(value: JsValue): Result<ASTNode, MacroError> {
        if (isTopLevel) {
            return Result<ASTNode, MacroError>.Ok(caller)
        }
        return Result<ASTNode, MacroError>.Ok(ASTNode(ExprTag.Undefined, caller.loc, EUndefined()))
    }

    private func coerceArray(value: JsValue): Result<ASTNode, MacroError> {
        isTopLevel = false
        let identity = value.identity()
        if (let Some(cached) <- visited.get(identity)) {
            return Result<ASTNode, MacroError>.Ok(cached)
        }

        let array = EArray()
        array.wasOriginallyMacro = true
        let expr = ASTNode(ExprTag.Array, caller.loc, array)
        visited.put(identity, expr)

        var iter = JsArrayIterator_.initFunc(value, `macro`.vm.globalObject)
        while (let Some(item) <- iter.next()) {
            match (run(item)) {
                case Ok(elem) =>
                    if (elem.tag != ExprTag.Missing) {
                        array.items.append(elem)
                    }
                case Err(err) => return Result<ASTNode, MacroError>.Err(err)
            }
        }
        return Result<ASTNode, MacroError>.Ok(expr)
    }

    private func coerceObject(value: JsValue): Result<ASTNode, MacroError> {
        isTopLevel = false
        let identity = value.identity()
        if (let Some(cached) <- visited.get(identity)) {
            return Result<ASTNode, MacroError>.Ok(cached)
        }

        let raw = match (value.getObject()) {
            case Some(obj) => obj
            case None => return Result<ASTNode, MacroError>.Err(MacroError.MacroFailed)
        }
        let object = EObject()
        object.wasOriginallyMacro = true
        let expr = ASTNode(ExprTag.Object, caller.loc, object)
        visited.put(identity, expr)

        for (key in raw.keys()) {
            let propValue = raw.get(key)
            match (run(propValue)) {
                case Ok(objectValue) =>
                    let `prop` = GProperty(ASTNode(ExprTag.StringExpr, caller.loc, key), objectValue)
                    object.properties.append(`prop`)
                case Err(err) => return Result<ASTNode, MacroError>.Err(err)
            }
        }
        return Result<ASTNode, MacroError>.Ok(expr)
    }

    private func coercePromise(value: JsValue): Result<ASTNode, MacroError> {
        let promise = match (value.asAnyPromise()) {
            case Some(p) => p
            case None => return Result<ASTNode, MacroError>.Err(MacroError.MacroFailed)
        }
        `macro`.vm.waitForPromise(JsObject.make())
        let result = promise.result(JsVirtualMachine())
        let isRejected = match (promise.status()) {
            case JSPromiseStatus.Rejected => true
            case _ => false
        }
        if (isRejected || result.isError() ||
            result.isAggregateError(`macro`.vm.globalObject) || result.isException()) {
            `macro`.vm.unhandledRejection(`macro`.vm.globalObject, result, value)
            return Result<ASTNode, MacroError>.Err(MacroError.MacroFailed)
        }
        return run(result)
    }
}
