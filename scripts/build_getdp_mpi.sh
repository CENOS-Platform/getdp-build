#!/usr/bin/env bash
# GetDP against the MPI-parallel MUMPS arch.
#
# Two extras vs the sequential builds:
#  1. ScaLAPACK/BLACS must be on the link line - GetDP's CMake links only
#     BLAS_LAPACK_LIBRARIES + libpetsc, not PETSc's full external lib list.
#  2. MKL's ScaLAPACK exports UPPERCASE Fortran names; libscalapack_alias.a
#     bridges the three pzelset_/pzelget_/pzmatadd_ PETSc wants.
set -e
export PATH=/usr/x86_64-w64-mingw32/sys-root/mingw/bin:$PATH
ROOT=${ROOT:-/cygdrive/d/source/for_getdp_build}
MKL=${MKL:-/cygdrive/d/source/cenos/backend/bin/Library}
export PETSC_DIR=$ROOT/petsc
export PETSC_ARCH=complex_mpi_mumps

SCALIBS="$ROOT/libscalapack_alias.a;$MKL/lib/mkl_scalapack_lp64_dll.lib;$MKL/lib/mkl_blacs_lp64_dll.lib;$MKL/lib/mkl_rt.lib"
# Build the ScaLAPACK naming bridge (see scalapack_alias.c for why)
x86_64-w64-mingw32-gcc -O2 -c $ROOT/scalapack_alias.c -o $ROOT/scalapack_alias.o
ar cr $ROOT/libscalapack_alias.a $ROOT/scalapack_alias.o
ranlib $ROOT/libscalapack_alias.a

cd $ROOT/cenos-getdp-fork
rm -rf build_mpi
mkdir -p build_mpi && cd build_mpi
cmake -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
      -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
      -DCMAKE_Fortran_COMPILER=x86_64-w64-mingw32-gfortran \
      -DENABLE_MPI=0 -DENABLE_BLAS_LAPACK=1 -DENABLE_OPENMP=1 -DENABLE_PETSC=1 \
      -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release \
      -DBLAS_LAPACK_LIBRARIES="$SCALIBS" \
      -DGMSH_INC=/usr/local/include -DGMSH_LIB=/usr/local/lib/libgmsh.a \
      -DENABLE_PYTHON=0 \
      -DGETDP_RELEASE=1 \
      -DGETDP_EXTRA_VERSION="+cenos.mpi" \
      ..
make -j"$(nproc)"
ls -la getdp.exe
echo "GETDP_MPI_BUILD_DONE"
