// bao_ast - 操作符定义
// 严格翻译自: src/ast/op.zig (292L)
//   Op.Code - 操作符代码枚举 (一元/二元/赋值)
//   Op.Level - 操作符优先级
//   Op - 操作符结构体 (text, level, is_keyword)
//   Op.Table - 操作符查找表 (编译期生成)
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// OpCode - 操作符代码
// 严格翻译自: src/ast/op.zig:1-144
//   pub const Code = enum { un_pos, un_neg, ..., bin_add, bin_sub, ..., bin_assign, ... }
//   操作符按类别排列：前缀一元、前缀更新、后缀更新、左结合二元、
//   非结合二元、右结合赋值
// ============================================================================

/// 操作符代码 - 对应 Bun Op.Code
/// Bun: enum(u8) 包含所有 JS 操作符
/// 顺序严格对应 Bun 源码中枚举值的顺序，用于依赖 ordinal 的判断逻辑
public enum OpCode {
    // ---- 前缀一元操作符 ----
    | UnPos          // +expr    一元正号
    | UnNeg          // -expr    一元负号
    | UnCpl          // ~expr    按位取反
    | UnNot          // !expr    逻辑非
    | UnVoid         // void expr
    | UnTypeof       // typeof expr
    | UnDelete       // delete expr

    // ---- 前缀更新操作符 ----
    | UnPreDec       // --expr   前缀递减
    | UnPreInc       // ++expr   前缀递增

    // ---- 后缀更新操作符 ----
    | UnPostDec      // expr--   后缀递减
    | UnPostInc      // expr++   后缀递增

    // ---- 左结合二元操作符 ----
    | BinAdd         // +        左结合
    | BinSub         // -        左结合
    | BinMul         // *        左结合
    | BinDiv         // /        左结合
    | BinRem         // %        左结合
    | BinPow         // **       左结合
    | BinLt          // <        左结合
    | BinLe          // <=       左结合
    | BinGt          // >        左结合
    | BinGe          // >=       左结合
    | BinIn          // in       左结合
    | BinInstanceof  // instanceof 左结合
    | BinShl         // <<       左结合
    | BinShr         // >>       左结合
    | BinUShr        // >>>      左结合
    | BinLooseEq     // ==       左结合
    | BinLooseNe     // !=       左结合
    | BinStrictEq    // ===      左结合
    | BinStrictNe    // !==      左结合
    | BinNullishCoalescing // ?? 左结合
    | BinLogicalOr   // ||       左结合
    | BinLogicalAnd  // &&       左结合
    | BinBitwiseOr   // |        左结合
    | BinBitwiseAnd  // &        左结合
    | BinBitwiseXor  // ^        左结合

    // ---- 非结合二元操作符 ----
    | BinComma       // ,        非结合

    // ---- 右结合赋值操作符 ----
    | BinAssign              // =     右结合
    | BinAddAssign           // +=    右结合
    | BinSubAssign           // -=    右结合
    | BinMulAssign           // *=    右结合
    | BinDivAssign           // /=    右结合
    | BinRemAssign           // %=    右结合
    | BinPowAssign           // **=   右结合
    | BinShlAssign           // <<=   右结合
    | BinShrAssign           // >>=   右结合
    | BinUShrAssign          // >>>=  右结合
    | BinBitwiseOrAssign     // |=    右结合
    | BinBitwiseAndAssign    // &=    右结合
    | BinBitwiseXorAssign    // ^=    右结合
    | BinNullishCoalescingAssign // ??= 右结合
    | BinLogicalOrAssign     // ||=   右结合
    | BinLogicalAndAssign    // &&=   右结合

    /// 序数值 - 用于依赖枚举顺序的判断
    /// 严格保持与 Bun 枚举值相同的序号
    public func ordinal(): Int64 {
        match (this) {
            case UnPos => 0
            case UnNeg => 1
            case UnCpl => 2
            case UnNot => 3
            case UnVoid => 4
            case UnTypeof => 5
            case UnDelete => 6
            case UnPreDec => 7
            case UnPreInc => 8
            case UnPostDec => 9
            case UnPostInc => 10
            case BinAdd => 11
            case BinSub => 12
            case BinMul => 13
            case BinDiv => 14
            case BinRem => 15
            case BinPow => 16
            case BinLt => 17
            case BinLe => 18
            case BinGt => 19
            case BinGe => 20
            case BinIn => 21
            case BinInstanceof => 22
            case BinShl => 23
            case BinShr => 24
            case BinUShr => 25
            case BinLooseEq => 26
            case BinLooseNe => 27
            case BinStrictEq => 28
            case BinStrictNe => 29
            case BinNullishCoalescing => 30
            case BinLogicalOr => 31
            case BinLogicalAnd => 32
            case BinBitwiseOr => 33
            case BinBitwiseAnd => 34
            case BinBitwiseXor => 35
            case BinComma => 36
            case BinAssign => 37
            case BinAddAssign => 38
            case BinSubAssign => 39
            case BinMulAssign => 40
            case BinDivAssign => 41
            case BinRemAssign => 42
            case BinPowAssign => 43
            case BinShlAssign => 44
            case BinShrAssign => 45
            case BinUShrAssign => 46
            case BinBitwiseOrAssign => 47
            case BinBitwiseAndAssign => 48
            case BinBitwiseXorAssign => 49
            case BinNullishCoalescingAssign => 50
            case BinLogicalOrAssign => 51
            case BinLogicalAndAssign => 52
        }
    }

    /// 一元赋值目标 - 对应 Bun Op.Code.unaryAssignTarget()
    /// Bun: pub fn unaryAssignTarget(code: Op.Code) AssignTarget
    /// 前缀递减/递增到后缀递减/递增之间为 update，其他为 none
    public func unaryAssignTarget(): AssignTarget {
        let ord = ordinal()
        if (ord >= OpCode.UnPreDec.ordinal() && ord <= OpCode.UnPostInc.ordinal()) {
            return AssignTarget.Update
        }
        return AssignTarget.None
    }

    /// 是否为左结合 - 对应 Bun Op.Code.isLeftAssociative()
    /// Bun: 从 bin_add 到 bin_comma 之间 (不含 bin_pow) 为左结合
    public func isLeftAssociative(): Bool {
        let ord = ordinal()
        return ord >= OpCode.BinAdd.ordinal() &&
               ord < OpCode.BinComma.ordinal() &&
               this != OpCode.BinPow
    }

    /// 是否为右结合 - 对应 Bun Op.Code.isRightAssociative()
    /// Bun: bin_assign 及之后 或 bin_pow 为右结合
    public func isRightAssociative(): Bool {
        return ordinal() >= OpCode.BinAssign.ordinal() || this == OpCode.BinPow
    }

    /// 二元赋值目标 - 对应 Bun Op.Code.binaryAssignTarget()
    /// Bun: bin_assign 为 replace，之后的为 update
    public func binaryAssignTarget(): AssignTarget {
        if (this == OpCode.BinAssign) {
            return AssignTarget.Replace
        }
        if (ordinal() > OpCode.BinAssign.ordinal()) {
            return AssignTarget.Update
        }
        return AssignTarget.None
    }

    /// 是否为前缀 - 对应 Bun Op.Code.isPrefix()
    /// Bun: 在 un_post_dec 之前的都是前缀
    public func isPrefix(): Bool {
        return ordinal() < OpCode.UnPostDec.ordinal()
    }

    /// 是否为赋值操作符
    public func isAssign(): Bool {
        return ordinal() >= OpCode.BinAssign.ordinal()
    }

    /// 是否为二元操作符 (非赋值)
    public func isBinaryNonAssign(): Bool {
        let ord = ordinal()
        return ord >= OpCode.BinAdd.ordinal() && ord <= OpCode.BinComma.ordinal()
    }

    /// 是否为一元操作符
    public func isUnary(): Bool {
        return ordinal() <= OpCode.UnPostInc.ordinal()
    }

    /// 获取操作符文本 - 对应 Bun Op.Table 中的 text 字段
    public func text(): String {
        match (this) {
            // 前缀一元
            case UnPos => "+"
            case UnNeg => "-"
            case UnCpl => "~"
            case UnNot => "!"
            case UnVoid => "void"
            case UnTypeof => "typeof"
            case UnDelete => "delete"
            // 前缀更新
            case UnPreDec => "--"
            case UnPreInc => "++"
            // 后缀更新
            case UnPostDec => "--"
            case UnPostInc => "++"
            // 左结合二元
            case BinAdd => "+"
            case BinSub => "-"
            case BinMul => "*"
            case BinDiv => "/"
            case BinRem => "%"
            case BinPow => "**"
            case BinLt => "<"
            case BinLe => "<="
            case BinGt => ">"
            case BinGe => ">="
            case BinIn => "in"
            case BinInstanceof => "instanceof"
            case BinShl => "<<"
            case BinShr => ">>"
            case BinUShr => ">>>"
            case BinLooseEq => "=="
            case BinLooseNe => "!="
            case BinStrictEq => "==="
            case BinStrictNe => "!=="
            case BinNullishCoalescing => "??"
            case BinLogicalOr => "||"
            case BinLogicalAnd => "&&"
            case BinBitwiseOr => "|"
            case BinBitwiseAnd => "&"
            case BinBitwiseXor => "^"
            // 非结合
            case BinComma => ","
            // 右结合赋值
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
            case BinBitwiseOrAssign => "|="
            case BinBitwiseAndAssign => "&="
            case BinBitwiseXorAssign => "^="
            case BinNullishCoalescingAssign => "??="
            case BinLogicalOrAssign => "||="
            case BinLogicalAndAssign => "&&="
        }
    }

    /// 是否为关键字操作符 - 对应 Bun Op.Table 中的 is_keyword 字段
    public func isKeyword(): Bool {
        match (this) {
            case UnVoid | UnTypeof | UnDelete | BinIn | BinInstanceof => true
            case _ => false
        }
    }
}

// ============================================================================
// OpLevel - 操作符优先级
// 严格翻译自: src/ast/op.zig:146-194
//   pub const Level = enum(u6) {
//       lowest, comma,spread,yield,assign,conditional,nullish_coalescing,
//       logical_or,logical_and,bitwise_or,bitwise_xor,bitwise_and,
//       equals,compare,shift,add,multiply,exponentiation,prefix,postfix,new,call,member
//   }
// ============================================================================

/// 操作符优先级 - 对应 Bun Op.Level
/// Bun: enum(u6) 从低到高排列
/// 用于表达式解析和打印时的优先级判断
public enum OpLevel {
    | Lowest               // 0  - 最低
    | Comma                // 1  - ,
    | Spread               // 2  - ...
    | Yield                // 3  - yield
    | Assign               // 4  - = += -= ...
    | Conditional          // 5  - ?:
    | NullishCoalescing    // 6  - ??
    | LogicalOr            // 7  - ||
    | LogicalAnd           // 8  - &&
    | BitwiseOr            // 9  - |
    | BitwiseXor           // 10 - ^
    | BitwiseAnd           // 11 - &
    | Equals               // 12 - == != === !==
    | Compare              // 13 - < > <= >= in instanceof
    | Shift                // 14 - << >> >>>
    | Add                  // 15 - + -
    | Multiply             // 16 - * / %
    | Exponentiation       // 17 - **
    | Prefix               // 18 - ! ~ + - typeof void delete
    | Postfix              // 19 - ++ --
    | New                  // 20 - new
    | Call                 // 21 - f()
    | Member               // 22 - . []

    /// 序数值 - 对应 Bun enum 的整数值
    public func ordinal(): Int64 {
        match (this) {
            case Lowest => 0
            case Comma => 1
            case Spread => 2
            case Yield => 3
            case Assign => 4
            case Conditional => 5
            case NullishCoalescing => 6
            case LogicalOr => 7
            case LogicalAnd => 8
            case BitwiseOr => 9
            case BitwiseXor => 10
            case BitwiseAnd => 11
            case Equals => 12
            case Compare => 13
            case Shift => 14
            case Add => 15
            case Multiply => 16
            case Exponentiation => 17
            case Prefix => 18
            case Postfix => 19
            case New => 20
            case Call => 21
            case Member => 22
        }
    }

    /// 小于比较 - 对应 Bun Level.lt()
    /// Bun: pub inline fn lt(self: Level, b: Level) bool
    public func lt(other: OpLevel): Bool {
        return ordinal() < other.ordinal()
    }

    /// 大于比较 - 对应 Bun Level.gt()
    public func gt(other: OpLevel): Bool {
        return ordinal() > other.ordinal()
    }

    /// 大于等于 - 对应 Bun Level.gte()
    public func gte(other: OpLevel): Bool {
        return ordinal() >= other.ordinal()
    }

    /// 小于等于 - 对应 Bun Level.lte()
    public func lte(other: OpLevel): Bool {
        return ordinal() <= other.ordinal()
    }

    /// 相等比较 - 对应 Bun Level.eql()
    public func eql(other: OpLevel): Bool {
        return ordinal() == other.ordinal()
    }

    /// 减法 - 对应 Bun Level.sub()
    /// Bun: pub inline fn sub(self: Level, i: anytype) Level
    public func sub(i: Int64): OpLevel {
        return fromOrdinal(ordinal() - i)
    }

    /// 加法 - 对应 Bun Level.addF()
    /// Bun: pub inline fn addF(self: Level, i: anytype) Level
    public func addF(i: Int64): OpLevel {
        return fromOrdinal(ordinal() + i)
    }

    /// 从整数创建 - 用于 sub/addF 的辅助
    public static func fromOrdinal(ord: Int64): OpLevel {
        if (ord <= 0) { return Lowest }
        if (ord >= 22) { return Member }
        match (ord) {
            case 0 => Lowest
            case 1 => Comma
            case 2 => Spread
            case 3 => Yield
            case 4 => Assign
            case 5 => Conditional
            case 6 => NullishCoalescing
            case 7 => LogicalOr
            case 8 => LogicalAnd
            case 9 => BitwiseOr
            case 10 => BitwiseXor
            case 11 => BitwiseAnd
            case 12 => Equals
            case 13 => Compare
            case 14 => Shift
            case 15 => Add
            case 16 => Multiply
            case 17 => Exponentiation
            case 18 => Prefix
            case 19 => Postfix
            case 20 => New
            case 21 => Call
            case 22 => Member
            case _ => Lowest
        }
    }
}

// ============================================================================
// Op - 操作符结构体
// 严格翻译自: src/ast/op.zig:196-212
//   pub const Op = struct {
//       text: string,
//       level: Level,
//       is_keyword: bool = false,
//   }
// ============================================================================

/// 操作符 - 对应 Bun Op
/// Bun: pub const Op = struct { text: string, level: Level, is_keyword: bool = false }
public class Op {
    /// 操作符文本 - 对应 Bun Op.text
    public var text: String
    /// 操作符优先级 - 对应 Bun Op.level
    public var level: OpLevel
    /// 是否为关键字 - 对应 Bun Op.is_keyword
    public var isKeyword: Bool

    public init(text: String, level: OpLevel, isKeyword: Bool) {
        this.text = text
        this.level = level
        this.isKeyword = isKeyword
    }

    /// 从三元组初始化 - 对应 Bun Op.init(triple)
    /// Bun: pub fn init(triple: anytype) Op
    public static func init(text: String, level: OpLevel, isKeyword: Bool): Op {
        return Op(text, level, isKeyword)
    }
}

// ============================================================================
// OpTable - 操作符查找表
// 严格翻译自: src/ast/op.zig:213-282
//   pub const Table = brk: { var table = std.EnumArray(Op.Code, Op).initUndefined(); ... }
//   编译期生成的 Op.Code -> Op 映射表
// ============================================================================

/// 操作符查找表 - 对应 Bun Op.Table
/// Bun 使用编译期 EnumArray，仓颉使用静态 HashMap
/// 包含所有 Op.Code 到 Op 的映射
public class OpTable {
    /// 操作符表 - 内部存储
    private static var table: HashMap<OpCode, Op>

    /// 初始化查找表 - 对应 Bun Op.Table 的编译期生成
    public static func init(): HashMap<OpCode, Op> {
        let t = HashMap<OpCode, Op>()

        // 前缀一元操作符
        t.put(OpCode.UnPos, Op.init("+", OpLevel.Prefix, false))
        t.put(OpCode.UnNeg, Op.init("-", OpLevel.Prefix, false))
        t.put(OpCode.UnCpl, Op.init("~", OpLevel.Prefix, false))
        t.put(OpCode.UnNot, Op.init("!", OpLevel.Prefix, false))
        t.put(OpCode.UnVoid, Op.init("void", OpLevel.Prefix, true))
        t.put(OpCode.UnTypeof, Op.init("typeof", OpLevel.Prefix, true))
        t.put(OpCode.UnDelete, Op.init("delete", OpLevel.Prefix, true))

        // 前缀更新操作符
        t.put(OpCode.UnPreDec, Op.init("--", OpLevel.Prefix, false))
        t.put(OpCode.UnPreInc, Op.init("++", OpLevel.Prefix, false))

        // 后缀更新操作符
        t.put(OpCode.UnPostDec, Op.init("--", OpLevel.Postfix, false))
        t.put(OpCode.UnPostInc, Op.init("++", OpLevel.Postfix, false))

        // 左结合二元操作符
        t.put(OpCode.BinAdd, Op.init("+", OpLevel.Add, false))
        t.put(OpCode.BinSub, Op.init("-", OpLevel.Add, false))
        t.put(OpCode.BinMul, Op.init("*", OpLevel.Multiply, false))
        t.put(OpCode.BinDiv, Op.init("/", OpLevel.Multiply, false))
        t.put(OpCode.BinRem, Op.init("%", OpLevel.Multiply, false))
        t.put(OpCode.BinPow, Op.init("**", OpLevel.Exponentiation, false))
        t.put(OpCode.BinLt, Op.init("<", OpLevel.Compare, false))
        t.put(OpCode.BinLe, Op.init("<=", OpLevel.Compare, false))
        t.put(OpCode.BinGt, Op.init(">", OpLevel.Compare, false))
        t.put(OpCode.BinGe, Op.init(">=", OpLevel.Compare, false))
        t.put(OpCode.BinIn, Op.init("in", OpLevel.Compare, true))
        t.put(OpCode.BinInstanceof, Op.init("instanceof", OpLevel.Compare, true))
        t.put(OpCode.BinShl, Op.init("<<", OpLevel.Shift, false))
        t.put(OpCode.BinShr, Op.init(">>", OpLevel.Shift, false))
        t.put(OpCode.BinUShr, Op.init(">>>", OpLevel.Shift, false))
        t.put(OpCode.BinLooseEq, Op.init("==", OpLevel.Equals, false))
        t.put(OpCode.BinLooseNe, Op.init("!=", OpLevel.Equals, false))
        t.put(OpCode.BinStrictEq, Op.init("===", OpLevel.Equals, false))
        t.put(OpCode.BinStrictNe, Op.init("!==", OpLevel.Equals, false))
        t.put(OpCode.BinNullishCoalescing, Op.init("??", OpLevel.NullishCoalescing, false))
        t.put(OpCode.BinLogicalOr, Op.init("||", OpLevel.LogicalOr, false))
        t.put(OpCode.BinLogicalAnd, Op.init("&&", OpLevel.LogicalAnd, false))
        t.put(OpCode.BinBitwiseOr, Op.init("|", OpLevel.BitwiseOr, false))
        t.put(OpCode.BinBitwiseAnd, Op.init("&", OpLevel.BitwiseAnd, false))
        t.put(OpCode.BinBitwiseXor, Op.init("^", OpLevel.BitwiseXor, false))

        // 非结合
        t.put(OpCode.BinComma, Op.init(",", OpLevel.Comma, false))

        // 右结合赋值操作符
        t.put(OpCode.BinAssign, Op.init("=", OpLevel.Assign, false))
        t.put(OpCode.BinAddAssign, Op.init("+=", OpLevel.Assign, false))
        t.put(OpCode.BinSubAssign, Op.init("-=", OpLevel.Assign, false))
        t.put(OpCode.BinMulAssign, Op.init("*=", OpLevel.Assign, false))
        t.put(OpCode.BinDivAssign, Op.init("/=", OpLevel.Assign, false))
        t.put(OpCode.BinRemAssign, Op.init("%=", OpLevel.Assign, false))
        t.put(OpCode.BinPowAssign, Op.init("**=", OpLevel.Assign, false))
        t.put(OpCode.BinShlAssign, Op.init("<<=", OpLevel.Assign, false))
        t.put(OpCode.BinShrAssign, Op.init(">>=", OpLevel.Assign, false))
        t.put(OpCode.BinUShrAssign, Op.init(">>>=", OpLevel.Assign, false))
        t.put(OpCode.BinBitwiseOrAssign, Op.init("|=", OpLevel.Assign, false))
        t.put(OpCode.BinBitwiseAndAssign, Op.init("&=", OpLevel.Assign, false))
        t.put(OpCode.BinBitwiseXorAssign, Op.init("^=", OpLevel.Assign, false))
        t.put(OpCode.BinNullishCoalescingAssign, Op.init("??=", OpLevel.Assign, false))
        t.put(OpCode.BinLogicalOrAssign, Op.init("||=", OpLevel.Assign, false))
        t.put(OpCode.BinLogicalAndAssign, Op.init("&&=", OpLevel.Assign, false))

        return t
    }

    /// 获取操作符信息 - 对应 Bun Op.Table.get(code)
    public static func get(code: OpCode): ?Op {
        return table.get(code)
    }

    /// 获取操作符优先级
    public static func getLevel(code: OpCode): OpLevel {
        match (table.get(code)) {
            case Some(op) => op.level
            case None => OpLevel.Lowest
        }
    }
}
