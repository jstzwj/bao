// 工具绑定模块
// 对应 Bun: src/runtime/node/node_util_binding.zig
// 严格翻译自: src/runtime/node/node_util_binding.zig
package bao_runtime.node

// ============================================================================
// 错误名称映射
// 对应 Bun: src/runtime/node/node_util_binding.zig - internalErrorName
// ============================================================================
public class InternalErrorName {
    // 根据错误码返回错误名称
    // 对应 Bun: src/runtime/node/node_util_binding.zig - internalErrorName
    public static func fromCode(errInt: Int32): String {
        // 系统错误码映射
        if (errInt == -4095) { return "EOF" }
        if (errInt == -4094) { return "UNKNOWN" }
        if (errInt == -3000) { return "EAI_ADDRFAMILY" }
        if (errInt == -3001) { return "EAI_AGAIN" }
        if (errInt == -3002) { return "EAI_BADFLAGS" }
        if (errInt == -3003) { return "EAI_CANCELED" }
        if (errInt == -3004) { return "EAI_FAIL" }
        if (errInt == -3005) { return "EAI_FAMILY" }
        if (errInt == -3006) { return "EAI_MEMORY" }
        if (errInt == -3007) { return "EAI_NODATA" }
        if (errInt == -3008) { return "EAI_NONAME" }
        if (errInt == -3009) { return "EAI_OVERFLOW" }
        if (errInt == -3010) { return "EAI_SERVICE" }
        if (errInt == -3011) { return "EAI_SOCKTYPE" }
        if (errInt == -3013) { return "EAI_BADHINTS" }
        if (errInt == -3014) { return "EAI_PROTOCOL" }

        // POSIX 错误码映射
        let errorMap = HashMap<Int32, String>()
        errorMap.put(-7, "E2BIG")
        errorMap.put(-13, "EACCES")
        errorMap.put(-98, "EADDRINUSE")
        errorMap.put(-99, "EADDRNOTAVAIL")
        errorMap.put(-97, "EAFNOSUPPORT")
        errorMap.put(-11, "EAGAIN")
        errorMap.put(-114, "EALREADY")
        errorMap.put(-9, "EBADF")
        errorMap.put(-16, "EBUSY")
        errorMap.put(-125, "ECANCELED")
        errorMap.put(-12, "ENOMEM")
        errorMap.put(-22, "EINVAL")
        errorMap.put(-5, "EIO")
        errorMap.put(-106, "EISCONN")
        errorMap.put(-21, "EISDIR")
        errorMap.put(-40, "ELOOP")
        errorMap.put(-24, "EMFILE")
        errorMap.put(-90, "EMSGSIZE")
        errorMap.put(-36, "ENAMETOOLONG")
        errorMap.put(-100, "ENETDOWN")
        errorMap.put(-101, "ENETUNREACH")
        errorMap.put(-23, "ENFILE")
        errorMap.put(-105, "ENOBUFS")
        errorMap.put(-19, "ENODEV")
        errorMap.put(-2, "ENOENT")
        errorMap.put(-13, "EACCES")
        errorMap.put(-28, "ENOSPC")
        errorMap.put(-38, "ENOSYS")
        errorMap.put(-107, "ENOTCONN")
        errorMap.put(-20, "ENOTDIR")
        errorMap.put(-39, "ENOTEMPTY")
        errorMap.put(-88, "ENOTSOCK")
        errorMap.put(-1, "EPERM")
        errorMap.put(-32, "EPIPE")
        errorMap.put(-71, "EPROTO")
        errorMap.put(-93, "EPROTONOSUPPORT")
        errorMap.put(-91, "EPROTOTYPE")
        errorMap.put(-30, "EROFS")
        errorMap.put(-108, "ESHUTDOWN")
        errorMap.put(-29, "ESPIPE")
        errorMap.put(-3, "ESRCH")
        errorMap.put(-110, "ETIMEDOUT")
        errorMap.put(-26, "ETXTBSY")
        errorMap.put(-18, "EXDEV")
        errorMap.put(-27, "EFBIG")
        errorMap.put(-92, "ENOPROTOOPT")
        errorMap.put(-34, "ERANGE")
        errorMap.put(-6, "ENXIO")
        errorMap.put(-31, "EMLINK")
        errorMap.put(-33, "EDOM")
        errorMap.put(-15, "ENOTBLK")
        errorMap.put(-17, "EEXIST")
        errorMap.put(-14, "EFAULT")
        errorMap.put(-64, "EHOSTUNREACH")
        errorMap.put(-4, "EINTR")
        errorMap.put(-44, "ECONNRESET")
        errorMap.put(-103, "ECONNABORTED")
        errorMap.put(-111, "ECONNREFUSED")
        errorMap.put(-87, "EDESTADDRREQ")
        errorMap.put(-56, "EBADMSG")
        errorMap.put(-35, "EDEADLK")
        errorMap.put(-37, "ENOLCK")
        errorMap.put(-39, "ENOTEMPTY")
        errorMap.put(-42, "ENOMSG")
        errorMap.put(-82, "ELIBBAD")
        errorMap.put(-83, "ELIBEXEC")
        errorMap.put(-84, "ELIBMAX")

        let found = errorMap.get(errInt)
        if (found != None) {
            return found.getOrThrow()
        }

        return "Unknown system error ${errInt}"
    }
}

// ============================================================================
// 编码规范化
// 对应 Bun: src/runtime/node/node_util_binding.zig - normalizeEncoding
// ============================================================================
public class NormalizeEncoding {
    // 将编码字符串规范化为标准编码名
    public static func normalize(input: String): ?Encoding {
        if (input.size == 0) {
            return Encoding.utf8
        }
        return Encoding.from(input)
    }
}

// ============================================================================
// 环境变量解析
// 对应 Bun: src/runtime/node/node_util_binding.zig - parseEnv
// ============================================================================
public class ParseEnv {
    // 解析 .env 格式的内容为键值对
    public static func parse(content: String): Map<String, String> {
        let result = HashMap<String, String>()
        let lines = content.split('\n')
        for (line in lines) {
            let trimmed = line.trim()
            if (trimmed.size == 0 || trimmed.startsWith("#")) {
                continue
            }
            let eqIdx = trimmed.indexOf('=')
            if (eqIdx != None) {
                let idx = eqIdx.getOrThrow()
                let key = trimmed.substring(0, idx).trim()
                var value = trimmed.substring(idx + 1, trimmed.size).trim()
                // 去除引号
                if ((value.startsWith("\"") && value.endsWith("\"")) ||
                    (value.startsWith("'") && value.endsWith("'"))) {
                    value = value.substring(1, value.size - 1)
                }
                result.put(key, value)
            }
        }
        return result
    }
}
