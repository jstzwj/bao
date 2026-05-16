// 严格翻译自: src/windows_sys/externs.zig

package bao_windows_sys

// ============================================================================
// Win32 type aliases
// ============================================================================

public type BOOL = Int32
public type BOOLEAN = UInt8
public type DWORD = UInt32
public type HANDLE = UIntNative
public type HMODULE = UIntNative
public type HRESULT = Int32
public type UINT = UInt32
public type LPSTR = CPointer<UInt8>
public type LPCSTR = CPointer<UInt8>
public type LPWSTR = CPointer<UInt16>
public type LPCWSTR = CPointer<UInt16>
public type PWSTR = CPointer<UInt16>
public type LPVOID = CPointer<Unit>
public type LPDWORD = CPointer<DWORD>
public type HPCON = CPointer<Unit>
public type DWORD_PTR = UInt64

// ============================================================================
// COORD struct - must be @C struct for FFI
// ============================================================================

@C
public struct COORD {
    public var X: Int16 = 0
    public var Y: Int16 = 0
}

// ============================================================================
// FILETIME struct - must be @C struct for FFI
// ============================================================================

@C
public struct FILETIME {
    public var dwLowDateTime: DWORD = 0
    public var dwHighDateTime: DWORD = 0
}

// ============================================================================
// BY_HANDLE_FILE_INFORMATION struct (opaque reference - defined elsewhere)
// ============================================================================

@C
public struct BY_HANDLE_FILE_INFORMATION {}

// ============================================================================
// SECURITY_ATTRIBUTES struct (opaque reference)
// ============================================================================

@C
public struct SECURITY_ATTRIBUTES {}

// ============================================================================
// FILE_INFO_BY_HANDLE_CLASS constants (enum values cannot be used in FFI)
// ============================================================================

public let FILE_INFO_BY_HANDLE_CLASS_FileBasicInfo: DWORD = 0
public let FILE_INFO_BY_HANDLE_CLASS_FileStandardInfo: DWORD = 1

// ============================================================================
// kernel32 FFI extern functions
// ============================================================================

foreign func GetFileInformationByHandle(
    hFile: HANDLE,
    lpFileInformation: CPointer<BY_HANDLE_FILE_INFORMATION>
): BOOL

foreign func GetBinaryTypeW(
    lpApplicationName: LPCWSTR,
    lpBinaryType: LPDWORD
): BOOL

foreign func SetCurrentDirectoryW(
    lpPathName: LPCWSTR
): BOOL

foreign func CopyFileW(
    source: LPCWSTR,
    dest: LPCWSTR,
    bFailIfExists: BOOL
): BOOL

foreign func SetFileInformationByHandle(
    file: HANDLE,
    fileInformationClass: DWORD,
    fileInformation: LPVOID,
    bufferSize: DWORD
): BOOL

foreign func GetHostNameW(
    lpBuffer: PWSTR,
    nSize: Int32
): BOOL

foreign func GetTempPathW(
    nBufferLength: DWORD,
    lpBuffer: LPCWSTR
): DWORD

foreign func CreateJobObjectA(
    lpJobAttributes: CPointer<Unit>,
    lpName: LPCSTR
): HANDLE

foreign func AssignProcessToJobObject(
    hJob: HANDLE,
    hProcess: HANDLE
): BOOL

foreign func ResumeThread(
    hJob: HANDLE
): DWORD

foreign func SetInformationJobObject(
    hJob: HANDLE,
    JobObjectInformationClass: DWORD,
    lpJobObjectInformation: LPVOID,
    cbJobObjectInformationLength: DWORD
): BOOL

foreign func OpenProcess(
    dwDesiredAccess: DWORD,
    bInheritHandle: BOOL,
    dwProcessId: DWORD
): HANDLE

foreign func CreateDirectoryExW(
    lpTemplateDirectory: CPointer<UInt16>,
    lpNewDirectory: CPointer<UInt16>,
    lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>
): BOOL

foreign func GetModuleHandleExW(
    dwFlags: UInt32,
    lpModuleName: CPointer<Unit>,
    phModule: CPointer<HMODULE>
): BOOL

foreign func GetModuleFileNameW(
    hModule: HMODULE,
    lpFilename: LPWSTR,
    nSize: DWORD
): BOOL

foreign func GetThreadDescription(
    thread: CPointer<Unit>,
    ppszThreadDescription: CPointer<PWSTR>
): HRESULT

foreign func SetStdHandle(nStdHandle: UInt32, hHandle: CPointer<Unit>): UInt32

foreign func GetConsoleOutputCP(): UInt32

foreign func GetConsoleCP(): UInt32

foreign func SetConsoleCP(wCodePageID: UINT): BOOL

foreign func InitializeProcThreadAttributeList(
    lpAttributeList: CPointer<UInt8>,
    dwAttributeCount: DWORD,
    dwFlags: DWORD,
    size: CPointer<UInt64>
): BOOL

foreign func UpdateProcThreadAttribute(
    lpAttributeList: CPointer<UInt8>,
    dwFlags: DWORD,
    Attribute: DWORD_PTR,
    lpValue: CPointer<Unit>,
    cbSize: UInt64,
    lpPreviousValue: CPointer<Unit>,
    lpReturnSize: CPointer<UInt64>
): BOOL

foreign func IsProcessInJob(process: HANDLE, job: HANDLE, result: CPointer<BOOL>): BOOL

foreign func CreatePseudoConsole(
    size: COORD,
    hInput: HANDLE,
    hOutput: HANDLE,
    dwFlags: DWORD,
    phPC: CPointer<HPCON>
): HRESULT

foreign func ResizePseudoConsole(
    hPC: HPCON,
    size: COORD
): HRESULT

foreign func ClosePseudoConsole(hPC: HPCON): Unit

foreign func CloseHandle(hObject: HANDLE): BOOL

foreign func GetFinalPathNameByHandleW(
    hFile: HANDLE,
    lpszFilePath: CPointer<UInt16>,
    cchFilePath: DWORD,
    dwFlags: DWORD
): DWORD

foreign func DeleteFileW(lpFileName: CPointer<UInt16>): BOOL

foreign func CreateSymbolicLinkW(
    lpSymlinkFileName: CPointer<UInt16>,
    lpTargetFileName: CPointer<UInt16>,
    dwFlags: DWORD
): BOOLEAN

foreign func GetCurrentThread(): HANDLE

foreign func GetCommandLineW(): LPWSTR

foreign func CreateDirectoryW(
    lpPathName: CPointer<UInt16>,
    lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>
): BOOL

foreign func SetEndOfFile(hFile: HANDLE): BOOL

foreign func GetProcessTimes(
    in_hProcess: HANDLE,
    out_lpCreationTime: CPointer<FILETIME>,
    out_lpExitTime: CPointer<FILETIME>,
    out_lpKernelTime: CPointer<FILETIME>,
    out_lpUserTime: CPointer<FILETIME>
): BOOL

// ============================================================================
// shell32 FFI extern functions
// ============================================================================

foreign func CommandLineToArgvW(
    lpCmdLine: LPCWSTR,
    pNumArgs: CPointer<Int32>
): CPointer<LPWSTR>

// ============================================================================
// advapi32 FFI extern functions
// ============================================================================

foreign func SaferiIsExecutableFileType(
    szFullPathname: LPCWSTR,
    bFromShellExecute: BOOLEAN
): BOOL

foreign func GetUserNameW(
    lpBuffer: LPWSTR,
    pcbBuffer: LPDWORD
): BOOL

// ============================================================================
// Generic FFI extern functions (no library annotation)
// ============================================================================

foreign func GetProcAddress(
    ptr: CPointer<Unit>,
    procName: CPointer<UInt16>
): CPointer<Unit>

foreign func LoadLibraryA(
    lpLibFileName: CPointer<UInt8>
): CPointer<Unit>

foreign func windows_enable_stdio_inheritance(): Unit
