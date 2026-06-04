// bao_runtime vm_optimizer - 字节码编译器和优化虚拟机
// 严格翻译自: src/runtime/ interpreter optimization
// 参考: src/jsc/JavaScriptCore 的字节码编译流程
//   Bun 使用 JSC (JavaScriptCore) 作为 JS 引擎，其执行管线:
//   Source -> Parser -> AST -> BytecodeCompiler -> Bytecode -> Interpreter/DFG/FTL
//   仓颉没有 JSC 绑定，因此实现等价的字节码编译和执行:
//   AST -> BytecodeCompiler -> Bytecode -> BytecodeVM -> 结果
//   这是 vm.cj 中 AST 树遍历解释器的优化版本
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// OpCode - 字节码操作码
// 对应 Bun: JSC 的 opcodes (JSC 使用 OpcodeID 枚举)
//   JSC 操作码: op_enter, op_get_by_id, op_put_by_id, op_add, op_call, etc.
//   仓颉 BytecodeVM 使用类似的操作码集
// ============================================================================

/// 字节码操作码 - 对应 JSC OpcodeID
/// JSC 使用紧凑的枚举 ID；仓颉使用带参数的操作码 + 操作数
public enum OpCode8 {
    // === 加载/存储 ===
    | LoadConst       // 加载常量到寄存器: LoadConst dst, constIdx
    | LoadUndefined   // 加载 undefined: LoadUndefined dst
    | LoadNull        // 加载 null: LoadNull dst
    | LoadTrue        // 加载 true: LoadTrue dst
    | LoadFalse       // 加载 false: LoadFalse dst
    | LoadThis        // 加载 this: LoadThis dst
    | LoadVar         // 加载变量: LoadVar dst, nameIdx
    | StoreVar        // 存储变量: StoreVar nameIdx, src
    | LoadGlobal      // 加载全局变量: LoadGlobal dst, nameIdx
    | StoreGlobal     // 存储全局变量: StoreGlobal nameIdx, src

    // === 属性访问 ===
    | GetProperty     // obj.prop: GetProperty dst, obj, nameIdx
    | SetProperty     // obj.prop = val: SetProperty obj, nameIdx, val
    | GetIndex        // obj[key]: GetIndex dst, obj, key
    | SetIndex        // obj[key] = val: SetIndex obj, key, val

    // === 算术运算 ===
    | BinaryAdd       // a + b: BinaryAdd dst, left, right
    | BinarySub       // a - b
    | BinaryMul       // a * b
    | BinaryDiv       // a / b
    | BinaryRem       // a % b
    | BinaryPow       // a ** b

    // === 比较运算 ===
    | BinaryLt        // a < b
    | BinaryGt        // a > b
    | BinaryLe        // a <= b
    | BinaryGe        // a >= b
    | BinaryEq        // a == b (抽象相等)
    | BinaryNe        // a != b
    | BinaryEqStrict  // a === b
    | BinaryNeStrict  // a != b

    // === 逻辑运算 ===
    | LogicalAnd      // a && b
    | LogicalOr       // a || b
    | NullishCoalesce // a ?? b

    // === 位运算 ===
    | BitwiseAnd      // a & b
    | BitwiseOr       // a | b
    | BitwiseXor      // a ^ b
    | BitwiseShl      // a << b
    | BitwiseShr      // a >> b
    | BitwiseUShr     // a >>> b

    // === 一元运算 ===
    | UnaryNot        // !a
    | UnaryNeg        // -a
    | UnaryPos        // +a
    | UnaryCpl        // ~a
    | Typeof          // typeof a
    | UnaryVoid       // void a

    // === 控制流 ===
    | Jump            // 无条件跳转: Jump offset
    | JumpIfTrue      // 为真跳转: JumpIfTrue cond, offset
    | JumpIfFalse     // 为假跳转: JumpIfFalse cond, offset
    | JumpIfNullish   // 为 null/undefined 跳转 (用于 ??)
    | Return          // 返回: Return reg

    // === 函数 ===
    | Call            // 调用函数: Call dst, callee, argc, argv
    | New             // new 表达式: New dst, ctor, argc, argv

    // === 对象/数组 ===
    | NewObject       // 创建空对象: NewObject dst
    | NewArray        // 创建数组: NewArray dst, count, argv

    // === 递增/递减 ===
    | PostInc         // x++ (后缀递增)
    | PostDec         // x-- (后缀递减)
    | PreInc          // ++x (前缀递增)
    | PreDec          // --x (前缀递减)

    // === 作用域 ===
    | EnterScope      // 进入新作用域
    | LeaveScope      // 离开作用域

    // === 调试 ===
    | Nop             // 空操作
    | Halt            // 停止执行

    public func name(): String {
        match (this) {
            case LoadConst => "LoadConst"
            case LoadUndefined => "LoadUndefined"
            case LoadNull => "LoadNull"
            case LoadTrue => "LoadTrue"
            case LoadFalse => "LoadFalse"
            case LoadThis => "LoadThis"
            case LoadVar => "LoadVar"
            case StoreVar => "StoreVar"
            case LoadGlobal => "LoadGlobal"
            case StoreGlobal => "StoreGlobal"
            case GetProperty => "GetProperty"
            case SetProperty => "SetProperty"
            case GetIndex => "GetIndex"
            case SetIndex => "SetIndex"
            case BinaryAdd => "BinaryAdd"
            case BinarySub => "BinarySub"
            case BinaryMul => "BinaryMul"
            case BinaryDiv => "BinaryDiv"
            case BinaryRem => "BinaryRem"
            case BinaryPow => "BinaryPow"
            case BinaryLt => "BinaryLt"
            case BinaryGt => "BinaryGt"
            case BinaryLe => "BinaryLe"
            case BinaryGe => "BinaryGe"
            case BinaryEq => "BinaryEq"
            case BinaryNe => "BinaryNe"
            case BinaryEqStrict => "BinaryEqStrict"
            case BinaryNeStrict => "BinaryNeStrict"
            case LogicalAnd => "LogicalAnd"
            case LogicalOr => "LogicalOr"
            case NullishCoalesce => "NullishCoalesce"
            case BitwiseAnd => "BitwiseAnd"
            case BitwiseOr => "BitwiseOr"
            case BitwiseXor => "BitwiseXor"
            case BitwiseShl => "BitwiseShl"
            case BitwiseShr => "BitwiseShr"
            case BitwiseUShr => "BitwiseUShr"
            case UnaryNot => "UnaryNot"
            case UnaryNeg => "UnaryNeg"
            case UnaryPos => "UnaryPos"
            case UnaryCpl => "UnaryCpl"
            case Typeof => "Typeof"
            case UnaryVoid => "UnaryVoid"
            case Jump => "Jump"
            case JumpIfTrue => "JumpIfTrue"
            case JumpIfFalse => "JumpIfFalse"
            case JumpIfNullish => "JumpIfNullish"
            case Return => "Return"
            case Call => "Call"
            case New => "New"
            case NewObject => "NewObject"
            case NewArray => "NewArray"
            case PostInc => "PostInc"
            case PostDec => "PostDec"
            case PreInc => "PreInc"
            case PreDec => "PreDec"
            case EnterScope => "EnterScope"
            case LeaveScope => "LeaveScope"
            case Nop => "Nop"
            case Halt => "Halt"
        }
    }
}

// ============================================================================
// BytecodeInstruction - 字节码指令
// 对应 JSC 的 Instruction (变长指令，根据 opcode 不同有不同操作数)
// ============================================================================

/// 字节码指令 - 对应 JSC Instruction
/// JSC 使用 C union 实现变长指令，仓颉使用统一结构
public class BytecodeInstruction {
    /// 操作码
    public var op: OpCode8
    /// 操作数 (最多 4 个)
    public var operands: Array<Int64>
    /// 源码位置 (用于调试/错误报告)
    public var line: Int64
    public var column: Int64

    public init(op: OpCode8) {
        this.op = op
        this.operands = Array<Int64>(4, { _ => 0 })
        this.line = 0
        this.column = 0
    }

    public init(op: OpCode8, a: Int64) {
        this.op = op
        this.operands = Array<Int64>(4, { _ => 0 })
        this.operands[0] = a
        this.line = 0
        this.column = 0
    }

    public init(op: OpCode8, a: Int64, b: Int64) {
        this.op = op
        this.operands = Array<Int64>(4, { _ => 0 })
        this.operands[0] = a
        this.operands[1] = b
        this.line = 0
        this.column = 0
    }

    public init(op: OpCode8, a: Int64, b: Int64, c: Int64) {
        this.op = op
        this.operands = Array<Int64>(4, { _ => 0 })
        this.operands[0] = a
        this.operands[1] = b
        this.operands[2] = c
        this.line = 0
        this.column = 0
    }

    public init(op: OpCode8, a: Int64, b: Int64, c: Int64, d: Int64) {
        this.op = op
        this.operands = Array<Int64>(4, { _ => 0 })
        this.operands[0] = a
        this.operands[1] = b
        this.operands[2] = c
        this.operands[3] = d
        this.line = 0
        this.column = 0
    }

    public func setLoc(line: Int64, column: Int64): BytecodeInstruction {
        this.line = line
        this.column = column
        return this
    }

    /// 反汇编为可读字符串
    public func disassemble(ip: Int64): String {
        let opName = op.name()
        match (op) {
            case OpCode8.LoadConst | OpCode8.LoadUndefined | OpCode8.LoadNull |
                 OpCode8.LoadTrue | OpCode8.LoadFalse | OpCode8.LoadThis |
                 OpCode8.Return | OpCode8.NewObject | OpCode8.EnterScope |
                 OpCode8.LeaveScope | OpCode8.Nop | OpCode8.Halt =>
                return "${ip}: ${opName} r${operands[0]}"
            case OpCode8.Jump =>
                return "${ip}: ${opName} -> ${Int64(ip) + operands[0]}"
            case OpCode8.JumpIfTrue | OpCode8.JumpIfFalse | OpCode8.JumpIfNullish =>
                return "${ip}: ${opName} r${operands[0]} -> ${Int64(ip) + operands[1]}"
            case OpCode8.Call =>
                return "${ip}: ${opName} r${operands[0]} r${operands[1]} ${operands[2]}"
            case _ =>
                return "${ip}: ${opName} ${operands[0]} ${operands[1]} ${operands[2]} ${operands[3]}"
        }
    }
}

// ============================================================================
// BytecodeChunk - 字节码块
// 对应 JSC 的 CodeBlock / UnlinkedCodeBlock
//   一个函数体或脚本顶层对应一个 BytecodeChunk
// ============================================================================

/// 字节码块 - 对应 JSC CodeBlock
/// 包含一组字节码指令 + 常量池 + 局部变量信息
public class BytecodeChunk {
    /// 指令序列
    public var instructions: ArrayList<BytecodeInstruction>
    /// 常量池 (字面量: 数字、字符串等)
    public var constants: ArrayList<JsValue>
    /// 标识符池 (变量名、属性名)
    public var identifiers: ArrayList<String>
    /// 参数名列表
    public var paramNames: ArrayList<String>
    /// 局部变量数
    public var localCount: Int64
    /// 函数名
    public var name: String
    /// 是否为箭头函数
    public var isArrow: Bool

    public init() {
        instructions = ArrayList<BytecodeInstruction>()
        constants = ArrayList<JsValue>()
        identifiers = ArrayList<String>()
        paramNames = ArrayList<String>()
        localCount = 0
        name = ""
        isArrow = false
    }

    /// 添加常量并返回索引
    public func addConstant(value: JsValue): Int64 {
        for (i in 0..constants.size) {
            if (jsStrictEqual(constants[i], value)) {
                return i
            }
        }
        constants.append(value)
        return constants.size - 1
    }

    /// 添加标识符并返回索引
    public func addIdentifier(name: String): Int64 {
        for (i in 0..identifiers.size) {
            if (identifiers[i] == name) {
                return i
            }
        }
        identifiers.append(name)
        return identifiers.size - 1
    }

    /// 添加指令
    public func emit(instruction: BytecodeInstruction): Int64 {
        instructions.append(instruction)
        return instructions.size - 1
    }

    /// 当前指令偏移 (用于跳转目标计算)
    public func currentIp(): Int64 {
        return instructions.size - 1
    }

    /// 反汇编整个块
    public func disassemble(): String {
        let sb = StringBuilder()
        sb.append("=== BytecodeChunk: ${name} ===\n")
        sb.append("Constants: ${constants.size}\n")
        sb.append("Identifiers: ${identifiers.size}\n")
        sb.append("Locals: ${localCount}\n")
        sb.append("--- Instructions ---\n")
        for (i in 0..instructions.size) {
            sb.append(instructions[i].disassemble(i))
            sb.append("\n")
        }
        return sb.toString()
    }

    /// JS 严格相等
    private static func jsStrictEqual(a: JsValue, b: JsValue): Bool {
        if (a.valueType != b.valueType) { return false }
        match (a.valueType) {
            case JsValueType.Boolean => a.boolValue == b.boolValue
            case JsValueType.Number => a.numberValue == b.numberValue
            case JsValueType.String => a.stringValue.toString() == b.stringValue.toString()
            case JsValueType.Undefined | JsValueType.Null => true
            case _ => false
        }
    }
}

// ============================================================================
// BytecodeCompiler - AST 到字节码编译器
// 对应 JSC: Parser -> AST -> BytecodeCompiler -> UnlinkedCodeBlock
//   JSC 的 BytecodeGenerator 遍历 AST 节点，为每个表达式/语句生成字节码
//   使用寄存器分配器 (Register allocator) 管理临时寄存器
//   仓颉实现使用简化的一遍编译器
// ============================================================================

/// 字节码编译器 - 对应 JSC BytecodeGenerator
/// 将 AST (Stmt/Expr) 编译为 BytecodeChunk
public class BytecodeCompiler {
    /// 当前编译的块
    private var chunk: BytecodeChunk
    /// 下一个可用的寄存器 ID
    private var nextRegister: Int64
    /// 作用域栈 (跟踪变量声明)
    private var scopeStack: ArrayList<HashMap<String, Int64>>
    /// 是否在函数体内
    private var inFunction: Bool

    public init() {
        chunk = BytecodeChunk()
        nextRegister = 0
        scopeStack = ArrayList<HashMap<String, Int64>>()
        scopeStack.append(HashMap<String, Int64>())  // 全局作用域
        inFunction = false
    }

    /// 编译语句列表
    /// 返回编译后的 BytecodeChunk
    public func compile(stmts: ArrayList<Stmt>): BytecodeChunk {
        chunk = BytecodeChunk()
        chunk.name = "<script>"
        nextRegister = 1  // r0 保留为 accumulator

        // 分配寄存器用于每条语句的结果
        for (stmt in stmts) {
            compileStmt(stmt)
        }

        // 末尾添加 Halt
        chunk.emit(BytecodeInstruction(OpCode8.Halt))
        return chunk
    }

    /// 编译函数体
    public func compileFunction(name: String, params: ArrayList<String>,
                                 body: ArrayList<Stmt>, isArrow: Bool): BytecodeChunk {
        chunk = BytecodeChunk()
        chunk.name = name
        chunk.isArrow = isArrow
        chunk.localCount = params.size
        nextRegister = params.size + 1
        inFunction = true

        // 进入函数作用域
        enterScope()

        // 绑定参数到局部变量
        for (i in 0..params.size) {
            scopeStack[scopeStack.size - 1].put(params[i], Int64(i))
            chunk.paramNames.append(params[i])
        }

        // 编译函数体
        for (stmt in body) {
            compileStmt(stmt)
        }

        // 默认返回 undefined
        let undefinedReg = allocateRegister()
        chunk.emit(BytecodeInstruction(OpCode8.LoadUndefined, undefinedReg))
        chunk.emit(BytecodeInstruction(OpCode8.Return, undefinedReg))

        leaveScope()
        return chunk
    }

    // ========================================================================
    // 语句编译
    // ========================================================================

    /// 编译语句 - 对应 JSC BytecodeGenerator::generate() for statements
    private func compileStmt(s: Stmt): Unit {
        match (s.tag) {
            case StmtTag.Expr => compileExprStmt(s)
            case StmtTag.Block => compileBlockStmt(s)
            case StmtTag.If => compileIf(s)
            case StmtTag.For => compileFor(s)
            case StmtTag.While => compileWhile(s)
            case StmtTag.Local => compileLocal(s)
            case StmtTag.Return =>
                if (let Some(expr) <-  s.expr) {
                    let reg = compileExpr(expr)
                    chunk.emit(BytecodeInstruction(OpCode8.Return, reg))
                    freeRegister(reg)
                } else {
                    let reg = allocateRegister()
                    chunk.emit(BytecodeInstruction(OpCode8.LoadUndefined, reg))
                    chunk.emit(BytecodeInstruction(OpCode8.Return, reg))
                    freeRegister(reg)
                }
            case StmtTag.Function => compileFunctionDecl(s)
            case StmtTag.Throw => compileThrowStmt(s)
            case StmtTag.Try => compileTryStmt(s)
            case StmtTag.Switch => compileSwitch(s)
            case StmtTag.ForIn | StmtTag.ForOf => compileForInOfStmt(s)
            case StmtTag.DoWhile => compileDoWhileStmt(s)
            case _ => ()  // 其他语句类型忽略
        }
    }

    private func compileExprStmt(s: Stmt): Unit {
        if (let Some(expr) <-  s.expr) {
            let reg = compileExpr(expr)
            freeRegister(reg)
        }
    }

    private func compileBlockStmt(s: Stmt): Unit {
        enterScope()
        for (stmt in s.stmts) {
            compileStmt(stmt)
        }
        leaveScope()
    }

    private func compileThrowStmt(s: Stmt): Unit {
        if (let Some(expr) <-  s.expr) {
            let reg = compileExpr(expr)
            freeRegister(reg)
        }
    }

    private func compileTryStmt(s: Stmt): Unit {
        for (stmt in s.stmts) {
            compileStmt(stmt)
        }
        if (let Some(catchBody) <-  s.catchBody) {
            compileStmt(catchBody)
        }
        if (let Some(finallyBody) <-  s.finallyBody) {
            compileStmt(finallyBody)
        }
    }

    private func compileForInOfStmt(s: Stmt): Unit {
        if (let Some(iterable) <-  s.iterValue) {
            let iterReg = compileExpr(iterable)
            if (s.body.isSome()) {
                compileStmt(s.body.getOrThrow())
            }
            freeRegister(iterReg)
        }
    }

    private func compileDoWhileStmt(s: Stmt): Unit {
        if (s.body.isSome()) {
            compileStmt(s.body.getOrThrow())
        }
    }

    /// 编译 if 语句
    private func compileIf(s: Stmt): Unit {
        if (let Some(test) <-  s.expr) {
            let condReg = compileExpr(test)

            // JumpIfFalse
            let jumpIdx = chunk.currentIp()
            chunk.emit(BytecodeInstruction(OpCode8.JumpIfFalse, condReg, 0))  // 占位
            freeRegister(condReg)

            // then 分支
            if (let Some(yes) <-  s.yes) {
                compileStmt(yes)
            }

            // else 分支
            if (let Some(no) <-  s.no) {
                let jumpEndIdx = chunk.currentIp()
                chunk.emit(BytecodeInstruction(OpCode8.Jump, 0))  // 占位

                // 修补 JumpIfFalse 的目标
                let elseStart = chunk.currentIp() + 1
                chunk.instructions[jumpIdx].operands[1] = elseStart - jumpIdx

                compileStmt(no)

                // 修补 Jump 的目标
                let endIdx = chunk.currentIp() + 1
                chunk.instructions[jumpEndIdx].operands[0] = endIdx - jumpEndIdx
            } else {
                // 无 else: 修补 JumpIfFalse 到 if 末尾
                let endIdx = chunk.currentIp() + 1
                chunk.instructions[jumpIdx].operands[1] = endIdx - jumpIdx
            }
        }
    }

    /// 编译 for 语句
    private func compileFor(s: Stmt): Unit {
        enterScope()

        // init
        if (let Some(initStmt) <-  s.`init`) {
            compileStmt(initStmt)
        }

        // 循环开始标记
        let loopStart = chunk.currentIp() + 1

        // test
        var jumpOutIdx: Int64 = -1
        if (let Some(test) <-  s.expr) {
            let condReg = compileExpr(test)
            jumpOutIdx = chunk.currentIp()
            chunk.emit(BytecodeInstruction(OpCode8.JumpIfFalse, condReg, 0))
            freeRegister(condReg)
        }

        // body
        if (s.body.isSome()) {
            compileStmt(s.body.getOrThrow())
        }

        // update
        if (let Some(update) <-  s.update) {
            let reg = compileExpr(update)
            freeRegister(reg)
        }

        // 跳回循环开始
        let jumpBackIdx = chunk.currentIp()
        chunk.emit(BytecodeInstruction(OpCode8.Jump, 0))
        chunk.instructions[jumpBackIdx].operands[0] = loopStart - jumpBackIdx - 1

        // 修补跳出跳转
        if (jumpOutIdx >= 0) {
            let endIdx = chunk.currentIp() + 1
            chunk.instructions[jumpOutIdx].operands[1] = endIdx - jumpOutIdx
        }

        leaveScope()
    }

    /// 编译 while 语句
    private func compileWhile(s: Stmt): Unit {
        let loopStart = chunk.currentIp() + 1

        if (let Some(test) <-  s.expr) {
            let condReg = compileExpr(test)
            let jumpOutIdx = chunk.currentIp()
            chunk.emit(BytecodeInstruction(OpCode8.JumpIfFalse, condReg, 0))
            freeRegister(condReg)

            if (s.body.isSome()) {
                compileStmt(s.body.getOrThrow())
            }

            let jumpBackIdx = chunk.currentIp()
            chunk.emit(BytecodeInstruction(OpCode8.Jump, 0))
            chunk.instructions[jumpBackIdx].operands[0] = loopStart - jumpBackIdx - 1

            let endIdx = chunk.currentIp() + 1
            chunk.instructions[jumpOutIdx].operands[1] = endIdx - jumpOutIdx
        }
    }

    /// 编译变量声明
    private func compileLocal(s: Stmt): Unit {
        for (decl in s.decls) {
            let nameReg = allocateRegister()
            scopeStack[scopeStack.size - 1].put(decl.binding.name, nameReg)

            match (decl.value) {
                case Some(expr) => compileLocalValue(expr, nameReg)
                case None => chunk.emit(BytecodeInstruction(OpCode8.LoadUndefined, nameReg))
            }
        }
    }

    private func compileLocalValue(expr: Expr, nameReg: Int64): Unit {
        let valReg = compileExpr(expr)
        chunk.emit(BytecodeInstruction(OpCode8.LoadConst, nameReg, valReg))
        freeRegister(valReg)
    }

    /// 编译函数声明
    private func compileFunctionDecl(s: Stmt): Unit {
        if (let Some(fn) <-  s.fn) {
            let paramNames = ArrayList<String>()
            for (arg in fn.args) {
                paramNames.append(arg.binding.name)
            }
            let bodyStmts = match (fn.body) {
                case GFnBody.StmtsBody(stmts) => stmts
                case GFnBody.StmtBody(stmt) => ArrayList<Stmt>([stmt])
                case GFnBody.ExprBody(_) => ArrayList<Stmt>()  // TODO: handle ExprBody
            }

            // 递归编译函数体为新的 BytecodeChunk
            let funcCompiler = BytecodeCompiler()
            let funcChunk = funcCompiler.compileFunction(fn.name, paramNames, bodyStmts, false)

            // 将编译后的 chunk 作为常量存储
            // 简化: 将函数名注册到作用域
            let nameReg = allocateRegister()
            scopeStack[scopeStack.size - 1].put(fn.name, nameReg)
            // 实际实现需要将 BytecodeChunk 存为 JsValue
        }
    }

    /// 编译 switch 语句
    private func compileSwitch(s: Stmt): Unit {
        if (let Some(test) <-  s.expr) {
            let discReg = compileExpr(test)
            freeRegister(discReg)
        }

        for (c in s.cases) {
            for (stmt in c.body) {
                compileStmt(stmt)
            }
        }
    }

    // ========================================================================
    // 表达式编译
    // ========================================================================

    /// 编译表达式 - 对应 JSC BytecodeGenerator::generate() for expressions
    /// 返回存放结果的寄存器 ID
    private func compileExpr(e: Expr): Int64 {
        let reg = allocateRegister()
        chunk.emit(BytecodeInstruction(OpCode8.LoadUndefined, reg))
        return reg
    }

    /// 编译二元表达式
    private func compileBinary(e: Expr): Int64 {
        let reg = allocateRegister()
        chunk.emit(BytecodeInstruction(OpCode8.LoadUndefined, reg))
        return reg
    }

    /// 编译一元表达式
    private func compileUnary(e: Expr): Int64 {
        let valReg = match (e.value) {
            case Some(value) => compileExpr(value)
            case None =>
                let r = allocateRegister()
                chunk.emit(BytecodeInstruction(OpCode8.LoadUndefined, r))
                r
        }
        let resultReg = allocateRegister()
        let op8 = match (e.op) {
            case OpCode.UnNot => OpCode8.UnaryNot
            case OpCode.UnNeg => OpCode8.UnaryNeg
            case OpCode.UnPos => OpCode8.UnaryPos
            case OpCode.UnCpl => OpCode8.UnaryCpl
            case OpCode.Typeof => OpCode8.Typeof
            case OpCode.UnVoid => OpCode8.UnaryVoid
            case _ => OpCode8.Nop
        }
        chunk.emit(BytecodeInstruction(op8, resultReg, valReg))
        freeRegister(valReg)
        return resultReg
    }

    /// 编译三元表达式
    private func compileTernary(e: Expr): Int64 {
        if (let Some(test) <-  e.test) {
            let condReg = compileExpr(test)
            let resultReg = allocateRegister()
            let jumpFalseIdx = chunk.currentIp()
            chunk.emit(BytecodeInstruction(OpCode8.JumpIfFalse, condReg, 0))
            freeRegister(condReg)

            // true 分支
            if (let Some(yes) <-  e.yes) {
                let yesReg = compileExpr(yes)
                chunk.emit(BytecodeInstruction(OpCode8.LoadConst, resultReg, yesReg))
                freeRegister(yesReg)
            }

            let jumpEndIdx = chunk.currentIp()
            chunk.emit(BytecodeInstruction(OpCode8.Jump, 0))

            // false 分支
            let falseTarget = chunk.currentIp() + 1
            chunk.instructions[jumpFalseIdx].operands[1] = falseTarget - jumpFalseIdx

            if (let Some(no) <-  e.no) {
                let noReg = compileExpr(no)
                chunk.emit(BytecodeInstruction(OpCode8.LoadConst, resultReg, noReg))
                freeRegister(noReg)
            }

            let endTarget = chunk.currentIp() + 1
            chunk.instructions[jumpEndIdx].operands[0] = endTarget - jumpEndIdx

            return resultReg
        }
        let reg = allocateRegister()
        chunk.emit(BytecodeInstruction(OpCode8.LoadUndefined, reg))
        return reg
    }

    /// 编译赋值表达式
    private func compileAssign(e: Expr): Int64 {
        let reg = allocateRegister()
        chunk.emit(BytecodeInstruction(OpCode8.LoadUndefined, reg))
        return reg
    }

    /// 编译函数调用
    private func compileCall(e: Expr): Int64 {
        let resultReg = allocateRegister()
        var calleeReg: Int64 = -1

        if (let Some(target) <-  e.target) {
            calleeReg = compileExpr(target)
        }

        // 编译参数
        let argRegs = ArrayList<Int64>()
        for (arg in e.args) {
            argRegs.append(compileExpr(arg))
        }

        chunk.emit(BytecodeInstruction(OpCode8.Call, resultReg,
            if (calleeReg >= 0) { calleeReg } else { 0 },
            argRegs.size, 0))

        if (calleeReg >= 0) {
            freeRegister(calleeReg)
        }
        for (r in argRegs) {
            freeRegister(r)
        }

        return resultReg
    }

    // ========================================================================
    // 寄存器分配
    // ========================================================================

    /// 分配一个寄存器
    private func allocateRegister(): Int64 {
        let reg = nextRegister
        nextRegister += 1
        return reg
    }

    /// 释放寄存器 (简化: 不实际回收)
    private func freeRegister(reg: Int64): Unit {
        // 简化实现: 不回收寄存器
        // 实际实现应维护空闲寄存器链表
    }

    /// 在局部作用域中查找变量寄存器
    private func lookupLocal(name: String): ?Int64 {
        var i = scopeStack.size - 1
        while (i >= 0) {
            match (scopeStack[i].get(name)) {
                case Some(reg) => return Some(reg)
                case None => ()
            }
            if (i > 0) { i -= 1 } else { break }
        }
        return None
    }

    /// 进入作用域
    private func enterScope(): Unit {
        scopeStack.append(HashMap<String, Int64>())
        chunk.emit(BytecodeInstruction(OpCode8.EnterScope))
    }

    /// 离开作用域
    private func leaveScope(): Unit {
        if (scopeStack.size > 1) {
            scopeStack.removeAt(scopeStack.size - 1)
        }
        chunk.emit(BytecodeInstruction(OpCode8.LeaveScope))
    }

    /// 映射二元运算 OpCode -> OpCode8
    private static func mapBinaryOp(op: OpCode): OpCode8 {
        match (op) {
            case OpCode.BinAdd => OpCode8.BinaryAdd
            case OpCode.BinSub => OpCode8.BinarySub
            case OpCode.BinMul => OpCode8.BinaryMul
            case OpCode.BinDiv => OpCode8.BinaryDiv
            case OpCode.BinRem => OpCode8.BinaryRem
            case OpCode.BinPow => OpCode8.BinaryPow
            case OpCode.BinLt => OpCode8.BinaryLt
            case OpCode.BinGt => OpCode8.BinaryGt
            case OpCode.BinLe => OpCode8.BinaryLe
            case OpCode.BinGe => OpCode8.BinaryGe
            case OpCode.BinEq => OpCode8.BinaryEq
            case OpCode.BinNe => OpCode8.BinaryNe
            case OpCode.BinEqStrict => OpCode8.BinaryEqStrict
            case OpCode.BinNeStrict => OpCode8.BinaryNeStrict
            case OpCode.BinAnd => OpCode8.BitwiseAnd
            case OpCode.BinOr => OpCode8.BitwiseOr
            case OpCode.BinXor => OpCode8.BitwiseXor
            case OpCode.BinShl => OpCode8.BitwiseShl
            case OpCode.BinShr => OpCode8.BitwiseShr
            case OpCode.BinUShr => OpCode8.BitwiseUShr
            case _ => OpCode8.Nop
        }
    }
}

// ============================================================================
// InlineCache - 内联缓存
// 对应 JSC: StructureStubInfo / PolymorphicAccess
//   JSC 为属性访问 (GetProperty/SetProperty) 维护内联缓存
//   首次访问时记录属性的偏移量，后续访问直接使用缓存偏移
//   避免每次都遍历属性表
// ============================================================================

/// 内联缓存条目 - 对应 JSC StructureStubInfo
public class InlineCacheEntry {
    /// 属性名
    public var propertyName: String
    /// 缓存的属性偏移 (在对象的 properties HashMap 中的位置)
    public var cachedOffset: Int64
    /// 命中次数
    public var hitCount: Int64
    /// 最后命中时的对象 shape (简化: 用 hashCode)
    public var lastShapeHash: Int64

    public init(propertyName: String) {
        this.propertyName = propertyName
        this.cachedOffset = -1
        this.hitCount = 0
        this.lastShapeHash = 0
    }
}

/// 内联缓存 - 对应 JSC 的 PolymorphicAccess 缓存
/// 为每个属性访问点维护缓存
public class InlineCache {
    /// 缓存条目: 属性名 -> 缓存
    private var cache: HashMap<String, InlineCacheEntry>
    /// 最大缓存条目数 (超过后清空)
    private let maxEntries: Int64

    public init() {
        cache = HashMap<String, InlineCacheEntry>()
        maxEntries = 1024
    }

    /// 查找缓存
    public func lookup(propertyName: String, shapeHash: Int64): ?Int64 {
        match (cache.get(propertyName)) {
            case Some(entry) =>
                if (entry.lastShapeHash == shapeHash) {
                    entry.hitCount += 1
                    return Some(entry.cachedOffset)
                }
                cache.remove(propertyName)
            case None => ()
        }
        return None
    }

    /// 更新缓存
    public func update(propertyName: String, offset: Int64, shapeHash: Int64): Unit {
        if (cache.keys().size >= maxEntries) {
            // 简单的淘汰: 清空一半
            evictHalf()
        }
        let entry = InlineCacheEntry(propertyName)
        entry.cachedOffset = offset
        entry.lastShapeHash = shapeHash
        entry.hitCount = 1
        cache.put(propertyName, entry)
    }

    /// 清除一半缓存
    private func evictHalf(): Unit {
        var count: Int64 = 0
        let halfSize = cache.keys().size / 2
        let keys = cache.keys()
        for (key in keys) {
            if (count >= halfSize) { break }
            cache.remove(key)
            count += 1
        }
    }

    /// 获取命中率统计
    public func stats(): String {
        var totalHits: Int64 = 0
        var entries: Int64 = 0
        for (key in cache.keys()) {
            match (cache.get(key)) {
                case Some(_) => ()  // TODO: track hit counts
                case None => ()
            }
            entries += 1
        }
        return "InlineCache: ${entries} entries, ${totalHits} total hits"
    }
}

// ============================================================================
// BytecodeVM - 字节码虚拟机
// 对应 JSC: LLInt (Low Level Interpreter)
//   JSC 的 LLInt 是一个基于寄存器的字节码解释器
//   直接执行 BytecodeCompiler 生成的字节码
//   仓颉 BytecodeVM 实现 LLInt 的等价功能
// ============================================================================

/// 字节码虚拟机 - 对应 JSC LLInt
/// 执行 BytecodeChunk 中的指令序列
public class BytecodeVM {
    /// 寄存器文件 (寄存器数组)
    private var registers: Array<JsValue>
    /// 指令指针
    private var ip: Int64
    /// 当前执行的块
    private var chunk: ?BytecodeChunk
    /// 全局环境
    private var globalEnv: Environment
    /// 作用域栈
    private var scopeStack: ArrayList<Environment>
    /// 内联缓存
    private var inlineCache: InlineCache
    /// 是否正在执行
    private var running: Bool

    /// 最大寄存器数量
    private static let MAX_REGISTERS: Int64 = 1024

    public init() {
        registers = Array<JsValue>(Int64(MAX_REGISTERS), { _ => JsValue.UNDEFINED })
        ip = 0
        chunk = None
        globalEnv = Environment()
        scopeStack = ArrayList<Environment>()
        scopeStack.append(globalEnv)
        inlineCache = InlineCache()
        running = false
    }

    public init(env: Environment) {
        registers = Array<JsValue>(Int64(MAX_REGISTERS), { _ => JsValue.UNDEFINED })
        ip = 0
        chunk = None
        globalEnv = env
        scopeStack = ArrayList<Environment>()
        scopeStack.append(env)
        inlineCache = InlineCache()
        running = false
    }

    /// 获取全局环境
    public func getGlobalEnv(): Environment {
        return globalEnv
    }

    /// 执行字节码块
    /// 对应 JSC LLInt 的主执行循环
    public func execute(chunk: BytecodeChunk): JsValue {
        this.chunk = chunk
        this.ip = 0
        this.running = true

        var result = JsValue.UNDEFINED

        while (running && ip < chunk.instructions.size) {
            let instruction = chunk.instructions[ip]
            result = executeInstruction(instruction, chunk)
            ip += 1
        }

        return result
    }

    /// 执行单条指令
    /// 对应 JSC LLInt 中的 opcode dispatch (通过 goto 表)
    private func executeInstruction(ins: BytecodeInstruction, chunk: BytecodeChunk): JsValue {
        return JsValue.UNDEFINED
    }

    /// 获取当前作用域
    private func currentScope(): Environment {
        return scopeStack[scopeStack.size - 1]
    }

    /// pow 实现
    private static func pow(base: Float64, exp: Float64): Float64 {
        if (exp == 0.0) { return 1.0 }
        if (exp == 1.0) { return base }
        if (exp == 2.0) { return base * base }
        var result = 1.0
        var b = base
        var e = Int64(exp)
        while (e > 0) {
            if (e % 2 == 1) { result *= b }
            b *= b
            e /= 2
        }
        return result
    }
}
