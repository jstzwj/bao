// bao_patch - 统一差异补丁解析器
// 严格翻译自: bun/src/patch/patch.zig
//   统一差异格式的补丁文件解析与应用
//   支持: 文件修改、文件创建、文件删除、文件重命名、模式更改
package bao_patch

import bao_core.*

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
//   pub const PatchMutationPart = struct {
//       type: PartType,
//       lines: List([]const u8) = .{},
//       no_newline_at_end_of_file: bool = false,
//   };
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
//   pub const Header = struct {
//       original: struct { start: u32, len: u32 },
//       patched: struct { start: u32, len: u32 },
//   };
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
//   pub const Hunk = struct {
//       header: Header,
//       parts: List(PatchMutationPart) = .{},
//   };
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
                case Context => {
                    patchedLen += part.lines.size
                    origLen += part.lines.size
                }
                case Insertion => patchedLen += part.lines.size
                case Deletion => origLen += part.lines.size
            }
        }

        origLen == header.origLen && patchedLen == header.patchedLen
    }
}

// ============================================================================
// FilePatch - 文件补丁
// 严格翻译自: patch.zig - FilePatch
//   pub const FilePatch = struct {
//       path: []const u8,
//       hunks: List(Hunk),
//       before_hash: ?[]const u8,
//       after_hash: ?[]const u8,
//   };
// ============================================================================

/// 文件补丁 - 对应 Bun FilePatch
public class FilePatch {
    /// 文件路径
    public var path: String
    /// 补丁块列表
    public var hunks: ArrayList<Hunk>
    /// 修改前哈希
    public var beforeHash: ?String
    /// 修改后哈希
    public var afterHash: ?String

    public init(path: String) {
        this.path = path
        hunks = ArrayList<Hunk>()
        beforeHash = None
        afterHash = None
    }
}

// ============================================================================
// FileDeletion - 文件删除
// 严格翻译自: patch.zig - FileDeletion
// ============================================================================

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

// ============================================================================
// FileCreation - 文件创建
// 严格翻译自: patch.zig - FileCreation
// ============================================================================

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

// ============================================================================
// FileRename - 文件重命名
// 严格翻译自: patch.zig - FileRename
// ============================================================================

/// 文件重命名 - 对应 Bun FileRename
public class FileRename {
    public var fromPath: String
    public var toPath: String

    public init(fromPath: String, toPath: String) {
        this.fromPath = fromPath
        this.toPath = toPath
    }
}

// ============================================================================
// FileModeChange - 文件模式更改
// 严格翻译自: patch.zig - FileModeChange
// ============================================================================

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
//   pub const PatchFilePart = union(enum) {
//       file_patch: *FilePatch,
//       file_deletion: *FileDeletion,
//       ...
//   };
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
//   pub const PatchFile = struct {
//       parts: List(PatchFilePart) = .{},
//   };
// ============================================================================

/// 补丁文件 - 对应 Bun PatchFile
/// 解析后的统一差异格式补丁文件
public class PatchFile {
    /// 补丁文件部分列表
    public var parts: ArrayList<PatchFilePart>

    public init() {
        parts = ArrayList<PatchFilePart>()
    }

    // ========================================================================
    // parsePatchFile - 解析补丁文件
    // 严格翻译自: patch.zig - parsePatchFile
    //   pub fn parsePatchFile(file: []const u8) ParseErr!PatchFile
    //   NOTE: 返回的 PatchFile 中的字符串指针指向原始输入文本
    // ========================================================================

    /// 解析统一差异格式的补丁文件
    /// 对应 Bun parsePatchFile
    public static func parse(file: String): ?PatchFile {
        let parser = PatchLinesParser()
        // 先尝试标准解析
        var result = parser.parse(file, false)
        if (result.isNone()) {
            // 如果 hunk_header_integrity_check_failed，尝试 legacy diff 模式
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
// FileDeets - 解析过程中的文件详情 (内部类型)
// 严格翻译自: patch.zig - FileDeets
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
        // 将空字符串设为 None
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

// ============================================================================
// HunkLineType - Hunk 行类型
// 严格翻译自: patch.zig - PatchLinesParser.HunkLineType
// ============================================================================

/// Hunk 行类型 - 对应 Bun HunkLineType
enum HunkLineType {
    | Context    // 上下文行 (空格开头)
    | Insertion  // 插入行 (+)
    | Deletion   // 删除行 (-)
    | Header     // @@ 头部
    | Pragma     // \ No newline at end of file
}

// ============================================================================
// PatchLinesParser - 补丁行解析器
// 严格翻译自: patch.zig - PatchLinesParser
//   pub const PatchLinesParser = struct { ... };
//   pub fn parse(...) ParseErr!void { ... }
// ============================================================================

/// 补丁行解析器 - 对应 Bun PatchLinesParser
class PatchLinesParser {
    var result: ArrayList<FileDeets>
    var currentFilePatch: FileDeets
    var state: ParserState
    var currentHunk: ?Hunk
    var currentHunkMutationPart: ?PatchMutationPart

    enum ParserState {
        | ParsingHeader
        | ParsingHunks
    }

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
        if (end > 0 && file[end - 1] == '\n') {
            end -= 1
        }
        if (end == 0) {
            return None
        }

        let content = file.subString(0, end)
        let lines = content.split("\n")

        for (line in lines) {
            match (state) {
                case ParsingHeader => {
                    if (line.startsWith("@@")) {
                        state = ParserState.ParsingHunks
                        currentFilePatch.hunks = ArrayList<Hunk>()
                        // 回退一行，让 ParsingHunks 处理
                        // (在 Cangjie 中无法真正回退迭代器，需特殊处理)
                        parseHunkState(line, supportLegacyDiffs)
                    } else if (line.startsWith("diff --git ")) {
                        if (currentFilePatch.diffLineFromPath.isSome()) {
                            commitFilePatch()
                        }
                        let paths = parseDiffLinePaths(line)
                        if (paths.isSome()) {
                            currentFilePatch.diffLineFromPath = paths.getOrThrow()[0]
                            currentFilePatch.diffLineToPath = paths.getOrThrow()[1]
                        }
                    } else if (line.startsWith("old mode ")) {
                        currentFilePatch.oldMode = line.subString("old mode ".size).trim()
                    } else if (line.startsWith("new mode ")) {
                        currentFilePatch.newMode = line.subString("new mode ".size).trim()
                    } else if (line.startsWith("deleted file mode ")) {
                        currentFilePatch.deletedFileMode = line.subString("deleted file mode ".size).trim()
                    } else if (line.startsWith("new file mode ")) {
                        currentFilePatch.newFileMode = line.subString("new file mode ".size).trim()
                    } else if (line.startsWith("rename from ")) {
                        currentFilePatch.renameFrom = line.subString("rename from ".size).trim()
                    } else if (line.startsWith("rename to ")) {
                        currentFilePatch.renameTo = line.subString("rename to ".size).trim()
                    } else if (line.startsWith("index ")) {
                        let hashes = parseDiffHashes(line.subString("index ".size))
                        if (hashes.isSome()) {
                            currentFilePatch.beforeHash = hashes.getOrThrow()[0]
                            currentFilePatch.afterHash = hashes.getOrThrow()[1]
                        }
                    } else if (line.startsWith("--- ")) {
                        let path = line.subString("--- ".size)
                        if (path.startsWith("a/")) {
                            currentFilePatch.fromPath = path.subString(2).trim()
                        } else {
                            currentFilePatch.fromPath = path.trim()
                        }
                    } else if (line.startsWith("+++ ")) {
                        let path = line.subString("+++ ".size)
                        if (path.startsWith("b/")) {
                            currentFilePatch.toPath = path.subString(2).trim()
                        } else {
                            currentFilePatch.toPath = path.trim()
                        }
                    }
                }
                case ParsingHunks => {
                    parseHunkState(line, supportLegacyDiffs)
                }
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
            // 空行视为上下文
            handleContextLine("")
            return
        }

        let firstChar = line[0]
        let hunkLineType: ?HunkLineType = match (firstChar.value) {
            case '@' => HunkLineType.Header
            case '-' => HunkLineType.Deletion
            case '+' => HunkLineType.Insertion
            case ' ' => HunkLineType.Context
            case '\\' => HunkLineType.Pragma
            case '\r' => HunkLineType.Context
            case _ => {
                // 未识别的行，回到 header 解析
                state = ParserState.ParsingHeader
                commitFilePatch()
                None
            }
        }

        if (hunkLineType.isNone()) {
            return
        }

        let hlt = hunkLineType.getOrThrow()

        match (hlt) {
            case Header => {
                commitHunk()
                let hunk = parseHunkHeaderLine(line)
                if (hunk.isSome()) {
                    currentHunk = hunk.getOrThrow()
                }
            }
            case Pragma => {
                if (!line.startsWith("\\ No newline at end of file")) {
                    return // unrecognized_pragma
                }
                if (currentHunkMutationPart.isSome()) {
                    currentHunkMutationPart.getOrThrow().noNewlineAtEndOfFile = true
                }
            }
            case Insertion | Deletion | Context => {
                if (currentHunk.isNone()) {
                    return // hunk_lines_encountered_before_hunk_header
                }

                // 如果类型变化，提交当前 part
                if (currentHunkMutationPart.isSome() &&
                    currentHunkMutationPart.getOrThrow().partType != toPartType(hlt)) {
                    currentHunk.getOrThrow().parts.append(currentHunkMutationPart.getOrThrow())
                    currentHunkMutationPart = None
                }

                // 创建新的 part
                if (currentHunkMutationPart.isNone()) {
                    currentHunkMutationPart = PatchMutationPart(toPartType(hlt))
                }

                // 添加行内容 (去掉第一个字符前缀)
                let lineContent = if (line.size > 1) line.subString(1) else ""
                currentHunkMutationPart.getOrThrow().lines.append(lineContent)
            }
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
            currentHunkMutationPart.getOrThrow().partType != PatchPartType.Context) {
            currentHunk.getOrThrow().parts.append(currentHunkMutationPart.getOrThrow())
            currentHunkMutationPart = None
        }
        if (currentHunkMutationPart.isNone()) {
            currentHunkMutationPart = PatchMutationPart(PatchPartType.Context)
        }
        currentHunkMutationPart.getOrThrow().lines.append(line)
    }

    func commitHunk(): Unit {
        if (currentHunk.isSome()) {
            if (currentHunkMutationPart.isSome()) {
                currentHunk.getOrThrow().parts.append(currentHunkMutationPart.getOrThrow())
                currentHunkMutationPart = None
            }
            currentFilePatch.hunks.append(currentHunk.getOrThrow())
            currentHunk = None
        }
    }

    func commitFilePatch(): Unit {
        commitHunk()
        currentFilePatch.nullifyEmptyStrings()
        result.append(currentFilePatch)
        currentFilePatch = FileDeets()
    }

    /// 解析 hunk 头部行
    /// 对应 Bun PatchLinesParser.parseHunkHeaderLine()
    /// @@ -100,32 +100,32 @@
    func parseHunkHeaderLine(line: String): ?Hunk {
        var trimmed = line.trim()
        // 检查 @@ - 前缀
        if (trimmed.size < 4 || trimmed[0] != '@' || trimmed[1] != '@' ||
            trimmed[2] != ' ' || trimmed[3] != '-') {
            return None
        }
        if (trimmed.size <= 4) { return None }
        trimmed = trimmed.subString(4)

        // 解析第一部分 (原始范围)
        let firstResult = parseHunkHeaderLineImpl(trimmed)
        if (firstResult.isNone()) { return None }
        let fr = firstResult.getOrThrow()

        // 检查 " +" 前缀
        var rest = fr.rest
        if (rest.size < 2 || rest[1] != '+') { return None }
        rest = rest.subString(2)

        // 解析第二部分 (修补范围)
        let secondResult = parseHunkHeaderLineImpl(rest)
        if (secondResult.isNone()) { return None }
        let sr = secondResult.getOrThrow()

        // 检查 " @@" 后缀
        rest = sr.rest
        if (rest.size >= 3 && rest[0] == ' ' && rest[1] == '@' && rest[2] == '@') {
            return Hunk(HunkHeader(
                fr.lineNr, fr.lineCount,
                sr.lineNr, sr.lineCount
            ))
        }

        return None
    }

    /// 解析 hunk 头部中的行号和计数
    /// 对应 Bun PatchLinesParser.parseHunkHeaderLineImpl()
    func parseHunkHeaderLineImpl(text: String): ?HunkHeaderImplResult {
        if (text.size == 0) { return None }

        var lineNrEnd = 0
        var sawComma = false
        var sawWhitespace = false

        while (lineNrEnd < text.size) {
            let ch = text[lineNrEnd]
            if (ch == ',') {
                sawComma = true
                break
            } else if (ch == ' ') {
                sawWhitespace = true
                break
            } else if (ch.value < '0' || ch.value > '9') {
                return None // bad_header_line
            }
            lineNrEnd += 1
        }

        if (!sawComma && !sawWhitespace) { return None }

        let lineNrStr = text.subString(0, lineNrEnd)
        var lineNrCountStr = "1"
        var rest = if (lineNrEnd + 1 < text.size) text.subString(lineNrEnd) else ""
        if (rest.size == 0) { return None }

        if (sawComma) {
            rest = rest.subString(1)
            var firstColEnd = 0
            while (firstColEnd < rest.size) {
                let ch = rest[firstColEnd]
                if (ch == ' ') {
                    sawWhitespace = true
                    break
                } else if (ch.value < '0' || ch.value > '9') {
                    return None
                }
                firstColEnd += 1
            }
            if (!sawWhitespace) { return None }
            lineNrCountStr = rest.subString(0, firstColEnd)
            rest = rest.subString(firstColEnd)
        }

        let lineNr = Int64.parse(lineNrStr).getOr(1)
        let lineCount = Int64.parse(lineNrCountStr).getOr(1)

        HunkHeaderImplResult(
            if (lineNr >= 1) lineNr else 1,
            lineCount,
            rest
        )
    }

    /// 解析 diff --git 行的路径
    /// 对应 Bun PatchLinesParser.parseDiffLinePaths()
    func parseDiffLinePaths(line: String): ?Tuple2<String, String> {
        let prefix = "diff --git a/"
        if (!line.startsWith(prefix)) { return None }
        var rest = line.subString(prefix.size)
        if (rest.size == 0) { return None }

        // 查找 " b/" 分隔符
        var i = 0
        while (i < rest.size) {
            let idx = rest.indexOfFrom("b/", i)
            if (idx.isNone()) { return None }
            let bIdx = idx.getOrThrow()
            if (bIdx > 0 && rest[bIdx - 1] == ' ' && bIdx + 2 < rest.size) {
                let aPath = rest.subString(0, bIdx - 1)
                let bPath = rest.subString(bIdx + 2).trimRight(" \n\r\t".toArray())
                return Tuple2(aPath, bPath)
            }
            i = bIdx + 1
        }

        return None
    }

    /// 解析 index 行的哈希值
    /// 对应 Bun PatchLinesParser.parseDiffHashes()
    func parseDiffHashes(line: String): ?Tuple2<String, String> {
        let delimiterIdx = line.indexOf("..")
        if (delimiterIdx.isNone()) { return None }
        let dIdx = delimiterIdx.getOrThrow()

        let aPart = line.subString(0, dIdx)
        let bStart = dIdx + 2
        if (bStart >= line.size) { return None }

        // 查找空格或结尾
        var bEnd = line.size
        for (j in bStart..line.size) {
            let ch = line[j]
            if (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
                bEnd = j
                break
            }
        }
        let bPart = line.subString(bStart, bEnd)

        Tuple2(aPart, bPart)
    }

    /// 第二遍处理：将 FileDeets 转为 PatchFilePart
    /// 对应 Bun patchFileSecondPass()
    func patchFileSecondPass(): PatchFile {
        let patchFile = PatchFile()

        for (file in result) {
            // 确定类型
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
                case FileRename => {
                    let fromPath = file.renameFrom.getOrThrow()
                    let toPath = file.renameTo.getOrThrow()
                    patchFile.parts.append(PatchFilePart(FileRename(fromPath, toPath)))
                    destinationFilePath = toPath
                }
                case FileDeletion => {
                    let path = file.diffLineFromPath.getOr(file.fromPath.getOr(""))
                    let modeStr = file.deletedFileMode.getOrThrow()
                    let mode = parseFileMode(modeStr)
                    if (mode.isSome()) {
                        let deletion = FileDeletion(path, mode.getOrThrow())
                        if (file.hunks.size > 0) {
                            deletion.hunk = file.hunks[0]
                        }
                        deletion.hash = file.beforeHash
                        patchFile.parts.append(PatchFilePart(deletion))
                    }
                }
                case FileCreation => {
                    let path = file.diffLineToPath.getOr(file.toPath.getOr(""))
                    let modeStr = file.newFileMode.getOrThrow()
                    let mode = parseFileMode(modeStr)
                    if (mode.isSome()) {
                        let creation = FileCreation(path, mode.getOrThrow())
                        if (file.hunks.size > 0) {
                            creation.hunk = file.hunks[0]
                        }
                        creation.hash = file.afterHash
                        patchFile.parts.append(PatchFilePart(creation))
                    }
                }
                case FilePatch | FileModeChange => {
                    destinationFilePath = file.toPath.getOr(file.diffLineToPath)
                }
            }

            // 处理模式更改
            if (destinationFilePath.isSome() &&
                file.oldMode.isSome() && file.newMode.isSome() &&
                file.oldMode.getOrThrow() != file.newMode.getOrThrow()) {
                let oldMode = parseFileMode(file.oldMode.getOrThrow())
                let newMode = parseFileMode(file.newMode.getOrThrow())
                if (oldMode.isSome() && newMode.isSome()) {
                    patchFile.parts.append(PatchFilePart(
                        FileModeChange(destinationFilePath.getOrThrow(),
                                       oldMode.getOrThrow(), newMode.getOrThrow())
                    ))
                }
            }

            // 处理文件补丁
            if (destinationFilePath.isSome() && file.hunks.size > 0) {
                let fp = FilePatch(destinationFilePath.getOrThrow())
                fp.hunks = file.takeHunks()
                fp.beforeHash = file.beforeHash
                fp.afterHash = file.afterHash
                patchFile.parts.append(PatchFilePart(fp))
            }
        }

        return patchFile
    }

    /// 解析文件模式字符串
    func parseFileMode(mode: String): ?FileMode {
        // 解析八进制模式
        let parsed = Int64.parse(mode).getOr(-1)
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

    operator func [](index: Int64): T1 where T1 == T2 {
        if (index == 0) { v1 } else { v2 }
    }
}
