// 严格翻译自: src/cli/open.zig
package bao_cli

import bao_core.*

// ============================================================================
// Open — URL 打开器和编辑器检测
// 严格翻译自: src/cli/open.zig
// ============================================================================

/// URL 打开器程序路径
/// 对应 Bun: opener (编译时常量)
public let OPENER_MACOS = "/usr/bin/open"
public let OPENER_WINDOWS = "start"
public let OPENER_LINUX = "xdg-open"

/// 获取当前平台的 URL 打开器
public func getOpener(): String {
    if (Environment.isMac) {
        return OPENER_MACOS
    } else if (Environment.isWindows) {
        return OPENER_WINDOWS
    } else {
        return OPENER_LINUX
    }
}

/// 回退方案: 打印 URL
/// 对应 Bun: fallback()
private func fallback(url: String): Unit {
    Output.println("-> ${url}")
    Output.flush()
}

/// 打开 URL
/// 对应 Bun: openURL()
public func openURL(url: String): Unit {
    if (Environment.isWasi) {
        fallback(url)
        return
    }

    val args: ArrayList<String> = ArrayList<String>()
    if (Environment.isAndroid) {
        args.append("/system/bin/am")
        args.append("start")
        args.append("-a")
        args.append("android.intent.action.VIEW")
        args.append("-d")
        args.append(url)
    } else {
        args.append(getOpener())
        args.append(url)
    }

    val result = Sys.spawnSync(args, null, Stdio.inherit, Stdio.inherit, Stdio.inherit)
    match (result) {
        case Some(procResult) => {
            if (procResult.isOK()) {
                return
            }
        }
        case None => {}
    }

    // 失败时回退到打印 URL
    fallback(url)
}

/// 编辑器类型枚举
/// 对应 Bun: Editor enum
public enum Editor {
    | none
    | sublime
    | vscode
    | atom
    | textmate
    | intellij
    | webstorm
    | vim
    | neovim
    | emacs
    | other

    /// 根据名称查找编辑器
    /// 对应 Bun: Editor.byName()
    public static func byName(name: String): ?Editor {
        // 处理名称中包含空格的情况 (如路径)
        val cleanName = if (name.indexOf(' ') >= 0) {
            name.substring(0, name.indexOf(' '))
        } else {
            name
        }

        return EditorNameMap.get(cleanName)
    }

    /// 从环境变量检测编辑器
    /// 对应 Bun: Editor.detect()
    public static func detect(env: DotEnvLoader): ?Editor {
        val varNames = ["EDITOR", "VISUAL"]
        for (varName in varNames) {
            val value = env.get(varName)
            if (value != None) {
                val basename = Path.basename(value!)
                val editor = byName(basename)
                if (editor != None) {
                    return editor
                }
            }
        }
        return None
    }

    /// 从 PATH 查找编辑器
    /// 对应 Bun: Editor.byPATH()
    public static func byPATH(env: DotEnvLoader, cwd: String): ?Editor {
        val pathEnv = env.get("PATH") ?: return None

        for (editor in defaultPreferenceList) {
            val binName = binNameFor(editor)
            if (binName.length > 0) {
                val bin = Which.which(pathEnv, cwd, binName)
                if (bin != None) {
                    return Some(editor)
                }
            }
        }

        return None
    }

    /// 为指定编辑器从 PATH 查找
    /// 对应 Bun: Editor.byPATHForEditor()
    public static func byPATHForEditor(env: DotEnvLoader, editor: Editor, cwd: String): Bool {
        val pathEnv = env.get("PATH") ?: return false
        val binName = binNameFor(editor)
        if (binName.length > 0) {
            val bin = Which.which(pathEnv, cwd, binName)
            return bin != None
        }
        return false
    }

    /// 通过回退路径查找编辑器
    /// 对应 Bun: Editor.byFallbackPathForEditor()
    public static func byFallbackPathForEditor(editor: Editor): Bool {
        val paths = binPathFor(editor)
        if (paths != None) {
            for (path in paths!!) {
                if (BaoFile.exists(path)) {
                    return true
                }
            }
        }
        return false
    }

    /// 回退检测编辑器
    /// 对应 Bun: Editor.byFallback()
    public static func byFallback(env: DotEnvLoader, cwd: String): ?Editor {
        for (editor in defaultPreferenceList) {
            if (byPATHForEditor(env, editor, cwd)) {
                return Some(editor)
            }
            if (byFallbackPathForEditor(editor)) {
                return Some(editor)
            }
        }
        return None
    }

    /// 判断是否为 JetBrains 编辑器
    /// 对应 Bun: Editor.isJetBrains()
    public func isJetBrains(): Bool {
        return this == Editor.intellij || this == Editor.webstorm
    }

    /// 使用编辑器打开文件
    /// 对应 Bun: Editor.open()
    public func openFile(binary: String, file: String, line: ?String, column: ?String): Unit {
        val args = ArrayList<String>()

        // vim/emacs/neovim 需要通过终端打开
        if (this == Editor.vim || this == Editor.emacs || this == Editor.neovim) {
            args.append(getOpener())
            args.append(binary)
            if (Environment.isMac) {
                args.append("--args")
            }
        }

        args.append(binary)

        // vscode 使用 --goto 参数
        if (this == Editor.vscode && line != None && line!!.length > 0) {
            args.append("--goto")
        }

        // 构建文件路径参数
        when (this) {
            case Editor.sublime | Editor.atom | Editor.vscode | Editor.webstorm | Editor.intellij => {
                var filePath = file
                if (line != None && line!!.length > 0) {
                    filePath += ":" + line!!
                    if (!isJetBrains() && column != None && column!!.length > 0) {
                        filePath += ":" + column!!
                    }
                }
                args.append(filePath)
            }
            case Editor.textmate => {
                if (line != None && line!!.length > 0) {
                    args.append("--line")
                    var lineArg = line!!
                    if (column != None && column!!.length > 0) {
                        lineArg += ":" + column!!
                    }
                    args.append(lineArg)
                }
                args.append(file)
            }
            else => {
                if (file.length > 0) {
                    args.append(file)
                }
            }
        }

        // 启动编辑器进程
        Sys.spawnDetached(args)
    }

    /// 默认偏好顺序
    /// 对应 Bun: Editor.default_preference_list
    public static let defaultPreferenceList: Array<Editor> = [
        Editor.vscode,
        Editor.sublime,
        Editor.atom,
        Editor.neovim,
        Editor.webstorm,
        Editor.intellij,
        Editor.textmate,
        Editor.vim,
    ]
}

/// 获取编辑器的二进制名
/// 对应 Bun: Editor.bin_name
public func binNameFor(editor: Editor): String {
    when (editor) {
        case Editor.sublime => "subl"
        case Editor.vscode => "code"
        case Editor.atom => "atom"
        case Editor.textmate => "mate"
        case Editor.intellij => "idea"
        case Editor.webstorm => "webstorm"
        case Editor.vim => "vim"
        case Editor.neovim => "nvim"
        case Editor.emacs => "emacs"
        case Editor.other => ""
        case Editor.none => ""
    }
}

/// 获取编辑器的回退路径
/// 对应 Bun: Editor.bin_path
public func binPathFor(editor: Editor): ?Array<String> {
    if (!Environment.isMac) {
        return None
    }
    when (editor) {
        case Editor.vscode => Some([
            "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
            "/Applications/VSCodium.app/Contents/Resources/app/bin/code",
        ])
        case Editor.atom => Some([
            "/Applications/Atom.app/Contents/Resources/app/atom.sh",
        ])
        case Editor.sublime => Some([
            "/Applications/Sublime Text 4.app/Contents/SharedSupport/bin/subl",
            "/Applications/Sublime Text 3.app/Contents/SharedSupport/bin/subl",
            "/Applications/Sublime Text 2.app/Contents/SharedSupport/bin/subl",
            "/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl",
        ])
        else => None
    }
}

/// 编辑器名称映射表
/// 对应 Bun: Editor.name_map (ComptimeStringMap)
public class EditorNameMap {
    private static let map: HashMap<String, Editor> = {
        val m = HashMap<String, Editor>()
        m.put("sublime", Editor.sublime)
        m.put("subl", Editor.sublime)
        m.put("vscode", Editor.vscode)
        m.put("code", Editor.vscode)
        m.put("textmate", Editor.textmate)
        m.put("mate", Editor.textmate)
        m.put("atom", Editor.atom)
        m.put("idea", Editor.intellij)
        m.put("webstorm", Editor.webstorm)
        m.put("nvim", Editor.neovim)
        m.put("neovim", Editor.neovim)
        m.put("vim", Editor.vim)
        m.put("vi", Editor.vim)
        m.put("emacs", Editor.emacs)
        m
    }()

    public static func get(name: String): ?Editor {
        return map.get(name)
    }
}

/// 编辑器上下文
/// 对应 Bun: EditorContext
public class EditorContext {
    /// 检测到的编辑器
    public var editor: ?Editor

    /// 编辑器名称
    public var name: String

    /// 编辑器路径
    public var path: String

    public init() {
        editor = None
        name = ""
        path = ""
    }

    /// 自动检测编辑器 (仅在未检测时)
    /// 对应 Bun: EditorContext.autoDetectEditor()
    public func autoDetectEditor(env: DotEnvLoader): Unit {
        if (editor == None) {
            detectEditor(env)
        }
    }

    /// 检测编辑器
    /// 对应 Bun: EditorContext.detectEditor()
    public func detectEditor(env: DotEnvLoader): Unit {
        var out = ""

        // 1. 用户指定的名称
        if (name.length > 0) {
            // 绝对路径
            if (Path.isAbsolute(name)) {
                editor = Editor.byName(Path.basename(name)) ?: Editor.other
                path = name
                return
            }

            // 名称查找
            val editor_ = Editor.byName(Path.basename(name))
            if (editor_ != None) {
                if (Editor.byPATHForEditor(env, editor_!!, Fs.instance.topLevelDir)) {
                    editor = editor_
                    // path = resolved from PATH
                    return
                }
                if (Editor.byFallbackPathForEditor(editor_!!)) {
                    editor = editor_
                    return
                }
            }
        }

        // 2. EDITOR 环境变量
        val envEditor = Editor.detect(env)
        if (envEditor != None) {
            if (Editor.byPATHForEditor(env, envEditor!!, Fs.instance.topLevelDir)) {
                editor = envEditor
                return
            }
            if (Editor.byFallbackPathForEditor(envEditor!!)) {
                editor = envEditor
                return
            }
        }

        // 3. 通过 PATH 回退检测
        val fallbackEditor = Editor.byFallback(env, Fs.instance.topLevelDir)
        if (fallbackEditor != None) {
            editor = fallbackEditor
            return
        }

        editor = Editor.none
    }
}
