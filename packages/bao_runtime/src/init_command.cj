// 严格翻译自: src/runtime/cli/init_command.zig
// bun init 命令 — 初始化新项目
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

// ============================================================================
// InitCommand — bun init / bun init -y
// 对应 Bun: src/runtime/cli/init_command.zig
// ============================================================================

/// 项目类型选择
public enum ProjectType {
    | blank
    | minimal
    | library
    | react
    | next

    public operator func ==(other: ProjectType): Bool {
        match (this) {
            case blank => match (other) { case blank => true; case _ => false }
            case minimal => match (other) { case minimal => true; case _ => false }
            case library => match (other) { case library => true; case _ => false }
            case react => match (other) { case react => true; case _ => false }
            case next => match (other) { case next => true; case _ => false }
        }
    }

    public operator func !=(other: ProjectType): Bool {
        !(this == other)
    }
}

/// bun init 命令实现
public class InitCommand {
    /// 执行命令
    public static func exec(ctx: CommandContext): Unit {
        let yes = ctx.flags.get("yes").isSome() || ctx.flags.get("y").isSome()
        let cwd = ctx.cwd

        if (yes) {
            initBlank(cwd)
            return
        }

        // 交互式初始化
        Output.prettyln("bun init - Initialize a new project\n")

        let name = prompt("Package name: ", Path.basename(cwd))
        let entryPoint = prompt("Entry point: ", "index.ts")

        // 选择项目类型
        Output.prettyln("\nProject type:")
        Output.prettyln("  1. blank       (empty project)")
        Output.prettyln("  2. minimal     (package.json + tsconfig)")
        Output.prettyln("  3. library     (package with build)")
        Output.prettyln("  4. react       (React app)")
        Output.prettyln("  5. next        (Next.js app)")

        let typeStr = prompt("Select (1-5): ", "1")
        let projectType = match (typeStr) {
            case "2" => ProjectType.minimal
            case "3" => ProjectType.library
            case "4" => ProjectType.react
            case "5" => ProjectType.next
            case _ => ProjectType.blank
        }

        createProject(cwd, name, entryPoint, projectType)
    }

    /// 交互式提示
    public static func prompt(label: String, default: String): String {
        Output.pretty(label)
        if (default.size > 0) {
            Output.pretty("(${default}): ")
        }
        Output.flush()

        // TODO: implement with proper stdin reading
        return default
    }

    /// 创建空白项目（-y 标志）
    static func initBlank(cwd: String): Unit {
        createPackageJson(cwd, Path.basename(cwd), "index.ts")
        createTsconfig(cwd)
        createIndexFile(cwd, "index.ts")

        Output.prettyln("Done! A blank project has been created in ${cwd}")
        Output.prettyln("\nTo get started, run:")
        Output.prettyln("  bun run index.ts")
    }

    /// 创建项目
    static func createProject(cwd: String, name: String, entryPoint: String, projectType: ProjectType): Unit {
        createPackageJson(cwd, name, entryPoint)

        match (projectType) {
            case ProjectType.blank =>
                createIndexFile(cwd, entryPoint)
            case ProjectType.minimal =>
                createTsconfig(cwd)
                createIndexFile(cwd, entryPoint)
            case ProjectType.library =>
                createTsconfig(cwd)
                createLibIndex(cwd, entryPoint)
            case ProjectType.react =>
                createReactProject(cwd, name)
            case ProjectType.next =>
                createNextProject(cwd, name)
        }

        Output.prettyln("\nDone! Project '${name}' has been created in ${cwd}")
        Output.prettyln("\nTo get started, run:")
        Output.prettyln("  bun run ${entryPoint}")
    }

    /// 创建 package.json
    static func createPackageJson(cwd: String, name: String, entryPoint: String): Unit {
        let path = Path.join(cwd, "package.json")
        if (BaoFile.exists(path)) {
            Output.prettyln("package.json already exists, skipping")
            return
        }

        let content = StringBuilder()
        content.append("{\n")
        content.append("  \"name\": \"${name}\",\n")
        content.append("  \"version\": \"1.0.0\",\n")
        content.append("  \"private\": true,\n")
        content.append("  \"module\": \"${entryPoint}\",\n")
        content.append("  \"type\": \"module\",\n")
        content.append("  \"scripts\": {\n")
        content.append("    \"dev\": \"bun run --watch ${entryPoint}\",\n")
        content.append("    \"start\": \"bun run ${entryPoint}\"\n")
        content.append("  }\n")
        content.append("}\n")

        BaoFile.writeAllText(path, content.toString())
    }

    /// 创建 tsconfig.json
    static func createTsconfig(cwd: String): Unit {
        let path = Path.join(cwd, "tsconfig.json")
        if (BaoFile.exists(path)) { return }

        let content = StringBuilder()
        content.append("{\n")
        content.append("  \"compilerOptions\": {\n")
        content.append("    \"target\": \"ESNext\",\n")
        content.append("    \"module\": \"ESNext\",\n")
        content.append("    \"moduleResolution\": \"bundler\",\n")
        content.append("    \"strict\": true,\n")
        content.append("    \"skipLibCheck\": true,\n")
        content.append("    \"noEmit\": true,\n")
        content.append("    \"jsx\": \"react-jsx\",\n")
        content.append("    \"allowImportingTsExtensions\": true\n")
        content.append("  },\n")
        content.append("  \"include\": [\"**/*\"]\n")
        content.append("}\n")

        BaoFile.writeAllText(path, content.toString())
    }

    /// 创建入口文件
    static func createIndexFile(cwd: String, entryPoint: String): Unit {
        let path = Path.join(cwd, entryPoint)
        if (BaoFile.exists(path)) { return }

        let content = "console.log(\"Hello via Bun!\");\n"
        BaoFile.writeAllText(path, content)
    }

    /// 创建库入口文件
    static func createLibIndex(cwd: String, entryPoint: String): Unit {
        let path = Path.join(cwd, entryPoint)
        if (BaoFile.exists(path)) { return }

        let content = StringBuilder()
        content.append("// Library entry point\n")
        content.append("export function hello(name: string): string {\n")
        content.append("  return \"Hello, \" + name + \"!\";\n")
        content.append("}\n")

        BaoFile.writeAllText(path, content.toString())
    }

    /// 创建 React 项目
    static func createReactProject(cwd: String, name: String): Unit {
        createTsconfig(cwd)

        // 创建 src 目录
        let srcDir = Path.join(cwd, "src")
        BaoFile.mkdir(srcDir, true)

        // index.html
        let html = StringBuilder()
        html.append("<!DOCTYPE html>\n")
        html.append("<html lang=\"en\">\n")
        html.append("<head><meta charset=\"UTF-8\"><title>${name}</title></head>\n")
        html.append("<body><div id=\"root\"></div><script src=\"./src/index.tsx\"></script></body>\n")
        html.append("</html>\n")
        BaoFile.writeAllText(Path.join(cwd, "index.html"), html.toString())

        // index.tsx
        let tsx = StringBuilder()
        tsx.append("import { render } from \"react-dom/client\";\n")
        tsx.append("import App from \"./App\";\n\n")
        tsx.append("const root = render(document.getElementById(\"root\")!);\n")
        tsx.append("root.render(<App />);\n")
        BaoFile.writeAllText(Path.join(srcDir, "index.tsx"), tsx.toString())

        // App.tsx
        let app = StringBuilder()
        app.append("export default function App() {\n")
        app.append("  return <h1>Hello via Bun + React!</h1>;\n")
        app.append("}\n")
        BaoFile.writeAllText(Path.join(srcDir, "App.tsx"), app.toString())

        Output.prettyln("To install React dependencies, run:")
        Output.prettyln("  bun add react react-dom")
    }

    /// 创建 Next.js 项目
    static func createNextProject(cwd: String, name: String): Unit {
        Output.prettyln("For Next.js projects, we recommend using:")
        Output.prettyln("  bunx create-next-app ${name}")
    }
}
