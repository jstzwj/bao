// bao_parsers - CSV 解析器
// 严格翻译自: src/parsers/ 中的 CSV 处理模式
// Bun 不提供独立的 CSV 解析器，但在以下场景处理 CSV:
//   - fetch Response.csv() (Bun 原生扩展)
//   - SQL 查询结果导出
//   - CSV 文件读取 (bun:spawn 输出)
// 仓颉实现完整的 CSV 解析器，包含流式处理
package bao_parsers

import bao_core.*
import bao_collections.*

// ============================================================================
// CsvParser - CSV 解析器
// RFC 4180 CSV 解析器实现
// 支持可配置分隔符、引号字符、行尾处理
// ============================================================================

/// CSV 解析配置
public class CsvOptions {
    /// 分隔符 (默认逗号)
    public var delimiter: Char
    /// 引号字符 (默认双引号)
    public var quote: Char
    /// 转义字符 (默认与引号相同，即 "" 表示一个 ")
    public var escape: Char
    /// 是否允许字段内换行
    public var allowNewlineInField: Bool
    /// 是否跳过空行
    public var skipEmptyLines: Bool
    /// 是否将第一行作为标题行
    public var hasHeaders: Bool
    /// 注释字符 (None 表示不支持)
    public var commentChar: ?Char
    /// 编码 (默认 UTF-8)
    public var encoding: String

    public init() {
        delimiter = ','
        quote = '"'
        escape = '"'
        allowNewlineInField = true
        skipEmptyLines = false
        hasHeaders = true
        commentChar = None
        encoding = "utf-8"
    }

    /// 默认 CSV 配置
    public static func defaults(): CsvOptions {
        return CsvOptions()
    }

    /// TSV (Tab-Separated Values) 配置
    public static func tsv(): CsvOptions {
        let opts = CsvOptions()
        opts.delimiter = '\t'
        return opts
    }

    /// 无标题行配置
    public static func noHeaders(): CsvOptions {
        let opts = CsvOptions()
        opts.hasHeaders = false
        return opts
    }
}

/// CSV 解析结果
public class CsvResult {
    /// 标题行 (如果 hasHeaders = true)
    public var headers: ArrayList<String>
    /// 数据行 (每行是一个字符串数组)
    public var rows: ArrayList<ArrayList<String>>
    /// 总行数 (含标题行)
    public var totalLines: Int64
    /// 已解析行数 (不含跳过的行)
    public var parsedRows: Int64

    public init() {
        headers = ArrayList<String>()
        rows = ArrayList<ArrayList<String>>()
        totalLines = Int64(0)
        parsedRows = Int64(0)
    }

    /// 获取指定行的指定列值
    public func get(row: Int64, col: Int64): ?String {
        if (row < Int64(0) || row >= rows.size) {
            return None
        }
        let r = rows[row]
        if (col < Int64(0) || col >= r.size) {
            return None
        }
        return Some(r[col])
    }

    /// 通过标题名获取值
    public func get(row: Int64, header: String): ?String {
        let colIndex = headers.indexOf(header)
        if (colIndex < Int64(0)) {
            return None
        }
        return get(row, colIndex)
    }

    /// 行数
    public prop rowCount: Int64 {
        get() { rows.size }
    }

    /// 列数 (基于标题行或第一行)
    public prop columnCount: Int64 {
        get() {
            if (headers.size > Int64(0)) {
                headers.size
            } else if (rows.size > Int64(0)) {
                rows[Int64(0)].size
            } else {
                Int64(0)
            }
        }
    }
}

/// CSV 解析器 - RFC 4180 兼容
/// 支持引号字段、嵌入换行、转义引号
public class CsvParser {
    /// 解析选项
    private var options: CsvOptions
    /// 错误收集
    private var errors: ArrayList<ParseError>

    public init() {
        options = CsvOptions.defaults()
        errors = ArrayList<ParseError>()
    }

    public init(options: CsvOptions) {
        this.options = options
        errors = ArrayList<ParseError>()
    }

    /// 解析 CSV 文本
    public func parse(text: String): ParseResult<CsvResult> {
        let result = ParseResult<CsvResult>()
        let csvResult = CsvResult()
        var pos = Int64(0)
        let size = text.size
        var lineNum = Int64(1)

        // 解析所有行
        var isFirstRow = true
        while (pos < size) {
            // 跳过注释行
            if (isCommentLine(text, pos, size)) {
                pos = skipLine(text, pos, size)
                lineNum += Int64(1)
                continue
            }
            // 解析一行
            let row = parseRow(text, pos, size)
            let fields = row.fields
            pos = row.nextPos
            lineNum += Int64(1)

            // 跳过空行
            if (options.skipEmptyLines && isEmptyRow(fields)) {
                continue
            }

            if (isFirstRow && options.hasHeaders) {
                // 第一行作为标题
                for (field in fields) {
                    csvResult.headers.append(field)
                }
                isFirstRow = false
            } else {
                csvResult.rows.append(fields)
                csvResult.parsedRows += Int64(1)
                isFirstRow = false
            }
        }

        csvResult.totalLines = lineNum - Int64(1)
        if (errors.size > Int64(0)) {
            for (err in errors) {
                result.addError(err)
            }
        } else {
            result.value = Some(csvResult)
            result.state = ParseState.Success
        }
        result.consumedBytes = pos
        return result
    }

    /// 解析单行 - 返回字段列表和下一个位置
    private func parseRow(text: String, start: Int64, size: Int64): ParseRowResult {
        var pos = start
        let fields = ArrayList<String>()
        while (pos < size) {
            let ch = text[Int64(pos)]
            if (ch == '\r' || ch == '\n') {
                // 行尾
                pos = skipNewline(text, pos, size)
                break
            }
            // 解析一个字段
            let fieldResult = parseField(text, pos, size)
            fields.append(fieldResult.field)
            pos = fieldResult.nextPos
            // 检查分隔符或行尾
            if (pos < size) {
                let nextCh = text[Int64(pos)]
                if (nextCh == options.delimiter) {
                    pos += Int64(1) // consume delimiter
                    // 如果分隔符后面紧跟行尾，添加空字段
                    if (pos < size && (text[Int64(pos)] == '\r' || text[Int64(pos)] == '\n')) {
                        fields.append("")
                    }
                } else if (nextCh == '\r' || nextCh == '\n') {
                    pos = skipNewline(text, pos, size)
                    break
                }
            }
        }
        return ParseRowResult(fields, pos)
    }

    /// 解析单个字段
    private func parseField(text: String, start: Int64, size: Int64): ParseFieldResult {
        var pos = start
        if (pos >= size) {
            return ParseFieldResult("", pos)
        }
        let ch = text[Int64(pos)]
        if (ch == options.quote) {
            // 引号字段
            return parseQuotedField(text, pos, size)
        } else {
            // 非引号字段
            return parseUnquotedField(text, pos, size)
        }
    }

    /// 解析引号字段 - RFC 4180: "field with ""embedded"" quotes"
    private func parseQuotedField(text: String, start: Int64, size: Int64): ParseFieldResult {
        var pos = start + Int64(1) // skip opening quote
        let sb = StringBuilder()
        while (pos < size) {
            let ch = text[Int64(pos)]
            if (ch == options.escape) {
                // 检查是否为转义引号 ("")
                if (pos + Int64(1) < size && text[Int64(pos + Int64(1))] == options.quote) {
                    sb.append(options.quote)
                    pos += Int64(2)
                } else {
                    // 结束引号
                    pos += Int64(1) // skip closing quote
                    break
                }
            } else {
                sb.append(ch)
                pos += Int64(1)
            }
        }
        return ParseFieldResult(sb.toString(), pos)
    }

    /// 解析非引号字段
    private func parseUnquotedField(text: String, start: Int64, size: Int64): ParseFieldResult {
        var pos = start
        let sb = StringBuilder()
        while (pos < size) {
            let ch = text[Int64(pos)]
            if (ch == options.delimiter || ch == '\r' || ch == '\n') {
                break
            }
            sb.append(ch)
            pos += Int64(1)
        }
        return ParseFieldResult(sb.toString(), pos)
    }

    /// 跳过换行 (\r\n 或 \n)
    private func skipNewline(text: String, pos: Int64, size: Int64): Int64 {
        if (pos >= size) { return pos }
        if (text[Int64(pos)] == '\r') {
            pos += Int64(1)
            if (pos < size && text[Int64(pos)] == '\n') {
                pos += Int64(1)
            }
        } else if (text[Int64(pos)] == '\n') {
            pos += Int64(1)
        }
        return pos
    }

    /// 跳过整行
    private func skipLine(text: String, pos: Int64, size: Int64): Int64 {
        var p = pos
        while (p < size && text[Int64(p)] != '\r' && text[Int64(p)] != '\n') {
            p += Int64(1)
        }
        return skipNewline(text, p, size)
    }

    /// 是否为注释行
    private func isCommentLine(text: String, pos: Int64, size: Int64): Bool {
        match (options.commentChar) {
            case Some(commentCh) =>
                pos < size && text[Int64(pos)] == commentCh
            case None => false
        }
    }

    /// 是否为空行
    private func isEmptyRow(fields: ArrayList<String>): Bool {
        if (fields.size == Int64(0)) {
            return true
        }
        if (fields.size == Int64(1) && fields[Int64(0)].size == Int64(0)) {
            return true
        }
        return false
    }

    /// 是否有错误
    public func hasErrors(): Bool {
        errors.size > Int64(0)
    }

    /// 获取错误列表
    public func getErrors(): ArrayList<ParseError> {
        errors
    }
}

/// 行解析结果 (内部使用)
private class ParseRowResult {
    var fields: ArrayList<String>
    var nextPos: Int64

    init(fields: ArrayList<String>, nextPos: Int64) {
        this.fields = fields
        this.nextPos = nextPos
    }
}

/// 字段解析结果 (内部使用)
private class ParseFieldResult {
    var field: String
    var nextPos: Int64

    init(field: String, nextPos: Int64) {
        this.field = field
        this.nextPos = nextPos
    }
}

// ============================================================================
// CsvWriter - CSV 写入器
// RFC 4180 兼容的 CSV 生成器
// ============================================================================

/// CSV 写入器
public class CsvWriter {
    private var options: CsvOptions
    private var sb: StringBuilder

    public init() {
        options = CsvOptions.defaults()
        sb = StringBuilder()
    }

    public init(options: CsvOptions) {
        this.options = options
        sb = StringBuilder()
    }

    /// 写入标题行
    public func writeHeaders(headers: ArrayList<String>): Unit {
        writeRow(headers)
    }

    /// 写入标题行 (可变参数)
    public func writeHeaders(headers: Array<String>): Unit {
        let list = ArrayList<String>()
        for (h in headers) {
            list.append(h)
        }
        writeRow(list)
    }

    /// 写入数据行
    public func writeRow(fields: ArrayList<String>): Unit {
        if (sb.size > Int64(0)) {
            sb.append('\n')
        }
        var first = true
        for (field in fields) {
            if (!first) {
                sb.append(options.delimiter)
            }
            first = false
            sb.append(escapeField(field))
        }
    }

    /// 写入数据行 (可变参数)
    public func writeRow(fields: Array<String>): Unit {
        let list = ArrayList<String>()
        for (f in fields) {
            list.append(f)
        }
        writeRow(list)
    }

    /// 写入所有行
    public func writeAll(rows: ArrayList<ArrayList<String>>): Unit {
        for (row in rows) {
            writeRow(row)
        }
    }

    /// 写入带标题的所有数据
    public func writeAll(headers: ArrayList<String>, rows: ArrayList<ArrayList<String>>): Unit {
        writeHeaders(headers)
        writeAll(rows)
    }

    /// 转义字段 - RFC 4180: 包含逗号/引号/换行的字段需要用引号包围
    private func escapeField(field: String): String {
        var needsQuoting = false
        // 检查是否需要引号
        for (ch in field) {
            if (ch == options.delimiter || ch == options.quote || ch == '\n' || ch == '\r') {
                needsQuoting = true
                break
            }
        }
        if (!needsQuoting && field.size > Int64(0)) {
            return field
        }
        if (field.size == Int64(0)) {
            return ""
        }
        // 用引号包围，转义内部引号
        let escaped = StringBuilder()
        escaped.append(options.quote)
        for (ch in field) {
            if (ch == options.quote) {
                escaped.append(options.escape)
                escaped.append(options.quote)
            } else {
                escaped.append(ch)
            }
        }
        escaped.append(options.quote)
        return escaped.toString()
    }

    /// 获取生成的 CSV 文本
    public func toString(): String {
        sb.toString()
    }

    /// 重置
    public func reset(): Unit {
        sb = StringBuilder()
    }
}

// ============================================================================
// StreamingCsvParser - 流式 CSV 解析器
// 用于逐行解析大 CSV 文件
// ============================================================================

/// 流式 CSV 行解析器 - 逐行处理
/// 用于处理大 CSV 文件而不需要一次性加载到内存
public class StreamingCsvParser {
    /// 解析选项
    private var options: CsvOptions
    /// 缓冲区 (用于未完成的行)
    private var buffer: StringBuilder
    /// 是否在引号字段内
    private var inQuote: Bool
    /// 是否已解析标题
    private var headersParsed: Bool
    /// 标题行
    private var headers: ArrayList<String>
    /// 行号
    private var lineNum: Int64

    public init() {
        options = CsvOptions.defaults()
        buffer = StringBuilder()
        inQuote = false
        headersParsed = false
        headers = ArrayList<String>()
        lineNum = Int64(0)
    }

    public init(options: CsvOptions) {
        this.options = options
        buffer = StringBuilder()
        inQuote = false
        headersParsed = false
        headers = ArrayList<String>()
        lineNum = Int64(0)
    }

    /// 追加数据块并返回已完成的行
    /// 返回: 解析出的完整行列表 (可能为空)
    public func feed(chunk: String): ArrayList<ArrayList<String>> {
        let completedRows = ArrayList<ArrayList<String>>()
        for (ch in chunk) {
            buffer.append(ch)
            if (!inQuote && ch == '\n') {
                // 行完成
                let line = buffer.toString()
                buffer = StringBuilder()
                lineNum += Int64(1)
                let fields = parseLineComplete(line)
                if (fields.size > Int64(0)) {
                    if (!headersParsed && options.hasHeaders) {
                        headers = fields
                        headersParsed = true
                    } else {
                        completedRows.append(fields)
                    }
                }
            }
            if (ch == options.quote) {
                inQuote = !inQuote
            }
        }
        return completedRows
    }

    /// 获取剩余缓冲区内容 (文件结束时调用)
    public func finish(): ?ArrayList<String> {
        if (buffer.size == Int64(0)) {
            return None
        }
        let line = buffer.toString().trimAscii()
        buffer = StringBuilder()
        if (line.size == Int64(0)) {
            return None
        }
        let fields = parseLineComplete(line)
        if (fields.size > Int64(0)) {
            if (!headersParsed && options.hasHeaders) {
                headers = fields
                headersParsed = true
                return None
            }
            return Some(fields)
        }
        return None
    }

    /// 解析完整行
    private func parseLineComplete(line: String): ArrayList<String> {
        let fields = ArrayList<String>()
        var pos = Int64(0)
        let size = line.size
        // 去掉行尾换行
        var endPos = size
        while (endPos > Int64(0) && (line[endPos - Int64(1)] == '\r' || line[endPos - Int64(1)] == '\n')) {
            endPos -= Int64(1)
        }
        while (pos < endPos) {
            let ch = line[pos]
            if (ch == options.quote) {
                // 引号字段
                pos += Int64(1)
                let sb = StringBuilder()
                while (pos < endPos) {
                    let c = line[pos]
                    if (c == options.quote) {
                        if (pos + Int64(1) < endPos && line[pos + Int64(1)] == options.quote) {
                            sb.append(options.quote)
                            pos += Int64(2)
                        } else {
                            pos += Int64(1)
                            break
                        }
                    } else {
                        sb.append(c)
                        pos += Int64(1)
                    }
                }
                fields.append(sb.toString())
                // 跳过分隔符
                if (pos < endPos && line[pos] == options.delimiter) {
                    pos += Int64(1)
                }
            } else {
                // 非引号字段
                let sb = StringBuilder()
                while (pos < endPos && line[pos] != options.delimiter) {
                    sb.append(line[pos])
                    pos += Int64(1)
                }
                fields.append(sb.toString())
                if (pos < endPos && line[pos] == options.delimiter) {
                    pos += Int64(1)
                    // 尾部分隔符 → 空字段
                    if (pos >= endPos) {
                        fields.append("")
                    }
                }
            }
        }
        return fields
    }

    /// 获取标题
    public func getHeaders(): ArrayList<String> {
        headers
    }

    /// 获取行号
    public func getLineNum(): Int64 {
        lineNum
    }

    /// 是否已解析标题
    public func isHeadersParsed(): Bool {
        headersParsed
    }

    /// 重置
    public func reset(): Unit {
        buffer = StringBuilder()
        inQuote = false
        headersParsed = false
        headers.clear()
        lineNum = Int64(0)
    }
}
