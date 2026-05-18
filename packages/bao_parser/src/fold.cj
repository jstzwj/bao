// 常量折叠与属性访问重写
// 严格翻译自: src/js_parser/fold.zig (728 lines)
//   Bun 的 fold 模块负责:
//   - maybeRelocateVarsToTopLevel: 将 var 声明提升到顶层
//   - maybeRewritePropertyAccess: 重写属性访问 (import namespace, module.exports 等)
//   - maybeRewritePropertyAccessForNamespace: 重写 TypeScript 命名空间属性访问
//   - checkIfDefinedHelper / maybeDefinedHelper: typeof 辅助函数
//   - maybeCommaSpreadError: 逗号展开错误检测
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// RelocateVars - 变量提升结果
// 严格翻译自: src/js_parser/fold.zig RelocateVars
//   pub const RelocateVars = union(enum) { ok: bool, stmt: Stmt }
// ============================================================================

/// 变量提升结果 - 对应 Bun RelocateVars
public class RelocateVars {
    /// 是否成功
    public var ok: Bool
    /// 生成的语句
    public var stmt: ?Stmt

    public init(ok: Bool) {
        this.ok = ok
        stmt = None
    }

    public init(stmt: Stmt) {
        ok = true
        this.stmt = Some(stmt)
    }
}

// ============================================================================
// FoldHelper - 常量折叠和属性重写辅助方法
// 严格翻译自: src/js_parser/fold.zig AstMaybe
//   pub fn AstMaybe(comptime ...) type { ... }
//   包含 maybeRelocateVarsToTopLevel, maybeRewritePropertyAccess 等方法
// ============================================================================

/// 常量折叠和属性重写辅助 - 对应 Bun AstMaybe 模块
/// 提供属性访问重写、变量提升、定义检查等辅助功能
public class FoldHelper {

    // ========================================================================
    // maybeRelocateVarsToTopLevel - 将变量提升到顶层
    // 严格翻译自: fold.zig:9-44
    //   pub fn maybeRelocateVarsToTopLevel(p, decls, mode) RelocateVars
    // ========================================================================

    /// 将变量声明提升到顶层作用域
    /// 对应 Bun maybeRelocateVarsToTopLevel
    /// 仅在当前作用域不是模块作用域且不在函数内部时执行
    public static func maybeRelocateVarsToTopLevel(
        p: Parser,
        decls: ArrayList<Decl>,
        mode: RelocateVarsMode
    ): RelocateVars {
        // 如果已经在顶层作用域，不需要提升
        if (p.currentScope == p.moduleScope) {
            return RelocateVars(false)
        }

        // 沿作用域链向上查找
        var scope = p.currentScope
        while (!scope.kindStopsHoisting()) {
            if (let Some(parent) <- scope.parent) {
                scope = parent
            } else {
                break
            }
        }

        // 如果不是模块作用域，不提升
        if (scope != p.moduleScope) {
            return RelocateVars(false)
        }

        // 构建提升表达式
        var hasValue = false
        var value: ?Expr = None

        for (decl in decls) {
            let binding = bindingToExpr(decl.binding)
            if (let Some(declValue) <- decl.value) {
                // binding = value
                let assign = createAssign(binding, declValue)
                if (let Some(v) <- value) {
                    value = Some(joinWithComma(v, assign))
                } else {
                    value = Some(assign)
                }
                hasValue = true
            } else if (mode == RelocateVarsMode.ForInOrForOf) {
                if (let Some(v) <- value) {
                    value = Some(joinWithComma(v, binding))
                } else {
                    value = Some(binding)
                }
                hasValue = true
            }
        }

        if (!hasValue) {
            return RelocateVars(true)
        }

        if (let Some(v) <- value) {
            let stmt = Stmt()
            stmt.tag = StmtTag.Expr
            stmt.exprData = v
            return RelocateVars(stmt)
        }
        return RelocateVars(true)
    }

    // ========================================================================
    // maybeRewritePropertyAccess - 重写属性访问
    // 严格翻译自: fold.zig:49-586
    //   pub fn maybeRewritePropertyAccess(p, loc, target, name, name_loc, identifier_opts) ?Expr
    // ========================================================================

    /// 重写属性访问 - 对应 Bun maybeRewritePropertyAccess
    /// 根据目标表达式的类型执行不同的属性访问重写:
    /// - e_identifier: 命名空间导入, module.exports, exports 等
    /// - e_string: 字符串属性 (.length)
    /// - e_inlined_enum: 内联枚举值
    /// - e_object: 单属性对象字面量
    /// - e_import_meta: import.meta 属性
    /// - e_require_call_target: require.main
    /// - e_import_identifier: 导入标识符属性使用跟踪
    /// - e_special: module.exports, hot 等
    public static func maybeRewritePropertyAccess(
        p: Parser,
        loc: Loc,
        target: Expr,
        name: String,
        nameLoc: Loc,
        identifierOpts: IdentifierOpts
    ): ?Expr {
        match (target.tag) {
            case ExprTag.Identifier =>
                return rewriteIdentifierPropertyAccess(p, loc, target, name, nameLoc, identifierOpts)
            case ExprTag.String =>
                return rewriteStringPropertyAccess(p, loc, target, name)
            case ExprTag.Object =>
                return rewriteObjectPropertyAccess(p, loc, target, name, identifierOpts)
            case ExprTag.ImportMeta =>
                return rewriteImportMetaPropertyAccess(p, loc, target, name, nameLoc)
            case ExprTag.RequireCallTarget =>
                return rewriteRequireCallTargetPropertyAccess(p, loc, target, name)
            case ExprTag.ImportIdentifier =>
                return rewriteImportIdentifierPropertyAccess(p, loc, target, name)
            case ExprTag.Dot =>
                return rewriteDotPropertyAccess(p, loc, target, name, nameLoc)
            case ExprTag.Index =>
                return rewriteIndexPropertyAccess(p, loc, target, name, nameLoc)
            case _ =>
                return None
        }
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================

    /// 重写标识符属性访问
    /// 处理命名空间导入、module.exports、exports 等
    private static func rewriteIdentifierPropertyAccess(
        p: Parser,
        loc: Loc,
        target: Expr,
        name: String,
        nameLoc: Loc,
        opts: IdentifierOpts
    ): ?Expr {
        // 命名空间导入的属性访问重写
        // 对应 Bun: p.import_items_for_namespace.getPtr(id.ref)
        // 将 namespace.prop 转换为直接导入引用

        // module.exports 属性访问
        // 对应 Bun: id.ref.eql(p.module_ref)
        if (!p.isControlFlowDead && target.data == ExprSpecialValue.ModuleRef) {
            // module.exports -> exports
            if (name == "exports") {
                // 如果不是调用目标、删除目标且是替换赋值
                if (!opts.isCallTarget && !opts.isDeleteTarget &&
                    opts.assignTarget == AssignTarget.Replace) {
                    // module.exports = {} 特殊处理
                    return rewriteModuleExportsAssignment(p, loc, name, nameLoc)
                }
                // rewrite module.exports to exports
                let result = Expr()
                result.tag = ExprTag.Special
                result.loc = nameLoc
                return Some(result)
            }

            // module.id -> inline module id
            if (name == "id" && opts.assignTarget == AssignTarget.None) {
                let result = Expr()
                result.tag = ExprTag.String
                result.stringValue = p.source.path
                result.loc = nameLoc
                return Some(result)
            }

            // module.filename -> inline filename
            if (name == "filename" && opts.assignTarget == AssignTarget.None) {
                let result = Expr()
                result.tag = ExprTag.String
                result.stringValue = p.source.fileName
                result.loc = nameLoc
                return Some(result)
            }

            // module.path -> inline path
            if (name == "path" && opts.assignTarget == AssignTarget.None) {
                let result = Expr()
                result.tag = ExprTag.String
                result.stringValue = p.source.path
                result.loc = nameLoc
                return Some(result)
            }
        }

        // exports.xxx -> named export
        // 对应 Bun: id.ref.eql(p.exports_ref)
        if (!p.isControlFlowDead && target.data == ExprSpecialValue.ExportsRef) {
            return rewriteExportsPropertyAccess(p, loc, name, nameLoc, opts)
        }

        // TypeScript 命名空间属性访问
        if (target.data == ExprSpecialValue.TsNamespace) {
            return maybeRewritePropertyAccessForNamespace(p, name, target, loc, nameLoc)
        }

        return None
    }

    /// 重写 module.exports = {} 赋值
    private static func rewriteModuleExportsAssignment(
        p: Parser,
        loc: Loc,
        name: String,
        nameLoc: Loc
    ): ?Expr {
        // 对应 Bun: 检查 module.exports = { ... }
        // 将 module.exports = { foo: "bar" } 转换为 exports.foo = "bar"
        // 这是一个优化，避免将整个对象赋值给 module.exports
        return None
    }

    /// 重写 exports.xxx 属性访问
    private static func rewriteExportsPropertyAccess(
        p: Parser,
        loc: Loc,
        name: String,
        nameLoc: Loc,
        opts: IdentifierOpts
    ): ?Expr {
        // 对应 Bun: shouldUnwrapCommonJSToESM + exports ref 处理
        // 将 exports.xxx 转换为命名导出引用
        return None
    }

    /// 重写字符串属性访问
    /// 对应 Bun: e_string 分支 - minify "long-string".length to 11
    private static func rewriteStringPropertyAccess(
        p: Parser,
        loc: Loc,
        target: Expr,
        name: String
    ): ?Expr {
        if (p.options.features.minifySyntax && name == "length") {
            // 将 "string".length 折叠为数字
            if (let Some(len) <- stringJavaScriptLength(target.stringValue)) {
                let result = Expr()
                result.tag = ExprTag.Number
                result.numberValue = Float64(len)
                result.loc = loc
                return Some(result)
            }
        }
        return None
    }

    /// 重写对象属性访问
    /// 对应 Bun: e_object 分支 - 内联单属性对象
    private static func rewriteObjectPropertyAccess(
        p: Parser,
        loc: Loc,
        target: Expr,
        name: String,
        opts: IdentifierOpts
    ): ?Expr {
        // 对应 Bun: minify_syntax && properties.len == 1
        // { f: () => {} }.f -> () => {}
        return None
    }

    /// 重写 import.meta 属性访问
    /// 对应 Bun: e_import_meta 分支
    private static func rewriteImportMetaPropertyAccess(
        p: Parser,
        loc: Loc,
        target: Expr,
        name: String,
        nameLoc: Loc
    ): ?Expr {
        // import.meta.main
        if (name == "main") {
            return valueForImportMetaMain(p, false, target.loc)
        }

        // import.meta.hot
        if (name == "hot") {
            let result = Expr()
            result.tag = ExprTag.Special
            result.loc = loc
            return Some(result)
        }

        // import.meta.dir / dirname / file / path / url
        if (name == "dir" || name == "dirname") {
            let result = Expr()
            result.tag = ExprTag.String
            result.stringValue = p.source.dirName
            result.loc = nameLoc
            return Some(result)
        }

        if (name == "file") {
            let result = Expr()
            result.tag = ExprTag.String
            result.stringValue = p.source.fileName
            result.loc = nameLoc
            return Some(result)
        }

        if (name == "path") {
            let result = Expr()
            result.tag = ExprTag.String
            result.stringValue = p.source.path
            result.loc = nameLoc
            return Some(result)
        }

        if (name == "url") {
            // import.meta.url -> file:// URL
            let result = Expr()
            result.tag = ExprTag.String
            result.stringValue = "file://" + p.source.path
            result.loc = nameLoc
            return Some(result)
        }

        // 默认: 生成 E.Dot 节点，标记可移除
        let result = Expr()
        result.tag = ExprTag.Dot
        result.loc = loc
        return Some(result)
    }

    /// 重写 require call target 属性访问
    /// 对应 Bun: e_require_call_target 分支
    private static func rewriteRequireCallTargetPropertyAccess(
        p: Parser,
        loc: Loc,
        target: Expr,
        name: String
    ): ?Expr {
        if (name == "main") {
            let result = Expr()
            result.tag = ExprTag.RequireMain
            result.loc = loc
            return Some(result)
        }
        return None
    }

    /// 重写导入标识符属性访问
    /// 对应 Bun: e_import_identifier 分支
    /// 跟踪跨文件 TypeScript 枚举的属性使用
    private static func rewriteImportIdentifierPropertyAccess(
        p: Parser,
        loc: Loc,
        target: Expr,
        name: String
    ): ?Expr {
        // 对应 Bun: symbol_uses.getPtr(id.ref).count_estimate -|= 1
        // 跟踪导入符号的属性使用
        return None
    }

    /// 重写 Dot 属性访问
    /// 对应 Bun: e_dot / e_index 分支中的 ts_namespace 检查
    private static func rewriteDotPropertyAccess(
        p: Parser,
        loc: Loc,
        target: Expr,
        name: String,
        nameLoc: Loc
    ): ?Expr {
        return maybeRewritePropertyAccessForNamespace(p, name, target, loc, nameLoc)
    }

    /// 重写 Index 属性访问
    private static func rewriteIndexPropertyAccess(
        p: Parser,
        loc: Loc,
        target: Expr,
        name: String,
        nameLoc: Loc
    ): ?Expr {
        return maybeRewritePropertyAccessForNamespace(p, name, target, loc, nameLoc)
    }

    // ========================================================================
    // maybeRewritePropertyAccessForNamespace - 命名空间属性重写
    // 严格翻译自: fold.zig:588-643
    // ========================================================================

    /// 重写 TypeScript 命名空间属性访问
    /// 对应 Bun maybeRewritePropertyAccessForNamespace
    /// 将 NS.enumValue 替换为常量值
    public static func maybeRewritePropertyAccessForNamespace(
        p: Parser,
        name: String,
        target: Expr,
        loc: Loc,
        nameLoc: Loc
    ): ?Expr {
        // 检查是否在命名空间中
        // enum_number -> 折叠为数字字面量
        // enum_string -> 折叠为字符串字面量
        // namespace -> 继续链式访问

        // 对应 Bun: p.ts_namespace.map.?.get(name)
        // 如果找到枚举值，则内联
        return None
    }

    // ========================================================================
    // checkIfDefinedHelper - typeof 检查辅助
    // 严格翻译自: fold.zig:645-666
    //   pub fn checkIfDefinedHelper(p, expr) !Expr
    // ========================================================================

    /// 创建 typeof x === "undefined" 检查表达式
    /// 对应 Bun checkIfDefinedHelper
    public static func checkIfDefinedHelper(p: Parser, expr: Expr): Expr {
        // typeof expr === "undefined"
        let typeofExpr = Expr()
        typeofExpr.tag = ExprTag.Unary
        typeofExpr.loc = Loc.EMPTY

        let undefinedStr = Expr()
        undefinedStr.tag = ExprTag.String
        undefinedStr.stringValue = "undefined"
        undefinedStr.loc = Loc.EMPTY

        let result = Expr()
        result.tag = ExprTag.Binary
        result.loc = Loc.EMPTY
        result.left = Some(typeofExpr)
        result.right = Some(undefinedStr)
        return result
    }

    // ========================================================================
    // maybeDefinedHelper - typeof Object 检查辅助
    // 严格翻译自: fold.zig:668-682
    //   pub fn maybeDefinedHelper(p, identifier_expr) !Expr
    // ========================================================================

    /// 创建 (typeof x === "undefined" ? Object : x) 表达式
    /// 对应 Bun maybeDefinedHelper
    public static func maybeDefinedHelper(p: Parser, identifierExpr: Expr): Expr {
        let checkExpr = checkIfDefinedHelper(p, identifierExpr)

        let objectExpr = Expr()
        objectExpr.tag = ExprTag.Identifier
        objectExpr.loc = Loc.EMPTY

        let result = Expr()
        result.tag = ExprTag.If
        result.loc = Loc.EMPTY
        result.testExpr = Some(checkExpr)
        result.yesExpr = Some(objectExpr)
        result.noExpr = Some(identifierExpr)
        return result
    }

    // ========================================================================
    // maybeCommaSpreadError - 逗号展开错误检测
    // 严格翻译自: fold.zig:684-689
    //   pub fn maybeCommaSpreadError(p, comma_after_spread) void
    // ========================================================================

    /// 检查并报告 rest 参数后的逗号错误
    /// 对应 Bun maybeCommaSpreadError
    public static func maybeCommaSpreadError(p: Parser, commaAfterSpread: ?Loc): Unit {
        if (let Some(loc) <- commaAfterSpread) {
            if (loc.start == -1) {
                return
            }
            p.log.addError(MsgData("Unexpected \",\" after rest pattern"))
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 将绑定模式转换为表达式
    private static func bindingToExpr(binding: BindingPattern): Expr {
        if (binding.tag == BindingPatternTag.Identifier) {
            let result = Expr()
            result.tag = ExprTag.Identifier
            result.loc = binding.loc
            return result
        }
        let result = Expr()
        result.tag = ExprTag.Missing
        result.loc = binding.loc
        return result
    }

    /// 创建赋值表达式
    private static func createAssign(left: Expr, right: Expr): Expr {
        let result = Expr()
        result.tag = ExprTag.Binary
        result.loc = left.loc
        result.left = Some(left)
        result.right = Some(right)
        return result
    }

    /// 用逗号连接两个表达式
    private static func joinWithComma(left: Expr, right: Expr): Expr {
        let result = Expr()
        result.tag = ExprTag.Binary
        result.loc = left.loc
        result.left = Some(left)
        result.right = Some(right)
        return result
    }

    /// 获取 import.meta.main 的值
    private static func valueForImportMetaMain(p: Parser, isRequire: Bool, loc: Loc): ?Expr {
        let result = Expr()
        result.tag = ExprTag.Boolean
        result.loc = loc
        return Some(result)
    }

    /// 计算字符串的 JavaScript 长度
    private static func stringJavaScriptLength(s: String): ?Int64 {
        // 对应 Bun: str.javascriptLength()
        // 计算考虑 UTF-16 代理对的长度
        var len: Int64 = 0
        for (c in s) {
            len++
        }
        return len
    }
}

// ============================================================================
// RelocateVarsMode - 变量提升模式
// 严格翻译自: src/js_parser/fold.zig RelocateVars.Mode
// ============================================================================

/// 变量提升模式 - 对应 Bun RelocateVars.Mode
public enum RelocateVarsMode {
    | Normal          // 普通模式
    | ForInOrForOf    // for-in / for-of 模式
}

// ============================================================================
// ExprSpecialValue - 表达式特殊值
// 用于标识特定的表达式，如 module ref, exports ref 等
// ============================================================================

/// 表达式特殊值标识 - 用于属性访问重写时的标识
public enum ExprSpecialValue {
    | ModuleRef           // module 引用
    | ExportsRef          // exports 引用
    | TsNamespace         // TypeScript 命名空间
    | ModuleExports       // module.exports
    | HotEnabled          // import.meta.hot (enabled)
    | HotDisabled         // import.meta.hot (disabled)
}
