// 严格翻译自: src/patch/patch.zig
// 统一差异补丁解析器 - 解析 unified diff 格式的补丁文件
//   - PatchFile: 顶层补丁文件 (包含多个 PatchFilePart)
//   - PatchFilePart: 单个文件变更 (修改/删除/创建/重命名/模式更改)
//   - Hunk: @@ -1,3 +1,3 @@ 块
//   - PatchMutationPart: 块内修改部分 (上下文/插入/删除)
//   - PatchLinesParser: 行级解析器 (核心解析逻辑)
//   - parsePatchFile / apply / diffPostProcess: 顶层 API
package bao_patch

import bao_core.*
import std.collection.*

// ============================================================================
// ParseError - 解析错误类型
// 严格翻译自: patch.zig - ParseErr
// ============================================================================

/// 补丁解析错误 - 对应 Bun ParseErr
public enum PatchParseError {
    | UnrecognizedPragma
    | NoNewlineAtEofPragmaEncounteredWithoutContext
    | HunkLinesEncounteredBeforeHunkHeader
    | HunkHeaderIntegrityCheckFailed
    | BadDiffLine
    | BadHeaderLine
    | RenameFromAndToNotGiven
    | NoPathGivenForFileDeletion
    | NoPathGivenForFileCreation
    | BadFileMode

    public func message(): String {
        match (this) {
            case UnrecognizedPragma => "unrecognized pragma"
            case NoNewlineAtEofPragmaEncounteredWithoutContext => "no newline at end of file pragma encountered without context"
            case HunkLinesEncounteredBeforeHunkHeader => "hunk lines encountered before hunk header"
            case HunkHeaderIntegrityCheckFailed => "hunk header integrity check failed"
            case BadDiffLine => "bad diff line"
            case BadHeaderLine => "bad header line"
            case RenameFromAndToNotGiven => "rename from and to not given"
            case NoPathGivenForFileDeletion => "no path given for file deletion"
            case NoPathGivenForFileCreation => "no path given for file creation"
            case BadFileMode => "bad file mode"
        }
    }
}

// ============================================================================
// PatchFilePartKind - 补丁文件部分类型
// 严格翻译自: patch.zig - PatchFilePartKind
// ============================================================================

/// 补丁文件部分类型 - 对应 Bun PatchFilePartKind
public enum PatchFilePartKind {
    | FilePatch       // 文件修改
    | FileDeletion    // 文件删除
    | FileCreation    // 文件创建
    | FileRename      // 文件重命名
    | FileModeChange  // 文件模式更改
}

// ============================================================================
// PartType - 修改部分类型
// 严格翻译自: patch.zig - PatchMutationPart.PartType
//   pub const PartType = enum(u2) { context = 0, insertion, deletion };
// ============================================================================

/// 修改部分类型 - 对应 Bun PartType
public enum PatchPartType {
    | Context    // 上下文行 (未修改)
    | Insertion  // 插入行 (+)
    | Deletion   // 删除行 (-)

    public operator func ==(right: PatchPartType): Bool {
        match (this) {
            case Context => match (right) { case Context => true case _ => false }
            case Insertion => match (right) { case Insertion => true case _ => false }
            case Deletion => match (right) { case Deletion => true case _ => false }
        }
    }
}

// ============================================================================
// FileMode - 文件权限模式
// 严格翻译自: patch.zig - FileMode
//   pub const FileMode = enum(u32) { non_executable = 0o644, executable = 0o755 };
// ============================================================================

/// 文件权限模式 - 对应 Bun FileMode
public enum FileMode {
    | NonExecutable  // 0o644
    | Executable     // 0o755

    /// 转换为数字模式
    public func toMode(): Int64 {
        match (this) {
            case NonExecutable => 0o644
            case Executable => 0o755
        }
    }

    /// 从数字解析
    public static func fromU32(mode: Int64): ?FileMode {
        match (mode) {
            case 0o644 => FileMode.NonExecutable
            case 0o755 => FileMode.Executable
            case _ => None
        }
    }
}

// ============================================================================
// PatchMutationPart - 修改部分
// 严格翻译自: patch.zig - PatchMutationPart
// ============================================================================

/// 修改部分 - 对应 Bun PatchMutationPart
public class PatchMutationPart {
    /// 部分类型
    public var partType: PatchPartType
    /// 行内容
    public var lines: ArrayList<String>
    /// 文件末尾无换行
    public var noNewlineAtEndOfFile: Bool

    public init(partType: PatchPartType) {
        this.partType = partType
        lines = ArrayList<String>()
        noNewlineAtEndOfFile = false
    }
}

// ============================================================================
// HunkHeader - Hunk 头部
// 严格翻译自: patch.zig - Hunk.Header
// ============================================================================

/// Hunk 头部范围信息 - 对应 Bun Hunk.Header
public class HunkHeader {
    /// 原始文件的起始行号和行数
    public var origStart: Int64
    public var origLen: Int64
    /// 修补后的起始行号和行数
    public var patchedStart: Int64
    public var patchedLen: Int64

    public init() {
        origStart = 1
        origLen = 0
        patchedStart = 1
        patchedLen = 0
    }

    public init(origStart: Int64, origLen: Int64, patchedStart: Int64, patchedLen: Int64) {
        this.origStart = origStart
        this.origLen = origLen
        this.patchedStart = patchedStart
        this.patchedLen = patchedLen
    }

    /// 空 header
    public static func empty(): HunkHeader {
        HunkHeader(1, 0, 1, 0)
    }
}

// ============================================================================
// Hunk - 补丁块
// 严格翻译自: patch.zig - Hunk
// ============================================================================

/// 补丁块 - 对应 Bun Hunk
/// 表示一个 @@ -1,3 +1,3 @@ 块
public class Hunk {
    /// 头部信息
    public var header: HunkHeader
    /// 修改部分列表
    public var parts: ArrayList<PatchMutationPart>

    public init() {
        header = HunkHeader.empty()
        parts = ArrayList<PatchMutationPart>()
    }

    public init(header: HunkHeader) {
        this.header = header
        parts = ArrayList<PatchMutationPart>()
    }

    /// 验证完整性
    /// 对应 Bun Hunk.verifyIntegrity()
    public func verifyIntegrity(): Bool {
        var origLen: Int64 = 0
        var patchedLen: Int64 = 0

        for (part in parts) {
            match (part.partType) {
                case Insertion => patchedLen += part.lines.size
                case Deletion => origLen += part.lines.size
                case _ => patchedLen += part.lines.size; origLen += part.lines.size
            }
        }

        origLen == header.origLen && patchedLen == header.patchedLen
    }
}

// ============================================================================
// FilePatch / FileDeletion / FileCreation / FileRename / FileModeChange
// 严格翻译自: patch.zig 中同名 struct
// ============================================================================

/// 文件补丁 - 对应 Bun FilePatch
public class FilePatch {
    public var path: String
    public var hunks: ArrayList<Hunk>
    public var beforeHash: ?String
    public var afterHash: ?String

    public init(path: String) {
        this.path = path
        hunks = ArrayList<Hunk>()
        beforeHash = None
        afterHash = None
    }
}

/// 文件删除 - 对应 Bun FileDeletion
public class FileDeletion {
    public var path: String
    public var mode: FileMode
    public var hunk: ?Hunk
    public var hash: ?String

    public init(path: String, mode: FileMode) {
        this.path = path
        this.mode = mode
        hunk = None
        hash = None
    }
}

/// 文件创建 - 对应 Bun FileCreation
public class FileCreation {
    public var path: String
    public var mode: FileMode
    public var hunk: ?Hunk
    public var hash: ?String

    public init(path: String, mode: FileMode) {
        this.path = path
        this.mode = mode
        hunk = None
        hash = None
    }
}

/// 文件重命名 - 对应 Bun FileRename
public class FileRename {
    public var fromPath: String
    public var toPath: String

    public init(fromPath: String, toPath: String) {
        this.fromPath = fromPath
        this.toPath = toPath
    }
}

/// 文件模式更改 - 对应 Bun FileModeChange
public class FileModeChange {
    public var path: String
    public var oldMode: FileMode
    public var newMode: FileMode

    public init(path: String, oldMode: FileMode, newMode: FileMode) {
        this.path = path
        this.oldMode = oldMode
        this.newMode = newMode
    }
}

// ============================================================================
// PatchFilePart - 补丁文件部分 (tagged union)
// 严格翻译自: patch.zig - PatchFilePart
// ============================================================================

/// 补丁文件部分 - 对应 Bun PatchFilePart
public class PatchFilePart {
    public var kind: PatchFilePartKind
    public var filePatch: ?FilePatch
    public var fileDeletion: ?FileDeletion
    public var fileCreation: ?FileCreation
    public var fileRename: ?FileRename
    public var fileModeChange: ?FileModeChange

    public init(filePatch: FilePatch) {
        kind = PatchFilePartKind.FilePatch
        this.filePatch = filePatch
        this.fileDeletion = None
        this.fileCreation = None
        this.fileRename = None
        this.fileModeChange = None
    }

    public init(fileDeletion: FileDeletion) {
        kind = PatchFilePartKind.FileDeletion
        this.filePatch = None
        this.fileDeletion = fileDeletion
        this.fileCreation = None
        this.fileRename = None
        this.fileModeChange = None
    }

    public init(fileCreation: FileCreation) {
        kind = PatchFilePartKind.FileCreation
        this.filePatch = None
        this.fileDeletion = None
        this.fileCreation = fileCreation
        this.fileRename = None
        this.fileModeChange = None
    }

    public init(fileRename: FileRename) {
        kind = PatchFilePartKind.FileRename
        this.filePatch = None
        this.fileDeletion = None
        this.fileCreation = None
        this.fileRename = fileRename
        this.fileModeChange = None
    }

    public init(fileModeChange: FileModeChange) {
        kind = PatchFilePartKind.FileModeChange
        this.filePatch = None
        this.fileDeletion = None
        this.fileCreation = None
        this.fileRename = None
        this.fileModeChange = fileModeChange
    }
}

// ============================================================================
// PatchFile - 补丁文件 (顶层)
// 严格翻译自: patch.zig - PatchFile
// ============================================================================

/// 补丁文件 - 对应 Bun PatchFile
public class PatchFile {
    public var parts: ArrayList<PatchFilePart>

    public init() {
        parts = ArrayList<PatchFilePart>()
    }

    /// 解析统一差异格式的补丁文件
    /// 对应 Bun parsePatchFile
    public static func parse(file: String): ?PatchFile {
        let parser = PatchLinesParser()
        var result = parser.parse(file, false)
        if (result.isNone()) {
            parser.reset()
            result = parser.parse(file, true)
            if (result.isNone()) {
                return None
            }
        }
        result
    }
}

// ============================================================================
// 内部解析类型
// 严格翻译自: patch.zig - FileDeets, HunkLineType, ParserState
// ============================================================================

/// 解析过程中的文件详情 - 对应 Bun FileDeets (内部)
class FileDeets {
    var diffLineFromPath: ?String
    var diffLineToPath: ?String
    var oldMode: ?String
    var newMode: ?String
    var deletedFileMode: ?String
    var newFileMode: ?String
    var renameFrom: ?String
    var renameTo: ?String
    var beforeHash: ?String
    var afterHash: ?String
    var fromPath: ?String
    var toPath: ?String
    var hunks: ArrayList<Hunk>

    init() {
        diffLineFromPath = None
        diffLineToPath = None
        oldMode = None
        newMode = None
        deletedFileMode = None
        newFileMode = None
        renameFrom = None
        renameTo = None
        beforeHash = None
        afterHash = None
        fromPath = None
        toPath = None
        hunks = ArrayList<Hunk>()
    }

    func takeHunks(): ArrayList<Hunk> {
        let result = hunks
        hunks = ArrayList<Hunk>()
        return result
    }

    func nullifyEmptyStrings(): Unit {
        if (diffLineFromPath.isSome() && diffLineFromPath.getOrThrow().size == 0) { diffLineFromPath = None }
        if (diffLineToPath.isSome() && diffLineToPath.getOrThrow().size == 0) { diffLineToPath = None }
        if (oldMode.isSome() && oldMode.getOrThrow().size == 0) { oldMode = None }
        if (newMode.isSome() && newMode.getOrThrow().size == 0) { newMode = None }
        if (deletedFileMode.isSome() && deletedFileMode.getOrThrow().size == 0) { deletedFileMode = None }
        if (newFileMode.isSome() && newFileMode.getOrThrow().size == 0) { newFileMode = None }
        if (renameFrom.isSome() && renameFrom.getOrThrow().size == 0) { renameFrom = None }
        if (renameTo.isSome() && renameTo.getOrThrow().size == 0) { renameTo = None }
        if (beforeHash.isSome() && beforeHash.getOrThrow().size == 0) { beforeHash = None }
        if (afterHash.isSome() && afterHash.getOrThrow().size == 0) { afterHash = None }
        if (fromPath.isSome() && fromPath.getOrThrow().size == 0) { fromPath = None }
        if (toPath.isSome() && toPath.getOrThrow().size == 0) { toPath = None }
    }
}

/// Hunk 行类型 - 对应 Bun HunkLineType
enum HunkLineType {
    | Context
    | Insertion
    | Deletion
    | Header
    | Pragma

    public operator func ==(right: HunkLineType): Bool {
        match (this) {
            case Context => match (right) { case Context => true case _ => false }
            case Insertion => match (right) { case Insertion => true case _ => false }
            case Deletion => match (right) { case Deletion => true case _ => false }
            case Header => match (right) { case Header => true case _ => false }
            case Pragma => match (right) { case Pragma => true case _ => false }
        }
    }
}

enum ParserState {
    | ParsingHeader
    | ParsingHunks

    public operator func ==(right: ParserState): Bool {
        match (this) {
            case ParsingHeader => match (right) { case ParsingHeader => true case _ => false }
            case ParsingHunks => match (right) { case ParsingHunks => true case _ => false }
        }
    }
}

// ============================================================================
// PatchLinesParser - 补丁行解析器
// 严格翻译自: patch.zig - PatchLinesParser
// ============================================================================

/// 补丁行解析器 - 对应 Bun PatchLinesParser
class PatchLinesParser {
    var result: ArrayList<FileDeets>
    var currentFilePatch: FileDeets
    var state: ParserState
    var currentHunk: ?Hunk
    var currentHunkMutationPart: ?PatchMutationPart

    init() {
        result = ArrayList<FileDeets>()
        currentFilePatch = FileDeets()
        state = ParserState.ParsingHeader
        currentHunk = None
        currentHunkMutationPart = None
    }

    func reset(): Unit {
        result = ArrayList<FileDeets>()
        currentFilePatch = FileDeets()
        state = ParserState.ParsingHeader
        currentHunk = None
        currentHunkMutationPart = None
    }

    /// 解析补丁文件内容
    /// 对应 Bun PatchLinesParser.parse()
    func parse(file: String, supportLegacyDiffs: Bool): ?PatchFile {
        if (file.size == 0) {
            return None
        }

        // 移除末尾空行
        var end = file.size
        if (end > 0 && file[end - 1] == UInt8(0x0A)) {
            end -= 1
        }
        if (end == 0) {
            return None
        }

        let content = file[0..end]
        let lines = content.split("\n")

        for (line in lines) {
            if (state == ParserState.ParsingHeader) {
                if (line.startsWith("@@")) {
                    state = ParserState.ParsingHunks
                    currentFilePatch.hunks = ArrayList<Hunk>()
                    parseHunkState(line, supportLegacyDiffs)
                } else if (line.startsWith("diff --git ")) {
                    if (currentFilePatch.diffLineFromPath.isSome()) {
                        commitFilePatch()
                    }
                    let paths = parseDiffLinePaths(line)
                    if (paths.isSome()) {
                        currentFilePatch.diffLineFromPath = paths.getOrThrow().getFirst()
                        currentFilePatch.diffLineToPath = paths.getOrThrow().getSecond()
                    }
                } else if (line.startsWith("old mode ")) {
                    currentFilePatch.oldMode = line["old mode ".size..]
                } else if (line.startsWith("new mode ")) {
                    currentFilePatch.newMode = line["new mode ".size..]
                } else if (line.startsWith("deleted file mode ")) {
                    currentFilePatch.deletedFileMode = line["deleted file mode ".size..]
                } else if (line.startsWith("new file mode ")) {
                    currentFilePatch.newFileMode = line["new file mode ".size..]
                } else if (line.startsWith("rename from ")) {
                    currentFilePatch.renameFrom = line["rename from ".size..]
                } else if (line.startsWith("rename to ")) {
                    currentFilePatch.renameTo = line["rename to ".size..]
                } else if (line.startsWith("index ")) {
                    let hashes = parseDiffHashes(line["index ".size..])
                    if (hashes.isSome()) {
                        currentFilePatch.beforeHash = hashes.getOrThrow().getFirst()
                        currentFilePatch.afterHash = hashes.getOrThrow().getSecond()
                    }
                } else if (line.startsWith("--- ")) {
                    let path = line["--- ".size..]
                    if (path.startsWith("a/")) {
                        currentFilePatch.fromPath = path[2..]
                    } else {
                        currentFilePatch.fromPath = path
                    }
                } else if (line.startsWith("+++ ")) {
                    let path = line["+++ ".size..]
                    if (path.startsWith("b/")) {
                        currentFilePatch.toPath = path[2..]
                    } else {
                        currentFilePatch.toPath = path
                    }
                }
            } else {
                parseHunkState(line, supportLegacyDiffs)
            }
        }

        commitFilePatch()

        // 验证完整性
        for (fileDeet in result) {
            for (hunk in fileDeet.hunks) {
                if (!hunk.verifyIntegrity()) {
                    return None
                }
            }
        }

        return patchFileSecondPass()
    }

    /// 处理 hunk 状态的行
    func parseHunkState(line: String, supportLegacyDiffs: Bool): Unit {
        if (supportLegacyDiffs && line.startsWith("--- a/")) {
            state = ParserState.ParsingHeader
            commitFilePatch()
            return
        }

        if (line.size == 0) {
            handleContextLine("")
            return
        }

        let firstChar = UInt8(line[0])
        var hunkLineType: ?HunkLineType = None
        if (firstChar == UInt8(0x40)) { // '@'
            hunkLineType = HunkLineType.Header
        } else if (firstChar == UInt8(0x2D)) { // '-'
            hunkLineType = HunkLineType.Deletion
        } else if (firstChar == UInt8(0x2B)) { // '+'
            hunkLineType = HunkLineType.Insertion
        } else if (firstChar == UInt8(0x20)) { // ' '
            hunkLineType = HunkLineType.Context
        } else if (firstChar == UInt8(0x5C)) { // '\'
            hunkLineType = HunkLineType.Pragma
        } else if (firstChar == UInt8(0x0D)) { // '\r'
            hunkLineType = HunkLineType.Context
        }

        if (hunkLineType.isNone()) {
            state = ParserState.ParsingHeader
            commitFilePatch()
            return
        }

        let hlt = hunkLineType.getOrThrow()

        if (hlt == HunkLineType.Header) {
            commitHunk()
            let hunk = parseHunkHeaderLine(line)
            if (hunk.isSome()) {
                currentHunk = hunk.getOrThrow()
            }
        } else if (hlt == HunkLineType.Pragma) {
            if (!line.startsWith("\\ No newline at end of file")) {
                return // unrecognized_pragma
            }
            if (currentHunkMutationPart.isSome()) {
                currentHunkMutationPart.getOrThrow().noNewlineAtEndOfFile = true
            }
        } else {
            // Insertion | Deletion | Context
            if (currentHunk.isNone()) {
                return // hunk_lines_encountered_before_hunk_header
            }

            if (currentHunkMutationPart.isSome() &&
                !(currentHunkMutationPart.getOrThrow().partType == toPartType(hlt))) {
                currentHunk.getOrThrow().parts.add(currentHunkMutationPart.getOrThrow())
                currentHunkMutationPart = None
            }

            if (currentHunkMutationPart.isNone()) {
                currentHunkMutationPart = PatchMutationPart(toPartType(hlt))
            }

            let lineContent = if (line.size > 1) { line[1..] } else { "" }
            currentHunkMutationPart.getOrThrow().lines.add(lineContent)
        }
    }

    func toPartType(hlt: HunkLineType): PatchPartType {
        match (hlt) {
            case Context => PatchPartType.Context
            case Insertion => PatchPartType.Insertion
            case Deletion => PatchPartType.Deletion
            case _ => PatchPartType.Context
        }
    }

    func handleContextLine(line: String): Unit {
        if (currentHunk.isNone()) { return }
        if (currentHunkMutationPart.isSome() &&
            !(currentHunkMutationPart.getOrThrow().partType == PatchPartType.Context)) {
            currentHunk.getOrThrow().parts.add(currentHunkMutationPart.getOrThrow())
            currentHunkMutationPart = None
        }
        if (currentHunkMutationPart.isNone()) {
            currentHunkMutationPart = PatchMutationPart(PatchPartType.Context)
        }
        currentHunkMutationPart.getOrThrow().lines.add(line)
    }

    func commitHunk(): Unit {
        if (currentHunk.isSome()) {
            if (currentHunkMutationPart.isSome()) {
                currentHunk.getOrThrow().parts.add(currentHunkMutationPart.getOrThrow())
                currentHunkMutationPart = None
            }
            currentFilePatch.hunks.add(currentHunk.getOrThrow())
            currentHunk = None
        }
    }

    func commitFilePatch(): Unit {
        commitHunk()
        currentFilePatch.nullifyEmptyStrings()
        result.add(currentFilePatch)
        currentFilePatch = FileDeets()
    }

    /// 解析 hunk 头部行
    /// 对应 Bun PatchLinesParser.parseHunkHeaderLine()
    /// @@ -100,32 +100,32 @@
    func parseHunkHeaderLine(line: String): ?Hunk {
        var trimmed = line
        if (trimmed.size < 4 || trimmed[0] != UInt8(0x40) || trimmed[1] != UInt8(0x40) ||
            trimmed[2] != UInt8(0x20) || trimmed[3] != UInt8(0x2D)) {
            return None
        }
        if (trimmed.size <= 4) { return None }
        trimmed = trimmed[4..]

        let firstResult = parseHunkHeaderLineImpl(trimmed)
        if (firstResult.isNone()) { return None }
        let fr = firstResult.getOrThrow()

        var rest = fr.rest
        if (rest.size < 2 || rest[1] != UInt8(0x2B)) { return None }
        rest = rest[2..]

        let secondResult = parseHunkHeaderLineImpl(rest)
        if (secondResult.isNone()) { return None }
        let sr = secondResult.getOrThrow()

        rest = sr.rest
        if (rest.size >= 3 && rest[0] == UInt8(0x20) && rest[1] == UInt8(0x40) && rest[2] == UInt8(0x40)) {
            return Hunk(HunkHeader(
                fr.lineNr, fr.lineCount,
                sr.lineNr, sr.lineCount
            ))
        }

        return None
    }

    /// 解析 hunk 头部中的行号和计数
    func parseHunkHeaderLineImpl(text: String): ?HunkHeaderImplResult {
        if (text.size == 0) { return None }

        var lineNrEnd = 0
        var sawComma = false
        var sawWhitespace = false

        while (lineNrEnd < text.size) {
            let ch = text[lineNrEnd]
            if (ch == UInt8(0x2C)) {
                sawComma = true
                break
            } else if (ch == UInt8(0x20)) {
                sawWhitespace = true
                break
            } else if (ch < UInt8(0x30) || ch > UInt8(0x39)) {
                return None
            }
            lineNrEnd += 1
        }

        if (!sawComma && !sawWhitespace) { return None }

        let lineNrStr = text[0..lineNrEnd]
        var lineNrCountStr = "1"
        var rest = if (lineNrEnd + 1 < text.size) { text[lineNrEnd..] } else { "" }
        if (rest.size == 0) { return None }

        if (sawComma) {
            rest = rest[1..]
            var firstColEnd = 0
            while (firstColEnd < rest.size) {
                let ch = rest[firstColEnd]
                if (ch == UInt8(0x20)) {
                    sawWhitespace = true
                    break
                } else if (ch < UInt8(0x30) || ch > UInt8(0x39)) {
                    return None
                }
                firstColEnd += 1
            }
            if (!sawWhitespace) { return None }
            lineNrCountStr = rest[0..firstColEnd]
            rest = rest[firstColEnd..]
        }

        let lineNr = IntParser.parseInt(lineNrStr, 10)
        let lineCount = IntParser.parseInt(lineNrCountStr, 10)

        HunkHeaderImplResult(
            if (lineNr >= 1) { lineNr } else { 1 },
            lineCount,
            rest
        )
    }

    /// 解析 diff --git 行的路径
    func parseDiffLinePaths(line: String): ?Tuple2<String, String> {
        let prefix = "diff --git a/"
        if (!line.startsWith(prefix)) { return None }
        var rest = line[prefix.size..]
        if (rest.size == 0) { return None }

        var i = 0
        while (i + 2 < rest.size) {
            if (rest[i] == UInt8(0x20) && rest[i + 1] == UInt8(0x62) && rest[i + 2] == UInt8(0x2F)) {
                let aPath = rest[0..i]
                let bPath = rest[i + 3..]
                return Tuple2(aPath, bPath)
            }
            i += 1
        }

        return None
    }

    /// 解析 index 行的哈希值
    func parseDiffHashes(line: String): ?Tuple2<String, String> {
        let delimiterIdx = line.indexOf("..")
        if (delimiterIdx.isNone()) { return None }
        let dIdx = delimiterIdx.getOrThrow()

        let aPart = line[0..dIdx]
        let bStart = dIdx + 2
        if (bStart >= line.size) { return None }

        var bEnd = line.size
        for (j in bStart..line.size) {
            let ch = line[j]
            if (ch == UInt8(0x20) || ch == UInt8(0x0A) || ch == UInt8(0x0D) || ch == UInt8(0x09)) {
                bEnd = j
                break
            }
        }
        let bPart = line[bStart..bEnd]

        Tuple2(aPart, bPart)
    }

    /// 第二遍处理：将 FileDeets 转为 PatchFilePart
    func patchFileSecondPass(): PatchFile {
        let patchFile = PatchFile()

        for (file in result) {
            var kind = PatchFilePartKind.FilePatch
            if (file.renameFrom.isSome() && file.renameFrom.getOrThrow().size > 0) {
                kind = PatchFilePartKind.FileRename
            } else if (file.deletedFileMode.isSome() && file.deletedFileMode.getOrThrow().size > 0) {
                kind = PatchFilePartKind.FileDeletion
            } else if (file.newFileMode.isSome() && file.newFileMode.getOrThrow().size > 0) {
                kind = PatchFilePartKind.FileCreation
            } else if (file.hunks.size == 0) {
                kind = PatchFilePartKind.FileModeChange
            }

            var destinationFilePath: ?String = None

            match (kind) {
                case FileRename =>
                    let fromPath = file.renameFrom.getOrThrow()
                    let toPath = file.renameTo.getOrThrow()
                    patchFile.parts.add(PatchFilePart(FileRename(fromPath, toPath)))
                    destinationFilePath = toPath
                case FileDeletion =>
                    let path = if (file.diffLineFromPath.isSome()) { file.diffLineFromPath.getOrThrow() } else if (file.fromPath.isSome()) { file.fromPath.getOrThrow() } else { "" }
                    let modeStr = file.deletedFileMode.getOrThrow()
                    let mode = parseFileMode(modeStr)
                    if (mode.isSome()) {
                        let deletion = FileDeletion(path, mode.getOrThrow())
                        if (file.hunks.size > 0) {
                            deletion.hunk = file.hunks[0]
                        }
                        deletion.hash = file.beforeHash
                        patchFile.parts.add(PatchFilePart(deletion))
                    }
                case FileCreation =>
                    let path = if (file.diffLineToPath.isSome()) { file.diffLineToPath.getOrThrow() } else if (file.toPath.isSome()) { file.toPath.getOrThrow() } else { "" }
                    let modeStr = file.newFileMode.getOrThrow()
                    let mode = parseFileMode(modeStr)
                    if (mode.isSome()) {
                        let creation = FileCreation(path, mode.getOrThrow())
                        if (file.hunks.size > 0) {
                            creation.hunk = file.hunks[0]
                        }
                        creation.hash = file.afterHash
                        patchFile.parts.add(PatchFilePart(creation))
                    }
                case FilePatch | FileModeChange =>
                    destinationFilePath = if (file.toPath.isSome()) { file.toPath } else { file.diffLineToPath }
            }

            if (destinationFilePath.isSome() &&
                file.oldMode.isSome() && file.newMode.isSome() &&
                file.oldMode.getOrThrow() != file.newMode.getOrThrow()) {
                let oldMode = parseFileMode(file.oldMode.getOrThrow())
                let newMode = parseFileMode(file.newMode.getOrThrow())
                if (oldMode.isSome() && newMode.isSome()) {
                    patchFile.parts.add(PatchFilePart(
                        FileModeChange(destinationFilePath.getOrThrow(),
                                       oldMode.getOrThrow(), newMode.getOrThrow())
                    ))
                }
            }

            if (destinationFilePath.isSome() && file.hunks.size > 0) {
                let fp = FilePatch(destinationFilePath.getOrThrow())
                fp.hunks = file.takeHunks()
                fp.beforeHash = file.beforeHash
                fp.afterHash = file.afterHash
                patchFile.parts.add(PatchFilePart(fp))
            }
        }

        return patchFile
    }

    /// 解析文件模式字符串
    func parseFileMode(mode: String): ?FileMode {
        let parsed = IntParser.parseInt(mode, 10)
        if (parsed < 0) { return None }
        let masked = parsed % 512 // & 0o777
        FileMode.fromU32(masked)
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// Hunk 头部解析结果
class HunkHeaderImplResult {
    var lineNr: Int64
    var lineCount: Int64
    var rest: String

    init(lineNr: Int64, lineCount: Int64, rest: String) {
        this.lineNr = lineNr
        this.lineCount = lineCount
        this.rest = rest
    }
}

/// 二元组
class Tuple2<T1, T2> {
    var v1: T1
    var v2: T2

    init(v1: T1, v2: T2) {
        this.v1 = v1
        this.v2 = v2
    }

    func getFirst(): T1 { v1 }

    func getSecond(): T2 { v2 }
}
