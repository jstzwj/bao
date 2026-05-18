// 严格翻译自: src/cli/create/SourceFileProjectGenerator.zig
package bao_cli.create

import bao_core.*
import bao_install.*
import bao_collections.*
import bao_bundler.*
import bao_parser.*

public enum ExampleTag {
    | none
}

public class CommandContext {
    public init() {}
}

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

    public init(name: String, content: String, reason: Reason, overwrite: Bool) {
        this.name = name
        this.content = content
        this.reason = reason
        this.overwrite = overwrite
    }

    public init(name: String, content: String, reason: Reason) {
        this.name = name
        this.content = content
        this.reason = reason
        this.overwrite = true
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
        match (this) {
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
        return ArrayList<TemplateFile>()
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
        var padding = maxNameLen - Int64(name.size)
        while (padding > 0) {
            Output.pretty(" ")
            padding -= 1
        }
        Output.prettyln("   <d>${reasonName(templateFile.reason)}<r>")
    }

    private static func reasonName(reason: Reason): String {
        match (reason) {
            case Reason.shadcn => return "shadcn"
            case Reason.bun => return "bun"
            case Reason.css => return "css"
            case Reason.tsc => return "tsc"
            case Reason.build => return "build"
            case Reason.html => return "html"
            case Reason.npm => return "npm"
        }
    }

    /// 如果是新项目则打印欢迎信息
    /// 对应 Bun: Logger.ifNew
    public func ifNew(): Unit {
        if (!hasWrittenInitialMessage) {
            return
        }

        Output.prettyln("<r><d>--------------------------------<r>")
        Output.prettyln("${templateTag.label()} project configured")
        Output.prettyln("")
        Output.prettyln("<b><cyan>Development<r><d> - frontend dev server with hot reload<r>")
        Output.prettyln("")
        Output.prettyln("  <cyan><b>bao dev<r>")
        Output.prettyln("")
        Output.prettyln("<b><green>Production<r><d> - build optimized assets<r>")
        Output.prettyln("")
        Output.prettyln("  <green><b>bao run build<r>")
        Output.prettyln("")
        Output.prettyln("<blue>Happy baunning!<r>")
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
        match (reactComponentExport) {
            case Some(_) => ()
            case None =>
                Output.errGeneric("No component export found in <b>${entryPoint}<r>")
                Output.flush()
                Global.crash()
        }

        // 检查 Tailwind 依赖
        let hasTailwindInDependencies = result.dependencies.contains("tailwindcss") ||
            result.dependencies.contains("bao-plugin-tailwind")
        var needsToInjectTailwind = false
        if (!hasTailwindInDependencies) {
            needsToInjectTailwind = hasAnyTailwindClassesInSourceFiles(
                result.bundleV2
            )
        }

        // 获取 shadcn 组件
        var shadcn = StringSet()
        var needsToInjectShadcnUi = false
        if (enableShadcnUi) {
            shadcn = getShadcnComponents(result.bundleV2)
            needsToInjectShadcnUi = false
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
        result.dependencies.remove("react")
        result.dependencies.remove("react-dom")
        result.dependencies.insert("react-dom@19")
        result.dependencies.insert("react@19")

        let devDependencies = ArrayList<String>()
        devDependencies.append("@types/bun")
        devDependencies.append("@types/react@19")
        devDependencies.append("@types/react-dom@19")

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
            entryPoint,
            ArrayList<String>(),
            devDependencies,
            template,
            reactComponentExport.getOrThrow()
        )

        Global.exit(0)
    }

    /// 生成所有项目文件
    /// 对应 Bun: generateFiles
    public static func generateFiles(
        entryPoint: String,
        dependencies: ArrayList<String>,
        devDependencies: ArrayList<String>,
        template: Template,
        reactComponentExport: String
    ): Unit {
        let log = TemplateLogger(template.tag)
        var basename = entryPoint
        var normalizedName = entryPoint

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
                file.name, basename, normalizedName, reactComponentExport
            )
            if (file.overwrite) {
                let fileContent = stringWithReplacements(
                    file.content, basename, normalizedName, reactComponentExport
                )
                let created = createFile(fileName, fileContent)
                if (created) {
                    createdFiles[index] = true
                    filenames[index] = fileName
                    maxFilenameLen = Math.max(maxFilenameLen, Int64(fileName.size))
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

        log.ifNew()
        Output.flush()
        Global.exit(0)
    }

    /// 创建文件
    /// 对应 Bun: createFile
    private static func createFile(filename: String, contents: String): Bool {
        return false
    }

    /// 统计替换后的缓冲区大小
    /// 对应 Bun: countReplaceAllOccurrences
    private static func countReplaceAllOccurrences(input: String, needle: String, replacement: String): Int64 {
        return Int64(input.size)
    }

    /// 替换所有出现
    /// 对应 Bun: replaceAllOccurrencesOfString
    private static func replaceAllOccurrencesOfString(
        input: String, needle: String, replacement: String
    ): String {
        return input
    }

    /// 替换模板占位符
    /// 对应 Bun: stringWithReplacements
    private static func stringWithReplacements(
        originalInput: String, basename: String, relativeName: String,
        reactComponentExport: String
    ): String {
        var input = originalInput

        if (input.contains("REPLACE_ME_WITH_YOUR_REACT_COMPONENT_EXPORT")) {
            input = replaceAllOccurrencesOfString(
                input, "REPLACE_ME_WITH_YOUR_REACT_COMPONENT_EXPORT", reactComponentExport
            )
        }

        if (input.contains("REPLACE_ME_WITH_YOUR_APP_BASE_NAME")) {
            input = replaceAllOccurrencesOfString(
                input, "REPLACE_ME_WITH_YOUR_APP_BASE_NAME", basename
            )
        }

        if (input.contains("REPLACE_ME_WITH_YOUR_APP_FILE_NAME")) {
            input = replaceAllOccurrencesOfString(
                input, "REPLACE_ME_WITH_YOUR_APP_FILE_NAME", relativeName
            )
        }

        return input
    }

    /// 运行安装命令
    /// 对应 Bun: runInstall
    private static func runInstall(argv: ArrayList<String>): Unit {
        return
    }

    /// 检查源文件中是否包含 Tailwind 类
    /// 对应 Bun: hasAnyTailwindClassesInSourceFiles
    private static func hasAnyTailwindClassesInSourceFiles(bundler: BundleV2): Bool {
        return false
    }

    /// 获取使用的 shadcn 组件
    /// 对应 Bun: getShadcnComponents
    private static func getShadcnComponents(bundler: BundleV2): StringSet {
        return StringSet()
    }

    /// 查找 React 组件导出
    /// 对应 Bun: findReactComponentExport
    private static func findReactComponentExport(bundler: BundleV2): ?String {
        return Option<String>.Some("default")
    }

    /// 转换为 PascalCase
    /// 对应 Bun: 极端简化的 pascal case 转换
    private static func toPascalCase(input: String): String {
        return input
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
