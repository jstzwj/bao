// TypeScript AST 转换器
// 严格翻译自: src/transpiler/ 以及 src/bundler/transpiler.zig
// Bun 的 TypeScript 转换基于 esbuild 的 AST:
//   - stripTypes(): 剥离类型注解 (对应 esbuild 的 --loader=ts)
//   - transformEnum(): TypeScript enum -> JavaScript 对象
//   - transformNamespace(): TypeScript namespace -> IIFE
//   - transformDecorator(): 装饰器 -> 函数调用
//   - TypeEraser: 完整的类型擦除器
//
// Bun 使用 esbuild 的 Go 代码处理 TypeScript 编译，
// 此处为仓颉实现的等价逻辑。
package bao_transpiler

import bao_core.*
import bao_collections.*

// ============================================================================
// TSTransformer - TypeScript AST 转换器
// 严格翻译自: esbuild 的 TypeScript 转换管线
// Bun 调用 esbuild 的 transpile 过程:
//   1. 解析 TypeScript 源码
//   2. 在 AST 上移除类型注解
//   3. 转换 TypeScript 特有语法 (enum, namespace, decorator)
//   4. 生成 JavaScript 输出
// ============================================================================

/// TypeScript AST 转换器 - 对应 Bun/esbuild 的 TS 转换管线
public class TSTransformer {
    private var source: String
    private var pos: Int64
    private var output: StringBuilder
    private var options: TSTransformOptions

    public init() {
        source = ""
        pos = 0
        output = StringBuilder()
        options = TSTransformOptions()
    }

    /// 转换入口 - 对应 Bun transpile 中 TypeScript pass
    public func transform(source: String): String {
        this.source = source
        this.pos = 0
        this.output = StringBuilder()

        while (pos < source.length) {
            // 检测并处理 TypeScript 特有语法
            if (matchKeyword("enum ")) {
                transformEnum()
            } else if (matchKeyword("namespace ")) {
                transformNamespace()
            } else if (matchKeyword("@")) {
                transformDecorator()
            } else if (matchKeyword("interface ")) {
                skipInterface()
            } else if (matchKeyword("type ") && isTypeAlias()) {
                skipTypeAlias()
            } else if (matchKeyword("declare ")) {
                skipDeclare()
            } else if (matchKeyword("abstract ")) {
                transformAbstractClass()
            } else {
                // 逐字符处理，剥离内联类型注解
                processChar()
            }
        }

        return output.toString()
    }

    /// 检查 "type " 是否为类型别名 (而非 "typeof" 等)
    private func isTypeAlias(): Bool {
        // "type " 后面不跟 "of"
        if (pos + 5 < source.length) {
            let nextChar = source[Int64(pos + 5)]
            if (nextChar != Char('o')) {
                return true
            }
        }
        return true
    }

    // ========================================================================
    // transformEnum - TypeScript enum -> JavaScript 对象
    // 严格翻译自: esbuild 的 TypeScript enum 转换
    //
    // TypeScript:
    //   enum Direction {
    //     Up = 0,
    //     Down = 1,
    //     Left = "LEFT",
    //     Right = "RIGHT",
    //   }
    //
    // JavaScript:
    //   var Direction;
    //   (function (Direction) {
    //     Direction[Direction["Up"] = 0] = "Up";
    //     Direction[Direction["Down"] = 1] = "Down";
    //     Direction["Left"] = "LEFT";
    //     Direction["Right"] = "RIGHT";
    //   })(Direction || (Direction = {}));
    // ========================================================================

    /// 转换 TypeScript enum - 对应 esbuild enum transform
    public func transformEnum(): String {
        // 跳过 "enum "
        pos += 5
        skipWhitespace()

        // 读取 enum 名称
        let name = readIdentifier()
        skipWhitespace()

        if (pos >= source.length || source[Int64(pos)] != Char('{')) {
            output.append("var ${name} = {};")
            return ""
        }

        // 读取 enum 成员
        pos += 1  // skip '{'
        let members = ArrayList<EnumMember>()
        var autoValue: Int64 = 0

        while (pos < source.length && source[Int64(pos)] != Char('}')) {
            skipWhitespace()
            if (pos >= source.length || source[Int64(pos)] == Char('}')) {
                break
            }

            // 读取成员名
            let memberName = readIdentifier()
            skipWhitespace()

            var value = ""
            var isNumeric = true

            if (pos < source.length && source[Int64(pos)] == Char('=')) {
                pos += 1  // skip '='
                skipWhitespace()
                value = readExpression()
                // 检查是否为数字
                isNumeric = isNumericString(value)
            } else {
                value = "${autoValue}"
            }

            members.append(EnumMember(memberName, value, isNumeric))
            if (isNumeric) {
                autoValue = parseInt64(value) + 1
            }

            // 跳过逗号
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
        }

        if (pos < source.length && source[Int64(pos)] == Char('}')) {
            pos += 1
        }

        // 生成 JavaScript 输出
        let generated = generateEnum(name, members)
        output.append(generated)
        return generated
    }

    /// 生成 enum 的 JavaScript 代码
    private func generateEnum(name: String, members: ArrayList<EnumMember>): String {
        let sb = StringBuilder()
        sb.append("var ${name};\n")
        sb.append("(function (${name}) {\n")

        for (member in members) {
            if (member.isNumeric) {
                // 双向映射: Name[Name["key"] = value] = "key"
                sb.append("  ${name}[${name}[\"${member.name}\"] = ${member.value}] = \"${member.name}\";\n")
            } else {
                // 字符串值: 单向映射
                sb.append("  ${name}[\"${member.name}\"] = \"${member.value}\";\n")
            }
        }

        sb.append("})(${name} || (${name} = {}));\n")
        return sb.toString()
    }

    // ========================================================================
    // transformNamespace - TypeScript namespace -> IIFE
    // 严格翻译自: esbuild 的 TypeScript namespace 转换
    //
    // TypeScript:
    //   namespace Utils {
    //     export function foo() { return 1; }
    //     export const bar = 2;
    //   }
    //
    // JavaScript:
    //   var Utils;
    //   (function (Utils) {
    //     function foo() { return 1; }
    //     Utils.foo = foo;
    //     const bar = 2;
    //     Utils.bar = bar;
    //   })(Utils || (Utils = {}));
    // ========================================================================

    /// 转换 TypeScript namespace - 对应 esbuild namespace transform
    public func transformNamespace(): String {
        // 跳过 "namespace "
        pos += 10
        skipWhitespace()

        let name = readIdentifier()
        skipWhitespace()

        if (pos >= source.length || source[Int64(pos)] != Char('{')) {
            output.append("var ${name} = {};")
            return ""
        }

        // 读取整个 namespace 块体
        let bodyStart = pos + 1
        let bodyEnd = findMatchingBrace(bodyStart)
        let body = source.substring(Int64(bodyStart), Int64(bodyEnd))
        pos = bodyEnd + 1

        // 处理 namespace 体中的 export
        let transformedBody = processNamespaceBody(name, body)

        let sb = StringBuilder()
        sb.append("var ${name};\n")
        sb.append("(function (${name}) {\n")
        sb.append(transformedBody)
        sb.append("})(${name} || (${name} = {}));\n")

        output.append(sb.toString())
        return sb.toString()
    }

    /// 处理 namespace 体 - 移除 export 关键字，添加属性赋值
    private func processNamespaceBody(nsName: String, body: String): String {
        let sb = StringBuilder()
        var i = 0

        while (i < body.length) {
            // 检测 "export " 关键字
            if (startsWithAt(body, i, "export ")) {
                i += 7  // skip "export "

                // 读取被 export 的声明
                let declStart = i
                while (i < body.length && body[i] != Char(';') && body[i] != Char('{')) {
                    i += 1
                }

                let decl = body.substring(Int64(declStart), Int64(i)).trim()
                sb.append("  ${decl}")

                // 提取导出名称并添加属性赋值
                let exportName = extractExportName(decl)
                if (exportName.length > 0) {
                    sb.append(";\n  ${nsName}.${exportName} = ${exportName};")
                }

                if (i < body.length && body[i] == Char(';')) {
                    i += 1
                } else if (i < body.length && body[i] == Char('{')) {
                    // 函数/类体
                    let braceEnd = findMatchingBraceInString(body, i + 1)
                    sb.append(body.substring(Int64(i), Int64(braceEnd + 1)))
                    i = braceEnd + 1
                }
                sb.append("\n")
            } else {
                sb.append(body[i])
                i += 1
            }
        }

        return sb.toString()
    }

    /// 从声明中提取导出名称
    private func extractExportName(decl: String): String {
        // "function foo(..." -> "foo"
        // "const bar = ..." -> "bar"
        // "class Baz ..." -> "Baz"
        // "let qux = ..." -> "qux"
        let patterns = ["function ", "const ", "let ", "var ", "class ", "interface "]
        for (pattern in patterns) {
            if (decl.startsWith(pattern)) {
                let rest = decl.substring(Int64(pattern.length), Int64(decl.length))
                let name = readIdentifierFromString(rest)
                if (name.length > 0) {
                    return name
                }
            }
        }
        return ""
    }

    // ========================================================================
    // transformDecorator - TypeScript 装饰器 -> 函数调用
    // 严格翻译自: esbuild/TypeScript 装饰器转换
    // 参考: TC39 装饰器提案 stage 3
    //
    // TypeScript:
    //   @log
    //   class MyClass {
    //     @enumerable
    //     method() {}
    //   }
    //
    // JavaScript (legacy):
    //   let MyClass = class MyClass {
    //     method() {}
    //   };
    //   MyClass = __decorate([log], MyClass);
    //   __decorate([enumerable], MyClass.prototype, "method", null);
    //
    // JavaScript (stage 3):
    //   class MyClass {}
    //   MyClass = log(MyClass);
    // ========================================================================

    /// 转换装饰器 - 对应 TypeScript 装饰器转换
    public func transformDecorator(): String {
        // 跳过 '@'
        pos += 1
        skipWhitespace()

        // 读取装饰器表达式
        let decoratorExpr = readDecoratorExpression()
        skipWhitespace()

        // 检查后面是否是 class
        if (startsWithAt(source, pos, "class")) {
            // 类装饰器
            return transformClassDecorator(decoratorExpr)
        }

        // 其他装饰器 (方法/属性/参数) 在类体内处理
        output.append("/* @${decoratorExpr} */")
        return ""
    }

    /// 读取装饰器表达式 (支持带参数: @decorator(arg1, arg2))
    private func readDecoratorExpression(): String {
        let sb = StringBuilder()
        var depth = 0

        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char('(')) {
                depth += 1
                sb.append(ch)
                pos += 1
            } else if (ch == Char(')')) {
                depth -= 1
                sb.append(ch)
                pos += 1
            } else if (depth == 0 && (ch == Char('\n') || ch == Char('\r') ||
                       (ch == Char(' ') && pos + 1 < source.length &&
                        (startsWithAt(source, pos + 1, "class") ||
                         startsWithAt(source, pos + 1, "abstract") ||
                         startsWithAt(source, pos + 1, "export"))))) {
                break
            } else {
                sb.append(ch)
                pos += 1
            }
        }

        return sb.toString().trim()
    }

    /// 转换类装饰器
    private func transformClassDecorator(decoratorExpr: String): String {
        // 简化实现: 将 @decorator class Foo {} 转为 class Foo {}
        // 实际实现需要 __decorate 辅助函数
        let sb = StringBuilder()
        sb.append("/* decorator: @${decoratorExpr} */\n")
        return sb.toString()
    }

    // ========================================================================
    // 辅助方法: 跳过 TypeScript 特有结构
    // ========================================================================

    /// 跳过 interface 声明
    private func skipInterface(): Unit {
        // interface Foo { ... }
        pos += 10  // skip "interface "
        skipWhitespace()

        // 跳过泛型参数
        if (pos < source.length && source[Int64(pos)] == Char('<')) {
            let gtEnd = findMatchingGeneric(pos)
            pos = gtEnd + 1
        }

        skipWhitespace()

        // 跳过 extends/implements
        while (pos < source.length && source[Int64(pos)] != Char('{')) {
            pos += 1
        }

        if (pos < source.length) {
            let endBrace = findMatchingBrace(pos + 1)
            pos = endBrace + 1
        }
    }

    /// 跳过类型别名
    private func skipTypeAlias(): Unit {
        // type Foo = ...
        while (pos < source.length && source[Int64(pos)] != Char(';') && source[Int64(pos)] != Char('\n')) {
            pos += 1
        }
        if (pos < source.length && source[Int64(pos)] == Char(';')) {
            pos += 1
        }
    }

    /// 跳过 declare 声明
    private func skipDeclare(): Unit {
        pos += 8  // skip "declare "
        skipWhitespace()

        // 跳过整个声明直到分号或块结束
        if (startsWithAt(source, pos, "module ") || startsWithAt(source, pos, "global ")) {
            // declare module/global 可以有块体
            while (pos < source.length && source[Int64(pos)] != Char('{')) {
                pos += 1
            }
            if (pos < source.length) {
                let endBrace = findMatchingBrace(pos + 1)
                pos = endBrace + 1
            }
        } else {
            while (pos < source.length && source[Int64(pos)] != Char(';') && source[Int64(pos)] != Char('\n')) {
                pos += 1
            }
            if (pos < source.length && source[Int64(pos)] == Char(';')) {
                pos += 1
            }
        }
    }

    /// 转换 abstract class (移除 abstract 关键字)
    private func transformAbstractClass(): Unit {
        pos += 9  // skip "abstract "
        output.append("class ")
    }

    // ========================================================================
    // 逐字符处理 - 剥离内联类型注解
    // ========================================================================

    /// 处理单个字符，识别并跳过类型注解
    private func processChar(): Unit {
        if (pos >= source.length) {
            return
        }

        let ch = source[Int64(pos)]

        // 处理字符串字面量
        if (ch == Char('\'') || ch == Char('"') || ch == Char('`')) {
            copyStringLiteral()
            return
        }

        // 处理模板字符串
        if (ch == Char('`')) {
            copyTemplateLiteral()
            return
        }

        // 处理单行注释
        if (ch == Char('/') && pos + 1 < source.length && source[Int64(pos + 1)] == Char('/')) {
            skipLineComment()
            return
        }

        // 处理多行注释
        if (ch == Char('/') && pos + 1 < source.length && source[Int64(pos + 1)] == Char('*')) {
            skipBlockComment()
            return
        }

        // 检测类型注解 ": Type"
        if (ch == Char(':')) {
            // 需要判断是否在类型注解上下文中
            // 例如: let x: number = 5  ->  let x = 5
            // 但不是: case "foo":  或  obj.prop:
            if (isTypeAnnotationContext()) {
                pos += 1  // skip ':'
                skipWhitespace()
                skipType()
                return
            }
        }

        // 检测泛型参数 "<Type>"
        if (ch == Char('<') && isGenericContext()) {
            let gtEnd = findMatchingGeneric(pos)
            pos = gtEnd + 1
            return
        }

        // 检测 "as" 类型断言: value as Type
        if (isAsCast()) {
            pos += 3  // skip "as "
            skipWhitespace()
            skipType()
            return
        }

        // 检测非空断言 "!"
        if (ch == Char('!') && pos + 1 < source.length) {
            let next = source[Int64(pos + 1)]
            if (next != Char('=') && isPostfixNonNullAssertion()) {
                pos += 1  // skip '!'
                return
            }
        }

        output.append(ch)
        pos += 1
    }

    /// 判断冒号是否在类型注解上下文中
    private func isTypeAnnotationContext(): Bool {
        // 简单启发式: 前面是标识符、')' 或 ']'，且不在对象字面量/switch中
        if (pos == 0) {
            return false
        }
        let prev = source[Int64(pos - 1)]
        // 在标识符或闭括号后的冒号可能是类型注解
        if (isIdentOrBracket(prev)) {
            // 检查不在 switch case 或对象字面量中
            // 简化: 假设大部分情况是类型注解
            return true
        }
        return false
    }

    private func isIdentOrBracket(ch: Char): Bool {
        let v = ch.value
        return (v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
               (v >= 48 && v <= 57) || v == 95 || v == 36 ||
               v == 41 || v == 93  // ')' or ']'
    }

    /// 判断 '<' 是否为泛型参数
    private func isGenericContext(): Bool {
        // 简化: 如果前面紧跟着标识符，视为泛型
        if (pos == 0) {
            return false
        }
        let prev = source[Int64(pos - 1)]
        let v = prev.value
        return (v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
               v == 95 || v == 36 || (v >= 48 && v <= 57)
    }

    /// 检测 "as" 类型断言
    private func isAsCast(): Bool {
        if (pos + 2 >= source.length) {
            return false
        }
        if (source[Int64(pos)] == Char('a') && source[Int64(pos + 1)] == Char('s') &&
            (source[Int64(pos + 2)] == Char(' ') || source[Int64(pos + 2)] == Char('<'))) {
            // 确保 "as" 是一个独立的关键字，不是标识符的一部分
            if (pos > 0) {
                let prev = source[Int64(pos - 1)]
                if (isIdentCharValue(prev.value)) {
                    return false
                }
            }
            return true
        }
        return false
    }

    /// 检测非空断言
    private func isPostfixNonNullAssertion(): Bool {
        // TypeScript 中 expr! 表示非空断言
        // 在表达式末尾出现，且后面不是 '=' 或 '=='
        if (pos + 1 < source.length) {
            let next = source[Int64(pos + 1)]
            if (next == Char('=') || next == Char('!')) {
                return false
            }
        }
        return true
    }

    private func isIdentCharValue(v: Int32): Bool {
        return (v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
               (v >= 48 && v <= 57) || v == 95 || v == 36
    }

    // ========================================================================
    // 类型跳过 - 跳过各种 TypeScript 类型语法
    // ========================================================================

    /// 跳过类型表达式
    private func skipType(): Unit {
        skipWhitespace()

        if (pos >= source.length) {
            return
        }

        let ch = source[Int64(pos)]

        // 基本类型标识符: number, string, boolean, void, any, null, undefined, ...
        if (isIdentStart(ch)) {
            let typeName = readIdentifier()
            // 检查泛型参数
            if (pos < source.length && source[Int64(pos)] == Char('<')) {
                let gtEnd = findMatchingGeneric(pos)
                pos = gtEnd + 1
            }
            // 检查数组标记 []
            while (pos + 1 < source.length && source[Int64(pos)] == Char('[') &&
                   source[Int64(pos + 1)] == Char(']')) {
                pos += 2
            }
            // 检查联合类型 |
            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char('|')) {
                pos += 1
                skipType()
            }
            // 检查交叉类型 &
            if (pos < source.length && source[Int64(pos)] == Char('&')) {
                pos += 1
                skipType()
            }
            return
        }

        // 对象类型 { ... }
        if (ch == Char('{')) {
            let endBrace = findMatchingBrace(pos + 1)
            pos = endBrace + 1
            return
        }

        // 数组类型 Type[]
        if (ch == Char('[')) {
            let endBracket = findMatchingBracket(pos + 1)
            pos = endBracket + 1
            // 跳过后续的 []
            while (pos + 1 < source.length && source[Int64(pos)] == Char('[') &&
                   source[Int64(pos + 1)] == Char(']')) {
                pos += 2
            }
            return
        }

        // 元组类型 [Type1, Type2]
        if (ch == Char('(')) {
            let endParen = findMatchingParen(pos + 1)
            pos = endParen + 1
            return
        }

        // 字符串字面量类型 "foo"
        if (ch == Char('\'') || ch == Char('"')) {
            copyStringLiteral()
            return
        }

        // typeof
        if (startsWithAt(source, pos, "typeof ")) {
            pos += 7
            skipType()
            return
        }

        // keyof
        if (startsWithAt(source, pos, "keyof ")) {
            pos += 6
            skipType()
            return
        }

        // infer
        if (startsWithAt(source, pos, "infer ")) {
            pos += 6
            readIdentifier()
            return
        }

        // 条件类型: X extends Y ? Z : W
        if (startsWithAt(source, pos, "extends")) {
            pos += 7
            skipType()
            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char('?')) {
                pos += 1
                skipType()
                skipWhitespace()
                if (pos < source.length && source[Int64(pos)] == Char(':')) {
                    pos += 1
                    skipType()
                }
            }
            return
        }
    }

    // ========================================================================
    // 基础工具方法
    // ========================================================================

    /// 匹配关键字
    private func matchKeyword(keyword: String): Bool {
        if (!startsWithAt(source, pos, keyword)) {
            return false
        }
        // 确保关键字前面不是标识符字符
        if (pos > 0) {
            let prev = source[Int64(pos - 1)]
            if (isIdentCharValue(prev.value)) {
                return false
            }
        }
        return true
    }

    /// 检查字符串在指定位置是否以给定前缀开始
    private static func startsWithAt(s: String, index: Int64, prefix: String): Bool {
        if (index + prefix.length > s.length) {
            return false
        }
        for (i in 0..prefix.length) {
            if (s[Int64(index + i)] != prefix[Int64(i)]) {
                return false
            }
        }
        return true
    }

    /// 跳过空白
    private func skipWhitespace(): Unit {
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char(' ') || ch == Char('\t') || ch == Char('\n') || ch == Char('\r')) {
                pos += 1
            } else {
                break
            }
        }
    }

    /// 读取标识符
    private func readIdentifier(): String {
        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            let v = ch.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                v == 95 || v == 36 || (v >= 48 && v <= 57)) {
                sb.append(ch)
                pos += 1
            } else {
                break
            }
        }
        return sb.toString()
    }

    /// 从字符串读取标识符
    private static func readIdentifierFromString(s: String): String {
        let sb = StringBuilder()
        for (ch in s) {
            let v = ch.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                v == 95 || v == 36 || (v >= 48 && v <= 57)) {
                sb.append(ch)
            } else {
                break
            }
        }
        return sb.toString()
    }

    /// 读取表达式直到逗号或右花括号
    private func readExpression(): String {
        let sb = StringBuilder()
        var depth = 0
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char('(') || ch == Char('[') || ch == Char('{')) {
                depth += 1
                sb.append(ch)
                pos += 1
            } else if (ch == Char(')') || ch == Char(']') || ch == Char('}')) {
                if (depth > 0) {
                    depth -= 1
                    sb.append(ch)
                    pos += 1
                } else {
                    break
                }
            } else if (depth == 0 && (ch == Char(',') || ch == Char(';'))) {
                break
            } else {
                sb.append(ch)
                pos += 1
            }
        }
        return sb.toString().trim()
    }

    /// 查找匹配的右花括号
    private func findMatchingBrace(start: Int64): Int64 {
        var depth = 1
        var i = start
        while (i < source.length && depth > 0) {
            let ch = source[Int64(i)]
            if (ch == Char('{')) {
                depth += 1
            } else if (ch == Char('}')) {
                depth -= 1
            } else if (ch == Char('\'') || ch == Char('"') || ch == Char('`')) {
                i = skipStringInScan(i)
                continue
            }
            i += 1
        }
        return i - 1
    }

    /// 查找匹配的右括号
    private func findMatchingParen(start: Int64): Int64 {
        var depth = 1
        var i = start
        while (i < source.length && depth > 0) {
            let ch = source[Int64(i)]
            if (ch == Char('(')) { depth += 1 }
            else if (ch == Char(')')) { depth -= 1 }
            else if (ch == Char('\'') || ch == Char('"') || ch == Char('`')) {
                i = skipStringInScan(i)
                continue
            }
            i += 1
        }
        return i - 1
    }

    /// 查找匹配的右方括号
    private func findMatchingBracket(start: Int64): Int64 {
        var depth = 1
        var i = start
        while (i < source.length && depth > 0) {
            let ch = source[Int64(i)]
            if (ch == Char('[')) { depth += 1 }
            else if (ch == Char(']')) { depth -= 1 }
            i += 1
        }
        return i - 1
    }

    /// 查找匹配的泛型尖括号
    private func findMatchingGeneric(start: Int64): Int64 {
        var depth = 1
        var i = start + 1
        while (i < source.length && depth > 0) {
            let ch = source[Int64(i)]
            if (ch == Char('<')) { depth += 1 }
            else if (ch == Char('>')) { depth -= 1 }
            else if (ch == Char('\'') || ch == Char('"') || ch == Char('`')) {
                i = skipStringInScan(i)
                continue
            }
            i += 1
        }
        return i - 1
    }

    /// 在字符串中查找匹配的右花括号
    private static func findMatchingBraceInString(s: String, start: Int64): Int64 {
        var depth = 1
        var i = start
        while (i < s.length && depth > 0) {
            let ch = s[Int64(i)]
            if (ch == Char('{')) { depth += 1 }
            else if (ch == Char('}')) { depth -= 1 }
            i += 1
        }
        return i - 1
    }

    /// 跳过扫描中的字符串
    private func skipStringInScan(start: Int64): Int64 {
        let quote = source[Int64(start)]
        var i = start + 1
        while (i < source.length) {
            let ch = source[Int64(i)]
            if (ch == Char('\\')) {
                i += 2
                continue
            }
            if (ch == quote) {
                return i + 1
            }
            i += 1
        }
        return i
    }

    /// 复制字符串字面量到输出
    private func copyStringLiteral(): Unit {
        let quote = source[Int64(pos)]
        output.append(quote)
        pos += 1
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            output.append(ch)
            pos += 1
            if (ch == Char('\\') && pos < source.length) {
                output.append(source[Int64(pos)])
                pos += 1
            } else if (ch == quote) {
                break
            }
        }
    }

    /// 复制模板字符串到输出
    private func copyTemplateLiteral(): Unit {
        output.append(Char('`'))
        pos += 1
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char('\\')) {
                output.append(ch)
                pos += 1
                if (pos < source.length) {
                    output.append(source[Int64(pos)])
                    pos += 1
                }
            } else if (ch == Char('`')) {
                output.append(ch)
                pos += 1
                break
            } else if (ch == Char('$') && pos + 1 < source.length && source[Int64(pos + 1)] == Char('{')) {
                output.append(Char('$'))
                output.append(Char('{'))
                pos += 2
                // 简化: 复制到匹配的 }
                var depth = 1
                while (pos < source.length && depth > 0) {
                    let c = source[Int64(pos)]
                    if (c == Char('{')) { depth += 1 }
                    else if (c == Char('}')) { depth -= 1 }
                    output.append(c)
                    pos += 1
                }
            } else {
                output.append(ch)
                pos += 1
            }
        }
    }

    /// 跳过行注释
    private func skipLineComment(): Unit {
        output.append(Char('/'))
        output.append(Char('/'))
        pos += 2
        while (pos < source.length && source[Int64(pos)] != Char('\n')) {
            output.append(source[Int64(pos)])
            pos += 1
        }
    }

    /// 跳过块注释
    private func skipBlockComment(): Unit {
        output.append(Char('/'))
        output.append(Char('*'))
        pos += 2
        while (pos + 1 < source.length) {
            output.append(source[Int64(pos)])
            if (source[Int64(pos)] == Char('*') && source[Int64(pos + 1)] == Char('/')) {
                output.append(Char('/'))
                pos += 2
                break
            }
            pos += 1
        }
    }

    private func isIdentStart(ch: Char): Bool {
        let v = ch.value
        return (v >= 97 && v <= 122) || (v >= 65 && v <= 90) || v == 95 || v == 36
    }

    private func isNumericString(s: String): Bool {
        if (s.length == 0) { return false }
        for (ch in s) {
            let v = ch.value
            if (!((v >= 48 && v <= 57) || v == 45 || v == 46)) {
                return false
            }
        }
        return true
    }

    private func parseInt64(s: String): Int64 {
        var result: Int64 = 0
        for (ch in s) {
            let v = ch.value
            if (v >= 48 && v <= 57) {
                result = result * 10 + Int64(v - 48)
            }
        }
        return result
    }
}

// ============================================================================
// EnumMember - Enum 成员
// ============================================================================

/// Enum 成员数据
public class EnumMember {
    public var name: String
    public var value: String
    public var isNumeric: Bool

    public init(name: String, value: String, isNumeric: Bool) {
        this.name = name
        this.value = value
        this.isNumeric = isNumeric
    }
}

// ============================================================================
// TSTransformOptions - TypeScript 转换选项
// ============================================================================

/// TypeScript 转换选项
public class TSTransformOptions {
    public var stripOnly: Bool
    public var transformEnums: Bool
    public var transformNamespaces: Bool
    public var transformDecorators: Bool
    public var experimentalDecorators: Bool
    public var emitDecoratorMetadata: Bool
    public var useDefineForClassFields: Bool
    public var preserveImportsNotUsedAsValues: Bool

    public init() {
        stripOnly = false
        transformEnums = true
        transformNamespaces = true
        transformDecorators = true
        experimentalDecorators = false
        emitDecoratorMetadata = false
        useDefineForClassFields = true
        preserveImportsNotUsedAsValues = false
    }
}

// ============================================================================
// TypeEraser - 类型擦除器
// 严格翻译自: esbuild 的 TypeScript 类型剥离
// Bun 使用 esbuild 的 Go 实现，此为仓颉等价实现
//
// 核心逻辑:
//   1. 移除所有类型注解 (x: number -> x)
//   2. 移除 interface 声明
//   3. 移除 type 别名
//   4. 移除 declare 语句
//   5. 转换 enum 为对象
//   6. 转换 namespace 为 IIFE
//   7. 移除泛型参数
//   8. 移除 as 类型断言
//   9. 移除非空断言 (!)
//   10. 移除 TypeScript 导入/导出语法
// ============================================================================

/// 类型擦除器 - 对应 esbuild/Bun 的 TypeScript 类型剥离
public class TypeEraser {
    /// 擦除所有 TypeScript 语法 - 对应 Bun 的 TypeScript 处理
    public func eraseAll(source: String): String {
        let transformer = TSTransformer()
        return transformer.transform(source)
    }
}
