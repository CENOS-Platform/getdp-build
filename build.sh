#!/usr/bin/env bash
#
# Build GetDP (MUMPS 5.6.2/METIS + MKL PARDISO).
#
# Run from a Cygwin login shell, after:  git submodule update --init --recursive
#
# ---- external dependencies: set these, nothing else is discovered ----------
#
#   MKL=<dir>               REQUIRED. oneMKL with include/ and lib/mkl_rt.lib.
#                           CENOS ships one at  <cenos>/backend/bin/Library
#
#   PY=<dir>                optional. CPython prefix with include/ and
#                           libs/$PYLIB. Set it to build the SHIPPABLE binary
#                           (embedded Python); omit for a test binary.
#                           CENOS ships one at  <cenos>/backend/bin
#   PYLIB=<file>            optional, default python310.lib
#
#   CUDSS_DIR=<dir>         optional. Supplies include/cudss.h + lib/cudss.lib.
#   CUDA_TOOLKIT_DIR=<dir>  required together with CUDSS_DIR. Supplies
#                           include/cuda_runtime.h + lib/x64/cudart.lib.
#                           Both may be the SAME directory - CENOS bundles all
#                           four at  <cenos>/backend/bin/Lib/site-packages/nvidia/cu13
#                           No CUDA Toolkit install and no nvcc needed: cuDSS is
#                           called as a plain host API, but cudart is still linked.
#
#   BUILDDIR=<name>         optional, default "build"
#
# Examples
#   # test binary, no Python, MKL from a standalone oneMKL
#   MKL=/cygdrive/c/oneMKL/latest ./build.sh
#
#   # shippable binary, everything from a CENOS install
#   C=/cygdrive/d/source/cenos/backend/bin
#   MKL=$C/Library PY=$C ./build.sh
#
#   # + GPU, all from the same CENOS install
#   NV=$C/Lib/site-packages/nvidia/cu13
#   MKL=$C/Library PY=$C CUDA_TOOLKIT_DIR=$NV CUDSS_DIR=$NV ./build.sh
#
set -e
cd "$(dirname "$0")"
export ROOT="$(pwd)/src"
# cmake 4 dropped compatibility with cmake_minimum_required(VERSION < 3.5), which
# several pinned submodules still declare (gmsh 3.3, METIS 2.8).
export CMAKE_POLICY_VERSION_MINIMUM=${CMAKE_POLICY_VERSION_MINIMUM:-3.5}
BUILDDIR=${BUILDDIR:-build}

# Every stage must agree on the C runtime - see scripts/crt.sh for why.
. ./scripts/crt.sh

: "${MKL:?set MKL to a oneMKL install (see the header of this script)}"
[ -f "$MKL/lib/mkl_rt.lib" ] || { echo "no $MKL/lib/mkl_rt.lib"; exit 1; }
[ -d "$MKL/include" ]        || { echo "no $MKL/include"; exit 1; }
[ -d src/petsc/config ]      || { echo "sources missing - run: git submodule update --init --recursive"; exit 1; }

./scripts/fix_eol.sh                        # CRLF submodule checkout -> LF

echo "MKL       : $MKL"
echo "Python    : ${PY:-<none - test binary only>}"
echo "cuDSS     : ${CUDSS_DIR:-<none>}"
echo "C runtime : $CRT ${CRT_FLAGS:+($CRT_FLAGS)}"
echo "output    : src/cenos-getdp-fork/$BUILDDIR/getdp.exe"
echo

./scripts/build_deps.sh                     # OpenBLAS, LAPACK, gmsh
./scripts/build_metis_only.sh               # METIS
./scripts/build_mkl_petsc.sh                # PETSc arch complex_mkl_metis
# Don't abort on a failed check here. The binary exists either way, and the report
# below - the import table in particular - is exactly what you need to diagnose the
# failure. The exit status is carried to the end of the script.
arch_rc=0
./scripts/build_getdp_arch.sh complex_mkl_metis "$BUILDDIR" "$MKL/lib/mkl_rt.lib" || arch_rc=$?

EXE="$ROOT/cenos-getdp-fork/$BUILDDIR/getdp.exe"
echo
if [ -x "$EXE" ]; then
  echo "OK: $EXE"
  if [ -z "${PY:-}" ]; then
    echo "NOTE: built without embedded Python."
  fi
  echo
  echo "Runtime DLLs (must be on PATH, or beside getdp.exe):"
  echo "  mkl_rt.2.dll  mkl_core.2.dll  mkl_intel_thread.2.dll  libiomp5md.dll"
  echo "  mkl_def.2.dll  mkl_avx2.2.dll  mkl_avx512.2.dll  mkl_mc3.2.dll"
  if [ -n "${PY:-}" ]; then
    pydll=${PYLIB:-python310.lib}
    echo "  ${pydll%.lib}.dll"
  fi
  if [ -n "${CUDSS_DIR:-}" ]; then
    echo "  cudss64_*.dll  cudart64_*.dll  cublas64_*.dll  cublasLt64_*.dll"
  fi
  echo
  # The runtime DLL list depends on which features this build enabled, so the
  # shippable version is generated from the build rather than kept in sync by
  # hand. It is written beside getdp.exe. Not captured in a $(...): its progress
  # and any error must reach the terminal, and a failure here must not lose the
  # build - the binary above is already good.
  echo "Full list with versions and licences, ready to ship:"
  if ! ./scripts/gen_linked_libs.sh "$BUILDDIR"; then
    echo "WARNING: could not generate linked_libs.md - the build itself is fine."
  fi
else
  echo "FAILED: no $EXE"; exit 1
fi

if [ "$arch_rc" -ne 0 ]; then
  echo
  echo "FAILED: a post-build check rejected this binary (see above). Do not ship it."
  exit "$arch_rc"
fi
