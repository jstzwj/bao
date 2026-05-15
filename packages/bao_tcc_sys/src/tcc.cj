// 严格翻译自: src/tcc_sys/tcc.zig

package bao_tcc_sys

// ============================================================================
// Opaque types
// ============================================================================

public opaque type TCCState {}
public opaque type Symbol {}

// ============================================================================
// Callback function types
// ============================================================================

public type TCCErrorFunc = CFunctionPointer<(CPointer<None>, CPointer<UInt8>) -> Unit>

public type SymbolCallbackFunc = CFunctionPointer<(CPointer<None>, CPointer<UInt8>, CPointer<None>) -> Unit>

// ============================================================================
// Output format constants
// ============================================================================

public let TCC_OUTPUT_MEMORY: Int32 = 1
public let TCC_OUTPUT_EXE: Int32 = 2
public let TCC_OUTPUT_DLL: Int32 = 3
public let TCC_OUTPUT_OBJ: Int32 = 4
public let TCC_OUTPUT_PREPROCESS: Int32 = 5

// ============================================================================
// OutputFormat enum
// ============================================================================

public enum OutputFormat {
    Memory = 1   // TCC_OUTPUT_MEMORY
    Exe = 2      // TCC_OUTPUT_EXE
    Dll = 3      // TCC_OUTPUT_DLL
    Obj = 4      // TCC_OUTPUT_OBJ
    Preprocess = 5  // TCC_OUTPUT_PREPROCESS
}

// ============================================================================
// Error enum
// ============================================================================

public enum TCCError {
    InvalidOptions
    InvalidIncludePath
    CompileError
    InvalidOutputType
    SyntaxError
    InvalidLibraryPath
    InvalidSymbol
    ExecError
    RelocationError
    OutputError
}

// ============================================================================
// FFI extern functions - Core TCC API
// ============================================================================

@Extern
public func tcc_new(): CPointer<TCCState>

@Extern
public func tcc_delete(s: CPointer<TCCState>): Unit

@Extern
public func tcc_set_lib_path(s: CPointer<TCCState>, path: CPointer<UInt8>): Unit

@Extern
public func tcc_set_error_func(s: CPointer<TCCState>, error_opaque: CPointer<None>, error_func: TCCErrorFunc): Unit

@Extern
public func tcc_get_error_func(s: CPointer<TCCState>): TCCErrorFunc

@Extern
public func tcc_get_error_opaque(s: CPointer<TCCState>): CPointer<None>

@Extern
public func tcc_set_options(s: CPointer<TCCState>, str: CPointer<UInt8>): Int32

// ============================================================================
// FFI extern functions - Preprocessor
// ============================================================================

@Extern
public func tcc_add_include_path(s: CPointer<TCCState>, pathname: CPointer<UInt8>): Int32

@Extern
public func tcc_add_sysinclude_path(s: CPointer<TCCState>, pathname: CPointer<UInt8>): Int32

@Extern
public func tcc_define_symbol(s: CPointer<TCCState>, sym: CPointer<UInt8>, value: CPointer<UInt8>): Unit

@Extern
public func tcc_undefine_symbol(s: CPointer<TCCState>, sym: CPointer<UInt8>): Unit

// ============================================================================
// FFI extern functions - Compiling
// ============================================================================

@Extern
public func tcc_add_file(s: CPointer<TCCState>, filename: CPointer<UInt8>): Int32

@Extern
public func tcc_compile_string(s: CPointer<TCCState>, buf: CPointer<UInt8>): Int32

// ============================================================================
// FFI extern functions - Linking
// ============================================================================

@Extern
public func tcc_set_output_type(s: CPointer<TCCState>, output_type: Int32): Int32

@Extern
public func tcc_add_library_path(s: CPointer<TCCState>, pathname: CPointer<UInt8>): Int32

@Extern
public func tcc_add_library(s: CPointer<TCCState>, libraryname: CPointer<UInt8>): Int32

@Extern
public func tcc_add_symbol(s: CPointer<TCCState>, name: CPointer<UInt8>, val: CPointer<None>): Int32

@Extern
public func tcc_output_file(s: CPointer<TCCState>, filename: CPointer<UInt8>): Int32

@Extern
public func tcc_run(s: CPointer<TCCState>, argc: Int32, argv: CPointer<CPointer<UInt8>>): Int32

@Extern
public func tcc_relocate(s1: CPointer<TCCState>): Int32

@Extern
public func tcc_get_symbol(s: CPointer<TCCState>, name: CPointer<UInt8>): CPointer<None>

@Extern
public func tcc_list_symbols(s: CPointer<TCCState>, ctx: CPointer<None>, symbol_cb: SymbolCallbackFunc): Unit

// ============================================================================
// Type alias
// ============================================================================

public type State = TCCState
