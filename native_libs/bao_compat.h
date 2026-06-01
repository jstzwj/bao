// bao_compat.h — GCC + standard OpenSSL compatibility shims for Bun native code
// Included via -include bao_compat.h in CFLAGS/CXXFLAGS
#ifndef BAO_COMPAT_H
#define BAO_COMPAT_H

// Make __has_feature work with GCC (always returns 0)
#ifndef __has_feature
#define __has_feature(x) 0
#endif

// BoringSSL uses OPENSSL_PUT_ERROR which doesn't exist in standard OpenSSL.
// Map to no-op for now (error reporting only, doesn't affect functionality)
#include <openssl/err.h>
#ifndef OPENSSL_PUT_ERROR
// In BoringSSL: OPENSSL_PUT_ERROR(lib, reason) → ERR_put_error(lib, func, reason, file, line)
// Standard OpenSSL has ERR_put_error but with different args
// Use a simplified version
#define OPENSSL_PUT_ERROR(lib, reason) do { } while(0)
#endif

// BoringSSL error reason constants that may not exist in standard OpenSSL
#ifndef ERR_R_SYS_LIB
#define ERR_R_SYS_LIB ERR_R_SYS
#endif
#ifndef ERR_R_MALLOC_FAILURE
#define ERR_R_MALLOC_FAILURE ERR_R_MALLOC_FAILURE
#endif
#ifndef ERR_R_PEM_LIB
#define ERR_R_PEM_LIB ERR_R_PEM_LIB
#endif

#endif // BAO_COMPAT_H
