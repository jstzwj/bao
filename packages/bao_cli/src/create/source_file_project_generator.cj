// 严格翻译自: src/cli/create/SourceFileProjectGenerator.zig
package bao_cli.create

import bao_core.*
import bao_install.*

// ============================================================================
// SourceFileProjectGenerator — 源文件项目生成器
// 严格翻译自: src/cli/create/SourceFileProjectGenerator.zig
//
// 从单个源文件 (JSX/TSX) 生成完整项目:
// - 检测 React 组件导出
// - 检测 Tailwind CSS 类
// - 检测 shadcn/ui 组件
// - 选择模板 (React / React+Tailwind / React+shadcn)
// - 生成项目文件并安装依赖
// ============================================================================

/// 模板文件
/// 对应 Bun: TemplateFile
public class TemplateFile {
    public var name: String
    public var content: String
    public var reason: Reason
    public var overwrite: Bool = true

    public init(name: String, content: String, reason: Reason, overwrite: Bool = true) {
        this.name = name
        this.content = content
        this.reason = reason
        this.overwrite = overwrite
    }
}

/// 文件原因
/// 对应 Bun: Reason
public enum Reason {
    | shadcn
    | bun
    | css
    | tsc
    | build
    | html
    | npm
}

/// 模板标签
/// 对应 Bun: Template.Tag
public enum TemplateTag {
    | reactTailwindSpa
    | reactSpa
    | reactShadcnSpa

    /// 获取标签名称
    /// 对应 Bun: Template.Tag.label
    public func label(): String {
        when (this) {
            case TemplateTag.reactTailwindSpa => return "React + Tailwind"
            case TemplateTag.reactSpa => return "React"
            case TemplateTag.reactShadcnSpa => return "React + shadcn/ui + Tailwind"
        }
    }
}

/// 项目模板
/// 对应 Bun: Template
public class Template {
    public var tag: TemplateTag
    public var components: StringSet

    public init(tag: TemplateTag, components: StringSet) {
        this.tag = tag
        this.components = components
    }

    /// 获取模板文件列表
    /// 对应 Bun: ReactTailwindSpa.files / ReactSpa.files / ReactShadcnSpa.files
    public func files(): ArrayList<TemplateFile> {
        when (tag) {
            case TemplateTag.reactTailwindSpa => return reactTailwindSpaFiles()
            case TemplateTag.reactSpa => return reactSpaFiles()
            case TemplateTag.reactShadcnSpa => return reactShadcnSpaFiles()
        }
    }
}

/// 模板日志记录器
/// 对应 Bun: Template.Logger
public class TemplateLogger {
    public var hasWrittenInitialMessage: Bool = false
    public var templateTag: TemplateTag

    public init(templateTag: TemplateTag) {
        this.templateTag = templateTag
    }

    /// 记录文件创建
    /// 对应 Bun: Logger.file
    public func file(templateFile: TemplateFile, name: String, maxNameLen: Int64): Unit {
        hasWrittenInitialMessage = true
        Output.pretty(" <green>create<r>  ")
        Output.pretty(name)
        var padding = maxNameLen - name.length
        while (padding > 0) {
            Output.pretty(" ")
            padding -= 1
        }
        Output.prettyLn("   <d>${templateFile.reason}<r>")
    }

    /// 如果是新项目则打印欢迎信息
    /// 对应 Bun: Logger.ifNew
    public func ifNew(): Unit {
        if (!hasWrittenInitialMessage) {
            return
        }

        Output.prettyLn("<r><d>--------------------------------<r>")
        Output.prettyLn("${templateTag.label()} project configured")
        Output.prettyLn("")
        Output.prettyLn("<b><cyan>Development<r><d> - frontend dev server with hot reload<r>")
        Output.prettyLn("")
        Output.prettyLn("  <cyan><b>bao dev<r>")
        Output.prettyLn("")
        Output.prettyLn("<b><green>Production<r><d> - build optimized assets<r>")
        Output.prettyLn("")
        Output.prettyLn("  <green><b>bao run build<r>")
        Output.prettyLn("")
        Output.prettyLn("<blue>Happy baunning!<r>")
    }
}

/// 源文件项目生成器
/// 对应 Bun: SourceFileProjectGenerator
public class SourceFileProjectGenerator {
    /// 启用 shadcn/ui
    private static let enableShadcnUi: Bool = true

    /// 生成项目
    /// 对应 Bun: SourceFileProjectGenerator.generate
    public static func generate(
        ctx: CommandContext,
        exampleTag: ExampleTag,
        entryPoint: String,
        result: DependenciesScannerResult
    ): Unit {
        let reactComponentExport = findReactComponentExport(result.bundleV2)
        if (reactComponentExport == None) {
            Output.errGeneric("No component export found in <b>${entryPoint}<r>")
            Output.flush()
            Output.errorWriterBuffered().writeAll(
                "\nPlease add an export to your file. For example:\n\n" +
                "   export default function MyApp() {\n" +
                "     return <div>Hello World</div>;\n" +
                "   };\n\n"
            )
            Output.flush()
            Global.crash()
        }

        // 检查 Tailwind 依赖
        let hasTailwindInDependencies = result.dependencies.contains("tailwindcss") ||
            result.dependencies.contains("bao-plugin-tailwind")
        var needsToInjectTailwind = false
        if (!hasTailwindInDependencies) {
            needsToInjectTailwind = hasAnyTailwindClassesInSourceFiles(
                result.bundleV2, result.reachableFiles
            )
        }

        // 获取 shadcn 组件
        var shadcn = StringSet()
        var needsToInjectShadcnUi = false
        if (enableShadcnUi) {
            shadcn = getShadcnComponents(result.bundleV2, result.reachableFiles)
            needsToInjectShadcnUi = shadcn.keys().size > 0
        }

        // 添加 Tailwind 依赖
        if (needsToInjectTailwind) {
            result.dependencies.insert("tailwindcss")
            result.dependencies.insert("bao-plugin-tailwind")
        }

        // 添加 shadcn 依赖
        if (needsToInjectShadcnUi) {
            result.dependencies.insert("tw-animate-css")
            result.dependencies.insert("class-variance-authority")
            result.dependencies.insert("clsx")
            result.dependencies.insert("tailwind-merge")
            result.dependencies.insert("lucide-react")
        }

        let usesTailwind = hasTailwindInDependencies || needsToInjectTailwind

        // 强制 React 19
        result.dependencies.swapRemove("react")
        result.dependencies.swapRemove("react-dom")
        result.dependencies.insert("react-dom@19")
        result.dependencies.insert("react@19")

        let devDependencies = ["@types/bun", "@types/react@19", "@types/react-dom@19"]

        // 选择模板
        let template: Template = if (needsToInjectShadcnUi) {
            Template(TemplateTag.reactShadcnSpa, shadcn)
        } else if (usesTailwind) {
            Template(TemplateTag.reactTailwindSpa, StringSet())
        } else {
            Template(TemplateTag.reactSpa, StringSet())
        }

        // 生成文件
        generateFiles(
            DefaultAllocator.get(),
            entryPoint,
            result.dependencies.keys(),
            devDependencies,
            template,
            reactComponentExport!!
        )

        Global.exit(0)
    }

    /// 生成所有项目文件
    /// 对应 Bun: generateFiles
    public static func generateFiles(
        allocator: Allocator,
        entryPoint: String,
        dependencies: ArrayList<String>,
        devDependencies: ArrayList<String>,
        template: Template,
        reactComponentExport: String
    ): Unit {
        let log = TemplateLogger(template.tag)
        var basename = Path.basename(entryPoint)
        let extension = Path.extension(basename)
        if (extension.length > 0) {
            basename = basename.substring(0, basename.length - extension.length)
        }

        // 规范化文件路径
        var normalizedBuf = PathBuffer()
        var normalizedName = if (Path.isAbsolute(entryPoint)) {
            Path.relativeNormalizedBuf(normalizedBuf, FileSystem.instance.topLevelDir, entryPoint, true)
        } else {
            Path.normalizeBuf(entryPoint, normalizedBuf)
        }

        if (extension.length > 0) {
            normalizedName = normalizedName.substring(0, normalizedName.length - extension.length)
        }

        // 获取模板文件
        let files = template.files()

        var maxFilenameLen: Int64 = 0
        let filenames = ArrayList<String>()
        let createdFiles = ArrayList<Bool>()

        for (i in 0..files.size) {
            createdFiles.append(false)
            filenames.append("")
        }

        // 创建所有模板文件
        for (index in 0..files.size) {
            let file = files[index]
            let fileName = stringWithReplacements(
                file.name, basename, normalizedName, reactComponentExport, allocator
            )
            if (file.overwrite || !Syscall.exists(fileName)) {
                let fileContent = stringWithReplacements(
                    file.content, basename, normalizedName, reactComponentExport, DefaultAllocator.get()
                )
                let created = createFile(fileName, fileContent)
                if (created.isErr) {
                    Output.errGeneric("failed to create ${fileName}")
                    Global.crash()
                } else if (created.result) {
                    createdFiles[index] = true
                    filenames[index] = fileName
                    maxFilenameLen = Math.max(maxFilenameLen, fileName.length)
                }
            }
        }

        for (index in 0..files.size) {
            if (createdFiles[index]) {
                log.file(files[index], filenames[index], maxFilenameLen)
            }
        }

        // 安装依赖
        if (dependencies.size > 0 || devDependencies.size > 0) {
            if (log.hasWrittenInitialMessage) {
                Output.print("\n")
            }
            Output.pretty("<r>📦 <b>Auto-installing ${dependencies.size + devDependencies.size} detected dependencies<r>\n")
        }

        if (dependencies.size > 0) {
            let argv = ArrayList<String>()
            argv.append("bao")
            argv.append("--only-missing")
            argv.append("install")
            for (dep in dependencies) {
                argv.append(dep)
            }
            runInstall(argv)
        }

        if (devDependencies.size > 0) {
            let argv = ArrayList<String>()
            argv.append("bao")
            argv.append("--only-missing")
            argv.append("add")
            argv.append("-d")
            for (dep in devDependencies) {
                argv.append(dep)
            }
            runInstall(argv)
        }

        // shadcn 组件安装
        if (template.tag == TemplateTag.reactShadcnSpa && template.components.keys().size > 0) {
            let shadcnArgv = ArrayList<String>()
            shadcnArgv.append("bao")
            shadcnArgv.append("x")
            shadcnArgv.append("shadcn@canary")
            shadcnArgv.append("add")
            if (normalizedName.contains("/src")) {
                shadcnArgv.append("--src-dir")
            }
            shadcnArgv.append("-y")
            for (key in template.components.keys()) {
                shadcnArgv.append(key)
            }

            Output.prettyLn("\n<r>😎 <b>Setting up shadcn/ui components<r>")
            Output.commandOut(shadcnArgv.toArray())
            Output.flush()

            shadcnArgv[0] = Sys.selfExePath() ?: "bao"

            let shadcnProcess = Process.spawnSync(shadcnArgv.toArray(), FileSystem.instance.topLevelDir)
            if (!shadcnProcess.isOK()) {
                Global.crash()
            }

            Output.print("\n")
            log.ifNew()
        }

        // React 和 React+Tailwind 模板
        if (template.tag == TemplateTag.reactSpa || template.tag == TemplateTag.reactTailwindSpa) {
            log.ifNew()
        }

        Output.flush()

        // 启动开发服务器
        let startArgv = [Sys.selfExePath() ?: "bao", "dev"]
        let startProcess = Process.spawnSync(startArgv, FileSystem.instance.topLevelDir)
        if (!startProcess.isOK()) {
            Global.crash()
        }

        Global.exit(0)
    }

    /// 创建文件
    /// 对应 Bun: createFile
    private static func createFile(filename: String, contents: String): Result<Bool> {
        // 检查文件是否已存在且内容相同
        let sourceContents = BaoFile.readAllText(filename)
        if (sourceContents != None && sourceContents!! == contents) {
            return Result<Bool>.ok(false)
        }

        // 创建父目录
        let dirname = Path.dirname(filename)
        if (dirname.length > 0) {
            BaoFile.mkdirRecursive(dirname)
        }

        // 写入文件
        BaoFile.writeAllText(filename, contents)
        return Result<Bool>.ok(true)
    }

    /// 统计替换后的缓冲区大小
    /// 对应 Bun: countReplaceAllOccurrences
    private static func countReplaceAllOccurrences(input: String, needle: String, replacement: String): Int64 {
        var remaining = input
        var count: Int64 = 0
        while (remaining.length > 0) {
            let index = remaining.indexOf(needle)
            if (index >= 0) {
                remaining = remaining.substring(index + needle.length)
                count += 1
            } else {
                break
            }
        }
        return input.length + (count * (replacement.length - needle.length))
    }

    /// 替换所有出现
    /// 对应 Bun: replaceAllOccurrencesOfString
    private static func replaceAllOccurrencesOfString(
        allocator: Allocator, input: String, needle: String, replacement: String
    ): String {
        let result = StringBuilder()
        var remaining = input
        while (remaining.length > 0) {
            let index = remaining.indexOf(needle)
            if (index >= 0) {
                result.append(remaining.substring(0, index))
                result.append(replacement)
                remaining = remaining.substring(index + needle.length)
            } else {
                result.append(remaining)
                break
            }
        }
        return result.toString()
    }

    /// 替换模板占位符
    /// 对应 Bun: stringWithReplacements
    private static func stringWithReplacements(
        originalInput: String, basename: String, relativeName: String,
        reactComponentExport: String, allocator: Allocator
    ): String {
        var input = originalInput

        if (input.contains("REPLACE_ME_WITH_YOUR_REACT_COMPONENT_EXPORT")) {
            input = replaceAllOccurrencesOfString(
                allocator, input, "REPLACE_ME_WITH_YOUR_REACT_COMPONENT_EXPORT", reactComponentExport
            )
        }

        if (input.contains("REPLACE_ME_WITH_YOUR_APP_BASE_NAME")) {
            input = replaceAllOccurrencesOfString(
                allocator, input, "REPLACE_ME_WITH_YOUR_APP_BASE_NAME", basename
            )
        }

        if (input.contains("REPLACE_ME_WITH_YOUR_APP_FILE_NAME")) {
            input = replaceAllOccurrencesOfString(
                allocator, input, "REPLACE_ME_WITH_YOUR_APP_FILE_NAME", relativeName
            )
        }

        return input
    }

    /// 运行安装命令
    /// 对应 Bun: runInstall
    private static func runInstall(argv: ArrayList<String>): Unit {
        Output.commandOut(argv.toArray())
        Output.flush()

        argv[0] = Sys.selfExePath() ?: "bao"

        let process = Process.spawnSync(argv.toArray(), FileSystem.instance.topLevelDir)
        if (process.isErr) {
            Output.errGeneric("failed to install dependencies")
            Global.crash()
        }
        if (!process.result.isOK()) {
            if (process.result == SpawnStatus.exited) {
                Global.exit(process.result.exitCode)
            }
            Global.crash()
        }
    }

    /// 检查源文件中是否包含 Tailwind 类
    /// 对应 Bun: hasAnyTailwindClassesInSourceFiles
    private static func hasAnyTailwindClassesInSourceFiles(
        bundler: BundleV2, reachableFiles: ArrayList<AstIndex>
    ): Bool {
        let commonTailwindPatterns = [
            "bg-", "text-", "p-", "m-", "flex", "grid", "border", "rounded",
            "shadow", "hover:", "focus:", "dark:", "sm:", "md:", "lg:", "xl:",
            "w-", "h-", "space-", "gap-", "items-", "justify-", "font-"
        ]

        for (file in reachableFiles) {
            let loader = bundler.graph.inputFiles.loaders[file.get()]
            when (loader) {
                case Loader.tsx, Loader.jsx => {
                    let sourceCode = bundler.graph.inputFiles.sources[file.get()].contents

                    // 检查 className=" 或 className='
                    var searchCode = sourceCode
                    while (true) {
                        let idx = searchCode.indexOf("className=")
                        if (idx < 0) {
                            break
                        }
                        searchCode = searchCode.substring(idx + "className=".length)
                        if (searchCode.length < 1) {
                            return false
                        }
                        when (searchCode[0]) {
                            case '\'', '"' => {
                                let quote = searchCode[0]
                                searchCode = searchCode.substring(1)
                                let endQuote = searchCode.indexOf(quote)
                                if (endQuote < 0) {
                                    continue
                                }
                                let className = searchCode.substring(0, endQuote)
                                for (pattern in commonTailwindPatterns) {
                                    if (className.contains(pattern)) {
                                        return true
                                    }
                                }
                            }
                            case _ => {
                                searchCode = searchCode.substring(1)
                            }
                        }
                    }
                }
                case Loader.html => {
                    let sourceCode = bundler.graph.inputFiles.sources[file.get()].contents
                    var i: Int64 = 0
                    while (i < sourceCode.length) {
                        if (i + 7 >= sourceCode.length) {
                            break
                        }
                        if (sourceCode.substring(i.toInt()).startsWith("class")) {
                            var j = i + 5
                            while (j < sourceCode.length && (sourceCode[j.toInt()] == ' ' || sourceCode[j.toInt()] == '=')) {
                                j += 1
                            }
                            if (j < sourceCode.length && (sourceCode[j.toInt()] == '"' || sourceCode[j.toInt()] == '\'')) {
                                let searchEnd = Math.min(j + 1000, sourceCode.length)
                                let classSection = sourceCode.substring(j.toInt(), searchEnd.toInt())
                                for (pattern in commonTailwindPatterns) {
                                    if (classSection.contains(pattern)) {
                                        return true
                                    }
                                }
                            }
                            i = j
                        }
                        i += 1
                    }
                }
                case _ => ()
            }
        }

        return false
    }

    /// 获取使用的 shadcn 组件
    /// 对应 Bun: getShadcnComponents
    private static func getShadcnComponents(
        bundler: BundleV2, reachableFiles: ArrayList<AstIndex>
    ): StringSet {
        let icons = StringSet()
        let all = bundler.graph.ast.importRecords

        for (file in reachableFiles) {
            let loader = bundler.graph.inputFiles.loaders[file.get()]
            when (loader) {
                case Loader.tsx, Loader.jsx => {
                    let importRecords = all[file.get()]
                    for (importRecord in importRecords) {
                        if (importRecord.path.text.startsWith("@/components/ui/")) {
                            icons.insert(importRecord.path.text.substring("@/components/ui/".length))
                        }
                    }
                }
                case _ => ()
            }
        }

        return icons
    }

    /// 查找 React 组件导出
    /// 对应 Bun: findReactComponentExport
    private static func findReactComponentExport(bundler: BundleV2): ?String {
        let inputFiles = bundler.graph.inputFiles
        let loaders = inputFiles.loaders
        let resolvedExports = bundler.linker.graph.meta.resolvedExports
        let sources = inputFiles.sources

        let entryPointIds = bundler.graph.entryPoints

        for (entryPointId in entryPointIds) {
            let loader = loaders[entryPointId.get()]
            if (loader == Loader.jsx || loader == Loader.tsx) {
                let source = sources[entryPointId.get()]
                let exports = resolvedExports[entryPointId.get()]

                // 1. 优先默认导出
                if (exports.contains("default")) {
                    return "default"
                }

                let exportNames = exports.keys()
                if (exportNames.size == 1) {
                    return exportNames[0]
                }

                if (exportNames.size == 0) {
                    continue
                }

                let filename = source.path.name.nonUniqueNameStringBase()
                if (filename.length == 0) {
                    continue
                }

                // 2. 优先匹配文件名 (首字母大写)
                if (filename[0] >= 'A' && filename[0] <= 'Z') {
                    if (JsLexer.isIdentifier(filename) && exports.contains(filename)) {
                        return filename
                    }
                }

                // 3. 尝试首字母大写
                if (filename[0] >= 'a' && filename[0] <= 'z') {
                    let duped = filename
                    let capitalized = duped[0].toUpperCase() + duped.substring(1)
                    if (JsLexer.isIdentifier(capitalized) && exports.contains(capitalized)) {
                        return capitalized
                    }

                    // PascalCase 转换
                    let pascalCase = toPascalCase(duped)
                    if (exports.contains(pascalCase)) {
                        return pascalCase
                    }

                    // 极端简化的 PascalCase
                    if (pascalCase.length > 1) {
                        let lowerRest = pascalCase[0] + pascalCase.substring(1).toLowerCase()
                        if (exports.contains(lowerRest)) {
                            return lowerRest
                        }
                    }
                }

                // 4. 确保为有效标识符
                let nameToTry = MutableString.ensureValidIdentifier(filename)
                if (nameToTry != None && exports.contains(nameToTry!!)) {
                    return nameToTry
                }

                // 5. 找一个大写开头的导出
                for (exportName in exportNames) {
                    if (exportName.length > 0 && exportName[0] >= 'A' && exportName[0] <= 'Z') {
                        return exportName
                    }
                }

                // 6. 随便选一个
                if (exportNames.size > 0) {
                    return exportNames[0]
                }
            }
        }

        return None
    }

    /// 转换为 PascalCase
    /// 对应 Bun: 极端简化的 pascal case 转换
    private static func toPascalCase(input: String): String {
        let result = StringBuilder()
        var capitalizeNext = false
        var outputIndex = 0

        for ((inputIndex, char) in input) {
            if (char == ' ' || char == '-' || char == '_' ||
                (outputIndex == 0 && !JsLexer.isIdentifierStart(char))) {
                capitalizeNext = true
                continue
            }
            if (outputIndex == 0 || capitalizeNext) {
                if (char >= 'a' && char <= 'z') {
                    result.append(char.toUpperCase())
                } else {
                    result.append(char)
                }
                capitalizeNext = false
                outputIndex += 1
            } else {
                result.append(char)
                outputIndex += 1
            }
        }

        return result.toString()
    }

    // ========================================================================
    // 模板文件定义
    // ========================================================================

    /// React + Tailwind SPA 文件列表
    /// 对应 Bun: ReactTailwindSpa.files
    private static func reactTailwindSpaFiles(): ArrayList<TemplateFile> {
        let result = ArrayList<TemplateFile>()
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.build.ts",
            sharedBuildTs(),
            Reason.build
        ))
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.css",
            reactTailwindSpaCss(),
            Reason.css
        ))
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.html",
            sharedHtml(),
            Reason.html
        ))
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.client.tsx",
            sharedClientTsx(),
            Reason.bun
        ))
        result.append(TemplateFile(
            "bunfig.toml",
            sharedBunfigToml(),
            Reason.bun,
            false
        ))
        result.append(TemplateFile(
            "package.json",
            sharedPackageJson(),
            Reason.npm,
            false
        ))
        return result
    }

    /// React SPA 文件列表
    /// 对应 Bun: ReactSpa.files
    private static func reactSpaFiles(): ArrayList<TemplateFile> {
        let result = ArrayList<TemplateFile>()
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.build.ts",
            sharedBuildTs(),
            Reason.build
        ))
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.css",
            reactSpaCss(),
            Reason.css,
            false
        ))
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.html",
            sharedHtml(),
            Reason.html
        ))
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.client.tsx",
            sharedClientTsx(),
            Reason.bun
        ))
        result.append(TemplateFile(
            "package.json",
            sharedPackageJson(),
            Reason.npm,
            false
        ))
        return result
    }

    /// React + shadcn SPA 文件列表
    /// 对应 Bun: ReactShadcnSpa.files
    private static func reactShadcnSpaFiles(): ArrayList<TemplateFile> {
        let result = ArrayList<TemplateFile>()
        result.append(TemplateFile("lib/utils.ts", shadcnUtilsTs(), Reason.shadcn))
        result.append(TemplateFile("index.css", shadcnIndexCss(), Reason.shadcn))
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.build.ts",
            sharedBuildTs(),
            Reason.bun
        ))
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.client.tsx",
            sharedClientTsx(),
            Reason.bun
        ))
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.css",
            shadcnAppCss(),
            Reason.css
        ))
        result.append(TemplateFile(
            "REPLACE_ME_WITH_YOUR_APP_FILE_NAME.html",
            sharedHtml(),
            Reason.html
        ))
        result.append(TemplateFile("styles/globals.css", shadcnGlobalsCss(), Reason.shadcn))
        result.append(TemplateFile("bunfig.toml", sharedBunfigToml(), Reason.bun, false))
        result.append(TemplateFile("package.json", sharedPackageJson(), Reason.npm, false))
        result.append(TemplateFile("tsconfig.json", shadcnTsconfig(), Reason.tsc, false))
        result.append(TemplateFile("components.json", shadcnComponentsJson(), Reason.shadcn, false))
        return result
    }

    // ========================================================================
    // 共享模板内容 (占位符, 实际内容由 embedFile 提供)
    // ========================================================================

    /// 共享 build.ts
    /// 对应 Bun: shared_build_ts
    private static func sharedBuildTs(): String {
        return "import bao from 'bao';\n" +
            "// Build configuration\n" +
            "export default bao.build({\n" +
            "  entrypoints: ['./REPLACE_ME_WITH_YOUR_APP_FILE_NAME.client.tsx'],\n" +
            "  outdir: './dist',\n" +
            "});\n"
    }

    /// 共享 client.tsx
    /// 对应 Bun: shared_client_tsx
    private static func sharedClientTsx(): String {
        return "import { createRoot } from 'react-dom/client';\n" +
            "import REPLACE_ME_WITH_YOUR_REACT_COMPONENT_EXPORT from './REPLACE_ME_WITH_YOUR_APP_FILE_NAME';\n" +
            "import './REPLACE_ME_WITH_YOUR_APP_FILE_NAME.css';\n\n" +
            "const root = createRoot(document.getElementById('root')!);\n" +
            "root.render(<REPLACE_ME_WITH_YOUR_REACT_COMPONENT_EXPORT />);\n"
    }

    /// 共享 HTML
    /// 对应 Bun: shared_html
    private static func sharedHtml(): String {
        return "<!DOCTYPE html>\n" +
            "<html lang=\"en\">\n" +
            "<head>\n" +
            "  <meta charset=\"UTF-8\" />\n" +
            "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n" +
            "  <title>REPLACE_ME_WITH_YOUR_APP_BASE_NAME</title>\n" +
            "</head>\n" +
            "<body>\n" +
            "  <div id=\"root\"></div>\n" +
            "  <script src=\"./REPLACE_ME_WITH_YOUR_APP_FILE_NAME.client.tsx\"></script>\n" +
            "</body>\n" +
            "</html>\n"
    }

    /// 共享 package.json
    /// 对应 Bun: shared_package_json
    private static func sharedPackageJson(): String {
        return "{\n" +
            "  \"name\": \"REPLACE_ME_WITH_YOUR_APP_BASE_NAME\",\n" +
            "  \"private\": true,\n" +
            "  \"version\": \"0.0.0\",\n" +
            "  \"type\": \"module\"\n" +
            "}\n"
    }

    /// 共享 bunfig.toml
    /// 对应 Bun: shared_bunfig_toml
    private static func sharedBunfigToml(): String {
        return "# Bao configuration\n"
    }

    /// React + Tailwind CSS
    private static func reactTailwindSpaCss(): String {
        return "@tailwind base;\n@tailwind components;\n@tailwind utilities;\n"
    }

    /// React SPA CSS
    private static func reactSpaCss(): String {
        return "/* Styles */\n"
    }

    /// shadcn 组件
    private static func shadcnUtilsTs(): String {
        return "import { clsx, type ClassValue } from 'clsx';\n" +
            "import { twMerge } from 'tailwind-merge';\n\n" +
            "export function cn(...inputs: ClassValue[]) {\n" +
            "  return twMerge(clsx(inputs));\n" +
            "}\n"
    }

    /// shadcn index.css
    private static func shadcnIndexCss(): String {
        return "@tailwind base;\n@tailwind components;\n@tailwind utilities;\n"
    }

    /// shadcn app.css
    private static func shadcnAppCss(): String {
        return "@tailwind base;\n@tailwind components;\n@tailwind utilities;\n"
    }

    /// shadcn globals.css
    private static func shadcnGlobalsCss(): String {
        return "@tailwind base;\n@tailwind components;\n@tailwind utilities;\n"
    }

    /// shadcn tsconfig.json
    private static func shadcnTsconfig(): String {
        return "{\n" +
            "  \"compilerOptions\": {\n" +
            "    \"jsx\": \"react-jsx\",\n" +
            "    \"paths\": { \"@/*\": [\"./src/*\"] }\n" +
            "  }\n" +
            "}\n"
    }

    /// shadcn components.json
    private static func shadcnComponentsJson(): String {
        return "{\n" +
            "  \"style\": \"new-york\",\n" +
            "  \"tailwind\": { \"config\": \"tailwind.config.js\" }\n" +
            "}\n"
    }
}
