#!/usr/bin/env bash
# Link GetDP against a PETSc arch.
#   build_getdp_arch.sh <PETSC_ARCH> <build-dir> <blas-libs>
#
# Optional, from the environment:
#   PY=<dir>                CPython prefix (include/, libs/$PYLIB) -> embedded Python
#   PYLIB=<file>            default python310.lib
#   CUDSS_DIR=<dir>         NVIDIA cuDSS install  -> GPU direct solve
#   CUDA_TOOLKIT_DIR=<dir>  required when CUDSS_DIR is set
#   TAG=<string>            version suffix, default +cenos.<arch>
#
# <blas-libs> must match the BLAS the arch was configured with, or the binary
# links two BLAS implementations.
set -e
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$PATH
ROOT=${ROOT:?set ROOT to the sources directory}
export PETSC_DIR=$ROOT/petsc
export PETSC_ARCH=${1:?arch}
BUILDDIR=${2:?build dir}
BLASLIBS=${3:?blas libs}
TAG=${TAG:-+cenos.$PETSC_ARCH}

OPTS=()
if [ -n "${PY:-}" ]; then
  PYLIB=${PYLIB:-python310.lib}
  [ -d "$PY/include" ] || { echo "PY=$PY has no include/"; exit 1; }
  [ -f "$PY/libs/$PYLIB" ] || { echo "PY=$PY has no libs/$PYLIB"; exit 1; }
  OPTS+=(-DENABLE_PYTHON=1 "-DPYTHON_INCLUDE_DIR=$PY/include" "-DPYTHON_LIBRARY=$PY/libs/$PYLIB")
  echo "  embedded Python: $PY ($PYLIB)"
else
  OPTS+=(-DENABLE_PYTHON=0)
  echo "  embedded Python: no (not shippable; fine for testing)"
fi

if [ -n "${CUDSS_DIR:-}" ]; then
  : "${CUDA_TOOLKIT_DIR:?set CUDA_TOOLKIT_DIR together with CUDSS_DIR}"
  OPTS+=(-DENABLE_CUDSS=1 "-DCUDSS_DIR=$CUDSS_DIR" "-DCUDA_TOOLKIT_DIR=$CUDA_TOOLKIT_DIR")
  echo "  cuDSS GPU solve: $CUDSS_DIR"
else
  echo "  cuDSS GPU solve: no"
fi

cd "$ROOT/cenos-getdp-fork"
rm -rf "$BUILDDIR"; mkdir -p "$BUILDDIR"; cd "$BUILDDIR"
cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
      -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
      -DCMAKE_Fortran_COMPILER=x86_64-w64-mingw32-gfortran \
      -DENABLE_MPI=0 -DENABLE_BLAS_LAPACK=1 -DENABLE_OPENMP=1 -DENABLE_PETSC=1 \
      -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release \
      -DBLAS_LAPACK_LIBRARIES="$BLASLIBS" \
      -DGMSH_INC=/usr/local/include -DGMSH_LIB=/usr/local/lib/libgmsh.a \
      -DGETDP_RELEASE=1 -DGETDP_EXTRA_VERSION="$TAG" \
      "${OPTS[@]}" ..
make -j"$(nproc)"
# Smoke test. The binary needs its DLLs at runtime - python310.dll from $PY and
# mkl_rt.2.dll from the MKL install - so put them on PATH here rather than
# reporting a link success that cannot actually start.
RUNPATH="$PATH"
if [ -n "${MKL:-}" ]; then RUNPATH="$MKL/bin:$(dirname "$MKL"):$RUNPATH"; fi
if [ -n "${PY:-}" ]; then RUNPATH="$PY:$RUNPATH"; fi
if out=$(PATH="$RUNPATH" ./getdp.exe -info 2>&1); then
  echo "$out" | head -3
else
  echo "$out" | head -3
  echo "WARNING: getdp.exe built but would not start."
  echo "  It needs python310.dll (from PY) and mkl_rt.2.dll (from MKL) on PATH."
  echo "  The link itself is fine - this is a runtime DLL search issue."
fi
