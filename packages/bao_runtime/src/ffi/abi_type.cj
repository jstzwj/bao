// ABI 类型定义 — FFI C 类型标签枚举及其查找表
// 对应 Bun: src/runtime/ffi/abi_type.rs
// 提供 ABIType 枚举、类型标签查找表、C/JS 格式化器
package bao_runtime.ffi

// ============================================================================
// ABI 类型枚举
// 对应 Bun: ABIType (abi_type.rs:16)
// ============================================================================

/// FFI C 类型标签枚举
/// 与 C ABI 对应，必须与 JSFFIFunction.h 保持同步
/// 对应 Rust: #[repr(i32)] pub enum ABIType { ... }
public enum AbiType {
    | Char       // 0  - char
    | Int8T      // 1  - int8_t
    | Uint8T     // 2  - uint8_t
    | Int16T     // 3  - int16_t
    | Uint16T    // 4  - uint16_t
    | Int32T     // 5  - int32_t
    | Uint32T    // 6  - uint32_t
    | Int64T     // 7  - int64_t
    | Uint64T    // 8  - uint64_t
    | Double     // 9  - double
    | Float      // 10 - float
    | Bool       // 11 - bool
    | Ptr        // 12 - void*
    | Void       // 13 - void
    | CString    // 14 - void* (null-terminated string)
    | I64Fast    // 15 - int64_t (fast path)
    | U64Fast    // 16 - uint64_t (fast path)
    | Function   // 17 - void* (function pointer)
    | NapiEnv    // 18 - napi_env
    | NapiValue  // 19 - napi_value
    | Buffer     // 20 - void* (typed array buffer)

    /// 最大标准类型索引 (NapiValue = 19)
    /// 对应 Rust: pub const MAX: i32 = ABIType::NapiValue as i32
    public static let MAX: Int32 = 19

    /// 从数值解析 ABI 类型
    /// 对应 Rust: ABIType::from_int (abi_type.rs:204)
    public static func fromInt(n: Int32): ?AbiType {
        match (n) {
            case 0 => AbiType.Char
            case 1 => AbiType.Int8T
            case 2 => AbiType.Uint8T
            case 3 => AbiType.Int16T
            case 4 => AbiType.Uint16T
            case 5 => AbiType.Int32T
            case 6 => AbiType.Uint32T
            case 7 => AbiType.Int64T
            case 8 => AbiType.Uint64T
            case 9 => AbiType.Double
            case 10 => AbiType.Float
            case 11 => AbiType.Bool
            case 12 => AbiType.Ptr
            case 13 => AbiType.Void
            case 14 => AbiType.CString
            case 15 => AbiType.I64Fast
            case 16 => AbiType.U64Fast
            case 17 => AbiType.Function
            case 18 => AbiType.NapiEnv
            case 19 => AbiType.NapiValue
            case 20 => AbiType.Buffer
            case _ => None
        }
    }

    /// 从字符串标签解析 ABI 类型
    /// 对应 Rust: ABI_TYPE_LABEL (abi_type.rs:76) phf_map
    public static func fromLabel(label: String): ?AbiType {
        match (label) {
            case "bool" => AbiType.Bool
            case "c_int" => AbiType.Int32T
            case "c_uint" => AbiType.Uint32T
            case "char" => AbiType.Char
            case "char*" => AbiType.Ptr
            case "double" => AbiType.Double
            case "f32" => AbiType.Float
            case "f64" => AbiType.Double
            case "float" => AbiType.Float
            case "i16" => AbiType.Int16T
            case "i32" => AbiType.Int32T
            case "i64" => AbiType.Int64T
            case "i8" => AbiType.Int8T
            case "int" => AbiType.Int32T
            case "int16_t" => AbiType.Int16T
            case "int32_t" => AbiType.Int32T
            case "int64_t" => AbiType.Int64T
            case "int8_t" => AbiType.Int8T
            case "isize" => AbiType.Int64T
            case "u16" => AbiType.Uint16T
            case "u32" => AbiType.Uint32T
            case "u64" => AbiType.Uint64T
            case "u8" => AbiType.Uint8T
            case "uint16_t" => AbiType.Uint16T
            case "uint32_t" => AbiType.Uint32T
            case "uint64_t" => AbiType.Uint64T
            case "uint8_t" => AbiType.Uint8T
            case "usize" => AbiType.Uint64T
            case "size_t" => AbiType.Uint64T
            case "buffer" => AbiType.Buffer
            case "void*" => AbiType.Ptr
            case "ptr" => AbiType.Ptr
            case "pointer" => AbiType.Ptr
            case "void" => AbiType.Void
            case "cstring" => AbiType.CString
            case "i64_fast" => AbiType.I64Fast
            case "u64_fast" => AbiType.U64Fast
            case "function" | "callback" | "fn" => AbiType.Function
            case "napi_env" => AbiType.NapiEnv
            case "napi_value" => AbiType.NapiValue
            case _ => None
        }
    }

    /// 是否为浮点类型
    /// 对应 Rust: is_floating_point (abi_type.rs:245)
    public func isFloatingPoint(): Bool {
        match (this) {
            case Double | Float => true
            case _ => false
        }
    }

    /// 是否需要在 C 中进行类型转换 (非小整数类型)
    /// 对应 Rust: needs_a_cast_in_c (abi_type.rs:232)
    public func needsACastInC(): Bool {
        match (this) {
            case Char | Int8T | Uint8T | Int16T | Uint16T | Int32T | Uint32T => false
            case _ => true
        }
    }

    /// 获取 C 类型名 (用于返回值/声明位置)
    /// 对应 Rust: typename_label (abi_type.rs:274) → AbiRow.c_type
    public func typenameLabel(): String {
        match (this) {
            case Char => "char"
            case Int8T => "int8_t"
            case Uint8T => "uint8_t"
            case Int16T => "int16_t"
            case Uint16T => "uint16_t"
            case Int32T => "int32_t"
            case Uint32T => "uint32_t"
            case Int64T | I64Fast => "int64_t"
            case Uint64T | U64Fast => "uint64_t"
            case Double => "double"
            case Float => "float"
            case Bool => "bool"
            case Ptr => "void*"
            case Void => "void"
            case CString => "void*"
            case Function => "void*"
            case NapiEnv => "napi_env"
            case NapiValue => "napi_value"
            case Buffer => "void*"
        }
    }

    /// 获取 C 参数类型名 (用于参数位置)
    /// 对应 Rust: param_typename_label (abi_type.rs:284) → AbiRow.c_param_type
    /// 与 typenameLabel 的区别：Uint32T 在参数位置使用 int32_t, Buffer 使用 buffer
    public func paramTypenameLabel(): String {
        match (this) {
            case Uint32T => "int32_t"
            case Buffer => "buffer"
            case _ => typenameLabel()
        }
    }

    /// 生成将 JS 值转换为 C 值的代码
    /// 对应 Rust: ToCFormatter (abi_type.rs:307)
    public func toCFormatter(symbol: String, exact: Bool): String {
        match (this) {
            case Void => ""
            case NapiEnv => "((napi_env)&Bun__thisFFIModuleNapiEnv)"
            case NapiValue => "${symbol}.asNapiValue"
            case Char => {
                if (exact) { "(char)JSVALUE_TO_INT32(${symbol})" }
                else { "JSVALUE_TO_INT32(${symbol})" }
            }
            case Int8T => {
                if (exact) { "(int8_t)JSVALUE_TO_INT32(${symbol})" }
                else { "JSVALUE_TO_INT32(${symbol})" }
            }
            case Uint8T => {
                if (exact) { "(uint8_t)JSVALUE_TO_INT32(${symbol})" }
                else { "JSVALUE_TO_INT32(${symbol})" }
            }
            case Int16T => {
                if (exact) { "(int16_t)JSVALUE_TO_INT32(${symbol})" }
                else { "JSVALUE_TO_INT32(${symbol})" }
            }
            case Uint16T => {
                if (exact) { "(uint16_t)JSVALUE_TO_INT32(${symbol})" }
                else { "JSVALUE_TO_INT32(${symbol})" }
            }
            case Int32T => {
                if (exact) { "(int32_t)JSVALUE_TO_INT32(${symbol})" }
                else { "JSVALUE_TO_INT32(${symbol})" }
            }
            case Uint32T => {
                if (exact) { "(uint32_t)JSVALUE_TO_INT32(${symbol})" }
                else { "JSVALUE_TO_INT32(${symbol})" }
            }
            case Int64T => {
                if (exact) { "(int64_t)JSVALUE_TO_INT64(${symbol})" }
                else { "JSVALUE_TO_INT64(${symbol})" }
            }
            case Uint64T => {
                if (exact) { "(uint64_t)JSVALUE_TO_UINT64(${symbol})" }
                else { "JSVALUE_TO_UINT64(${symbol})" }
            }
            case Double => {
                if (exact) { "(double)JSVALUE_TO_DOUBLE(${symbol})" }
                else { "JSVALUE_TO_DOUBLE(${symbol})" }
            }
            case Float => {
                if (exact) { "(float)JSVALUE_TO_FLOAT(${symbol})" }
                else { "JSVALUE_TO_FLOAT(${symbol})" }
            }
            case Bool => {
                if (exact) { "(bool)JSVALUE_TO_BOOL(${symbol})" }
                else { "JSVALUE_TO_BOOL(${symbol})" }
            }
            case Ptr | CString | Function => {
                if (exact) { "(void*)JSVALUE_TO_PTR(${symbol})" }
                else { "JSVALUE_TO_PTR(${symbol})" }
            }
            case Buffer => "JSVALUE_TO_TYPED_ARRAY_VECTOR(${symbol})"
            case I64Fast => {
                if (exact) { "(int64_t)JSVALUE_TO_INT64(${symbol})" }
                else { "JSVALUE_TO_INT64(${symbol})" }
            }
            case U64Fast => {
                if (exact) { "(uint64_t)JSVALUE_TO_UINT64(${symbol})" }
                else { "JSVALUE_TO_UINT64(${symbol})" }
            }
        }
    }

    /// 生成将 C 值转换为 JS 值的代码
    /// 对应 Rust: ToJSFormatter (abi_type.rs:333)
    public func toJSFormatter(symbol: String): String {
        match (this) {
            case Void => ""
            case NapiEnv => "((napi_env)&Bun__thisFFIModuleNapiEnv)"
            case Buffer => "0"
            case Char => "INT32_TO_JSVALUE((int32_t)${symbol})"
            case Int8T => "INT32_TO_JSVALUE((int32_t)${symbol})"
            case Uint8T => "INT32_TO_JSVALUE((int32_t)${symbol})"
            case Int16T => "INT32_TO_JSVALUE((int32_t)${symbol})"
            case Uint16T => "INT32_TO_JSVALUE((int32_t)${symbol})"
            case Int32T => "INT32_TO_JSVALUE((int32_t)${symbol})"
            case Uint32T => "UINT32_TO_JSVALUE(${symbol})"
            case Int64T => "INT64_TO_JSVALUE_SLOW(JS_GLOBAL_OBJECT, ${symbol})"
            case Uint64T => "UINT64_TO_JSVALUE_SLOW(JS_GLOBAL_OBJECT, ${symbol})"
            case Double => "DOUBLE_TO_JSVALUE(${symbol})"
            case Float => "FLOAT_TO_JSVALUE(${symbol})"
            case Bool => "BOOLEAN_TO_JSVALUE(${symbol})"
            case Ptr | CString | Function => "PTR_TO_JSVALUE(${symbol})"
            case I64Fast => "INT64_TO_JSVALUE(JS_GLOBAL_OBJECT, (int64_t)${symbol})"
            case U64Fast => "UINT64_TO_JSVALUE(JS_GLOBAL_OBJECT, ${symbol})"
            case NapiValue => "((EncodedJSValue) {.asNapiValue = ${symbol} } )"
        }
    }

    /// 转为整数值 (枚举判别值)
    public func toInt32(): Int32 {
        match (this) {
            case Char => 0
            case Int8T => 1
            case Uint8T => 2
            case Int16T => 3
            case Uint16T => 4
            case Int32T => 5
            case Uint32T => 6
            case Int64T => 7
            case Uint64T => 8
            case Double => 9
            case Float => 10
            case Bool => 11
            case Ptr => 12
            case Void => 13
            case CString => 14
            case I64Fast => 15
            case U64Fast => 16
            case Function => 17
            case NapiEnv => 18
            case NapiValue => 19
            case Buffer => 20
        }
    }
}

// ============================================================================
// 枚举映射格式化器
// 对应 Bun: EnumMapFormatter (abi_type.rs:288)
// ============================================================================

/// 用于生成 JS 对象映射的格式化器
/// 对应 Rust: pub struct EnumMapFormatter
public class EnumMapFormatter {
    public var name: String
    public var entry: AbiType

    public init(name: String, entry: AbiType) {
        this.name = name
        this.entry = entry
    }

    /// 格式化为 JS 对象映射条目
    /// 对应 Rust: fmt::Display for EnumMapFormatter
    public func format(): String {
        return "['${name}']:${entry.toInt32()},'${entry.toInt32()}':${entry.toInt32()}"
    }
}
