#!/usr/bin/env bash
# Link GetDP against a PETSc arch.
#   build_getdp_arch.sh <PETSC_ARCH> <build-dir> <blas-libs>
#
# Optional, from the environment:
#   PY=<dir>                CPython prefix (include/, libs/$PYLIB) -> embedded Python
#   PYLIB=<file>            default python310.lib
#   CUDSS_DIR=<dir>         NVIDIA cuDSS install  -> GPU direct solve
#   CUDA_TOOLKIT_DIR=<dir>  required when CUDSS_DIR is set
#   BUILD_METADATA=<string> override the auto-derived "+" metadata (py310.cu13.g<hash>)
#   GETDP_EXTRA_VERSION=<s> override the whole version suffix; normally left unset
#                           so the fork's own -cenos.N tag is used
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

# Version build metadata - the part after "+" in e.g.
#   4.0.0-cenos.1+py310.cu13.g9622b0d
# The fork's CMakeLists owns the "-cenos.N" pre-release tag (bump
# GETDP_CENOS_REVISION there); this script only describes what the binary was
# actually linked against. SemVer ignores everything after "+" when comparing
# versions, so nothing here can affect ordering - it is traceability only.
if [ -z "${BUILD_METADATA:-}" ]; then
  META=()
  # python310.lib -> py310
  if [ -n "${PY:-}" ]; then
    v=${PYLIB%.lib}; v=${v#python}
    META+=("py${v:-unknown}")
  fi
  if [ -n "${CUDSS_DIR:-}" ]; then
    # CUDART_VERSION is 1000*major + 10*minor, e.g. 13000 -> cu13.
    cu=""
    for h in "$CUDA_TOOLKIT_DIR/include/cuda_runtime_api.h" \
             "$CUDA_TOOLKIT_DIR/include/cuda_runtime.h"; do
      [ -f "$h" ] || continue
      v=$(sed -n 's/^[[:space:]]*#define[[:space:]]\{1,\}CUDART_VERSION[[:space:]]\{1,\}\([0-9]\{1,\}\).*/\1/p' "$h" | head -1)
      [ -n "$v" ] && { cu=$((v / 1000)); break; }
    done
    # pip-wheel CUDA layouts (nvidia/cu13/...) ship no cudart header, so the
    # directory name is the only statement of the major version available.
    if [ -z "$cu" ]; then
      case "$(basename "$CUDSS_DIR")" in
        cu[0-9]*) cu=$(basename "$CUDSS_DIR"); cu=${cu#cu} ;;
      esac
    fi
    # The exact cuDSS version is printed by the solver at runtime, so only the
    # CUDA major goes in the tag; "cudss" alone if even that is not derivable.
    if [ -n "$cu" ]; then META+=("cu$cu"); else META+=("cudss"); fi
  fi
  h=$(git -C "$ROOT/cenos-getdp-fork" log -1 --format=%h 2>/dev/null || true)
  [ -n "$h" ] && META+=("g$h")
  BUILD_METADATA=$(IFS=.; echo "${META[*]}")
fi
OPTS+=("-DGETDP_BUILD_METADATA=$BUILD_METADATA")
# Normally unset: the fork supplies "-cenos.N" itself. Set it only to override.
if [ -n "${GETDP_EXTRA_VERSION:-}" ]; then
  OPTS+=("-DGETDP_EXTRA_VERSION=$GETDP_EXTRA_VERSION")
fi
echo "  version metadata: ${BUILD_METADATA:-<none>}"

cd "$ROOT/cenos-getdp-fork"
rm -rf "$BUILDDIR"; mkdir -p "$BUILDDIR"; cd "$BUILDDIR"
cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
      -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
      -DCMAKE_Fortran_COMPILER=x86_64-w64-mingw32-gfortran \
      -DENABLE_MPI=0 -DENABLE_BLAS_LAPACK=1 -DENABLE_OPENMP=1 -DENABLE_PETSC=1 \
      -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release \
      -DBLAS_LAPACK_LIBRARIES="$BLASLIBS" \
      -DGMSH_INC=/usr/local/include -DGMSH_LIB=/usr/local/lib/libgmsh.a \
      -DGETDP_RELEASE=1 \
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
