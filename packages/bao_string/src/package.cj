// bao_string - 字符串工具包
// 严格翻译自: src/string/ (Bun string 模块)
//   Bun 的字符串模块提供:
//   - 公共字符串工具函数 (immutable.zig)
//   - 转义正则表达式 (escapeRegExp.zig)
//   - 哈希字符串 (HashedString.zig)
//   - 可变字符串 (MutableString.zig)
//   - 路径字符串 (PathString.zig)
//   - 小字符串优化 SmolStr (SmolStr.zig)
//   - 字符串构建器 (StringBuilder.zig)
//   - 字符串连接器 (StringJoiner.zig)
//   - WTF-8/WTF-16 编码 (wtf.zig)
//   - BunString 主类型 (string.zig)
package bao_string

// ============================================================================
// 模块重导出
// ============================================================================

// 不可变字符串工具 - 严格翻译自 src/string/immutable.zig
public import bao_string.immutable.*

// 转义正则表达式 - 严格翻译自 src/string/escapeRegExp.zig
public import bao_string.escape_reg_exp.*

// 哈希字符串 - 严格翻译自 src/string/HashedString.zig
public import bao_string.hashed_string.*

// 可变字符串 - 严格翻译自 src/string/MutableString.zig
public import bao_string.mutable_string.*

// 路径字符串 - 严格翻译自 src/string/PathString.zig
public import bao_string.path_string.*

// 小字符串优化 - 严格翻译自 src/string/SmolStr.zig
public import bao_string.smol_str.*

// 字符串构建器 - 严格翻译自 src/string/StringBuilder.zig
public import bao_string.string_builder.*

// 字符串连接器 - 严格翻译自 src/string/StringJoiner.zig
public import bao_string.string_joiner.*

// WTF-8/WTF-16 编码 - 严格翻译自 src/string/wtf.zig
public import bao_string.wtf.*

// BunString 主类型 - 严格翻译自 src/string/string.zig
public import bao_string.string.*
