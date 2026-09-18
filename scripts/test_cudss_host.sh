#!/usr/bin/env bash
# Unit-test the host side of the cuDSS path, without a GPU.
#   test_cudss_host.sh
#
# LinAlg_CUDSS.cpp does two things on the CPU before cuDSS ever sees the
# problem: it works out whether the matrix can be described by its upper
# triangle alone (complex symmetric - half the flops, half the factor), and it
# re-checks on every solve that the two triangles still agree numerically. Get
# either wrong and the GPU is handed a different matrix than the one being
# solved. Both are pure host code, so they are tested here rather than only on
# the one machine with an NVIDIA card - this runs anywhere the cross-compiler
# and the cuDSS headers are present.
#
# Needs CUDSS_DIR and CUDA_TOOLKIT_DIR, the same two build.sh takes. The test
# links the real cuDSS import library (it never calls it), so cudss64_0.dll
# must be loadable - it is put on PATH below.
set -e
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$PATH
SCRIPTS=$(cd "$(dirname "$0")" && pwd)
ROOT=${ROOT:-$(cd "$SCRIPTS/../src" && pwd)}
KERNEL=$ROOT/cenos-getdp-fork/src/kernel
TEST=$SCRIPTS/../tests/cudss_host/selftest.cpp

: "${CUDSS_DIR:?set CUDSS_DIR (cuDSS install with include/cudss.h)}"
: "${CUDA_TOOLKIT_DIR:?set CUDA_TOOLKIT_DIR (CUDA with include/cuda_runtime.h)}"
[ -f "$KERNEL/LinAlg_CUDSS.cpp" ] || { echo "no $KERNEL/LinAlg_CUDSS.cpp" >&2; exit 1; }
[ -f "$TEST" ] || { echo "no $TEST" >&2; exit 1; }

CUDA_INC=$CUDA_TOOLKIT_DIR/include
CUDSS_INC=$CUDSS_DIR/include
[ -f "$CUDA_INC/cuda_runtime.h" ] || { echo "no $CUDA_INC/cuda_runtime.h" >&2; exit 1; }
[ -f "$CUDSS_INC/cudss.h" ] || { echo "no $CUDSS_INC/cudss.h" >&2; exit 1; }

# Same rule as the CMake build: a pip-wheel CUDA flattens include/crt/*.h into
# include/, so the redirect shim goes first - and a real Toolkit install, which
# has its own crt/, must not get it.
INCS=(-I"$KERNEL" -I"$CUDA_INC" -I"$CUDSS_INC")
if [ ! -f "$CUDA_INC/crt/host_config.h" ]; then
  INCS=(-I"$KERNEL/cuda_crt_shim" "${INCS[@]}")
fi

CUDSS_LIB=$(ls "$CUDSS_DIR"/lib/13/cudss.lib "$CUDSS_DIR"/lib/cudss.lib 2>/dev/null | head -1)
CUDART_LIB=$CUDA_TOOLKIT_DIR/lib/x64/cudart.lib
[ -n "$CUDSS_LIB" ] || { echo "no cudss.lib under $CUDSS_DIR/lib" >&2; exit 1; }
[ -f "$CUDART_LIB" ] || { echo "no $CUDART_LIB" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# gs_stub.c comes along for the same reason the real build needs it: cudart.lib
# is MSVC-built and references /GS stack-cookie symbols mingw does not define.
# It must be compiled as C - through g++ its symbols would come out C++-mangled
# and the cudart loader object would still not find them.
x86_64-w64-mingw32-gcc -O1 -c "$KERNEL/gs_stub.c" -o "$WORK/gs_stub.o"

x86_64-w64-mingw32-g++ -std=c++17 -O1 -Wall -Wextra -Wno-unused-parameter \
  "${INCS[@]}" "$TEST" "$WORK/gs_stub.o" \
  "$CUDSS_LIB" "$CUDART_LIB" -o "$WORK/cudss_host_selftest.exe"

if PATH="$CUDSS_DIR/bin:$PATH" "$WORK/cudss_host_selftest.exe"; then
  exit 0
fi
echo "test_cudss_host: FAIL - see the checks above" >&2
exit 1
