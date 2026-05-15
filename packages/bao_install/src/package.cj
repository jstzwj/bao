// bao_install - 包管理器
// 对应 Bun: src/install/
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 版本管理
// 对应 Bun: src/semver/
// ============================================================================

/// 包版本
/// 对应 Bun: src/semver/semver.zig
public class SemVer {
    public let major: Int64
    public let minor: Int64
    public let patch: Int64
    public let prerelease: ?String

    public init(major: Int64, minor: Int64, patch: Int64) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.prerelease = None
    }

    public func toString(): String {
        var s = "${major}.${minor}.${patch}"
        match (prerelease) {
            case Some(pre) => s = s + "-${pre}"
            case None => ()
        }
        return s
    }

    /// 从字符串解析版本号
    public static func parse(s: String): ?SemVer {
        var version = s
        if (version.startsWith("v") || version.startsWith("^") || version.startsWith("~")) {
            version = version.substring(1)
        }
        // 去除 prerelease 后缀
        let dashIdx = version.indexOf("-")
        var pre = None
        if (dashIdx >= 0) {
            pre = Some(version.substring(dashIdx + 1))
            version = version.substring(0, dashIdx)
        }
        let parts = version.split(".")
        if (parts.size >= 3) {
            try {
                let sv = SemVer(Int64.parse(parts[0]), Int64.parse(parts[1]), Int64.parse(parts[2]))
                sv.prerelease = pre
                return Some(sv)
            } catch (_: Exception) {
                return None
            }
        }
        return None
    }

    /// 比较: -1 表示 this < other, 0 表示相等, 1 表示 this > other
    public func compare(other: SemVer): Int64 {
        if (major != other.major) { return if (major > other.major) { 1 } else { -1 } }
        if (minor != other.minor) { return if (minor > other.minor) { 1 } else { -1 } }
        if (patch != other.patch) { return if (patch > other.patch) { 1 } else { -1 } }
        return 0
    }

    /// 是否满足范围 (^1.2.3, ~1.2.3, >=1.0.0)
    public static func satisfies(version: SemVer, range: String): Bool {
        if (range == "*" || range == "latest") { return true }

        var rangeStr = range.trim()

        // ^1.2.3 — 兼容版本 (主版本号相同)
        if (rangeStr.startsWith("^")) {
            let target = parse(rangeStr.substring(1))
            match (target) {
                case Some(t) => return version.major == t.major && version.compare(t) >= 0
                case None => return false
            }
        }

        // ~1.2.3 — 近似版本 (主+次版本号相同)
        if (rangeStr.startsWith("~")) {
            let target = parse(rangeStr.substring(1))
            match (target) {
                case Some(t) => return version.major == t.major && version.minor == t.minor && version.compare(t) >= 0
                case None => return false
            }
        }

        // >=1.0.0
        if (rangeStr.startsWith(">=")) {
            let target = parse(rangeStr.substring(2))
            match (target) {
                case Some(t) => return version.compare(t) >= 0
                case None => return false
            }
        }

        // <=1.0.0
        if (rangeStr.startsWith("<=")) {
            let target = parse(rangeStr.substring(2))
            match (target) {
                case Some(t) => return version.compare(t) <= 0
                case None => return false
            }
        }

        // >1.0.0
        if (rangeStr.startsWith(">")) {
            let target = parse(rangeStr.substring(1))
            match (target) {
                case Some(t) => return version.compare(t) > 0
                case None => return false
            }
        }

        // <1.0.0
        if (rangeStr.startsWith("<")) {
            let target = parse(rangeStr.substring(1))
            match (target) {
                case Some(t) => return version.compare(t) < 0
                case None => return false
            }
        }

        // 精确版本
        let target = parse(rangeStr)
        match (target) {
            case Some(t) => return version.compare(t) == 0
            case None => return false
        }
    }
}

// ============================================================================
// 包信息
// 对应 Bun: src/install/install.zig
// ============================================================================

/// 包信息
public class PackageInfo {
    public let name: String
    public let version: SemVer
    public var dependencies: HashMap<String, String>
    public var devDependencies: HashMap<String, String>
    public var description: String
    public var main: String
    public var module: ?String
    public var types: ?String
    public var scripts: HashMap<String, String>

    public init(name: String, version: SemVer) {
        this.name = name
        this.version = version
        this.dependencies = HashMap<String, String>()
        this.devDependencies = HashMap<String, String>()
        this.description = ""
        this.main = "index.js"
        this.module = None
        this.types = None
        this.scripts = HashMap<String, String>()
    }
}

/// 锁文件条目
public class LockfileEntry {
    public let name: String
    public let version: String
    public let resolved: String  // 下载 URL
    public let integrity: String // SHA512 哈希
    public var dependencies: ArrayList<String>

    public init(name: String, version: String, resolved: String, integrity: String) {
        this.name = name
        this.version = version
        this.resolved = resolved
        this.integrity = integrity
        this.dependencies = ArrayList<String>()
    }
}

// ============================================================================
// 简易 JSON 解析器
// 对应 Bun: src/install/ 中读取 package.json 的逻辑
// ============================================================================

/// 简易 JSON 值
public enum JsonValue {
    | Null
    | Bool(Bool)
    | Number(Float64)
    | Str(String)
    | Array(ArrayList<JsonValue>)
    | Object(HashMap<String, JsonValue>)
}

/// 简易 JSON 解析器 — 仅用于 package.json
public class JsonParser {
    private var src: String
    private var pos: Int64

    public init() {
        src = ""
        pos = 0
    }

    /// 解析 JSON 字符串
    public func parse(input: String): ?JsonValue {
        src = input
        pos = 0
        skipWhitespace()
        return parseValue()
    }

    private func parseValue(): ?JsonValue {
        if (pos >= src.length) { return None }
        let c = src[pos]
        if (c == '"') { return Some(parseString()) }
        if (c == '{') { return Some(parseObject()) }
        if (c == '[') { return Some(parseArray()) }
        if (c == 't' || c == 'f') { return Some(parseBool()) }
        if (c == 'n') { return Some(parseNull()) }
        if (c == '-' || (c >= '0' && c <= '9')) { return Some(parseNumber()) }
        return None
    }

    private func parseString(): JsonValue {
        pos++  // skip opening "
        let sb = StringBuilder()
        while (pos < src.length && src[pos] != '"') {
            if (src[pos] == '\\' && pos + 1 < src.length) {
                pos++
                match (src[pos]) {
                    case 'n' => sb.append('\n')
                    case 't' => sb.append('\t')
                    case 'r' => sb.append('\r')
                    case '\\' => sb.append('\\')
                    case '"' => sb.append('"')
                    case _ => sb.append(src[pos])
                }
            } else {
                sb.append(src[pos])
            }
            pos++
        }
        pos++  // skip closing "
        return JsonValue.Str(sb.toString())
    }

    private func parseObject(): JsonValue {
        pos++  // skip {
        skipWhitespace()
        let obj = HashMap<String, JsonValue>()
        if (pos < src.length && src[pos] == '}') {
            pos++
            return JsonValue.Object(obj)
        }
        while (pos < src.length) {
            skipWhitespace()
            if (src[pos] != '"') { break }
            let key = match (parseString()) {
                case JsonValue.Str(s) => s
                case _ => ""
            }
            skipWhitespace()
            if (pos < src.length && src[pos] == ':') { pos++ }
            skipWhitespace()
            let val = parseValue()
            match (val) {
                case Some(v) => obj.put(key, v)
                case None => ()
            }
            skipWhitespace()
            if (pos < src.length && src[pos] == ',') { pos++ }
            if (pos < src.length && src[pos] == '}') { pos++; break }
        }
        return JsonValue.Object(obj)
    }

    private func parseArray(): JsonValue {
        pos++  // skip [
        skipWhitespace()
        let arr = ArrayList<JsonValue>()
        if (pos < src.length && src[pos] == ']') {
            pos++
            return JsonValue.Array(arr)
        }
        while (pos < src.length) {
            skipWhitespace()
            let val = parseValue()
            match (val) {
                case Some(v) => arr.append(v)
                case None => break
            }
            skipWhitespace()
            if (pos < src.length && src[pos] == ',') { pos++ }
            if (pos < src.length && src[pos] == ']') { pos++; break }
        }
        return JsonValue.Array(arr)
    }

    private func parseBool(): JsonValue {
        if (src.substring(pos, pos + 4) == "true") {
            pos += 4
            return JsonValue.Bool(true)
        }
        pos += 5
        return JsonValue.Bool(false)
    }

    private func parseNull(): JsonValue {
        pos += 4
        return JsonValue.Null
    }

    private func parseNumber(): JsonValue {
        let start = pos
        if (pos < src.length && src[pos] == '-') { pos++ }
        while (pos < src.length && src[pos] >= '0' && src[pos] <= '9') { pos++ }
        if (pos < src.length && src[pos] == '.') { pos++ }
        while (pos < src.length && src[pos] >= '0' && src[pos] <= '9') { pos++ }
        let numStr = src.substring(start, pos)
        try {
            return JsonValue.Number(Float64.parse(numStr))
        } catch (_: Exception) {
            return JsonValue.Number(0.0)
        }
    }

    private func skipWhitespace(): Unit {
        while (pos < src.length && (src[pos] == ' ' || src[pos] == '\n' || src[pos] == '\r' || src[pos] == '\t')) {
            pos++
        }
    }
}

/// JsonValue 工具方法
public class JsonHelper {
    /// 获取对象字段
    public static func getField(obj: JsonValue, key: String): ?JsonValue {
        match (obj) {
            case JsonValue.Object(m) => return m.get(key)
            case _ => return None
        }
    }

    /// 获取字符串字段
    public static func getString(obj: JsonValue, key: String): ?String {
        match (getField(obj, key)) {
            case Some(JsonValue.Str(s)) => return Some(s)
            case _ => return None
        }
    }

    /// 获取对象字段中的字符串映射
    public static func getStringMap(obj: JsonValue, key: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        match (getField(obj, key)) {
            case Some(JsonValue.Object(m)) => {
                for (k in m.keys()) {
                    match (m.get(k)) {
                        case Some(JsonValue.Str(v)) => result.put(k, v)
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }
        return result
    }
}

// ============================================================================
// 包管理器
// 对应 Bun: src/install/install.zig
// ============================================================================

/// 安装选项
public class InstallOptions {
    public var production: Bool
    public var frozen: Bool
    public var verbose: Bool

    public init() {
        production = false
        frozen = false
        verbose = false
    }
}

/// 包管理器
/// 对应 Bun: src/install/install.zig PackageManager
public class PackageManager {
    private var lockfile: HashMap<String, LockfileEntry>
    private var cacheDir: String
    private var jsonParser: JsonParser

    public init() {
        lockfile = HashMap<String, LockfileEntry>()
        cacheDir = bao_path.PathModule.join(ArrayList<String>([
            bao_sys.SysModule.getEnv("HOME").getOrElse(() => "/tmp"),
            ".bao", "cache"
        ]))
        jsonParser = JsonParser()
    }

    /// 安装依赖
    public func install(options: InstallOptions): Unit {
        // 1. 读取 package.json
        let packageJson = readPackageJson()
        match (packageJson) {
            case Some(pkg) => {
                if (options.verbose) {
                    println("Installing dependencies for ${pkg.name}@${pkg.version.toString()}")
                }

                // 2. 解析依赖
                let resolved = resolveDependencies(pkg, options)

                // 3. 下载包
                downloadPackages(resolved)

                // 4. 写入锁文件
                writeLockfile(resolved)

                if (options.verbose) {
                    println("Installed ${resolved.size} packages")
                }
            }
            case None => {
                throw BaoError("No package.json found in current directory")
            }
        }
    }

    /// 添加依赖
    /// 对应 Bun: bun add <package>
    public func add(name: String, version: ?String): Unit {
        let verStr = match (version) {
            case Some(v) => v
            case None => "latest"
        }

        // 读取现有 package.json
        let pkgOpt = readPackageJson()
        match (pkgOpt) {
            case Some(pkg) => {
                // 添加依赖
                pkg.dependencies.put(name, "^${verStr}")

                // 重写 package.json
                writePackageJson(pkg)

                // 安装
                let options = InstallOptions()
                options.verbose = true
                install(options)
            }
            case None => {
                throw BaoError("No package.json found")
            }
        }
    }

    /// 删除依赖
    /// 对应 Bun: bun remove <package>
    public func remove(name: String): Unit {
        let pkgOpt = readPackageJson()
        match (pkgOpt) {
            case Some(pkg) => {
                pkg.dependencies.remove(name)
                pkg.devDependencies.remove(name)

                // 删除 node_modules 中的包
                let moduleDir = "./node_modules/${name}"
                BaoFile.removeRecursive(moduleDir)

                // 重写 package.json
                writePackageJson(pkg)
            }
            case None => {
                throw BaoError("No package.json found")
            }
        }
    }

    /// 读取 package.json
    /// 对应 Bun: src/install/ 中读取 package.json 的逻辑
    private func readPackageJson(): ?PackageInfo {
        let content = try {
            BaoFile.readAllText("package.json")
        } catch (_: Exception) {
            return None
        }

        let json = jsonParser.parse(content)
        match (json) {
            case Some(root) => {
                let name = match (JsonHelper.getString(root, "name")) {
                    case Some(n) => n
                    case None => "unknown"
                }
                let versionStr = match (JsonHelper.getString(root, "version")) {
                    case Some(v) => v
                    case None => "0.0.0"
                }
                let version = match (SemVer.parse(versionStr)) {
                    case Some(v) => v
                    case None => SemVer(0, 0, 0)
                }

                let pkg = PackageInfo(name, version)
                pkg.description = match (JsonHelper.getString(root, "description")) {
                    case Some(d) => d
                    case None => ""
                }
                pkg.main = match (JsonHelper.getString(root, "main")) {
                    case Some(m) => m
                    case None => "index.js"
                }
                pkg.module = JsonHelper.getString(root, "module")
                pkg.types = JsonHelper.getString(root, "types")
                pkg.dependencies = JsonHelper.getStringMap(root, "dependencies")
                pkg.devDependencies = JsonHelper.getStringMap(root, "devDependencies")

                // 解析 scripts
                match (JsonHelper.getField(root, "scripts")) {
                    case Some(JsonValue.Object(scripts)) => {
                        for (k in scripts.keys()) {
                            match (scripts.get(k)) {
                                case Some(JsonValue.Str(v)) => pkg.scripts.put(k, v)
                                case _ => ()
                            }
                        }
                    }
                    case _ => ()
                }

                return Some(pkg)
            }
            case None => return None
        }
    }

    /// 写入 package.json
    private func writePackageJson(pkg: PackageInfo): Unit {
        let sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"name\": \"${pkg.name}\",\n")
        sb.append("  \"version\": \"${pkg.version.toString()}\",\n")
        if (pkg.description.length > 0) {
            sb.append("  \"description\": \"${pkg.description}\",\n")
        }
        sb.append("  \"main\": \"${pkg.main}\",\n")

        // scripts
        if (pkg.scripts.keys().size > 0) {
            sb.append("  \"scripts\": {\n")
            let keys = pkg.scripts.keys()
            for (i in 0..keys.size) {
                match (pkg.scripts.get(keys[i])) {
                    case Some(v) => {
                        sb.append("    \"${keys[i]}\": \"${v}\"")
                        if (i < keys.size - 1) { sb.append(",") }
                        sb.append("\n")
                    }
                    case None => ()
                }
            }
            sb.append("  },\n")
        }

        // dependencies
        if (pkg.dependencies.keys().size > 0) {
            sb.append("  \"dependencies\": {\n")
            let keys = pkg.dependencies.keys()
            for (i in 0..keys.size) {
                match (pkg.dependencies.get(keys[i])) {
                    case Some(v) => {
                        sb.append("    \"${keys[i]}\": \"${v}\"")
                        if (i < keys.size - 1) { sb.append(",") }
                        sb.append("\n")
                    }
                    case None => ()
                }
            }
            sb.append("  }\n")
        }

        sb.append("}\n")
        BaoFile.writeAllText("package.json", sb.toString())
    }

    /// 解析依赖树
    /// 对应 Bun: src/install/resolution.zig
    private func resolveDependencies(pkg: PackageInfo, options: InstallOptions): ArrayList<LockfileEntry> {
        let result = ArrayList<LockfileEntry>()
        let resolved = HashSet<String>()

        // 合并 dependencies 和 devDependencies
        let allDeps = HashMap<String, String>()
        if (!options.production) {
            for (key in pkg.devDependencies.keys()) {
                match (pkg.devDependencies.get(key)) {
                    case Some(v) => allDeps.put(key, v)
                    case None => ()
                }
            }
        }
        for (key in pkg.dependencies.keys()) {
            match (pkg.dependencies.get(key)) {
                case Some(v) => allDeps.put(key, v)
                case None => ()
            }
        }

        // 解析每个依赖
        for (name in allDeps.keys()) {
            if (resolved.contains(name)) { continue }
            resolved.put(name)

            let version = match (allDeps.get(name)) {
                case Some(v) => v
                case None => "*"
            }

            // 构造 npm registry URL
            let registryUrl = "https://registry.npmjs.org/${name}/${version}"

            // 创建锁文件条目
            let entry = LockfileEntry(name, version, registryUrl, "")
            result.append(entry)
        }

        return result
    }

    /// 下载包
    /// 对应 Bun: src/install/ 中并行下载的逻辑
    private func downloadPackages(packages: ArrayList<LockfileEntry>): Unit {
        for (entry in packages) {
            // 确保目录存在
            let moduleDir = "./node_modules/${entry.name}"
            BaoFile.mkdir(moduleDir, true)

            // 简化: 创建占位 package.json
            let pkgJson = "{\n  \"name\": \"${entry.name}\",\n  \"version\": \"${entry.version}\"\n}\n"
            BaoFile.writeAllText(moduleDir + "/package.json", pkgJson)

            // TODO: 实际从 registry 下载并解压 tarball
        }
    }

    /// 写入锁文件
    /// 对应 Bun: src/install/lockfile.zig
    private func writeLockfile(entries: ArrayList<LockfileEntry>): Unit {
        let sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"lockfileVersion\": 1,\n")
        sb.append("  \"packages\": {\n")
        for (i in 0..entries.size) {
            let entry = entries[i]
            sb.append("    \"node_modules/${entry.name}\": {\n")
            sb.append("      \"version\": \"${entry.version}\",\n")
            sb.append("      \"resolved\": \"${entry.resolved}\"")
            if (entry.integrity.length > 0) {
                sb.append(",\n      \"integrity\": \"${entry.integrity}\"")
            }
            sb.append("\n    }")
            if (i < entries.size - 1) { sb.append(",") }
            sb.append("\n")
        }
        sb.append("  }\n")
        sb.append("}\n")
        BaoFile.writeAllText("bao.lock", sb.toString())
    }

    /// 读取锁文件
    public func readLockfile(): HashMap<String, LockfileEntry> {
        let content = try {
            BaoFile.readAllText("bao.lock")
        } catch (_: Exception) {
            return HashMap<String, LockfileEntry>()
        }

        let json = jsonParser.parse(content)
        let result = HashMap<String, LockfileEntry>()
        match (json) {
            case Some(JsonValue.Object(root)) => {
                match (JsonHelper.getField(root, "packages")) {
                    case Some(JsonValue.Object(packages)) => {
                        for (key in packages.keys()) {
                            match (packages.get(key)) {
                                case Some(JsonValue.Object(pkg)) => {
                                    let name = key.replace("node_modules/", "")
                                    let version = match (JsonHelper.getString(pkg, "version")) {
                                        case Some(v) => v
                                        case None => "0.0.0"
                                    }
                                    let resolved = match (JsonHelper.getString(pkg, "resolved")) {
                                        case Some(v) => v
                                        case None => ""
                                    }
                                    let integrity = match (JsonHelper.getString(pkg, "integrity")) {
                                        case Some(v) => v
                                        case None => ""
                                    }
                                    result.put(name, LockfileEntry(name, version, resolved, integrity))
                                }
                                case _ => ()
                            }
                        }
                    }
                    case _ => ()
                }
            }
            case _ => ()
        }
        return result
    }
}
