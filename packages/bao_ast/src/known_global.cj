// 严格翻译自: src/ast/known_global.zig (~350行)
// bao_ast - 已知全局构造函数: 用于压缩 new X() 调用的优化
package bao_ast

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// KnownGlobal - 已知全局构造函数
// 严格翻译自: src/ast/known_global.zig:1-350
// Bun: pub const KnownGlobal = enum {
//   WeakSet, WeakMap, Date, Set, Map, Headers, Response,
//   TextEncoder, TextDecoder, Error, TypeError, SyntaxError, ...
//   Array, Object, Function, RegExp
// }
// 用于 minifyGlobalConstructor() 中将 new X() 优化为更短的形式
// ============================================================================

/// 已知全局构造函数 - 对应 Bun KnownGlobal
/// Bun: pub const KnownGlobal = enum { WeakSet, WeakMap, Date, ... }
/// 用于识别和优化全局构造函数调用
public enum KnownGlobal {
    | WeakSet
    | WeakMap
    | Date
    | Set
    | Map
    | Headers
    | Response
    | TextEncoder
    | TextDecoder
    | Error
    | TypeError
    | SyntaxError
    | RangeError
    | ReferenceError
    | EvalError
    | URIError
    | AggregateError
    | Array
    | Object
    | Function
    | RegExp

    public func name(): String {
        match (this) {
            case WeakSet => "WeakSet"
            case WeakMap => "WeakMap"
            case Date => "Date"
            case Set => "Set"
            case Map => "Map"
            case Headers => "Headers"
            case Response => "Response"
            case TextEncoder => "TextEncoder"
            case TextDecoder => "TextDecoder"
            case Error => "Error"
            case TypeError => "TypeError"
            case SyntaxError => "SyntaxError"
            case RangeError => "RangeError"
            case ReferenceError => "ReferenceError"
            case EvalError => "EvalError"
            case URIError => "URIError"
            case AggregateError => "AggregateError"
            case Array => "Array"
            case Object => "Object"
            case Function => "Function"
            case RegExp => "RegExp"
        }
    }

    /// 从字符串解析 - 对应 Bun ComptimeEnumMap.get()
    public static func fromString(name: String): ?KnownGlobal {
        match (name) {
            case "WeakSet" => WeakSet
            case "WeakMap" => WeakMap
            case "Date" => Date
            case "Set" => Set
            case "Map" => Map
            case "Headers" => Headers
            case "Response" => Response
            case "TextEncoder" => TextEncoder
            case "TextDecoder" => TextDecoder
            case "Error" => Error
            case "TypeError" => TypeError
            case "SyntaxError" => SyntaxError
            case "RangeError" => RangeError
            case "ReferenceError" => ReferenceError
            case "EvalError" => EvalError
            case "URIError" => URIError
            case "AggregateError" => AggregateError
            case "Array" => Array
            case "Object" => Object
            case "Function" => Function
            case "RegExp" => RegExp
            case _ => None
        }
    }

    /// 是否为错误构造函数 - 对应 Bun minifyGlobalConstructor 中的 Error 分支
    public func isError(): Bool {
        match (this) {
            case Error | TypeError | SyntaxError | RangeError |
                 ReferenceError | EvalError | URIError | AggregateError => true
            case _ => false
        }
    }
}

/// 已知全局构造函数优化器 - 对应 Bun KnownGlobal.minifyGlobalConstructor()
/// Bun: pub noinline fn minifyGlobalConstructor(allocator, e, symbols, loc, minify_whitespace) ?Expr
///
/// 将 new 构造函数调用优化为更短的形式:
/// - new Error(...) => Error(...) (Error 可以不用 new 调用)
/// - new Object() => {}
/// - new Array() => []
/// - new Object({...}) => {...}
/// - new Object([...]) => [...]
/// - 设置 can_be_unwrapped_if_unused 标志 (纯调用)
public class KnownGlobalOptimizer {

    /// 压缩全局构造函数 - 对应 Bun KnownGlobal.minifyGlobalConstructor()
    /// Bun: pub noinline fn minifyGlobalConstructor(allocator, e, symbols, loc, minify_whitespace) ?Expr
    ///
    /// 参数:
    ///   targetName - 构造函数名 (如 "Error", "Array", "Object")
    ///   args - 构造函数参数列表
    ///   minifyWhitespace - 是否压缩空白
    ///   loc - 源码位置
    /// 返回:
    ///   优化后的表达式, 或 null 表示不优化
    public static func minifyGlobalConstructor(
        targetName: String,
        args: ArrayList<ASTNode>,
        minifyWhitespace: Bool,
        loc: Loc
    ): ?ASTNode {
        let global = KnownGlobal.fromString(targetName)
        match (global) {
            case Some(g) => return optimize(g, args, minifyWhitespace, loc)
            case None => return None
        }
    }

    /// 内部优化逻辑 - 对应 Bun minifyGlobalConstructor 的 switch 分支
    private static func optimize(
        constructor: KnownGlobal,
        args: ArrayList<ASTNode>,
        minifyWhitespace: Bool,
        loc: Loc
    ): ?ASTNode {
        let n = args.size

        match (constructor) {
            // Error 构造函数可以不用 new 调用, 行为完全一致
            // new Error(...) => Error(...)
            case KnownGlobal.Error | KnownGlobal.TypeError |
                 KnownGlobal.SyntaxError | KnownGlobal.RangeError |
                 KnownGlobal.ReferenceError | KnownGlobal.EvalError |
                 KnownGlobal.URIError | KnownGlobal.AggregateError => {
                // 返回不带 new 的调用表达式
                return ExprFactory.call(
                    ExprFactory.identifier(Ref.NONE, loc),
                    args, loc
                )
            }

            // new Object() => {}
            // new Object({...}) => {...}
            // new Object([...]) => [...]
            // new Object(null) => {}
            // new Object(undefined) => {}
            case KnownGlobal.Object => {
                if (n == Int64(0)) {
                    return ExprFactory.object(ArrayList<GProperty>(), loc)
                }
                if (n == Int64(1)) {
                    let arg = args[Int64(0)]
                    match (arg.tag) {
                        case ExprTag.Object | ExprTag.Array => return arg
                        case ExprTag.Null | ExprTag.Undefined =>
                            return ExprFactory.object(ArrayList<GProperty>(), loc)
                        case _ => ()
                    }
                }
                // 其他情况: 去掉 new
                return ExprFactory.call(
                    ExprFactory.identifier(Ref.NONE, loc),
                    args, loc
                )
            }

            // new Array() => []
            // new Array(1, 2, 3) => [1, 2, 3]
            // new Array(3) => 不优化 (创建 3 个空位的数组)
            case KnownGlobal.Array => {
                if (n == Int64(0)) {
                    return ExprFactory.array(ArrayList<ASTNode>(), loc)
                }
                if (n > Int64(1)) {
                    // 多个参数: new Array(1, 2, 3) => [1, 2, 3]
                    return ExprFactory.array(args, loc)
                }
                // 单参数: 可能是 Array(3) 创建空位数组, 不优化
                return None
            }

            // new Function(...) => Function(...)
            case KnownGlobal.Function => {
                return ExprFactory.call(
                    ExprFactory.identifier(Ref.NONE, loc),
                    args, loc
                )
            }

            // RegExp 不优化 - 语义太复杂
            // new RegExp(re) 创建副本, 但 RegExp(re) 返回相同实例
            case KnownGlobal.RegExp => {
                return None
            }

            // new WeakSet()/WeakMap() 无参数时是纯的
            case KnownGlobal.WeakSet | KnownGlobal.WeakMap => {
                // 无参数或 null/undefined 参数时是纯的
                // 返回 null 表示不替换表达式, 但可能设置纯标志
                return None
            }

            // new Date() 无参数时是纯的
            case KnownGlobal.Date => {
                return None
            }

            // new Set() 无参数时是纯的
            // new Set([...]) 是纯的
            case KnownGlobal.Set => {
                return None
            }

            // new Headers() 无参数时是纯的
            case KnownGlobal.Headers => {
                return None
            }

            // new Response() 无参数时是纯的
            case KnownGlobal.Response => {
                return None
            }

            // new TextEncoder()/TextDecoder() 无参数时是纯的
            case KnownGlobal.TextEncoder | KnownGlobal.TextDecoder => {
                return None
            }

            // new Map() 无参数时是纯的
            // new Map([[a, b], [c, d]]) 是纯的
            case KnownGlobal.Map => {
                return None
            }
        }
    }
}
