// bao_ssl_macros.c
// OpenSSL functions that are macros in openssl/ssl.h
// Cangjie FFI needs actual symbol names, so we undef the macros and create real functions
#include <openssl/ssl.h>
#include <openssl/x509.h>
#include <openssl/err.h>

// Undef the macros so we can create actual functions
#ifdef SSL_CTX_set_min_proto_version
#undef SSL_CTX_set_min_proto_version
#endif
#ifdef SSL_CTX_set_max_proto_version
#undef SSL_CTX_set_max_proto_version
#endif
#ifdef SSL_set_tlsext_host_name
#undef SSL_set_tlsext_host_name
#endif
#ifdef SSL_get_peer_certificate
#undef SSL_get_peer_certificate
#endif

// Now create actual functions that call the underlying OpenSSL internals
int SSL_CTX_set_min_proto_version(SSL_CTX *ctx, int version) {
    return SSL_CTX_ctrl(ctx, SSL_CTRL_SET_MIN_PROTO_VERSION, version, NULL);
}

int SSL_CTX_set_max_proto_version(SSL_CTX *ctx, int version) {
    return SSL_CTX_ctrl(ctx, SSL_CTRL_SET_MAX_PROTO_VERSION, version, NULL);
}

int SSL_set_tlsext_host_name(SSL *s, const char *name) {
    return SSL_set_tlsext_host_name(s, name);
}

// This one is tricky - we already undef'd it, so use the OpenSSL 3.0 function directly
X509 *SSL_get_peer_certificate(const SSL *s) {
    // OpenSSL 3.0 renamed this to SSL_get1_peer_certificate
    return SSL_get1_peer_certificate((SSL *)s);
}
