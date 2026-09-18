#!/usr/bin/env bash
# OpenBLAS + LAPACK + gmsh. Skips anything already built with the current C
# runtime; FORCE=1 cleans and rebuilds all three (see scripts/crt.sh).
set -e
ROOT=${ROOT:?set ROOT to the src/ directory}
CFG="$(cd "$(dirname "$0")/../config" && pwd)"
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$PATH
. "$(dirname "$0")/crt.sh"

BLAS_A="$ROOT/OpenBLAS/libopenblas.a"
if [ -f "$BLAS_A" ] && [ -z "${FORCE:-}" ]; then
  crt_require "$BLAS_A" OpenBLAS
else
  echo "== OpenBLAS =="
  # Recompile, don't relink: a rebuild here means either FORCE or a CRT switch,
  # and the objects already on disk were compiled with the other runtime's
  # headers. OpenBLAS keeps them in the source tree, so nothing else clears them.
  ( cd "$ROOT/OpenBLAS" && make clean >/dev/null 2>&1 ) || true
  cp "$CFG/Makefile.rule" "$ROOT/OpenBLAS/Makefile.rule"
  # Makefile.rule is read before Makefile.system, which appends to these itself.
  if [ -n "$CRT_FLAGS" ]; then
    printf 'CCOMMON_OPT += %s\nFCOMMON_OPT += %s\n' "$CRT_FLAGS" "$CRT_FLAGS" \
      >> "$ROOT/OpenBLAS/Makefile.rule"
  fi
  ( cd "$ROOT/OpenBLAS" && make -j"$(nproc)" )
  crt_record "$BLAS_A"
fi

LAPACK_A="$ROOT/lapack/build/lib/liblapack.a"
if [ -f "$LAPACK_A" ] && [ -z "${FORCE:-}" ]; then
  crt_require "$LAPACK_A" LAPACK
else
  echo "== LAPACK =="
  rm -rf "$ROOT/lapack/build"   # stale objects and a cached CMAKE_C_FLAGS
  mkdir -p "$ROOT/lapack/build"
  ( cd "$ROOT/lapack/build" \
    && cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
             -DCMAKE_Fortran_COMPILER=x86_64-w64-mingw32-gfortran \
             -DCMAKE_C_FLAGS="$CRT_FLAGS" -DCMAKE_Fortran_FLAGS="$CRT_FLAGS" \
             -DBUILD_SHARED_LIBS=OFF -DCBLAS=OFF -DLAPACKE=OFF \
             -DLAPACKE_WITH_TMG=OFF .. \
    && make -j"$(nproc)" )
  crt_record "$LAPACK_A"
fi

GMSH_A=/usr/local/lib/libgmsh.a
if [ -f "$GMSH_A" ] && [ -z "${FORCE:-}" ]; then
  crt_require "$GMSH_A" gmsh
else
  echo "== gmsh =="
  rm -rf "$ROOT/gmsh/build"   # a failed configure leaves a stale cache
  mkdir -p "$ROOT/gmsh/build"
  ( cd "$ROOT/gmsh/build" \
    && cmake -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
             -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
             -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
             -DCMAKE_C_FLAGS="$CRT_FLAGS" -DCMAKE_CXX_FLAGS="$CRT_FLAGS" \
             -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
             -DENABLE_BUILD_LIB=1 -DENABLE_BUILD_SHARED=OFF -DENABLE_BUILD_DYNAMIC=OFF \
             -DENABLE_BLAS_LAPACK=1 -DENABLE_OPENMP=1 -DENABLE_PARSER=1 -DENABLE_POST=1 \
             -DENABLE_PLUGINS=1 -DENABLE_PRIVATE_API=1 -DENABLE_ALGLIB=1 -DENABLE_ANN=1 \
             -DENABLE_GMP=ON \
             -DENABLE_MESH=OFF -DENABLE_OCC=OFF -DENABLE_FLTK=0 -DENABLE_MPI=OFF \
             -DENABLE_PETSC=OFF -DENABLE_MED=OFF -DENABLE_CGNS=OFF -DENABLE_MMG=OFF \
             -DENABLE_METIS=OFF -DENABLE_NETGEN=OFF -DENABLE_TESTS=OFF -DENABLE_EIGEN=0 \
             -DENABLE_WRAP_PYTHON=OFF .. \
    && make -j"$(nproc)" && make install )
  crt_record "$GMSH_A"
fi
echo "deps ready"
