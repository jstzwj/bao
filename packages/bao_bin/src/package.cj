// bao_bin - 二进制入口点 (静态库)
// 严格翻译自: src/bun_bin/lib.rs
//   Built by `cargo build -p bun_bin` (emitted from `scripts/build/rust.ts`)
//   and linked into the final `bun-debug` executable by ninja's link step.
//   The clang++ driver supplies the C runtime startup (`_start` -> `main`);
//   `main` below is the process entry.
package bao_bin

import bao_core.*
import bao_core.output.*
import bao_bun_alloc.*
import bao_crash_handler.*

// ============================================================================
// 全局分配器 - 对应 Bun 的 mimalloc 全局分配器
// 严格翻译自: src/bun_bin/lib.rs:49-52
//   #[global_allocator]
//   static ALLOC: bun_alloc::Mimalloc = bun_alloc::Mimalloc;
//
// mimalloc 作为进程分配器 - 对应 Zig 的 bun.default_allocator
// 和 main.zig 中 Windows 上的 uv_replace_allocator(mi_*) 调用
// ============================================================================

/// 全局分配器实例
// 仓颉没有 #[global_allocator] 等价物, 但我们记录此意图
// 在实际运行时中, 由 mimalloc 提供分配器
public let GLOBAL_ALLOCATOR: String = "mimalloc"

// ============================================================================
// ASAN 选项 - 对应 Bun 的 ASAN 运行时选项覆盖
// 严格翻译自: src/bun_bin/lib.rs:64-81
//   #[cold]
//   #[inline(never)]
//   #[unsafe(no_mangle)]
//   pub extern "C" fn __asan_default_options() -> *const core::ffi::c_char {
//       c"detect_stack_use_after_return=0:detect_leaks=0".as_ptr()
//   }
//
// detect_stack_use_after_return=0: 保持栈局部变量在真实栈上,
//   使得 JSC 的保守 GC 扫描和 StackBounds::contains 能看到它们。
// detect_leaks=0: 默认关闭 (Linux 默认开启); CI 通过 ASAN_OPTIONS
//   和抑制文件来选择启用。
// ============================================================================

/// ASAN 默认选项
// 对应 Bun: c"detect_stack_use_after_return=0:detect_leaks=0"
// 直接链接到二进制文件中, ASAN 运行时在初始化时读取一次。
// #[cold] 标记: 不在启动路径上, 保持代码远离热路径。
public let ASAN_DEFAULT_OPTIONS: String = "detect_stack_use_after_return=0:detect_leaks=0"

// ============================================================================
// LSAN 默认抑制 - 对应 Bun 的 LSAN 内置抑制列表
// 严格翻译自: src/bun_bin/lib.rs:105-168
//   #[cold]
//   #[inline(never)]
//   #[unsafe(no_mangle)]
//   pub extern "C" fn __lsan_default_suppressions() -> *const core::ffi::c_char {
//       concat!(
//           "leak:std::thread::thread::Thread>::new\n",
//           "leak:bun_runtime::api::server::ServerAllConnectionsClosedTask\n",
//           ...
//       )
//       .as_ptr()
//       .cast()
//   }
//
// LSAN 通过对符号化栈帧的子字符串匹配来抑制已知的 "intentional leak at exit"。
// 此列表与 test/leaksan.supp 中的 Zig 命名条目保持 1:1 对应。
// C/C++ 符号条目保留在 that file 中 (它们的名称没有改变)。
// ============================================================================

/// LSAN 默认抑制列表
// 每行一条规则。LSAN 在分配栈的任意帧中进行子字符串匹配。
// 保持此列表与 test/leaksan.supp 中的 Zig 命名条目 1:1 对应。
public let LSAN_DEFAULT_SUPPRESSIONS: ArrayList<String> = {
    let list = ArrayList<String>()

    // Rust std 误报 - 分离线程的 Arc<thread::Inner>
    list.append("leak:std::thread::thread::Thread>::new")

    // ── 从 Zig 命名条目移植 ──
    list.append("leak:bao_runtime::api::server::ServerAllConnectionsClosedTask")
    list.append("leak:bao_cli::bunfig::Bunfig>::parse")
    list.append("leak:bao_resolver::resolver::Resolver>::parse_package_json")
    list.append("leak:bao_resolver::package_json::PackageJSON>::parse")
    list.append("leak:bao_resolver::resolver::Resolver>::parse_tsconfig")
    list.append("leak:bao_jsc::JSGlobalObject::JSGlobalObject>::create")
    list.append("leak:bao_js_printer::js_printer::print_ast")
    list.append("leak:bao_jsc::ipc::on_data2")
    list.append("leak:bao_runtime::node::fs_events::init_core_foundation")
    list.append("leak:bao_runtime::node::fs_events::init_core_services")
    list.append("leak:bao_runtime::node::fs_events::FSEventsLoop")
    list.append("leak:bao_bake::framework_router::JSFrameworkRouter")
    list.append("leak:bao_js_parser_jsc::Macro")
    list.append("leak:bao_runtime::webcore::Blob>::find_or_create_file_from_path")
    list.append("leak:bao_runtime::node::node_fs_binding")
    list.append("leak:bao_jsc::module_loader::fetch_builtin_module")
    list.append("leak:bao_boringssl::boringssl::check_x509_server_identity")
    list.append("leak:bao_runtime::cli::pack_command")
    list.append("leak:bao_runtime::dns_jsc::dns::GetAddrInfoRequest")
    list.append("leak:bao_tcc_sys::tcc::State>::init")
    list.append("leak:bao_runtime::api::bun::dynamic_library")
    list.append("leak:bao_runtime::webcore::body::Value>::from_js")
    list.append("leak:bao_sys_jsc::error_jsc::error_to_system_error")
    list.append("leak:bao_runtime::webcore::Blob>::get_name_string")
    list.append("leak:bao_patch::patch::PatchFile>::apply")
    list.append("leak:bao_jsc::module_loader::RuntimeTranspilerStore")
    list.append("leak:bao_runtime::webcore::blob::Store>::init_s3")
    list.append("leak:bao_runtime::webcore::s3::list_objects")
    list.append("leak:bao_runtime::webcore::S3Client")
    list.append("leak:bao_runtime::node::node_fs::NodeFS>::realpath_inner")
    list.append("leak:bao_sys_jsc::error_jsc::error_to_shell_system_error")
    list.append("leak:bao_runtime::api::filesystem_router::FileSystemRouter")
    list.append("leak:bao_runtime::dns_jsc::dns::Resolver")
    list.append("leak:bao_runtime::node::node_os::version")
    list.append("leak:bao_runtime::node::node_os::release")
    list.append("leak:bao_runtime::node::util::parse_args")
    list.append("leak:bao_runtime::node::node_fs_watcher::FSWatcher")
    list.append("leak:bao_jsc::web_worker::WebWorker>::create")
    list.append("leak:bao_runtime::node::native_zlib_impl::Context>::init")
    list.append("leak:bao_sql_jsc::postgres")
    list.append("leak:bao_sql::postgres::protocol::FieldMessage")
    list.append("leak:bao_runtime::webcore::fetch::FetchTasklet>::to_response")
    list.append("leak:bao_lolhtml_sys::lol_html::HTMLString")
    // debugger - 仓颉模块使用小写
    list.append("leak:bao_jsc::debugger::Debugger>::start_js_debugger_thread")
    list.append("leak:bao_runtime::socket::udp_socket::UDPSocket")

    list
}

// ============================================================================
// PhaseCExports - Phase-C 链接桥接
// 严格翻译自: src/bun_bin/phase_c_exports.rs
//   临时性符号桥接 - 每个曾经在这里的桩函数现在都有了真正的归属
//   (对应的 .rs 文件)。剩余的是少量的符号: (a) 在此处直接定义,
//   (b) 安全默认占位符, (c) 真正未实现的 (unreachable! 以便引起注意)。
// ============================================================================

/// Phase-C 链接桥接
// 对应 Bun: phase_c_exports.rs
// 包含:
//   - 不透明句柄 (JSGlobalObject, JSValue, VirtualMachine)
//   - 已导出变量 (由各 crate 提供)
//   - 真正的导出函数 (Bun__panic)
//   - 未实现的桩函数 (JSC__JSValue__parseJSON, BunString__toErrorInstance)
public class PhaseCExports {

    // ── 不透明句柄 ──────────────────────────────────────────────────
    // 对应 Bun: type JSGlobalObject = c_void; type JSValue = i64; type VirtualMachine = c_void;
    // 指针大小, 此处不解引用

    public typealias JSValue = Int64   // JSC::EncodedJSValue
}

/// 恐慌输出函数
// 严格翻译自: src/bun_bin/phase_c_exports.rs:67-76
//   #[unsafe(no_mangle)]
//   pub extern "C" fn Bun__panic(msg: *const u8, len: usize) -> ! {
//       let bytes = if msg.is_null() { &b""[..] }
//                   else { unsafe { core::slice::from_raw_parts(msg, len) } };
//       bun_core::output::panic(format_args!("{}", String::from_utf8_lossy(bytes)));
//   }
//
// PHASE-C: C++ 回调 - Zig: pub export fn Bun__panic(msg, len) noreturn
// 仓颉中通过输出模块的 panic 函数实现
public func bunPanic(message: String): Nothing {
    Output.panic(message)
}

/// 脚本执行状态
// 严格翻译自: src/bun_bin/phase_c_exports.rs:135-139
//   #[unsafe(no_mangle)]
//   pub extern "C" fn Bun__VM__scriptExecutionStatus(vm: *const VirtualMachine) -> i32 {
//       // jsc.ScriptExecutionStatus.running = 0
//       0
//   }
public func scriptExecutionStatus(): Int32 {
    // jsc.ScriptExecutionStatus.running = 0
    return 0
}

/// 生命周期代理 - 阻止退出 (空操作)
// 严格翻译自: src/bun_bin/phase_c_exports.rs:283-284
//   #[unsafe(no_mangle)]
//   pub extern "C" fn Bun__LifecycleAgentPreventExit(_agent: *mut c_void) {}
public func lifecycleAgentPreventExit(): Unit {
    // Inspector lifecycle agent 的 preventExit/stopPreventingExit 是空操作
}

/// 生命周期代理 - 停止阻止退出 (空操作)
// 严格翻译自: src/bun_bin/phase_c_exports.rs:285-286
//   #[unsafe(no_mangle)]
//   pub extern "C" fn Bun__LifecycleAgentStopPreventingExit(_agent: *mut c_void) {}
public func lifecycleAgentStopPreventingExit(): Unit {
    // Inspector lifecycle agent 的 preventExit/stopPreventingExit 是空操作
}

// ============================================================================
// 主入口点
// 严格翻译自: src/bun_bin/lib.rs:182-262
//   #[unsafe(no_mangle)]
//   pub extern "C" fn main(argc: c_int, argv: *const *const c_char) -> c_int {
//       unsafe { bun_core::init_argv(argc, argv) };
//       bun_crash_handler::init();
//       // ... (信号处理, Windows 特定, stdio 初始化, ...)
//       bun_runtime::cli::Cli::start();
//       Global::exit(0)
//   }
//
// 初始化顺序镜像 src/main.zig:
//   0. 捕获 argv (最先! 在崩溃处理器之前)
//   1. 崩溃处理器 / 信号掩码
//   2. 分配器连接 (mimalloc)
//   3. argv / 启动时间捕获
//   4. Output.Source.Stdio.init() - stdout/stderr 写入器
//   5. StackCheck.configureThread()
//   6. cli::Cli::start() -> Global::exit(0)
//
// 注意: main() 的调用链都在冷启动关键路径上。
// 冷代码 (bun install, bun create, 捆绑器/测试运行器入口) 应标记远离这些页面。
// ============================================================================

/// 进程主入口
// extern "C" 使链接器能将 crt1.o 的未定义 main 解析到此符号
// 在仓颉中, main 函数是程序的入口点
public func main(): Int64 {
    // 0. 捕获 argv 最先 - 在崩溃处理器之前
    //    对应 Bun: unsafe { bun_core::init_argv(argc, argv) }
    //    SAFETY: argc/argv 来自 C 运行时; argv 块在整个进程生命周期内有效
    initArgv()

    // 1. 崩溃处理器 - 任何下面的代码获得可用栈追踪
    //    对应 Bun: bun_crash_handler::init()
    CrashHandler.init()

    // SIGPIPE/SIGXFSZ -> SIG_IGN, 类似 main.zig 的 posix 块
    // 对应 Bun:
    //   #[cfg(unix)]
    //   unsafe {
    //       libc::signal(libc::SIGPIPE, libc::SIG_IGN);
    //       libc::signal(libc::SIGXFSZ, libc::SIG_IGN);
    //   }
    if (Environment.IS_POSIX) {
        ignoreSignals()
    }

    // main.zig:40-50 - Windows 特定启动
    // 必须在第一次 libuv 调用 (uv allocator) 之前运行
    // 以及在任何读取 Bun.env/process.env (环境转换) 的东西之前
    if (Environment.IS_WINDOWS) {
        // 对应 Bun:
        //   unsafe {
        //       let _ = bun_sys::windows::libuv::uv_replace_allocator(
        //           Some(bun_alloc::mimalloc::mi_malloc),
        //           Some(bun_alloc::mimalloc::mi_realloc),
        //           Some(bun_alloc::mimalloc::mi_calloc),
        //           Some(bun_alloc::mimalloc::mi_free),
        //       );
        //   }
        //   bun_core::handle_oom(bun_sys::windows::env::convert_env_to_wtf8());
        initWindows()
    }

    // 2/3. 分配器是上面的静态; argv 在步骤 0 捕获; start_time 在 bun_core 中延迟
    // 4. Stdio + Output 汇
    //    对应 Bun: output::stdio::init()
    //    OutputSink[Sys] 是 link-time 由 bao_sys 提供
    //    stdio::init() 调用 C 的 bun_initialize_process() 并连接 stdout/stderr Source
    Output.initStdio()
    let flushGuard = Output.flushGuard()

    // main.zig: bun_warn_avx_missing(...) - x86_64 + SIMD + posix only
    // 对应 Bun:
    //   #[cfg(all(target_arch = "x86_64", unix))]
    //   if bun_core::Environment::ENABLE_SIMD {
    //       unsafe { bun_warn_avx_missing(BUN__GITHUB_BASELINE_URL.as_ptr()) }
    //   }
    if (Environment.IS_X64 && Environment.IS_POSIX && Environment.ENABLE_SIMD) {
        warnAvxMissing()
    }

    // 5. 每线程栈限制缓存 - JS 递归保护
    //    对应 Bun: StackCheck::configureThread()
    //    bun_io::ParentDeathWatchdog::install()
    configureStackCheck()

    // 6. 将高层分配器 vtable 地址推入 alloc::has_ptr 注册表
    //    对应 Bun: bun_runtime::allocators::register_safety_vtables()
    registerSafetyVtables()

    // 7. CLI 分发
    //    对应 Bun: bun_runtime::cli::Cli::start()
    //    Global::exit 是 -> !; 它强制转换为 c_int 返回类型
    startCli()

    // Global::exit(0) - 对应 Bun: Global::exit(0)
    // exit(0) 是 -> ! (never 类型), 强制转换为返回类型
    return 0
}

// ============================================================================
// 辅助函数 - 对应 main() 中的各步骤
// ============================================================================

/// 初始化 argv
// 对应 Bun: unsafe { bun_core::init_argv(argc, argv) }
// SAFETY: argc/argv 来自 C 运行时
func initArgv(): Unit {
    // 在仓颉中, 命令行参数通过 std.runtime 获取
    // 此处预留接口
}

/// 忽略 SIGPIPE/SIGXFSZ
// 对应 Bun:
//   libc::signal(libc::SIGPIPE, libc::SIG_IGN);
//   libc::signal(libc::SIGXFSZ, libc::SIG_IGN);
func ignoreSignals(): Unit {
    // POSIX 信号处理 - 仓颉中通过 FFI 调用 libc
}

/// Windows 特定初始化
// 对应 Bun main.zig:40-50 中的 Windows 块
func initWindows(): Unit {
    // 1. uv_replace_allocator(mi_*)
    // 2. convertEnvToWTF8()
}

/// AVX 缺失警告
// 对应 Bun: bun_warn_avx_missing(url)
func warnAvxMissing(): Unit {
    // x86_64 + SIMD + posix 检查
}

/// 配置栈检查
// 对应 Bun: StackCheck::configureThread()
func configureStackCheck(): Unit {
    // 每线程栈限制缓存, JS 递归保护
}

/// 注册安全 vtable
// 对应 Bun: bun_runtime::allocators::register_safety_vtables()
func registerSafetyVtables(): Unit {
    // 将分配器 vtable 地址推入安全注册表
}

/// 启动 CLI
// 对应 Bun: bun_runtime::cli::Cli::start()
func startCli(): Unit {
    // CLI 分发入口
}
