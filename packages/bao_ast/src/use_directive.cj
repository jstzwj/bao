// 严格翻译自: src/ast/use_directive.zig (~65行)
// bao_ast - UseDirective: "use client" / "use server" 指令解析
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// UseDirective - "use" 指令解析
// 严格翻译自: src/ast/use_directive.zig:1-65
//
// 解析文件顶部的 "use client" 或 "use server" 指令。
// 这些指令用于 React Server Components 中标记模块的运行环境。
//
// 注意: ServerComponentBoundary 中已包含 UseDirective 枚举定义。
// 本文件提供解析功能。
// ============================================================================

/// 解析 "use" 指令 - 对应 Bun UseDirective.parse()
/// Bun: pub fn parse(contents: []const u8) ?UseDirective
///
/// 从文件内容中检测 "use client" 或 "use server" 指令。
/// 指令必须是文件的第一个语句 (可以有空白/分号前缀)。
///
/// 返回值:
///   UseDirective.Client - 检测到 "use client"
///   UseDirective.Server - 检测到 "use server"
///   None - 未检测到有效指令
///   null (作为 ?UseDirective) - 内容太短或不匹配
public func parseUseDirective(contents: String): ?UseDirective {
    // 去除前导空白/换行/分号
    var truncated = trimLeftDirective(contents)
    let minLength = "'use client';".size  // 13

    if (truncated.size < minLength) {
        return None
    }

    // 取前 13 个字符检查
    let directiveString = truncated[0..minLength]

    // 检查引号: 第一个和倒数第二个字符必须是相同的引号
    let firstQuote = directiveString[0]
    let lastQuote = directiveString[directiveString.size - Int64(2)]
    if (firstQuote != lastQuote) {
        return None
    }
    if (firstQuote != Char('"') && firstQuote != Char('\'') && firstQuote != Char('`')) {
        return None
    }

    // 提取引号内的内容
    let unquoted = directiveString[Int64(1)..(directiveString.size - Int64(2))]

    // 检查指令内容
    if (unquoted == "use client") {
        return UseDirective.Client
    }

    if (unquoted == "use server") {
        return UseDirective.Server
    }

    return None
}

/// 去除前导空白 - 对应 Bun std.mem.trimLeft(u8, contents, " \t\n\r;")
private func trimLeftDirective(s: String): String {
    var i = Int64(0)
    while (i < s.size) {
        let c = s[i]
        if (c != Char(' ') && c != Char('\t') && c != Char('\n') &&
            c != Char('\r') && c != Char(';')) {
            return s[i..]
        }
        i += Int64(1)
    }
    return ""
}
