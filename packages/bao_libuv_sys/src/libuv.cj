// 严格翻译自: src/libuv_sys/libuv.zig
package bao_libuv_sys

// ============================================================================
// libuv FFI 函数声明
// 严格翻译自: libuv.zig 中所有 pub extern fn
// ============================================================================

// --- 版本信息 ---
foreign func uv_version(): UInt32
foreign func uv_version_string(): CString

// --- 内存分配器 ---
foreign func uv_library_shutdown(): Unit
foreign func uv_replace_allocator(malloc_func: UvMallocFunc, realloc_func: UvReallocFunc, calloc_func: UvCallocFunc, free_func: UvFreeFunc): Int32

// --- Loop 管理 ---
foreign func uv_loop_init(loop: CPointer<Unit>): Int32
foreign func uv_loop_close(loop: CPointer<Unit>): Int32
foreign func uv_loop_new(): CPointer<Unit>
foreign func uv_loop_delete(loop: CPointer<Unit>): Unit
foreign func uv_loop_size(): UIntNative
foreign func uv_loop_alive(loop: CPointer<Unit>): Int32
foreign func uv_loop_configure(loop: CPointer<Unit>, option: UInt32, ...): Int32
foreign func uv_loop_fork(loop: CPointer<Unit>): Int32
foreign func uv_run(loop: CPointer<Unit>, mode: UvRunMode): Int32
foreign func uv_stop(loop: CPointer<Unit>): Unit
foreign func uv_loop_get_data(loop: CPointer<Unit>): CPointer<Unit>
foreign func uv_loop_set_data(loop: CPointer<Unit>, data: CPointer<Unit>): Unit

// --- 引用计数 ---
foreign func uv_ref(handle: CPointer<Unit>): Unit
foreign func uv_unref(handle: CPointer<Unit>): Unit
foreign func uv_has_ref(handle: CPointer<Unit>): Int32

// --- 时间 ---
foreign func uv_update_time(loop: CPointer<Unit>): Unit
foreign func uv_now(loop: CPointer<Unit>): UInt64
foreign func uv_backend_fd(loop: CPointer<Unit>): Int32
foreign func uv_backend_timeout(loop: CPointer<Unit>): Int32

// --- 错误处理 ---
foreign func uv_translate_sys_error(sys_errno: Int32): Int32
foreign func uv_strerror(err: Int32): CString
foreign func uv_strerror_r(err: Int32, buf: CPointer<UInt8>, buflen: UIntNative): CPointer<UInt8>
foreign func uv_err_name(err: Int32): CString
foreign func uv_err_name_r(err: Int32, buf: CPointer<UInt8>, buflen: UIntNative): CPointer<UInt8>

// --- Handle 操作 ---
foreign func uv_handle_size(handle_type: UInt32): UIntNative
foreign func uv_handle_get_type(handle: CPointer<Unit>): UInt32
foreign func uv_handle_type_name(handle_type: UInt32): CPointer<UInt8>
foreign func uv_handle_get_data(handle: CPointer<Unit>): CPointer<Unit>
foreign func uv_handle_get_loop(handle: CPointer<Unit>): CPointer<Unit>
foreign func uv_handle_set_data(handle: CPointer<Unit>, data: CPointer<Unit>): Unit
foreign func uv_is_active(handle: CPointer<Unit>): Int32
foreign func uv_is_closing(handle: CPointer<Unit>): Int32
foreign func uv_close(handle: CPointer<Unit>, close_cb: UvCloseCb): Unit
foreign func uv_send_buffer_size(handle: CPointer<Unit>, value: CPointer<Int32>): Int32
foreign func uv_recv_buffer_size(handle: CPointer<Unit>, value: CPointer<Int32>): Int32
foreign func uv_fileno(handle: CPointer<Unit>, fd: CPointer<Unit>): Int32
foreign func uv_walk(loop: CPointer<Unit>, walk_cb: UvWalkCb, arg: CPointer<Unit>): Unit
foreign func uv_print_all_handles(loop: CPointer<Unit>, stream: CPointer<Unit>): Unit
foreign func uv_print_active_handles(loop: CPointer<Unit>, stream: CPointer<Unit>): Unit

// --- Request 操作 ---
foreign func uv_req_size(req_type: UInt32): UIntNative
foreign func uv_req_get_data(req: CPointer<Unit>): CPointer<Unit>
foreign func uv_req_set_data(req: CPointer<Unit>, data: CPointer<Unit>): Unit
foreign func uv_req_get_type(req: CPointer<Unit>): UInt32
foreign func uv_req_type_name(req_type: UInt32): CPointer<UInt8>
foreign func uv_cancel(req: CPointer<Unit>): Int32

// --- Buffer ---
foreign func uv_buf_init(base: CPointer<UInt8>, len: UInt32): UvBufT
foreign func uv_pipe(fds: CPointer<Int32>, read_flags: Int32, write_flags: Int32): Int32
foreign func uv_socketpair(sock_type: Int32, protocol: Int32, socket_vector: CPointer<Int32>, flags0: Int32, flags1: Int32): Int32

// --- Stream ---
foreign func uv_stream_get_write_queue_size(stream: CPointer<Unit>): UIntNative
foreign func uv_listen(stream: CPointer<Unit>, backlog: Int32, cb: UvConnectionCb): Int32
foreign func uv_accept(server: CPointer<Unit>, client: CPointer<Unit>): Int32
foreign func uv_read_start(stream: CPointer<Unit>, alloc_cb: UvAllocCb, read_cb: UvReadCb): Int32
foreign func uv_read_stop(stream: CPointer<Unit>): Int32
foreign func uv_write(req: CPointer<Unit>, handle: CPointer<Unit>, bufs: CPointer<UvBufT>, nbufs: UInt32, cb: UvWriteCb): Int32
foreign func uv_write2(req: CPointer<Unit>, handle: CPointer<Unit>, bufs: CPointer<UvBufT>, nbufs: UInt32, send_handle: CPointer<Unit>, cb: UvWriteCb): Int32
foreign func uv_try_write(handle: CPointer<Unit>, bufs: CPointer<UvBufT>, nbufs: UInt32): Int32
foreign func uv_try_write2(handle: CPointer<Unit>, bufs: CPointer<UvBufT>, nbufs: UInt32, send_handle: CPointer<Unit>): Int32
foreign func uv_is_readable(handle: CPointer<Unit>): Int32
foreign func uv_is_writable(handle: CPointer<Unit>): Int32
foreign func uv_stream_set_blocking(handle: CPointer<Unit>, blocking: Int32): Int32
foreign func uv_shutdown(req: CPointer<Unit>, handle: CPointer<Unit>, cb: UvShutdownCb): Int32

// --- TCP ---
foreign func uv_tcp_init(loop: CPointer<Unit>, handle: CPointer<Unit>): Int32
foreign func uv_tcp_init_ex(loop: CPointer<Unit>, handle: CPointer<Unit>, flags: UInt32): Int32
foreign func uv_tcp_open(handle: CPointer<Unit>, sock: Int32): Int32
foreign func uv_tcp_nodelay(handle: CPointer<Unit>, enable: Int32): Int32
foreign func uv_tcp_keepalive(handle: CPointer<Unit>, enable: Int32, delay: UInt32): Int32
foreign func uv_tcp_simultaneous_accepts(handle: CPointer<Unit>, enable: Int32): Int32
foreign func uv_tcp_bind(handle: CPointer<Unit>, addr: CPointer<Sockaddr>, flags: UInt32): Int32
foreign func uv_tcp_getsockname(handle: CPointer<Unit>, name: CPointer<Sockaddr>, namelen: CPointer<Int32>): Int32
foreign func uv_tcp_getpeername(handle: CPointer<Unit>, name: CPointer<Sockaddr>, namelen: CPointer<Int32>): Int32
foreign func uv_tcp_close_reset(handle: CPointer<Unit>, close_cb: UvCloseCb): Int32
foreign func uv_tcp_connect(req: CPointer<Unit>, handle: CPointer<Unit>, addr: CPointer<Sockaddr>, cb: UvConnectCb): Int32

// --- UDP ---
foreign func uv_udp_init(loop: CPointer<Unit>, handle: CPointer<Unit>): Int32
foreign func uv_udp_init_ex(loop: CPointer<Unit>, handle: CPointer<Unit>, flags: UInt32): Int32
foreign func uv_udp_open(handle: CPointer<Unit>, sock: Int32): Int32
foreign func uv_udp_bind(handle: CPointer<Unit>, addr: CPointer<Sockaddr>, flags: UInt32): Int32
foreign func uv_udp_connect(handle: CPointer<Unit>, addr: CPointer<Sockaddr>): Int32
foreign func uv_udp_getpeername(handle: CPointer<Unit>, name: CPointer<Sockaddr>, namelen: CPointer<Int32>): Int32
foreign func uv_udp_getsockname(handle: CPointer<Unit>, name: CPointer<Sockaddr>, namelen: CPointer<Int32>): Int32
foreign func uv_udp_set_membership(handle: CPointer<Unit>, multicast_addr: CPointer<UInt8>, interface_addr: CPointer<UInt8>, membership: Int32): Int32
foreign func uv_udp_set_source_membership(handle: CPointer<Unit>, multicast_addr: CPointer<UInt8>, interface_addr: CPointer<UInt8>, source_addr: CPointer<UInt8>, membership: Int32): Int32
foreign func uv_udp_set_multicast_loop(handle: CPointer<Unit>, on: Int32): Int32
foreign func uv_udp_set_multicast_ttl(handle: CPointer<Unit>, ttl: Int32): Int32
foreign func uv_udp_set_multicast_interface(handle: CPointer<Unit>, interface_addr: CPointer<UInt8>): Int32
foreign func uv_udp_set_broadcast(handle: CPointer<Unit>, on: Int32): Int32
foreign func uv_udp_set_ttl(handle: CPointer<Unit>, ttl: Int32): Int32
foreign func uv_udp_send(req: CPointer<Unit>, handle: CPointer<Unit>, bufs: CPointer<UvBufT>, nbufs: UInt32, addr: CPointer<Sockaddr>, send_cb: UvUdpSendCb): Int32
foreign func uv_udp_try_send(handle: CPointer<Unit>, bufs: CPointer<UvBufT>, nbufs: UInt32, addr: CPointer<Sockaddr>): Int32
foreign func uv_udp_recv_start(handle: CPointer<Unit>, alloc_cb: UvAllocCb, recv_cb: UvUdpRecvCb): Int32
foreign func uv_udp_using_recvmmsg(handle: CPointer<Unit>): Int32
foreign func uv_udp_recv_stop(handle: CPointer<Unit>): Int32
foreign func uv_udp_get_send_queue_size(handle: CPointer<Unit>): UIntNative
foreign func uv_udp_get_send_queue_count(handle: CPointer<Unit>): UIntNative

// --- TTY ---
foreign func uv_tty_init(loop: CPointer<Unit>, tty: CPointer<Unit>, fd: Int32, readable: Int32): Int32
foreign func uv_tty_set_mode(tty: CPointer<Unit>, mode: Int32): Int32
foreign func uv_tty_reset_mode(): Int32
foreign func uv_tty_get_winsize(tty: CPointer<Unit>, width: CPointer<Int32>, height: CPointer<Int32>): Int32
foreign func uv_tty_set_vterm_state(state: Int32): Unit
foreign func uv_tty_get_vterm_state(state: CPointer<Int32>): Int32
foreign func uv_guess_handle(file: Int32): UInt32

// --- Pipe ---
foreign func uv_pipe_init(loop: CPointer<Unit>, handle: CPointer<Unit>, ipc: Int32): Int32
foreign func uv_pipe_open(handle: CPointer<Unit>, file: Int32): Int32
foreign func uv_pipe_bind(handle: CPointer<Unit>, name: CPointer<UInt8>): Int32
foreign func uv_pipe_bind2(handle: CPointer<Unit>, name: CPointer<UInt8>, namelen: UIntNative, flags: UInt32): Int32
foreign func uv_pipe_connect(req: CPointer<Unit>, handle: CPointer<Unit>, name: CPointer<UInt8>, cb: UvConnectCb): Unit
foreign func uv_pipe_connect2(req: CPointer<Unit>, handle: CPointer<Unit>, name: CPointer<UInt8>, namelen: UIntNative, flags: UInt32, cb: UvConnectCb): Int32
foreign func uv_pipe_getsockname(handle: CPointer<Unit>, buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32
foreign func uv_pipe_getpeername(handle: CPointer<Unit>, buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32
foreign func uv_pipe_pending_instances(handle: CPointer<Unit>, count: Int32): Unit
foreign func uv_pipe_pending_count(handle: CPointer<Unit>): Int32
foreign func uv_pipe_pending_type(handle: CPointer<Unit>): UInt32
foreign func uv_pipe_chmod(handle: CPointer<Unit>, flags: Int32): Int32

// --- Poll ---
foreign func uv_poll_init(loop: CPointer<Unit>, handle: CPointer<Unit>, fd: Int32): Int32
foreign func uv_poll_init_socket(loop: CPointer<Unit>, handle: CPointer<Unit>, socket: Int32): Int32
foreign func uv_poll_start(handle: CPointer<Unit>, events: Int32, cb: UvPollCb): Int32
foreign func uv_poll_stop(handle: CPointer<Unit>): Int32

// --- Prepare/Check/Idle ---
foreign func uv_prepare_init(loop: CPointer<Unit>, prepare: CPointer<Unit>): Int32
foreign func uv_prepare_start(prepare: CPointer<Unit>, cb: UvPrepareCb): Int32
foreign func uv_prepare_stop(prepare: CPointer<Unit>): Int32
foreign func uv_check_init(loop: CPointer<Unit>, check: CPointer<Unit>): Int32
foreign func uv_check_start(check: CPointer<Unit>, cb: UvCheckCb): Int32
foreign func uv_check_stop(check: CPointer<Unit>): Int32
foreign func uv_idle_init(loop: CPointer<Unit>, idle: CPointer<Unit>): Int32
foreign func uv_idle_start(idle: CPointer<Unit>, cb: UvIdleCb): Int32
foreign func uv_idle_stop(idle: CPointer<Unit>): Int32

// --- Async ---
foreign func uv_async_init(loop: CPointer<Unit>, async_: CPointer<Unit>, async_cb: UvAsyncCb): Int32
foreign func uv_async_send(async_: CPointer<Unit>): Int32

// --- Timer ---
foreign func uv_timer_init(loop: CPointer<Unit>, handle: CPointer<Unit>): Int32
foreign func uv_timer_start(handle: CPointer<Unit>, cb: UvTimerCb, timeout: UInt64, repeat: UInt64): Int32
foreign func uv_timer_stop(handle: CPointer<Unit>): Int32
foreign func uv_timer_again(handle: CPointer<Unit>): Int32
foreign func uv_timer_set_repeat(handle: CPointer<Unit>, repeat: UInt64): Unit
foreign func uv_timer_get_repeat(handle: CPointer<Unit>): UInt64
foreign func uv_timer_get_due_in(handle: CPointer<Unit>): UInt64

// --- DNS ---
foreign func uv_getaddrinfo(loop: CPointer<Unit>, req: CPointer<Unit>, getaddrinfo_cb: UvGetaddrinfoCb, node: CString, service: CString, hints: CPointer<Unit>): Int32
foreign func uv_freeaddrinfo(ai: CPointer<Unit>): Unit
foreign func uv_getnameinfo(loop: CPointer<Unit>, req: CPointer<Unit>, getnameinfo_cb: UvGetnameinfoCb, addr: CPointer<Sockaddr>, flags: Int32): Int32

// --- Process ---
foreign func uv_spawn(loop: CPointer<Unit>, handle: CPointer<Unit>, options: CPointer<Unit>): Int32
foreign func uv_process_kill(handle: CPointer<Unit>, signum: Int32): Int32
foreign func uv_kill(pid: Int32, signum: Int32): Int32
foreign func uv_process_get_pid(handle: CPointer<Unit>): Int32

// --- Work queue ---
foreign func uv_queue_work(loop: CPointer<Unit>, req: CPointer<Unit>, work_cb: UvWorkCb, after_work_cb: UvAfterWorkCb): Int32

// --- System 信息 ---
foreign func uv_setup_args(argc: Int32, argv: CPointer<CPointer<UInt8>>): CPointer<CPointer<UInt8>>
foreign func uv_get_process_title(buffer: CPointer<UInt8>, size: UIntNative): Int32
foreign func uv_set_process_title(title: CPointer<UInt8>): Int32
foreign func uv_resident_set_memory(rss: CPointer<UIntNative>): Int32
foreign func uv_uptime(uptime: CPointer<Float64>): Int32
foreign func uv_getrusage(rusage: CPointer<Unit>): Int32
foreign func uv_os_homedir(buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32
foreign func uv_os_tmpdir(buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32
foreign func uv_os_get_passwd(pwd: CPointer<Unit>): Int32
foreign func uv_os_free_passwd(pwd: CPointer<Unit>): Unit
foreign func uv_os_get_passwd2(pwd: CPointer<Unit>, uid: UInt8): Int32
foreign func uv_os_get_group(grp: CPointer<Unit>, gid: UInt8): Int32
foreign func uv_os_free_group(grp: CPointer<Unit>): Unit
foreign func uv_os_getpid(): Int32
foreign func uv_os_getppid(): Int32
foreign func uv_os_getpriority(pid: Int32, priority: CPointer<Int32>): Int32
foreign func uv_os_setpriority(pid: Int32, priority: Int32): Int32
foreign func uv_available_parallelism(): UInt32
foreign func uv_cpu_info(cpu_infos: CPointer<CPointer<Unit>>, count: CPointer<Int32>): Int32
foreign func uv_free_cpu_info(cpu_infos: CPointer<Unit>, count: Int32): Unit
foreign func uv_cpumask_size(): Int32
foreign func uv_interface_addresses(addresses: CPointer<CPointer<Unit>>, count: CPointer<Int32>): Int32
foreign func uv_free_interface_addresses(addresses: CPointer<Unit>, count: Int32): Unit
foreign func uv_os_environ(envitems: CPointer<CPointer<Unit>>, count: CPointer<Int32>): Int32
foreign func uv_os_free_environ(envitems: CPointer<Unit>, count: Int32): Unit
foreign func uv_os_getenv(name: CPointer<UInt8>, buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32
foreign func uv_os_setenv(name: CPointer<UInt8>, value: CPointer<UInt8>): Int32
foreign func uv_os_unsetenv(name: CPointer<UInt8>): Int32
foreign func uv_os_gethostname(buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32
foreign func uv_os_uname(buffer: CPointer<Unit>): Int32
foreign func uv_metrics_info(loop: CPointer<Unit>, metrics: CPointer<Unit>): Int32
foreign func uv_metrics_idle_time(loop: CPointer<Unit>): UInt64

// --- 文件系统 ---
foreign func uv_fs_get_type(req: CPointer<Unit>): Int32
foreign func uv_fs_get_result(req: CPointer<Unit>): Int64
foreign func uv_fs_get_system_error(req: CPointer<Unit>): Int32
foreign func uv_fs_get_ptr(req: CPointer<Unit>): CPointer<Unit>
foreign func uv_fs_get_path(req: CPointer<Unit>): CString
foreign func uv_fs_get_statbuf(req: CPointer<Unit>): CPointer<UvStatT>
foreign func uv_fs_req_cleanup(req: CPointer<Unit>): Unit
foreign func uv_fs_close(loop: CPointer<Unit>, req: CPointer<Unit>, file: Int32, cb: UvFsCb): Int32
foreign func uv_fs_open(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, flags: Int32, mode: Int32, cb: UvFsCb): Int32
foreign func uv_fs_read(loop: CPointer<Unit>, req: CPointer<Unit>, file: Int32, bufs: CPointer<UvBufT>, nbufs: UInt32, offset: Int64, cb: UvFsCb): Int32
foreign func uv_fs_unlink(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, cb: UvFsCb): Int32
foreign func uv_fs_write(loop: CPointer<Unit>, req: CPointer<Unit>, file: Int32, bufs: CPointer<UvBufT>, nbufs: UInt32, offset: Int64, cb: UvFsCb): Int32
foreign func uv_fs_copyfile(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, new_path: CString, flags: Int32, cb: UvFsCb): Int32
foreign func uv_fs_mkdir(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, mode: Int32, cb: UvFsCb): Int32
foreign func uv_fs_mkdtemp(loop: CPointer<Unit>, req: CPointer<Unit>, tpl: CString, cb: UvFsCb): Int32
foreign func uv_fs_mkstemp(loop: CPointer<Unit>, req: CPointer<Unit>, tpl: CString, cb: UvFsCb): Int32
foreign func uv_fs_rmdir(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, cb: UvFsCb): Int32
foreign func uv_fs_scandir(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, flags: Int32, cb: UvFsCb): Int32
foreign func uv_fs_scandir_next(req: CPointer<Unit>, ent: CPointer<Unit>): Int32
foreign func uv_fs_opendir(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<UInt8>, cb: UvFsCb): Int32
foreign func uv_fs_readdir(loop: CPointer<Unit>, req: CPointer<Unit>, dir: CPointer<Unit>, cb: UvFsCb): Int32
foreign func uv_fs_closedir(loop: CPointer<Unit>, req: CPointer<Unit>, dir: CPointer<Unit>, cb: UvFsCb): Int32
foreign func uv_fs_stat(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, cb: UvFsCb): Int32
foreign func uv_fs_fstat(loop: CPointer<Unit>, req: CPointer<Unit>, file: Int32, cb: UvFsCb): Int32
foreign func uv_fs_rename(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, new_path: CString, cb: UvFsCb): Int32
foreign func uv_fs_fsync(loop: CPointer<Unit>, req: CPointer<Unit>, file: Int32, cb: UvFsCb): Int32
foreign func uv_fs_fdatasync(loop: CPointer<Unit>, req: CPointer<Unit>, file: Int32, cb: UvFsCb): Int32
foreign func uv_fs_ftruncate(loop: CPointer<Unit>, req: CPointer<Unit>, file: Int32, offset: Int64, cb: UvFsCb): Int32
foreign func uv_fs_sendfile(loop: CPointer<Unit>, req: CPointer<Unit>, out_fd: Int32, in_fd: Int32, in_offset: Int64, length: UIntNative, cb: UvFsCb): Int32
foreign func uv_fs_access(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, mode: Int32, cb: UvFsCb): Int32
foreign func uv_fs_chmod(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, mode: Int32, cb: UvFsCb): Int32
foreign func uv_fs_utime(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, atime: Float64, mtime: Float64, cb: UvFsCb): Int32
foreign func uv_fs_futime(loop: CPointer<Unit>, req: CPointer<Unit>, file: Int32, atime: Float64, mtime: Float64, cb: UvFsCb): Int32
foreign func uv_fs_lutime(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, atime: Float64, mtime: Float64, cb: UvFsCb): Int32
foreign func uv_fs_lstat(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, cb: UvFsCb): Int32
foreign func uv_fs_link(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, new_path: CString, cb: UvFsCb): Int32
foreign func uv_fs_symlink(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, new_path: CString, flags: Int32, cb: UvFsCb): Int32
foreign func uv_fs_readlink(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, cb: UvFsCb): Int32
foreign func uv_fs_realpath(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, cb: UvFsCb): Int32
foreign func uv_fs_fchmod(loop: CPointer<Unit>, req: CPointer<Unit>, file: Int32, mode: Int32, cb: UvFsCb): Int32
foreign func uv_fs_chown(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, uid: UInt8, gid: UInt8, cb: UvFsCb): Int32
foreign func uv_fs_fchown(loop: CPointer<Unit>, req: CPointer<Unit>, file: Int32, uid: UInt8, gid: UInt8, cb: UvFsCb): Int32
foreign func uv_fs_lchown(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, uid: UInt8, gid: UInt8, cb: UvFsCb): Int32
foreign func uv_fs_statfs(loop: CPointer<Unit>, req: CPointer<Unit>, path: CString, cb: UvFsCb): Int32

// --- FS Poll ---
foreign func uv_fs_poll_init(loop: CPointer<Unit>, handle: CPointer<Unit>): Int32
foreign func uv_fs_poll_start(handle: CPointer<Unit>, poll_cb: UvFsPollCb, path: CString, interval: UInt32): Int32
foreign func uv_fs_poll_stop(handle: CPointer<Unit>): Int32
foreign func uv_fs_poll_getpath(handle: CPointer<Unit>, buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32

// --- Signal ---
foreign func uv_signal_init(loop: CPointer<Unit>, handle: CPointer<Unit>): Int32
foreign func uv_signal_start(handle: CPointer<Unit>, signal_cb: UvSignalCb, signum: Int32): Int32
foreign func uv_signal_start_oneshot(handle: CPointer<Unit>, signal_cb: UvSignalCb, signum: Int32): Int32
foreign func uv_signal_stop(handle: CPointer<Unit>): Int32

// --- Load average ---
foreign func uv_loadavg(avg: CPointer<Float64>): Unit

// --- FS Event ---
foreign func uv_fs_event_init(loop: CPointer<Unit>, handle: CPointer<Unit>): Int32
foreign func uv_fs_event_start(handle: CPointer<Unit>, cb: UvFsEventCb, path: CString, flags: UInt32): Int32
foreign func uv_fs_event_stop(handle: CPointer<Unit>): Int32
foreign func uv_fs_event_getpath(handle: CPointer<Unit>, buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32

// --- IP 地址 ---
foreign func uv_ip4_addr(ip: CPointer<UInt8>, port: Int32, addr: CPointer<Sockaddr>): Int32
foreign func uv_ip6_addr(ip: CPointer<UInt8>, port: Int32, addr: CPointer<Unit>): Int32
foreign func uv_ip4_name(src: CPointer<Unit>, dst: CPointer<UInt8>, size: UIntNative): Int32
foreign func uv_ip6_name(src: CPointer<Unit>, dst: CPointer<UInt8>, size: UIntNative): Int32
foreign func uv_ip_name(src: CPointer<Sockaddr>, dst: CPointer<UInt8>, size: UIntNative): Int32
foreign func uv_inet_ntop(af: Int32, src: CPointer<Unit>, dst: CPointer<UInt8>, size: UIntNative): Int32
foreign func uv_inet_pton(af: Int32, src: CPointer<UInt8>, dst: CPointer<Unit>): Int32

// --- Random ---
foreign func uv_random(loop: CPointer<Unit>, req: CPointer<Unit>, buf: CPointer<Unit>, buflen: UIntNative, flags: UInt32, cb: UvRandomCb): Int32

// --- Network 接口 ---
foreign func uv_if_indextoname(ifindex: UInt32, buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32
foreign func uv_if_indextoiid(ifindex: UInt32, buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32

// --- 路径 ---
foreign func uv_exepath(buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32
foreign func uv_cwd(buffer: CPointer<UInt8>, size: CPointer<UIntNative>): Int32
foreign func uv_chdir(dir: CPointer<UInt8>): Int32

// --- 系统内存 ---
foreign func uv_get_free_memory(): UInt64
foreign func uv_get_total_memory(): UInt64
foreign func uv_get_constrained_memory(): UInt64
foreign func uv_get_available_memory(): UInt64
foreign func uv_clock_gettime(clock_id: UInt32, ts: CPointer<UvTimespec64T>): Int32
foreign func uv_hrtime(): UInt64
foreign func uv_sleep(msec: UInt32): Unit

// --- 库加载 ---
foreign func uv_disable_stdio_inheritance(): Unit
foreign func uv_dlopen(filename: CPointer<UInt8>, lib: CPointer<Unit>): Int32
foreign func uv_dlclose(lib: CPointer<Unit>): Unit
foreign func uv_dlsym(lib: CPointer<Unit>, name: CPointer<UInt8>, ptr: CPointer<CPointer<Unit>>): Int32
foreign func uv_dlerror(lib: CPointer<Unit>): CPointer<UInt8>

// --- 线程原语 ---
foreign func uv_once(guard: CPointer<Unit>, callback: CFunc<() -> Unit>): Unit
foreign func uv_key_create(key: CPointer<Unit>): Int32
foreign func uv_key_delete(key: CPointer<Unit>): Unit
foreign func uv_key_get(key: CPointer<Unit>): CPointer<Unit>
foreign func uv_key_set(key: CPointer<Unit>, value: CPointer<Unit>): Unit
foreign func uv_gettimeofday(tv: CPointer<UvTimeval64T>): Int32
foreign func uv_thread_create(tid: CPointer<Unit>, entry: UvThreadCb, arg: CPointer<Unit>): Int32
foreign func uv_thread_create_ex(tid: CPointer<Unit>, params: CPointer<Unit>, entry: UvThreadCb, arg: CPointer<Unit>): Int32
foreign func uv_thread_setaffinity(tid: CPointer<Unit>, cpumask: CPointer<UInt8>, oldmask: CPointer<UInt8>, mask_size: UIntNative): Int32
foreign func uv_thread_getaffinity(tid: CPointer<Unit>, cpumask: CPointer<UInt8>, mask_size: UIntNative): Int32
foreign func uv_thread_getcpu(): Int32
foreign func uv_thread_self(): CPointer<Unit>
foreign func uv_thread_join(tid: CPointer<Unit>): Int32
foreign func uv_thread_equal(t1: CPointer<Unit>, t2: CPointer<Unit>): Int32
