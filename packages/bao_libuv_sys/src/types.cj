// 严格翻译自: src/libuv_sys/libuv.zig
package bao_libuv_sys

// ============================================================================
// libuv 基础类型和结构体
// 严格翻译自: libuv.zig 中的类型定义
// ============================================================================

/// linger 结构体
/// 严格翻译自: struct_linger
@C
public struct Linger {
    public var l_onoff: UInt16 = 0
    public var l_linger: UInt16 = 0
}

/// sockaddr 结构体
/// 严格翻译自: struct_sockaddr
@C
public struct Sockaddr {
    public var sa_family: UInt16 = 0
    public var sa_data: VArray<UInt8, $14> = VArray<UInt8, $14>(repeat: 0)
}

/// uv_buf_t 结构体
/// 严格翻译自: uv_buf_t
@C
public struct UvBufT {
    public var len: UInt32 = 0
    public var base: CPointer<UInt8> = CPointer<UInt8>()
}

/// uv_timespec_t
/// 严格翻译自: uv_timespec_t
@C
public struct UvTimespecT {
    public var sec: Int64 = 0
    public var nsec: Int64 = 0
}

/// uv_timespec64_t
/// 严格翻译自: uv_timespec64_t
@C
public struct UvTimespec64T {
    public var sec: Int64 = 0
    public var nsec: Int32 = 0
}

/// uv_timeval_t
/// 严格翻译自: uv_timeval_t
@C
public struct UvTimevalT {
    public var sec: Int64 = 0
    public var usec: Int64 = 0
}

/// uv_timeval64_t
/// 严格翻译自: uv_timeval64_t
@C
public struct UvTimeval64T {
    public var sec: Int64 = 0
    public var usec: Int32 = 0
}

/// uv_stat_t
/// 严格翻译自: uv_stat_t
@C
public struct UvStatT {
    public var dev: UInt64 = 0
    public var mode: UInt64 = 0
    public var nlink: UInt64 = 0
    public var uid: UInt64 = 0
    public var gid: UInt64 = 0
    public var rdev: UInt64 = 0
    public var ino: UInt64 = 0
    public var size: UInt64 = 0
    public var blksize: UInt64 = 0
    public var blocks: UInt64 = 0
    public var flags: UInt64 = 0
    public var gen: UInt64 = 0
    public var atim: UvTimespecT = UvTimespecT()
    public var mtim: UvTimespecT = UvTimespecT()
    public var ctim: UvTimespecT = UvTimespecT()
    public var birthtim: UvTimespecT = UvTimespecT()
}

/// uv_statfs_t
/// 严格翻译自: uv_statfs_t
@C
public struct UvStatfsT {
    public var f_type: UInt64 = 0
    public var f_bsize: UInt64 = 0
    public var f_blocks: UInt64 = 0
    public var f_bfree: UInt64 = 0
    public var f_bavail: UInt64 = 0
    public var f_files: UInt64 = 0
    public var f_ffree: UInt64 = 0
    public var f_spare: VArray<UInt64, $4> = VArray<UInt64, $4>(repeat: 0)
}

/// uv_metrics_t
/// 严格翻译自: uv_metrics_t
@C
public struct UvMetricsT {
    public var loop_count: UInt64 = 0
    public var events: UInt64 = 0
    public var events_waiting: UInt64 = 0
    public var reserved: VArray<CPointer<UInt64>, $13> = VArray<CPointer<UInt64>, $13>(repeat: CPointer<UInt64>())
}

/// uv_env_item_t
/// 严格翻译自: uv_env_item_t
@C
public struct UvEnvItemT {
    public var name: CPointer<UInt8> = CPointer<UInt8>()
    public var value: CPointer<UInt8> = CPointer<UInt8>()
}

/// uv_cpu_times_s
/// 严格翻译自: struct_uv_cpu_times_s
@C
public struct UvCpuTimesT {
    public var user: UInt64 = 0
    public var nice: UInt64 = 0
    public var sys: UInt64 = 0
    public var idle: UInt64 = 0
    public var irq: UInt64 = 0
}

/// uv_cpu_info_t
/// 严格翻译自: uv_cpu_info_t
@C
public struct UvCpuInfoT {
    public var model: CString = CString()
    public var speed: Int32 = 0
    public var cpu_times: UvCpuTimesT = UvCpuTimesT()
}

/// uv_passwd_t
/// 严格翻译自: uv_passwd_t
@C
public struct UvPasswdT {
    public var username: CPointer<UInt8> = CPointer<UInt8>()
    public var uid: UInt64 = 0
    public var gid: UInt64 = 0
    public var shell: CPointer<UInt8> = CPointer<UInt8>()
    public var homedir: CPointer<UInt8> = CPointer<UInt8>()
}

/// uv_group_t
/// 严格翻译自: uv_group_t
@C
public struct UvGroupT {
    public var groupname: CPointer<UInt8> = CPointer<UInt8>()
    public var gid: UInt64 = 0
    public var members: CPointer<CPointer<UInt8>> = CPointer<CPointer<UInt8>>()
}

/// uv_utsname_t
/// 严格翻译自: uv_utsname_t
@C
public struct UvUtsnameT {
    public var sysname: VArray<UInt8, $255> = VArray<UInt8, $255>(repeat: 0)
    public var release: VArray<UInt8, $255> = VArray<UInt8, $255>(repeat: 0)
    public var version: VArray<UInt8, $255> = VArray<UInt8, $255>(repeat: 0)
    public var machine: VArray<UInt8, $255> = VArray<UInt8, $255>(repeat: 0)
}

/// uv_interface_address_t (简化版, 使用固定大小缓冲区)
/// 严格翻译自: uv_interface_address_t
@C
public struct UvInterfaceAddressT {
    public var name: CPointer<UInt8> = CPointer<UInt8>()
    public var phys_addr: VArray<UInt8, $6> = VArray<UInt8, $6>(repeat: 0)
    public var is_internal: Int32 = 0
    public var address: VArray<UInt8, $128> = VArray<UInt8, $128>(repeat: 0)
    public var netmask: VArray<UInt8, $128> = VArray<UInt8, $128>(repeat: 0)
}

/// uv_rusage_t (简化的 resource usage)
/// 严格翻译自: uv_rusage_t
@C
public struct UvRusageT {
    public var ru_maxrss: UInt64 = 0
    public var ru_ixrss: UInt64 = 0
    public var ru_idrss: UInt64 = 0
    public var ru_isrss: UInt64 = 0
    public var ru_minflt: UInt64 = 0
    public var ru_majflt: UInt64 = 0
    public var ru_nswap: UInt64 = 0
    public var ru_inblock: UInt64 = 0
    public var ru_oublock: UInt64 = 0
    public var ru_msgsnd: UInt64 = 0
    public var ru_msgrcv: UInt64 = 0
    public var ru_nsignals: UInt64 = 0
    public var ru_nvcsw: UInt64 = 0
    public var ru_nivcsw: UInt64 = 0
}

// ============================================================================
// 回调函数类型
// 严格翻译自: libuv.zig 中的回调类型定义
// ============================================================================
public type UvCloseCb = CFunc<(CPointer<Unit>) -> Unit>
public type UvAllocCb = CFunc<(CPointer<Unit>, UIntNative, CPointer<UvBufT>) -> Unit>
public type UvReadCb = CFunc<(CPointer<Unit>, Int64, CPointer<UvBufT>) -> Unit>
public type UvWriteCb = CFunc<(CPointer<Unit>, Int32) -> Unit>
public type UvConnectionCb = CFunc<(CPointer<Unit>, Int32) -> Unit>
public type UvShutdownCb = CFunc<(CPointer<Unit>, Int32) -> Unit>
public type UvConnectCb = CFunc<(CPointer<Unit>, Int32) -> Unit>
public type UvPrepareCb = CFunc<(CPointer<Unit>) -> Unit>
public type UvCheckCb = CFunc<(CPointer<Unit>) -> Unit>
public type UvIdleCb = CFunc<(CPointer<Unit>) -> Unit>
public type UvAsyncCb = CFunc<(CPointer<Unit>) -> Unit>
public type UvTimerCb = CFunc<(CPointer<Unit>) -> Unit>
public type UvWalkCb = CFunc<(CPointer<Unit>, CPointer<Unit>) -> Unit>
public type UvPollCb = CFunc<(CPointer<Unit>, Int32, Int32) -> Unit>
public type UvExitCb = CFunc<(CPointer<Unit>, Int64, Int32) -> Unit>
public type UvSignalCb = CFunc<(CPointer<Unit>, Int32) -> Unit>
public type UvFsCb = CFunc<(CPointer<Unit>) -> Unit>
public type UvWorkCb = CFunc<(CPointer<Unit>) -> Unit>
public type UvAfterWorkCb = CFunc<(CPointer<Unit>, Int32) -> Unit>
public type UvGetaddrinfoCb = CFunc<(CPointer<Unit>, Int32, CPointer<Unit>) -> Unit>
public type UvGetnameinfoCb = CFunc<(CPointer<Unit>, Int32, CString, CString) -> Unit>
public type UvFsPollCb = CFunc<(CPointer<Unit>, Int32, CPointer<UvStatT>, CPointer<UvStatT>) -> Unit>
public type UvFsEventCb = CFunc<(CPointer<Unit>, CString, Int32, Int32) -> Unit>
public type UvUdpRecvCb = CFunc<(CPointer<Unit>, Int64, CPointer<UvBufT>, CPointer<Unit>, UInt32) -> Unit>
public type UvUdpSendCb = CFunc<(CPointer<Unit>, Int32) -> Unit>
public type UvRandomCb = CFunc<(CPointer<Unit>, Int32, CPointer<Unit>, UIntNative) -> Unit>
public type UvMallocFunc = CFunc<(UIntNative) -> CPointer<Unit>>
public type UvReallocFunc = CFunc<(CPointer<Unit>, UIntNative) -> CPointer<Unit>>
public type UvCallocFunc = CFunc<(UIntNative, UIntNative) -> CPointer<Unit>>
public type UvFreeFunc = CFunc<(CPointer<Unit>) -> Unit>
public type UvThreadCb = CFunc<(CPointer<Unit>) -> Unit>

// ============================================================================
// 枚举
// 严格翻译自: libuv.zig 中的枚举
// ============================================================================

/// Handle 类型
/// 严格翻译自: Handle.Type
public enum UvHandleType <: UInt32 {
    unknown = 0
    async = 1
    check = 2
    fs_event = 3
    fs_poll = 4
    handle = 5
    idle = 6
    named_pipe = 7
    poll = 8
    prepare = 9
    process = 10
    stream = 11
    tcp = 12
    timer = 13
    tty = 14
    udp = 15
    signal = 16
    file = 17
}

/// Run 模式
/// 严格翻译自: RunMode
public enum UvRunMode <: UInt32 {
    default = 0
    once = 1
    nowait = 2
}

/// TTY 模式
/// 严格翻译自: struct_uv_tty_s.Mode
public enum UvTtyMode <: UInt32 {
    normal = 0
    raw = 1
    io = 2
    vt = 3
}

/// fs 事件类型
public enum UvFsEvent <: UInt32 {
    rename = 1
    change = 2
}
