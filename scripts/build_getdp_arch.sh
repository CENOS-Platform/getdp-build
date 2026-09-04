#!/usr/bin/env bash
# Link GetDP against an arbitrary PETSc arch, into its own build dir.
# usage: build_getdp_arch.sh <PETSC_ARCH> <build-dir-name> <blas-libs> [extra-version-tag]
# <blas-libs> must match the BLAS the PETSc arch was built with, otherwise the
# binary ends up with both OpenBLAS and MKL in it.
set -e
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$PATH
ROOT=${ROOT:-/cygdrive/d/source/for_getdp_build}
export PETSC_DIR=$ROOT/petsc
export PETSC_ARCH=$1
BUILDDIR=$2
BLASLIBS=$3
TAG=${4:-+cenos.$1}

cd $ROOT/cenos-getdp-fork
rm -rf $BUILDDIR
mkdir -p $BUILDDIR && cd $BUILDDIR
cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
      -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
      -DCMAKE_Fortran_COMPILER=x86_64-w64-mingw32-gfortran \
      -DENABLE_MPI=0 -DENABLE_BLAS_LAPACK=1 -DENABLE_OPENMP=1 -DENABLE_PETSC=1 \
      -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release \
      -DBLAS_LAPACK_LIBRARIES="$BLASLIBS" \
      -DGMSH_INC=/usr/local/include -DGMSH_LIB=/usr/local/lib/libgmsh.a \
      -DENABLE_PYTHON=0 \
      -DGETDP_RELEASE=1 \
      -DGETDP_EXTRA_VERSION="$TAG" \
      ..
make -j"$(nproc)"
ls -la getdp.exe
./getdp.exe -info 2>&1 | head -20
echo "GETDP_BUILD_DONE_$1"
