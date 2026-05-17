// bao_js_printer - JavaScript code printer
// 严格翻译自 Bun 的 src/js_printer/ 模块
//   Bun 的 js_printer 模块将 AST 节点生成 JavaScript 源代码
//
// Bun 源文件对应关系:
//   src/js_printer/js_printer.zig -> js_printer.cj (核心打印器)
//   src/js_printer/js_printer.zig -> js_printer_expr.cj (表达式打印)
//   src/js_printer/js_printer.zig -> js_printer_stmt.cj (语句打印)
//   src/js_printer/js_printer.zig -> js_printer_writer.cj (Writer 和入口函数)
//   src/js_printer/renamer.zig    -> renamer.cj (符号重命名器)
//   src/js_printer/lib.rs         -> module_info.cj (ModuleInfo 分析)
//
// 仓颉翻译说明:
//   - Zig 的 comptime 泛型 (NewPrinter) 在仓颉中用类字段代替
//   - Writer 类型参数化用 PrinterWriter 接口代替
//   - ExprFlag.Set (EnumSet) 用位标志类代替
//   - Whitespacer 的 comptime 计算改为运行时处理
package bao_js_printer

import bao_core.*
import bao_collections.*

/// 操作符代码 - 对应 Bun Op.Code
public enum OpCode {
    | UnPos
    | UnNeg
    | UnCpl
    | UnBitNot
    | UnNot
    | UnPreInc
    | UnPreDec
    | UnPostInc
    | UnPostDec
    | UnVoid
    | UnDelete
    | Typeof
    | UnTypeof
    | BinAdd
    | BinSub
    | BinMul
    | BinDiv
    | BinRem
    | BinMod
    | BinPow
    | BinLt
    | BinGt
    | BinLe
    | BinGe
    | BinIn
    | BinInstanceof
    | BinShl
    | BinShr
    | BinUShr
    | BinUshr
    | BinEq
    | BinNe
    | BinEqStrict
    | BinNeStrict
    | BinAnd
    | BinOr
    | BinXor
    | BinLoAnd
    | BinLogicalAnd
    | BinLoOr
    | BinLogicalOr
    | BinNullish
    | BinNullishCoalescing
    | BinAssign
    | BinAddAssign
    | BinSubAssign
    | BinMulAssign
    | BinDivAssign
    | BinRemAssign
    | BinPowAssign
    | BinShlAssign
    | BinShrAssign
    | BinUShrAssign
    | BinAndAssign
    | BinOrAssign
    | BinXorAssign
    | BinLoAndAssign
    | BinLoOrAssign
    | BinNullishAssign
    | Comma
    | BinComma
    | Spread

    public func isAssign(): Bool {
        match (this) {
            case BinAssign | BinAddAssign | BinSubAssign | BinMulAssign |
                 BinDivAssign | BinRemAssign | BinPowAssign | BinShlAssign |
                 BinShrAssign | BinUShrAssign | BinAndAssign | BinOrAssign |
                 BinXorAssign | BinLoAndAssign | BinLoOrAssign | BinNullishAssign => true
            case _ => false
        }
    }

    public func text(): String {
        match (this) {
            case UnPos => "+"
            case UnNeg => "-"
            case UnCpl => "~"
            case UnBitNot => "~"
            case UnNot => "!"
            case UnPreInc => "++"
            case UnPreDec => "--"
            case UnPostInc => "++"
            case UnPostDec => "--"
            case UnVoid => "void"
            case UnDelete => "delete"
            case Typeof => "typeof"
            case UnTypeof => "typeof"
            case BinAdd => "+"
            case BinSub => "-"
            case BinMul => "*"
            case BinDiv => "/"
            case BinRem => "%"
            case BinMod => "%"
            case BinPow => "**"
            case BinLt => "<"
            case BinGt => ">"
            case BinLe => "<="
            case BinGe => ">="
            case BinUShr => ">>>"
            case BinUshr => ">>>"
            case BinIn => "in"
            case BinInstanceof => "instanceof"
            case BinEq => "=="
            case BinNe => "!="
            case BinEqStrict => "==="
            case BinNeStrict => "!=="
            case BinAnd => "&"
            case BinOr => "|"
            case BinXor => "^"
            case BinLoAnd => "&&"
            case BinLogicalAnd => "&&"
            case BinLoOr => "||"
            case BinLogicalOr => "||"
            case BinNullish => "??"
            case BinNullishCoalescing => "??"
            case BinAssign => "="
            case BinAddAssign => "+="
            case BinSubAssign => "-="
            case BinMulAssign => "*="
            case BinDivAssign => "/="
            case BinRemAssign => "%="
            case BinPowAssign => "**="
            case BinShlAssign => "<<="
            case BinShrAssign => ">>="
            case BinUShrAssign => ">>>="
            case BinAndAssign => "&="
            case BinOrAssign => "|="
            case BinXorAssign => "^="
            case BinLoAndAssign => "&&="
            case BinLoOrAssign => "||="
            case BinNullishAssign => "??="
            case Comma => ","
            case BinComma => ","
            case Spread => "..."
            case _ => "??"
        }
    }

    public operator func ==(right: OpCode): Bool {
        this.text() == right.text()
    }

    public operator func !=(right: OpCode): Bool {
        !(this == right)
    }
}

/// 操作符优先级 - 对应 Bun Op.Level
public enum OpLevel {
    | Comma
    | Spread
    | Yield
    | Assign
    | Conditional
    | NullishCoalescing
    | LogicalOr
    | LogicalAnd
    | BitwiseOr
    | BitwiseXor
    | BitwiseAnd
    | Equality
    | Relational
    | Shift
    | Additive
    | Multiplicative
    | Exponentiation
    | Unary
    | Update
    | Member
    | Call
    | Primary

    public func ordinal(): Int64 {
        match (this) {
            case Comma => 0
            case Spread => 1
            case Yield => 2
            case Assign => 3
            case Conditional => 4
            case NullishCoalescing => 5
            case LogicalOr => 6
            case LogicalAnd => 7
            case BitwiseOr => 8
            case BitwiseXor => 9
            case BitwiseAnd => 10
            case Equality => 11
            case Relational => 12
            case Shift => 13
            case Additive => 14
            case Multiplicative => 15
            case Exponentiation => 16
            case Unary => 17
            case Update => 18
            case Member => 19
            case Call => 20
            case Primary => 21
        }
    }
}
