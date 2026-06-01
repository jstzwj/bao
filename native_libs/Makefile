# ============================================================================
# Makefile for building native C/C++ libraries for Bao
# 从 Bun 的 uSockets + uWebSockets 源码编译静态库
# ============================================================================

BAO_ROOT := ..
OUTDIR   := $(BAO_ROOT)/target/native

CC       := gcc
CXX      := g++
AR       := ar

# GCC 兼容: -include bao_compat.h 提供 __has_feature 和 OPENSSL_PUT_ERROR 等
COMPAT   := -include bao_compat.h

# 通用编译参数
CFLAGS   := -O2 -fPIC $(COMPAT) -D_GNU_SOURCE -DLIBUS_USE_OPENSSL=1 -DLIBUS_USE_EPOLL=1 \
            -DLIBUS_USE_BORINGSSL=0 -DWITH_BORINGSSL=0 \
            -DBUN_DEBUG=1 \
            -Wno-unused-result -Wno-sign-compare

CXXFLAGS := -O2 -fPIC $(COMPAT) -std=c++17 -D_GNU_SOURCE -DLIBUS_USE_OPENSSL=1 \
            -DLIBUS_USE_EPOLL=1 -DLIBUS_USE_BORINGSSL=0 -DWITH_BORINGSSL=0 \
            -DBUN_DEBUG=1 \
            -Wno-unused-result -Wno-sign-compare -Wno-unknown-pragmas \
            -Wno-attributes -Wno-format-truncation

# Include 路径
US_INC   := -Iusockets/src -Iusockets/src/internal -Iusockets/src/crypto \
            -Iusockets/src/eventing

UWS_INC  := -Iuws/src -Iuws/include -Iuws/include/bun-uws/src \
            -Iuws/include/bun-usockets/src -Iuws/include/bun-usockets/src/internal \
            -Iuws/include/bun-usockets/src/crypto \
            -Iusockets/src -Iusockets/src/internal

SSL_INC  := $(shell pkg-config --cflags openssl 2>/dev/null)
SSL_LIBS := $(shell pkg-config --libs openssl 2>/dev/null)

# ============================================================================
# uSockets C 源文件
# ============================================================================

US_C_SRCS := \
	usockets/src/bsd.c \
	usockets/src/context.c \
	usockets/src/loop.c \
	usockets/src/socket.c \
	usockets/src/udp.c \
	usockets/src/eventing/epoll_kqueue.c \
	usockets/src/crypto/openssl.c

US_C_OBJS := $(patsubst usockets/src/%.c,$(OUTDIR)/us_%.o,$(US_C_SRCS))

# uSockets C++ 源文件 (crypto 中的 root_certs 等)
US_CXX_SRCS := \
	usockets/src/crypto/root_certs.cpp \
	usockets/src/crypto/root_certs_linux.cpp \
	usockets/src/crypto/sni_tree.cpp

US_CXX_OBJS := $(patsubst usockets/src/crypto/%.cpp,$(OUTDIR)/us_crypto_%.o,$(US_CXX_SRCS))

# ============================================================================
# uWS C++ wrapper 源文件
# ============================================================================

UWS_CXX_SRCS := \
	uws/src/libuwsockets.cpp \
	uws/src/libuwsockets_h3.cpp

# ============================================================================
# Bao C shim 文件
# ============================================================================

SHIM_SRC := $(BAO_ROOT)/packages/bao_cli/native/bao_native_ssl_shims.c
SHIM_OBJ := $(OUTDIR)/bao_native_ssl_shims.o

# ============================================================================
# 已有的 Bao native 文件
# ============================================================================

BAO_CLI_SHIMS := $(BAO_ROOT)/packages/bao_cli/native/bao_cli_native_shims.c
BAO_JSC_STUBS := $(BAO_ROOT)/packages/bao_cli/native/jsc_stubs.c
BAO_CLI_OBJ   := $(OUTDIR)/bao_cli_native_shims.o
BAO_JSC_OBJ   := $(OUTDIR)/jsc_stubs.o

# ============================================================================
# 构建目标
# ============================================================================

.PHONY: all clean info

all: $(OUTDIR)/libusockets.a $(OUTDIR)/libuwsockets.a $(SHIM_OBJ) $(BAO_CLI_OBJ) $(BAO_JSC_OBJ)

info:
	@echo "=== uSockets C sources ==="
	@echo $(US_C_SRCS)
	@echo "=== uSockets C++ sources ==="
	@echo $(US_CXX_SRCS)
	@echo "=== uWS C++ sources ==="
	@echo $(UWS_CXX_SRCS)
	@echo "=== OpenSSL ==="
	@echo "CFLAGS: $(SSL_INC)"
	@echo "LIBS: $(SSL_LIBS)"

# --- uSockets 静态库 ---
$(OUTDIR)/libusockets.a: $(US_C_OBJS) $(US_CXX_OBJS)
	$(AR) rcs $@ $^

$(OUTDIR)/us_%.o: usockets/src/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(US_INC) $(SSL_INC) -c $< -o $@

$(OUTDIR)/us_eventing_%.o: usockets/src/eventing/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(US_INC) $(SSL_INC) -c $< -o $@

$(OUTDIR)/us_crypto_%.o: usockets/src/crypto/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(US_INC) $(SSL_INC) -c $< -o $@

$(OUTDIR)/us_crypto_%.o: usockets/src/crypto/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(US_INC) $(SSL_INC) -c $< -o $@

# --- uWS 静态库 ---
$(OUTDIR)/libuwsockets.a: $(OUTDIR)/uws_libuwsockets.o $(OUTDIR)/uws_libuwsockets_h3.o
	$(AR) rcs $@ $^

$(OUTDIR)/uws_%.o: uws/src/%.cpp
	@mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(UWS_INC) $(SSL_INC) -c $< -o $@

# --- Bao shims ---
$(SHIM_OBJ): $(SHIM_SRC)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BAO_CLI_OBJ): $(BAO_CLI_SHIMS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BAO_JSC_OBJ): $(BAO_JSC_STUBS)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OUTDIR)/libusockets.a $(OUTDIR)/libuwsockets.a
	rm -f $(OUTDIR)/us_*.o $(OUTDIR)/uws_*.o $(OUTDIR)/bao_native_ssl_shims.o
	rm -f $(OUTDIR)/bao_cli_native_shims.o $(OUTDIR)/jsc_stubs.o
