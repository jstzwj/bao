// bao_install - 文件夹解析器
// 严格翻译自: src/install/resolvers/folder_resolver.zig
//   folder_resolver.zig 负责解析本地文件夹依赖,
//   即 package.json 中 "dependencies": { "foo": "file:../foo" } 的形式
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 文件夹解析器
// 严格翻译自: src/install/resolvers/folder_resolver.zig
//   负责解析 "file:" 协议的本地路径依赖
// ============================================================================

/// 文件夹解析结果
/// 翻译自: folder_resolver 的解析结果
public class FolderResolveResult {
    /// 是否成功
    public var success: Bool
    /// 解析后的绝对路径
    public var resolvedPath: String
    /// 包名
    public var packageName: String
    /// 包版本 (从 package.json 读取)
    public var packageVersion: String
    /// 错误消息
    public var errorMessage: ?String

    public init() {
        success = false
        resolvedPath = ""
        packageName = ""
        packageVersion = ""
        errorMessage = None
    }

    public static func ok(path: String, name: String, version: String): FolderResolveResult {
        let r = FolderResolveResult()
        r.success = true
        r.resolvedPath = path
        r.packageName = name
        r.packageVersion = version
        return r
    }

    public static func err(msg: String): FolderResolveResult {
        let r = FolderResolveResult()
        r.success = false
        r.errorMessage = msg
        return r
    }
}

/// 文件夹解析器
/// 对应 Bun: folder_resolver.zig
public class FolderResolver {

    /// 解析 "file:" 协议的依赖路径
    /// 翻译自: folder_resolver 中解析 file: 路径的逻辑
    ///
    /// 支持的格式:
    /// - "file:../foo"     -> 相对路径
    /// - "file:/abs/path"  -> 绝对路径
    /// - "file:./local"    -> 当前目录下
    /// - "../foo"           -> 直接相对路径 (无 file: 前缀)
    public static func resolve(
        specifier: String,
        sourceDir: String,
        log: ArrayList<String>
    ): FolderResolveResult {
        var path = specifier

        // 去除 "file:" 前缀
        // 翻译自: Dependency.Version.Tag.folder 解析
        if (path.startsWith("file:")) {
            path = path.substring(5)
        }

        // 处理不同路径格式
        let resolvedPath = if (path.startsWith("/") || path.startsWith("\\") || (path.length > 1 && path[1] == ':')) {
            // 绝对路径 (Unix 或 Windows)
            path
        } else {
            // 相对路径
            bao_path.PathModule.join(ArrayList<String>([sourceDir, path]))
        }

        // 规范化路径
        let normalizedPath = bao_path.PathModule.normalize(resolvedPath)

        // 验证目录存在
        if (!bao_io.File.directoryExists(normalizedPath)) {
            return FolderResolveResult.err("Directory not found: ${normalizedPath}")
        }

        // 读取 package.json
        let pkgJsonPath = bao_path.PathModule.join(ArrayList<String>([normalizedPath, "package.json"]))
        if (!bao_io.File.exists(pkgJsonPath)) {
            return FolderResolveResult.err("No package.json found in: ${normalizedPath}")
        }

        try {
            let content = bao_io.File.readTextFile(pkgJsonPath)
            let json = bao_json.JsonParser.parse(content)
            match (json) {
                case Some(root) => {
                    let name = match (bao_json.JsonHelper.getString(root, "name")) {
                        case Some(n) => n
                        case None => bao_path.PathModule.getFileName(normalizedPath)
                    }
                    let version = match (bao_json.JsonHelper.getString(root, "version")) {
                        case Some(v) => v
                        case None => "0.0.0"
                    }
                    return FolderResolveResult.ok(
                        path: normalizedPath,
                        name: name,
                        version: version
                    )
                }
                case None => {
                    return FolderResolveResult.err("Failed to parse package.json in: ${normalizedPath}")
                }
            }
        } catch (e: Exception) {
            return FolderResolveResult.err("Failed to read package.json: ${e.message}")
        }
    }

    /// 检查指定符是否为文件夹依赖
    /// 翻译自: Dependency.Version.Tag 判断逻辑
    public static func isFolderDependency(specifier: String): Bool {
        if (specifier.startsWith("file:")) { return true }
        if (specifier.startsWith("./")) { return true }
        if (specifier.startsWith("../")) { return true }
        if (specifier.startsWith("/")) { return true }
        return false
    }

    /// 检查路径是否为链接依赖
    /// 翻译自: link: 前缀检测
    public static func isLinkDependency(specifier: String): Bool {
        return specifier.startsWith("link:")
    }

    /// 解析 "link:" 协议的依赖路径
    /// 翻译自: pnpm 风格的 link: 协议
    public static func resolveLink(
        specifier: String,
        sourceDir: String,
        log: ArrayList<String>
    ): FolderResolveResult {
        var path = specifier
        if (path.startsWith("link:")) {
            path = path.substring(5)
        }

        // link: 解析为相对于源目录的路径
        let resolvedPath = bao_path.PathModule.join(ArrayList<String>([sourceDir, path]))
        let normalizedPath = bao_path.PathModule.normalize(resolvedPath)

        if (!bao_io.File.directoryExists(normalizedPath)) {
            return FolderResolveResult.err("Link target not found: ${normalizedPath}")
        }

        return FolderResolveResult.ok(
            path: normalizedPath,
            name: bao_path.PathModule.getFileName(normalizedPath),
            version: "0.0.0"
        )
    }
}
