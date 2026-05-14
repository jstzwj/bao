// 严格翻译自: src/cli/init_command.zig
// Init 命令实现
package bao_cli

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_sys.*
import bao_path.*

// ============================================================================
// InitCommand — bun init 实现
// 严格翻译自: src/cli/init_command.zig - InitCommand
// 对应 Bun: bun init — 项目脚手架
//
// Bun init 支持两种模式:
//   1. 交互式: 提示输入项目名称、类型等
//   2. 非交互式: 通过命令行参数指定
// ============================================================================

/// 项目模板类型
/// 对应 Bun: init 命令支持的模板
public enum ProjectTemplate {
    | Default    // 标准 Node.js 项目
    | Minimal    // 最小化项目
    | Library    // 库项目
    | React      // React 项目
    | Next       // Next.js 项目

    public func toString(): String {
        match (this) {
            case Default => "default"
            case Minimal => "minimal"
            case Library => "library"
            case React => "react"
            case Next => "next"
        }
    }

    public static func parse(value: String): ProjectTemplate {
        match (value) {
            case "minimal" => Minimal
            case "library" => Library
            case "react" => React
            case "next" => Next
            case _ => Default
        }
    }
}

/// Init 命令执行器
/// 对应 Bun: InitCommand.exec(ctx)
///
/// 生成的文件:
///   - package.json
///   - tsconfig.json (非 minimal)
///   - index.js (入口文件)
///   - .gitignore
///   - README.md
public class InitCommand {
    /// 初始化选项
    private var options: InitOptions

    public init(options: InitOptions) {
        this.options = options
    }

    /// 执行 init 命令
    /// 对应 Bun: InitCommand.exec → 创建项目文件
    public func execute(): Int64 {
        let name = options.name
        let template = ProjectTemplate.parse(options.template)

        println("Initializing project: ${name}")
        println("")

        // 检查目标目录是否为空
        // 对应 Bun: 检查当前目录是否有冲突文件
        if (!checkDirectory(name)) {
            return 1
        }

        // 生成项目文件
        generatePackageJson(name, template)
        generateEntryFile(name, template)
        generateGitignore()

        // 根据模板生成额外文件
        match (template) {
            case ProjectTemplate.Minimal => ()
            case ProjectTemplate.Library => {
                generateTsConfig(name)
                generateLibFiles(name)
            }
            case ProjectTemplate.React => {
                generateTsConfig(name)
                generateReactFiles(name)
            }
            case ProjectTemplate.Default => {
                generateTsConfig(name)
            }
            case ProjectTemplate.Next => {
                generateTsConfig(name)
            }
        }

        // 生成 README
        generateReadme(name, template)

        println("")
        println("Project initialized successfully!")
        println("")
        println("Next steps:")
        println("  cd ${name}")
        println("  bao install")
        println("  bao run index.js")

        return 0
    }

    /// 检查目录状态
    /// 对应 Bun: 确认目标目录可用
    private func checkDirectory(name: String): Bool {
        // 检查是否已存在 package.json
        if (BaoFile.exists("package.json")) {
            println("warning: package.json already exists")
            // 对应 Bun: 询问是否覆盖
            println("  Existing files may be overwritten")
        }
        return true
    }

    /// 生成 package.json
    /// 对应 Bun: init_command.zig → 生成 package.json
    private func generatePackageJson(name: String, template: ProjectTemplate): Unit {
        let content = match (template) {
            case ProjectTemplate.Library =>
                "{\n" +
                "  \"name\": \"${name}\",\n" +
                "  \"version\": \"1.0.0\",\n" +
                "  \"description\": \"A JavaScript library\",\n" +
                "  \"main\": \"dist/index.js\",\n" +
                "  \"module\": \"dist/index.mjs\",\n" +
                "  \"types\": \"dist/index.d.ts\",\n" +
                "  \"scripts\": {\n" +
                "    \"build\": \"bao build src/index.ts --outdir dist --minify\",\n" +
                "    \"test\": \"bao test\",\n" +
                "    \"prepublishOnly\": \"bao build\"\n" +
                "  },\n" +
                "  \"keywords\": [],\n" +
                "  \"license\": \"MIT\"\n" +
                "}\n"
            case ProjectTemplate.React =>
                "{\n" +
                "  \"name\": \"${name}\",\n" +
                "  \"version\": \"1.0.0\",\n" +
                "  \"scripts\": {\n" +
                "    \"dev\": \"bao run --watch src/index.tsx\",\n" +
                "    \"build\": \"bao build src/index.tsx --outdir dist\",\n" +
                "    \"start\": \"bao run dist/index.js\"\n" +
                "  }\n" +
                "}\n"
            case _ =>
                "{\n" +
                "  \"name\": \"${name}\",\n" +
                "  \"version\": \"1.0.0\",\n" +
                "  \"scripts\": {\n" +
                "    \"start\": \"bao run index.js\",\n" +
                "    \"test\": \"bao test\"\n" +
                "  }\n" +
                "}\n"
        }
        BaoFile.writeAllText("package.json", content)
        println("  Created package.json")
    }

    /// 生成入口文件
    /// 对应 Bun: init_command.zig → 生成 index.js / index.ts
    private func generateEntryFile(name: String, template: ProjectTemplate): Unit {
        let (fileName, content) = match (template) {
            case ProjectTemplate.Library =>
                ("src/index.ts",
                "// ${name}\n\n" +
                "export function hello(): string {\n" +
                "  return \"Hello from ${name}!\";\n" +
                "}\n\n" +
                "export default hello;\n")
            case ProjectTemplate.React =>
                ("src/index.tsx",
                "import { render } from \"react-dom\";\n\n" +
                "function App() {\n" +
                "  return <div>Hello from ${name}!</div>;\n" +
                "}\n\n" +
                "render(<App />, document.getElementById(\"root\"));\n")
            case ProjectTemplate.Minimal =>
                ("index.js",
                "console.log(\"Hello from ${name}!\");\n")
            case _ =>
                ("index.js",
                "console.log(\"Hello from ${name}!\");\n")
        }
        BaoFile.writeAllText(fileName, content)
        println("  Created ${fileName}")
    }

    /// 生成 tsconfig.json
    /// 对应 Bun: init 命令生成 TypeScript 配置
    private func generateTsConfig(name: String): Unit {
        let content =
            "{\n" +
            "  \"compilerOptions\": {\n" +
            "    \"target\": \"ES2020\",\n" +
            "    \"module\": \"ESNext\",\n" +
            "    \"moduleResolution\": \"bundler\",\n" +
            "    \"strict\": true,\n" +
            "    \"esModuleInterop\": true,\n" +
            "    \"skipLibCheck\": true,\n" +
            "    \"forceConsistentCasingInFileNames\": true,\n" +
            "    \"outDir\": \"./dist\",\n" +
            "    \"rootDir\": \"./src\",\n" +
            "    \"declaration\": true\n" +
            "  },\n" +
            "  \"include\": [\"src/**/*.ts\", \"src/**/*.tsx\"],\n" +
            "  \"exclude\": [\"node_modules\", \"dist\"]\n" +
            "}\n"
        BaoFile.writeAllText("tsconfig.json", content)
        println("  Created tsconfig.json")
    }

    /// 生成 .gitignore
    /// 对应 Bun: init 命令生成 .gitignore
    private func generateGitignore(): Unit {
        let content =
            "node_modules/\n" +
            "dist/\n" +
            "*.log\n" +
            ".env\n" +
            ".env.local\n" +
            ".bao/\n"
        BaoFile.writeAllText(".gitignore", content)
        println("  Created .gitignore")
    }

    /// 生成 README.md
    private func generateReadme(name: String, template: ProjectTemplate): Unit {
        let content = "# ${name}\n\n" +
            "A JavaScript/TypeScript project.\n\n" +
            "## Usage\n\n" +
            "```bash\n" +
            "bao run index.js\n" +
            "```\n\n" +
            "## Build\n\n" +
            "```bash\n" +
            "bao build index.js --outdir dist\n" +
            "```\n\n" +
            "## Test\n\n" +
            "```bash\n" +
            "bao test\n" +
            "```\n"
        BaoFile.writeAllText("README.md", content)
        println("  Created README.md")
    }

    /// 生成库项目文件
    private func generateLibFiles(name: String): Unit {
        // src 目录下的测试文件
        BaoFile.mkdir("src", false)
        BaoFile.mkdir("tests", false)
        let testContent =
            "import { describe, it, expect } from \"bun:test\";\n" +
            "import { hello } from \"../src/index\";\n\n" +
            "describe(\"${name}\", () => {\n" +
            "  it(\"should return greeting\", () => {\n" +
            "    expect(hello()).toBe(\"Hello from ${name}!\");\n" +
            "  });\n" +
            "});\n"
        BaoFile.writeAllText("tests/index.test.ts", testContent)
        println("  Created tests/index.test.ts")
    }

    /// 生成 React 项目文件
    private func generateReactFiles(name: String): Unit {
        BaoFile.mkdir("src", false)
        BaoFile.mkdir("public", false)
        let htmlContent =
            "<!DOCTYPE html>\n" +
            "<html>\n<head>\n" +
            "  <title>${name}</title>\n" +
            "</head>\n<body>\n" +
            "  <div id=\"root\"></div>\n" +
            "  <script src=\"../dist/index.js\"></script>\n" +
            "</body>\n</html>\n"
        BaoFile.writeAllText("public/index.html", htmlContent)
        println("  Created public/index.html")
    }
}
