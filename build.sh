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
BUILDDIR=${BUILDDIR:-build}

: "${MKL:?set MKL to a oneMKL install (see the header of this script)}"
[ -f "$MKL/lib/mkl_rt.lib" ] || { echo "no $MKL/lib/mkl_rt.lib"; exit 1; }
[ -d "$MKL/include" ]        || { echo "no $MKL/include"; exit 1; }
[ -d src/petsc/config ]      || { echo "sources missing - run: git submodule update --init --recursive"; exit 1; }

./scripts/fix_eol.sh                        # CRLF submodule checkout -> LF

echo "MKL       : $MKL"
echo "Python    : ${PY:-<none - test binary only>}"
echo "cuDSS     : ${CUDSS_DIR:-<none>}"
echo "output    : src/cenos-getdp-fork/$BUILDDIR/getdp.exe"
echo

./scripts/build_deps.sh                     # OpenBLAS, LAPACK, gmsh
./scripts/build_metis_only.sh               # METIS
./scripts/build_mkl_petsc.sh                # PETSc arch complex_mkl_metis
./scripts/build_getdp_arch.sh complex_mkl_metis "$BUILDDIR" "$MKL/lib/mkl_rt.lib"

EXE="$ROOT/cenos-getdp-fork/$BUILDDIR/getdp.exe"
echo
if [ -x "$EXE" ]; then
  echo "OK: $EXE"
  [ -n "${PY:-}" ] || echo "NOTE: built without embedded Python - not the shippable binary."
  echo "Runtime DLLs: mkl_rt.2.dll and its kernels (already in CENOS backend/bin);"
  echo "              plus python*.dll if PY was set, and cuDSS/CUDA DLLs if CUDSS_DIR was."
else
  echo "FAILED: no $EXE"; exit 1
fi
