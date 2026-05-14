#!/usr/bin/env python3
"""
Bao 项目验证脚本
验证仓颉项目结构、包依赖、文件完整性
"""

import os
import sys
import json
from pathlib import Path

# 项目根目录
ROOT = Path(__file__).parent.parent
PACKAGES_DIR = ROOT / "packages"
DOCS_DIR = ROOT / "docs"
TOOLS_DIR = ROOT / "tools"
TEST_DIR = ROOT / "test"

# 颜色输出
def green(s): return f"\033[92m{s}\033[0m"
def red(s): return f"\033[91m{s}\033[0m"
def yellow(s): return f"\033[93m{s}\033[0m"
def bold(s): return f"\033[1m{s}\033[0m"

# 统计
errors = 0
warnings = 0
passed = 0

def check(condition, msg, level="error"):
    global errors, warnings, passed
    if condition:
        print(green(f"  [PASS] {msg}"))
        passed += 1
    elif level == "error":
        print(red(f"  [FAIL] {msg}"))
        errors += 1
    elif level == "warn":
        print(yellow(f"  [WARN] {msg}"))
        warnings += 1

def validate_phase0():
    """验证 Phase 0: 项目骨架"""
    print(bold("\n=== Phase 0: 项目骨架搭建 ==="))

    # 根 cjpm.toml
    check((ROOT / "cjpm.toml").exists(), "根 cjpm.toml 存在")

    # 文档
    for doc in ["plan.md", "architecture.md", "ffi-bridge.md", "translation-guide.md"]:
        check((DOCS_DIR / doc).exists(), f"文档 {doc} 存在")

    # 工具脚本
    check((TOOLS_DIR / "validate.py").exists(), "验证脚本存在")

    # 包结构
    expected_packages = [
        "bao_core", "bao_collections", "bao_unicode", "bao_hash",
        "bao_path", "bao_sys", "bao_io", "bao_threading", "bao_event_loop",
        "bao_parser", "bao_runtime", "bao_http", "bao_bundler",
        "bao_install", "bao_sql", "bao_cli"
    ]
    for pkg in expected_packages:
        pkg_dir = PACKAGES_DIR / pkg
        check(pkg_dir.exists(), f"包 {pkg} 目录存在")
        check((pkg_dir / "cjpm.toml").exists(), f"包 {pkg}/cjpm.toml 存在")
        check((pkg_dir / "src").exists(), f"包 {pkg}/src 目录存在")

def validate_phase1():
    """验证 Phase 1: 基础工具库"""
    print(bold("\n=== Phase 1: 基础工具库 ==="))

    # bao_core
    core_src = PACKAGES_DIR / "bao_core" / "src"
    check(core_src.exists(), "bao_core/src 存在")
    for f in ["package.cj", "string.cj", "result.cj", "alloc.cj", "ptr.cj"]:
        check((core_src / f).exists(), f"bao_core/src/{f} 存在")

    # bao_collections
    coll_src = PACKAGES_DIR / "bao_collections" / "src"
    check(coll_src.exists(), "bao_collections/src 存在")
    check((coll_src / "package.cj").exists(), "bao_collections/src/package.cj 存在")

    # 验证 HashMap 和 HashSet 实现
    coll_content = (coll_src / "package.cj").read_text() if (coll_src / "package.cj").exists() else ""
    check("class HashMap" in coll_content, "HashMap<K,V> 类已实现")
    check("class HashSet" in coll_content, "HashSet<T> 类已实现")
    check("func put(" in coll_content, "HashMap.put() 方法存在")
    check("func get(" in coll_content, "HashMap.get() 方法存在")
    check("func contains(" in coll_content, "HashMap.contains() 方法存在")
    check("func remove(" in coll_content, "HashMap.remove() 方法存在")
    check("func keys(" in coll_content, "HashMap.keys() 方法存在")
    check("func values(" in coll_content, "HashMap.values() 方法存在")

    # bao_unicode
    uni_src = PACKAGES_DIR / "bao_unicode" / "src"
    check((uni_src / "package.cj").exists(), "bao_unicode/src/package.cj 存在")
    uni_content = (uni_src / "package.cj").read_text() if (uni_src / "package.cj").exists() else ""
    check("ExtendedPictographic" in uni_content, "Unicode ExtendedPictographic 属性已定义")
    check("EmojiModifier" in uni_content, "Unicode EmojiModifier 属性已定义")
    check("IndicConjunct" in uni_content, "Unicode IndicConjunct 属性已定义")
    check("isExtendedPictographic" in uni_content, "isExtendedPictographic() 函数已实现")

    # bao_hash
    hash_src = PACKAGES_DIR / "bao_hash" / "src"
    check((hash_src / "package.cj").exists(), "bao_hash/src/package.cj 存在")
    hash_content = (hash_src / "package.cj").read_text() if (hash_src / "package.cj").exists() else ""
    check("WyHash" in hash_content, "WyHash 算法已实现")
    check("Highway" in hash_content, "HighwayHash 算法已实现")

def validate_phase2():
    """验证 Phase 2: 平台层"""
    print(bold("\n=== Phase 2: 平台层 ==="))

    phase2_packages = {
        "bao_path": ["package.cj"],
        "bao_sys": ["package.cj"],
        "bao_io": ["package.cj"],
        "bao_threading": ["package.cj"],
        "bao_event_loop": ["package.cj"],
    }
    for pkg, files in phase2_packages.items():
        pkg_src = PACKAGES_DIR / pkg / "src"
        check(pkg_src.exists(), f"{pkg}/src 存在")
        for f in files:
            check((pkg_src / f).exists(), f"{pkg}/src/{f} 存在")

    # 验证 C FFI 绑定
    sys_content = (PACKAGES_DIR / "bao_sys" / "src" / "package.cj").read_text() \
        if (PACKAGES_DIR / "bao_sys" / "src" / "package.cj").exists() else ""
    check("@C" in sys_content or "foreign" in sys_content, "bao_sys 包含 C FFI 声明")

def validate_phase3():
    """验证 Phase 3: 解析器"""
    print(bold("\n=== Phase 3: 解析器 ==="))

    parser_src = PACKAGES_DIR / "bao_parser" / "src"
    check(parser_src.exists(), "bao_parser/src 存在")

    # 必要文件
    for f in ["package.cj", "lexer.cj", "parser.cj", "ast.cj", "token.cj", "printer.cj"]:
        check((parser_src / f).exists(), f"bao_parser/src/{f} 存在")

    # 验证 Printer 实现
    printer_content = (parser_src / "printer.cj").read_text() \
        if (parser_src / "printer.cj").exists() else ""
    check("class Printer" in printer_content, "Printer 类已实现")
    check("printStmt" in printer_content, "printStmt() 方法存在")
    check("printExpr" in printer_content, "printExpr() 方法存在")
    check("printProgram" in printer_content, "printProgram() 方法存在")
    check("StmtTag.Block" in printer_content, "Printer 处理 Block 语句")
    check("StmtTag.If" in printer_content, "Printer 处理 If 语句")
    check("ExprTag.Binary" in printer_content, "Printer 处理 Binary 表达式")
    check("ExprTag.Call" in printer_content, "Printer 处理 Call 表达式")

    # 验证 TypeScript 解析
    parser_content = (parser_src / "parser.cj").read_text() \
        if (parser_src / "parser.cj").exists() else ""
    check("tryParseTypeScriptStmt" in parser_content, "TypeScript 语句解析已实现")
    check("parseTsInterfaceStmt" in parser_content, "Interface 解析已实现")
    check("parseTsTypeAliasStmt" in parser_content, "Type 别名解析已实现")
    check("parseTsEnumStmt" in parser_content, "Enum 解析已实现")
    check("parseTsNamespaceStmt" in parser_content, "Namespace 解析已实现")
    check("parseTsDeclareStmt" in parser_content, "Declare 解析已实现")
    check("skipTsType" in parser_content, "Type 类型跳过函数已实现")
    check("skipTsTypeAnnotation" in parser_content, "类型注解跳过函数已实现")

def validate_tests():
    """验证测试框架"""
    print(bold("\n=== 测试框架 ==="))

    test_packages = ["test_core", "test_hash", "test_collections", "test_parser"]
    for pkg in test_packages:
        test_dir = TEST_DIR / pkg
        check(test_dir.exists(), f"测试目录 {pkg} 存在", "warn")

    # 检查至少有一些测试文件
    test_files = list(TEST_DIR.rglob("*.cj"))
    check(len(test_files) > 0, f"发现 {len(test_files)} 个测试文件")

def validate_phase4():
    """验证 Phase 4: JavaScript 运行时"""
    print(bold("\n=== Phase 4: JavaScript 运行时 ==="))

    rt_src = PACKAGES_DIR / "bao_runtime" / "src"

    # 核心运行时文件
    for f in ["package.cj", "vm.cj", "module.cj"]:
        check((rt_src / f).exists(), f"bao_runtime/src/{f} 存在")

    # JSC FFI
    for f in ["jsc_ffi.cj", "js_value.cj"]:
        check((rt_src / "jsc" / f).exists(), f"bao_runtime/src/jsc/{f} 存在")

    # Node.js API
    for f in ["fs.cj", "path.cj", "process.cj", "events.cj"]:
        check((rt_src / "node_api" / f).exists(), f"bao_runtime/src/node_api/{f} 存在")

    # Web API
    for f in ["console.cj", "url.cj", "timers.cj"]:
        check((rt_src / "web_api" / f).exists(), f"bao_runtime/src/web_api/{f} 存在")

    # 验证核心实现
    vm_content = (rt_src / "vm.cj").read_text() if (rt_src / "vm.cj").exists() else ""
    check("class Interpreter" in vm_content, "Interpreter 类已实现")
    check("class Environment" in vm_content, "Environment 作用域类已实现")
    check("class JsFunction" in vm_content, "JsFunction 函数类已实现")
    check("evalExpr" in vm_content, "evalExpr() 表达式求值已实现")
    check("execStmt" in vm_content, "execStmt() 语句执行已实现")
    check("callFunction" in vm_content, "callFunction() 函数调用已实现")

    # 验证 JsValue 增强
    pkg_content = (rt_src / "package.cj").read_text() if (rt_src / "package.cj").exists() else ""
    check("objectData" in pkg_content, "JsValue.objectData 字段存在")
    check("arrayData" in pkg_content, "JsValue.arrayData 字段存在")
    check("functionData" in pkg_content, "JsValue.functionData 字段存在")
    check("nativeFnData" in pkg_content, "JsValue.nativeFnData 字段存在")
    check("static func array(" in pkg_content, "JsValue.array() 工厂方法存在")
    check("static func function(" in pkg_content, "JsValue.function() 工厂方法存在")
    check("static func nativeFunction(" in pkg_content, "JsValue.nativeFunction() 工厂方法存在")

    # 验证模块系统
    mod_content = (rt_src / "module.cj").read_text() if (rt_src / "module.cj").exists() else ""
    check("class ModuleLoader" in mod_content, "ModuleLoader 类已实现")
    check("class ModuleResolver" in mod_content, "ModuleResolver 类已实现")
    check("class BuiltinModules" in mod_content, "BuiltinModules 内置模块注册已实现")
    check("func require(" in mod_content, "require() CJS 加载已实现")

    # 验证 VirtualMachine 使用 Interpreter
    check("interpreter" in pkg_content, "VirtualMachine 使用 Interpreter")

    # 验证 Node.js API
    fs_content = (rt_src / "node_api" / "fs.cj").read_text() if (rt_src / "node_api" / "fs.cj").exists() else ""
    check("class FsModule" in fs_content, "FsModule 类已实现")
    check("readFileSync" in fs_content, "fs.readFileSync 已实现")
    check("writeFileSync" in fs_content, "fs.writeFileSync 已实现")
    check("toJsValue" in fs_content, "FsModule.toJsValue() 已实现")

    path_content = (rt_src / "node_api" / "path.cj").read_text() if (rt_src / "node_api" / "path.cj").exists() else ""
    check("class PathModule" in path_content, "PathModule 类已实现")
    check("func join(" in path_content, "path.join 已实现")
    check("func resolve(" in path_content, "path.resolve 已实现")

    process_content = (rt_src / "node_api" / "process.cj").read_text() if (rt_src / "node_api" / "process.cj").exists() else ""
    check("class ProcessModule" in process_content, "ProcessModule 类已实现")
    check("func cwd(" in process_content, "process.cwd 已实现")
    check("func exit(" in process_content, "process.exit 已实现")

    events_content = (rt_src / "node_api" / "events.cj").read_text() if (rt_src / "node_api" / "events.cj").exists() else ""
    check("class EventEmitter" in events_content, "EventEmitter 类已实现")
    check("func on(" in events_content, "EventEmitter.on 已实现")
    check("func emit(" in events_content, "EventEmitter.emit 已实现")

    # 验证 Web API
    console_content = (rt_src / "web_api" / "console.cj").read_text() if (rt_src / "web_api" / "console.cj").exists() else ""
    check("class ConsoleModule" in console_content, "ConsoleModule 类已实现")
    check("func log(" in console_content, "console.log 已实现")
    check("func time(" in console_content, "console.time 已实现")

    url_content = (rt_src / "web_api" / "url.cj").read_text() if (rt_src / "web_api" / "url.cj").exists() else ""
    check("class BaoUrl" in url_content, "URL 类已实现")
    check("class URLSearchParams" in url_content, "URLSearchParams 类已实现")

    timers_content = (rt_src / "web_api" / "timers.cj").read_text() if (rt_src / "web_api" / "timers.cj").exists() else ""
    check("class TimerManager" in timers_content, "TimerManager 类已实现")
    check("class TimersModule" in timers_content, "TimersModule 类已实现")
    check("registerGlobals" in timers_content, "TimersModule.registerGlobals 已实现")

def validate_phase5():
    """验证 Phase 5: 应用层"""
    print(bold("\n=== Phase 5: 应用层 ==="))

    # bao_http
    http_src = PACKAGES_DIR / "bao_http" / "src"
    check((http_src / "package.cj").exists(), "bao_http/src/package.cj 存在")
    http_content = (http_src / "package.cj").read_text() if (http_src / "package.cj").exists() else ""
    check("class HttpServer" in http_content, "HttpServer 类已实现")
    check("class HttpClient" in http_content, "HttpClient 类已实现")
    check("class Request" in http_content, "Request 类已实现")
    check("class Response" in http_content, "Response 类已实现")
    check("class Headers" in http_content, "Headers 类已实现")
    check("class ParsedUrl" in http_content, "ParsedUrl URL解析已实现")
    check("class HttpStatus" in http_content, "HttpStatus 状态码已实现")
    check("class FormData" in http_content, "FormData 类已实现")
    check("class Blob" in http_content, "Blob 类已实现")
    check("class FetchOptions" in http_content, "FetchOptions 类已实现")
    check("func fetch(" in http_content, "fetch() 已实现")
    check("func text(" in http_content, "Request.text() 已实现")

    # bao_bundler
    bundler_src = PACKAGES_DIR / "bao_bundler" / "src"
    check((bundler_src / "package.cj").exists(), "bao_bundler/src/package.cj 存在")
    bundler_content = (bundler_src / "package.cj").read_text() if (bundler_src / "package.cj").exists() else ""
    check("class Bundler" in bundler_content, "Bundler 类已实现")
    check("class Resolver" in bundler_content, "Resolver 类已实现")
    check("class BundleResult" in bundler_content, "BundleResult 类已实现")
    check("extractDependencies" in bundler_content, "extractDependencies() 已实现")
    check("extractRequireSpecifier" in bundler_content, "require() 依赖提取已实现")
    check("topologicalSort" in bundler_content, "topologicalSort() 拓扑排序已实现")
    check("bundleToString" in bundler_content, "bundleToString() 便捷方法已实现")
    check("PrintOptions" in bundler_content, "Printer 集成已实现")
    check("__bao_modules" in bundler_content, "模块注册表运行时已实现")

    # bao_install
    install_src = PACKAGES_DIR / "bao_install" / "src"
    check((install_src / "package.cj").exists(), "bao_install/src/package.cj 存在")
    install_content = (install_src / "package.cj").read_text() if (install_src / "package.cj").exists() else ""
    check("class PackageManager" in install_content, "PackageManager 类已实现")
    check("class SemVer" in install_content, "SemVer 版本类已实现")
    check("class JsonParser" in install_content, "JsonParser JSON解析器已实现")
    check("enum JsonValue" in install_content or "JsonValue" in install_content, "JsonValue JSON值类型已实现")
    check("class JsonHelper" in install_content, "JsonHelper JSON工具类已实现")
    check("func satisfies(" in install_content, "SemVer.satisfies() 范围匹配已实现")
    check("readPackageJson" in install_content, "readPackageJson() 已实现")
    check("writePackageJson" in install_content, "writePackageJson() 已实现")
    check("resolveDependencies" in install_content, "resolveDependencies() 已实现")
    check("downloadPackages" in install_content, "downloadPackages() 已实现")
    check("writeLockfile" in install_content, "writeLockfile() 已实现")
    check("readLockfile" in install_content, "readLockfile() 已实现")

    # bao_sql
    sql_src = PACKAGES_DIR / "bao_sql" / "src"
    check((sql_src / "package.cj").exists(), "bao_sql/src/package.cj 存在")
    sql_content = (sql_src / "package.cj").read_text() if (sql_src / "package.cj").exists() else ""
    check("class SQLiteDatabase" in sql_content, "SQLiteDatabase 类已实现")
    check("class SQLiteStatement" in sql_content, "SQLiteStatement 类已实现")
    check("class SQLiteConstants" in sql_content, "SQLiteConstants 常量已定义")
    check("sqlite3_open" in sql_content, "sqlite3_open FFI 声明已定义")
    check("sqlite3_exec" in sql_content, "sqlite3_exec FFI 声明已定义")
    check("sqlite3_prepare_v2" in sql_content, "sqlite3_prepare_v2 FFI 声明已定义")
    check("sqlite3_step" in sql_content, "sqlite3_step FFI 声明已定义")
    check("interface Database" in sql_content, "Database 接口已定义")
    check("interface Statement" in sql_content, "Statement 接口已定义")

    # bao_cli
    cli_src = PACKAGES_DIR / "bao_cli" / "src"
    check((cli_src / "package.cj").exists(), "bao_cli/src/package.cj 存在")
    cli_content = (cli_src / "package.cj").read_text() if (cli_src / "package.cj").exists() else ""
    check("class CliParser" in cli_content, "CliParser 参数解析器已实现")
    check("func main(" in cli_content, "main() 入口函数已实现")
    check("executeRun" in cli_content, "executeRun() 已实现")
    check("executeBuild" in cli_content, "executeBuild() 已实现")
    check("executeInstall" in cli_content, "executeInstall() 已实现")
    check("executeTest" in cli_content, "executeTest() 已实现")
    check("executeInit" in cli_content, "executeInit() 已实现")
    check("executeRepl" in cli_content, "executeRepl() REPL模式已实现")
    check("findTestFiles" in cli_content, "findTestFiles() 测试文件查找已实现")
    check("readPackageJson" in cli_content, "readPackageJson() package.json读取已实现")
    check("Command.Repl" in cli_content, "REPL 命令已定义")

def main():
    print(bold("=" * 60))
    print(bold("  Bao 项目验证工具"))
    print(bold("=" * 60))

    validate_phase0()
    validate_phase1()
    validate_phase2()
    validate_phase3()
    validate_phase4()
    validate_phase5()
    validate_tests()

    print(bold("\n" + "=" * 60))
    print(bold(f"  结果: {green(f'{passed} 通过')} | {red(f'{errors} 失败')} | {yellow(f'{warnings} 警告')}"))
    print(bold("=" * 60))

    return 0 if errors == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
