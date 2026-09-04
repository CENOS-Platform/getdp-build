#!/usr/bin/env bash
# OpenBLAS + LAPACK + gmsh. Skips anything already built.
set -e
ROOT=${ROOT:?set ROOT to the src/ directory}
CFG="$(cd "$(dirname "$0")/../config" && pwd)"
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$PATH

if [ ! -f "$ROOT/OpenBLAS/libopenblas.a" ]; then
  echo "== OpenBLAS =="
  cp "$CFG/Makefile.rule" "$ROOT/OpenBLAS/Makefile.rule"
  ( cd "$ROOT/OpenBLAS" && make -j"$(nproc)" )
fi

if [ ! -f "$ROOT/lapack/build/lib/liblapack.a" ]; then
  echo "== LAPACK =="
  mkdir -p "$ROOT/lapack/build"
  ( cd "$ROOT/lapack/build" \
    && cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
             -DCMAKE_Fortran_COMPILER=x86_64-w64-mingw32-gfortran \
             -DBUILD_SHARED_LIBS=OFF -DCBLAS=OFF -DLAPACKE=OFF \
             -DLAPACKE_WITH_TMG=OFF .. \
    && make -j"$(nproc)" )
fi

if [ ! -f /usr/local/lib/libgmsh.a ]; then
  echo "== gmsh =="
  mkdir -p "$ROOT/gmsh/build"
  ( cd "$ROOT/gmsh/build" \
    && cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
             -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
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
fi
echo "deps ready"
