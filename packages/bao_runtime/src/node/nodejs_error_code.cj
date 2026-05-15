// Node.js 错误码定义
// 对应 Bun: src/runtime/node/nodejs_error_code.zig
// 严格翻译自: src/runtime/node/nodejs_error_code.zig
package bao_runtime

// ============================================================================
// Node.js 错误码枚举
// 对应 Bun: src/runtime/node/nodejs_error_code.zig - Code
// 参考: https://nodejs.org/api/errors.html#nodejs-error-codes
// ============================================================================
public enum NodeJsErrorCode {
    // 操作被中止（通常使用 AbortController）
    ABORT_ERR,

    // 函数参数用法有歧义
    ERR_AMBIGUOUS_ARGUMENT,

    // 参数不可迭代
    ERR_ARG_NOT_ITERABLE,

    // 断言错误
    ERR_ASSERTION,

    // 无效的异步钩子回调
    ERR_ASYNC_CALLBACK,

    // 无效的异步资源类型
    ERR_ASYNC_TYPE,

    // Brotli 压缩失败
    ERR_BROTLI_COMPRESSION_FAILED,

    // Brotli 无效参数
    ERR_BROTLI_INVALID_PARAM,

    // Buffer 上下文不可用
    ERR_BUFFER_CONTEXT_NOT_AVAILABLE,

    // Buffer 越界
    ERR_BUFFER_OUT_OF_BOUNDS,

    // Buffer 过大
    ERR_BUFFER_TOO_LARGE,

    // 无法监听 SIGINT 信号
    ERR_CANNOT_WATCH_SIGINT,

    // 子进程在父进程收到回复前关闭
    ERR_CHILD_CLOSED_BEFORE_REPLY,

    // 子进程需要 IPC 通道
    ERR_CHILD_PROCESS_IPC_REQUIRED,

    // 子进程 stdio 超过最大缓冲区
    ERR_CHILD_PROCESS_STDIO_MAXBUFFER,

    // MessagePort 已关闭
    ERR_CLOSED_MESSAGE_PORT,

    // Console 流不可写
    ERR_CONSOLE_WRITABLE_STREAM,

    // 无效的构造函数调用
    ERR_CONSTRUCT_CALL_INVALID,

    // 构造函数需要 new 调用
    ERR_CONSTRUCT_CALL_REQUIRED,

    // VM 上下文未初始化
    ERR_CONTEXT_NOT_INITIALIZED,

    // 不支持的客户端证书引擎
    ERR_CRYPTO_CUSTOM_ENGINE_NOT_SUPPORTED,

    // ECDH 无效格式
    ERR_CRYPTO_ECDH_INVALID_FORMAT,

    // ECDH 无效公钥
    ERR_CRYPTO_ECDH_INVALID_PUBLIC_KEY,

    // 未知的加密引擎
    ERR_CRYPTO_ENGINE_UNKNOWN,

    // FIPS 模式被强制
    ERR_CRYPTO_FIPS_FORCED,

    // FIPS 模式不可用
    ERR_CRYPTO_FIPS_UNAVAILABLE,

    // hash.digest() 被多次调用
    ERR_CRYPTO_HASH_FINALIZED,

    // hash.update() 失败
    ERR_CRYPTO_HASH_UPDATE_FAILED,

    // 加密密钥不兼容
    ERR_CRYPTO_INCOMPATIBLE_KEY,

    // 密钥编码选项不兼容
    ERR_CRYPTO_INCOMPATIBLE_KEY_OPTIONS,

    // 加密子系统初始化失败
    ERR_CRYPTO_INITIALIZATION_FAILED,

    // 无效的认证标签
    ERR_CRYPTO_INVALID_AUTH_TAG,

    // 无效的计数器
    ERR_CRYPTO_INVALID_COUNTER,

    // 无效的椭圆曲线
    ERR_CRYPTO_INVALID_CURVE,

    // 无效的摘要算法
    ERR_CRYPTO_INVALID_DIGEST,

    // 无效的初始化向量
    ERR_CRYPTO_INVALID_IV,

    // 无效的 JSON Web Key
    ERR_CRYPTO_INVALID_JWK,

    // 无效的密钥对象类型
    ERR_CRYPTO_INVALID_KEY_OBJECT_TYPE,

    // 无效的密钥长度
    ERR_CRYPTO_INVALID_KEYLEN,

    // 无效的密钥对
    ERR_CRYPTO_INVALID_KEYPAIR,

    // 无效的密钥类型
    ERR_CRYPTO_INVALID_KEYTYPE,

    // 无效的消息长度
    ERR_CRYPTO_INVALID_MESSAGELEN,

    // 无效的 scrypt 参数
    ERR_CRYPTO_INVALID_SCRYPT_PARAMS,

    // 加密操作处于无效状态
    ERR_CRYPTO_INVALID_STATE,

    // 无效的认证标签长度
    ERR_CRYPTO_INVALID_TAG_LENGTH,

    // 异步加密操作初始化失败
    ERR_CRYPTO_JOB_INIT_FAILED,

    // JWK 不支持的曲线
    ERR_CRYPTO_JWK_UNSUPPORTED_CURVE,

    // JWK 不支持的密钥类型
    ERR_CRYPTO_JWK_UNSUPPORTED_KEY_TYPE,

    // 加密操作失败
    ERR_CRYPTO_OPERATION_FAILED,

    // PBKDF2 错误
    ERR_CRYPTO_PBKDF2_ERROR,

    // scrypt 无效参数
    ERR_CRYPTO_SCRYPT_INVALID_PARAMETER,

    // 不支持 scrypt
    ERR_CRYPTO_SCRYPT_NOT_SUPPORTED,

    // 需要签名密钥
    ERR_CRYPTO_SIGN_KEY_REQUIRED,

    // timingSafeEqual 长度不匹配
    ERR_CRYPTO_TIMING_SAFE_EQUAL_LENGTH,

    // 未知的密码
    ERR_CRYPTO_UNKNOWN_CIPHER,

    // 未知的 DH 组名
    ERR_CRYPTO_UNKNOWN_DH_GROUP,

    // 不支持的加密操作
    ERR_CRYPTO_UNSUPPORTED_OPERATION,

    // 调试器错误
    ERR_DEBUGGER_ERROR,

    // 调试器启动错误
    ERR_DEBUGGER_STARTUP_ERROR,

    // 原生插件加载被禁用
    ERR_DLOPEN_DISABLED,

    // process.dlopen() 失败
    ERR_DLOPEN_FAILED,

    // fs.Dir 已关闭
    ERR_DIR_CLOSED,

    // fs.Dir 上有并发操作
    ERR_DIR_CONCURRENT_OPERATION,

    // DNS 设置服务器失败
    ERR_DNS_SET_SERVERS_FAILED,

    // domain 回调不可用
    ERR_DOMAIN_CALLBACK_NOT_AVAILABLE,

    // domain 无法设置未捕获异常回调
    ERR_DOMAIN_CANNOT_SET_UNCAUGHT_EXCEPTION_CAPTURE,

    // TextDecoder 数据无效
    ERR_ENCODING_INVALID_ENCODED_DATA,

    // 不支持的编码
    ERR_ENCODING_NOT_SUPPORTED,

    // --print 不能用于 ESM 输入
    ERR_EVAL_ESM_CANNOT_PRINT,

    // 事件递归
    ERR_EVENT_RECURSION,

    // JS 执行环境不可用
    ERR_EXECUTION_ENVIRONMENT_NOT_AVAILABLE,

    // Promise 被假值拒绝
    ERR_FALSY_VALUE_REJECTION,

    // 当前平台不支持该功能
    ERR_FEATURE_UNAVAILABLE_ON_PLATFORM,

    // fs.cp() 目录到非目录
    ERR_FS_CP_DIR_TO_NON_DIR,

    // fs.cp() 文件已存在
    ERR_FS_CP_EEXIST,

    // fs.cp() 无效路径
    ERR_FS_CP_EINVAL,

    // fs.cp() 命名管道
    ERR_FS_CP_FIFO_PIPE,

    // fs.cp() 非目录到目录
    ERR_FS_CP_NON_DIR_TO_DIR,

    // fs.cp() 套接字
    ERR_FS_CP_SOCKET,

    // fs.cp() 符号链接指向子目录
    ERR_FS_CP_SYMLINK_TO_SUBDIRECTORY,

    // fs.cp() 未知文件类型
    ERR_FS_CP_UNKNOWN,

    // 路径是目录
    ERR_FS_EISDIR,

    // 文件太大
    ERR_FS_FILE_TOO_LARGE,

    // 无效的符号链接类型
    ERR_FS_INVALID_SYMLINK_TYPE,

    // HTTP 头已发送
    ERR_HTTP_HEADERS_SENT,

    // 无效的 HTTP 头值
    ERR_HTTP_INVALID_HEADER_VALUE,

    // 无效的 HTTP 状态码
    ERR_HTTP_INVALID_STATUS_CODE,

    // HTTP 请求超时
    ERR_HTTP_REQUEST_TIMEOUT,

    // 不允许更改 socket 编码
    ERR_HTTP_SOCKET_ENCODING,

    // 无效的 HTTP Trailer
    ERR_HTTP_TRAILER_INVALID,

    // HTTP/2 ALTSVC 无效源
    ERR_HTTP2_ALTSVC_INVALID_ORIGIN,

    // HTTP/2 ALTSVC 长度超限
    ERR_HTTP2_ALTSVC_LENGTH,

    // HTTP/2 CONNECT 需要 :authority
    ERR_HTTP2_CONNECT_AUTHORITY,

    // HTTP/2 CONNECT 禁止 :path
    ERR_HTTP2_CONNECT_PATH,

    // HTTP/2 CONNECT 禁止 :scheme
    ERR_HTTP2_CONNECT_SCHEME,

    // HTTP/2 通用错误
    ERR_HTTP2_ERROR,

    // HTTP/2 GOAWAY 后不能打开新流
    ERR_HTTP2_GOAWAY_SESSION,

    // HTTP/2 头字段应该是单值
    ERR_HTTP2_HEADER_SINGLE_VALUE,

    // HTTP/2 响应后设置了额外头
    ERR_HTTP2_HEADERS_AFTER_RESPOND,

    // HTTP/2 多次发送响应头
    ERR_HTTP2_HEADERS_SENT,

    // HTTP/2 不允许信息状态码
    ERR_HTTP2_INFO_STATUS_NOT_ALLOWED,

    // HTTP/2 无效连接头
    ERR_HTTP2_INVALID_CONNECTION_HEADERS,

    // HTTP/2 无效头值
    ERR_HTTP2_INVALID_HEADER_VALUE,

    // HTTP/2 无效信息状态码
    ERR_HTTP2_INVALID_INFO_STATUS,

    // HTTP/2 无效源
    ERR_HTTP2_INVALID_ORIGIN,

    // HTTP/2 无效的打包设置长度
    ERR_HTTP2_INVALID_PACKED_SETTINGS_LENGTH,

    // HTTP/2 无效伪头
    ERR_HTTP2_INVALID_PSEUDOHEADER,

    // HTTP/2 无效会话
    ERR_HTTP2_INVALID_SESSION,

    // HTTP/2 无效设置值
    ERR_HTTP2_INVALID_SETTING_VALUE,

    // HTTP/2 无效流
    ERR_HTTP2_INVALID_STREAM,

    // HTTP/2 待确认设置过多
    ERR_HTTP2_MAX_PENDING_SETTINGS_ACK,

    // HTTP/2 嵌套推送
    ERR_HTTP2_NESTED_PUSH,

    // HTTP/2 内存不足
    ERR_HTTP2_NO_MEM,

    // HTTP/2 不能直接操作 socket
    ERR_HTTP2_NO_SOCKET_MANIPULATION,

    // HTTP/2 ORIGIN 帧长度超限
    ERR_HTTP2_ORIGIN_LENGTH,

    // HTTP/2 流数量超限
    ERR_HTTP2_OUT_OF_STREAMS,

    // HTTP/2 禁止的消息负载
    ERR_HTTP2_PAYLOAD_FORBIDDEN,

    // HTTP/2 ping 被取消
    ERR_HTTP2_PING_CANCEL,

    // HTTP/2 ping 负载长度必须为 8 字节
    ERR_HTTP2_PING_LENGTH,

    // HTTP/2 不允许的伪头
    ERR_HTTP2_PSEUDOHEADER_NOT_ALLOWED,

    // HTTP/2 推送被客户端禁用
    ERR_HTTP2_PUSH_DISABLED,

    // HTTP/2 responseWithFile 发送了目录
    ERR_HTTP2_SEND_FILE,

    // HTTP/2 responseWithFile 不支持 seek
    ERR_HTTP2_SEND_FILE_NOSEEK,

    // HTTP/2 会话错误
    ERR_HTTP2_SESSION_ERROR,

    // HTTP/2 设置被取消
    ERR_HTTP2_SETTINGS_CANCEL,

    // HTTP/2 socket 已绑定
    ERR_HTTP2_SOCKET_BOUND,

    // HTTP/2 socket 未绑定
    ERR_HTTP2_SOCKET_UNBOUND,

    // HTTP/2 禁止使用 101 状态码
    ERR_HTTP2_STATUS_101,

    // HTTP/2 无效状态码
    ERR_HTTP2_STATUS_INVALID,

    // HTTP/2 流被取消
    ERR_HTTP2_STREAM_CANCEL,

    // HTTP/2 流错误
    ERR_HTTP2_STREAM_ERROR,

    // HTTP/2 流自依赖
    ERR_HTTP2_STREAM_SELF_DEPENDENCY,

    // HTTP/2 过多无效帧
    ERR_HTTP2_TOO_MANY_INVALID_FRAMES,

    // HTTP/2 trailer 已发送
    ERR_HTTP2_TRAILERS_ALREADY_SENT,

    // HTTP/2 trailer 未就绪
    ERR_HTTP2_TRAILERS_NOT_READY,

    // HTTP/2 不支持的协议
    ERR_HTTP2_UNSUPPORTED_PROTOCOL,

    // 非法构造函数
    ERR_ILLEGAL_CONSTRUCTOR,

    // 导入断言类型失败
    ERR_IMPORT_ASSERTION_TYPE_FAILED,

    // 缺少导入断言类型
    ERR_IMPORT_ASSERTION_TYPE_MISSING,

    // 不支持的导入断言类型
    ERR_IMPORT_ASSERTION_TYPE_UNSUPPORTED,

    // 不兼容的选项对
    ERR_INCOMPATIBLE_OPTION_PAIR,

    // 不允许的输入类型
    ERR_INPUT_TYPE_NOT_ALLOWED,

    // Inspector 已激活
    ERR_INSPECTOR_ALREADY_ACTIVATED,

    // Inspector 已连接
    ERR_INSPECTOR_ALREADY_CONNECTED,

    // Inspector 已关闭
    ERR_INSPECTOR_CLOSED,

    // Inspector 命令错误
    ERR_INSPECTOR_COMMAND,

    // Inspector 未激活
    ERR_INSPECTOR_NOT_ACTIVE,

    // Inspector 不可用
    ERR_INSPECTOR_NOT_AVAILABLE,

    // Inspector 未连接
    ERR_INSPECTOR_NOT_CONNECTED,

    // Inspector 非 Worker
    ERR_INSPECTOR_NOT_WORKER,

    // 内部断言失败
    ERR_INTERNAL_ASSERTION,

    // 无效的 IP 地址
    ERR_INVALID_ADDRESS,

    // 无效的地址族
    ERR_INVALID_ADDRESS_FAMILY,

    // 参数类型错误
    ERR_INVALID_ARG_TYPE,

    // 参数值无效
    ERR_INVALID_ARG_VALUE,

    // 无效的异步 ID
    ERR_INVALID_ASYNC_ID,

    // Buffer 大小不兼容
    ERR_INVALID_BUFFER_SIZE,

    // 缺少回调函数
    ERR_INVALID_CALLBACK,

    // 头中包含无效字符
    ERR_INVALID_CHAR,

    // 无效的光标位置
    ERR_INVALID_CURSOR_POS,

    // 无效的文件描述符
    ERR_INVALID_FD,

    // 无效的文件描述符类型
    ERR_INVALID_FD_TYPE,

    // file: URL 主机不兼容
    ERR_INVALID_FILE_URL_HOST,

    // file: URL 路径不兼容
    ERR_INVALID_FILE_URL_PATH,

    // 无效的句柄类型
    ERR_INVALID_HANDLE_TYPE,

    // 无效的 HTTP token
    ERR_INVALID_HTTP_TOKEN,

    // 无效的 IP 地址
    ERR_INVALID_IP_ADDRESS,

    // 无效的模块
    ERR_INVALID_MODULE,

    // 无效的模块说明符
    ERR_INVALID_MODULE_SPECIFIER,

    // package.json 解析失败
    ERR_INVALID_PACKAGE_CONFIG,

    // package.json exports 无效目标
    ERR_INVALID_PACKAGE_TARGET,

    // 无效的性能标记
    ERR_INVALID_PERFORMANCE_MARK,

    // 无效的协议
    ERR_INVALID_PROTOCOL,

    // 无效的 REPL eval 配置
    ERR_INVALID_REPL_EVAL_CONFIG,

    // 无效的 REPL 输入
    ERR_INVALID_REPL_INPUT,

    // 返回属性无效
    ERR_INVALID_RETURN_PROPERTY,

    // 返回属性值类型无效
    ERR_INVALID_RETURN_PROPERTY_VALUE,

    // 返回值类型无效
    ERR_INVALID_RETURN_VALUE,

    // 无效状态
    ERR_INVALID_STATE,

    // 无效的同步 fork 输入
    ERR_INVALID_SYNC_FORK_INPUT,

    // this 值无效
    ERR_INVALID_THIS,

    // 无效的传输对象
    ERR_INVALID_TRANSFER_OBJECT,

    // 无效的元组
    ERR_INVALID_TUPLE,

    // 无效的 URI
    ERR_INVALID_URI,

    // 无效的 URL
    ERR_INVALID_URL,

    // URL 协议不兼容
    ERR_INVALID_URL_SCHEME,

    // IPC 通道已关闭
    ERR_IPC_CHANNEL_CLOSED,

    // IPC 已断开
    ERR_IPC_DISCONNECTED,

    // IPC 只能有一个管道
    ERR_IPC_ONE_PIPE,

    // IPC 同步 fork
    ERR_IPC_SYNC_FORK,

    // 策略清单断言完整性失败
    ERR_MANIFEST_ASSERT_INTEGRITY,

    // 策略清单缺少依赖
    ERR_MANIFEST_DEPENDENCY_MISSING,

    // 策略清单完整性不匹配
    ERR_MANIFEST_INTEGRITY_MISMATCH,

    // 策略清单无效资源字段
    ERR_MANIFEST_INVALID_RESOURCE_FIELD,

    // 策略清单无效说明符
    ERR_MANIFEST_INVALID_SPECIFIER,

    // 策略清单解析失败
    ERR_MANIFEST_PARSE_POLICY,

    // 策略清单 TDZ
    ERR_MANIFEST_TDZ,

    // 策略清单未知 onerror
    ERR_MANIFEST_UNKNOWN_ONERROR,

    // 内存分配失败
    ERR_MEMORY_ALLOCATION_FAILED,

    // 消息目标上下文不可用
    ERR_MESSAGE_TARGET_CONTEXT_UNAVAILABLE,

    // 方法未实现
    ERR_METHOD_NOT_IMPLEMENTED,

    // 缺少参数
    ERR_MISSING_ARGS,

    // 缺少必要选项
    ERR_MISSING_OPTION,

    // 缺少密码短语
    ERR_MISSING_PASSPHRASE,

    // Worker 平台不可用
    ERR_MISSING_PLATFORM_FOR_WORKER,

    // 传输列表中缺少可传输对象
    ERR_MISSING_TRANSFERABLE_IN_TRANSFER_LIST,

    // 模块未找到
    ERR_MODULE_NOT_FOUND,

    // 多次回调
    ERR_MULTIPLE_CALLBACK,

    // N-API 构造函数不是函数
    ERR_NAPI_CONS_FUNCTION,

    // N-API DataView 参数无效
    ERR_NAPI_INVALID_DATAVIEW_ARGS,

    // N-API TypedArray 对齐无效
    ERR_NAPI_INVALID_TYPEDARRAY_ALIGNMENT,

    // N-API TypedArray 长度无效
    ERR_NAPI_INVALID_TYPEDARRAY_LENGTH,

    // N-API 线程安全函数调用 JS 失败
    ERR_NAPI_TSFN_CALL_JS,

    // N-API 获取 undefined 失败
    ERR_NAPI_TSFN_GET_UNDEFINED,

    // N-API 启动空闲循环失败
    ERR_NAPI_TSFN_START_IDLE_LOOP,

    // N-API 停止空闲循环失败
    ERR_NAPI_TSFN_STOP_IDLE_LOOP,

    // 无加密支持
    ERR_NO_CRYPTO,

    // 无 ICU 支持
    ERR_NO_ICU,

    // 非上下文感知的原生插件被禁用
    ERR_NON_CONTEXT_AWARE_DISABLED,

    // 值超出范围
    ERR_OUT_OF_RANGE,

    // package.json imports 未定义该说明符
    ERR_PACKAGE_IMPORT_NOT_DEFINED,

    // package.json exports 未导出该子路径
    ERR_PACKAGE_PATH_NOT_EXPORTED,

    // 无效的性能时间戳
    ERR_PERFORMANCE_INVALID_TIMESTAMP,

    // 无效的性能度量选项
    ERR_PERFORMANCE_MEASURE_INVALID_OPTIONS,

    // __proto__ 访问被禁止
    ERR_PROTO_ACCESS,

    // require() ES 模块
    ERR_REQUIRE_ESM,

    // 脚本执行被中断
    ERR_SCRIPT_EXECUTION_INTERRUPTED,

    // 脚本执行超时
    ERR_SCRIPT_EXECUTION_TIMEOUT,

    // 服务器已在监听
    ERR_SERVER_ALREADY_LISTEN,

    // 服务器未运行
    ERR_SERVER_NOT_RUNNING,

    // Socket 已绑定
    ERR_SOCKET_ALREADY_BOUND,

    // Socket 缓冲区大小无效
    ERR_SOCKET_BAD_BUFFER_SIZE,

    // Socket 端口无效
    ERR_SOCKET_BAD_PORT,

    // Socket 类型无效
    ERR_SOCKET_BAD_TYPE,

    // Socket 缓冲区大小
    ERR_SOCKET_BUFFER_SIZE,

    // Socket 已关闭
    ERR_SOCKET_CLOSED,

    // UDP socket 已连接
    ERR_SOCKET_DGRAM_IS_CONNECTED,

    // UDP socket 未连接
    ERR_SOCKET_DGRAM_NOT_CONNECTED,

    // UDP 子系统未运行
    ERR_SOCKET_DGRAM_NOT_RUNNING,

    // SRI 解析失败
    ERR_SRI_PARSE,

    // 流已完成
    ERR_STREAM_ALREADY_FINISHED,

    // 不能 pipe 到 Writable
    ERR_STREAM_CANNOT_PIPE,

    // 流已销毁
    ERR_STREAM_DESTROYED,

    // 流中遇到 null 值
    ERR_STREAM_NULL_VALUES,

    // 流过早关闭
    ERR_STREAM_PREMATURE_CLOSE,

    // EOF 后调用 push
    ERR_STREAM_PUSH_AFTER_EOF,

    // end 事件后调用 unshift
    ERR_STREAM_UNSHIFT_AFTER_END_EVENT,

    // 流包装器
    ERR_STREAM_WRAP,

    // end 后调用 write
    ERR_STREAM_WRITE_AFTER_END,

    // 字符串过长
    ERR_STRING_TOO_LONG,

    // 合成错误
    ERR_SYNTHETIC,

    // 系统错误
    ERR_SYSTEM_ERROR,

    // TLS 证书主题备用名称格式错误
    ERR_TLS_CERT_ALTNAME_FORMAT,

    // TLS 证书主题备用名称无效
    ERR_TLS_CERT_ALTNAME_INVALID,

    // TLS DH 参数太小
    ERR_TLS_DH_PARAM_SIZE,

    // TLS 握手超时
    ERR_TLS_HANDSHAKE_TIMEOUT,

    // TLS 上下文无效
    ERR_TLS_INVALID_CONTEXT,

    // TLS 协议方法无效
    ERR_TLS_INVALID_PROTOCOL_METHOD,

    // TLS 协议版本无效
    ERR_TLS_INVALID_PROTOCOL_VERSION,

    // TLS 状态无效
    ERR_TLS_INVALID_STATE,

    // TLS 协议版本冲突
    ERR_TLS_PROTOCOL_VERSION_CONFLICT,

    // TLS PSK 身份提示设置失败
    ERR_TLS_PSK_SET_IDENTIY_HINT_FAILED,

    // TLS 重新协商被禁用
    ERR_TLS_RENEGOTIATION_DISABLED,

    // TLS 需要服务器名称
    ERR_TLS_REQUIRED_SERVER_NAME,

    // TLS 检测到过多重新协商
    ERR_TLS_SESSION_ATTACK,

    // TLS 从服务端发送 SNI
    ERR_TLS_SNI_FROM_SERVER,

    // 跟踪事件类别必需
    ERR_TRACE_EVENTS_CATEGORY_REQUIRED,

    // 跟踪事件不可用
    ERR_TRACE_EVENTS_UNAVAILABLE,

    // Transform 流仍在转换
    ERR_TRANSFORM_ALREADY_TRANSFORMING,

    // Transform 流写缓冲区有残留数据
    ERR_TRANSFORM_WITH_LENGTH_0,

    // TTY 初始化失败
    ERR_TTY_INIT_FAILED,

    // exit 处理器中不可用
    ERR_UNAVAILABLE_DURING_EXIT,

    // 未捕获异常回调已设置
    ERR_UNCAUGHT_EXCEPTION_CAPTURE_ALREADY_SET,

    // 未转义字符
    ERR_UNESCAPED_CHARACTERS,

    // 未处理的错误
    ERR_UNHANDLED_ERROR,

    // 未知的内置模块
    ERR_UNKNOWN_BUILTIN_MODULE,

    // 未知的凭据
    ERR_UNKNOWN_CREDENTIAL,

    // 未知的编码
    ERR_UNKNOWN_ENCODING,

    // 未知的文件扩展名
    ERR_UNKNOWN_FILE_EXTENSION,

    // 未知的模块格式
    ERR_UNKNOWN_MODULE_FORMAT,

    // 未知的信号
    ERR_UNKNOWN_SIGNAL,

    // 不支持的目录导入
    ERR_UNSUPPORTED_DIR_IMPORT,

    // 不支持的 ESM URL 方案
    ERR_UNSUPPORTED_ESM_URL_SCHEME,

    // 无效的性能条目类型
    ERR_VALID_PERFORMANCE_ENTRY_TYPE,

    // VM 动态导入回调缺失
    ERR_VM_DYNAMIC_IMPORT_CALLBACK_MISSING,

    // VM 模块已链接
    ERR_VM_MODULE_ALREADY_LINKED,

    // VM 模块缓存数据被拒绝
    ERR_VM_MODULE_CACHED_DATA_REJECTED,

    // VM 模块不能创建缓存数据
    ERR_VM_MODULE_CANNOT_CREATE_CACHED_DATA,

    // VM 模块不同上下文
    ERR_VM_MODULE_DIFFERENT_CONTEXT,

    // VM 模块链接出错
    ERR_VM_MODULE_LINKING_ERRORED,

    // VM 模块链接失败
    ERR_VM_MODULE_LINK_FAILURE,

    // VM 模块不是模块
    ERR_VM_MODULE_NOT_MODULE,

    // VM 模块状态错误
    ERR_VM_MODULE_STATUS,

    // WASI 已启动
    ERR_WASI_ALREADY_STARTED,

    // WASI 未启动
    ERR_WASI_NOT_STARTED,

    // Worker 初始化失败
    ERR_WORKER_INIT_FAILED,

    // Worker execArgv 无效
    ERR_WORKER_INVALID_EXEC_ARGV,

    // Worker 未运行
    ERR_WORKER_NOT_RUNNING,

    // Worker 内存不足
    ERR_WORKER_OUT_OF_MEMORY,

    // Worker 路径无效
    ERR_WORKER_PATH,

    // Worker 异常不可序列化
    ERR_WORKER_UNSERIALIZABLE_ERROR,

    // Worker 不支持的操作
    ERR_WORKER_UNSUPPORTED_OPERATION,

    // zlib 初始化失败
    ERR_ZLIB_INITIALIZATION_FAILED,

    // HTTP 头溢出
    HPE_HEADER_OVERFLOW,

    // 意外的 Content-Length
    HPE_UNEXPECTED_CONTENT_LENGTH,

    // 模块未找到
    MODULE_NOT_FOUND,

    // -- 已弃用 --

    // 不能传输对象
    ERR_CANNOT_TRANSFER_OBJECT,

    // hash.digest() 不支持 UTF-16
    ERR_CRYPTO_HASH_DIGEST_NO_UTF16,

    // HTTP/2 帧错误
    ERR_HTTP2_FRAME_ERROR,

    // HTTP/2 头对象
    ERR_HTTP2_HEADERS_OBJECT,

    // HTTP/2 缺少必需头
    ERR_HTTP2_HEADER_REQUIRED,

    // HTTP/2 响应后发送信息头
    ERR_HTTP2_INFO_HEADERS_AFTER_RESPOND,

    // HTTP/2 流已关闭
    ERR_HTTP2_STREAM_CLOSED,

    // HTTP 无效字符
    ERR_HTTP_INVALID_CHAR,

    // 索引超出范围
    ERR_INDEX_OUT_OF_RANGE,

    // 无效的选项值
    ERR_INVALID_OPT_VALUE,

    // 无效的选项值编码
    ERR_INVALID_OPT_VALUE_ENCODING,

    // 传输列表中缺少 MessagePort
    ERR_MISSING_MESSAGE_PORT_IN_TRANSFER_LIST,

    // N-API 原型不是对象
    ERR_NAPI_CONS_PROTOTYPE_OBJECT,

    // 不再支持
    ERR_NO_LONGER_SUPPORTED,

    // 操作失败
    ERR_OPERATION_FAILED,

    // 内存不足
    ERR_OUTOFMEMORY,

    // 解析历史数据失败
    ERR_PARSE_HISTORY_DATA,

    // Socket 不能发送
    ERR_SOCKET_CANNOT_SEND,

    // stderr 不能关闭
    ERR_STDERR_CLOSE,

    // stdout 不能关闭
    ERR_STDOUT_CLOSE,

    // 流 read 未实现
    ERR_STREAM_READ_NOT_IMPLEMENTED,

    // TLS 重新协商失败
    ERR_TLS_RENEGOTIATION_FAILED,

    // 传输外部化 SharedArrayBuffer
    ERR_TRANSFERRING_EXTERNALIZED_SHAREDARRAYBUFFER,

    // 未知的标准输入类型
    ERR_UNKNOWN_STDIN_TYPE,

    // 未知的标准输出类型
    ERR_UNKNOWN_STREAM_TYPE,

    // V8 BreakIterator
    ERR_V8BREAKITERATOR,

    // 值超出范围
    ERR_VALUE_OUT_OF_RANGE,

    // VM 模块未链接
    ERR_VM_MODULE_NOT_LINKED,

    // Worker 不支持的扩展名
    ERR_WORKER_UNSUPPORTED_EXTENSION,

    // zlib 绑定已关闭
    ERR_ZLIB_BINDING_CLOSED,

    // CPU 使用率
    ERR_CPU_USAGE,

    // parseArgs 无效选项值
    ERR_PARSE_ARGS_INVALID_OPTION_VALUE,

    // parseArgs 未知选项
    ERR_PARSE_ARGS_UNKNOWN_OPTION,

    // parseArgs 意外的位置参数
    ERR_PARSE_ARGS_UNEXPECTED_POSITIONAL,
}
