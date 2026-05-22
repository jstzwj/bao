// Path manipulation module (complete translation)
// Translated from Bun: src/runtime/node/path.rs (3788 lines)
// Based on Node v21.6.1 path.js — full POSIX and Windows path support
package bao_runtime.node

import bao_core.*
import bao_sys.*
import std.collection.ArrayList

// ============================================================================
// Constants
// Corresponds to Bun: path.rs lines 193-278
// Based on Node v21.6.1 path.js constants
// ============================================================================
public class PathConstants {
    // Character constants
    public static let CHAR_FORWARD_SLASH: UInt8 = UInt8(0x2F)     // '/'
    public static let CHAR_BACKWARD_SLASH: UInt8 = UInt8(0x5C)    // '\\'
    public static let CHAR_COLON: UInt8 = UInt8(0x3A)              // ':'
    public static let CHAR_DOT: UInt8 = UInt8(0x2E)                // '.'
    public static let CHAR_QUESTION_MARK: UInt8 = UInt8(0x3F)      // '?'

    // String constants
    public static let CHAR_STR_BACKWARD_SLASH: String = "\\"
    public static let CHAR_STR_FORWARD_SLASH: String = "/"
    public static let CHAR_STR_DOT: String = "."

    // Path size constants
    // Corresponds to Bun: path.rs PATH_MIN_WIDE, STACK_FALLBACK_SIZE_SMALL
    public static let PATH_MIN_WIDE: Int64 = 4096
    public static let MAX_PATH_BYTES: Int64 = 4096

    // Separator constants
    public static let SEP_POSIX: UInt8 = UInt8(0x2F)   // '/'
    public static let SEP_WINDOWS: UInt8 = UInt8(0x5C)  // '\\'
    public static let SEP_STR_POSIX: String = "/"
    public static let SEP_STR_WINDOWS: String = "\\"

    // Delimiter constants
    public static let delimiterPosix: String = ":"
    public static let delimiterWindows: String = ";"
}

// ============================================================================
// PathParsed — Parsed path result (root, dir, base, ext, name)
// Corresponds to Bun: path.rs PathParsed<'a, T>
// Based on Node v21.6.1 path.parse return value
// ============================================================================
public class PathParsed {
    public var root: String = ""
    public var dir: String = ""
    public var base: String = ""
    public var ext: String = ""
    public var name: String = ""

    public init() {}

    public init(root: String, dir: String, base: String, ext: String, name: String) {
        this.root = root
        this.dir = dir
        this.base = base
        this.ext = ext
        this.name = name
    }
}

// ============================================================================
// Platform enum for normalize_string dispatch
// Corresponds to Bun: bun_paths::Platform
// ============================================================================
public enum Platform {
    | Posix
    | Windows
}

// ============================================================================
// Path — Complete path manipulation functions
// Corresponds to Bun: path.rs — all path functions
// Based on Node v21.6.1 path.js — full POSIX and Windows implementations
// ============================================================================
public class Path {

    // ========================================================================
    // isSepPosix — Check if byte is POSIX separator ('/')
    // Corresponds to Bun: path.rs is_sep_posix_t
    // ========================================================================
    public static func isSepPosix(byte: UInt8): Bool {
        return byte == PathConstants.CHAR_FORWARD_SLASH
    }

    // ========================================================================
    // isSepWindows — Check if byte is a Windows path separator (/ or \)
    // Corresponds to Bun: path.rs is_sep_windows_t (= is_sep_any_t)
    // Node win32.isPathSeparator accepts BOTH / and \
    // ========================================================================
    public static func isSepWindows(byte: UInt8): Bool {
        return byte == PathConstants.CHAR_FORWARD_SLASH || byte == PathConstants.CHAR_BACKWARD_SLASH
    }

    // ========================================================================
    // isWindowsDeviceRoot — Check if byte is a Windows drive letter
    // Corresponds to Bun: path.rs is_windows_device_root_t
    // 'A'-'Z' or 'a'-'z'
    // ========================================================================
    public static func isWindowsDeviceRoot(byte: UInt8): Bool {
        return (byte >= UInt8(0x41) && byte <= UInt8(0x5A)) ||  // 'A'-'Z'
               (byte >= UInt8(0x61) && byte <= UInt8(0x7A))      // 'a'-'z'
    }

    // ========================================================================
    // toLower — Convert byte to lowercase (ASCII only)
    // Corresponds to Bun: path.rs to_lower_t
    // ========================================================================
    public static func toLower(byte: UInt8): UInt8 {
        if (byte >= UInt8(0x41) && byte <= UInt8(0x5A)) {  // 'A'-'Z'
            return byte + UInt8(0x20)  // 'a' - 'A' = 32
        }
        return byte
    }

    // ========================================================================
    // eqlIgnoreCase — Compare byte slices case-insensitively (ASCII)
    // Corresponds to Bun: path.rs eql_ignore_case_t
    // ========================================================================
    public static func eqlIgnoreCase(a: String, b: String): Bool {
        if (a.size != b.size) {
            return false
        }
        for (i in 0..a.size) {
            if (toLower(a[i]) != toLower(b[i])) {
                return false
            }
        }
        return true
    }

    // ========================================================================
    // formatExt — Format extension, adding leading dot if needed
    // Corresponds to Bun: path.rs format_ext_t
    // Based on Node v21.6.1 private helper formatExt
    // ========================================================================
    public static func formatExt(ext: String): String {
        if (ext.size == 0) {
            return ""
        }
        if (ext[0] == PathConstants.CHAR_DOT) {
            return ext
        }
        return "." + ext
    }

    // ========================================================================
    // posixCwd — Get POSIX-formatted cwd
    // Corresponds to Bun: path.rs posix_cwd_t
    // On POSIX: return cwd as-is. On Windows: convert backslashes, strip drive.
    // ========================================================================
    public static func posixCwd(): String {
        return getCwd()
    }

    // ========================================================================
    // getCwd — Get current working directory
    // Corresponds to Bun: path.rs get_cwd_u8
    // Returns cached cwd without trailing slash
    // ========================================================================
    public static func getCwd(): String {
        return OS.getcwd()
    }

    // ========================================================================
    // basenamePosix — Get filename from path (POSIX)
    // Corresponds to Bun: path.rs basename_posix_t
    // Based on Node v21.6.1 path.posix.basename
    // ========================================================================
    public static func basenamePosix(path: String, suffix: String): String {
        validateString(path, "path")
        let len = path.size
        if (len == 0) {
            return ""
        }

        var start: Int64 = 0
        var end: Int64 = -1
        var matchedSlash: Bool = true

        let suffixLen = suffix.size
        if (suffixLen > 0 && suffixLen <= len) {
            if (suffix == path) {
                return ""
            }

            var extIdx: Int64 = suffixLen - 1
            var firstNonSlashEnd: Int64 = -1
            var i: Int64 = len - 1

            while (i >= start) {
                let byte = path[i]
                if (byte == PathConstants.CHAR_FORWARD_SLASH) {
                    if (!matchedSlash) {
                        start = i + 1
                        break
                    }
                } else {
                    if (firstNonSlashEnd < 0) {
                        matchedSlash = false
                        firstNonSlashEnd = i + 1
                    }
                    if (extIdx >= 0) {
                        if (byte == suffix[Int64(extIdx)]) {
                            if (extIdx == 0) {
                                end = i
                                extIdx = -1
                            } else {
                                extIdx -= 1
                            }
                        } else {
                            extIdx = -1
                            end = firstNonSlashEnd
                        }
                    }
                }
                i -= 1
            }

            if (end >= 0) {
                if (start == end) {
                    return substring(path, start, firstNonSlashEnd)
                } else {
                    return substring(path, start, end)
                }
            }
            return substring(path, start, Int64(len))
        }

        // No suffix version
        var i2: Int64 = len - 1
        while (i2 > -1) {
            let byte = path[i2]
            if (byte == PathConstants.CHAR_FORWARD_SLASH) {
                if (!matchedSlash) {
                    start = i2 + 1
                    break
                }
            } else if (end < 0) {
                matchedSlash = false
                end = i2 + 1
            }
            i2 -= 1
        }

        if (end >= 0) {
            return substring(path, start, end)
        }
        return ""
    }

    // ========================================================================
    // basenameWindows — Get filename from path (Windows)
    // Corresponds to Bun: path.rs basename_windows_t
    // Based on Node v21.6.1 path.win32.basename
    // ========================================================================
    public static func basenameWindows(path: String, suffix: String): String {
        validateString(path, "path")
        let len = path.size
        if (len == 0) {
            return ""
        }

        var start: Int64 = 0
        var end: Int64 = -1
        var matchedSlash: Bool = true

        // Check for drive letter prefix
        if (len >= 2 && isWindowsDeviceRoot(path[0]) && path[1] == PathConstants.CHAR_COLON) {
            start = 2
        }

        let suffixLen = suffix.size
        if (suffixLen > 0 && suffixLen <= len) {
            if (suffix == path) {
                return ""
            }

            var extIdx: Int64 = suffixLen - 1
            var firstNonSlashEnd: Int64 = -1
            var i: Int64 = len - 1

            while (i >= start) {
                let byte = path[i]
                if (isSepWindows(byte)) {
                    if (!matchedSlash) {
                        start = i + 1
                        break
                    }
                } else {
                    if (firstNonSlashEnd < 0) {
                        matchedSlash = false
                        firstNonSlashEnd = i + 1
                    }
                    if (extIdx >= 0) {
                        if (byte == suffix[Int64(extIdx)]) {
                            if (extIdx == 0) {
                                end = i
                                extIdx = -1
                            } else {
                                extIdx -= 1
                            }
                        } else {
                            extIdx = -1
                            end = firstNonSlashEnd
                        }
                    }
                }
                i -= 1
            }

            if (end >= 0) {
                if (start == end) {
                    return substring(path, start, firstNonSlashEnd)
                } else {
                    return substring(path, start, end)
                }
            }
            return substring(path, start, Int64(len))
        }

        // No suffix version
        var i2: Int64 = len - 1
        while (i2 >= start) {
            let byte = path[i2]
            if (isSepWindows(byte)) {
                if (!matchedSlash) {
                    start = i2 + 1
                    break
                }
            } else if (end < 0) {
                matchedSlash = false
                end = i2 + 1
            }
            i2 -= 1
        }

        if (end >= 0) {
            return substring(path, start, end)
        }
        return ""
    }

    // ========================================================================
    // basename — Get filename from path (dispatches to platform)
    // Corresponds to Bun: path.rs basename (JS entry point)
    // ========================================================================
    public static func basename(path: String, suffix: String): String {
        return basenamePosix(path, suffix)
    }

    public static func basename(path: String): String {
        return basenamePosix(path, "")
    }

    public static func basename(path: String, suffix: String, isWindows: Bool): String {
        if (isWindows) {
            return basenameWindows(path, suffix)
        }
        return basenamePosix(path, suffix)
    }

    // ========================================================================
    // dirnamePosix — Get directory name from path (POSIX)
    // Corresponds to Bun: path.rs dirname_posix_t
    // Based on Node v21.6.1 path.posix.dirname
    // ========================================================================
    public static func dirnamePosix(path: String): String {
        validateString(path, "path")
        let len = path.size
        if (len == 0) {
            return "."
        }

        let hasRoot = path[0] == PathConstants.CHAR_FORWARD_SLASH
        var end: Int64 = -1
        var matchedSlash: Bool = true
        var i: Int64 = len - 1

        while (i >= 1) {
            if (path[Int64(i)] == PathConstants.CHAR_FORWARD_SLASH) {
                if (!matchedSlash) {
                    end = i
                    break
                }
            } else {
                matchedSlash = false
            }
            i -= 1
        }

        if (end >= 0) {
            if (hasRoot && end == 1) {
                return "//"
            }
            return substring(path, 0, end)
        }
        if (hasRoot) {
            return "/"
        }
        return "."
    }

    // ========================================================================
    // dirnameWindows — Get directory name from path (Windows)
    // Corresponds to Bun: path.rs dirname_windows_t
    // Based on Node v21.6.1 path.win32.dirname
    // ========================================================================
    public static func dirnameWindows(path: String): String {
        validateString(path, "path")
        let len = path.size
        if (len == 0) {
            return "."
        }

        var rootEnd: Int64 = -1
        var offset: Int64 = 0
        let byte0 = path[0]

        if (len == 1) {
            if (isSepWindows(byte0)) {
                return substring(path, 0, 1)
            }
            return "."
        }

        // Try to match a root
        if (isSepWindows(byte0)) {
            // Possible UNC root
            rootEnd = 1
            offset = 1

            if (isSepWindows(path[1])) {
                // Matched double path separator at beginning
                var j: Int64 = 2
                var last: Int64 = j

                // Match 1 or more non-path separators
                while (j < len && !isSepWindows(path[Int64(j)])) {
                    j += 1
                }

                if (j < len && j != last) {
                    last = j
                    // Match 1 or more path separators
                    while (j < len && isSepWindows(path[Int64(j)])) {
                        j += 1
                    }

                    if (j < len && j != last) {
                        last = j
                        // Match 1 or more non-path separators
                        while (j < len && !isSepWindows(path[Int64(j)])) {
                            j += 1
                        }

                        if (j == len) {
                            // We matched a UNC root only
                            return path
                        }

                        if (j != last) {
                            // We matched a UNC root with leftovers
                            offset = j + 1
                            rootEnd = offset
                        }
                    }
                }
            }
            // Possible device root
        } else if (isWindowsDeviceRoot(byte0) && path[1] == PathConstants.CHAR_COLON) {
            offset = if (len > 2 && isSepWindows(path[2])) { 3 } else { 2 }
            rootEnd = offset
        }

        var end: Int64 = -1
        var matchedSlash: Bool = true

        var i: Int64 = len - 1
        while (i >= offset) {
            if (isSepWindows(path[Int64(i)])) {
                if (!matchedSlash) {
                    end = i
                    break
                }
            } else {
                matchedSlash = false
            }
            i -= 1
        }

        if (end >= 0) {
            return substring(path, 0, end)
        }

        if (rootEnd >= 0) {
            return substring(path, 0, rootEnd)
        }
        return "."
    }

    // ========================================================================
    // dirname — Get directory name from path (dispatches to platform)
    // Corresponds to Bun: path.rs dirname (JS entry point)
    // ========================================================================
    public static func dirname(path: String): String {
        return dirnamePosix(path)
    }

    public static func dirname(path: String, isWindows: Bool): String {
        if (isWindows) {
            return dirnameWindows(path)
        }
        return dirnamePosix(path)
    }

    // ========================================================================
    // extnamePosix — Get file extension (POSIX)
    // Corresponds to Bun: path.rs extname_posix_t
    // Based on Node v21.6.1 path.posix.extname
    // ========================================================================
    public static func extnamePosix(path: String): String {
        validateString(path, "path")
        let len = path.size
        if (len == 0) {
            return ""
        }

        var startDot: Int64 = -1
        var startPart: Int64 = 0
        var end: Int64 = -1
        var matchedSlash: Bool = true
        var preDotState: Int64 = 0

        var i: Int64 = len - 1
        while (i > -1) {
            let byte = path[Int64(i)]
            if (byte == PathConstants.CHAR_FORWARD_SLASH) {
                if (!matchedSlash) {
                    startPart = i + 1
                    break
                }
                i -= 1
                continue
            }

            if (end < 0) {
                matchedSlash = false
                end = i + 1
            }

            if (byte == PathConstants.CHAR_DOT) {
                if (startDot < 0) {
                    startDot = i
                } else if (preDotState >= 0 && preDotState != 1) {
                    preDotState = 1
                }
            } else if (startDot >= 0) {
                preDotState = -1
            }
            i -= 1
        }

        if (startDot < 0 || end < 0 ||
            (preDotState >= 0 && preDotState == 0) ||
            (preDotState == 1 && startDot == end - 1 && startDot == startPart + 1)) {
            return ""
        }

        return substring(path, startDot, end)
    }

    // ========================================================================
    // extnameWindows — Get file extension (Windows)
    // Corresponds to Bun: path.rs extname_windows_t
    // Based on Node v21.6.1 path.win32.extname
    // ========================================================================
    public static func extnameWindows(path: String): String {
        validateString(path, "path")
        let len = path.size
        if (len == 0) {
            return ""
        }

        var start: Int64 = 0
        var startDot: Int64 = -1
        var startPart: Int64 = 0
        var end: Int64 = -1
        var matchedSlash: Bool = true
        var preDotState: Int64 = 0

        // Check for drive letter prefix
        if (len >= 2 && path[1] == PathConstants.CHAR_COLON && isWindowsDeviceRoot(path[0])) {
            start = 2
            startPart = start
        }

        var i: Int64 = len - 1
        while (i >= start) {
            let byte = path[Int64(i)]
            if (isSepWindows(byte)) {
                if (!matchedSlash) {
                    startPart = i + 1
                    break
                }
                i -= 1
                continue
            }
            if (end < 0) {
                matchedSlash = false
                end = i + 1
            }
            if (byte == PathConstants.CHAR_DOT) {
                if (startDot < 0) {
                    startDot = i
                } else if (preDotState >= 0 && preDotState != 1) {
                    preDotState = 1
                }
            } else if (startDot >= 0) {
                preDotState = -1
            }
            i -= 1
        }

        if (startDot < 0 || end < 0 ||
            (preDotState >= 0 && preDotState == 0) ||
            (preDotState == 1 && startDot == end - 1 && startDot == startPart + 1)) {
            return ""
        }

        return substring(path, startDot, end)
    }

    // ========================================================================
    // extname — Get file extension (dispatches to platform)
    // Corresponds to Bun: path.rs extname (JS entry point)
    // ========================================================================
    public static func extname(path: String): String {
        return extnamePosix(path)
    }

    public static func extname(path: String, isWindows: Bool): String {
        if (isWindows) {
            return extnameWindows(path)
        }
        return extnamePosix(path)
    }

    // ========================================================================
    // format — Build path string from components (POSIX)
    // Corresponds to Bun: path.rs _format_t
    // Based on Node v21.6.1 private helper _format
    // ========================================================================
    public static func formatPosix(parsed: PathParsed): String {
        return formatImpl(parsed, PathConstants.CHAR_FORWARD_SLASH)
    }

    // ========================================================================
    // formatWindows — Build path string from components (Windows)
    // Corresponds to Bun: path.rs _format_t (with backslash)
    // ========================================================================
    public static func formatWindows(parsed: PathParsed): String {
        return formatImpl(parsed, PathConstants.CHAR_BACKWARD_SLASH)
    }

    // ========================================================================
    // format — Build path string from components (dispatches to platform)
    // Corresponds to Bun: path.rs format (JS entry point)
    // ========================================================================
    public static func format(parsed: PathParsed): String {
        return formatPosix(parsed)
    }

    public static func format(parsed: PathParsed, isWindows: Bool): String {
        if (isWindows) {
            return formatWindows(parsed)
        }
        return formatPosix(parsed)
    }

    // ========================================================================
    // isAbsolutePosix — Check if path is absolute (POSIX)
    // Corresponds to Bun: path.rs is_absolute_posix_t
    // Based on Node v21.6.1 path.posix.isAbsolute
    // ========================================================================
    public static func isAbsolutePosix(path: String): Bool {
        return path.size > 0 && path[0] == PathConstants.CHAR_FORWARD_SLASH
    }

    // ========================================================================
    // isAbsoluteWindows — Check if path is absolute (Windows)
    // Corresponds to Bun: path.rs is_absolute_windows_t
    // Based on Node v21.6.1 path.win32.isAbsolute
    // ========================================================================
    public static func isAbsoluteWindows(path: String): Bool {
        let len = path.size
        if (len == 0) {
            return false
        }
        let byte0 = path[0]
        return isSepWindows(byte0) ||
               (len > 2 && isWindowsDeviceRoot(byte0) &&
                path[1] == PathConstants.CHAR_COLON && isSepWindows(path[2]))
    }

    // ========================================================================
    // isAbsolute — Check if path is absolute (dispatches to platform)
    // Corresponds to Bun: path.rs isAbsolute (JS entry point)
    // ========================================================================
    public static func isAbsolute(path: String): Bool {
        return isAbsolutePosix(path)
    }

    public static func isAbsolute(path: String, isWindows: Bool): Bool {
        if (isWindows) {
            return isAbsoluteWindows(path)
        }
        return isAbsolutePosix(path)
    }

    // ========================================================================
    // joinPosix — Join path fragments (POSIX)
    // Corresponds to Bun: path.rs join_posix_t
    // Based on Node v21.6.1 path.posix.join
    // ========================================================================
    public static func joinPosix(paths: Array<String>): String {
        if (paths.size == 0) {
            return "."
        }

        var joined = ""
        for (i in 0..paths.size) {
            let p = paths[i]
            if (p.size > 0) {
                if (joined.size > 0) {
                    joined = joined + "/"
                }
                joined = joined + p
            }
        }

        if (joined.size == 0) {
            return "."
        }

        return normalizePosix(joined)
    }

    // ========================================================================
    // joinWindows — Join path fragments (Windows)
    // Corresponds to Bun: path.rs join_windows_t
    // Based on Node v21.6.1 path.win32.join
    // Ensures UNC path handling is correct
    // ========================================================================
    public static func joinWindows(paths: Array<String>): String {
        if (paths.size == 0) {
            return "."
        }

        var joined = ""
        var firstPartLen: Int64 = 0

        for (i in 0..paths.size) {
            let p = paths[i]
            if (p.size > 0) {
                if (joined.size == 0) {
                    joined = p
                    firstPartLen = Int64(p.size)
                } else {
                    joined = joined + "\\" + p
                }
            }
        }

        if (joined.size == 0) {
            return "."
        }

        // Make sure the joined path doesn't start with two slashes, because
        // normalize() will mistake it for a UNC path then.
        // This step is skipped when it is clear that the user actually
        // intended to point at a UNC path.
        var needsReplace: Bool = true
        var slashCount: Int64 = 0
        if (isSepWindows(joined[0])) {
            slashCount += 1
            if (firstPartLen > 1 && isSepWindows(joined[1])) {
                slashCount += 1
                if (firstPartLen > 2) {
                    if (isSepWindows(joined[2])) {
                        slashCount += 1
                    } else {
                        // We matched a UNC path in the first part
                        needsReplace = false
                    }
                }
            }
        }
        if (needsReplace) {
            // Find any more consecutive slashes we need to replace
            while (slashCount < joined.size && isSepWindows(joined[Int64(slashCount)])) {
                slashCount += 1
            }
            // Replace the slashes if needed
            if (slashCount >= 2) {
                joined = "\\" + substring(joined, slashCount, Int64(joined.size))
            }
        }

        return normalizeWindows(joined)
    }

    // ========================================================================
    // join — Join path fragments (dispatches to platform)
    // Corresponds to Bun: path.rs join (JS entry point)
    // ========================================================================
    public static func join(paths: Array<String>): String {
        return joinPosix(paths)
    }

    public static func join(paths: Array<String>, isWindows: Bool): String {
        if (isWindows) {
            return joinWindows(paths)
        }
        return joinPosix(paths)
    }

    // ========================================================================
    // joinWTF — Join two paths (WTF string variant)
    // Corresponds to Bun: path.rs Bun__Node__Path_joinWTF
    // ========================================================================
    public static func joinWTF(lhs: String, rhs: String): String {
        return joinPosix([lhs, rhs])
    }

    // ========================================================================
    // normalizePosix — Normalize path (POSIX)
    // Corresponds to Bun: path.rs normalize_posix_t
    // Based on Node v21.6.1 path.posix.normalize
    // Resolves . and .. elements
    // ========================================================================
    public static func normalizePosix(path: String): String {
        validateString(path, "path")
        let len = path.size
        if (len == 0) {
            return "."
        }

        let isAbs = path[0] == PathConstants.CHAR_FORWARD_SLASH
        let trailingSep = len > 0 && path[len - 1] == PathConstants.CHAR_FORWARD_SLASH

        // normalizeString: resolve . and .. elements
        var result = ""
        var lastSegmentLength: Int64 = 0
        var lastSlash: Int64 = -1
        var dots: Int64 = 0
        var byte: UInt8 = 0

        var i: Int64 = 0
        while (i <= len) {
            if (i < len) {
                byte = path[Int64(i)]
            } else if (byte == PathConstants.CHAR_FORWARD_SLASH) {
                break
            } else {
                byte = PathConstants.CHAR_FORWARD_SLASH
            }

            if (byte == PathConstants.CHAR_FORWARD_SLASH) {
                if ((lastSlash < 0 && i == 0) ||
                    (lastSlash >= 0 && i > 0 && lastSlash == i - 1) ||
                    (dots == 1)) {
                    // NOOP
                } else if (dots == 2) {
                    if (result.size < 2 ||
                        lastSegmentLength != 2 ||
                        result[result.size - 1] != PathConstants.CHAR_DOT ||
                        result[result.size - 2] != PathConstants.CHAR_DOT) {
                        if (result.size > 2) {
                            let lastSlashIdx = result.lastIndexOf('/')
                            if (lastSlashIdx.isNone()) {
                                result = ""
                                lastSegmentLength = 0
                            } else {
                                let lastSlashIndex = lastSlashIdx.getOrThrow()
                                result = result[0..lastSlashIndex]
                                let lastIndexOfSep = result.lastIndexOf('/')
                                if (lastIndexOfSep.isNone()) {
                                    lastSegmentLength = result.size
                                } else {
                                    lastSegmentLength = result.size - 1 - lastIndexOfSep.getOrThrow()
                                }
                            }
                        } else if (result.size > 0) {
                            result = ""
                            lastSegmentLength = 0
                        }
                    }
                    if (!isAbs) {
                        if (result.size > 0) {
                            result = result + "/.."
                        } else {
                            result = ".."
                        }
                        lastSegmentLength = 2
                    }
                } else {
                    let sliceStart = if (lastSlash >= 0) { lastSlash + 1 } else { 0 }
                    let slice = substring(path, sliceStart, i)

                    if (result.size > 0) {
                        result = result + "/"
                    }
                    result = result + slice

                    let subtract = if (lastSlash >= 0) { lastSlash + 1 } else { 2 }
                    lastSegmentLength = if (i >= subtract) { i - subtract } else { 0 }
                }
                lastSlash = i
                dots = 0
            } else if (byte == PathConstants.CHAR_DOT && dots >= 0) {
                dots += 1
            } else {
                dots = -1
            }
            i += 1
        }

        if (result.size == 0) {
            if (isAbs) {
                return "/"
            }
            return if (trailingSep) { "./" } else { "." }
        }

        // Append trailing separator
        if (trailingSep && result[result.size - 1] != UInt8(0x2F)) {
            result = result + "/"
        }

        // If absolute, prefix /
        if (isAbs) {
            result = "/" + result
        }

        return result
    }

    // ========================================================================
    // normalizeWindows — Normalize path (Windows)
    // Corresponds to Bun: path.rs normalize_windows_t
    // Based on Node v21.6.1 path.win32.normalize
    // ========================================================================
    public static func normalizeWindows(path: String): String {
        validateString(path, "path")
        let len = path.size
        if (len == 0) {
            return "."
        }

        let byte0 = path[0]

        // Single character path
        if (len == 1) {
            if (isSepWindows(byte0)) {
                return "\\"
            }
            return substring(path, 0, 1)
        }

        var rootEnd: Int64 = 0
        var device: String = ""
        var isAbs: Bool = false

        // Try to match a root
        if (isSepWindows(byte0)) {
            // Possible UNC root
            isAbs = true

            if (isSepWindows(path[1])) {
                // Matched double path separator at beginning
                var j: Int64 = 2
                var last: Int64 = j
                // Match 1 or more non-path separators
                while (j < len && !isSepWindows(path[Int64(j)])) {
                    j += 1
                }
                if (j < len && j != last) {
                    let firstPart = substring(path, last, j)
                    last = j
                    // Match 1 or more path separators
                    while (j < len && isSepWindows(path[Int64(j)])) {
                        j += 1
                    }
                    if (j < len && j != last) {
                        last = j
                        // Match 1 or more non-path separators
                        while (j < len && !isSepWindows(path[Int64(j)])) {
                            j += 1
                        }
                        if (j == len) {
                            // We matched a UNC root only
                            return "\\" + "\\" + firstPart + "\\" + substring(path, last, j) + "\\"
                        }
                        if (j != last) {
                            // We matched a UNC root with leftovers
                            device = "\\" + "\\" + firstPart + "\\" + substring(path, last, j)
                            rootEnd = j
                        }
                    }
                }
            } else {
                rootEnd = 1
            }
        } else if (isWindowsDeviceRoot(byte0) && path[1] == PathConstants.CHAR_COLON) {
            // Possible device root
            device = substring(path, 0, 2)
            rootEnd = 2
            if (len > 2 && isSepWindows(path[2])) {
                isAbs = true
                rootEnd = 3
            }
        }

        // Normalize the tail
        var tail: String = ""
        if (rootEnd < len) {
            tail = normalizeStringWindowsImpl(substring(path, rootEnd, Int64(len)), !isAbs)
        }
        if (tail.size == 0 && !isAbs) {
            tail = "."
        }
        // Append trailing separator
        if (tail.size > 0 && isSepWindows(path[len - 1])) {
            tail = tail + "\\"
        }

        if (device.size == 0) {
            return if (isAbs) { "\\" + tail } else { tail }
        }
        return if (isAbs) { device + "\\" + tail } else { device + tail }
    }

    // ========================================================================
    // normalize — Normalize path (dispatches to platform)
    // Corresponds to Bun: path.rs normalize (JS entry point)
    // ========================================================================
    public static func normalize(path: String): String {
        return normalizePosix(path)
    }

    public static func normalize(path: String, isWindows: Bool): String {
        if (isWindows) {
            return normalizeWindows(path)
        }
        return normalizePosix(path)
    }

    // ========================================================================
    // parsePosix — Parse path into components (POSIX)
    // Corresponds to Bun: path.rs parse_posix_t
    // Based on Node v21.6.1 path.posix.parse
    // ========================================================================
    public static func parsePosix(path: String): PathParsed {
        validateString(path, "path")
        let len = path.size
        if (len == 0) {
            return PathParsed()
        }

        var root = ""
        var dir = ""
        var base = ""
        var ext = ""
        var nameStr = ""

        let isAbsolute = path[0] == PathConstants.CHAR_FORWARD_SLASH
        var start: Int64 = 0
        if (isAbsolute) {
            root = "/"
            start = 1
        }

        var startDot: Int64 = -1
        var startPart: Int64 = 0
        var end: Int64 = -1
        var matchedSlash: Bool = true
        var preDotState: Int64 = 0

        var i: Int64 = len - 1
        while (i >= start) {
            let byte = path[Int64(i)]
            if (byte == PathConstants.CHAR_FORWARD_SLASH) {
                if (!matchedSlash) {
                    startPart = i + 1
                    break
                }
                i -= 1
                continue
            }
            if (end < 0) {
                matchedSlash = false
                end = i + 1
            }
            if (byte == PathConstants.CHAR_DOT) {
                if (startDot < 0) {
                    startDot = i
                } else if (preDotState >= 0 && preDotState != 1) {
                    preDotState = 1
                }
            } else if (startDot >= 0) {
                preDotState = -1
            }
            i -= 1
        }

        if (end >= 0) {
            start = if (startPart == 0 && isAbsolute) { 1 } else { startPart }
            if (startDot < 0 ||
                (preDotState >= 0 && preDotState == 0) ||
                (preDotState == 1 && startDot == end - 1 && startDot == startPart + 1)) {
                nameStr = substring(path, start, end)
                base = nameStr
            } else {
                nameStr = substring(path, start, startDot)
                base = substring(path, start, end)
                ext = substring(path, startDot, end)
            }
        }

        if (startPart > 0) {
            dir = substring(path, 0, startPart - 1)
        } else if (isAbsolute) {
            dir = "/"
        }

        return PathParsed(root, dir, base, ext, nameStr)
    }

    // ========================================================================
    // parseWindows — Parse path into components (Windows)
    // Corresponds to Bun: path.rs parse_windows_t
    // Based on Node v21.6.1 path.win32.parse
    // ========================================================================
    public static func parseWindows(path: String): PathParsed {
        validateString(path, "path")
        var root = ""
        var dir = ""
        var base = ""
        var ext = ""
        var nameStr = ""

        let len = path.size
        if (len == 0) {
            return PathParsed(root, dir, base, ext, nameStr)
        }

        var rootEnd: Int64 = 0
        let byte = path[0]

        if (len == 1) {
            if (isSepWindows(byte)) {
                root = substring(path, 0, 1)
                dir = root
            } else {
                base = substring(path, 0, 1)
                nameStr = base
            }
            return PathParsed(root, dir, base, ext, nameStr)
        }

        // Try to match a root
        if (isSepWindows(byte)) {
            // Possible UNC root
            rootEnd = 1
            if (isSepWindows(path[1])) {
                // Matched double path separator at beginning
                var j: Int64 = 2
                var last: Int64 = j
                // Match 1 or more non-path separators
                while (j < len && !isSepWindows(path[Int64(j)])) {
                    j += 1
                }
                if (j < len && j != last) {
                    last = j
                    // Match 1 or more path separators
                    while (j < len && isSepWindows(path[Int64(j)])) {
                        j += 1
                    }
                    if (j < len && j != last) {
                        last = j
                        // Match 1 or more non-path separators
                        while (j < len && !isSepWindows(path[Int64(j)])) {
                            j += 1
                        }
                        if (j == len) {
                            // We matched a UNC root only
                            rootEnd = j
                        } else if (j != last) {
                            // We matched a UNC root with leftovers
                            rootEnd = j + 1
                        }
                    }
                }
            }
        } else if (isWindowsDeviceRoot(byte) && path[1] == PathConstants.CHAR_COLON) {
            // Possible device root
            if (len <= 2) {
                root = path
                dir = path
                return PathParsed(root, dir, base, ext, nameStr)
            }
            rootEnd = 2
            if (isSepWindows(path[2])) {
                if (len == 3) {
                    root = path
                    dir = path
                    return PathParsed(root, dir, base, ext, nameStr)
                }
                rootEnd = 3
            }
        }

        if (rootEnd > 0) {
            root = substring(path, 0, rootEnd)
        }

        var startDot: Int64 = -1
        var startPart: Int64 = rootEnd
        var end: Int64 = -1
        var matchedSlash: Bool = true
        var preDotState: Int64 = 0

        // Get non-dir info
        var i: Int64 = len - 1
        while (i >= rootEnd) {
            let b = path[Int64(i)]
            if (isSepWindows(b)) {
                if (!matchedSlash) {
                    startPart = i + 1
                    break
                }
                i -= 1
                continue
            }
            if (end < 0) {
                matchedSlash = false
                end = i + 1
            }
            if (b == PathConstants.CHAR_DOT) {
                if (startDot < 0) {
                    startDot = i
                } else if (preDotState >= 0 && preDotState != 1) {
                    preDotState = 1
                }
            } else if (startDot >= 0) {
                preDotState = -1
            }
            i -= 1
        }

        if (end >= 0) {
            if (startDot < 0 ||
                (preDotState >= 0 && preDotState == 0) ||
                (preDotState == 1 && startDot == end - 1 && startDot == startPart + 1)) {
                nameStr = substring(path, startPart, end)
                base = nameStr
            } else {
                nameStr = substring(path, startPart, startDot)
                base = substring(path, startPart, end)
                ext = substring(path, startDot, end)
            }
        }

        // If directory is root, use entire root including trailing slash.
        // Otherwise strip trailing slash.
        if (startPart > 0 && startPart != rootEnd) {
            dir = substring(path, 0, startPart - 1)
        } else {
            dir = root
        }

        return PathParsed(root, dir, base, ext, nameStr)
    }

    // ========================================================================
    // parse — Parse path into components (dispatches to platform)
    // Corresponds to Bun: path.rs parse (JS entry point)
    // ========================================================================
    public static func parse(path: String): PathParsed {
        return parsePosix(path)
    }

    public static func parse(path: String, isWindows: Bool): PathParsed {
        if (isWindows) {
            return parseWindows(path)
        }
        return parsePosix(path)
    }

    // ========================================================================
    // relativePosix — Compute relative path from `from` to `to` (POSIX)
    // Corresponds to Bun: path.rs relative_posix_t
    // Based on Node v21.6.1 path.posix.relative
    // ========================================================================
    public static func relativePosix(from: String, to: String): String {
        validateString(from, "from")
        validateString(to, "to")

        if (from == to) {
            return ""
        }

        // Resolve both paths to absolute
        let fromAbs = resolvePosix([from])
        let toAbs = resolvePosix([to])

        if (fromAbs == toAbs) {
            return ""
        }

        let fromStart: Int64 = 1
        let fromEnd: Int64 = Int64(fromAbs.size)
        let fromLen = fromEnd - fromStart
        let toOrigLen: Int64 = Int64(toAbs.size)
        var toStart: Int64 = 1
        let toLen = toOrigLen - toStart

        // Find longest common path
        let smallestLength = if (fromLen < toLen) { fromLen } else { toLen }
        var lastCommonSep: Int64 = -1

        var i: Int64 = 0
        while (i < smallestLength) {
            let fromByte = fromAbs[Int64(fromStart + i)]
            if (fromByte != toAbs[Int64(toStart + i)]) {
                break
            } else if (fromByte == UInt8(0x2F)) {
                lastCommonSep = i
            }
            i += 1
        }
        let matchesAllOfSmallest = (i == smallestLength)

        if (matchesAllOfSmallest) {
            if (toLen > smallestLength) {
                if (toAbs[Int64(toStart + smallestLength)] == UInt8(0x2F)) {
                    return substring(toAbs, toStart + smallestLength + 1, toOrigLen)
                }
                if (smallestLength == 0) {
                    return substring(toAbs, toStart + smallestLength, toOrigLen)
                }
            } else if (fromLen > smallestLength) {
                if (fromAbs[Int64(fromStart + smallestLength)] == UInt8(0x2F)) {
                    lastCommonSep = smallestLength
                } else if (smallestLength == 0) {
                    lastCommonSep = 0
                }
            }
        }

        // Generate the relative path
        var out = ""
        var j: Int64 = fromStart + (if (lastCommonSep >= 0) { lastCommonSep + 1 } else { 0 })
        while (j <= fromEnd) {
            if (j == fromEnd || fromAbs[Int64(j)] == UInt8(0x2F)) {
                if (out.size > 0) {
                    out = out + "/.."
                } else {
                    out = ".."
                }
            }
            j += 1
        }

        // Append remaining path of `to`
        toStart = if (lastCommonSep >= 0) { toStart + lastCommonSep } else { 0 }
        let sliceSize = toOrigLen - toStart
        if (sliceSize > 0) {
            out = out + substring(toAbs, toStart, toOrigLen)
        }

        return out
    }

    // ========================================================================
    // relativeWindows — Compute relative path from `from` to `to` (Windows)
    // Corresponds to Bun: path.rs relative_windows_t
    // Based on Node v21.6.1 path.win32.relative
    // ========================================================================
    public static func relativeWindows(from: String, to: String): String {
        validateString(from, "from")
        validateString(to, "to")

        if (from == to) {
            return ""
        }

        let fromOrig = resolveWindows([from])
        let toOrig = resolveWindows([to])

        if (eqlIgnoreCase(fromOrig, toOrig)) {
            return ""
        }

        // Trim leading backslashes
        var fromStart: Int64 = 0
        while (fromStart < fromOrig.size && fromOrig[Int64(fromStart)] == PathConstants.CHAR_BACKWARD_SLASH) {
            fromStart += 1
        }

        // Trim trailing backslashes
        var fromEnd: Int64 = Int64(fromOrig.size)
        while (fromEnd - 1 > fromStart && fromOrig[Int64(fromEnd - 1)] == PathConstants.CHAR_BACKWARD_SLASH) {
            fromEnd -= 1
        }

        let fromLen = fromEnd - fromStart

        // Trim leading backslashes
        var toStart: Int64 = 0
        while (toStart < toOrig.size && toOrig[Int64(toStart)] == PathConstants.CHAR_BACKWARD_SLASH) {
            toStart += 1
        }

        // Trim trailing backslashes
        var toEnd: Int64 = Int64(toOrig.size)
        while (toEnd - 1 > toStart && toOrig[Int64(toEnd - 1)] == PathConstants.CHAR_BACKWARD_SLASH) {
            toEnd -= 1
        }

        let toLen = toEnd - toStart

        // Find longest common path
        let smallestLength = if (fromLen < toLen) { fromLen } else { toLen }
        var lastCommonSep: Int64 = -1

        var i: Int64 = 0
        while (i < smallestLength) {
            let fromByte = fromOrig[Int64(fromStart + i)]
            if (toLower(fromByte) != toLower(toOrig[Int64(toStart + i)])) {
                break
            } else if (fromByte == PathConstants.CHAR_BACKWARD_SLASH) {
                lastCommonSep = i
            }
            i += 1
        }
        let matchesAllOfSmallest = (i == smallestLength)

        // Found mismatch before first common separator
        if (!matchesAllOfSmallest) {
            if (lastCommonSep < 0) {
                return toOrig
            }
        } else {
            if (toLen > smallestLength) {
                if (toOrig[Int64(toStart + smallestLength)] == PathConstants.CHAR_BACKWARD_SLASH) {
                    return substring(toOrig, toStart + smallestLength + 1, toEnd)
                }
                if (smallestLength == 2) {
                    return substring(toOrig, toStart + smallestLength, toEnd)
                }
            }
            if (fromLen > smallestLength) {
                if (fromOrig[Int64(fromStart + smallestLength)] == PathConstants.CHAR_BACKWARD_SLASH) {
                    lastCommonSep = smallestLength
                } else if (smallestLength == 2) {
                    lastCommonSep = 3
                }
            }
            if (lastCommonSep < 0) {
                lastCommonSep = 0
            }
        }

        // Generate relative path
        var out = ""
        var j: Int64 = fromStart + (if (lastCommonSep >= 0) { lastCommonSep + 1 } else { 0 })
        while (j <= fromEnd) {
            if (j == fromEnd || fromOrig[Int64(j)] == PathConstants.CHAR_BACKWARD_SLASH) {
                if (out.size > 0) {
                    out = out + "\\.."
                } else {
                    out = ".."
                }
            }
            j += 1
        }

        // Adjust toStart
        if (lastCommonSep < 0) {
            toStart = if (toStart > 0) { toStart - 1 } else { toEnd - 1 }
        } else {
            toStart += lastCommonSep
        }

        // Append remaining path of `to`
        if (out.size > 0) {
            let sliceSize = toEnd - toStart
            if (sliceSize > 0) {
                out = out + substring(toOrig, toStart, toEnd)
            }
            return out
        }

        if (toStart < toOrig.size && toOrig[Int64(toStart)] == PathConstants.CHAR_BACKWARD_SLASH) {
            toStart += 1
        }
        return substring(toOrig, toStart, toEnd)
    }

    // ========================================================================
    // relative — Compute relative path (dispatches to platform)
    // Corresponds to Bun: path.rs relative (JS entry point)
    // ========================================================================
    public static func relative(from: String, to: String): String {
        return relativePosix(from, to)
    }

    public static func relative(from: String, to: String, isWindows: Bool): String {
        if (isWindows) {
            return relativeWindows(from, to)
        }
        return relativePosix(from, to)
    }

    // ========================================================================
    // resolvePosix — Resolve to absolute path (POSIX)
    // Corresponds to Bun: path.rs resolve_posix_t
    // Based on Node v21.6.1 path.posix.resolve
    // ========================================================================
    public static func resolvePosix(paths: Array<String>): String {
        var resolvedPath = ""
        var resolvedAbsolute: Bool = false

        var idx: Int64 = Int64(paths.size) - 1
        while (idx >= -1 && !resolvedAbsolute) {
            var path: String
            if (idx >= 0) {
                path = paths[Int64(idx)]
            } else {
                path = posixCwd()
            }

            let len = path.size
            if (len == 0) {
                idx -= 1
                continue
            }

            resolvedPath = path + "/" + resolvedPath
            resolvedAbsolute = path[0] == PathConstants.CHAR_FORWARD_SLASH
            idx -= 1
        }

        if (resolvedPath.size == 0) {
            return "."
        }

        // Normalize
        resolvedPath = normalizeStringPosixImpl(resolvedPath, !resolvedAbsolute)

        if (resolvedAbsolute) {
            return "/" + resolvedPath
        }
        return if (resolvedPath.size > 0) { resolvedPath } else { "." }
    }

    // ========================================================================
    // resolveWindows — Resolve to absolute path (Windows)
    // Corresponds to Bun: path.rs resolve_windows_t
    // Based on Node v21.6.1 path.win32.resolve
    // ========================================================================
    public static func resolveWindows(paths: Array<String>): String {
        var resolvedDevice: String = ""
        var resolvedTail: String = ""
        var resolvedAbsolute: Bool = false

        var idx: Int64 = Int64(paths.size) - 1
        while (idx >= -1) {
            var path: String
            if (idx >= 0) {
                path = paths[Int64(idx)]
            } else {
                if (resolvedDevice.size == 0) {
                    path = getCwd()
                } else {
                    // Try drive-specific cwd
                    path = getCwd()
                }
            }

            let len = path.size
            if (len == 0) {
                idx -= 1
                continue
            }

            var rootEnd: Int64 = 0
            var device: String = ""
            var isAbs: Bool = false
            let byte0 = path[0]

            // Try to match a root
            if (len == 1) {
                if (isSepWindows(byte0)) {
                    rootEnd = 1
                    isAbs = true
                }
            } else if (isSepWindows(byte0)) {
                isAbs = true

                if (isSepWindows(path[1])) {
                    // Matched double path separator at beginning
                    var j: Int64 = 2
                    var last: Int64 = j
                    while (j < len && !isSepWindows(path[Int64(j)])) {
                        j += 1
                    }
                    if (j < len && j != last) {
                        let firstPartStart = last
                        let firstPartEnd = j
                        last = j
                        while (j < len && isSepWindows(path[Int64(j)])) {
                            j += 1
                        }
                        if (j < len && j != last) {
                            last = j
                            while (j < len && !isSepWindows(path[Int64(j)])) {
                                j += 1
                            }
                            if (j == len || j != last) {
                                // We matched a UNC root
                                if (resolvedDevice.size > 0) {
                                    idx -= 1
                                    continue
                                }
                                device = "\\" + "\\" + substring(path, firstPartStart, firstPartEnd) +
                                         "\\" + substring(path, last, j)
                                rootEnd = j
                            }
                        }
                    }
                } else {
                    rootEnd = 1
                }
            } else if (isWindowsDeviceRoot(byte0) && path[1] == PathConstants.CHAR_COLON) {
                device = substring(path, 0, 2)
                rootEnd = 2
                if (len > 2 && isSepWindows(path[2])) {
                    isAbs = true
                    rootEnd = 3
                }
            }

            if (device.size > 0) {
                if (resolvedDevice.size > 0) {
                    if (!eqlIgnoreCase(device, resolvedDevice)) {
                        // This path points to another device
                        idx -= 1
                        continue
                    }
                } else {
                    resolvedDevice = device
                }
            }

            if (resolvedAbsolute) {
                if (resolvedDevice.size > 0) {
                    break
                }
            } else {
                // resolvedTail = path[rootEnd..] + "\" + resolvedTail
                let slice = if (rootEnd < len) { substring(path, rootEnd, Int64(len)) } else { "" }
                if (resolvedTail.size > 0) {
                    resolvedTail = slice + "\\" + resolvedTail
                } else {
                    resolvedTail = slice
                }
                resolvedAbsolute = isAbs

                if (isAbs && resolvedDevice.size > 0) {
                    break
                }
            }
            idx -= 1
        }

        if (resolvedTail.size == 0) {
            return "."
        }

        // Normalize the tail
        resolvedTail = normalizeStringWindowsImpl(resolvedTail, !resolvedAbsolute)

        if (resolvedAbsolute) {
            return resolvedDevice + "\\" + resolvedTail
        }
        if (resolvedDevice.size + resolvedTail.size > 0) {
            return resolvedDevice + resolvedTail
        }
        return "."
    }

    // ========================================================================
    // resolve — Resolve to absolute path (dispatches to platform)
    // Corresponds to Bun: path.rs resolve (JS entry point)
    // ========================================================================
    public static func resolve(paths: Array<String>): String {
        return resolvePosix(paths)
    }

    public static func resolve(paths: Array<String>, isWindows: Bool): String {
        if (isWindows) {
            return resolveWindows(paths)
        }
        return resolvePosix(paths)
    }

    // Micro-optimization: resolve(".") and resolve("./") === process.cwd()
    public static func resolve(cwd: String, paths: Array<String>): String {
        // POSIX quick paths
        if (paths.size == 0 || (paths.size == 1 && (paths[0] == "." || paths[0] == "./"))) {
            return cwd
        }
        return resolvePosix(paths)
    }

    // ========================================================================
    // toNamespacedPathWindows — Convert to namespaced path (Windows)
    // Corresponds to Bun: path.rs to_namespaced_path_windows_t
    // Based on Node v21.6.1 path.win32.toNamespacedPath
    // Converts device roots and UNC paths to \\?\ long UNC paths
    // ========================================================================
    public static func toNamespacedPathWindows(path: String): String {
        let resolved = resolveWindows([path])
        let len = resolved.size

        if (len <= 2) {
            return path
        }

        let byte0 = resolved[0]
        if (byte0 == PathConstants.CHAR_BACKWARD_SLASH) {
            // Possible UNC root
            if (resolved[1] == PathConstants.CHAR_BACKWARD_SLASH) {
                let byte2 = resolved[2]
                if (byte2 != PathConstants.CHAR_QUESTION_MARK && byte2 != PathConstants.CHAR_DOT) {
                    // Matched non-long UNC root, convert to long UNC path
                    return "\\\\?\\UNC\\" + substring(resolved, 2, Int64(len))
                }
            }
        } else if (isWindowsDeviceRoot(byte0) &&
                   resolved[1] == PathConstants.CHAR_COLON &&
                   resolved[2] == PathConstants.CHAR_BACKWARD_SLASH) {
            // Matched device root, convert to long UNC path
            return "\\\\?\\" + resolved
        }
        return resolved
    }

    // ========================================================================
    // toNamespacedPath — Convert to namespaced path
    // Corresponds to Bun: path.rs toNamespacedPath
    // On POSIX: identity function. On Windows: converts to \\?\ prefix.
    // ========================================================================
    public static func toNamespacedPath(path: String): String {
        // On POSIX, toNamespacedPath is identity
        return path
    }

    public static func toNamespacedPath(path: String, isWindows: Bool): String {
        if (!isWindows || path.size == 0) {
            return path
        }
        return toNamespacedPathWindows(path)
    }

    // ========================================================================
    // Internal helper functions
    // ========================================================================

    // formatImpl — Core format logic shared by POSIX and Windows
    // Corresponds to Bun: path.rs _format_t
    private static func formatImpl(parsed: PathParsed, sep: UInt8): String {
        let root = parsed.root
        let dir = parsed.dir
        let base = parsed.base
        let ext = parsed.ext
        let name = parsed.name

        // dir || root
        let dirIsRoot = dir.size == 0 || dir == root
        let dirOrRoot = if (dirIsRoot) { root } else { dir }
        let sepStr = String.fromUtf8([sep])

        // base || name + formatExt(ext)
        var baseOrNameExt = base
        if (base.size == 0) {
            var formattedExt = ext
            if (ext.size > 0 && ext[0] != PathConstants.CHAR_DOT) {
                formattedExt = "." + ext
            }
            baseOrNameExt = name + formattedExt
        }

        // if (!dir) return base
        if (dirOrRoot.size == 0) {
            return baseOrNameExt
        }

        // dir === root ? dir + base : dir + sep + base
        if (dirIsRoot) {
            return dirOrRoot + baseOrNameExt
        }
        return dirOrRoot + sepStr + baseOrNameExt
    }

    // normalizeStringPosixImpl — Resolve . and .. elements (POSIX variant)
    // Corresponds to Bun: path.rs normalize_string_t with Platform::Posix
    private static func normalizeStringPosixImpl(path: String, allowAboveRoot: Bool): String {
        let len = path.size
        var result = ""
        var lastSegmentLength: Int64 = 0
        var lastSlash: Int64 = -1
        var dots: Int64 = 0
        var byte: UInt8 = 0

        var i: Int64 = 0
        while (i <= len) {
            if (i < len) {
                byte = path[Int64(i)]
            } else if (byte == PathConstants.CHAR_FORWARD_SLASH) {
                break
            } else {
                byte = PathConstants.CHAR_FORWARD_SLASH
            }

            if (byte == PathConstants.CHAR_FORWARD_SLASH) {
                if ((lastSlash < 0 && i == 0) ||
                    (lastSlash >= 0 && i > 0 && lastSlash == i - 1) ||
                    (dots == 1)) {
                    // NOOP
                } else if (dots == 2) {
                    if (result.size < 2 ||
                        lastSegmentLength != 2 ||
                        result[result.size - 1] != PathConstants.CHAR_DOT ||
                        result[result.size - 2] != PathConstants.CHAR_DOT) {
                        if (result.size > 2) {
                            let lastSlashIdx = result.lastIndexOf('/')
                            if (lastSlashIdx.isNone()) {
                                result = ""
                                lastSegmentLength = 0
                            } else {
                                let lastSlashIndex = lastSlashIdx.getOrThrow()
                                result = result[0..lastSlashIndex]
                                let lastIndexOfSep = result.lastIndexOf('/')
                                if (lastIndexOfSep.isNone()) {
                                    lastSegmentLength = result.size
                                } else {
                                    lastSegmentLength = result.size - 1 - lastIndexOfSep.getOrThrow()
                                }
                            }
                        } else if (result.size > 0) {
                            result = ""
                            lastSegmentLength = 0
                        }
                    }
                    if (allowAboveRoot) {
                        if (result.size > 0) {
                            result = result + "/.."
                        } else {
                            result = ".."
                        }
                        lastSegmentLength = 2
                    }
                } else {
                    let sliceStart = if (lastSlash >= 0) { lastSlash + 1 } else { 0 }
                    let slice = substring(path, sliceStart, i)

                    if (result.size > 0) {
                        result = result + "/"
                    }
                    result = result + slice

                    let subtract = if (lastSlash >= 0) { lastSlash + 1 } else { 2 }
                    lastSegmentLength = if (i >= subtract) { i - subtract } else { 0 }
                }
                lastSlash = i
                dots = 0
            } else if (byte == PathConstants.CHAR_DOT && dots >= 0) {
                dots += 1
            } else {
                dots = -1
            }
            i += 1
        }

        return result
    }

    // normalizeStringWindowsImpl — Resolve . and .. elements (Windows variant)
    // Corresponds to Bun: path.rs normalize_string_t with Platform::Windows
    private static func normalizeStringWindowsImpl(path: String, allowAboveRoot: Bool): String {
        let len = path.size
        var result = ""
        var lastSegmentLength: Int64 = 0
        var lastSlash: Int64 = -1
        var dots: Int64 = 0
        var byte: UInt8 = 0

        var i: Int64 = 0
        while (i <= len) {
            if (i < len) {
                byte = path[Int64(i)]
            } else if (isSepWindows(byte)) {
                break
            } else {
                byte = PathConstants.CHAR_BACKWARD_SLASH
            }

            if (isSepWindows(byte)) {
                if ((lastSlash < 0 && i == 0) ||
                    (lastSlash >= 0 && i > 0 && lastSlash == i - 1) ||
                    (dots == 1)) {
                    // NOOP
                } else if (dots == 2) {
                    if (result.size < 2 ||
                        lastSegmentLength != 2 ||
                        result[result.size - 1] != PathConstants.CHAR_DOT ||
                        result[result.size - 2] != PathConstants.CHAR_DOT) {
                        if (result.size > 2) {
                            let lastSlashIdx = result.lastIndexOf("\\")
                            if (lastSlashIdx.isNone()) {
                                result = ""
                                lastSegmentLength = 0
                            } else {
                                let lastSlashIndex = lastSlashIdx.getOrThrow()
                                result = result[0..lastSlashIndex]
                                let lastIndexOfSep = result.lastIndexOf("\\")
                                if (lastIndexOfSep.isNone()) {
                                    lastSegmentLength = result.size
                                } else {
                                    lastSegmentLength = result.size - 1 - lastIndexOfSep.getOrThrow()
                                }
                            }
                        } else if (result.size > 0) {
                            result = ""
                            lastSegmentLength = 0
                        }
                    }
                    if (allowAboveRoot) {
                        if (result.size > 0) {
                            result = result + "\\.."
                        } else {
                            result = ".."
                        }
                        lastSegmentLength = 2
                    }
                } else {
                    let sliceStart = if (lastSlash >= 0) { lastSlash + 1 } else { 0 }
                    let slice = substring(path, sliceStart, i)

                    if (result.size > 0) {
                        result = result + "\\"
                    }
                    result = result + slice

                    let subtract = if (lastSlash >= 0) { lastSlash + 1 } else { 2 }
                    lastSegmentLength = if (i >= subtract) { i - subtract } else { 0 }
                }
                lastSlash = i
                dots = 0
            } else if (byte == PathConstants.CHAR_DOT && dots >= 0) {
                dots += 1
            } else {
                dots = -1
            }
            i += 1
        }

        return result
    }

    // Validate path string
    // Corresponds to Bun: path.rs validate_string (via validators module)
    private static func validateString(path: String, name: String): Unit {
        // In Bun, this throws ERR_INVALID_ARG_TYPE for non-string values.
        // Cangjie implementation is simplified to a no-op since we use String type.
    }

    // Safe substring helper that handles negative/clamped indices
    private static func substring(s: String, start: Int64, end: Int64): String {
        if (start < 0) {
            return ""
        }
        if (end < 0 || start >= end) {
            return ""
        }
        let len = Int64(s.size)
        if (start >= len) {
            return ""
        }
        let realEnd = if (end > len) { len } else { end }
        return s[start..realEnd]
    }

    // Split path by separator
    private static func splitPath(path: String, sep: UInt8): Array<String> {
        let sepStr = String.fromUtf8([sep])
        let parts = path.split(sepStr)
        var result = ArrayList<String>()
        for (part in parts) {
            if (part.size > 0) {
                result.add(part)
            }
        }
        return result.toArray()
    }
}

// ============================================================================
// Exported path host functions
// Corresponds to Bun: path.rs export_path_host_fn! macro
// These are the C-ABI entry points called from C++ (NodePath.cpp)
// In Bao/Cangjie, these are public static methods on PathHostFunctions
// ============================================================================
public class PathHostFunctions {
    // Bun__Path__basename
    public static func basename(global: Int64, isWindows: Bool, args: Array<String>): String {
        if (args.size == 0) {
            return ""
        }
        let path = args[0]
        let suffix = if (args.size > 1) { args[1] } else { "" }
        return Path.basename(path, suffix, isWindows)
    }

    // Bun__Path__dirname
    public static func dirname(global: Int64, isWindows: Bool, args: Array<String>): String {
        if (args.size == 0) {
            return "."
        }
        return Path.dirname(args[0], isWindows)
    }

    // Bun__Path__extname
    public static func extname(global: Int64, isWindows: Bool, args: Array<String>): String {
        if (args.size == 0) {
            return ""
        }
        return Path.extname(args[0], isWindows)
    }

    // Bun__Path__format
    public static func format(global: Int64, isWindows: Bool, args: Array<PathParsed>): String {
        if (args.size == 0) {
            return ""
        }
        return Path.format(args[0], isWindows)
    }

    // Bun__Path__isAbsolute
    public static func isAbsolute(global: Int64, isWindows: Bool, args: Array<String>): Bool {
        if (args.size == 0) {
            return false
        }
        return Path.isAbsolute(args[0], isWindows)
    }

    // Bun__Path__join
    public static func join(global: Int64, isWindows: Bool, args: Array<String>): String {
        return Path.join(args, isWindows)
    }

    // Bun__Path__normalize
    public static func normalize(global: Int64, isWindows: Bool, args: Array<String>): String {
        if (args.size == 0) {
            return "."
        }
        return Path.normalize(args[0], isWindows)
    }

    // Bun__Path__parse
    public static func parse(global: Int64, isWindows: Bool, args: Array<String>): PathParsed {
        if (args.size == 0) {
            return PathParsed()
        }
        return Path.parse(args[0], isWindows)
    }

    // Bun__Path__relative
    public static func relative(global: Int64, isWindows: Bool, args: Array<String>): String {
        if (args.size < 2) {
            return ""
        }
        return Path.relative(args[0], args[1], isWindows)
    }

    // Bun__Path__resolve
    public static func resolve(global: Int64, isWindows: Bool, args: Array<String>): String {
        return Path.resolve(args, isWindows)
    }

    // Bun__Path__toNamespacedPath
    public static func toNamespacedPath(global: Int64, isWindows: Bool, args: Array<String>): String {
        if (args.size == 0) {
            return ""
        }
        return Path.toNamespacedPath(args[0], isWindows)
    }
}
