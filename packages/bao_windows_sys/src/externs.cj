// 严格翻译自: src/windows_sys/externs.zig

package bao_windows_sys

// ============================================================================
// Win32 type aliases
// ============================================================================

public type BOOL = Int32
public type BOOLEAN = UInt8
public type DWORD = UInt32
public type HANDLE = UIntPtr
public type HMODULE = UIntPtr
public type HRESULT = Int32
public type UINT = UInt32
public type LPSTR = CPointer<UInt8>
public type LPCSTR = CPointer<UInt8>
public type LPWSTR = CPointer<UInt16>
public type LPCWSTR = CPointer<UInt16>
public type PWSTR = CPointer<UInt16>
public type LPVOID = CPointer<None>
public type LPDWORD = CPointer<DWORD>
public type HPCON = CPointer<None>
public type DWORD_PTR = UInt64

// ============================================================================
// COORD struct
// ============================================================================

public class COORD {
    public var X: Int16 = 0
    public var Y: Int16 = 0

    public init() {}
    public init(X: Int16, Y: Int16) {
        this.X = X
        this.Y = Y
    }
}

// ============================================================================
// FILETIME struct
// ============================================================================

public class FILETIME {
    public var dwLowDateTime: DWORD = 0
    public var dwHighDateTime: DWORD = 0

    public init() {}
}

// ============================================================================
// BY_HANDLE_FILE_INFORMATION struct (opaque reference - defined elsewhere)
// ============================================================================

public opaque type BY_HANDLE_FILE_INFORMATION {}

// ============================================================================
// SECURITY_ATTRIBUTES struct (opaque reference)
// ============================================================================

public opaque type SECURITY_ATTRIBUTES {}

// ============================================================================
// FILE_INFO_BY_HANDLE_CLASS enum
// ============================================================================

public enum FILE_INFO_BY_HANDLE_CLASS {
    FileBasicInfo = 0
    FileStandardInfo = 1
    FileNameInfo = 2
    FileRenameInfo = 3
    FileDispositionInfo = 4
    FileAllocationInfo = 5
    FileEndOfFileInfo = 6
    FileStreamInfo = 7
    FileCompressionInfo = 8
    FileAttributeTagInfo = 9
    FileIdBothDirectoryInfo = 10
    FileIdBothDirectoryRestartInfo = 11
    FileIoPriorityHintInfo = 12
    FileRemoteProtocolInfo = 13
    FileFullDirectoryInfo = 14
    FileFullDirectoryRestartInfo = 15
    FileStorageInfo = 16
    FileAlignmentInfo = 17
    FileIdInfo = 18
    FileIdExtdDirectoryInfo = 19
    FileIdExtdDirectoryRestartInfo = 20
    FileDispositionInfoEx = 21
    FileRenameInfoEx = 22
    FileCaseSensitiveInfo = 23
    FileNormalizedNameInfo = 24
    MaximumFileInfoByHandleClass = 25
}

// ============================================================================
// kernel32 FFI extern functions
// ============================================================================

@Extern
public func GetFileInformationByHandle(
    hFile: HANDLE,
    lpFileInformation: CPointer<BY_HANDLE_FILE_INFORMATION>
): BOOL

@Extern
public func GetBinaryTypeW(
    lpApplicationName: LPCWSTR,
    lpBinaryType: LPDWORD
): BOOL

@Extern
public func SetCurrentDirectoryW(
    lpPathName: LPCWSTR
): BOOL

@Extern
public func CopyFileW(
    source: LPCWSTR,
    dest: LPCWSTR,
    bFailIfExists: BOOL
): BOOL

@Extern
public func SetFileInformationByHandle(
    file: HANDLE,
    fileInformationClass: FILE_INFO_BY_HANDLE_CLASS,
    fileInformation: LPVOID,
    bufferSize: DWORD
): BOOL

@Extern
public func GetHostNameW(
    lpBuffer: PWSTR,
    nSize: Int32
): BOOL

@Extern
public func GetTempPathW(
    nBufferLength: DWORD,
    lpBuffer: LPCWSTR
): DWORD

@Extern
public func CreateJobObjectA(
    lpJobAttributes: CPointer<None>,
    lpName: LPCSTR
): HANDLE

@Extern
public func AssignProcessToJobObject(
    hJob: HANDLE,
    hProcess: HANDLE
): BOOL

@Extern
public func ResumeThread(
    hJob: HANDLE
): DWORD

@Extern
public func SetInformationJobObject(
    hJob: HANDLE,
    JobObjectInformationClass: DWORD,
    lpJobObjectInformation: LPVOID,
    cbJobObjectInformationLength: DWORD
): BOOL

@Extern
public func OpenProcess(
    dwDesiredAccess: DWORD,
    bInheritHandle: BOOL,
    dwProcessId: DWORD
): HANDLE

@Extern
public func CreateDirectoryExW(
    lpTemplateDirectory: CPointer<UInt16>,
    lpNewDirectory: CPointer<UInt16>,
    lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>
): BOOL

@Extern
public func GetModuleHandleExW(
    dwFlags: UInt32,
    lpModuleName: CPointer<None>,
    phModule: CPointer<HMODULE>
): BOOL

@Extern
public func GetModuleFileNameW(
    hModule: HMODULE,
    lpFilename: LPWSTR,
    nSize: DWORD
): BOOL

@Extern
public func GetThreadDescription(
    thread: CPointer<None>,
    ppszThreadDescription: CPointer<PWSTR>
): HRESULT

@Extern
public func SetStdHandle(nStdHandle: UInt32, hHandle: CPointer<None>): UInt32

@Extern
public func GetConsoleOutputCP(): UInt32

@Extern
public func GetConsoleCP(): UInt32

@Extern
public func SetConsoleCP(wCodePageID: UINT): BOOL

@Extern
public func InitializeProcThreadAttributeList(
    lpAttributeList: CPointer<UInt8>,
    dwAttributeCount: DWORD,
    dwFlags: DWORD,
    size: CPointer<UInt64>
): BOOL

@Extern
public func UpdateProcThreadAttribute(
    lpAttributeList: CPointer<UInt8>,
    dwFlags: DWORD,
    Attribute: DWORD_PTR,
    lpValue: CPointer<None>,
    cbSize: UInt64,
    lpPreviousValue: CPointer<None>,
    lpReturnSize: CPointer<UInt64>
): BOOL

@Extern
public func IsProcessInJob(process: HANDLE, job: HANDLE, result: CPointer<BOOL>): BOOL

@Extern
public func CreatePseudoConsole(
    size: COORD,
    hInput: HANDLE,
    hOutput: HANDLE,
    dwFlags: DWORD,
    phPC: CPointer<HPCON>
): HRESULT

@Extern
public func ResizePseudoConsole(
    hPC: HPCON,
    size: COORD
): HRESULT

@Extern
public func ClosePseudoConsole(hPC: HPCON): Unit

@Extern
public func CloseHandle(hObject: HANDLE): BOOL

@Extern
public func GetFinalPathNameByHandleW(
    hFile: HANDLE,
    lpszFilePath: CPointer<UInt16>,
    cchFilePath: DWORD,
    dwFlags: DWORD
): DWORD

@Extern
public func DeleteFileW(lpFileName: CPointer<UInt16>): BOOL

@Extern
public func CreateSymbolicLinkW(
    lpSymlinkFileName: CPointer<UInt16>,
    lpTargetFileName: CPointer<UInt16>,
    dwFlags: DWORD
): BOOLEAN

@Extern
public func GetCurrentThread(): HANDLE

@Extern
public func GetCommandLineW(): LPWSTR

@Extern
public func CreateDirectoryW(
    lpPathName: CPointer<UInt16>,
    lpSecurityAttributes: CPointer<SECURITY_ATTRIBUTES>
): BOOL

@Extern
public func SetEndOfFile(hFile: HANDLE): BOOL

@Extern
public func GetProcessTimes(
    in_hProcess: HANDLE,
    out_lpCreationTime: CPointer<FILETIME>,
    out_lpExitTime: CPointer<FILETIME>,
    out_lpKernelTime: CPointer<FILETIME>,
    out_lpUserTime: CPointer<FILETIME>
): BOOL

// ============================================================================
// shell32 FFI extern functions
// ============================================================================

@Extern
public func CommandLineToArgvW(
    lpCmdLine: LPCWSTR,
    pNumArgs: CPointer<Int32>
): CPointer<LPWSTR>

// ============================================================================
// advapi32 FFI extern functions
// ============================================================================

@Extern
public func SaferiIsExecutableFileType(
    szFullPathname: LPCWSTR,
    bFromShellExecute: BOOLEAN
): BOOL

@Extern
public func GetUserNameW(
    lpBuffer: LPWSTR,
    pcbBuffer: LPDWORD
): BOOL

// ============================================================================
// Generic FFI extern functions (no library annotation)
// ============================================================================

@Extern
public func GetProcAddress(
    ptr: CPointer<None>,
    procName: CPointer<UInt16>
): CPointer<None>

@Extern
public func LoadLibraryA(
    lpLibFileName: CPointer<UInt8>
): CPointer<None>

@Extern
public func windows_enable_stdio_inheritance(): Unit
