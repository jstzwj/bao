// glob.cj - Glob模式入口
// 严格翻译自: src/glob/glob.zig
// 1:1 翻译 Bun glob 模块到仓颉

package bao_glob

// ============================================================================
// detectGlobSyntax - 检测字符串是否包含glob语法
// 严格翻译自: src/glob/glob.zig detectGlobSyntax
// ============================================================================

/// 检测给定字符串是否包含glob语法 (排除转义的反斜杠)
/// 支持的语法: !, *, {, [, ?
public func detectGlobSyntax(potentialPattern: String): Bool {
    let bytes = potentialPattern.toArray()

    // 否定只能在模式开头
    if (bytes.size > 0 && bytes[0] == UInt8(33)) {  // '!' = 33
        return true
    }

    // 按流行度降序排列
    let specialSyntax: Array<UInt8> = [UInt8(42), UInt8(123), UInt8(91), UInt8(63)]  // '*', '{', '[', '?'

    for (token in specialSyntax) {
        var i: Int64 = 0
        while (i < bytes.size) {
            // 查找 token
            var found: Bool = false
            var idx: Int64 = i
            while (idx < bytes.size) {
                if (bytes[idx] == token) {
                    found = true
                    break
                }
                idx += 1
            }
            if (!found) {
                break
            }

            // 检查前面的反斜杠数量 (偶数=未转义)
            var backslashCount: Int64 = 0
            var j: Int64 = idx
            while (j > 0 && bytes[j - 1] == UInt8(92)) {  // '\\' = 92
                backslashCount += 1
                j -= 1
            }

            if (backslashCount % 2 == 0) {
                return true
            }
            i = idx + 1
        }
    }

    return false
}
